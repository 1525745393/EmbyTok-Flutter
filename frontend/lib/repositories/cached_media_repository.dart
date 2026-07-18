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

  CachedMediaRepository(
    this._inner, {
    Duration ttl = const Duration(minutes: 5),
    int maxCacheEntries = 50,
  })  : _ttl = ttl,
        _libraryItemsCache = MemoryCache<PaginatedResponse<MediaItem>>(maxSize: maxCacheEntries),
        _favoritesCache = MemoryCache<FavoritesPageResult>(maxSize: 20),
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
        _favoritePeopleCache = MemoryCache<FavoritesPageResult>(maxSize: 20);

  // ============================
  // 统计信息
  // ============================

  /// 聚合统计信息（所有缓存的统计总和）
  CacheStats get stats {
    return CacheStats(
      hitCount: _sum((c) => c.stats.hitCount),
      missCount: _sum((c) => c.stats.missCount),
      evictionCount: _sum((c) => c.stats.evictionCount),
    );
  }

  /// 重置所有缓存的统计数据
  void resetStats() {
    _libraryItemsCache.resetStats();
    _favoritesCache.resetStats();
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
  }

  /// 辅助：对所有缓存执行统计求和
  int _sum(int Function(MemoryCache) selector) {
    return selector(_libraryItemsCache) +
        selector(_favoritesCache) +
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
        selector(_favoritePeopleCache);
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

  /// 生成 getFavoriteMovies 的缓存键
  String _favoritesKey(String serverUrl, String token, String? userId) {
    return 'fav:$serverUrl:$token:${userId ?? ''}';
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

  /// 生成 getFavoritePeople 的缓存键
  String _favoritePeopleKey(String serverUrl, String token, String? userId) {
    return 'fav_people:$serverUrl:$token:${userId ?? ''}';
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
  }) async {
    final key = _itemDetailKey(itemId, serverUrl, token);
    final cached = _itemDetailCache.get(key);
    if (cached != null) {
      return cached;
    }

    final result = await _inner.getItemDetail(
      itemId,
      serverUrl: serverUrl,
      token: token,
      userId: userId,
    );

    _itemDetailCache.set(key, result, ttl: _ttl);
    return result;
  }

  @override
  Future<PaginatedResponse<MediaItem>> getLibraryItems(
    MediaQueryParams params, {
    required String serverUrl,
    required String token,
    String? userId,
  }) async {
    final key = _libraryItemsKey(params, serverUrl, token);
    final cached = _libraryItemsCache.get(key);
    if (cached != null) {
      return cached;
    }

    final result = await _inner.getLibraryItems(
      params,
      serverUrl: serverUrl,
      token: token,
      userId: userId,
    );

    _libraryItemsCache.set(key, result, ttl: _ttl);
    return result;
  }

  @override
  Future<FavoritesPageResult> getFavoriteMovies({
    required String serverUrl,
    required String token,
    String? userId,
  }) async {
    final key = _favoritesKey(serverUrl, token, userId);
    final cached = _favoritesCache.get(key);
    if (cached != null) {
      return cached;
    }

    final result = await _inner.getFavoriteMovies(
      serverUrl: serverUrl,
      token: token,
      userId: userId,
    );

    _favoritesCache.set(key, result, ttl: _ttl);
    return result;
  }

  @override
  Future<PaginatedResponse<MediaItem>> getResumeItems({
    required String serverUrl,
    required String token,
    int limit = 50,
    int offset = 0,
  }) async {
    final key = _resumeKey(serverUrl, token, limit, offset);
    final cached = _resumeCache.get(key);
    if (cached != null) {
      return cached;
    }

    final result = await _inner.getResumeItems(
      serverUrl: serverUrl,
      token: token,
      limit: limit,
      offset: offset,
    );

    _resumeCache.set(key, result, ttl: _ttl);
    return result;
  }

  @override
  Future<List<Library>> getLibraries({
    required String serverUrl,
    required String token,
    String? userId,
  }) async {
    final key = _librariesKey(serverUrl, token, userId);
    final cached = _librariesCache.get(key);
    if (cached != null) {
      return cached;
    }

    final result = await _inner.getLibraries(
      serverUrl: serverUrl,
      token: token,
      userId: userId,
    );

    // 媒体库列表极少变更，使用更长的 TTL
    _librariesCache.set(key, result, ttl: const Duration(minutes: 30));
    return result;
  }

  @override
  Future<PaginatedResponse<MediaItem>> getNextUp({
    required String serverUrl,
    required String token,
    int limit = 20,
    String? seriesId,
  }) async {
    final key = _nextUpKey(serverUrl, token, limit, seriesId);
    final cached = _nextUpCache.get(key);
    if (cached != null) {
      return cached;
    }

    final result = await _inner.getNextUp(
      serverUrl: serverUrl,
      token: token,
      limit: limit,
      seriesId: seriesId,
    );

    // NextUp 看完一集就变，使用短 TTL
    _nextUpCache.set(key, result, ttl: const Duration(minutes: 1));
    return result;
  }

  @override
  Future<List<MediaItem>> getSeasons(
    String seriesId, {
    required String serverUrl,
    required String token,
  }) async {
    final key = _seasonsKey(seriesId, serverUrl, token);
    final cached = _seasonsCache.get(key);
    if (cached != null) {
      return cached;
    }

    final result = await _inner.getSeasons(
      seriesId,
      serverUrl: serverUrl,
      token: token,
    );

    // 季列表很少变化，使用中等 TTL
    _seasonsCache.set(key, result, ttl: _ttl);
    return result;
  }

  @override
  Future<PaginatedResponse<MediaItem>> getEpisodes(
    String seriesId, {
    String? seasonId,
    int limit = 100,
    int offset = 0,
    required String serverUrl,
    required String token,
  }) async {
    final key = _episodesKey(seriesId, seasonId, limit, offset, serverUrl, token);
    final cached = _episodesCache.get(key);
    if (cached != null) {
      return cached;
    }

    final result = await _inner.getEpisodes(
      seriesId,
      seasonId: seasonId,
      limit: limit,
      offset: offset,
      serverUrl: serverUrl,
      token: token,
    );

    // 集列表很少变化，使用中等 TTL
    _episodesCache.set(key, result, ttl: _ttl);
    return result;
  }

  @override
  Future<List<MediaItem>> getSimilarItems(
    String itemId, {
    int limit = 12,
    required String serverUrl,
    required String token,
  }) async {
    final key = _similarItemsKey(itemId, limit, serverUrl, token);
    final cached = _similarItemsCache.get(key);
    if (cached != null) {
      return cached;
    }

    final result = await _inner.getSimilarItems(
      itemId,
      limit: limit,
      serverUrl: serverUrl,
      token: token,
    );

    // 相似推荐短时间内稳定，使用中等 TTL
    _similarItemsCache.set(key, result, ttl: _ttl);
    return result;
  }

  @override
  Future<PaginatedResponse<Person>> getPeople({
    int limit = 50,
    int startIndex = 0,
    List<String>? personTypes,
    String? searchTerm,
    required String serverUrl,
    required String token,
  }) async {
    final key = _peopleKey(limit, startIndex, personTypes, searchTerm, serverUrl, token);
    final cached = _peopleCache.get(key);
    if (cached != null) {
      return cached;
    }

    final result = await _inner.getPeople(
      limit: limit,
      startIndex: startIndex,
      personTypes: personTypes,
      searchTerm: searchTerm,
      serverUrl: serverUrl,
      token: token,
    );

    // 搜索场景使用短 TTL，避免新演员上架后看不到；
    // 列表浏览场景使用中 TTL（演员列表变化不频繁）
    final ttl = (searchTerm != null && searchTerm.isNotEmpty)
        ? const Duration(seconds: 30)
        : _ttl;
    _peopleCache.set(key, result, ttl: ttl);
    return result;
  }

  @override
  Future<MediaItem?> getPersonDetail(
    String personId, {
    required String serverUrl,
    required String token,
    String? userId,
  }) async {
    final key = _personDetailKey(personId, serverUrl, token);
    final cached = _personDetailCache.get(key);
    if (cached != null) {
      return cached;
    }

    final result = await _inner.getPersonDetail(
      personId,
      serverUrl: serverUrl,
      token: token,
      userId: userId,
    );

    // 演员详情极少变化，使用长 TTL
    _personDetailCache.set(key, result, ttl: const Duration(minutes: 30));
    return result;
  }

  @override
  Future<PaginatedResponse<MediaItem>> getPersonItems(
    String personId, {
    int limit = 30,
    int offset = 0,
    required String serverUrl,
    required String token,
  }) async {
    final key = _personItemsKey(personId, limit, offset, serverUrl, token);
    final cached = _personItemsCache.get(key);
    if (cached != null) {
      return cached;
    }

    final result = await _inner.getPersonItems(
      personId,
      limit: limit,
      offset: offset,
      serverUrl: serverUrl,
      token: token,
    );

    // 演员作品列表使用中 TTL，标记已看后会失效
    _personItemsCache.set(key, result, ttl: _ttl);
    return result;
  }

  @override
  Future<FavoritesPageResult> getFavoritePeople({
    required String serverUrl,
    required String token,
    String? userId,
  }) async {
    final key = _favoritePeopleKey(serverUrl, token, userId);
    final cached = _favoritePeopleCache.get(key);
    if (cached != null) {
      return cached;
    }

    final result = await _inner.getFavoritePeople(
      serverUrl: serverUrl,
      token: token,
      userId: userId,
    );

    // 收藏人物使用中 TTL，切换收藏后失效
    _favoritePeopleCache.set(key, result, ttl: _ttl);
    return result;
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

  /// 失效收藏缓存
  void invalidateFavorites({
    required String serverUrl,
    required String token,
    String? userId,
  }) {
    final key = _favoritesKey(serverUrl, token, userId);
    _favoritesCache.delete(key);
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

  /// 失效收藏人物缓存
  ///
  /// toggleFavorite 后调用，避免显示旧的收藏列表。
  void invalidateFavoritePeople({
    required String serverUrl,
    required String token,
    String? userId,
  }) {
    final key = _favoritePeopleKey(serverUrl, token, userId);
    _favoritePeopleCache.delete(key);
  }

  /// 清除所有缓存
  void clearAll() {
    _libraryItemsCache.clear();
    _favoritesCache.clear();
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
  }
}
