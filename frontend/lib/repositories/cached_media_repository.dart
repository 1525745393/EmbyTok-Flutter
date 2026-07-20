// 缓存媒体仓库装饰器：为 MediaRepository 透明添加内存缓存能力
//
// 装饰器模式：包装一个 MediaRepository，在不改变接口的前提下，
// 为 getLibraryItems、getFavoriteMovies、getResumeItems 等读操作添加缓存。
//
// 缓存特性：
// - 按 serverUrl + token 隔离，避免多账号数据混淆
// - 支持 TTL 过期
// - 支持手动失效（invalidate）和全部清除（clearAll）
// - 写操作（toggleFavorite 等）自动失效相关缓存

import '../models/models.dart';
import '../utils/memory_cache.dart';
import 'media_repository.dart';

import 'dart:async';

/// 带缓存的媒体仓库装饰器
///
/// 使用装饰器模式包装 [MediaRepository]，为只读操作添加内存缓存。
/// 不同账号（token 不同）的数据自动隔离，不会互相污染。
class CachedMediaRepository implements MediaRepository {
  final MediaRepository _inner;
  final Duration _ttl;

  /// 列表类缓存（key: 组合参数的哈希）
  final MemoryCache<PaginatedResponse<MediaItem>> _libraryItemsCache;
  final MemoryCache<FavoritesPageResult> _favoritesCache;
  final MemoryCache<FavoritesPageResult> _boxSetsFavoritesCache;
  final MemoryCache<PaginatedResponse<MediaItem>> _resumeCache;
  final MemoryCache<MediaItem> _itemDetailCache;
  final MemoryCache<List<Library>> _librariesCache;
  final MemoryCache<PaginatedResponse<MediaItem>> _nextUpCache;
  final MemoryCache<List<MediaItem>> _seasonsCache;
  final MemoryCache<PaginatedResponse<MediaItem>> _episodesCache;
  final MemoryCache<List<MediaItem>> _similarItemsCache;
  // 演员相关缓存
  final MemoryCache<PaginatedResponse<Person>> _peopleCache;
  final MemoryCache<MediaItem?> _personDetailCache;
  final MemoryCache<PaginatedResponse<MediaItem>> _personItemsCache;
  final MemoryCache<FavoritesPageResult> _favoritePeopleCache;
  // 推荐/建议/历史/子项缓存
  final MemoryCache<PaginatedResponse<MediaItem>> _recommendationsCache;
  final MemoryCache<List<MediaItem>> _suggestionsCache;
  final MemoryCache<List<MediaItem>> _watchHistoryCache;
  final MemoryCache<List<MediaItem>> _childrenCache;
  // 类型/工作室缓存
  final MemoryCache<List<Library>> _genresCache;
  final MemoryCache<PaginatedResponse<MediaItem>> _genreItemsCache;
  final MemoryCache<List<Library>> _studiosCache;
  final MemoryCache<PaginatedResponse<MediaItem>> _studioItemsCache;

