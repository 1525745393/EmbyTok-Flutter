// 视频流单页：全屏视频 + 右侧操作按钮 + 左下角标题信息
// 新增：完整 Emby 播放上报链（reportCapabilities / reportPlaybackStart /
//       reportPlaybackPosition / reportPlaybackStopped），保持与 EmbyX 的
//       服务端统计对齐。

import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../services/embbytok_service.dart';
import '../utils/colors.dart';
import '../utils/constants.dart';
import 'gesture_overlay.dart';
import 'video_controls.dart';
import 'video_player_widget.dart';

/// 单个视频页：TikTok 卡片样式
class VideoPageItem extends ConsumerStatefulWidget {
  final MediaItem item;
  final VideoPlayerController? preloadedController;
  // 播放结束时的回调（用于自动连播下一条）
  final VoidCallback? onVideoEnded;
  // 是否为 resume 模式（需要从 userData.playbackPositionTicks 开始）
  final bool startFromResumePosition;
  // 上一集 / 下一集 回调（剧集类内容）
  final VoidCallback? onNextEpisode;
  final VoidCallback? onPrevEpisode;

  const VideoPageItem({
    super.key,
    required this.item,
    this.preloadedController,
    this.onVideoEnded,
    this.startFromResumePosition = false,
    this.onNextEpisode,
    this.onPrevEpisode,
  });

  @override
  ConsumerState<VideoPageItem> createState() => _VideoPageItemState();
}

class _VideoPageItemState extends ConsumerState<VideoPageItem> with TickerProviderStateMixin {
  VideoPlayerController? _videoController;
  bool _hasNotifiedEnded = false;  // 防止重复触发 onVideoEnded
  // 预加载控制器缓存：保持对下一条视频的 controller，当 widget 切换时复用

  // --- 唱片式静音按钮动画控制器 ---
  late final AnimationController _discRotationCtrl;
  late final Animation<double> _discRotation;

  // --- 播放上报相关 ---
  final EmbytokService _service = EmbytokService();
  Timer? _progressTimer;
  String? _playSessionId;
  bool _hasStartedReported = false;
  bool _capabilitiesReported = false;
  DateTime _lastProgressReport = DateTime.fromMicrosecondsSinceEpoch(0);
  // 节流距离：至少 5 秒 / 3 秒内不同时上报（避免网络波动下的冗余请求）
  static const _progressReportMinSeconds = 4;

  // 横屏全屏沉浸模式状态
  bool _isFullscreen = false;

  // 底部信息面板展开/收起状态
  bool _isInfoExpanded = false;

  // 控制层（VideoControls）显示状态
  bool _controlsVisible = false;
  Timer? _controlsHideTimer;

  // 控制层自动隐藏时长
  static const int _controlsAutoHideSeconds = 3;

  // --- NextUp（下一集提示）状态 ---
  // 播放结束时查询到的下一集条目（null 表示无下一集或未查询）
  MediaItem? _nextUpItem;
  // NextUp 提示条是否可见
  bool _showNextUpBanner = false;
  // NextUp 倒计时剩余秒数
  int _nextUpCountdown = 5;
  // NextUp 倒计时定时器
  Timer? _nextUpTimer;
  // NextUp 倒计时总时长
  static const int _nextUpCountdownSeconds = 5;

