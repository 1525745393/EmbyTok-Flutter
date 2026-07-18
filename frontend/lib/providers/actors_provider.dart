// 演员列表状态管理：加载、搜索、筛选、关注、分页
// - 一次性加载全量演员 + 缓存（SharedPreferences，24h 过期）
// - 搜索防抖（Timer 模式）
// - 关注状态从 Emby FavoritePeople API 拉取
// - 三 Tab（全部/已关注/未关注）共享同一数据源，仅视图过滤

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../services/embbytok_service.dart';
import '../utils/logger.dart';
import 'auth_provider.dart';
import 'cache_providers.dart';

// ============================================================
// 后台 isolate 函数：JSON 批量编解码（避免阻塞 UI 线程）
// ============================================================

/// 在后台 isolate 中批量 JSON 编码演员缓存数据
/// - 输入：可序列化的 List<Map>（主线程已完成 Person → Map 转换）
/// - 输出：List<String>（每条 JSON 字符串）
List<String> _encodeActorsCache(List<Map<String, dynamic>> actorsData) {
  return actorsData.map((a) => jsonEncode(a)).toList();
}

/// 在后台 isolate 中批量 JSON 解码演员缓存数据
/// - 输入：List<String>（SharedPreferences 中读取的 JSON 字符串列表）
/// - 输出：List<Map>（主线程再从 Map 构建 Person 对象）
List<Map<String, dynamic>> _decodeActorsCache(List<String> jsonList) {
  return jsonList
      .map((s) => jsonDecode(s) as Map<String, dynamic>)
      .toList(growable: false);
}

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
  static const int _cacheExpiryHours = 24;
  static const String _cacheKey = 'actors_cache_v2';
  static const String _cacheTimeKey = 'actors_cache_time_v2';

  bool _isLoadingFavorites = false;

  ActorsNotifier(this._ref) : super(const ActorsState());

  // ---- 加载演员列表 ----

  /// 加载演员列表（优先缓存，过期后从服务器拉取）
  Future<void> loadActors({bool forceRefresh = false}) async {
    if (state.loading) return;
    if (state.hasLoaded && !forceRefresh) return; // 防止重复加载

    state = state.copyWith(loading: true, error: null);

    try {
      // 先尝试缓存
      if (!forceRefresh) {
        final cached = await _loadFromCache();
        if (cached != null) {
          state = state.copyWith(
            actors: cached,
            total: cached.length,
            loading: false,
            hasLoaded: true,
          );
          // 异步加载关注状态（不阻塞 UI）
          _loadFavoritesInBackground();
          return;
        }
      }

      // 从服务器一次性加载全量演员
      final auth = _ref.read(authProvider);
      final allActors = await _fetchAllFromServer(auth);
      await _saveToCache(allActors);

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
  Future<void> _loadFavorites() async {
    try {
      final auth = _ref.read(authProvider);
      final serverUrl = auth.embyServerUrl;
      final token = auth.token;
      final userId = auth.user?.id;
      if (serverUrl == null || token == null) return;
      final result = await _service.getFavoritePeople(
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
        final resp = await _service.getPeople(
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
    final newIds = Set<String>.from(state.favoritedIds);
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
      if (serverUrl == null || token == null) return;
      await _service.toggleFavorite(
        itemId: actorId,
        isFavorite: !isFav,
        serverUrl: serverUrl,
        token: token,
        userId: userId,
      );
      // 失效收藏缓存（收藏人物列表已变）
      try {
        _ref.read(cacheControllerProvider).invalidateFavorites(
              serverUrl,
              token,
              userId,
            );
      } catch (_) {}
    } catch (e) {
      AppLogger.error('切换关注状态失败', error: e);
      // 失败回滚
      state = state.copyWith(favoritedIds: state.favoritedIds);
    }
  }

  // ---- 缓存 ----

  Future<void> _saveToCache(List<Person> actors) async {
    try {
      // 主线程：Person → Map（轻量字段访问，不涉及字符串解析）
      final actorsData = actors
          .map((a) => <String, dynamic>{
                'id': a.id,
                'name': a.name,
                'type': a.type,
                'imageUrl': a.imageUrl ?? '',
              })
          .toList(growable: false);
      // 后台 isolate：批量 JSON 编码（避免大量 jsonEncode 阻塞 UI）
      final json = await compute(_encodeActorsCache, actorsData);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_cacheKey, json);
      await prefs.setInt(_cacheTimeKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      AppLogger.error('保存演员缓存失败', error: e);
    }
  }

  Future<List<Person>?> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheTime = prefs.getInt(_cacheTimeKey);
      if (cacheTime == null) return null;
      final age = DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(cacheTime),
      );
      if (age.inHours >= _cacheExpiryHours) return null;
      final jsonList = prefs.getStringList(_cacheKey);
      if (jsonList == null || jsonList.isEmpty) return null;
      // 后台 isolate：批量 JSON 解码（避免大量 jsonDecode 阻塞 UI）
      final decoded = await compute(_decodeActorsCache, jsonList);
      // 主线程：Map → Person（轻量构造）
      return decoded
          .map((map) => Person(
                id: map['id'] as String? ?? '',
                name: map['name'] as String? ?? '',
                type: map['type'] as String? ?? 'Actor',
                imageUrl: (map['imageUrl'] as String?)?.isNotEmpty == true
                    ? map['imageUrl'] as String
                    : null,
              ))
          .toList(growable: false);
    } catch (e) {
      AppLogger.error('读取演员缓存失败', error: e);
      return null;
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