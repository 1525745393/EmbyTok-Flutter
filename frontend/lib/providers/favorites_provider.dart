// 收藏列表与状态管理（三栏：影片 / 合集 / 人物）
// - 自动监听登录状态：登录后从 Emby 并行拉取三栏数据，登出后清除本地缓存
// - toggleFavorite 采用乐观更新 + 失败回滚，提供即时 UI 反馈
// - 同一 itemId 的并发 toggleFavorite 自动合并（_pendingToggles 去重）
// - 网络层去重：_hasLoaded + _isLoading 标志避免重复 loadFavorites
// - 分页加载：每栏独立 offset + hasMore，loadMore 追加数据
// - 本地缓存：SharedPreferences 缓存 JSON，进入页面先展示缓存再后台刷新

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../services/embbytok_service.dart';
import '../utils/logger.dart';
import 'auth_provider.dart';
import 'cache_providers.dart';

// 每页拉取数量
const int _kFavoritesPageSize = 50;
// 本地缓存 key 前缀
const String _kCacheKeyPrefix = 'favorites_cache_';

/// 收藏状态：影片 / 合集 / 人物 三栏独立列表 + O(1) 快速查询的 favoriteIds
///
/// 核心字段：
/// - [movies] 收藏的影片列表
/// - [boxsets] 收藏的合集（BoxSet）列表
/// - [people] 收藏的人物（导演 / 演员）列表
/// - [favoriteIds] 所有已收藏条目的 ID 集合（用于快速判定收藏状态）
/// - [moviesError]/[boxSetsError]/[peopleError] 各栏独立的错误信息（部分失败时使用）
/// - [hasMoreMovies]/[hasMoreBoxSets]/[hasMorePeople] 各栏是否还有更多数据
class FavoritesState {
  final List<MediaItem> movies;
  final List<MediaItem> boxSets;
  final List<MediaItem> people;
  final bool isLoading;
  final bool isLoadingMore; // 加载更多中
  final String? error;
  final String? moviesError;
  final String? boxSetsError;
  final String? peopleError;
  final Set<String> favoriteIds;
  final bool hasMoreMovies;
  final bool hasMoreBoxSets;
  final bool hasMorePeople;
  final bool fromCache; // 当前数据是否来自本地缓存

  const FavoritesState({
    this.movies = const <MediaItem>[],
    this.boxSets = const <MediaItem>[],
    this.people = const <MediaItem>[],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.moviesError,
    this.boxSetsError,
    this.peopleError,
    this.favoriteIds = const <String>{},
    this.hasMoreMovies = false,
    this.hasMoreBoxSets = false,
    this.hasMorePeople = false,
    this.fromCache = false,
  });

  FavoritesState copyWith({
    List<MediaItem>? movies,
    List<MediaItem>? boxSets,
    List<MediaItem>? people,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    String? moviesError,
    String? boxSetsError,
    String? peopleError,
    Set<String>? favoriteIds,
    bool? hasMoreMovies,
    bool? hasMoreBoxSets,
    bool? hasMorePeople,
    bool? fromCache,
  }) {
    return FavoritesState(
      movies: movies ?? this.movies,
      boxSets: boxSets ?? this.boxSets,
      people: people ?? this.people,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error ?? this.error,
      moviesError: moviesError ?? this.moviesError,
      boxSetsError: boxSetsError ?? this.boxSetsError,
      peopleError: peopleError ?? this.peopleError,
      favoriteIds: favoriteIds ?? this.favoriteIds,
      hasMoreMovies: hasMoreMovies ?? this.hasMoreMovies,
      hasMoreBoxSets: hasMoreBoxSets ?? this.hasMoreBoxSets,
      hasMorePeople: hasMorePeople ?? this.hasMorePeople,
      fromCache: fromCache ?? this.fromCache,
    );
  }
}

/// 合并三组列表的 id 到一个 Set
Set<String> _mergeIds(
  List<MediaItem> a,
  List<MediaItem> b,
  List<MediaItem> c,
) {
  final ids = <String>{};
  for (final item in a) {
    ids.add(item.id);
  }
  for (final item in b) {
    ids.add(item.id);
  }
  for (final item in c) {
    ids.add(item.id);
  }
  return ids;
}

/// 收藏分类枚举（用于 loadMore）
enum FavoritesCategory { movie, boxSet, person }