  @override
  void initState() {
    super.initState();
    _discRotationCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(); // 持续旋转
    _discRotation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _discRotationCtrl, curve: Curves.linear));
  }

  @override
  void dispose() {
    _discRotationCtrl.dispose();
    // 0. 清理 controller 的 ended 监听器
    _videoController?.removeListener(_onVideoChanged);
    // 1. 停止并清理播放进度上报定时器
    _progressTimer?.cancel();
    _progressTimer = null;
    // 2. 上报播放停止（带上当前播放位置）
    if (_hasStartedReported) {
      _reportPlaybackStopped();
    }
    // 3. 清理计时器
    _controlsHideTimer?.cancel();
    // 3b. 清理 NextUp 倒计时定时器
    _nextUpTimer?.cancel();
    _nextUpTimer = null;
    // 4. 退出时恢复竖屏方向（避免横屏状态残留）
    if (_isFullscreen) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
    // 5. 清理当前 item 的 ready 标记（用于下次再滑回来重新淡入）
    ref.read(videoReadyProvider.notifier).clear(widget.item.id);
    // 5b. 清空 currentVideoControllerProvider
    final ctrl = ref.read(currentVideoControllerProvider);
    if (ctrl != null && identical(ctrl, _videoController)) {
      ref.read(currentVideoControllerProvider.notifier).state = null;
    }
    // 6. 显式释放视频控制器，避免 MediaCodec 泄漏导致 OOM
    _videoController?.dispose();
    _videoController = null;
    // 7. 重置会话状态（用于下次进入重新生成新的播放会话）
    _capabilitiesReported = false;
    _hasStartedReported = false;
    _playSessionId = null;
    _hasNotifiedEnded = false;
    super.dispose();
  }

  // 视频状态变化监听（用于检测播放结束）
  void _onVideoChanged() {
    if (!mounted || _videoController == null) return;
    // 播放结束检测（接近末尾 1 秒内就算播放完）
    if (!_hasNotifiedEnded) {
      final pos = _videoController!.value.position;
      final dur = _videoController!.value.duration;
      if (dur.inMilliseconds > 0 &&
          (dur - pos).inMilliseconds < 1000) {
        _hasNotifiedEnded = true;
        // 上报播放停止（带上结束位置）
        _reportPlaybackStopped();
        // 标记为已播放：Emby 服务端会从 resume 列表移除该条目
        // 同时通知本地 videoListProvider 移除（仅 resume 模式生效）
        unawaited(_service.markAsPlayed(
          widget.item.id,
          serverUrl: _authServerUrl(),
          token: _authToken(),
        ));
        ref.read(videoListProvider.notifier).removePlayedItem(widget.item.id);
        // 查询 NextUp：剧集类内容尝试获取下一集并显示提示条
        _queryNextUp();
      }
    }
  }

  // 查询 NextUp 下一集：剧集类内容调用 Emby /Shows/NextUp?SeriesId=xxx
  // 查询成功则显示提示条并启动倒计时；失败则回退到默认自动连播逻辑
  Future<void> _queryNextUp() async {
    // 仅剧集类内容（有 seriesId 或 seriesName）才查询 NextUp
    final seriesId = widget.item.seriesId;
    final isEpisode = widget.item.type == 'Episode' ||
        (widget.item.seriesName != null && widget.item.seriesName!.isNotEmpty);
    if (!isEpisode) {
      // 非剧集：直接走默认自动连播
      _fallbackAutoPlay();
      return;
    }
    try {
      final resp = await _service.getNextUp(
        seriesId: seriesId,
        limit: 1,
        serverUrl: _authServerUrl(),
        token: _authToken(),
      );
      // 过滤掉当前正在播放的条目，取第一个作为下一集
      final candidates = resp.items
          .where((it) => it.id != widget.item.id)
          .toList();
      if (mounted && candidates.isNotEmpty) {
        setState(() {
          _nextUpItem = candidates.first;
          _showNextUpBanner = true;
          _nextUpCountdown = _nextUpCountdownSeconds;
        });
        _startNextUpCountdown();
      } else if (mounted) {
        // 无下一集：回退默认逻辑
        _fallbackAutoPlay();
      }
    } catch (_) {
      // 查询失败：回退默认逻辑
      if (mounted) _fallbackAutoPlay();
    }
  }

  // 启动 NextUp 倒计时：每秒递减，归零时自动播放下一集
  void _startNextUpCountdown() {
    _nextUpTimer?.cancel();
    _nextUpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _nextUpCountdown--;
      });
      if (_nextUpCountdown <= 0) {
        timer.cancel();
        _playNextUp();
      }
    });
  }

  // 立即播放 NextUp 下一集（用户点击或倒计时结束触发）
  void _playNextUp() {
    _nextUpTimer?.cancel();
    if (!mounted) return;
    // 优先使用本地 onNextEpisode 回调（feed_view 中查找同 series 下一集）
    // 其次回退到 onVideoEnded（翻到 feed 下一条）
    if (widget.onNextEpisode != null) {
      setState(() {
        _showNextUpBanner = false;
      });
      widget.onNextEpisode!.call();
    } else {
      _fallbackAutoPlay();
    }
  }

  // 取消 NextUp 提示条（用户点击取消）
  void _cancelNextUp() {
    _nextUpTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _showNextUpBanner = false;
    });
  }

  // 回退到默认自动连播逻辑（无 NextUp 时）
  void _fallbackAutoPlay() {
    final autoPlay = ref.read(isAutoPlayProvider);
    if (autoPlay) {
      widget.onVideoEnded?.call();
    }
  }

  // ========== 播放上报链方法 ==========

  // 生成播放会话 ID：时间戳 + 随机数（不依赖 uuid 包）
  String _newPlaySessionId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    return 'emb-flutter-$now';
  }

  // 根据当前降级等级判断 PlayMethod（0/1 → DirectPlay，2 → Transcode）
  String _playMethodFromLevel(int level) {
    return level >= 2 ? 'Transcode' : 'DirectPlay';
  }

  // 首次进入播放前上报设备能力（整个 app 生命周期内只需要一次，但按 item 维度也可）
  void _ensureCapabilitiesReported() {
    if (_capabilitiesReported) return;
    _capabilitiesReported = true;
    unawaited(_service.reportCapabilities(
      serverUrl: _authServerUrl(),
      token: _authToken(),
    ));
  }

  // 播放开始：记录播放 URL 和 itemId / session
  void _reportPlaybackStart() {
    if (_hasStartedReported) return;
    _hasStartedReported = true;
    _playSessionId = _newPlaySessionId();
    final level = ref.read(playbackLevelProvider);
    final method = _playMethodFromLevel(level);
    unawaited(_service.reportPlaybackStart(
      itemId: widget.item.id,
      mediaSourceId: widget.item.id,
      playSessionId: _playSessionId!,
      playMethod: method,
      serverUrl: _authServerUrl(),
      token: _authToken(),
    ));
  }

  // 定时进度上报（节流版）
  void _reportPlaybackProgress({bool isPauseEvent = false}) {
    final now = DateTime.now();
    if (!isPauseEvent) {
      final delta = now.difference(_lastProgressReport);
      if (delta.inSeconds < _progressReportMinSeconds) return;
    }
    _lastProgressReport = now;
    final controller = _videoController;
    final position = controller?.value.position;
    final positionSeconds = position?.inSeconds ?? 0;
    final positionTicks = positionSeconds * 10000000;
    final isPaused = controller != null && !controller.value.isPlaying;
    final volume = controller?.value.volume;
    final volumeLevel = volume != null ? (volume * 100).round() : null;
    final level = ref.read(playbackLevelProvider);
    final method = _playMethodFromLevel(level);
    unawaited(_service.reportPlaybackPosition(
      itemId: widget.item.id,
      positionTicks: positionTicks,
      mediaSourceId: widget.item.id,
      playSessionId: _playSessionId,
      isPaused: isPaused,
      volumeLevel: volumeLevel,
      playMethod: method,
      eventName: isPauseEvent ? 'Pause' : 'TimeUpdate',
      serverUrl: _authServerUrl(),
      token: _authToken(),
    ));
  }

  // 播放停止
  void _reportPlaybackStopped() {
    final controller = _videoController;
    final position = controller?.value.position;
    final positionTicks = position != null
        ? (position.inSeconds * 10000000)
        : 0;
    unawaited(_service.reportPlaybackStopped(
      itemId: widget.item.id,
      positionTicks: positionTicks,
      mediaSourceId: widget.item.id,
      playSessionId: _playSessionId,
      serverUrl: _authServerUrl(),
      token: _authToken(),
    ));
    _hasStartedReported = false;
  }

  // 启动进度上报定时器（周期 5 秒，内部再做 _reportPlaybackProgress(）
  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      _reportPlaybackProgress();
    });
  }

  // ========== 认证辅助 ==========
  String? _authServerUrl() {
    final auth = ref.watch(authProvider);
    return auth.embyServerUrl;
  }

  String? _authToken() {
    final auth = ref.watch(authProvider);
    return auth.token;
  }

  // 切换横屏全屏沉浸模式
  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });
    if (_isFullscreen) {
      // 进入横屏沉浸：强制横屏 + 隐藏工具栏
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      ref.read(toolbarVisibilityProvider.notifier).hide();
    } else {
      // 退出横屏沉浸：恢复竖屏
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      ref.read(toolbarVisibilityProvider.notifier).show();
    }
  }

  // 切换控制层显示/隐藏（由 GestureOverlay 单击触发）
  void _toggleControls() {
    if (_controlsVisible) {
      _hideControls();
    } else {
      _showControls();
    }
  }

  // 显示控制层并启动自动隐藏计时器
  void _showControls() {
    _controlsHideTimer?.cancel();
    setState(() {
      _controlsVisible = true;
    });
    _controlsHideTimer = Timer(
      const Duration(seconds: _controlsAutoHideSeconds),
      _hideControls,
    );
  }

  // 隐藏控制层
  void _hideControls() {
    _controlsHideTimer?.cancel();
    if (mounted) {
      setState(() {
        _controlsVisible = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 监听播放状态变化：播放时让唱片持续旋转，暂停时停止旋转
    ref.listen<bool>(isPlayingProvider, (previous, next) {
      if (next) {
        if (!_discRotationCtrl.isAnimating) _discRotationCtrl.repeat();
      } else {
        if (_discRotationCtrl.isAnimating) _discRotationCtrl.stop();
      }
    });

    final authState = ref.watch(authProvider);
    final embyServerUrl = authState.embyServerUrl;
    final token = authState.token;

    // 响应式读取收藏状态：任何来源的切换都会立即反映到 UI
    final favorited =
        ref.watch(favoritesProvider).favoriteIds.contains(widget.item.id);

    // 读取 ready 状态：当 item.id 在 videoReadyProvider 中，视为 ready
    final isReady = ref.watch(videoReadyProvider).contains(widget.item.id);

    // 读取播放状态（用于中央播放按钮显示）
    final isPlaying = ref.watch(isPlayingProvider);

    // 读取自动连播状态（用于纯净模式）
    final isAutoPlay = ref.watch(isAutoPlayProvider);

    // 横屏全屏模式下使用黑色背景 + 居中布局
    final content = Stack(
      fit: StackFit.expand,
      children: [
        // 骨架占位：视频未 ready 时显示渐变色块
        AnimatedContainer(
          duration: const Duration(milliseconds: kVideoFadeInMs),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isReady
                  ? [Colors.transparent, Colors.transparent]
                  : [surfaceColorL2, surfaceColorL3],
            ),
          ),
        ),

        // 视频播放区（Gestures + VideoPlayer）：未 ready 时透明，ready 后 200ms 渐显
        AnimatedOpacity(
          opacity: isReady ? 1.0 : 0.0,
          duration: const Duration(milliseconds: kVideoFadeInMs),
          curve: Curves.easeOut,
          child: GestureOverlay(
            controller: _videoController,
            item: widget.item,
            onSingleTap: _toggleControls,
            child: VideoPlayerWidget(
              item: widget.item,
              embyServerUrl: embyServerUrl,
              token: token,
              preloadedController: widget.preloadedController,
              onControllerReady: (c) {
                setState(() {
                  _videoController = c;
                });
                // 暴露到全局 Provider（用于快捷键 seek、播放结束时切换）
                ref.read(currentVideoControllerProvider.notifier).state = c;
                ref.read(isPlayingProvider.notifier).state = true;
                ref.read(currentPlayingItemProvider.notifier).state =
                    widget.item;
                // 标记为 ready：触发 AnimatedOpacity 渐显
                ref.read(videoReadyProvider.notifier).markReady(widget.item.id);
                // 续播位置 seek：resume 模式下从上次播放位置开始
                if (widget.startFromResumePosition) {
                  final posTicks = widget.item.userData?.playbackPositionTicks ?? 0.0;
                  if (posTicks > 0.0) {
                    final posMs = (posTicks / 10000.0).round(); // 1 tick = 100ns → ms
                    if (posMs > 0) {
                      Future.microtask(() async {
                        try {
                          await c.seekTo(Duration(milliseconds: posMs));
                        } catch (_) {}
                      });
                    }
                  }
                }
                // ===== 播放上报链 =====
                // 1. 上报能力（仅一次）
                _ensureCapabilitiesReported();
                // 2. 上报播放开始
                _reportPlaybackStart();
                // 3. 启动周期进度上报（5 秒一次）
                _startProgressTimer();
                // 4. 监听播放状态：暂停上报 + 播放结束连播检测
                c.addListener(_onVideoChanged);
                c.addListener(() {
                  if (!mounted) return;
                  if (!c.value.isPlaying) {
                    _reportPlaybackProgress(isPauseEvent: true);
                  }
                });
              },
            ),
          ),
        ),

        // TikTok 风格底部细线进度条（始终可见）
        if (_videoController != null && _videoController!.value.isInitialized)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _ThinProgressBar(controller: _videoController!),
          ),

        // 中央播放/暂停按钮（暂停时显示）
        if (_videoController != null && _videoController!.value.isInitialized && !isPlaying)
          _buildCenterPlayButton(),

        // 倍速状态徽章：播放速度 > 1x 时显示（与 EmbyTok 原版一致）
        if (_videoController != null &&
            _videoController!.value.isInitialized &&
            _videoController!.value.playbackSpeed > 1.0)
          _buildSpeedBadge(_videoController!.value.playbackSpeed),

        // 控制层（VideoControls）：可隐藏，3 秒无操作自动淡出
        // 始终创建（不管 isAutoPlay），点击屏幕时通过 _toggleControls 触发动画显示
        if (_videoController != null && _videoController!.value.isInitialized)
          Positioned(
            left: 0,
            right: 0,
            bottom: _isFullscreen ? 0 : kBottomNavHeight,
            child: AnimatedOpacity(
              opacity: _controlsVisible ? 1.0 : 0.0,
              duration: Duration(milliseconds: _controlsVisible ? 200 : 300),
              child: IgnorePointer(
                ignoring: !_controlsVisible,
                child: VideoControls(
                  controller: _videoController!,
                  subtitleTracks: widget.item.subtitleTracks,
                  onPrevEpisode: widget.onPrevEpisode,
                  onNextEpisode: widget.onNextEpisode,
                ),
              ),
            ),
          ),

        // 底部渐变 + 标题/简介/类型标签（横屏全屏模式下隐藏；
        // 纯净模式下由信息按钮控制：信息面板的显示/隐藏）
        if (!_isFullscreen && (_isInfoExpanded || !isAutoPlay)) _buildBottomGradient(),

        // 右侧渐变 + 操作按钮（横屏全屏模式或纯净模式下隐藏）
        if (!_isFullscreen && !isAutoPlay) _buildRightActions(favorited),

        // 纯净模式下显示简化的右侧按钮区（仅连播开关 + 倍速按钮）
        if (!_isFullscreen && isAutoPlay) _buildCleanModeRightActions(),

        // 横屏全屏模式下显示退出按钮（右上角）
        if (_isFullscreen) _buildExitFullscreenButton(),

        // NextUp 下一集提示条：播放结束时显示，5 秒倒计时后自动播放
        if (_showNextUpBanner && _nextUpItem != null)
          _buildNextUpBanner(),
      ],
    );

    // 横屏全屏模式：黑色背景 + 居中
    if (_isFullscreen) {
      return Semantics(
        label: '横屏全屏视频播放',
        child: Container(
          color: backgroundColor,
          child: content,
        ),
      );
    }

    return Semantics(
      label: '视频播放区域，双击点赞此视频',
      child: content,
    );
  }

  // 中央播放按钮：暂停时显示半透明播放图标
  Widget _buildCenterPlayButton() {
    return Positioned.fill(
      child: Center(
        child: GestureDetector(
          onTap: () {
            try {
              _videoController?.play();
              ref.read(isPlayingProvider.notifier).state = true;
              // 显示控制层并重置计时器
              _showControls();
            } catch (e) {
              debugPrint('center play button error: $e');
            }
          },
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0x99000000), // 60% 不透明黑色
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.play_arrow,
              color: textPrimary,
              size: 48,
            ),
          ),
        ),
      ),
    );
  }

  // 倍速状态徽章：当播放速度 > 1x 时显示在右上角（与 EmbyTok 原版一致）
  Widget _buildSpeedBadge(double speed) {
    return Positioned(
      top: 48, // 位于顶部安全区下方
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.flash_on, // Zap 图标
                color: Color(0xFFFFD700), // 黄色
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                '${speed.toStringAsFixed(1)}x',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 横屏全屏模式下的退出按钮（右上角）
  Widget _buildExitFullscreenButton() {
    final topPadding = MediaQuery.of(context).padding.top;
    return Positioned(
      top: topPadding + 8,
      right: 16,
      child: IconButton(
        icon: const Icon(Icons.fullscreen_exit, color: textPrimary, size: 28),
        onPressed: _toggleFullscreen,
      ),
    );
  }

  // NextUp 下一集提示条：底部卡片，显示下一集标题 + 倒计时 + 立即播放/取消按钮
  Widget _buildNextUpBanner() {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final nextItem = _nextUpItem!;
    // 拼接下一集标题：SxEy + 标题（如果有）
    final seasonEp = (nextItem.parentIndexNumber != null && nextItem.indexNumber != null)
        ? 'S${nextItem.parentIndexNumber}E${nextItem.indexNumber}'
        : null;
    final nextTitle = seasonEp != null
        ? '$seasonEp ${nextItem.title}'
        : nextItem.title;

    return Positioned(
      left: 16,
      right: 16,
      bottom: bottomPadding + kBottomNavHeight + 16,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xE6000000), // 90% 不透明黑色
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: primaryPink, width: 1),
          ),
          child: Row(
            children: [
              // 左侧：下一集图标 + 标题信息
              const Icon(Icons.skip_next, color: primaryPink, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '即将播放下一集',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      nextTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              // 中间：倒计时秒数
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: primaryPink,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_nextUpCountdown}s',
                  style: const TextStyle(
                    color: textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              // 右侧：立即播放按钮
              GestureDetector(
                onTap: _playNextUp,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: primaryPink,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '立即播放',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              // 取消按钮
              IconButton(
                icon: const Icon(Icons.close, color: textSecondary, size: 20),
                onPressed: _cancelNextUp,
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 底部半透明黑色渐变 + 标题/简介/类型标签
  // 动态 padding：适配底部导航栏高度 + 底部手势条
  // 底部导航栏显示时向上偏移 kBottomNavHeight，隐藏时仅保留安全 padding
  Widget _buildBottomGradient() {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final toolbarVisible = ref.watch(toolbarVisibilityProvider);

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          16,
          80, // 顶部距离：从视频画面上方开始计算（避开右侧操作按钮的垂直范围
          96,
          // 底部距离：导航栏可见时 = kBottomNavHeight + 手势条 + 24px；隐藏时 = 手势条 + 24px
          toolbarVisible
              ? kBottomNavHeight + bottomPadding + 24
              : bottomPadding + 24,
        ),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                backgroundColor,
                backgroundColor,
                Colors.transparent,
              ],
              stops: [0.0, 0.5, 1.0],
            ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: primaryPink,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.item.type,
                style: const TextStyle(
                  color: textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _titleText(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            if (widget.item.overview != null && widget.item.overview!.isNotEmpty)
              Text(
                widget.item.overview!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: textSecondary,
                  fontSize: 14,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 右侧操作按钮列：与 React 版 EmbyTok 对齐
  Widget _buildRightActions(bool favorited) {
    final isMuted = ref.watch(isMutedProvider);
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final toolbarVisible = ref.watch(toolbarVisibilityProvider);
    final subtitleSelected = ref.watch(selectedSubtitleProvider);
    final playMode = ref.watch(playbackLevelProvider);

    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      width: 96,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          0,
          toolbarVisible
              ? topPadding + 56.0 + 40.0
              : topPadding + 40.0,
          8,
          24 + bottomPadding,
        ),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            colors: [
              Color(0x8A000000),
              Colors.transparent,
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // 1. 海报/头像展示区（顶部 TikTok 风格）
            _buildPosterAvatar(),
            const SizedBox(height: 20),
            // 2. 点赞
            _buildActionButton(
              favorited ? Icons.favorite : Icons.favorite_border,
              '点赞',
              color: favorited ? const Color(0xFFFF2D55) : textPrimary,
              onTap: () => ref.read(favoritesProvider.notifier).toggleFavorite(widget.item),
            ),
            const SizedBox(height: 20),
            // 3. 信息按钮
            _buildInfoButton(),
            const SizedBox(height: 20),
            // 4. 删除按钮
            _buildDeleteButton(),
            const SizedBox(height: 20),
            // 5. 倍速按钮
            _buildSpeedControlButton(),
            const SizedBox(height: 20),
            // 6. 播放模式按钮
            _buildPlayModeButton(),
            const SizedBox(height: 20),
            // 7. 字幕按钮
            _buildSubtitleButton(),
            const SizedBox(height: 20),
            // 8. 唱片式静音按钮
            _buildDiscMuteButton(),
            const SizedBox(height: 20),
            // 9. 全屏按钮
            _buildActionButton(
              _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
              _isFullscreen ? '退出' : '全屏',
              color: textPrimary,
              onTap: _toggleFullscreen,
            ),
            const SizedBox(height: 20),
            // 10. 下一集（仅剧集类）
            if (widget.onNextEpisode != null) ...[
              _buildActionButton(
                Icons.chevron_right,
                '下一集',
                color: textPrimary,
                onTap: widget.onNextEpisode,
              ),
              const SizedBox(height: 20),
            ],
            // 11. 连播开关（Infinity，最底部）
            _buildAutoPlayButton(),
          ],
        ),
      ),
    );
  }

  /// 海报/头像展示区（TikTok 风格）
  Widget _buildPosterAvatar() {
    final authState = ref.watch(authProvider);
    final embyServerUrl = authState.embyServerUrl;
    final token = authState.token;
    final posterUrl = widget.item.imageUrl('Primary', embyServerUrl: embyServerUrl, apiKey: token, maxWidth: 200);
    return GestureDetector(
      onTap: _togglePlay,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0x66FFFFFF), width: 2),
          color: Colors.black26,
        ),
        child: ClipOval(
          child: posterUrl != null && posterUrl.isNotEmpty
              ? Image.network(
                  posterUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.music_video, color: Colors.white54, size: 24),
                )
              : const Icon(Icons.music_video, color: Colors.white54, size: 24),
        ),
      ),
    );
  }

  /// 信息按钮：展开/收起底部详情面板
  Widget _buildInfoButton() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isInfoExpanded = !_isInfoExpanded;
        });
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _isInfoExpanded
              ? const Color(0xCC4F46E5) // 靛蓝色
              : const Color(0x4D000000), // 30% 黑色
        ),
        child: const Icon(
          Icons.info_outline,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  /// 播放模式按钮：DirectPlay / Transcode / Fallback 循环切换
  Widget _buildPlayModeButton() {
    final currentLevel = ref.watch(playbackLevelProvider);
    // 0=Direct, 1=Transcode, 2=Fallback
    final String label = currentLevel == 0 ? 'Direct' : (currentLevel == 1 ? 'Transcode' : 'Fbk');
    final bool isHighlight = currentLevel != 0;
    return GestureDetector(
      onTap: () {
        final newLevel = (currentLevel + 1) % 3;
        ref.read(playbackLevelProvider.notifier).state = newLevel;
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isHighlight
              ? const Color(0xCC4F46E5) // 靛蓝色
              : const Color(0x4D000000),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  /// 字幕控制按钮：弹出字幕选择菜单
  Widget _buildSubtitleButton() {
    final subtitleSelected = ref.watch(selectedSubtitleProvider);
    final bool hasSubtitles = widget.item.subtitleTracks.isNotEmpty;
    final bool isEnabled = subtitleSelected != null;
    return GestureDetector(
      onTap: hasSubtitles
          ? () => _showSubtitleSelector()
          : null,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isEnabled
              ? const Color(0xCC4F46E5)
              : (hasSubtitles ? const Color(0x4D000000) : const Color(0x1A000000)),
        ),
        child: const Icon(
          Icons.subtitles,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }

  /// 弹出字幕选择器
  void _showSubtitleSelector() {
    final tracks = widget.item.subtitleTracks;
    if (tracks.isEmpty) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xE6000000),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('字幕选择', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ListTile(
                title: const Text('关闭字幕', style: TextStyle(color: Colors.white)),
                onTap: () {
                  ref.read(selectedSubtitleProvider.notifier).state = null;
                  Navigator.of(context).pop();
                },
              ),
              ...tracks.asMap().entries.map((entry) {
                final track = entry.value;
                return ListTile(
                  title: Text(track.displayName ?? '字幕 ${entry.key + 1}', style: const TextStyle(color: Colors.white)),
                  onTap: () {
                    ref.read(selectedSubtitleProvider.notifier).state = track.id;
                    Navigator.of(context).pop();
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  /// 唱片式静音按钮：播放时持续旋转，显示视频封面图，静音时红色边框
  Widget _buildDiscMuteButton() {
    final isMuted = ref.watch(isMutedProvider);
    final isPlaying = ref.watch(isPlayingProvider);
    // 获取认证信息用于构造带认证的封面图 URL
    final authState = ref.watch(authProvider);
    final embyServerUrl = authState.embyServerUrl;
    final token = authState.token;
    // 构造视频封面图 URL
    final posterUrl = widget.item.imageUrl('Primary', embyServerUrl, token);
    // 获取认证头
    final headers = widget.item.authHeaders(token);

    return GestureDetector(
      onTap: () {
        ref.read(isMutedProvider.notifier).toggle();
        _videoController?.setVolume(isMuted ? 1.0 : 0.0);
      },
      child: RotationTransition(
        turns: _discRotation,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0x4D000000),
            border: Border.all(
              color: isMuted ? const Color(0xFFFF2D55) : const Color(0x66FFFFFF),
              width: 2,
            ),
            // 如果有封面图 URL，设置背景图片
            image: posterUrl != null && posterUrl.isNotEmpty
                ? DecorationImage(
                    image: CachedNetworkImageProvider(
                      posterUrl,
                      headers: headers.isNotEmpty ? headers : null,
                    ),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          // 如果没有封面图，显示默认图标
          child: posterUrl == null || posterUrl.isEmpty
              ? Center(
                  child: Icon(
                    isMuted ? Icons.volume_off : Icons.music_note,
                    color: isMuted ? const Color(0xFFFF2D55) : Colors.white,
                    size: 24,
                  ),
                )
              : null,
        ),
      ),
    );
  }

  /// 切换播放/暂停（海报头像点击触发）
  void _togglePlay() {
    if (_videoController == null) return;
    if (_videoController!.value.isPlaying) {
      _videoController!.pause();
      ref.read(isPlayingProvider.notifier).state = false;
    } else {
      _videoController!.play();
      ref.read(isPlayingProvider.notifier).state = true;
    }
  }

  /// 纯净模式下的右侧按钮区：可拖动，仅保留连播开关和倍速调节
  Widget _buildCleanModeRightActions() {
    const double buttonWidth = 96.0;
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return _DraggableCleanActions(
            containerSize: Size(constraints.maxWidth, constraints.maxHeight),
            buttonWidth: buttonWidth,
            buttons: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAutoPlayButton(),
                const SizedBox(height: 20),
                _buildSpeedControlButton(),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 自动播放开关按钮（Infinity 图标，与 EmbyTok 原版一致）
  Widget _buildAutoPlayButton() {
    final isAutoPlay = ref.watch(isAutoPlayProvider);
    // 自动播放开启时绿色高亮，关闭时灰色半透明
    final isEnabled = isAutoPlay;
    return GestureDetector(
      onTap: () {
        final newState = !isAutoPlay;
        ref.read(isAutoPlayProvider.notifier).toggle();
        // 显示连播模式切换提示
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                newState ? '连播模式已开启' : '连播模式已关闭',
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: newState
                  ? const Color(0xCC4CAF50) // 绿色
                  : const Color(0xCC666666), // 灰色
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.only(bottom: 100, left: 20, right: 20),
            ),
          );
        }
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isEnabled
              ? const Color(0xCC4CAF50) // 80% 绿色
              : const Color(0x4D000000), // 30% 黑色
        ),
        child: const Icon(
          Icons.all_inclusive, // Infinity 图标
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }

  /// 倍速调节按钮：显示当前倍速，点击弹出调节面板（1x-10x）
  Widget _buildSpeedControlButton() {
    final currentSpeed = _videoController?.value.playbackSpeed ?? 1.0;
    return GestureDetector(
      onTap: _showSpeedControlPanel,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: currentSpeed > 1.0
              ? const Color(0xCCFF9800) // 橙色高亮
              : const Color(0x4D000000), // 30% 黑色
        ),
        child: Center(
          child: Text(
            '${currentSpeed.toStringAsFixed(1)}x',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  /// 显示倍速调节面板（BottomSheet + 滑块）
  void _showSpeedControlPanel() {
    final currentSpeed = _videoController?.value.playbackSpeed ?? 1.0;
    double selectedSpeed = currentSpeed;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xE6000000),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 标题
                  const Text(
                    '播放速度',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 当前速度显示
                  Text(
                    '${selectedSpeed.toStringAsFixed(1)}x',
                    style: const TextStyle(
                      color: Color(0xFFFF9800),
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 速度滑块 1x - 10x
                  Slider(
                    value: selectedSpeed,
                    min: 1.0,
                    max: 10.0,
                    divisions: 18, // 0.5 步进
                    activeColor: const Color(0xFFFF9800),
                    inactiveColor: Colors.white24,
                    onChanged: (value) {
                      setSheetState(() {
                        selectedSpeed = double.parse(value.toStringAsFixed(1));
                      });
                    },
                  ),
                  // 速度刻度标签
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('1x', style: TextStyle(color: textSecondary, fontSize: 12)),
                      Text('10x', style: TextStyle(color: textSecondary, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // 快捷速度按钮
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [1.0, 1.5, 2.0, 3.0].map((speed) {
                      final isSelected = selectedSpeed == speed;
                      return GestureDetector(
                        onTap: () {
                          setSheetState(() {
                            selectedSpeed = speed;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFFF9800)
                                : Colors.white12,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${speed}x',
                            style: TextStyle(
                              color: isSelected ? Colors.black : Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  // 确认按钮
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        // 应用选定的倍速
                        _videoController?.setPlaybackSpeed(selectedSpeed);
                        ref.read(playbackRateProvider.notifier).state = selectedSpeed;
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF9800),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Text(
                        '确定',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// 删除按钮（Trash2 图标，与 EmbyTok 原版一致）
  Widget _buildDeleteButton() {
    return _PressableActionButton(
      icon: Icons.delete_outline,
      label: '删除',
      color: Colors.red,
      onTap: _showDeleteConfirmDialog,
    );
  }

  /// 显示删除确认对话框
  Future<void> _showDeleteConfirmDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xE6000000),
        title: const Text(
          '确认删除',
          style: TextStyle(color: textPrimary),
        ),
        content: Text(
          '确定要从媒体库中删除 "${widget.item.title}" 吗？',
          style: const TextStyle(color: textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消', style: TextStyle(color: textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteItem();
    }
  }

  /// 执行删除操作
  Future<void> _deleteItem() async {
    try {
      final serverUrl = _authServerUrl();
      final token = _authToken();
      if (serverUrl == null || token == null) return;

      final service = EmbytokService();
      await service.deleteItem(
        itemId: widget.item.id,
        serverUrl: serverUrl,
        token: token,
      );

      // 删除成功后通知父组件刷新列表
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已删除'), duration: Duration(seconds: 2)),
        );
        // 通知播放下一条（相当于刷新列表）
        widget.onVideoEnded?.call();
      }
    } catch (e) {
      debugPrint('_deleteItem error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e'), duration: const Duration(seconds: 2)),
        );
      }
    }
  }

  /// 通用操作按钮：图标 + 标签，带按下缩放动画
  Widget _buildActionButton(
    IconData icon,
    String label, {
    Color? color,
    VoidCallback? onTap,
  }) {
    return _PressableActionButton(
      icon: icon,
      label: label,
      color: color ?? textPrimary,
      onTap: onTap,
    );
  }

  String _titleText() {
    if (widget.item.year != null) {
      return '${widget.item.title} (${widget.item.year})';
    }
    return widget.item.title;
  }
}

/// 带按下缩放动画的按钮（内部 Stateful 管理自己的按下状态）
/// 支持 TV 遥控器焦点高亮：获得焦点时显示粉色圆角边框 + 缩放 1.05
class _PressableActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _PressableActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  State<_PressableActionButton> createState() => _PressableActionButtonState();
}

class _PressableActionButtonState extends State<_PressableActionButton> {
  bool _pressed = false;
  late final FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'ActionButton_${widget.label}');
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    final focused = _focusNode.hasFocus;
    if (_isFocused != focused) {
      setState(() {
        _isFocused = focused;
      });
    }
  }

  // D-pad 确认键处理
  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.gameButtonA) {
      widget.onTap?.call();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    const duration = Duration(milliseconds: 120);
    // 焦点缩放优先级高于按下缩放
    final scale = _isFocused ? 1.05 : (_pressed ? 0.8 : 1.0);
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _onKeyEvent,
      child: GestureDetector(
        onTapDown: (_) {
          if (mounted) setState(() => _pressed = true);
        },
        onTapUp: (_) {
          if (mounted) setState(() => _pressed = false);
          widget.onTap?.call();
        },
        onTapCancel: () {
          if (mounted) setState(() => _pressed = false);
        },
        child: AnimatedScale(
          scale: scale,
          duration: duration,
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: duration,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: _isFocused
                  ? Border.all(color: primaryPink, width: 2)
                  : Border.all(color: Colors.transparent, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.icon,
                  color: widget.color,
                  size: 32,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.label,
                  style: const TextStyle(
                    color: textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// TikTok 风格底部细线进度条
/// 高度 2px，始终可见，颜色为品牌粉色，背景半透明黑色
class _ThinProgressBar extends StatefulWidget {
  final VideoPlayerController controller;

  const _ThinProgressBar({required this.controller});

  @override
  State<_ThinProgressBar> createState() => _ThinProgressBarState();
}

class _ThinProgressBarState extends State<_ThinProgressBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final duration = widget.controller.value.duration;
    final position = widget.controller.value.position;
    final progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      height: 2,
      width: double.infinity,
      color: const Color(0x4D000000), // 30% 不透明黑色背景
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress,
        child: Container(color: primaryPink),
      ),
    );
  }
}

/// 可拖动的纯净模式按钮区组件
class _DraggableCleanActions extends StatefulWidget {
  final Size containerSize;
  final double buttonWidth;
  final Widget buttons;

  const _DraggableCleanActions({
    required this.containerSize,
    required this.buttonWidth,
    required this.buttons,
  });

  @override
  _DraggableCleanActionsState createState() => _DraggableCleanActionsState();
}

class _DraggableCleanActionsState extends State<_DraggableCleanActions> {
  late Offset _offset;
  Offset? _startPointer;
  Offset? _startOffset;
  bool _isDragging = false;
  double _dragDistance = 0.0;

  static const double _kDragThreshold = 10.0;
  static const double _kScaleFactor = 1.1;
  static const int _kHeightApprox = 140;

  @override
  void initState() {
    super.initState();
    _offset = Offset(
      widget.containerSize.width - widget.buttonWidth,
      widget.containerSize.height / 2 - _kHeightApprox / 2,
    );
  }

  @override
  void didUpdateWidget(covariant _DraggableCleanActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.containerSize != widget.containerSize) {
      setState(() {
        _offset = Offset(
          _offset.dx.clamp(0.0, widget.containerSize.width - widget.buttonWidth),
          _offset.dy.clamp(0.0, widget.containerSize.height - _kHeightApprox),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: _offset.dx,
          top: _offset.dy,
          child: Listener(
            onPointerDown: (event) {
              _startPointer = event.localPosition;
              _startOffset = _offset;
              _dragDistance = 0.0;
            },
            onPointerMove: (event) {
              if (_startPointer == null || _startOffset == null) return;
              final delta = event.localPosition - _startPointer!;
              _dragDistance = delta.distance;

              if (!_isDragging && _dragDistance > _kDragThreshold) {
                setState(() {
                  _isDragging = true;
                });
              }

              if (_isDragging) {
                setState(() {
                  double newX = _startOffset!.dx + delta.dx;
                  double newY = _startOffset!.dy + delta.dy;
                  newX = newX.clamp(0.0, widget.containerSize.width - widget.buttonWidth);
                  newY = newY.clamp(0.0, widget.containerSize.height - _kHeightApprox);
                  _offset = Offset(newX, newY);
                });
              }
            },
            onPointerUp: (event) {
              _startPointer = null;
              _startOffset = null;
              if (_isDragging) {
                setState(() {
                  _isDragging = false;
                });
              }
              _dragDistance = 0.0;
            },
            child: IgnorePointer(
              ignoring: _isDragging,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                transform: Matrix4.identity()..scale(_isDragging ? _kScaleFactor : 1.0),
                child: Container(
                  width: widget.buttonWidth,
                  height: _kHeightApprox.toDouble(),
                  padding: const EdgeInsets.only(right: 16),
                  alignment: Alignment.centerRight,
                  decoration: _isDragging
                      ? const BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x40000000),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        )
                      : null,
                  child: widget.buttons,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
