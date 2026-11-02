import '../models/models.dart';

abstract interface class EmbySeriesApi {
  // ============================

  /// 剧集季列表
  Future<List<MediaItem>> getSeasons(
    String seriesId, {
    String? serverUrl,
    String? token,
  });

  /// 剧集集列表
  Future<PaginatedResponse<MediaItem>> getEpisodes(
    String seriesId, {
    String? seasonId,
    int limit = 100,
    int offset = 0,
    String? serverUrl,
    String? token,
  });
}