  CachedMediaRepository(
    this._inner, {
    Duration ttl = const Duration(minutes: 5),
    int maxCacheEntries = 50,
  })  : _ttl = ttl,
        _libraryItemsCache = MemoryCache<PaginatedResponse<MediaItem>>(maxSize: maxCacheEntries),
        _favoritesCache = MemoryCache<FavoritesPageResult>(maxSize: 20),
        _boxSetsFavoritesCache = MemoryCache<FavoritesPageResult>(maxSize: 20),
        _resumeCache = MemoryCache<PaginatedResponse<MediaItem>>(maxSize: 20),
        _itemDetailCache = MemoryCache<MediaItem>(maxSize: 100),
        _librariesCache = MemoryCache<List<Library>>(maxSize: 10),
        _nextUpCache = MemoryCache<PaginatedResponse<MediaItem>>(maxSize: 20),
        _seasonsCache = MemoryCache<List<MediaItem>>(maxSize: 50),
        _episodesCache = MemoryCache<PaginatedResponse<MediaItem>>(maxSize: 50),
        _similarItemsCache = MemoryCache<List<MediaItem>>(maxSize: 100),
        _peopleCache = MemoryCache<PaginatedResponse<Person>>(maxSize: 50),
        _personDetailCache = MemoryCache<MediaItem?>(maxSize: 200),
        _personItemsCache = MemoryCache<PaginatedResponse<MediaItem>>(maxSize: 50),
        _favoritePeopleCache = MemoryCache<FavoritesPageResult>(maxSize: 20),
        _recommendationsCache = MemoryCache<PaginatedResponse<MediaItem>>(maxSize: 50),
        _suggestionsCache = MemoryCache<List<MediaItem>>(maxSize: 20),
        _watchHistoryCache = MemoryCache<List<MediaItem>>(maxSize: 20),
        _childrenCache = MemoryCache<List<MediaItem>>(maxSize: 100),
        _genresCache = MemoryCache<List<Library>>(maxSize: 10),
        _genreItemsCache = MemoryCache<PaginatedResponse<MediaItem>>(maxSize: 50),
        _studiosCache = MemoryCache<List<Library>>(maxSize: 10),
        _studioItemsCache = MemoryCache<PaginatedResponse<MediaItem>>(maxSize: 50);

  /// 正在后台刷新的 key 集合，防止并发重复刷新
  final Set<String> _pendingRefreshes = {};

  // ============================
  // 统计信息
  // ============================

  /// 聚合统计信息（所有缓存的统计总和）
  CacheStats get stats {
    return CacheStats(
      hitCount: _sum((c) => c.stats.hitCount),
      missCount: _sum((c) => c.stats.missCount),
      staleHitCount: _sum((c) => c.stats.staleHitCount),
      evictionCount: _sum((c) => c.stats.evictionCount),
      swrRefreshCount: _sum((c) => c.stats.swrRefreshCount),
    );
  }

  /// 重置所有缓存的统计数据
  void resetStats() {
    _libraryItemsCache.resetStats();
    _favoritesCache.resetStats();
    _boxSetsFavoritesCache.resetStats();
    _resumeCache.resetStats();
    _itemDetailCache.resetStats();
    _librariesCache.resetStats();
    _nextUpCache.resetStats();
    _seasonsCache.resetStats();
    _episodesCache.resetStats();
    _similarItemsCache.resetStats();
    _peopleCache.resetStats();
    _personDetailCache.resetStats();
    _personItemsCache.resetStats();
    _favoritePeopleCache.resetStats();
    _recommendationsCache.resetStats();
    _suggestionsCache.resetStats();
    _watchHistoryCache.resetStats();
    _childrenCache.resetStats();
    _genresCache.resetStats();
    _genreItemsCache.resetStats();
    _studiosCache.resetStats();
    _studioItemsCache.resetStats();
  }

  /// 辅助：对所有缓存执行统计求和
  int _sum(int Function(MemoryCache) selector) {
    return selector(_libraryItemsCache) +
        selector(_favoritesCache) +
        selector(_boxSetsFavoritesCache) +
        selector(_resumeCache) +
        selector(_itemDetailCache) +
        selector(_librariesCache) +
        selector(_nextUpCache) +
        selector(_seasonsCache) +
        selector(_episodesCache) +
        selector(_similarItemsCache) +
        selector(_peopleCache) +
        selector(_personDetailCache) +
        selector(_personItemsCache) +
        selector(_favoritePeopleCache) +
        selector(_recommendationsCache) +
        selector(_suggestionsCache) +
        selector(_watchHistoryCache) +
        selector(_childrenCache) +
        selector(_genresCache) +
        selector(_genreItemsCache) +
        selector(_studiosCache) +
        selector(_studioItemsCache);
  }

  // ============================
  // 缓存键生成
  // ============================

  /// 生成 getLibraryItems 的缓存键
  String _libraryItemsKey(
    MediaQueryParams params,
    String serverUrl,
    String token,
  ) {
    return 'lib:$serverUrl:$token:${params.libraryId}:${params.limit}:${params.offset}:'
        '${params.sortBy ?? ''}:${params.sortOrder ?? ''}:${params.searchTerm ?? ''}:'
        '${params.excludePlayed}';
  }

