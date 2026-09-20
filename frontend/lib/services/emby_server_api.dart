// Emby 服务器 API 适配层：实现 MediaServerApi 接口，封装所有 Emby 原生 API 调用
// 设计思路：纯 API 适配层，只负责 HTTP 请求和响应解析，不包含业务逻辑状态
// （如字幕缓存、播放状态等保留在 EmbytokService 中）

import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';

import '../models/models.dart';
import '../utils/logger.dart';
import 'api_client.dart';
import 'media_server_api.dart';

part 'emby_api_discovery.dart';
part 'emby_api_favorites.dart';
part 'emby_api_playback.dart';

/// 基类：持有 API client、默认配置与内部工具方法（供 mixin 使用）
abstract class EmbyServerApiBase {
  // 发现数据源列表分页拉取的防御上限
  static const int _kDiscoverListMax = 5000;

  // 本地字幕文件最大大小（字节），默认 5MB
  static const int maxSubtitleFileSize = 5 * 1024 * 1024;

  EmbyServerApiBase() : _apiClient = ApiClient();

  EmbyServerApiBase.withClient(this._apiClient);

  final ApiClient _apiClient;
  String? _defaultServerUrl;
  String? _defaultToken;
  String? _defaultUserId;

  Future<void> _retry(
    Future<void> Function() fn, {
    int maxAttempts = 3,
    int initialDelayMs = 1000,
    String operationName = 'operation',
  }) async {
    var attempt = 0;
    var delay = initialDelayMs;
    final random = Random();
    while (true) {
      attempt++;
      try {
        await fn();
        return;
      } catch (e) {
        if (attempt >= maxAttempts) {
          AppLogger.warn('$operationName 失败（$maxAttempts 次尝试均失败）',
              data: {'error': e.toString()});
          rethrow;
        }
        final jitter = (delay * 0.5 * random.nextDouble()).toInt();
        final waitMs = delay + jitter;
        AppLogger.debug('$operationName 第 $attempt 次失败，${waitMs}ms 后重试',
            data: {'error': e.toString()});
        await Future<void>.delayed(Duration(milliseconds: waitMs));
        delay *= 2;
      }
    }
  }

  void _ensureConfig(String? serverUrl, String? token) {
    final url = serverUrl ?? _defaultServerUrl;
    final tk = token ?? _defaultToken;
    if (url == null || url.isEmpty) {
      AppLogger.warn('服务器地址未配置');
      throw AppError.notAuthenticated(message: '请先登录或提供 Emby 服务器地址');
    }
    if (url != _apiClient.optionsBaseUrl) {
      _apiClient.setBaseUrl(url);
    }
    if (tk != null && tk.isNotEmpty) {
      _apiClient.setToken(tk);
    }
  }

  PaginatedResponse<MediaItem> _parsePaginatedResponse(
    dynamic data, {
    int offset = 0,
    int limit = 20,
  }) {
    if (data is! Map<String, dynamic>) {
      return PaginatedResponse<MediaItem>(
        items: const <MediaItem>[],
        total: 0,
        offset: offset,
        limit: limit,
      );
    }
    final items = (data['Items'] as List<dynamic>?) ?? [];
    final total = (data['TotalRecordCount'] as int?) ?? items.length;
    return PaginatedResponse(
      items: items
          .whereType<Map<String, dynamic>>()
          .map((e) => MediaItem.fromJson(e))
          .toList(),
      total: total,
      offset: offset,
      limit: limit,
    );
  }
}

/// Emby 服务器 API 适配层：实现 MediaServerApi 接口，封装所有 Emby 原生 API 调用
///
/// 方法实现拆分为三个 mixin（discovery/favorites/playback），
/// mixin 成员满足接口实现，逻辑与类体分离。
class EmbyServerApi extends EmbyServerApiBase
    with _EmbyDiscoveryApi, _EmbyFavoritesApi, _EmbyPlaybackApi
    implements MediaServerApi {
  EmbyServerApi() : super();

  EmbyServerApi.withClient(ApiClient client) : super.withClient(client);
}
