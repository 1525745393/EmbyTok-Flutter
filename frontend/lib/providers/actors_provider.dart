// 演员列表状态管理：加载、搜索、筛选、关注、分页
// - 从 Emby 服务器拉取全量演员，缓存仅用于本会话内的 MemoryCache 加速
// - 搜索防抖（Timer 模式）
// - 关注状态从 Emby FavoritePeople API 拉取
// - 三 Tab（全部/已关注/未关注）共享同一数据源，仅视图过滤

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/embbytok_service.dart';
import '../utils/logger.dart';
import 'auth_provider.dart';
import 'cache_providers.dart';

// ============================================================
// 状态
// ============================================================

class ActorsState {
  final List<Person> actors;
  final bool loading;
  final bool isLoadingMore;
  final String? error;
  final Set<String> favoritedIds;
  final String? selectedPersonType;
  final String searchQuery;
  final List<Person> searchResults;
  final bool isSearching;
  final int total;
  final bool hasLoaded;

  const ActorsState({
    this.actors = const [],
    this.loading = false,
    this.isLoadingMore = false,
    this.error,
    this.favoritedIds = const {},
    this.selectedPersonType,
    this.searchQuery = '',
    this.searchResults = const [],
    this.isSearching = false,
    this.total = 0,
    this.hasLoaded = false,
  });

  ActorsState copyWith({
    List<Person>? actors,
    bool? loading,
    bool? isLoadingMore,
    String? error,
    Set<String>? favoritedIds,
    String? selectedPersonType,
    String? searchQuery,
    List<Person>? searchResults,
    bool? isSearching,
    int? total,
    bool? hasLoaded,
    bool clearError = false,
    bool clearSelectedType = false,
  }) {
    return ActorsState(
      actors: actors ?? this.actors,
      loading: loading ?? this.loading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      favoritedIds: favoritedIds ?? this.favoritedIds,
      selectedPersonType: clearSelectedType ? null : (selectedPersonType ?? this.selectedPersonType),
      searchQuery: searchQuery ?? this.searchQuery,
      searchResults: searchResults ?? this.searchResults,
      isSearching: isSearching ?? this.isSearching,
      total: total ?? this.total,
      hasLoaded: hasLoaded ?? this.hasLoaded,
    );
  }
}

// ============================================================
// Notifier
// ============================================================

class ActorsNotifier extends StateNotifier<ActorsState> {
  final Ref _ref;
  final EmbytokService _service = EmbytokService();
  Timer? _debounceTimer;

  static const int _pageSize = 50;

  bool _isLoadingFavorites = false;

  ActorsNotifier(this._ref) : super(const ActorsState());

  // ---- 加载演员列表 ----

  /// 加载演员列表（始终从 Emby 服务器获取最新数据）
  Future<void> loadActors({bool forceRefresh = false}) async {
    if (state.loading) return;
    if (state.hasLoaded && !forceRefresh) return;

    state = state.copyWith(loading: true, error: null);

    try {
      final auth = _ref.read(authProvider);
      final allActors = await _fetchAllFromServer(auth);

      state = state.copyWith(
        actors: allActors,
        total: allActors.length,
        loading: false,
        hasLoaded: true,
      );

      _loadFavoritesInBackground();
    } catch (e) {
      AppLogger.error('加载演员列表失败', error: e);
      state = state.copyWith(
        loading: false,
        error: state.hasLoaded ? null : '加载演员失败',
      );
    }
  }

  /// 后台异步加载关注状态（不阻塞 UI，仅更新 favoritedIds）
  Future<void> _loadFavoritesInBackground() async {
    if (_isLoadingFavorites) return;
    _isLoadingFavorites = true;
    try {
      await _loadFavorites();
    } finally {
      _isLoadingFavorites = false;
    }
  }

  /// 加载关注列表（仅调用一次，结果存入 favoritedIds）
  ///
  /// 通过缓存仓库获取，避免短时间内重复请求；
  /// toggleFavorite 后会失效缓存，保证数据一致性。
  Future<void> _loadFavorites() async {
    try {
      final auth = _ref.read(authProvider);
      final serverUrl = auth.embyServerUrl;
      final token = auth.token;
      final userId = auth.user?.id;
      if (serverUrl == null || token == null) return;
      final cachedRepo = _ref.read(cachedMediaRepositoryProvider);
      final result = await cachedRepo.getFavoritePeople(
        serverUrl: serverUrl,
        token: token,
        userId: userId,
      );
      // Person.id 可空，过滤掉 null 后再收集
      final ids = result.items.map((e) => e.id).whereType<String>().toSet();
      if (ids.isNotEmpty) {
        state = state.copyWith(favoritedIds: ids);
      }
    } catch (e) {
      AppLogger.error('加载关注列表失败', error: e);
    }
  }

