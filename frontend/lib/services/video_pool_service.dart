// 视频控制器池（VideoPlayerController Pool）
//
// 设计目标：
// 1. 统一管理 Emby 视频的预加载与播放，避免重复初始化
// 2. 为每个控制器分配 PlaySessionId，与 Emby 上报链路一致
// 3. 预加载阶段支持降级：DirectPlay → DirectStream → HLS
// 4. 限制最大并发控制器数量，保护 Emby 服务器与设备内存
// 5. 支持 Token 失效后统一刷新

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../models/models.dart';

/// 单个播放会话：绑定 VideoPlayerController + PlaySessionId + 降级等级
class PlaybackSession {
  final String itemId;
  final VideoPlayerController controller;
  final String playSessionId;
  final int playbackLevel; // 0=DirectPlay, 1=DirectStream, 2=HLS
  final DateTime createdAt;
  /// 是否为轻量预加载（仅创建 controller，未执行 initialize）
  /// 取出播放时需由 VideoPlayerWidget 负责初始化
  final bool isLightPreload;
  bool _isDisposed = false;

  PlaybackSession({
    required this.itemId,
    required this.controller,
    required this.playSessionId,
    required this.playbackLevel,
    this.isLightPreload = false,
  }) : createdAt = DateTime.now();

  bool get isInitialized =>
      !_isDisposed && !isLightPreload && controller.value.isInitialized;

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    try {
      controller.pause();
    } catch (_) {}
    try {
      controller.dispose();
    } catch (_) {}
  }
}

/// 控制器池服务
///
/// 使用方式：
/// - `preload()`: 异步预加载下一个视频
/// - `take()`: 取出一个预加载好的会话（用于播放）
/// - `evictExcept()`: 清理距离当前索引较远的会话
/// - `invalidate()`: Token 变更或退出登录时清理全部
class VideoPoolService {
  VideoPoolService({this.maxSize = 4})
      : assert(maxSize >= 1, 'maxSize must be >= 1');

  /// 池中最多同时活跃的控制器数量（不含当前正在播放的那个）
  /// 注意：默认 4 是配合轻量预加载模式的容量。
  /// 轻量模式下仅创建 controller 不初始化，不占用解码器资源，
  /// 因此可以缓存更多条目以提高滑动命中率。
  final int maxSize;

  /// 最大并发预加载数：防止快速滑动时短时间内大量创建 controller
  static const int maxPendingPreloads = 1;
  int _pendingPreloads = 0;

  /// 主要缓存：key = itemId，value = 会话对象
  final Map<String, PlaybackSession> _sessions = <String, PlaybackSession>{};

  /// LRU 顺序：记录 itemId 按最近访问时间排序
  final List<String> _accessOrder = <String>[];

  /// 当前生效的 Token，用于检测是否需要刷新
  String? _currentToken;

  /// 当前生效的服务器地址
  String? _currentServer;

  /// 检查是否存在某个 itemId 的预加载会话
  bool hasSession(String itemId) => _sessions.containsKey(itemId);

  /// 获取（不移除）某个会话
  PlaybackSession? peek(String itemId) => _sessions[itemId];

  /// 更新 Token：如与当前不同，清空所有缓存（旧 Token 无法继续播放）
  void updateAuth({required String serverUrl, required String token}) {
    if (_currentServer == serverUrl && _currentToken == token) return;
    _currentServer = serverUrl;
    _currentToken = token;
    // Token 变更：所有已存在的 controller 持有的 headers 已失效
    // 异步释放，不阻塞当前调用链
    unawaited(disposeAll());
  }

