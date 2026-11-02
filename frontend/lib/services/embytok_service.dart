// 核心业务服务：业务门面，依赖 MediaServerApi 接口
// 设计思路：每个方法都接受可选的 serverUrl / token 参数，调用方可以显式传入，
// 也可以先调用 setupAuth 后使用无参方法。这样既有灵活性又便于 Provider 使用。
// 业务逻辑（字幕缓存、播放上报重试等）保留在此层，纯 API 调用委托给 _api。

import 'dart:io'; // part 文件 embytok_playback_api.dart 使用 File

import 'package:dio/dio.dart';

import '../models/models.dart';
import '../utils/logger.dart';
import '../utils/memory_cache.dart';
import '../utils/retry.dart';
import 'api_client.dart';
import 'emby_server_api.dart';
import 'media_server_api.dart';
part 'embytok_parts/embytok_query_api.dart';
part 'embytok_parts/embytok_favorites_api.dart';
part 'embytok_parts/embytok_playback_api.dart';

/// 基类：持有 MediaServerApi 门面与字幕缓存（供 mixin 使用）
abstract class EmbytokServiceBase {
  EmbytokServiceBase({MediaServerApi? api}) : _api = api ?? EmbyServerApi();

  EmbytokServiceBase.withClient(ApiClient client)
      : _api = EmbyServerApi.withClient(client);

  final MediaServerApi _api;

  // 字幕缓存：LRU + TTL，max 50 条，30 分钟过期
  final MemoryCache<List<SubtitleCue>> _subtitleCache =
      MemoryCache<List<SubtitleCue>>(maxSize: 50);

  // ============================
  // 认证配置（设置默认 server/token，后续调用可省略参数）
  // ============================
  void setupAuth({
    required String embyServerUrl,
    required String apiKey,
    String? userId,
  }) {
    _api.setupAuth(
      embyServerUrl: embyServerUrl,
      apiKey: apiKey,
      userId: userId,
    );
  }

  // 清除认证信息
  void clearAuth() {
    _api.clearAuth();
  }

  // ============================
  // 登录：Emby /Users/AuthenticateByName
  // ============================
  Future<User> login({
    required String embyServerUrl,
    required String username,
    required String password,
  }) {
    return _api.login(
      embyServerUrl: embyServerUrl,
      username: username,
      password: password,
    );
  }

  /// 获取收藏的各类型数量

  /// 清空字幕缓存（视频切换或用户登出时调用）

  /// 本地字幕文件最大大小（字节），默认 5MB
  ///
  /// 防止用户选择过大的文件导致内存问题
  static const int maxSubtitleFileSize = 5 * 1024 * 1024;

  /// 从本地文件加载字幕（外挂字幕）
  ///
  /// [filePath] 本地文件路径
  /// [format] 字幕格式（srt/vtt/ass/ssa），不传则从文件扩展名推断

  /// 从文件路径推断字幕格式
  String _detectFormatFromPath(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    switch (ext) {
      case 'vtt':
      case 'webvtt':
        return 'vtt';
      case 'ass':
      case 'ssa':
        return 'ass';
      case 'srt':
      case 'subrip':
      default:
        return 'srt';
    }
  }

  // 上报播放能力（播放开始前调用）

  // 上报播放开始（带指数退避重试）

  // 保存续播位置到云端（DisplayPreferences）

  // 从云端获取续播位置

  /// 删除指定的媒体项（调用 Emby DELETE /Items/{itemId}）
}

/// 业务门面：查询/收藏/播放方法分别在 embytok_query/favorites/playback_api.dart
class EmbytokService extends EmbytokServiceBase
    with EmbytokQueryApi, EmbytokFavoritesApi, EmbytokPlaybackApi {
  EmbytokService({super.api});

  EmbytokService.withClient(super.client) : super.withClient();
}
