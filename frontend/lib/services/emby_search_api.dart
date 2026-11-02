import '../models/models.dart';

abstract interface class EmbySearchApi {
  // ============================

  /// 搜索提示
  Future<List<SearchHint>> searchHints(
    String query, {
    int limit = 20,
    String? serverUrl,
    String? token,
  });

  /// 通用搜索（获取完整 MediaItem 对象）
  Future<PaginatedResponse<MediaItem>> searchItems(
    String query, {
    int limit = 30,
    int offset = 0,
    List<String>? includeTypes,
    String? userId,
    String? serverUrl,
    String? token,
  });

  /// 搜索人物（演员/导演/编剧）
  Future<List<Map<String, dynamic>>> searchPersons(
    String query, {
    int limit = 20,
    String? serverUrl,
    String? token,
  });
}