  /// 生成 getFavoriteMovies 的缓存键（含分页参数）
  String _favoritesKey(String serverUrl, String token, String? userId, int limit, int offset) {
    return 'fav:$serverUrl:$token:${userId ?? ''}:$limit:$offset';
  }

  /// 生成 getFavoriteBoxSets 的缓存键（含分页参数）
  String _boxSetsFavoritesKey(String serverUrl, String token, String? userId, int limit, int offset) {
    return 'fav_boxsets:$serverUrl:$token:${userId ?? ''}:$limit:$offset';
  }

  /// 生成 getResumeItems 的缓存键
  String _resumeKey(String serverUrl, String token, int limit, int offset) {
    return 'resume:$serverUrl:$token:$limit:$offset';
  }

  /// 生成 getItemDetail 的缓存键
  String _itemDetailKey(String itemId, String serverUrl, String token) {
    return 'detail:$serverUrl:$token:$itemId';
  }

  /// 生成 getLibraries 的缓存键
  String _librariesKey(String serverUrl, String token, String? userId) {
    return 'libs:$serverUrl:$token:${userId ?? ''}';
  }

  /// 生成 getNextUp 的缓存键
  String _nextUpKey(String serverUrl, String token, int limit, String? seriesId) {
    return 'nextup:$serverUrl:$token:$limit:${seriesId ?? ''}';
  }

  /// 生成 getSeasons 的缓存键
  String _seasonsKey(String seriesId, String serverUrl, String token) {
    return 'seasons:$serverUrl:$token:$seriesId';
  }

  /// 生成 getEpisodes 的缓存键
  String _episodesKey(String seriesId, String? seasonId, int limit, int offset, String serverUrl, String token) {
    return 'episodes:$serverUrl:$token:$seriesId:${seasonId ?? ''}:$limit:$offset';
  }

  /// 生成 getSimilarItems 的缓存键
  String _similarItemsKey(String itemId, int limit, String serverUrl, String token) {
    return 'similar:$serverUrl:$token:$itemId:$limit';
  }

  /// 生成 getPeople 的缓存键
  ///
  /// searchTerm 为空时表示列表浏览，使用中 TTL；
  /// 非空时表示搜索，使用短 TTL（由调用方控制 ttl 参数）。
  String _peopleKey(
    int limit,
    int startIndex,
    List<String>? personTypes,
    String? searchTerm,
    String serverUrl,
    String token,
  ) {
    return 'people:$serverUrl:$token:$limit:$startIndex:'
        '${personTypes != null ? personTypes.join(',') : ''}:'
        '${searchTerm ?? ''}';
  }

  /// 生成 getPersonDetail 的缓存键
  String _personDetailKey(String personId, String serverUrl, String token) {
    return 'person:$serverUrl:$token:$personId';
  }

  /// 生成 getPersonItems 的缓存键
  String _personItemsKey(
    String personId,
    int limit,
    int offset,
    String serverUrl,
    String token,
  ) {
    return 'person_items:$serverUrl:$token:$personId:$limit:$offset';
  }

  /// 生成 getFavoritePeople 的缓存键（含分页参数）
  String _favoritePeopleKey(String serverUrl, String token, String? userId, int limit, int offset) {
    return 'fav_people:$serverUrl:$token:${userId ?? ''}:$limit:$offset';
  }

  /// 生成 getRecommendations 的缓存键
  ///
  /// 包含 libraryId/minCommunityRating/excludePlayed/includeItemTypes，
  /// 因为相同 limit/offset 但不同过滤条件的结果不同。
  String _recommendationsKey(
    int limit,
    int offset,
    String? libraryId,
    String? userId,
    String serverUrl,
    String token,
    double minCommunityRating,
    bool excludePlayed,
    Set<String>? includeItemTypes,
  ) {
    final typesStr = includeItemTypes != null
        ? (includeItemTypes.toList()..sort()).join(',')
        : '';
    return 'rec:$serverUrl:$token:${userId ?? ''}:${libraryId ?? ''}:'
        '$limit:$offset:$minCommunityRating:$excludePlayed:$typesStr';
  }

