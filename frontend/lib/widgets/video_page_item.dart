// 视频流单页：全屏视频 + 右侧操作按钮 + 左下角标题信息
// 新增：完整 Emby 播放上报链（reportCapabilities / reportPlaybackStart /
//       reportPlaybackPosition / reportPlaybackStopped），保持与 EmbyX 的
//       服务端统计对齐。

import 'dart:async';

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

class _VideoPageItemState extends ConsumerState<VideoPageItem> {
  VideoPlayerController? _videoController;
  bool _hasNotifiedEnded = false;  // 防止重复触发 onVideoEnded
  // 预加载控制器缓存：保持对下一条视频的 controller，当 widget 切换时复用

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
  void dispose() {
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

        // 控制层（VideoControls）：可隐藏，3 秒无操作自动淡出
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

        // 底部渐变 + 标题/简介/类型标签（横屏全屏模式下隐藏）
        if (!_isFullscreen) _buildBottomGradient(),

        // 右侧渐变 + 操作按钮（横屏全屏模式下隐藏）
        if (!_isFullscreen) _buildRightActions(favorited),

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

  // 右侧操作按钮列：静音 / 点赞 / 收藏 / 评论 / 分享
  // 动态 padding：顶部工具栏可见时向下偏移 kAppToolbarHeight，避开半透明工具栏
  Widget _buildRightActions(bool favorited) {
    final isMuted = ref.watch(isMutedProvider);
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final toolbarVisible = ref.watch(toolbarVisibilityProvider);

    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      width: 96,
      child: Container(
        // 顶部距离：工具栏可见时 = 顶部安全区 + 工具栏高度 + 40px；隐藏时 = 安全区 + 40px
        padding: EdgeInsets.fromLTRB(
          0,
          toolbarVisible
              ? topPadding + kAppToolbarHeight + 40
              : topPadding + 40,
          8,
          24 + bottomPadding,
        ),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            colors: [
              black54,
              Colors.transparent,  // 透明是 Flutter 自带常量
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // 上一集 / 下一集 按钮（仅对有 seriesName 的剧集启用）
            if (widget.onNextEpisode != null) ...[
              _buildActionButton(
                Icons.chevron_right,
                '下一集',
                color: textPrimary,
                onTap: widget.onNextEpisode,
              ),
              const SizedBox(height: 20),
            ],
            _buildActionButton(
              _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
              _isFullscreen ? '退出' : '全屏',
              color: textPrimary,
              onTap: _toggleFullscreen,
            ),
            const SizedBox(height: 20),
            _buildActionButton(
              isMuted ? Icons.volume_off : Icons.volume_up,
              isMuted ? '静音' : '音量',
              color: isMuted ? errorColor : textPrimary,
              onTap: () {
                ref.read(isMutedProvider.notifier).toggle();
                _videoController?.setVolume(isMuted ? 1.0 : 0.0);
              },
            ),
            const SizedBox(height: 20),
            _buildActionButton(
              favorited ? Icons.favorite : Icons.favorite_border,
              '点赞',
              color: favorited ? primaryPink : textPrimary,
              onTap: () =>
                  ref.read(favoritesProvider.notifier).toggleFavorite(widget.item),
            ),
            const SizedBox(height: 20),
            _buildActionButton(
              favorited ? Icons.star : Icons.star_border,
              '收藏',
              color: favorited ? amberColor : textPrimary,
              onTap: () =>
                  ref.read(favoritesProvider.notifier).toggleFavorite(widget.item),
            ),
            const SizedBox(height: 20),
            _buildActionButton(Icons.mode_comment_outlined, '评论', onTap: () {}),
            const SizedBox(height: 20),
            _buildActionButton(Icons.share, '分享', onTap: () {}),
          ],
        ),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    const duration = Duration(milliseconds: 120);
    return GestureDetector(
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
        scale: _pressed ? 0.8 : 1.0,
        duration: duration,
        curve: Curves.easeOut,
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
