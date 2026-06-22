// 视频流单页：全屏视频 + 右侧操作按钮 + 左下角标题信息
// 完整 Emby 播放上报链（reportCapabilities / reportPlaybackStart /
//       reportPlaybackPosition / reportPlaybackStopped）

import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../services/embbytok_service.dart';
import '../services/video_pool_service.dart';
import 'gesture_overlay.dart';
import 'video_controls.dart';
import 'video_player_widget.dart';

// 拆分出的子组件
import 'video/video_action_button.dart';
import 'video/video_control_buttons.dart';
import 'video/video_progress_bars.dart';
import 'video/video_sheet_utils.dart' as sheet_utils;
import 'video/video_draggable_clean_actions.dart';

/// 单个视频页：TikTok 卡片样式
class VideoPageItem extends ConsumerStatefulWidget {
  final MediaItem item;
  final PlaybackSession? preloadedSession;
  final VoidCallback? onVideoEnded;
  final bool startFromResumePosition;
  final VoidCallback? onNextEpisode;
  final VoidCallback? onPrevEpisode;

  const VideoPageItem({
    super.key,
    required this.item,
    this.preloadedSession,
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
  bool _hasNotifiedEnded = false;

  // 唱片式静音按钮动画控制器
  late final AnimationController _discRotationCtrl;
  late final Animation<double> _discRotation;

  // 底部信息条 3 秒自动隐藏
  Timer? _infoHideTimer;
  bool _isInfoVisible = true;

  // 播放上报相关
  final EmbytokService _service = EmbytokService();
  Timer? _progressTimer;
  String? _playSessionId;
  bool _hasStartedReported = false;
  bool _capabilitiesReported = false;
  DateTime _lastProgressReport = DateTime.fromMicrosecondsSinceEpoch(0);
  static const _progressReportMinSeconds = 4;

  // 横屏全屏沉浸模式
  bool _isFullscreen = false;

  // 底部信息面板展开/收起
  bool _isInfoExpanded = false;

  // 控制层（VideoControls）显示状态
  bool _controlsVisible = false;
  Timer? _controlsHideTimer;
  static const int _controlsAutoHideSeconds = 3;

  // NextUp（下一集提示）状态
  MediaItem? _nextUpItem;
  bool _showNextUpBanner = false;
  int _nextUpCountdown = 5;
  Timer? _nextUpTimer;
  static const int _nextUpCountdownSeconds = 5;

  @override
  void initState() {
    super.initState();
    _discRotationCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _discRotation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _discRotationCtrl, curve: Curves.linear));
  }