  /// 生成 getSuggestions 的缓存键
  String _suggestionsKey(int limit, String? userId, String serverUrl, String token) {
    return 'sugg:$serverUrl:$token:${userId ?? ''}:$limit';
  }

  /// 生成 getWatchHistory 的缓存键
  String _watchHistoryKey(int limit, String? userId, String serverUrl, String token) {
    return 'history:$serverUrl:$token:${userId ?? ''}:$limit';
  }

  /// 生成 getChildren 的缓存键
  String _childrenKey(
    String parentId,
    int limit,
    int offset,
    String serverUrl,
    String token,
  ) {
    return 'children:$serverUrl:$token:$parentId:$limit:$offset';
  }

  /// 生成 getGenres 的缓存键
  String _genresKey(int limit, String serverUrl, String token) {
    return 'genres:$serverUrl:$token:$limit';
  }

  /// 生成 getItemsByGenre 的缓存键
  String _genreItemsKey(String genre, int limit, int offset, String serverUrl, String token) {
    return 'genre_items:$serverUrl:$token:$genre:$limit:$offset';
  }

  /// 生成 getStudios 的缓存键
  String _studiosKey(int limit, String serverUrl, String token) {
    return 'studios:$serverUrl:$token:$limit';
  }

  /// 生成 getItemsByStudio 的缓存键
  String _studioItemsKey(String studio, int limit, int offset, String serverUrl, String token) {
    return 'studio_items:$serverUrl:$token:$studio:$limit:$offset';
  }

  // ============================
  // SWR (Stale-While-Revalidate) 核心辅助
  // ============================

  /// 带缓存的数据获取（SWR 模式）
  ///
  /// 三级路径：
  /// 1. 新鲜命中 → 直接返回
  /// 2. 过期命中 → 返回过期数据 + 后台异步刷新
  /// 3. 完全未命中 → 同步等待获取
  Future<T> _withCache<T>(
    MemoryCache<T> cache,
    String key,
    Future<T> Function() fetcher, {
    Duration? ttl,
  }) async {
    final staleValue = cache.getStale(key);
    if (staleValue != null) {
      if (!cache.isExpired(key)) {
        return staleValue;
      }
      // 过期命中：返回旧数据 + 后台刷新
      _refreshInBackground(cache, key, fetcher, ttl: ttl);
      return staleValue;
    }
    // 未命中：同步获取
    final result = await fetcher();
    cache.set(key, result, ttl: ttl ?? _ttl);
    return result;
  }

  /// 后台异步刷新（防重复）
  void _refreshInBackground<T>(
    MemoryCache<T> cache,
    String key,
    Future<T> Function() fetcher, {
    Duration? ttl,
  }) {
    if (_pendingRefreshes.contains(key)) return;
    _pendingRefreshes.add(key);
    unawaited(fetcher().then((result) {
      cache.set(key, result, ttl: ttl ?? _ttl);
      cache.recordSwrRefresh();
    }).whenComplete(() {
      _pendingRefreshes.remove(key);
    }));
  }

  // ============================
  // 读操作（带缓存）
  // ============================

  @override
  Future<MediaItem> getItemDetail(
    String itemId, {
    required String serverUrl,
    required String token,
    String? userId,
  }) {
    final key = _itemDetailKey(itemId, serverUrl, token);
    return _withCache(_itemDetailCache, key, () => _inner.getItemDetail(
      itemId,
      serverUrl: serverUrl,
      token: token,
      userId: userId,
    ));
  }

  @override
  Future<PaginatedResponse<MediaItem>> getLibraryItems(
    MediaQueryParams params, {
    required String serverUrl,
    required String token,
    String? userId,
  }) {
    final key = _libraryItemsKey(params, serverUrl, token);
    return _withCache(_libraryItemsCache, key, () => _inner.getLibraryItems(
      params,
      serverUrl: serverUrl,
      token: token,
      userId: userId,
    ));
  }