  /// 预加载一个媒体条目
  ///
  /// - 返回 Future<PlaybackSession?>：控制器创建/初始化完成后 resolve
  /// - 如已存在则直接返回现有会话
  /// - 如池已满则先淘汰最旧的会话
  /// - [light]：轻量模式（默认 true），仅创建 controller + 设置静音，
  ///   不执行 initialize()，不占用解码器资源，由 VideoPlayerWidget
  ///   取出播放时才初始化。
  Future<PlaybackSession?> preload({
    required MediaItem item,
    required String serverUrl,
    required String token,
    bool light = true,
  }) async {
    if (kIsWeb) return null;
    if (item.id.isEmpty || serverUrl.isEmpty || token.isEmpty) return null;

    updateAuth(serverUrl: serverUrl, token: token);

    // 已有会话：直接返回
    final existing = _sessions[item.id];
    if (existing != null) {
      _touch(existing.itemId);
      return existing;
    }

    // 并发限流：避免快速滑动时短时间内大量创建 controller
    if (_pendingPreloads >= maxPendingPreloads) {
      debugPrint('VideoPoolService: too many pending preloads '
          '($_pendingPreloads), skip ${item.id}');
      return null;
    }
    _pendingPreloads++;

    try {
      // 池已满：淘汰最久未访问的会话
      if (_sessions.length >= maxSize) {
        final oldest = _accessOrder.first;
        _remove(oldest);
      }

      // 降级链：DirectPlay → DirectStream → HLS
      final urls = <int, String?>{
        0: item.computePlaybackUrl(serverUrl, token),
        1: item.computeDirectStreamUrl(serverUrl, token),
        2: item.computeHlsUrl(serverUrl, token,
            playSessionId: _generatePlaySessionId()),
      };
      final headers = item.authHeaders(token);

      PlaybackSession? created;
      for (int level = 0; level < 3; level++) {
        final url = urls[level];
        if (url == null || url.isEmpty) continue;
        VideoPlayerController? controller;
        try {
          controller = VideoPlayerController.networkUrl(
            Uri.parse(url),
            httpHeaders: headers,
          );
          // 预加载阶段默认静音，防止意外触发播放时突然发声
          await controller.setVolume(0);

          if (light) {
            // 轻量模式：不 initialize，不占用解码器资源
            created = PlaybackSession(
              itemId: item.id,
              controller: controller,
              playSessionId: _generatePlaySessionId(),
              playbackLevel: level,
              isLightPreload: true,
            );
          } else {
            // 全量模式：完整 initialize，解码首帧（占用解码器资源）
            await controller.initialize().timeout(
              const Duration(seconds: 10),
              onTimeout: () => throw TimeoutException('preload initialize timeout'),
            );
            created = PlaybackSession(
              itemId: item.id,
              controller: controller,
              playSessionId: _generatePlaySessionId(),
              playbackLevel: level,
              isLightPreload: false,
            );
          }
          _sessions[item.id] = created;
          _accessOrder.add(item.id);
          return created;
        } catch (e) {
          debugPrint(
              'VideoPoolService preload level=$level light=$light failed: $e');
          try {
            controller?.dispose();
          } catch (_) {}
        }
      }

      return created; // 可能为 null（全部失败）
    } finally {
      _pendingPreloads--;
    }
  }

  /// 取出一个会话（从池中移除，所有权交给调用方）
  ///
  /// 调用方负责调用 PlaybackSession.dispose() 释放资源
  PlaybackSession? take(String itemId) {
    final session = _sessions.remove(itemId);
    _accessOrder.remove(itemId);
    return session;
  }

  /// 清理指定 itemId 的会话
  void evict(String itemId) {
    _remove(itemId);
  }

  /// 清理除 keepIds 之外的所有会话
  void evictExcept(List<String> keepIds) {
    final toRemove = <String>[];
    for (final id in _sessions.keys) {
      if (!keepIds.contains(id)) toRemove.add(id);
    }
    for (final id in toRemove) {
      _remove(id);
    }
  }

  /// 清理所有会话（如退出登录、切换服务器）
  ///
  /// 逐个释放并在每个 dispose 后让出主线程，避免同步批量 dispose
  /// VideoPlayerController 时内存峰值过高导致的 OOM 崩溃
  /// （特别是在退出应用时）。
  Future<void> disposeAll() async {
    final sessions = List<PlaybackSession>.from(_sessions.values);
    _sessions.clear();
    _accessOrder.clear();

    for (var i = 0; i < sessions.length; i++) {
      sessions[i].dispose();
      // 每个 dispose 后让出主线程，给 GC 和 native texture 回收时间
      // 避免连续 dispose 多个已初始化 controller 时造成短暂的 MediaCodec 资源竞争
      if (i < sessions.length - 1) {
        await Future<void>.delayed(Duration.zero);
      }
    }
  }

  /// 当前池中的会话数
  int get size => _sessions.length;

  // ===== 内部方法 =====

  void _touch(String itemId) {
    _accessOrder.remove(itemId);
    _accessOrder.add(itemId);
  }

  void _remove(String itemId) {
    final session = _sessions.remove(itemId);
    _accessOrder.remove(itemId);
    session?.dispose();
  }

  String _generatePlaySessionId() =>
      'emb-pool-${DateTime.now().microsecondsSinceEpoch}-${identityHashCode(this) & 0xFFFF}';
}

/// 全局单例的 VideoPoolService（用 Provider 包装以便 Riverpod 访问）
final videoPoolProvider = Provider<VideoPoolService>((ref) => VideoPoolService());
