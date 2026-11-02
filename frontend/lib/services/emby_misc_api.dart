import '../models/models.dart';

abstract interface class EmbyMiscApi {
  // ============================

  /// 观看历史（从服务器获取最近观看的条目）
  Future<List<MediaItem>> getWatchHistory({
    int limit = 50,
    String? userId,
    String? serverUrl,
    String? token,
  });

  // ============================
  // 云同步
  // ============================

  /// 保存续播位置到云端（DisplayPreferences）
  Future<void> saveCloudSync({
    required String itemId,
    required String libraryId,
    String? libraryType,
    String? serverUrl,
    String? token,
  });

  /// 从云端获取续播位置
  Future<Map<String, dynamic>?> checkCloudSync({
    String? serverUrl,
    String? token,
  });

  // ============================
  // 其他通用方法
  // ============================

  /// 通用 POST 请求
  Future<dynamic> postRaw(
    String path, {
    Map<String, dynamic>? queryParameters,
    dynamic data,
    String? serverUrl,
    String? token,
  });

  /// 通用 DELETE 请求
  Future<dynamic> deleteRaw(
    String path, {
    Map<String, dynamic>? queryParameters,
    String? serverUrl,
    String? token,
  });
}