  /// 一次性从服务器分页拉取全部演员
  Future<List<Person>> _fetchAllFromServer(AuthState authState) async {
    final serverUrl = authState.embyServerUrl;
    final token = authState.token;
    if (serverUrl == null || token == null) return [];
    final all = <Person>[];
    int startIndex = 0;
    while (true) {
      final resp = await _service.getPeople(
        limit: _pageSize,
        startIndex: startIndex,
        personTypes: _personTypesParam(),
        serverUrl: serverUrl,
        token: token,
      );
      all.addAll(resp.items);
      if (resp.items.length < _pageSize) break;
      startIndex += _pageSize;
    }
    return all;
  }

  List<String>? _personTypesParam() {
    final t = state.selectedPersonType;
    return (t != null && t.isNotEmpty) ? [t] : null;
  }

  // ---- 搜索 ----

  /// 搜索演员（300ms 防抖）
  ///
  /// 通过缓存仓库获取搜索结果（30s TTL），
  /// 相同搜索词短时间内不重复请求。
  void searchActors(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      final q = query.trim();
      if (q.isEmpty) {
        state = state.copyWith(
          searchQuery: '',
          searchResults: [],
          isSearching: false,
        );
        return;
      }
      state = state.copyWith(searchQuery: q, isSearching: true);
      try {
        final auth = _ref.read(authProvider);
        final serverUrl = auth.embyServerUrl;
        final token = auth.token;
        if (serverUrl == null || token == null) {
          state = state.copyWith(isSearching: false);
          return;
        }
        final cachedRepo = _ref.read(cachedMediaRepositoryProvider);
        final resp = await cachedRepo.getPeople(
          limit: 50,
          startIndex: 0,
          personTypes: _personTypesParam(),
          searchTerm: q,
          serverUrl: serverUrl,
          token: token,
        );
        state = state.copyWith(searchResults: resp.items, isSearching: false);
      } catch (e) {
        AppLogger.error('搜索演员失败', error: e);
        state = state.copyWith(isSearching: false);
      }
    });
  }

  void clearSearch() {
    _debounceTimer?.cancel();
    state = state.copyWith(
      searchQuery: '',
      searchResults: [],
      isSearching: false,
    );
  }

  // ---- 筛选 ----

  void setSelectedType(String? type) {
    state = state.copyWith(
      selectedPersonType: type,
      hasLoaded: false, // 触发重新加载
    );
    loadActors(forceRefresh: true);
  }

  // ---- 关注/取消关注 ----

  Future<void> toggleFavorite(Person actor) async {
    final actorId = actor.id;
    if (actorId == null) return; // 无 ID 的演员无法操作关注状态
    final isFav = state.favoritedIds.contains(actorId);
    final oldIds = Set<String>.from(state.favoritedIds);
    final newIds = Set<String>.from(oldIds);
    if (isFav) {
      newIds.remove(actorId);
    } else {
      newIds.add(actorId);
    }
    // 乐观更新
    state = state.copyWith(favoritedIds: newIds);

    try {
      final auth = _ref.read(authProvider);
      final serverUrl = auth.embyServerUrl;
      final token = auth.token;
      final userId = auth.user?.id;
      if (serverUrl == null || token == null) {
        state = state.copyWith(favoritedIds: oldIds);
        return;
      }
      await _service.toggleFavorite(
        itemId: actorId,
        isFavorite: !isFav,
        serverUrl: serverUrl,
        token: token,
        userId: userId,
      );
      // 失效收藏缓存：invalidateFavorites 现在统一失效影片+合集+人物三类，
      // 确保下次进入收藏页/演员页时拉取最新数据
      try {
        final cacheController = _ref.read(cacheControllerProvider);
        cacheController.invalidateFavorites(serverUrl, token, userId);
      } catch (_) {}
    } catch (e) {
      AppLogger.error('切换关注状态失败', error: e);
      // 失败回滚：恢复乐观更新前的状态
      state = state.copyWith(favoritedIds: oldIds);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

// ============================================================
// Provider
// ============================================================

final actorsProvider = StateNotifierProvider<ActorsNotifier, ActorsState>((ref) {
  return ActorsNotifier(ref);
});