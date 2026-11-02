import 'package:dio/dio.dart';
import '../models/models.dart';

abstract interface class EmbyDiscoveryApi {
  // ============================

  /// 继续观看列表
  Future<PaginatedResponse<MediaItem>> getResumeItems({
    int limit = 20,
    int offset = 0,
    String? serverUrl,
    String? token,
    CancelToken? cancelToken,
    String? userId,
  });

  /// 推荐列表
  ///
  /// 按社区评分从高到低排序，默认排除已观看
  Future<PaginatedResponse<MediaItem>> getRecommendations({
    int limit = 20,
    int offset = 0,
    String? libraryId,
    String? userId,
    String? serverUrl,
    String? token,
    double minCommunityRating = 4.0,
    bool excludePlayed = true,
    Set<String>? includeItemTypes,
  });

  /// 最新影片：按入库时间倒序，取最新添加的影片（推荐页「最新影片」标签）
  Future<PaginatedResponse<MediaItem>> getLatestItems({
    int limit = 20,
    int offset = 0,
    String? libraryId,
    String? userId,
    String? serverUrl,
    String? token,
    Set<String>? includeItemTypes,
  });

  /// 个性化推荐
  ///
  /// 基于 Suggestions API，利用观看历史做智能推荐
  Future<List<MediaItem>> getSuggestions({
    int limit = 20,
    String? userId,
    String? serverUrl,
    String? token,
  });

  /// Emby 原生电影推荐（/Movies/Recommendations）
  ///
  /// 返回按"因为你看过 X"分组的电影，已在实现层展平去重。
  /// 老版本 Emby / Jellyfin 可能不支持，调用方需容错降级。
  Future<List<MediaItem>> getMovieRecommendations({
    int categoryLimit = 6,
    int itemLimit = 10,
    String? userId,
    String? libraryId,
    String? serverUrl,
    String? token,
  });

  /// Emby 原生电影推荐分组（/Movies/Recommendations，保留 BaselineItemName）
  ///
  /// 用于首页"因为你看过 X"横幅；返回带分组标题的推荐电影。
  /// 老版本 Emby / Jellyfin 可能不支持，调用方需容错降级。
  Future<List<NativeRecGroup>> getMovieRecommendationGroups({
    int categoryLimit = 6,
    int itemLimit = 10,
    String? userId,
    String? libraryId,
    String? serverUrl,
    String? token,
  });

  /// Emby 原生剧集推荐（/Shows/Recommended）
  ///
  /// 老版本 Emby / Jellyfin 可能不支持，调用方需容错降级。
  Future<List<MediaItem>> getRecommendedShows({
    int limit = 30,
    String? userId,
    String? libraryId,
    String? serverUrl,
    String? token,
  });

  /// Next Up（下一步看什么）—— 剧集的下一集
  ///
  /// 可选 seriesId：传入则只返回指定剧集的下一集
  Future<PaginatedResponse<MediaItem>> getNextUp({
    int limit = 20,
    String? seriesId,
    String? serverUrl,
    String? token,
  });

  /// 最近添加
  Future<PaginatedResponse<MediaItem>> getRecentlyAdded({
    int limit = 20,
    int offset = 0,
    String? libraryId,
    String? userId,
    String? serverUrl,
    String? token,
  });

  /// 相似影片
  Future<List<MediaItem>> getSimilarItems(
    String itemId, {
    int limit = 20,
    String? serverUrl,
    String? token,
    String? userId,
  });

  /// 预告片
  Future<PaginatedResponse<MediaItem>> getTrailers({
    int limit = 30,
    int offset = 0,
    String? serverUrl,
    String? token,
  });
}
