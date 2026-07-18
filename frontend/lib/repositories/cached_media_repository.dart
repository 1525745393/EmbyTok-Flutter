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

  CachedMediaRepository(
    this._inner, {
    Duration ttl = const Duration(minutes: 5),
    int maxCacheEntries = 50,
  })  : _ttl = ttl,
        _libraryItemsCache = MemoryCache<PaginatedResponse<MediaItem>>(maxSize: maxCacheEntries),
        _favoritesCache = MemoryCache<FavoritesPageResult>(maxSize: 20),
        _resumeCache = MemoryCache<PaginatedResponse<MediaItem>>(maxSize: 20),
        _itemDetailCache = MemoryCache<MediaItem>(maxSize: 100);

  // ============================
  // 统计信息
  // ============================

  /// 聚合统计信息（所有缓存的统计总和）
  CacheStats get stats {
    final libStats = _libraryItemsCache.stats;
    final favStats = _favoritesCache.stats;
    final resumeStats = _resumeCache.stats;
    final detailStats = _itemDetailCache.stats;
    return CacheStats(
      hitCount: libStats.hitCount + favStats.hitCount + resumeStats.hitCount + detailStats.hitCount,
      missCount: libStats.missCount + favStats.missCount + resumeStats.missCount + detailStats.missCount,
      evictionCount: libStats.evictionCount + favStats.evictionCount + resumeStats.evictionCount + detailStats.evictionCount,
    );
  }

  /// 重置所有缓存的统计数据
  void resetStats() {
    _libraryItemsCache.resetStats();
    _favoritesCache.resetStats();
    _resumeCache.resetStats();
    _itemDetailCache.resetStats();
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

  /// 清除所有缓存
  void clearAll() {
    _libraryItemsCache.clear();
    _favoritesCache.clear();
    _resumeCache.clear();
    _itemDetailCache.clear();
  }
}
