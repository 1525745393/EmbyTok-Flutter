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
import '../utils/logger.dart';

/// 单个播放会话：绑定 VideoPlayerController + PlaySessionId
class PlaybackSession {
  final String itemId;
  final VideoPlayerController controller;
  final String playSessionId;
  final DateTime createdAt;
  bool _isDisposed = false;

  PlaybackSession({
    required this.itemId,
    required this.controller,
    required this.playSessionId,
  }) : createdAt = DateTime.now();

  bool get isInitialized =>
      !_isDisposed && controller.value.isInitialized;

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
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
  VideoPoolService({this.maxSize = 2})
      : assert(maxSize >= 1, 'maxSize must be >= 1');

  /// 池中最多同时活跃的控制器数量（不含当前正在播放的那个）
  final int maxSize;

  /// 主要缓存：key = itemId，value = 会话对象
  final Map<String, PlaybackSession> _sessions = <String, PlaybackSession>{};

  /// LRU 顺序：记录 itemId 按最近访问时间排序
  final List<String> _accessOrder = <String>[];

  /// 正在预加载中的 itemId 集合，用于防止同一 item 并发预加载导致双建 controller
  final Set<String> _inflight = <String>{};

  /// disposeAll 后预加载 controller 逃逸防护
  bool _disposed = false;

  /// 当前生效的 Token，用于检测是否需要刷新
  String? _currentToken;

  /// 当前生效的服务器地址
  String? _currentServer;

  /// 正在异步释放所有会话（防止并发 preload 创建新会话后又被误杀）
  bool _disposing = false;

  /// 检查是否存在某个 itemId 的预加载会话
  bool hasSession(String itemId) => _sessions.containsKey(itemId);

  /// 获取（不移除）某个会话
  PlaybackSession? peek(String itemId) => _sessions[itemId];

  /// 更新 Token：如与当前不同，清空所有缓存（旧 Token 无法继续播放）
  void updateAuth({required String serverUrl, required String token}) {
    if (_currentServer == serverUrl && _currentToken == token) return;
    _currentServer = serverUrl;
    _currentToken = token;
    _disposing = true;
    _disposed = true;
    // Token 变更：所有已存在的 controller 持有的 headers 已失效
    // 异步释放，不阻塞当前调用链；disposeAll 完成后会自动重置 _disposed 和 _disposing
    unawaited(disposeAll());
  }

  /// 预加载一个媒体条目
  ///
  /// - 返回 Future<PlaybackSession?>：控制器初始化完成后 resolve
  /// - 如已存在则直接返回现有会话
  /// - 如池已满则先淘汰最旧的会话
  Future<PlaybackSession?> preload({
    required MediaItem item,
    required String serverUrl,
    required String token,
  }) async {
    if (kIsWeb) return null; // Web 环境下不预加载
    if (_disposed) return null;
    if (item.id.isEmpty || serverUrl.isEmpty || token.isEmpty) return null;

    // Token 检查：如已变更则重新记录
    updateAuth(serverUrl: serverUrl, token: token);

    // 正在异步释放旧会话（updateAuth 触发的 disposeAll），等待完成后再创建新会话
    if (_disposing) return null;

    // 已有会话：直接返回
    final existing = _sessions[item.id];
    if (existing != null) {
      _touch(existing.itemId);
      return existing;
    }

    // 并发防护：同一 item 正在预加载中则跳过，避免双建 controller 造成 native 资源泄漏
    if (_inflight.contains(item.id)) return null;

    PlaybackSession? created;
    try {
      _inflight.add(item.id);

      // 池已满：淘汰最久未访问的会话
      if (_sessions.length >= maxSize) {
        final oldest = _accessOrder.first;
        _remove(oldest);
      }

      // 降级链：DirectPlay → DirectStream → HLS
      // 统一生成一次 playSessionId，HLS URL 与存储的会话共用，保证 Emby 上报关联一致
      final playSessionId = _generatePlaySessionId();
      final urls = <int, String?>{
        0: item.computePlaybackUrl(serverUrl, token),
        1: item.computeDirectStreamUrl(serverUrl, token),
        2: item.computeHlsUrl(serverUrl, token,
            playSessionId: playSessionId),
      };
      final headers = item.authHeaders(token);

      // 降级链：DirectPlay → DirectStream → HLS
      for (int level = 0; level < 3; level++) {
        final url = urls[level];
        if (url == null || url.isEmpty) continue;
        VideoPlayerController? controller;
        try {
          controller = VideoPlayerController.networkUrl(
            Uri.parse(url),
            httpHeaders: headers,
          );
          await controller.initialize().timeout(
            const Duration(seconds: 12),
            onTimeout: () {
              throw TimeoutException('preload initialize timeout');
            },
          );
          if (_disposed) {
            try { controller.dispose(); } catch (_) {}
            return null;
          }
          created = PlaybackSession(
            itemId: item.id,
            controller: controller,
            playSessionId: playSessionId,
          );
          _sessions[item.id] = created;
          _accessOrder.add(item.id);
          return created;
        } catch (e) {
          AppLogger.debug('VideoPoolService preload failed', data: {'level': level, 'error': e.toString()});
          try {
            controller?.dispose();
          } catch (_) {}
        }
      }
    } finally {
      _inflight.remove(item.id);
    }

    return created; // 可能为 null（全部失败）
  }