/// 收藏 Notifier：管理整个应用的三栏收藏状态（乐观更新 + 并发去重 + 分页 + 本地缓存）
///
/// 核心功能：
/// - 登录后自动从 Emby 服务器拉取三栏收藏数据
/// - 登出后自动清空本地缓存
/// - toggleFavorite 采用乐观更新 + 失败回滚
/// - 同一 itemId 的并发 toggleFavorite 调用会自动合并（去重）
/// - 分页加载：每栏独立 offset，支持 loadMore 追加
/// - 本地缓存：SharedPreferences 缓存 JSON，先展示缓存再后台刷新
class FavoritesNotifier extends StateNotifier<FavoritesState> {
  final Ref _ref;
  final EmbytokService _service;

  bool _hasLoaded = false;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  final Set<String> _pendingToggles = <String>{};
  // 每栏已加载的数量（用于分页 offset）
  int _moviesLoaded = 0;
  int _boxSetsLoaded = 0;
  int _peopleLoaded = 0;

  ProviderSubscription<AuthState>? _authSubscription;

  FavoritesNotifier(this._ref, {EmbytokService? service})
      : _service = service ?? EmbytokService(),
        super(const FavoritesState()) {
    // 监听认证状态变化：登录 → 自动加载；登出 → 清除缓存
    _authSubscription = _ref.listen<AuthState>(authProvider, (previous, next) {
      final wasAuthenticated = previous?.isAuthenticated ?? false;
      final isNowAuthenticated = next.isAuthenticated;

      if (wasAuthenticated && !isNowAuthenticated) {
        // 用户登出：清空本地缓存，避免展示上一账号的数据
        reset();
      } else if (!wasAuthenticated && isNowAuthenticated) {
        // 用户登录：自动拉取当前账号的三栏收藏
        loadFavorites();
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.close();
    super.dispose();
  }

  AuthState get _auth => _ref.read(authProvider);

  /// 快速查询：某个 item 是否已收藏（纯同步，不触发网络）
  bool isFavorite(String itemId) {
    return state.favoriteIds.contains(itemId);
  }

  /// 确保至少加载过一次（幂等，并发安全）
  Future<void> ensureLoaded() async {
    if (_hasLoaded || _isLoading) return;
    await loadFavorites();
  }

  /// 从本地缓存加载收藏数据（快速展示，不等待网络）
  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = _auth.user?.id ?? 'default';

      final moviesJson = prefs.getString('$_kCacheKeyPrefix${userId}_movies');
      final boxSetsJson = prefs.getString('$_kCacheKeyPrefix${userId}_boxSets');
      final peopleJson = prefs.getString('$_kCacheKeyPrefix${userId}_people');

      final movies = _parseCache(moviesJson);
      final boxSets = _parseCache(boxSetsJson);
      final people = _parseCache(peopleJson);

      if (movies.isNotEmpty || boxSets.isNotEmpty || people.isNotEmpty) {
        final ids = _mergeIds(movies, boxSets, people);
        state = FavoritesState(
          movies: movies,
          boxSets: boxSets,
          people: people,
          favoriteIds: ids,
          fromCache: true,
        );
        AppLogger.info('从本地缓存加载收藏', data: {
          'movies': movies.length,
          'boxSets': boxSets.length,
          'people': people.length,
        });
      }
    } catch (e) {
      AppLogger.error('读取收藏缓存失败', error: e);
    }
  }

  List<MediaItem> _parseCache(String? json) {
    if (json == null || json.isEmpty) return [];
    try {
      final list = jsonDecode(json) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map((e) => MediaItem.fromJson(e))
          .toList();
    } catch (e) {
      AppLogger.error('解析收藏缓存失败', error: e);
      return [];
    }
  }

  /// 保存收藏数据到本地缓存
  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = _auth.user?.id ?? 'default';

      await prefs.setString(
        '$_kCacheKeyPrefix${userId}_movies',
        jsonEncode(state.movies.map((e) => e.toJson()).toList()),
      );
      await prefs.setString(
        '$_kCacheKeyPrefix${userId}_boxSets',
        jsonEncode(state.boxSets.map((e) => e.toJson()).toList()),
      );
      await prefs.setString(
        '$_kCacheKeyPrefix${userId}_people',
        jsonEncode(state.people.map((e) => e.toJson()).toList()),
      );
    } catch (e) {
      AppLogger.error('保存收藏缓存失败', error: e);
    }
  }

  /// 从 Emby 服务器并行拉取三栏收藏（首页，每栏 _kFavoritesPageSize 条）
  /// 每栏独立 try-catch：某一栏失败不影响其他栏展示
  /// 先尝试加载本地缓存，再后台刷新
  Future<void> loadFavorites() async {
    if (_isLoading) return;

    // 先从缓存加载（快速展示）
    if (!_hasLoaded) {
      await _loadFromCache();
    }

    _isLoading = true;
    state = state.copyWith(
      isLoading: true,
      error: null,
      moviesError: null,
      boxSetsError: null,
      peopleError: null,
      fromCache: false,
    );
    AppLogger.info('加载收藏列表（三栏）');

    final auth = _auth;
    if (!auth.isAuthenticated ||
        auth.embyServerUrl == null ||
        auth.token == null) {
      _isLoading = false;
      state = state.copyWith(isLoading: false, error: '尚未登录');
      return;
    }

    final serverUrl = auth.embyServerUrl;
    final token = auth.token;
    final userId = auth.user?.id;
    if (serverUrl == null || token == null) {
      _isLoading = false;
      state = state.copyWith(isLoading: false, error: '尚未登录');
      return;
    }

    // 三栏独立 try-catch，部分失败不影响整体
    List<MediaItem> movies = [];
    List<MediaItem> boxSets = [];
    List<MediaItem> people = [];
    String? moviesError;
    String? boxSetsError;
    String? peopleError;
    int moviesTotal = 0;
    int boxSetsTotal = 0;
    int peopleTotal = 0;

    await Future.wait<void>([
      // 收藏影片
      () async {
        try {
          final result = await _ref.read(cachedMediaRepositoryProvider).getFavoriteMovies(
            limit: _kFavoritesPageSize,
            offset: 0,
            serverUrl: serverUrl,
            token: token,
            userId: userId,
          );
          movies = result.items;
          moviesTotal = result.totalCount;
        } catch (e) {
          moviesError = e is String ? e : '加载失败：$e';
          AppLogger.error('加载收藏影片失败', error: e);
        }
      }(),
      // 收藏合集
      () async {
        try {
          final result = await _ref.read(cachedMediaRepositoryProvider).getFavoriteBoxSets(
            limit: _kFavoritesPageSize,
            offset: 0,
            serverUrl: serverUrl,
            token: token,
            userId: userId,
          );
          boxSets = result.items;
          boxSetsTotal = result.totalCount;
        } catch (e) {
          boxSetsError = e is String ? e : '加载失败：$e';
          AppLogger.error('加载收藏合集失败', error: e);
        }
      }(),
      // 收藏人物
      () async {
        try {
          final result = await _ref.read(cachedMediaRepositoryProvider).getFavoritePeople(
            limit: _kFavoritesPageSize,
            offset: 0,
            serverUrl: serverUrl,
            token: token,
            userId: userId,
          );
          people = result.items;
          peopleTotal = result.totalCount;
        } catch (e) {
          peopleError = e is String ? e : '加载失败：$e';
          AppLogger.error('加载收藏人物失败', error: e);
        }
      }(),
    ], eagerError: false);

    // 更新分页计数
    _moviesLoaded = movies.length;
    _boxSetsLoaded = boxSets.length;
    _peopleLoaded = people.length;

    // 合并 favoriteIds
    final ids = _mergeIds(movies, boxSets, people);

    // 全部失败才设置全局 error
    final allFailed =
        moviesError != null && boxSetsError != null && peopleError != null;

    state = FavoritesState(
      movies: movies,
      boxSets: boxSets,
      people: people,
      isLoading: false,
      error: allFailed ? '全部收藏加载失败' : null,
      moviesError: moviesError,
      boxSetsError: boxSetsError,
      peopleError: peopleError,
      favoriteIds: ids,
      hasMoreMovies: moviesTotal > movies.length,
      hasMoreBoxSets: boxSetsTotal > boxSets.length,
      hasMorePeople: peopleTotal > people.length,
    );
    _hasLoaded = true;
    AppLogger.info('收藏列表加载完成', data: {
      'movies': '${movies.length}/$moviesTotal',
      'boxSets': '${boxSets.length}/$boxSetsTotal',
      'people': '${people.length}/$peopleTotal',
    });
    _isLoading = false;

    // 保存到本地缓存
    _saveToCache();
  }

  /// 加载更多（分页追加）
  /// [category] 指定加载哪一栏
  Future<void> loadMore(FavoritesCategory category) async {
    if (_isLoadingMore) return;

    final auth = _auth;
    if (!auth.isAuthenticated ||
        auth.embyServerUrl == null ||
        auth.token == null) {
      return;
    }

    final serverUrl = auth.embyServerUrl;
    final token = auth.token;
    final userId = auth.user?.id;
    if (serverUrl == null || token == null) return;

    // 检查该栏是否还有更多
    bool hasMore;
    int offset;
    switch (category) {
      case FavoritesCategory.movie:
        hasMore = state.hasMoreMovies;
        offset = _moviesLoaded;
        break;
      case FavoritesCategory.boxSet:
        hasMore = state.hasMoreBoxSets;
        offset = _boxSetsLoaded;
        break;
      case FavoritesCategory.person:
        hasMore = state.hasMorePeople;
        offset = _peopleLoaded;
        break;
    }
    if (!hasMore) return;

    _isLoadingMore = true;
    state = state.copyWith(isLoadingMore: true);

    try {
      FavoritesPageResult result;
      final cachedRepo = _ref.read(cachedMediaRepositoryProvider);
      switch (category) {
        case FavoritesCategory.movie:
          result = await cachedRepo.getFavoriteMovies(
            limit: _kFavoritesPageSize,
            offset: offset,
            serverUrl: serverUrl,
            token: token,
            userId: userId,
          );
          _moviesLoaded += result.items.length;
          final newMovies = [...state.movies, ...result.items];
          final newIds = _mergeIds(newMovies, state.boxSets, state.people);
          state = state.copyWith(
            movies: newMovies,
            favoriteIds: newIds,
            hasMoreMovies: result.totalCount > newMovies.length,
            isLoadingMore: false,
          );
          break;
        case FavoritesCategory.boxSet:
          result = await cachedRepo.getFavoriteBoxSets(
            limit: _kFavoritesPageSize,
            offset: offset,
            serverUrl: serverUrl,
            token: token,
            userId: userId,
          );
          _boxSetsLoaded += result.items.length;
          final newBoxSets = [...state.boxSets, ...result.items];
          final newIds = _mergeIds(state.movies, newBoxSets, state.people);
          state = state.copyWith(
            boxSets: newBoxSets,
            favoriteIds: newIds,
            hasMoreBoxSets: result.totalCount > newBoxSets.length,
            isLoadingMore: false,
          );
          break;
        case FavoritesCategory.person:
          result = await cachedRepo.getFavoritePeople(
            limit: _kFavoritesPageSize,
            offset: offset,
            serverUrl: serverUrl,
            token: token,
            userId: userId,
          );
          _peopleLoaded += result.items.length;
          final newPeople = [...state.people, ...result.items];
          final newIds = _mergeIds(state.movies, state.boxSets, newPeople);
          state = state.copyWith(
            people: newPeople,
            favoriteIds: newIds,
            hasMorePeople: result.totalCount > newPeople.length,
            isLoadingMore: false,
          );
          break;
      }
      AppLogger.info('收藏分页加载更多', data: {
        'category': category.name,
        'newItems': result.items.length,
      });
    } catch (e) {
      AppLogger.error('收藏分页加载失败', error: e);
      state = state.copyWith(isLoadingMore: false);
    } finally {
      _isLoadingMore = false;
    }
  }

  /// 切换某条目的收藏状态
  ///
  /// 乐观更新 UI → 发网络请求 → 成功则保留，失败则回滚
  /// 同一 itemId 的并发调用会自动合并为一次，避免重复请求与状态抖动
  Future<void> toggleFavorite(MediaItem item) async {
    final auth = _auth;
    if (!auth.isAuthenticated ||
        auth.embyServerUrl == null ||
        auth.token == null) {
      state = state.copyWith(error: '尚未登录');
      return;
    }

    // 去重：防止快速连点产生重复请求
    if (_pendingToggles.contains(item.id)) return;
    _pendingToggles.add(item.id);

    // 1. 读取当前状态（乐观更新的基准）
    final currentlyFavorite = isFavorite(item.id);
    final newIsFavorite = !currentlyFavorite;

    AppLogger.info('切换收藏状态',
        data: {'itemId': item.id, 'itemTitle': item.title, 'newState': newIsFavorite});

    // 2. 乐观更新 UI：先按目标状态渲染
    final newIds = Set<String>.from(state.favoriteIds);
    final newMovies = List<MediaItem>.from(state.movies);
    final newBoxSets = List<MediaItem>.from(state.boxSets);
    final newPeople = List<MediaItem>.from(state.people);

    if (newIsFavorite) {
      newIds.add(item.id);
      // 根据类型加入对应的列表
      if (item.isBoxSet) {
        if (!newBoxSets.any((e) => e.id == item.id)) {
          newBoxSets.insert(0, item);
        }
      } else if (item.isPerson) {
        if (!newPeople.any((e) => e.id == item.id)) {
          newPeople.insert(0, item);
        }
      } else {
        // 默认作为影片
        if (!newMovies.any((e) => e.id == item.id)) {
          newMovies.insert(0, item);
        }
      }
    } else {
      newIds.remove(item.id);
      newMovies.removeWhere((e) => e.id == item.id);
      newBoxSets.removeWhere((e) => e.id == item.id);
      newPeople.removeWhere((e) => e.id == item.id);
    }

    state = state.copyWith(
      movies: newMovies,
      boxSets: newBoxSets,
      people: newPeople,
      favoriteIds: newIds,
      error: null,
    );

    // 3. 真正同步到服务器
    try {
      final serverUrl = auth.embyServerUrl;
      final token = auth.token;
      final userId = auth.user?.id;
      if (serverUrl == null || token == null) return;
      await _service.toggleFavorite(
        itemId: item.id,
        isFavorite: newIsFavorite,
        serverUrl: serverUrl,
        token: token,
        userId: userId,
      );
      // 同步成功后更新本地缓存
      _saveToCache();

      // 失效相关内存缓存：收藏状态变化会影响多种查询结果
      // 1. 收藏列表缓存（getFavoriteMovies 等）
      // 2. 媒体库列表缓存（可能包含 IsFavorite 过滤的查询）
      // 3. 媒体详情缓存（IsFavorite 标志位已变）
      try {
        final cacheController = _ref.read(cacheControllerProvider);
        cacheController.invalidateFavorites(serverUrl, token, userId);
        cacheController.invalidateItemDetail(item.id, serverUrl);
      } catch (_) {}
    } catch (e) {
      // 4. 失败回滚：恢复到乐观更新前的状态
      final rollbackIds = Set<String>.from(state.favoriteIds);
      final rollbackMovies = List<MediaItem>.from(state.movies);
      final rollbackBoxSets = List<MediaItem>.from(state.boxSets);
      final rollbackPeople = List<MediaItem>.from(state.people);

      if (currentlyFavorite) {
        rollbackIds.add(item.id);
        if (item.isBoxSet) {
          if (!rollbackBoxSets.any((e) => e.id == item.id)) {
            rollbackBoxSets.insert(0, item);
          }
        } else if (item.isPerson) {
          if (!rollbackPeople.any((e) => e.id == item.id)) {
            rollbackPeople.insert(0, item);
          }
        } else {
          if (!rollbackMovies.any((e) => e.id == item.id)) {
            rollbackMovies.insert(0, item);
          }
        }
      } else {
        rollbackIds.remove(item.id);
        rollbackMovies.removeWhere((e) => e.id == item.id);
        rollbackBoxSets.removeWhere((e) => e.id == item.id);
        rollbackPeople.removeWhere((e) => e.id == item.id);
      }

      final message = e is String ? e : '切换收藏失败：$e';
      state = state.copyWith(
        movies: rollbackMovies,
        boxSets: rollbackBoxSets,
        people: rollbackPeople,
        favoriteIds: rollbackIds,
        error: message,
      );
      AppLogger.error('切换收藏失败', error: e);
    } finally {
      _pendingToggles.remove(item.id);
    }
  }

  /// 登出/切换账号时清除所有本地缓存（下一次使用会重新拉取）
  Future<void> reset() async {
    _hasLoaded = false;
    _moviesLoaded = 0;
    _boxSetsLoaded = 0;
    _peopleLoaded = 0;
    _pendingToggles.clear();
    state = const FavoritesState();

    // 清除本地缓存
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = _auth.user?.id ?? 'default';
      await prefs.remove('$_kCacheKeyPrefix${userId}_movies');
      await prefs.remove('$_kCacheKeyPrefix${userId}_boxSets');
      await prefs.remove('$_kCacheKeyPrefix${userId}_people');
    } catch (e) {
      AppLogger.error('清除收藏缓存失败', error: e);
    }
  }
}

/// 顶层 Provider：整个 app 共享一份收藏状态
final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, FavoritesState>((ref) {
  return FavoritesNotifier(ref);
});
