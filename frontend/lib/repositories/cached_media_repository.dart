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

import 'package:dio/dio.dart';

import '../models/models.dart';
import '../utils/safe_unawaited.dart';
import '../utils/memory_cache.dart';
import 'media_repository.dart';

import 'dart:async';

/// 带缓存的媒体仓库装饰器
///
/// 使用装饰器模式包装 [MediaRepository]，为只读操作添加内存缓存。
/// 不同账号（token 不同）的数据自动隔离，不会互相污染。
part 'cache_parts/cache_query_api.dart';
part 'cache_parts/cache_invalidate_api.dart';

/// 基类：持有内存缓存与内部工具方法（供 mixin 使用）
abstract class CachedMediaRepositoryBase {
  CachedMediaRepositoryBase(
    this._inner, {
    Duration ttl = const Duration(minutes: 5),
    int maxCacheEntries = 50,
  })  : _ttl = ttl,
        _libraryItemsCache =
            MemoryCache<PaginatedResponse<MediaItem>>(maxSize: maxCacheEntries),
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
        _personItemsCache =
            MemoryCache<PaginatedResponse<MediaItem>>(maxSize: 50),
        _favoritePeopleCache = MemoryCache<FavoritesPageResult>(maxSize: 20),
        _recommendationsCache =
            MemoryCache<PaginatedResponse<MediaItem>>(maxSize: 50),
        _suggestionsCache = MemoryCache<List<MediaItem>>(maxSize: 20),
        _watchHistoryCache = MemoryCache<List<MediaItem>>(maxSize: 20),
        _childrenCache = MemoryCache<List<MediaItem>>(maxSize: 100),
        _genresCache = MemoryCache<List<Library>>(maxSize: 10),
        _collectionsCache = MemoryCache<List<Library>>(maxSize: 10),
        _tagsCache = MemoryCache<List<Library>>(maxSize: 10),
        _tagItemsCache = MemoryCache<PaginatedResponse<MediaItem>>(maxSize: 20),
        _genreItemsCache =
            MemoryCache<PaginatedResponse<MediaItem>>(maxSize: 50),
        _studiosCache = MemoryCache<List<Library>>(maxSize: 10),
        _studioItemsCache =
            MemoryCache<PaginatedResponse<MediaItem>>(maxSize: 50);
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
  final MemoryCache<List<Library>> _collectionsCache;
  final MemoryCache<List<Library>> _tagsCache;
  final MemoryCache<PaginatedResponse<MediaItem>> _tagItemsCache;
  final MemoryCache<PaginatedResponse<MediaItem>> _genreItemsCache;
  final MemoryCache<List<Library>> _studiosCache;
  final MemoryCache<PaginatedResponse<MediaItem>> _studioItemsCache;

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
    _collectionsCache.resetStats();
    _tagsCache.resetStats();
    _tagItemsCache.resetStats();
    _genreItemsCache.resetStats();
    _studiosCache.resetStats();
    _studioItemsCache.resetStats();
  }

  int _sum(int Function(MemoryCache<Object?>) selector) {
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
        selector(_collectionsCache) +
        selector(_tagsCache) +
        selector(_tagItemsCache) +
        selector(_genreItemsCache) +
        selector(_studiosCache) +
        selector(_studioItemsCache);
  }

  String _libraryItemsKey(
    MediaQueryParams params,
    String serverUrl,
    String token,
  ) {
    return 'lib:$serverUrl:$token:${params.libraryId}:${params.limit}:${params.offset}:'
        '${params.sortBy ?? ''}:${params.sortOrder ?? ''}:${params.searchTerm ?? ''}:'
        '${params.excludePlayed}';
  }

  String _favoritesKey(
      String serverUrl, String token, String? userId, int limit, int offset) {
    return 'fav:$serverUrl:$token:${userId ?? ''}:$limit:$offset';
  }

  String _boxSetsFavoritesKey(
      String serverUrl, String token, String? userId, int limit, int offset) {
    return 'fav_boxsets:$serverUrl:$token:${userId ?? ''}:$limit:$offset';
  }

  String _resumeKey(
      String serverUrl, String token, int limit, int offset, String? userId) {
    return 'resume:$serverUrl:$token:${userId ?? ''}:$limit:$offset';
  }

  String _itemDetailKey(String itemId, String serverUrl, String token) {
    return 'detail:$serverUrl:$token:$itemId';
  }

  String _librariesKey(String serverUrl, String token, String? userId) {
    return 'libs:$serverUrl:$token:${userId ?? ''}';
  }

  String _nextUpKey(
      String serverUrl, String token, int limit, String? seriesId) {
    return 'nextup:$serverUrl:$token:$limit:${seriesId ?? ''}';
  }

  String _seasonsKey(String seriesId, String serverUrl, String token) {
    return 'seasons:$serverUrl:$token:$seriesId';
  }

  String _episodesKey(String seriesId, String? seasonId, int limit, int offset,
      String serverUrl, String token) {
    return 'episodes:$serverUrl:$token:$seriesId:${seasonId ?? ''}:$limit:$offset';
  }

  String _similarItemsKey(String itemId, int limit, String serverUrl,
      String token, String? userId) {
    return 'similar:$serverUrl:$token:${userId ?? ''}:$itemId:$limit';
  }

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

  String _personDetailKey(String personId, String serverUrl, String token) {
    return 'person:$serverUrl:$token:$personId';
  }

  String _personItemsKey(
    String personId,
    int limit,
    int offset,
    String serverUrl,
    String token,
  ) {
    return 'person_items:$serverUrl:$token:$personId:$limit:$offset';
  }

  String _favoritePeopleKey(
      String serverUrl, String token, String? userId, int limit, int offset) {
    return 'fav_people:$serverUrl:$token:${userId ?? ''}:$limit:$offset';
  }

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

  String _suggestionsKey(
      int limit, String? userId, String serverUrl, String token) {
    return 'sugg:$serverUrl:$token:${userId ?? ''}:$limit';
  }

  String _watchHistoryKey(
      int limit, String? userId, String serverUrl, String token) {
    return 'history:$serverUrl:$token:${userId ?? ''}:$limit';
  }

  String _childrenKey(
    String parentId,
    int limit,
    int offset,
    String serverUrl,
    String token,
  ) {
    return 'children:$serverUrl:$token:$parentId:$limit:$offset';
  }

  String _genresKey(int limit, String serverUrl, String token) {
    return 'genres:$serverUrl:$token:$limit';
  }

  String _collectionsKey(int limit, String serverUrl, String token) {
    return 'collections:$serverUrl:$token:$limit';
  }

  String _tagsKey(int limit, String serverUrl, String token) {
    return 'tags:$serverUrl:$token:$limit';
  }

  String _tagItemsKey(
      String tag, int limit, int offset, String serverUrl, String token) {
    return 'tag_items:$serverUrl:$token:$tag:$limit:$offset';
  }

  String _genreItemsKey(
      String genre, int limit, int offset, String serverUrl, String token) {
    return 'genre_items:$serverUrl:$token:$genre:$limit:$offset';
  }

  String _studiosKey(int limit, String serverUrl, String token) {
    return 'studios:$serverUrl:$token:$limit';
  }

  String _studioItemsKey(
      String studio, int limit, int offset, String serverUrl, String token) {
    return 'studio_items:$serverUrl:$token:$studio:$limit:$offset';
  }

  Future<T> _withCache<T>(
    MemoryCache<T> cache,
    String key,
    Future<T> Function() fetcher, {
    Duration? ttl,
  }) async {
    // 1. 判断是否有缓存（包括值为 null 的条目）
    final hasCached = cache.hasEntry(key);
    final staleValue = cache.getStale(key);
    if (hasCached || staleValue != null) {
      // 有缓存条目：判断是否过期
      if (!cache.isExpired(key)) {
        return staleValue as T;
      }
      // 过期命中：返回旧数据 + 后台刷新（null 值同样适用）
      _refreshInBackground(cache, key, fetcher, ttl: ttl);
      return staleValue as T;
    }
    // 未命中：同步获取
    final result = await fetcher();
    cache.set(key, result, ttl: ttl ?? _ttl);
    return result;
  }

  void _refreshInBackground<T>(
    MemoryCache<T> cache,
    String key,
    Future<T> Function() fetcher, {
    Duration? ttl,
  }) {
    if (_pendingRefreshes.contains(key)) return;
    _pendingRefreshes.add(key);
    safeUnawaited(
      fetcher().then((result) {
        cache.set(key, result, ttl: ttl ?? _ttl);
        cache.recordSwrRefresh();
      }).whenComplete(() {
        _pendingRefreshes.remove(key);
      }),
      context: 'CachedMediaRepository._refreshInBackground',
    );
  }
}

/// 带内存缓存的媒体仓库：实现 MediaRepository 接口
///
/// 查询方法在 [_CacheQueryApi]（cache_query_api.dart），
/// 失效方法在 [_CacheInvalidateApi]（cache_invalidate_api.dart），
/// mixin 成员满足接口实现。
class CachedMediaRepository extends CachedMediaRepositoryBase
    with _CacheQueryApi, _CacheInvalidateApi
    implements MediaRepository {
  CachedMediaRepository(
    MediaRepository inner, {
    Duration ttl = const Duration(minutes: 5),
    int maxCacheEntries = 50,
  }) : super(
          inner,
          ttl: ttl,
          maxCacheEntries: maxCacheEntries,
        );
}