  /// 取出一个会话（从池中移除，所有权交给调用方）
  ///
  /// 调用方负责调用 PlaybackSession.dispose() 释放资源
  PlaybackSession? take(String itemId) {
    final session = _sessions.remove(itemId);
    _accessOrder.remove(itemId);
    return session;
  }

  /// 归还一个会话到池中（用于非当前页释放时复用）
  ///
  /// 使用场景：VideoPlayerWidget 在非当前页 2 秒延迟后释放 controller 时，
  /// 调用本方法将会话归还到池，而非直接 dispose。
  /// 后续用户来回滑动回到该 item 时，可从池中 take 直接复用，避免重新 initialize。
  ///
  /// 行为：
  /// - 若池中已有该 itemId 的会话：直接 dispose 传入的会话（避免重复）
  /// - 若池已满：按 LRU 淘汰最旧会话后存入
  /// - 否则：存入池中
  ///
  /// 注意：传入的会话必须已 initialize 完成且未被 dispose，否则会被忽略。
  void returnSession(PlaybackSession session) {
    // isInitialized 已包含 !_isDisposed 检查，无需重复访问私有字段
    if (!session.isInitialized) return;
    if (_sessions.containsKey(session.itemId)) {
      // 池中已有：直接 dispose 传入的（避免重复持有 native 资源）
      session.dispose();
      return;
    }
    if (_sessions.length >= maxSize) {
      final oldest = _accessOrder.first;
      _remove(oldest);
    }
    _sessions[session.itemId] = session;
    _accessOrder.add(session.itemId);
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
  /// 分批释放以避免同步批量 dispose VideoPlayerController 时内存峰值过高
  /// 导致的 OOM 崩溃（特别是在退出应用时）。
  ///
  /// 本方法在完成后会自动重置 `_disposed` 和 `_disposing` 标志，使池可继续接受新预加载请求。
  Future<void> disposeAll() async {
    _disposed = true;
    // 分批释放：每批处理 2 个，批次间让事件循环有机会触发 GC
    // 先清空 _inflight：防止登出/换账号后，正在预加载的旧会话完成后
    // 把过期 controller 写回已清空的 _sessions 池，造成 stale controller 残留
    _inflight.clear();
    final sessions = List<PlaybackSession>.from(_sessions.values);
    _sessions.clear();
    _accessOrder.clear();

    const batchSize = 2;
    for (var i = 0; i < sessions.length; i += batchSize) {
      final end = (i + batchSize < sessions.length) ? i + batchSize : sessions.length;
      for (var j = i; j < end; j++) {
        sessions[j].dispose();
      }
      // 批次之间让出主线程，给 GC 和 native texture 回收时间
      if (i + batchSize < sessions.length) {
        await Future<void>.delayed(Duration.zero);
      }
    }
    _disposing = false;
    _disposed = false;
  }

  /// 重置已销毁标记，使池可重新使用（如重新登录后复用同一实例）
  void reset() {
    _disposed = false;
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
