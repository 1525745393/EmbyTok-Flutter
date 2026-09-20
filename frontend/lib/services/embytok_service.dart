// 核心业务服务：业务门面，依赖 MediaServerApi 接口
// 设计思路：每个方法都接受可选的 serverUrl / token 参数，调用方可以显式传入，
// 也可以先调用 setupAuth 后使用无参方法。这样既有灵活性又便于 Provider 使用。
// 业务逻辑（字幕缓存、播放上报重试等）保留在此层，纯 API 调用委托给 _api。

import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';

import '../models/models.dart';
import '../utils/logger.dart';
import '../utils/memory_cache.dart';
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

  // ============================
  // 媒体库列表：默认使用 /Users/{userId}/Views（用户视角），向后兼容 /Library/VirtualFolders
  // ============================

  // ============================
  // 用户视图：GET /Users/{userId}/Views（getLibraries 的别名，语义更明确）
  // ============================

  // ============================
  // 获取某媒体库下的视频列表
  // ============================

  // ============================
  // 获取项详情
  // ============================

  // ============================
  // 继续观看列表
  // ============================

  // ============================
  // 推荐列表：按社区评分从高到低排序，评分阈值 4.0（满分 10）
  // 默认排除已观看（IsPlayed=false），避免推已完结的视频
  // 评分阈值可通过 minCommunityRating 参数覆盖（PR #78：推荐优化）
  // includeItemTypes 可控制推荐范围（PR #79：类型偏好）
  // ============================

  // ============================
  // 个性化推荐：基于 Emby Suggestions API，利用观看历史做智能推荐
  // ============================

  // ============================
  // Emby 原生电影推荐 /Movies/Recommendations（展平分组）
  // ============================

  // ============================
  // Emby 原生电影推荐分组（保留"因为你看过 X"标题）
  // ============================

  // ============================
  // Emby 原生剧集推荐 /Shows/Recommended
  // ============================

  // ============================
  // Next Up（下一步看什么）—— 剧集的下一集
  // 可选 seriesId：传入则只返回指定剧集的下一集
  // ============================

  // ============================
  // 最近添加
  // ============================

  // ============================
  // 相似影片
  // ============================

  // ============================
  // 人员（演员/导演）列表
  // ============================

  // ============================
  // 某演员出演的作品
  // ============================

  // ============================
  // 获取单个演员详情（包含 overview）
  //
  // 注意：Emby 的 /Items/{id} 端点对 Person 类型可能不返回 Overview，
  // 但 /Users/{userId}/Items 列表端点会返回。因此使用列表端点 + Ids 参数
  // 获取单条记录，保证 Overview 字段。
  // ============================

  // ============================
  // 类型列表（Genres）
  // ============================

  // ============================
  // 某类型下的影片
  // ============================

  // ============================
  // 工作室列表
  // ============================

  // ============================
  // 某工作室下的影片
  // ============================

  // ============================
  // 收藏列表（从 Emby 获取）
  // ============================

  // ============================
  // 收藏影片（按类型：电影/剧集/音乐视频/单集，使用用户视图路径，与 EmbyX 对齐）
  // ============================

  // ============================
  // 收藏合集（BoxSet，使用用户视图路径，与 EmbyX 对齐）
  // ============================

  // ============================
  // 收藏人物（Person，使用用户视图路径，与 EmbyX 对齐）
  // ============================

  /// 获取收藏的各类型数量

  // ============================
  // 切换收藏状态（带 userId 端点，与 EmbyX 对齐）
  // ============================

  // ============================
  // 标记已看 / 未看
  // ============================

  // ============================
  // 剧集季列表
  // ============================

  // ============================
  // 剧集集列表
  // ============================

  // ============================
  // 预告片
  // ============================

  // ============================
  // 播放信息（通过 getItemDetail 获取，MediaSources 在详情中已包含）
  // ============================

  // ============================
  // 从服务端获取最新播放进度
  // ============================

  // ============================
  // 字幕 Cues 加载（从 Emby 获取并解析 SRT/VTT）
  // - index: 字幕轨道 index（与 MediaStream.index）
  // - mediaSourceId: 媒体源 ID
  //
  // 字幕 URL 格式：/Videos/{itemId}/{mediaSourceId}/Subtitles/{index}/0/Stream.{format}
  // 返回：按 start / end / text
  // ============================

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

  // ============================
  // 上报播放进度 / 停止位置
  // ============================

  // 上报播放能力（播放开始前调用）

  // 上报播放开始（带指数退避重试）

  // ============================
  // 观看历史（从 Emby 获取最近观看的条目）
  //
  // 优先使用用户级路径 /Users/{userId}/Items，该路径在多数 Emby 服务器上
  // 对继续观看列表的权限更明确。若 userId 为空，则降级到全局 /Items
  // 并附加 UserId 查询参数保证向后兼容。
  // ============================

  // ============================
  // 搜索提示
  // ============================

  // ============================
  // 通用搜索（获取完整 MediaItem 对象，使用用户视图路径，与 EmbyX 对齐）
  // ============================

  // ============================
  // 搜索人物（演员/导演/编剧）
  // ============================

  // ============================
  // 获取子项（孩子节点）
  // ============================

  // ============================
  // 续播云同步：使用 DisplayPreferences 实现跨设备续播同步
  // ============================

  // 保存续播位置到云端（DisplayPreferences）

  // 从云端获取续播位置

  // ============================
  // 通用 POST 请求
  // ============================

  // ============================
  // 通用 DELETE 请求
  // ============================

  // ============================
  // 删除媒体项
  // ============================
  /// 删除指定的媒体项（调用 Emby DELETE /Items/{itemId}）

  // ============================
  // 内部辅助方法
  // ============================

  // 指数退避重试：用于播放上报等关键操作
  // - maxAttempts: 最多重试次数（含首次），默认 3 次
  // - delayMs: 初始延迟毫秒数，每次翻倍，带 50% 抖动
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
        return; // 成功
      } catch (e) {
        if (attempt >= maxAttempts) {
          AppLogger.warn('$operationName 失败（$maxAttempts 次尝试均失败）',
              data: {'error': e.toString()});
          rethrow;
        }
        // 指数退避 + 50% 随机抖动，避免多设备同时重试产生雪崩
        final jitter = (delay * 0.5 * random.nextDouble()).toInt();
        final waitMs = delay + jitter;
        AppLogger.debug('$operationName 第 $attempt 次失败，${waitMs}ms 后重试',
            data: {'error': e.toString()});
        await Future<void>.delayed(Duration(milliseconds: waitMs));
        delay *= 2;
      }
    }
  }
}

/// 业务门面：查询/收藏/播放方法分别在 embytok_query/favorites/playback_api.dart
class EmbytokService extends EmbytokServiceBase
    with EmbytokQueryApi, EmbytokFavoritesApi, EmbytokPlaybackApi {
  EmbytokService({MediaServerApi? api}) : super(api: api);

  EmbytokService.withClient(ApiClient client) : super.withClient(client);
}