  @override
  PaginatedResponse<MediaItem>? peekLibraryItems(
    MediaQueryParams params, {
    required String serverUrl,
    required String token,
    String? userId,
  }) {
    final key = _libraryItemsKey(params, serverUrl, token);
    return _libraryItemsCache.get(key);
  }

  @override
  Future<FavoritesPageResult> getFavoriteMovies({
    int limit = 50,
    int offset = 0,
    required String serverUrl,
    required String token,
    String? userId,
  }) {
    final key = _favoritesKey(serverUrl, token, userId, limit, offset);
    return _withCache(_favoritesCache, key, () => _inner.getFavoriteMovies(
      limit: limit,
      offset: offset,
      serverUrl: serverUrl,
      token: token,
      userId: userId,
    ));
  }

  @override
  FavoritesPageResult? peekFavoriteMovies({
    int limit = 50,
    int offset = 0,
    required String serverUrl,
    required String token,
    String? userId,
  }) {
    final key = _favoritesKey(serverUrl, token, userId, limit, offset);
    return _favoritesCache.get(key);
  }

  @override
  Future<FavoritesPageResult> getFavoriteBoxSets({
    int limit = 50,
    int offset = 0,
    required String serverUrl,
    required String token,
    String? userId,
  }) {
    final key = _boxSetsFavoritesKey(serverUrl, token, userId, limit, offset);
    return _withCache(_boxSetsFavoritesCache, key, () => _inner.getFavoriteBoxSets(
      limit: limit,
      offset: offset,
      serverUrl: serverUrl,
      token: token,
      userId: userId,
    ));
  }

  @override
  FavoritesPageResult? peekFavoriteBoxSets({
    int limit = 50,
    int offset = 0,
    required String serverUrl,
    required String token,
    String? userId,
  }) {
    final key = _boxSetsFavoritesKey(serverUrl, token, userId, limit, offset);
    return _boxSetsFavoritesCache.get(key);
  }

  @override
  Future<PaginatedResponse<MediaItem>> getResumeItems({
    required String serverUrl,
    required String token,
    int limit = 50,
    int offset = 0,
  }) {
    final key = _resumeKey(serverUrl, token, limit, offset);
    return _withCache(_resumeCache, key, () => _inner.getResumeItems(
      serverUrl: serverUrl,
      token: token,
      limit: limit,
      offset: offset,
    ));
  }

  @override
  Future<List<Library>> getLibraries({
    required String serverUrl,
    required String token,
    String? userId,
  }) {
    final key = _librariesKey(serverUrl, token, userId);
    return _withCache(_librariesCache, key, () => _inner.getLibraries(
      serverUrl: serverUrl,
      token: token,
      userId: userId,
    ), ttl: const Duration(minutes: 30));
  }

