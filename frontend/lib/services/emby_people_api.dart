import '../models/models.dart';

abstract interface class EmbyPeopleApi {
  // ============================

  /// 人员（演员/导演）列表
  Future<PaginatedResponse<Person>> getPeople({
    int limit = 50,
    int startIndex = 0,
    List<String>? personTypes,
    String? searchTerm,
    String? serverUrl,
    String? token,
  });

  /// 某演员出演的作品
  Future<PaginatedResponse<MediaItem>> getPersonItems(
    String personId, {
    int limit = 30,
    int offset = 0,
    String? serverUrl,
    String? token,
  });

  /// 按多个演员 ID 批量查作品（推荐页「追剧」=收藏演员新作品）
  Future<PaginatedResponse<MediaItem>> getItemsByPersonIds({
    required List<String> personIds,
    int limit = 30,
    int offset = 0,
    String? serverUrl,
    String? token,
    String? userId,
  });

  /// 获取合集（BoxSet）里的视频
  Future<PaginatedResponse<MediaItem>> getBoxSetItems(
    String boxSetId, {
    int limit = 50,
    int offset = 0,
    bool excludePlayed = false,
    String? serverUrl,
    String? token,
  });

  /// 获取单个演员详情（包含 overview）
  Future<MediaItem?> getPersonDetail(
    String personId, {
    String? personName,
    String? serverUrl,
    String? token,
    String? userId,
  });
}
