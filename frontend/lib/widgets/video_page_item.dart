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
import 'subtitle_renderer.dart';
import 'video_controls.dart';
import 'video_player_widget.dart';
import '../views/person_detail_view.dart';

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

  // --- 底部信息条 3秒自动隐藏 ---
  Timer? _infoHideTimer;
  bool _isInfoVisible = true;
  bool _wasPlayingWhenHidden = false;

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

  // --- 底部信息条显示/隐藏控制 ---
  // 播放中 3 秒后自动隐藏，暂停时保持显示
  void _resetInfoHideTimer() {
    _infoHideTimer?.cancel();
    if (!mounted) return;
    setState(() => _isInfoVisible = true);
    final c = _videoController;
    final isPlaying = c != null && c.value.isInitialized && c.value.isPlaying;
    if (isPlaying) {
      _infoHideTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _isInfoVisible = false);
      });
    }
  }

  // 切换信息条显示（用于点击画面手动触发）
  void _toggleInfoBar() {
    _infoHideTimer?.cancel();
    if (!mounted) return;
    setState(() => _isInfoVisible = !_isInfoVisible);
    if (_isInfoVisible) {
      final c = _videoController;
      final isPlaying = c != null && c.value.isInitialized && c.value.isPlaying;
      if (isPlaying) {
        _infoHideTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) setState(() => _isInfoVisible = false);
        });
      }
    }
  }

  @override
  void dispose() {
    _infoHideTimer?.cancel();
    _discRotationCtrl.dispose();
    // 1. 清理 controller 的 ended 监听器
    _videoController?.removeListener(_onVideoChanged);
    // 2. 停止并清理播放进度上报定时器
    _progressTimer?.cancel();
    _progressTimer = null;
    // 3. 上报播放停止（带上当前播放位置）
    if (_hasStartedReported) {
      _reportPlaybackStopped();
    }
    // 4. 清理计时器
    _controlsHideTimer?.cancel();
    // 4b. 清理 NextUp 倒计时定时器
    _nextUpTimer?.cancel();
    _nextUpTimer = null;
    // 5. 退出时恢复竖屏方向（避免横屏状态残留）
    if (_isFullscreen) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
    // 6. 清理当前 item 的 ready 标记（用于下次再滑回来重新淡入）
    ref.read(videoReadyProvider.notifier).clear(widget.item.id);
    // 7. 清空 currentVideoControllerProvider
    final ctrl = ref.read(currentVideoControllerProvider);
    if (ctrl != null && identical(ctrl, _videoController)) {
      ref.read(currentVideoControllerProvider.notifier).state = null;
    }
    // 8. ⚠️ 注意：_videoController 由内部 VideoPlayerWidget 负责 dispose，
    //    这里只清空引用，避免双重 dispose 导致 MediaCodec 泄漏
    _videoController = null;
    // 9. 重置会话状态（用于下次进入重新生成新的播放会话）
    _capabilitiesReported = false;
    _hasStartedReported = false;
    _playSessionId = null;
    _hasNotifiedEnded = false;
    super.dispose();
  }

  // 视频状态变化监听（用于检测播放结束）
  void _onVideoChanged() {
    if (!mounted) return;
    final controller = _videoController;
    if (controller == null) return;
    // 播放结束检测（接近末尾 1 秒内就算播放完）
    if (!_hasNotifiedEnded) {
      final pos = controller.value.position;
      final dur = controller.value.duration;
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

  // 响应式尺寸计算：根据屏幕宽度返回缩放后的尺寸。
  // 手机端（<=480px）保持 1.0x，大屏手机/小平板（~800px）~1.3x，
  // 平板/桌面（~1200px）~1.6x，更大屏幕上限 1.7x。
  double responsiveSize(double base, [double maxScale = 1.7]) {
    final screenWidth = MediaQuery.of(context).size.width;
    final double scale;
    if (screenWidth <= 480.0) {
      scale = 1.0;
    } else if (screenWidth <= 800.0) {
      scale = 1.0 + ((screenWidth - 480.0) / 320.0) * 0.3;
    } else if (screenWidth <= 1200.0) {
      scale = 1.3 + ((screenWidth - 800.0) / 400.0) * 0.3;
    } else {
      scale = 1.6 + ((screenWidth - 1200.0) / 720.0) * 0.1;
    }
    return base * (scale > maxScale ? maxScale : scale);
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

    // 读取自动播放状态（用于纯净模式）
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
                // 启动底部信息条 3秒自动隐藏逻辑
                _resetInfoHideTimer();
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
                // 4. 监听播放状态：暂停上报 + 播放结束连播检测 + 信息条显示
                c.addListener(_onVideoChanged);
                c.addListener(() {
                  if (!mounted) return;
                  if (!c.value.isPlaying) {
                    _reportPlaybackProgress(isPauseEvent: true);
                  }
                  // 根据播放状态更新信息条显示
                  _resetInfoHideTimer();
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

        // 顶部操作区：右上角全屏按钮（所有模式下都显示）
        _buildTopActions(),

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
          color: Theme.of(context).colorScheme.surface,
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
            width: responsiveSize(60),
            height: responsiveSize(60),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withOpacity(0.6),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.play_arrow,
              color: Theme.of(context).colorScheme.onSurface,
              size: responsiveSize(40),
            ),
          ),
        ),
      ),
    );
  }

  // 倍速状态徽章：当播放速度 > 1x 时显示在右上角（与 EmbyTok 原版一致）
  Widget _buildSpeedBadge(double speed) {
    final scheme = Theme.of(context).colorScheme;
    return Positioned(
      top: responsiveSize(40),
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: responsiveSize(12), vertical: responsiveSize(6)),
          decoration: BoxDecoration(
            // 背景色：深色半透明（原 Colors.black87）
            color: scheme.surface.withOpacity(0.87),
            borderRadius: BorderRadius.circular(responsiveSize(16)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.flash_on,
                // 金色图标用 tertiary（自动生成的第三色）
                color: scheme.tertiary,
                size: responsiveSize(14),
              ),
              SizedBox(width: responsiveSize(4)),
              Text(
                '${speed.toStringAsFixed(1)}x',
                style: TextStyle(
                  // 文字色：白色（原 Colors.white）
                  color: scheme.onSurface,
                  fontSize: responsiveSize(12, 1.3),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
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

    final scheme = Theme.of(context).colorScheme;
    return Positioned(
      left: 16,
      right: 16,
      bottom: bottomPadding + kBottomNavHeight + 16,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            // 深色 90% 不透明（原 Color(0xE6000000)）
            color: scheme.surface.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.primary, width: 1),
          ),
          child: Row(
            children: [
              // 左侧：下一集图标 + 标题信息
              Icon(Icons.skip_next, color: scheme.primary, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '即将播放下一集',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      nextTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurface,
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
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_nextUpCountdown}s',
                  style: TextStyle(
                    color: scheme.onPrimary,
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
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '立即播放',
                    style: TextStyle(
                      color: scheme.onPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              // 取消按钮
              IconButton(
                icon: Icon(Icons.close, color: scheme.onSurfaceVariant, size: 20),
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
  // 新增：播放中 3 秒后自动隐藏，暂停时保持显示（通过 AnimatedOpacity）
  Widget _buildBottomGradient() {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final toolbarVisible = ref.watch(toolbarVisibilityProvider);
    final scheme = Theme.of(context).colorScheme;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: AnimatedOpacity(
        opacity: _isInfoVisible ? 1.0 : 0.0,
        duration: Duration(milliseconds: _isInfoVisible ? 300 : 500),
        curve: Curves.easeOut,
        child: Container(
          padding: EdgeInsets.fromLTRB(
            16,
            80,
            96,
            toolbarVisible
                ? kBottomNavHeight + bottomPadding + 24
                : bottomPadding + 24,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  scheme.surface.withOpacity(0.8),
                  scheme.surface.withOpacity(0.5),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
          ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.item.type,
                style: TextStyle(
                  color: scheme.onPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    _titleText(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                if (widget.item.displayRating != null && widget.item.displayRating! > 0)
                  Text(
                    '★ ${widget.item.displayRating!.toStringAsFixed(1)}',
                    style: TextStyle(
                      color: scheme.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            if (widget.item.overview != null && widget.item.overview!.isNotEmpty)
              Text(
                widget.item.overview!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
            // 可拖拽进度条 + 时间显示
            if (_videoController != null && _videoController!.value.isInitialized)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _SeekableProgressBar(
                  controller: _videoController!,
                  formatDuration: _formatDuration,
                ),
              ),
          ],
        ),
        ),
      ),
    );
  }

  // 右侧操作按钮列：与 React 版 EmbyTok 对齐
  // 顺序（从上至下）：连播 ∞ → 演员头像/海报 → 点赞 ❤️ → 信息 ℹ️ → 删除 🗑️ → 倍速 → 播放模式 → 字幕 → 唱片/静音 💿 → 全屏 → 下一集
  Widget _buildRightActions(bool favorited) {
    final isMuted = ref.watch(isMutedProvider);
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final toolbarVisible = ref.watch(toolbarVisibilityProvider);
    final subtitleSelected = ref.watch(selectedSubtitleProvider);
    final playMode = ref.watch(playbackLevelProvider);
    final actionButtonSize = responsiveSize(40);
    final scheme = Theme.of(context).colorScheme;

    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      width: responsiveSize(80, 2.0),
      child: Container(
        padding: EdgeInsets.fromLTRB(
          0,
          toolbarVisible
              ? topPadding + responsiveSize(48) + responsiveSize(32)
              : topPadding + responsiveSize(32),
          responsiveSize(6),
          responsiveSize(20, 1.3) + bottomPadding,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            colors: [
              scheme.surface.withOpacity(0.54),
              Colors.transparent,
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _buildAutoPlayButton(),
            SizedBox(height: responsiveSize(16, 1.5)),
            _buildPosterAvatar(),
            SizedBox(height: responsiveSize(16, 1.5)),
            // 点赞
            _buildActionButton(
              favorited ? Icons.favorite : Icons.favorite_border,
              '点赞',
              color: favorited ? scheme.primary : scheme.onSurface,
              onTap: () => ref.read(favoritesProvider.notifier).toggleFavorite(widget.item),
            ),
            SizedBox(height: responsiveSize(16, 1.5)),
            _buildInfoButton(),
            SizedBox(height: responsiveSize(16, 1.5)),
            _buildDeleteButton(),
            SizedBox(height: responsiveSize(16, 1.5)),
            _buildSpeedControlButton(),
            SizedBox(height: responsiveSize(16, 1.5)),
            _buildPlayModeButton(),
            SizedBox(height: responsiveSize(16, 1.5)),
            _buildSubtitleButton(),
            SizedBox(height: responsiveSize(16, 1.5)),
            _buildDiscMuteButton(),
            SizedBox(height: responsiveSize(16, 1.5)),
            // 下一集（仅剧集类）
            if (widget.onNextEpisode != null) ...[
              _buildActionButton(
                Icons.chevron_right,
                '下一集',
                color: scheme.onSurface,
                onTap: widget.onNextEpisode,
              ),
              SizedBox(height: responsiveSize(16, 1.5)),
            ],
          ],
        ),
      ),
    );
  }

  /// 演员头像按钮（TikTok 风格）- 显示演员头像 + 收藏 + 按钮
  Widget _buildPosterAvatar() {
    final authState = ref.watch(authProvider);
    final embyServerUrl = authState.embyServerUrl;
    final token = authState.token;
    final scheme = Theme.of(context).colorScheme;

    // 从 people 列表中查找第一个 Actor
    final people = widget.item.people;
    final Person? firstActor = people != null && people.isNotEmpty
        ? people.firstWhere((p) => p.type.toLowerCase() == 'actor', orElse: () => people.first)
        : null;

    // 有演员信息：显示演员头像 + 收藏按钮
    if (firstActor != null && firstActor.id != null && firstActor.id!.isNotEmpty) {
      // 构造演员头像 URL
      final actorImageUrl = embyServerUrl != null && token != null
          ? '$embyServerUrl/Items/${firstActor.id}/Images/Primary?MaxWidth=200&api_key=$token'
          : (firstActor.imageUrl);

      final headers = widget.item.authHeaders(token);
      final isFavorited = ref.watch(favoritesProvider).favoriteIds.contains(firstActor.id!);

      // 构造 MediaItem（用于收藏和跳转到详情页）
      final actorMediaItem = MediaItem(
        id: firstActor.id!,
        title: firstActor.name,
        type: 'Person',
        imageTags: {'Primary': firstActor.imageUrl ?? 'primary'},
      );

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 圆形头像 + 收藏按钮
          SizedBox(
            width: responsiveSize(48),
            height: responsiveSize(48),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 演员头像
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PersonDetailView(person: actorMediaItem),
                        ),
                      );
                    },
                    child: Container(
                      width: responsiveSize(48),
                      height: responsiveSize(48),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: scheme.onSurface.withOpacity(0.4), width: 2),
                        color: scheme.surface.withOpacity(0.15),
                      ),
                      child: ClipOval(
                        child: actorImageUrl != null && actorImageUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: actorImageUrl,
                                fit: BoxFit.cover,
                                httpHeaders: headers.isNotEmpty ? headers : null,
                                placeholder: (_, __) => Icon(Icons.person, color: scheme.onSurface.withOpacity(0.54), size: responsiveSize(24)),
                                errorWidget: (_, __, ___) => Icon(Icons.person, color: scheme.onSurface.withOpacity(0.54), size: responsiveSize(24)),
                              )
                            : Icon(Icons.person, color: scheme.onSurface.withOpacity(0.54), size: responsiveSize(24)),
                      ),
                    ),
                  ),
                ),
                // 收藏 "+"按钮（右下角悬浮）
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onTap: () {
                      ref.read(favoritesProvider.notifier).toggleFavorite(actorMediaItem);
                    },
                    child: Container(
                      width: responsiveSize(20),
                      height: responsiveSize(20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scheme.tertiary,
                        border: Border.all(color: scheme.onSurface, width: 1.5),
                      ),
                      child: Icon(
                        isFavorited ? Icons.check : Icons.add,
                        color: scheme.onTertiary,
                        size: responsiveSize(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 演员名字（短名）
          SizedBox(height: responsiveSize(4)),
          Text(
            firstActor.name.length > 4 ? '${firstActor.name.substring(0, 4)}..' : firstActor.name,
            style: TextStyle(
              color: scheme.onSurface.withOpacity(0.7),
              fontSize: responsiveSize(9, 1.3),
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    }

    // 回退：无演员信息时显示视频封面，点击播放/暂停
    final posterUrl = widget.item.imageUrl('Primary', embyServerUrl: embyServerUrl, apiKey: token, maxWidth: 200);
    final posterHeaders = widget.item.authHeaders(token);
    return GestureDetector(
      onTap: _togglePlay,
      child: Container(
        width: responsiveSize(40),
        height: responsiveSize(40),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: scheme.onSurface.withOpacity(0.4), width: 2),
          color: scheme.surface.withOpacity(0.15),
        ),
        child: ClipOval(
          child: posterUrl != null && posterUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: posterUrl,
                  fit: BoxFit.cover,
                  httpHeaders: posterHeaders.isNotEmpty ? posterHeaders : null,
                  placeholder: (_, __) => Icon(Icons.music_video, color: scheme.onSurface.withOpacity(0.54), size: responsiveSize(20)),
                  errorWidget: (_, __, ___) => Icon(Icons.music_video, color: scheme.onSurface.withOpacity(0.54), size: responsiveSize(20)),
                )
              : Icon(Icons.music_video, color: scheme.onSurface.withOpacity(0.54), size: responsiveSize(20)),
        ),
      ),
    );
  }

  /// 信息按钮：点击弹出底部详情面板，展示视频元信息
  Widget _buildInfoButton() {
    final scheme = Theme.of(context).colorScheme;
    return _PressableActionButton(
      icon: Icons.info_outline,
      label: '信息',
      color: scheme.onSurface,
      onTap: () {
        setState(() {
          _isInfoExpanded = !_isInfoExpanded;
        });
        _showVideoInfoSheet();
      },
    );
  }

  /// 弹出底部信息面板：展示标题、年份、类型、时长、评分、简介、演员/导演等
  void _showVideoInfoSheet() {
    final item = widget.item;
    final type = item.type;
    final year = item.displayYear;
    final duration = item.formattedDuration;
    final rating = item.displayRating;
    final genres = item.displayGenres;
    final studios = item.studioNames;
    final overview = item.overview;
    final people = item.people;
    final scheme = Theme.of(context).colorScheme;

    // 剧集信息
    final isEpisode = type == 'Episode' ||
        (item.seriesName != null && item.seriesName!.isNotEmpty);

    // 分类显示人员：前 5 位演员 + 导演/编剧
    List<Person>? actors;
    List<Person>? directors;
    if (people != null && people.isNotEmpty) {
      actors = people
          .where((p) => p.type.toLowerCase() == 'actor')
          .take(5)
          .toList();
      directors = people
          .where((p) => p.type.toLowerCase().contains('director'))
          .take(3)
          .toList();
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: scheme.surface.withOpacity(0.9),
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: ListView(
                controller: scrollController,
                children: [
                  // 顶部小把手（指示可下滑关闭）
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: scheme.onSurface.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 标题
                  Text(
                    item.title,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 副标题：类型 + 年份 + 剧集信息
                  _buildInfoSubtitle(
                    type: type,
                    year: year,
                    isEpisode: isEpisode,
                    seriesName: item.seriesName,
                    season: item.parentIndexNumber,
                    episode: item.indexNumber,
                  ),
                  const SizedBox(height: 20),

                  // 基本信息行（时长、评分、类型、工作室）
                  _buildInfoRowItems(
                    duration: duration,
                    rating: rating,
                    genres: genres,
                    studios: studios,
                  ),
                  const SizedBox(height: 24),

                  // 简介
                  if (overview != null && overview.isNotEmpty) ...[
                    _SectionLabel('简介', color: scheme.onSurface),
                    const SizedBox(height: 8),
                    Text(
                      overview,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // 主要演员
                  if (actors != null && actors.isNotEmpty) ...[
                    _SectionLabel('主演', color: scheme.onSurface),
                    const SizedBox(height: 8),
                    _buildPeopleChips(actors),
                    const SizedBox(height: 24),
                  ],

                  // 导演
                  if (directors != null && directors.isNotEmpty) ...[
                    _SectionLabel('导演', color: scheme.onSurface),
                    const SizedBox(height: 8),
                    _buildPeopleChips(directors),
                    const SizedBox(height: 24),
                  ],

                  // 底部占位（避免紧贴导航栏）
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 副标题行：类型标签 + 年份 + 剧集信息
  Widget _buildInfoSubtitle({
    required String type,
    required int? year,
    required bool isEpisode,
    required String? seriesName,
    required int? season,
    required int? episode,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final children = <Widget>[];

    // 类型标签
    children.add(
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: scheme.primary.withOpacity(0.18),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          type,
          style: TextStyle(
            color: scheme.primary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );

    // 年份
    if (year != null) {
      children.addAll([
        const SizedBox(width: 8),
        Text(
          year.toString(),
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
      ]);
    }

    // 剧集信息
    if (isEpisode) {
      if (seriesName != null && seriesName.isNotEmpty) {
        children.addAll([
          const SizedBox(width: 8),
          Text(
            '·',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              seriesName,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ]);
      }
      if (season != null || episode != null) {
        final s = season != null ? 'S$season' : '';
        final e = episode != null ? 'E$episode' : '';
        children.addAll([
          if (children.length > 1) const SizedBox(width: 8),
          Text(
            '$s$e',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        ]);
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: children,
    );
  }

  // 基本信息卡片行：时长 / 评分 / 类型 / 工作室
  Widget _buildInfoRowItems({
    required String duration,
    required double? rating,
    required List<String> genres,
    required List<String>? studios,
  }) {
    final widgets = <Widget>[];

    if (duration.isNotEmpty) {
      widgets.add(_InfoChip(label: '时长', value: duration));
    }
    if (rating != null && rating > 0) {
      widgets.add(_InfoChip(
        label: '评分',
        value: '★ ${rating.toStringAsFixed(1)}',
        highlight: true,
      ));
    }
    if (genres.isNotEmpty) {
      widgets.add(_InfoChip(
        label: '类型',
        value: genres.take(3).join(' / '),
      ));
    }
    if (studios != null && studios.isNotEmpty) {
      widgets.add(_InfoChip(
        label: '出品',
        value: studios.first,
      ));
    }

    if (widgets.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 12,
      runSpacing: 10,
      children: widgets,
    );
  }

  // 人员 chips（如演员、导演）
  Widget _buildPeopleChips(List<Person> people) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: people.map((p) {
        final display =
            p.role != null && p.role!.isNotEmpty && p.role != p.name
                ? '${p.name} (${p.role})'
                : p.name;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: scheme.surface.withOpacity(0.25),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            display,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 13,
            ),
          ),
        );
      }).toList(),
    );
  }


  /// 播放模式按钮：DirectPlay / Transcode / Fallback 循环切换
  Widget _buildPlayModeButton() {
    final currentLevel = ref.watch(playbackLevelProvider);
    final scheme = Theme.of(context).colorScheme;
    // 0=Direct, 1=Transcode, 2=Fallback
    final IconData icon;
    final Color bgColor;
    switch (currentLevel) {
      case 0:
        icon = Icons.play_circle_outline;
        bgColor = scheme.surface.withOpacity(0.3);
        break;
      case 1:
        icon = Icons.swap_horiz;
        bgColor = scheme.primary.withOpacity(0.8);
        break;
      case 2:
      default:
        icon = Icons.warning;
        bgColor = scheme.tertiary.withOpacity(0.8);
        break;
    }
    return GestureDetector(
      onTap: () {
        final newLevel = (currentLevel + 1) % 3;
        ref.read(playbackLevelProvider.notifier).state = newLevel;
      },
      child: Container(
        width: responsiveSize(40),
        height: responsiveSize(40),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bgColor,
        ),
        child: Center(
          child: Icon(
            icon,
            color: scheme.onSurface,
            size: responsiveSize(20),
          ),
        ),
      ),
    );
  }

  /// 字幕控制按钮：弹出字幕选择菜单
  Widget _buildSubtitleButton() {
    final subtitleSelected = ref.watch(selectedSubtitleProvider);
    final scheme = Theme.of(context).colorScheme;
    final bool hasSubtitles = widget.item.subtitleTracks.isNotEmpty;
    final bool isEnabled = subtitleSelected != null;
    return GestureDetector(
      onTap: hasSubtitles
          ? () => _showSubtitleSelector()
          : null,
      child: Container(
        width: responsiveSize(40),
        height: responsiveSize(40),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isEnabled
              ? scheme.primary.withOpacity(0.8)
              : (hasSubtitles ? scheme.surface.withOpacity(0.3) : scheme.surface.withOpacity(0.1)),
        ),
        child: Icon(
          Icons.subtitles,
          color: scheme.onSurface,
          size: responsiveSize(20),
        ),
      ),
    );
  }

  /// 弹出字幕选择器
  void _showSubtitleSelector() {
    final tracks = widget.item.subtitleTracks;
    final scheme = Theme.of(context).colorScheme;
    if (tracks.isEmpty) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: scheme.surface.withOpacity(0.9),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('字幕选择', style: TextStyle(color: scheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ListTile(
                title: Text('关闭字幕', style: TextStyle(color: scheme.onSurface)),
                onTap: () {
                  ref.read(selectedSubtitleProvider.notifier).state = null;
                  Navigator.of(context).pop();
                },
              ),
              ...tracks.asMap().entries.map((entry) {
                final track = entry.value;
                return ListTile(
                  title: Text(track.displayName ?? '字幕 ${entry.key + 1}', style: TextStyle(color: scheme.onSurface)),
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
    final authState = ref.watch(authProvider);
    final embyServerUrl = authState.embyServerUrl;
    final token = authState.token;
    final scheme = Theme.of(context).colorScheme;
    final posterUrl = widget.item.primaryUrl(embyServerUrl: embyServerUrl, apiKey: token);
    final headers = widget.item.authHeaders(token);

    return GestureDetector(
      onTap: () {
        ref.read(isMutedProvider.notifier).toggle();
        _videoController?.setVolume(isMuted ? 1.0 : 0.0);
      },
      child: RotationTransition(
        turns: _discRotation,
        child: Container(
          width: responsiveSize(40),
          height: responsiveSize(40),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: scheme.surface.withOpacity(0.3),
            border: Border.all(
              color: isMuted ? scheme.primary : scheme.onSurface.withOpacity(0.4),
              width: 2,
            ),
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
          child: posterUrl == null || posterUrl.isEmpty
              ? Center(
                  child: Icon(
                    isMuted ? Icons.volume_off : Icons.music_note,
                    color: isMuted ? scheme.primary : scheme.onSurface,
                    size: responsiveSize(20),
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

  /// 顶部操作区：悬浮在视频容器右上角，包含全屏/退出全屏按钮
  /// 统一横屏和竖屏模式下的全屏切换入口
  Widget _buildTopActions() {
    final topPadding = MediaQuery.of(context).padding.top;
    final buttonSize = responsiveSize(40);
    final padding = responsiveSize(8);
    final scheme = Theme.of(context).colorScheme;

    return Positioned(
      top: topPadding + 8,
      right: 16,
      child: AnimatedOpacity(
        opacity: 1.0,
        duration: const Duration(milliseconds: 200),
        child: GestureDetector(
          onTap: _toggleFullscreen,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              color: scheme.surface.withOpacity(0.4),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: scheme.onSurface.withOpacity(0.15),
                  blurRadius: 8,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Icon(
              _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
              color: textPrimary,
              size: buttonSize,
            ),
          ),
        ),
      ),
    );
  }

  /// 纯净模式下的浮层按钮区：可拖动，初始位置在右下角
  /// 包含连播开关（∞）和倍速调节
  Widget _buildCleanModeRightActions() {
    final double buttonWidth = responsiveSize(80, 2.0);
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return _DraggableCleanActions(
            containerSize: Size(constraints.maxWidth, constraints.maxHeight),
            buttonWidth: buttonWidth,
            // 底部安全区：底部导航栏高度 + 系统手势条高度 + 16px 边距
            bottomSafeArea: bottomPadding + kBottomNavHeight + 16,
            // 右侧安全区：16px 边距
            rightSafeArea: 16,
            // 按钮包裹在半透明卡片中（使用语义色）
            buttons: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withOpacity(0.4),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildAutoPlayButton(),
                  SizedBox(height: responsiveSize(16, 1.5)),
                  _buildSpeedControlButton(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 自动播放开关按钮（Infinity 图标，与 EmbyTok 原版一致）
  Widget _buildAutoPlayButton() {
    final isAutoPlay = ref.watch(isAutoPlayProvider);
    final scheme = Theme.of(context).colorScheme;
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
                style: TextStyle(color: scheme.onPrimary),
              ),
              backgroundColor: newState
                  ? scheme.primary.withOpacity(0.8)
                  : scheme.onSurface.withOpacity(0.6),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.only(bottom: 100, left: 20, right: 20),
            ),
          );
        }
      },
      child: Container(
        width: responsiveSize(40),
        height: responsiveSize(40),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isEnabled
              ? scheme.primary.withOpacity(0.8)
              : scheme.surface.withOpacity(0.3),
        ),
        child: Icon(
          Icons.all_inclusive,
          color: scheme.onSurface,
          size: responsiveSize(24),
        ),
      ),
    );
  }

  /// 倍速调节按钮：显示当前倍速，点击弹出调节面板（1x-10x）
  Widget _buildSpeedControlButton() {
    final currentSpeed = _videoController?.value.playbackSpeed ?? 1.0;
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: _showSpeedControlPanel,
      child: Container(
        width: responsiveSize(40),
        height: responsiveSize(40),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: currentSpeed > 1.0
              ? scheme.tertiary.withOpacity(0.8)
              : scheme.surface.withOpacity(0.3),
        ),
        child: Icon(
          Icons.speed,
          color: scheme.onSurface,
          size: responsiveSize(20),
        ),
      ),
    );
  }

  /// 显示倍速调节面板（BottomSheet + 滑块）
  void _showSpeedControlPanel() {
    final currentSpeed = _videoController?.value.playbackSpeed ?? 1.0;
    double selectedSpeed = currentSpeed;
    final scheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: scheme.surface.withOpacity(0.9),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 标题
                  Text(
                    '播放速度',
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 当前速度显示
                  Text(
                    '${selectedSpeed.toStringAsFixed(1)}x',
                    style: TextStyle(
                      color: scheme.tertiary,
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
                    activeColor: scheme.tertiary,
                    inactiveColor: scheme.onSurface.withOpacity(0.2),
                    onChanged: (value) {
                      setSheetState(() {
                        selectedSpeed = double.parse(value.toStringAsFixed(1));
                      });
                    },
                  ),
                  // 速度刻度标签
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('1x', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                      Text('10x', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
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
                                ? scheme.tertiary
                                : scheme.onSurface.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${speed}x',
                            style: TextStyle(
                              color: isSelected ? scheme.onTertiary : scheme.onSurface,
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
                        backgroundColor: scheme.primary,
                        foregroundColor: scheme.onPrimary,
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
    final scheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: scheme.surface.withOpacity(0.9),
        title: Text(
          '确认删除',
          style: TextStyle(color: scheme.onSurface),
        ),
        content: Text(
          '确定要从媒体库中删除 "${widget.item.title}" 吗？',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('取消', style: TextStyle(color: scheme.onSurfaceVariant)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('删除', style: TextStyle(color: scheme.error)),
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

  /// Duration 格式化为 mm:ss 或 h:mm:ss
  String _formatDuration(Duration duration) {
    if (duration.inSeconds <= 0) return '0:00';
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours >= 1) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
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
    // 响应式尺寸计算（与 _VideoPageItemState.responsiveSize 相同逻辑）
    final screenWidth = MediaQuery.of(context).size.width;
    final double sizeScale;
    if (screenWidth <= 480.0) {
      sizeScale = 1.0;
    } else if (screenWidth <= 800.0) {
      sizeScale = 1.0 + ((screenWidth - 480.0) / 320.0) * 0.3;
    } else if (screenWidth <= 1200.0) {
      sizeScale = 1.3 + ((screenWidth - 800.0) / 400.0) * 0.3;
    } else {
      sizeScale = 1.6 + ((screenWidth - 1200.0) / 720.0) * 0.1;
    }
    double rs(double base, [double maxScale = 1.7]) =>
        base * (sizeScale > maxScale ? maxScale : sizeScale);

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
            padding: EdgeInsets.all(rs(4)),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(rs(6)),
              border: _isFocused
                  ? Border.all(color: primaryPink, width: 2)
                  : Border.all(color: Colors.transparent, width: 2),
            ),
            child: Icon(
              widget.icon,
              color: widget.color,
              size: rs(26),
            ),
          ),
        ),
      ),
    );
  }
}

/// 信息面板中的分节标题（如"简介"、"主演"、"导演"）
class _SectionLabel extends StatelessWidget {
  final String text;
  final Color? color;

  const _SectionLabel(this.text, {this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: color ?? Theme.of(context).colorScheme.onSurface,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

/// 信息面板中的小卡片（时长、评分、类型、出品等）
class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _InfoChip({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(10),
        border: highlight
            ? Border.all(color: primaryPink.withOpacity(0.45))
            : null,
      ),
      constraints: const BoxConstraints(minWidth: 80),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: highlight ? primaryPink : textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
    final scheme = Theme.of(context).colorScheme;
    final duration = widget.controller.value.duration;
    final position = widget.controller.value.position;
    final progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      height: 2,
      width: double.infinity,
      color: scheme.surface.withOpacity(0.3),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress,
        child: Container(color: scheme.primary),
      ),
    );
  }
}

/// 可点击/可拖拽的进度条，用于底部信息条
/// 支持点击跳转和水平拖拽 seek
class _SeekableProgressBar extends StatefulWidget {
  final VideoPlayerController controller;
  final String Function(Duration) formatDuration;

  const _SeekableProgressBar({
    required this.controller,
    required this.formatDuration,
  });

  @override
  State<_SeekableProgressBar> createState() => _SeekableProgressBarState();
}

class _SeekableProgressBarState extends State<_SeekableProgressBar> {
  double _dragProgress = 0.0;
  bool _isDragging = false;

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
    if (!mounted) return;
    setState(() {});
  }

  /// 根据水平点击/拖拽位置计算进度百分比并执行 seek
  void _seekToPosition(double localDx, double totalWidth) {
    final duration = widget.controller.value.duration;
    if (duration.inMilliseconds <= 0) return;

    double progress = (localDx / totalWidth).clamp(0.0, 1.0);
    final targetMs = (progress * duration.inMilliseconds).toInt();
    widget.controller.seekTo(Duration(milliseconds: targetMs));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final duration = widget.controller.value.duration;
    final position = widget.controller.value.position;
    final progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    final displayProgress = _isDragging ? _dragProgress : progress;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final barHeight = 12.0; // 更大的点击/拖拽区域
        final indicatorRadius = 6.0;
        final currentTime = widget.formatDuration(position);
        final totalTime = widget.formatDuration(duration);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 进度条区域（可点击/拖拽）
            GestureDetector(
              onTapDown: (details) {
                // 点击跳转
                final localDx = details.localPosition.dx;
                _seekToPosition(localDx, totalWidth);
              },
              onHorizontalDragStart: (details) {
                setState(() {
                  _isDragging = true;
                });
                _seekToPosition(details.localPosition.dx, totalWidth);
              },
              onHorizontalDragUpdate: (details) {
                final localDx = details.localPosition.dx;
                final newProgress = (localDx / totalWidth).clamp(0.0, 1.0);
                setState(() {
                  _dragProgress = newProgress;
                });
                _seekToPosition(localDx, totalWidth);
              },
              onHorizontalDragEnd: (details) {
                setState(() {
                  _isDragging = false;
                });
              },
              child: Container(
                height: barHeight,
                width: totalWidth,
                color: Colors.transparent, // 透明背景，使手势可检测
                alignment: Alignment.center,
                child: Container(
                  height: 4,
                  width: totalWidth,
                  decoration: BoxDecoration(
                    color: scheme.onSurface.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Stack(
                    children: [
                      // 已播放部分（粉色）
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: displayProgress,
                        child: Container(
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      // 拖拽小圆点指示器
                      Positioned(
                        left: (displayProgress * totalWidth)
                            .clamp(0.0, totalWidth - indicatorRadius * 2) - indicatorRadius,
                        top: barHeight / 2 - indicatorRadius,
                        child: Container(
                          width: indicatorRadius * 2,
                          height: indicatorRadius * 2,
                          decoration: BoxDecoration(
                            color: _isDragging ? scheme.primary : scheme.onSurface,
                            shape: BoxShape.circle,
                            boxShadow: _isDragging
                                ? [
                                    BoxShadow(
                                      color: scheme.primary.withOpacity(0.5),
                                      blurRadius: 6,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // 时间显示（当前时间 / 总时长）
            SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                '$currentTime / $totalTime',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.left,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 可拖动的纯净模式按钮区组件
/// 初始位置：屏幕右下角（受 bottomSafeArea 和 rightSafeArea 约束）
class _DraggableCleanActions extends StatefulWidget {
  final Size containerSize;
  final double buttonWidth;
  final Widget buttons;
  final double bottomSafeArea; // 底部安全区（导航栏 + 手势条 + 边距）
  final double rightSafeArea;  // 右侧安全区（边距）

  const _DraggableCleanActions({
    required this.containerSize,
    required this.buttonWidth,
    required this.buttons,
    this.bottomSafeArea = 100,  // 默认底部 100px 安全区
    this.rightSafeArea = 16,    // 默认右侧 16px 边距
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
  double _opacity = 0.0; // 渐入动画的不透明度初始值

  static const double _kDragThreshold = 10.0;
  static const double _kScaleFactor = 1.1;
  static const int _kHeightApprox = 140;

  @override
  void initState() {
    super.initState();
    // 初始位置：屏幕右下角，距离底部 = bottomSafeArea，距离右侧 = rightSafeArea
    _offset = Offset(
      widget.containerSize.width - widget.buttonWidth - widget.rightSafeArea,
      widget.containerSize.height - _kHeightApprox - widget.bottomSafeArea,
    );
    // 首帧绘制完成后触发渐入动画（200ms）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _opacity = 1.0);
      }
    });
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
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        // AnimatedPositioned: 位置变化有平滑过渡（如屏幕旋转时）
        // AnimatedOpacity: 出现时渐入动画（200ms，由 _opacity 控制）
        AnimatedPositioned(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          left: _offset.dx,
          top: _offset.dy,
          child: AnimatedOpacity(
            opacity: _opacity,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
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
                        ? BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: scheme.onSurface.withOpacity(0.25),
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
        ),
      ],
    );
  }
}