  // ===== 底部信息条 3 秒自动隐藏 =====
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
    _videoController?.removeListener(_onVideoChanged);
    _progressTimer?.cancel();
    _progressTimer = null;
    if (_hasStartedReported) _reportPlaybackStopped();
    _controlsHideTimer?.cancel();
    _nextUpTimer?.cancel();
    _nextUpTimer = null;
    if (_isFullscreen) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
    ref.read(videoReadyProvider.notifier).clear(widget.item.id);
    final ctrl = ref.read(currentVideoControllerProvider);
    if (ctrl != null && identical(ctrl, _videoController)) {
      ref.read(currentVideoControllerProvider.notifier).state = null;
    }
    // ⚠️ _videoController 由内部 VideoPlayerWidget 负责 dispose，这里只清空引用
    _videoController = null;
    _capabilitiesReported = false;
    _hasStartedReported = false;
    _playSessionId = null;
    _hasNotifiedEnded = false;
    super.dispose();
  }

  // ===== 视频状态变化监听 =====
  void _onVideoChanged() {
    if (!mounted) return;
    final controller = _videoController;
    if (controller == null) return;
    // 同步播放状态到 Provider，确保中央按钮和控制条状态一致
    ref.read(isPlayingProvider.notifier).state = controller.value.isPlaying;
    if (!_hasNotifiedEnded) {
      final pos = controller.value.position;
      final dur = controller.value.duration;
      if (dur.inMilliseconds > 0 && (dur - pos).inMilliseconds < 1000) {
        _hasNotifiedEnded = true;
        _reportPlaybackStopped();
        unawaited(_service.markAsPlayed(
          widget.item.id,
          serverUrl: _authServerUrl(),
          token: _authToken(),
        ));
        ref.read(videoListProvider.notifier).removePlayedItem(widget.item.id);
        _queryNextUp();
      }
    }
  }

  // ===== NextUp 下一集查询与倒计时 =====
  Future<void> _queryNextUp() async {
    final seriesId = widget.item.seriesId;
    final isEpisode = widget.item.type == 'Episode' ||
        (widget.item.seriesName != null && widget.item.seriesName!.isNotEmpty);
    if (!isEpisode) {
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
      final candidates = resp.items.where((it) => it.id != widget.item.id).toList();
      if (mounted && candidates.isNotEmpty) {
        setState(() {
          _nextUpItem = candidates.first;
          _showNextUpBanner = true;
          _nextUpCountdown = _nextUpCountdownSeconds;
        });
        _startNextUpCountdown();
      } else if (mounted) {
        _fallbackAutoPlay();
      }
    } catch (_) {
      if (mounted) _fallbackAutoPlay();
    }
  }

  void _startNextUpCountdown() {
    _nextUpTimer?.cancel();
    _nextUpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _nextUpCountdown--);
      if (_nextUpCountdown <= 0) {
        timer.cancel();
        _playNextUp();
      }
    });
  }

  void _playNextUp() {
    _nextUpTimer?.cancel();
    if (!mounted) return;
    if (widget.onNextEpisode != null) {
      setState(() => _showNextUpBanner = false);
      widget.onNextEpisode!.call();
    } else {
      _fallbackAutoPlay();
    }
  }

  void _cancelNextUp() {
    _nextUpTimer?.cancel();
    if (!mounted) return;
    setState(() => _showNextUpBanner = false);
  }

  void _fallbackAutoPlay() {
    final autoPlay = ref.read(isAutoPlayProvider);
    if (autoPlay) widget.onVideoEnded?.call();
  }

  // ===== 播放上报链方法 =====
  String _newPlaySessionId() => 'emb-flutter-${DateTime.now().microsecondsSinceEpoch}';

  String _playMethodFromLevel(int level) => level >= 2 ? 'Transcode' : 'DirectPlay';

  void _ensureCapabilitiesReported() {
    if (_capabilitiesReported) return;
    _capabilitiesReported = true;
    unawaited(_service.reportCapabilities(
      serverUrl: _authServerUrl(),
      token: _authToken(),
    ));
  }

  void _reportPlaybackStart() {
    if (_hasStartedReported) return;
    _hasStartedReported = true;
    // 如果来自预加载会话，则复用其 playSessionId，保证预加载和播放使用同一个会话
    _playSessionId = widget.preloadedSession?.playSessionId ?? _newPlaySessionId();
    // 如果来自预加载会话，同步播放等级到 provider（保证 reportPlaybackProgress 正确）
    if (widget.preloadedSession != null) {
      ref.read(playbackLevelProvider.notifier).setLevel(widget.preloadedSession!.playbackLevel);
    }
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

  void _reportPlaybackProgress({bool isPauseEvent = false}) {
    final now = DateTime.now();
    if (!isPauseEvent) {
      final delta = now.difference(_lastProgressReport);
      if (delta.inSeconds < _progressReportMinSeconds) return;
    }
    _lastProgressReport = now;
    final controller = _videoController;
    final position = controller?.value.position;
    final positionTicks = (position?.inSeconds ?? 0) * 10000000;
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

  void _reportPlaybackStopped() {
    final controller = _videoController;
    final position = controller?.value.position;
    final positionTicks = position != null ? position.inSeconds * 10000000 : 0;
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

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      _reportPlaybackProgress();
    });
  }

  // ===== 认证辅助 =====
  String? _authServerUrl() => ref.watch(authProvider).embyServerUrl;
  String? _authToken() => ref.watch(authProvider).token;

  // ===== 全屏切换 =====
  void _toggleFullscreen() {
    setState(() => _isFullscreen = !_isFullscreen);
    if (_isFullscreen) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      ref.read(toolbarVisibilityProvider.notifier).hide();
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      ref.read(toolbarVisibilityProvider.notifier).show();
    }
  }

  // ===== 控制层显示/隐藏 =====
  void _toggleControls() {
    if (_controlsVisible) {
      _hideControls();
    } else {
      _showControls();
    }
  }

  void _showControls() {
    _controlsHideTimer?.cancel();
    setState(() => _controlsVisible = true);
    _controlsHideTimer = Timer(const Duration(seconds: _controlsAutoHideSeconds), _hideControls);
  }

  void _hideControls() {
    _controlsHideTimer?.cancel();
    if (mounted) setState(() => _controlsVisible = false);
  }

  // ===== 播放/暂停切换 =====
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

  // ===== 删除确认 =====
  Future<void> _showDeleteConfirmDialog() async {
    final confirmed = await sheet_utils.showDeleteConfirmDialog(context, widget.item.title);
    if (confirmed) {
      try {
        await _service.deleteItem(
          itemId: widget.item.id,
          serverUrl: _authServerUrl()!,
          token: _authToken()!,
        );
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('已删除'), duration: Duration(seconds: 2)));
          widget.onVideoEnded?.call();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败: $e'), duration: const Duration(seconds: 2)),
          );
        }
      }
    }
  }

  // ===== Duration 格式化 =====
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
    if (widget.item.year != null) return '${widget.item.title} (${widget.item.year})';
    return widget.item.title;
  }

  @override
  Widget build(BuildContext context) {
    // 监听播放状态变化（播放时旋转唱片，暂停时停止）
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
    final favorited = ref.watch(favoritesProvider).favoriteIds.contains(widget.item.id);
    final isReady = ref.watch(videoReadyProvider).contains(widget.item.id);
    final isPlaying = ref.watch(isPlayingProvider);
    final isAutoPlay = ref.watch(isAutoPlayProvider);
    final toolbarVisible = ref.watch(toolbarVisibilityProvider);
    final scheme = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final rs = (double base, [double maxScale = 1.7]) => responsiveSize(context, base, maxScale);

    // 封面图 URL（用于唱片按钮）
    final posterUrl =
        widget.item.primaryUrl(embyServerUrl: embyServerUrl, apiKey: token) ?? '';
    final posterHeaders = widget.item.authHeaders(token);

    // ============ 主 Stack ============
    final content = Stack(
      fit: StackFit.expand,
      children: [
        // 骨架占位：视频未 ready 时显示渐变色块
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isReady
                  ? [Colors.transparent, Colors.transparent]
                  : [scheme.surface.withOpacity(0.7), scheme.surface],
            ),
          ),
        ),

        // 视频播放区（Gestures + VideoPlayer）
        AnimatedOpacity(
          opacity: isReady ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          child: GestureOverlay(
            controller: _videoController,
            item: widget.item,
            onSingleTap: () {
              if (_isFullscreen || isAutoPlay) {
                _toggleControls();
              } else {
                _togglePlay();
              }
            },
            child: VideoPlayerWidget(
              item: widget.item,
              embyServerUrl: embyServerUrl,
              token: token,
              preloadedController: widget.preloadedSession?.controller,
              preloadedPlaybackLevel: widget.preloadedSession?.playbackLevel,
              startFromResumePosition: widget.startFromResumePosition,
              onControllerReady: (c) {
                setState(() => _videoController = c);
                ref.read(currentVideoControllerProvider.notifier).state = c;
                ref.read(isPlayingProvider.notifier).state = true;
                ref.read(currentPlayingItemProvider.notifier).state = widget.item;
                ref.read(videoReadyProvider.notifier).markReady(widget.item.id);
                _resetInfoHideTimer();
                _ensureCapabilitiesReported();
                _reportPlaybackStart();
                _startProgressTimer();
                c.addListener(_onVideoChanged);
                c.addListener(() {
                  if (!mounted) return;
                  if (!c.value.isPlaying) _reportPlaybackProgress(isPauseEvent: true);
                  _resetInfoHideTimer();
                });
              },
            ),
          ),
        ),

        // 中央播放/暂停按钮（暂停时显示）
        if (_videoController != null && _videoController!.value.isInitialized && !isPlaying)
          CenterPlayButton(onPlay: _togglePlay),

        // 倍速状态徽章
        if (_videoController != null &&
            _videoController!.value.isInitialized &&
            _videoController!.value.playbackSpeed > 1.0)
          SpeedBadge(speed: _videoController!.value.playbackSpeed),

        // 底部细线进度条：仅在全屏 / 纯净模式且控制条隐藏时显示（VideoControls 显示时有自己的进度条）
        if (_videoController != null &&
            _videoController!.value.isInitialized &&
            (_isFullscreen || isAutoPlay) &&
            !_controlsVisible)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ThinProgressBar(controller: _videoController!),
          ),

        // 控制层（VideoControls）：仅在无信息栏时显示（全屏 / 纯净模式），非全屏非纯净模式下信息栏已有进度条替代
        if (_videoController != null && _videoController!.value.isInitialized && (_isFullscreen || isAutoPlay))
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
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
                  onToggleFullscreen: _toggleFullscreen,
                  isInFullscreen: _isFullscreen,
                ),
              ),
            ),
          ),

        // 底部渐变 + 标题/简介/类型标签（非纯净模式）
        if (!_isFullscreen && (_isInfoExpanded || !isAutoPlay))
          Positioned(
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
                  rs(80, 2.0) + 16,
                  toolbarVisible ? bottomPadding + 24 + 80 : bottomPadding + 24,
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
                    // 横屏视频：居中显示「全屏观看」按钮
                    if (_videoController != null &&
                        _videoController!.value.isInitialized &&
                        _videoController!.value.size.width > _videoController!.value.size.height)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: GestureDetector(
                            onTap: _toggleFullscreen,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              decoration: BoxDecoration(
                                color: scheme.surface.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.fullscreen, color: scheme.onSurface, size: 16),
                                  const SizedBox(width: 6),
                                  Text('全屏观看', style: TextStyle(color: scheme.onSurface, fontSize: 14, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(widget.item.type,
                          style: TextStyle(
                              color: scheme.onPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(
                          child: Text(_titleText(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: scheme.onSurface,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 12),
                        if (widget.item.displayRating != null && widget.item.displayRating! > 0)
                          Text('★ ${widget.item.displayRating!.toStringAsFixed(1)}',
                              style: TextStyle(
                                  color: scheme.primary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (widget.item.overview != null && widget.item.overview!.isNotEmpty)
                      Text(widget.item.overview!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14)),
                    if (_videoController != null && _videoController!.value.isInitialized)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: SeekableProgressBar(
                          controller: _videoController!,
                          formatDuration: _formatDuration,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

        // 右侧操作按钮（非纯净模式）
        if (!_isFullscreen && !isAutoPlay)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: rs(80, 2.0),
            child: Container(
              padding: EdgeInsets.fromLTRB(
                0,
                toolbarVisible ? MediaQuery.of(context).padding.top + rs(48) : rs(32),
                rs(6),
                toolbarVisible ? bottomPadding + 24 + 80 : bottomPadding + 24,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [scheme.surface.withOpacity(0.54), Colors.transparent],
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // 顶部全屏按钮（仅竖屏视频时显示，横屏视频下方已有居中"全屏观看"按钮）
                  if (_videoController == null ||
                      !_videoController!.value.isInitialized ||
                      _videoController!.value.size.width <= _videoController!.value.size.height)
                    PressableActionButton(
                      icon: Icons.fullscreen,
                      label: '全屏',
                      color: scheme.onSurface,
                      onTap: _toggleFullscreen,
                    ),
                  SizedBox(height: rs(16, 1.5)),
                  const AutoPlayButton(),
                  SizedBox(height: rs(16, 1.5)),
                  PosterAvatar(item: widget.item),
                  SizedBox(height: rs(16, 1.5)),
                  PressableActionButton(
                    icon: favorited ? Icons.favorite : Icons.favorite_border,
                    label: '点赞',
                    color: favorited ? scheme.primary : scheme.onSurface,
                    onTap: () => ref.read(favoritesProvider.notifier).toggleFavorite(widget.item),
                  ),
                  SizedBox(height: rs(16, 1.5)),
                  PressableActionButton(
                    icon: Icons.info_outline,
                    label: '信息',
                    color: scheme.onSurface,
                    onTap: () {
                      setState(() => _isInfoExpanded = !_isInfoExpanded);
                      sheet_utils.showVideoInfoSheet(context, widget.item);
                    },
                  ),
                  SizedBox(height: rs(16, 1.5)),
                  PressableActionButton(
                    icon: Icons.delete_outline,
                    label: '删除',
                    color: scheme.error,
                    onTap: _showDeleteConfirmDialog,
                  ),
                  SizedBox(height: rs(16, 1.5)),
                  SpeedControlButton(
                    controller: _videoController,
                    onTap: () => sheet_utils.showSpeedControlPanel(context, _videoController),
                  ),
                  SizedBox(height: rs(16, 1.5)),
                  const PlayModeButton(),
                  SizedBox(height: rs(16, 1.5)),
                  SubtitleButton(
                    hasSubtitles: widget.item.subtitleTracks.isNotEmpty,
                    onTap: () => sheet_utils.showSubtitleSelector(context, widget.item.subtitleTracks),
                  ),
                  SizedBox(height: rs(16, 1.5)),
                  DiscMuteButton(
                    discRotation: _discRotation,
                    controller: _videoController,
                    posterUrl: posterUrl,
                    httpHeaders: posterHeaders,
                  ),
                  if (widget.onNextEpisode != null) ...[
                    SizedBox(height: rs(16, 1.5)),
                    PressableActionButton(
                      icon: Icons.chevron_right,
                      label: '下一集',
                      color: scheme.onSurface,
                      onTap: widget.onNextEpisode,
                    ),
                  ],
                ],
              ),
            ),
          ),

        // 纯净模式：可拖动按钮组
        if (!_isFullscreen && isAutoPlay)
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return DraggableCleanActions(
                  containerSize: Size(constraints.maxWidth, constraints.maxHeight),
                  buttonWidth: rs(80, 2.0),
                  bottomSafeArea: bottomPadding + 80 + 16,
                  rightSafeArea: 16,
                  buttons: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.surface.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const AutoPlayButton(),
                        SizedBox(height: rs(16, 1.5)),
                        SpeedControlButton(
                          controller: _videoController,
                          onTap: () => sheet_utils.showSpeedControlPanel(context, _videoController),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

        // 顶部操作区：全屏模式下控制条已有退出按钮，无需额外入口

        // NextUp 下一集提示条
        if (_showNextUpBanner && _nextUpItem != null)
          NextUpBanner(
            nextItem: _nextUpItem!,
            countdown: _nextUpCountdown,
            onPlay: _playNextUp,
            onCancel: _cancelNextUp,
          ),
      ],
    );

    // 使用 PopScope 处理返回键：全屏模式下先退出全屏
    return PopScope(
      canPop: !_isFullscreen,
      onPopInvoked: (bool didPop) {
        // didPop == true 表示已经完成 pop，不需要额外处理
        if (didPop) return;
        // didPop == false 且在全屏模式：手动退出全屏
        if (_isFullscreen) {
          _toggleFullscreen();
        }
      },
      child: _isFullscreen
          ? Semantics(
              label: '横屏全屏视频播放',
              child: Container(
                color: scheme.surface,
                child: content,
              ),
            )
          : Semantics(label: '视频播放区域，双击点赞此视频', child: content),
    );
  }
}

/// 播放页面外壳：支持滑动切换视频列表
///
/// 使用 PageView 展示视频列表，支持上下滑动切换视频
class PlaybackShell extends ConsumerStatefulWidget {
  final MediaItem item; // 当前播放的视频
  final VoidCallback onBack; // 返回回调

  const PlaybackShell({
    super.key,
    required this.item,
    required this.onBack,
  });

  @override
  ConsumerState<PlaybackShell> createState() => _PlaybackShellState();
}

class _PlaybackShellState extends ConsumerState<PlaybackShell> {
  late PageController _pageController;
  int _currentIndex = 0;
  List<MediaItem> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0, viewportFraction: 1.0);
    _loadItems();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    // 从 videoListProvider 获取当前视频列表
    final videoState = ref.read(videoListProvider);
    if (videoState.items.isNotEmpty) {
      // 找到当前 item 在列表中的索引
      final initialIndex = videoState.items.indexWhere((i) => i.id == widget.item.id);
      setState(() {
        _items = videoState.items;
        _currentIndex = initialIndex >= 0 ? initialIndex : 0;
        _isLoading = false;
      });
      // 如果初始索引不是 0，滚动到对应位置
      if (initialIndex > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _pageController.hasClients) {
            _pageController.jumpToPage(initialIndex);
          }
        });
      }
    } else {
      // 如果列表为空，只播放当前视频
      setState(() {
        _items = [widget.item];
        _isLoading = false;
      });
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: scheme.surface,
        body: Center(
          child: CircularProgressIndicator(color: scheme.primary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Stack(
        children: [
          // PageView 支持滑动切换视频
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: _items.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              final item = _items[index];
              return VideoPageItem(
                key: ValueKey(item.id),
                item: item,
                onVideoEnded: index < _items.length - 1
                    ? () {
                        // 自动播放下一个
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      }
                    : null,
                startFromResumePosition: item.hasProgress,
              );
            },
          ),
          // 返回按钮
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: IconButton(
              icon: Icon(Icons.arrow_back, color: scheme.onSurface),
              onPressed: widget.onBack,
            ),
          ),
          // 当前位置指示器
          if (_items.length > 1)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: scheme.surface.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${_currentIndex + 1}/${_items.length}',
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
