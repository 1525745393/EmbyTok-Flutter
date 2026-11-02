import '../models/models.dart';

abstract interface class EmbyGenresApi {
  // ============================

  /// 类型列表（Genres）
  Future<List<Library>> getGenres({
    int limit = 100,
    String? parentId,
    String? serverUrl,
    String? token,
  });

  /// 获取服务器合集（BoxSet）列表（发现数据源）
  Future<List<Library>> getCollections({
    int limit = 100,
    String? serverUrl,
    String? token,
  });

  /// 获取服务器标签（Tags）列表（发现数据源）
  Future<List<Library>> getTags({
    int limit = 100,
    String? serverUrl,
    String? token,
  });

  /// 获取指定标签下的影片列表（发现数据源）
  Future<PaginatedResponse<MediaItem>> getItemsByTag(
    String tag, {
    int limit = 30,
    int offset = 0,
    String? serverUrl,
    String? token,
  });

  /// 某类型下的影片
  Future<PaginatedResponse<MediaItem>> getItemsByGenre(
    String genre, {
    int limit = 30,
    int offset = 0,
    String? serverUrl,
    String? token,
  });

  /// 工作室列表
  Future<List<Library>> getStudios({
    int limit = 100,
    String? serverUrl,
    String? token,
  });

  /// 某工作室下的影片
  Future<PaginatedResponse<MediaItem>> getItemsByStudio(
    String studio, {
    int limit = 30,
    int offset = 0,
    String? serverUrl,
    String? token,
  });
}
