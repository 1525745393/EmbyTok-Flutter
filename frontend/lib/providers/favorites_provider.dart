// 收藏列表与状态管理（三栏：影片 / 合集 / 人物）
// - 自动监听登录状态：登录后从 Emby 并行拉取三栏数据，登出后清除本地缓存
// - toggleFavorite 采用乐观更新 + 失败回滚，提供即时 UI 反馈
// - 同一 itemId 的并发 toggleFavorite 自动合并（_pendingToggles 去重）
// - 网络层去重：_hasLoaded + _isLoading 标志避免重复 loadFavorites

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/embbytok_service.dart';
import '../utils/logger.dart';
import 'auth_provider.dart';

/// 收藏状态：影片 / 合集 / 人物 三栏独立列表 + O(1) 快速查询的 favoriteIds
///
/// 核心字段：
/// - [movies] 收藏的影片列表
/// - [boxsets] 收藏的合集（BoxSet）列表
/// - [people] 收藏的人物（导演 / 演员）列表
/// - [favoriteIds] 所有已收藏条目的 ID 集合（用于快速判定收藏状态）
class FavoritesState {
  final List<MediaItem> movies;
  final List<MediaItem> boxSets;
  final List<MediaItem> people;
  final bool isLoading;
  final String? error;
  final Set<String> favoriteIds;

  const FavoritesState({
    this.movies = const <MediaItem>[],
    this.boxSets = const <MediaItem>[],
    this.people = const <MediaItem>[],
    this.isLoading = false,
    this.error,
    this.favoriteIds = const <String>{},
  });

  FavoritesState copyWith({
    List<MediaItem>? movies,
    List<MediaItem>? boxSets,
    List<MediaItem>? people,
    bool? isLoading,
    String? error,
    Set<String>? favoriteIds,
  }) {
    return FavoritesState(
      movies: movies ?? this.movies,
      boxSets: boxSets ?? this.boxSets,
      people: people ?? this.people,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      favoriteIds: favoriteIds ?? this.favoriteIds,
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

/// 收藏 Notifier：管理整个应用的三栏收藏状态（乐观更新 + 并发去重）
///
/// 核心功能：
/// - 登录后自动从 Emby 服务器拉取三栏收藏数据
/// - 登出后自动清空本地缓存
/// - toggleFavorite 采用乐观更新 + 失败回滚
/// - 同一 itemId 的并发 toggleFavorite 调用会自动合并（去重）
class FavoritesNotifier extends StateNotifier<FavoritesState> {
  final Ref _ref;
  final EmbytokService _service;

  bool _hasLoaded = false;
  bool _isLoading = false;
  final Set<String> _pendingToggles = <String>{};

  FavoritesNotifier(this._ref, {EmbytokService? service})
      : _service = service ?? EmbytokService(),
        super(const FavoritesState()) {
    // 监听认证状态变化：登录 → 自动加载；登出 → 清除缓存
    _ref.listen<AuthState>(authProvider, (previous, next) {
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

  /// 从 Emby 服务器并行拉取三栏收藏
  Future<void> loadFavorites() async {
    if (_isLoading) return;
    _isLoading = true;
    state = state.copyWith(isLoading: true, error: null);
    AppLogger.info('加载收藏列表（三栏）');

    final auth = _auth;
    if (!auth.isAuthenticated ||
        auth.embyServerUrl == null ||
        auth.token == null) {
      _isLoading = false;
      state = state.copyWith(isLoading: false, error: '尚未登录');
      return;
    }

    try {
      // 并行请求三栏数据
      final serverUrl = auth.embyServerUrl!;
      final token = auth.token!;
      final userId = auth.user?.id;
      final results = await Future.wait<List<MediaItem>>([
        _service.getFavoriteMovies(serverUrl: serverUrl, token: token, userId: userId),
        _service.getFavoriteBoxSets(serverUrl: serverUrl, token: token, userId: userId),
        _service.getFavoritePeople(serverUrl: serverUrl, token: token, userId: userId),
      ], eagerError: false);

      final movies = results[0];
      final boxSets = results[1];
      final people = results[2];

      // 合并 favoriteIds
      final ids = _mergeIds(movies, boxSets, people);

      state = FavoritesState(
        movies: movies,
        boxSets: boxSets,
        people: people,
        isLoading: false,
        favoriteIds: ids,
      );
      _hasLoaded = true;
      AppLogger.info('收藏列表加载成功', data: {
        'movies': movies.length,
        'boxSets': boxSets.length,
        'people': people.length,
      });
    } catch (e) {
      final message = e is String ? e : '加载收藏失败：$e';
      state = state.copyWith(isLoading: false, error: message);
      AppLogger.error('加载收藏失败', error: e);
    } finally {
      _isLoading = false;
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
      final type = item.type.toLowerCase();
      if (type == 'boxset') {
        if (!newBoxSets.any((e) => e.id == item.id)) {
          newBoxSets.insert(0, item);
        }
      } else if (type == 'person') {
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
      await _service.toggleFavorite(
        itemId: item.id,
        isFavorite: newIsFavorite,
        serverUrl: auth.embyServerUrl!,
        token: auth.token!,
        userId: auth.user?.id,
      );
    } catch (e) {
      // 4. 失败回滚：恢复到乐观更新前的状态
      final rollbackIds = Set<String>.from(state.favoriteIds);
      final rollbackMovies = List<MediaItem>.from(state.movies);
      final rollbackBoxSets = List<MediaItem>.from(state.boxSets);
      final rollbackPeople = List<MediaItem>.from(state.people);

      if (currentlyFavorite) {
        rollbackIds.add(item.id);
        final type = item.type.toLowerCase();
        if (type == 'boxset') {
          if (!rollbackBoxSets.any((e) => e.id == item.id)) {
            rollbackBoxSets.insert(0, item);
          }
        } else if (type == 'person') {
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
  void reset() {
    _hasLoaded = false;
    _pendingToggles.clear();
    state = const FavoritesState();
  }
}

/// 顶层 Provider：整个 app 共享同一份收藏状态
final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, FavoritesState>((ref) {
  return FavoritesNotifier(ref);
});