  @override
  Future<PaginatedResponse<MediaItem>> getNextUp({
    required String serverUrl,
    required String token,
    int limit = 20,
    String? seriesId,
  }) {
    final key = _nextUpKey(serverUrl, token, limit, seriesId);
    return _withCache(_nextUpCache, key, () => _inner.getNextUp(
      serverUrl: serverUrl,
      token: token,
      limit: limit,
      seriesId: seriesId,
    ), ttl: const Duration(minutes: 1));
  }
  }

  @override
  Future<List<MediaItem>> getSeasons(
    String seriesId, {
    required String serverUrl,
    required String token,
  }) {
    final key = _seasonsKey(seriesId, serverUrl, token);
    return _withCache(_seasonsCache, key, () => _inner.getSeasons(
      seriesId,
      serverUrl: serverUrl,
      token: token,
    ));
  }

  @override
  Future<PaginatedResponse<MediaItem>> getEpisodes(
    String seriesId, {
    String? seasonId,
    int limit = 100,
    int offset = 0,
    required String serverUrl,
    required String token,
  }) {
    final key = _episodesKey(seriesId, seasonId, limit, offset, serverUrl, token);
    return _withCache(_episodesCache, key, () => _inner.getEpisodes(
      seriesId,
      seasonId: seasonId,
      limit: limit,
      offset: offset,
      serverUrl: serverUrl,
      token: token,
    ));
  }

  @override
  Future<List<MediaItem>> getSimilarItems(
    String itemId, {
    int limit = 12,
    required String serverUrl,
    required String token,
  }) {
    final key = _similarItemsKey(itemId, limit, serverUrl, token);
    return _withCache(_similarItemsCache, key, () => _inner.getSimilarItems(
      itemId,
      limit: limit,
      serverUrl: serverUrl,
      token: token,
    ));
  }

  @override
  Future<PaginatedResponse<Person>> getPeople({
    int limit = 50,
    int startIndex = 0,
    List<String>? personTypes,
    String? searchTerm,
    required String serverUrl,
    required String token,
  }) {
    final key = _peopleKey(limit, startIndex, personTypes, searchTerm, serverUrl, token);
    final ttl = (searchTerm != null && searchTerm.isNotEmpty)
        ? const Duration(seconds: 30)
        : _ttl;
    return _withCache(_peopleCache, key, () => _inner.getPeople(
      limit: limit,
      startIndex: startIndex,
      personTypes: personTypes,
      searchTerm: searchTerm,
      serverUrl: serverUrl,
      token: token,
    ), ttl: ttl);
  }

  @override
  Future<MediaItem?> getPersonDetail(
    String personId, {
    required String serverUrl,
    required String token,
    String? userId,
  }) {
    final key = _personDetailKey(personId, serverUrl, token);
    return _withCache(_personDetailCache, key, () => _inner.getPersonDetail(
      personId,
      serverUrl: serverUrl,
      token: token,
      userId: userId,
    ), ttl: const Duration(minutes: 30));
  }

  @override
  Future<PaginatedResponse<MediaItem>> getPersonItems(
    String personId, {
    int limit = 30,
    int offset = 0,
    required String serverUrl,
    required String token,
  }) {
    final key = _personItemsKey(personId, limit, offset, serverUrl, token);
    return _withCache(_personItemsCache, key, () => _inner.getPersonItems(
      personId,
      limit: limit,
      offset: offset,
      serverUrl: serverUrl,
      token: token,
    ));
  }

  @override
  Future<FavoritesPageResult> getFavoritePeople({
    int limit = 50,
    int offset = 0,
    required String serverUrl,
    required String token,
    String? userId,
  }) {
    final key = _favoritePeopleKey(serverUrl, token, userId, limit, offset);
    return _withCache(_favoritePeopleCache, key, () => _inner.getFavoritePeople(
      limit: limit,
      offset: offset,
      serverUrl: serverUrl,
      token: token,
      userId: userId,
    ));
  }

  @override
  FavoritesPageResult? peekFavoritePeople({
    int limit = 50,
    int offset = 0,
    required String serverUrl,
    required String token,
    String? userId,
  }) {
    final key = _favoritePeopleKey(serverUrl, token, userId, limit, offset);
    return _favoritePeopleCache.get(key);
  }

  @override
  Future<PaginatedResponse<MediaItem>> getRecommendations({
    int limit = 20,
    int offset = 0,
    String? libraryId,
    String? userId,
    required String serverUrl,
    required String token,
    double minCommunityRating = 4.0,
    bool excludePlayed = true,
    Set<String>? includeItemTypes,
  }) {
    final key = _recommendationsKey(
      limit, offset, libraryId, userId, serverUrl, token,
      minCommunityRating, excludePlayed, includeItemTypes,
    );
    return _withCache(_recommendationsCache, key, () => _inner.getRecommendations(
      limit: limit,
      offset: offset,
      libraryId: libraryId,
      userId: userId,
      serverUrl: serverUrl,
      token: token,
      minCommunityRating: minCommunityRating,
      excludePlayed: excludePlayed,
      includeItemTypes: includeItemTypes,
    ));
  }

  @override
  Future<List<MediaItem>> getSuggestions({
    int limit = 20,
    String? userId,
    required String serverUrl,
    required String token,
  }) {
    final key = _suggestionsKey(limit, userId, serverUrl, token);
    return _withCache(_suggestionsCache, key, () => _inner.getSuggestions(
      limit: limit,
      userId: userId,
      serverUrl: serverUrl,
      token: token,
    ));
  }

  @override
  Future<List<MediaItem>> getWatchHistory({
    int limit = 50,
    String? userId,
    required String serverUrl,
    required String token,
  }) {
    final key = _watchHistoryKey(limit, userId, serverUrl, token);
    return _withCache(_watchHistoryCache, key, () => _inner.getWatchHistory(
      limit: limit,
      userId: userId,
      serverUrl: serverUrl,
      token: token,
    ), ttl: const Duration(minutes: 1));
  }

  @override
  Future<List<MediaItem>> getChildren(
    String parentId, {
    int limit = 100,
    int offset = 0,
    required String serverUrl,
    required String token,
  }) {
    final key = _childrenKey(parentId, limit, offset, serverUrl, token);
    return _withCache(_childrenCache, key, () => _inner.getChildren(
      parentId,
      limit: limit,
      offset: offset,
      serverUrl: serverUrl,
      token: token,
    ));
  }

  @override
  Future<List<Library>> getGenres({
    int limit = 100,
    required String serverUrl,
    required String token,
  }) {
    final key = _genresKey(limit, serverUrl, token);
    return _withCache(_genresCache, key, () => _inner.getGenres(
      limit: limit,
      serverUrl: serverUrl,
      token: token,
    ), ttl: const Duration(minutes: 30));
  }

  @override
  Future<PaginatedResponse<MediaItem>> getItemsByGenre(
    String genre, {
    int limit = 30,
    int offset = 0,
    required String serverUrl,
    required String token,
  }) {
    final key = _genreItemsKey(genre, limit, offset, serverUrl, token);
    return _withCache(_genreItemsCache, key, () => _inner.getItemsByGenre(
      genre,
      limit: limit,
      offset: offset,
      serverUrl: serverUrl,
      token: token,
    ));
  }

  @override
  Future<List<Library>> getStudios({
    int limit = 100,
    required String serverUrl,
    required String token,
  }) {
    final key = _studiosKey(limit, serverUrl, token);
    return _withCache(_studiosCache, key, () => _inner.getStudios(
      limit: limit,
      serverUrl: serverUrl,
      token: token,
    ), ttl: const Duration(minutes: 30));
  }

  @override
  Future<PaginatedResponse<MediaItem>> getItemsByStudio(
    String studio, {
    int limit = 30,
    int offset = 0,
    required String serverUrl,
    required String token,
  }) {
    final key = _studioItemsKey(studio, limit, offset, serverUrl, token);
    return _withCache(_studioItemsCache, key, () => _inner.getItemsByStudio(
      studio,
      limit: limit,
      offset: offset,
      serverUrl: serverUrl,
      token: token,
    ));
  }

  // ============================
  // 缓存失效操作
  // ============================

  /// 失效指定媒体库的列表缓存
  ///
  /// 当媒体库内容可能变化时（如标记已观看、收藏切换等）调用。
  /// 会清除该 serverUrl 下所有媒体库的列表缓存（前缀匹配）。
  void invalidateLibraryItems({
    required String libraryId,
    required String serverUrl,
  }) {
    _libraryItemsCache.deleteWherePrefix('lib:$serverUrl:');
  }

  /// 失效收藏缓存（影片 + 合集 + 人物）
  ///
  /// toggleFavorite 后调用，同时失效影片、合集、人物三类收藏缓存，
  /// 因为 Emby 的 IsFavorite 过滤是统一的，切换任一项的收藏状态都可能影响任一栏。
  void invalidateFavorites({
    required String serverUrl,
    required String token,
    String? userId,
  }) {
    // 影片：按前缀删除所有分页
    _favoritesCache.deleteWherePrefix('fav:$serverUrl:$token:${userId ?? ''}:');
    // 合集：按前缀删除所有分页
    _boxSetsFavoritesCache.deleteWherePrefix('fav_boxsets:$serverUrl:$token:${userId ?? ''}:');
    // 人物：按前缀删除所有分页
    _favoritePeopleCache.deleteWherePrefix('fav_people:$serverUrl:$token:${userId ?? ''}:');
  }

  /// 失效续播列表缓存
  void invalidateResume({
    required String serverUrl,
    required String token,
  }) {
    _resumeCache.clear();
  }

  /// 失效单个媒体条目的详情缓存
  ///
  /// 当条目的 UserData 可能变化时（如 toggleFavorite、markAsPlayed、
  /// reportPlaybackStopped 等）调用。
  void invalidateItemDetail({
    required String itemId,
    required String serverUrl,
  }) {
    _itemDetailCache.deleteWherePrefix('detail:$serverUrl:');
  }

  /// 失效 NextUp 缓存
  ///
  /// 标记已观看后调用，因为 NextUp 列表会变化。
  void invalidateNextUp({required String serverUrl}) {
    _nextUpCache.deleteWherePrefix('nextup:$serverUrl:');
  }

  /// 失效剧集相关缓存（季 + 集）
  ///
  /// 当剧集结构变化时调用。
  void invalidateSeries({
    required String seriesId,
    required String serverUrl,
  }) {
    _seasonsCache.deleteWherePrefix('seasons:$serverUrl:');
    _episodesCache.deleteWherePrefix('episodes:$serverUrl:');
  }

  /// 失效演员作品列表缓存
  ///
  /// 当用户标记作品已看/未看时调用，因为该演员的作品观看状态会变。
  /// 会清除该 serverUrl 下所有演员的作品列表缓存（前缀匹配）。
  void invalidatePersonItems({required String serverUrl}) {
    _personItemsCache.deleteWherePrefix('person_items:$serverUrl:');
  }

  /// 失效观看历史缓存
  ///
  /// 标记已看/取消已看、播放进度上报后调用，避免显示旧历史。
  /// 会清除该 serverUrl 下所有用户的观看历史缓存（前缀匹配）。
  void invalidateWatchHistory({required String serverUrl}) {
    _watchHistoryCache.deleteWherePrefix('history:$serverUrl:');
  }

  /// 失效子项列表缓存
  ///
  /// 当父项（如 BoxSet）的子项结构变化时调用。
  /// 会清除该 serverUrl 下所有父项的子项缓存（前缀匹配）。
  void invalidateChildren({required String serverUrl}) {
    _childrenCache.deleteWherePrefix('children:$serverUrl:');
  }

  /// 失效类型（Genre）列表缓存
  ///
  /// 类型列表极少变化，通常不需要主动失效，
  /// 仅在类型元数据被修改时调用。
  void invalidateGenres({required String serverUrl}) {
    _genresCache.deleteWherePrefix('genres:$serverUrl:');
  }

  /// 失效某类型下的影片缓存
  ///
  /// 当某类型下的影片可能变化时调用（如标记已看、收藏切换等）。
  void invalidateGenreItems({required String serverUrl}) {
    _genreItemsCache.deleteWherePrefix('genre_items:$serverUrl:');
  }

  /// 失效工作室（Studio）列表缓存
  void invalidateStudios({required String serverUrl}) {
    _studiosCache.deleteWherePrefix('studios:$serverUrl:');
  }

  /// 失效某工作室下的影片缓存
  void invalidateStudioItems({required String serverUrl}) {
    _studioItemsCache.deleteWherePrefix('studio_items:$serverUrl:');
  }

  /// 清除所有缓存
  void clearAll() {
    _pendingRefreshes.clear();
    _libraryItemsCache.clear();
    _favoritesCache.clear();
    _boxSetsFavoritesCache.clear();
    _resumeCache.clear();
    _itemDetailCache.clear();
    _librariesCache.clear();
    _nextUpCache.clear();
    _seasonsCache.clear();
    _episodesCache.clear();
    _similarItemsCache.clear();
    _peopleCache.clear();
    _personDetailCache.clear();
    _personItemsCache.clear();
    _favoritePeopleCache.clear();
    _recommendationsCache.clear();
    _suggestionsCache.clear();
    _watchHistoryCache.clear();
    _childrenCache.clear();
    _genresCache.clear();
    _genreItemsCache.clear();
    _studiosCache.clear();
    _studioItemsCache.clear();
  }
}
