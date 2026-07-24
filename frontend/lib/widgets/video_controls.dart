// 视频控制条：播放/暂停按钮 + 上一集 + 进度条 + 时间 + 倍速 + 字幕
// TikTok 风格半透明控制层，接入 isPlayingProvider 同步播放状态

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../services/playback/i_playback_controller.dart';
import 'subtitle_selector.dart';

// 视频控制条：半透明黑色背景，底部悬浮
class VideoControls extends ConsumerStatefulWidget {
  final IPlaybackController controller;
  // 字幕轨道列表（从 MediaSource.MediaStreams 提取）
  final List<SubtitleTrack> subtitleTracks;
  // 上一集回调（剧集类内容）
  final VoidCallback? onPrevEpisode;
  // 倍速档位（支持常见的 0.5x ～ 2.0x 六档）
  final List<double> playbackRates;
  // 全屏切换回调
  final VoidCallback? onToggleFullscreen;
  // 是否已经在全屏模式（用于切换图标）
  final bool isInFullscreen;
  // Slider 拖动开始/结束回调（用于外部暂停控制层自动隐藏计时器）
  final VoidCallback? onSeekStart;
  final VoidCallback? onSeekEnd;
  // 紧凑模式：双层布局（按钮行+进度条行），精简按钮，纯净模式使用
  final bool compact;

  const VideoControls({
    super.key,
    required this.controller,
    this.subtitleTracks = const <SubtitleTrack>[],
    this.onPrevEpisode,
    this.playbackRates = const <double>[0.5, 0.75, 1.0, 1.25, 1.5, 2.0],
    this.onToggleFullscreen,
    this.isInFullscreen = false,
    this.onSeekStart,
    this.onSeekEnd,
    this.compact = false,
  });

  @override
  ConsumerState<VideoControls> createState() => _VideoControlsState();
}

class _VideoControlsState extends ConsumerState<VideoControls> {
  // 记录上一次的播放状态，仅在 isPlaying 实际变化时才写入 Provider，
  // 避免播放时每帧重复写入 isPlayingProvider
  late bool _lastIsPlaying;
  // Slider 拖动状态：拖动中只更新预览位置，不调用 seekTo
  bool _isSeeking = false;
  Duration? _previewPosition;

  @override
  void initState() {
    super.initState();
    _lastIsPlaying = widget.controller.isPlaying;
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  // 控制器变化回调：不再调用 setState，依赖 controller.value 的组件
  // （进度条、时间、播放按钮、倍速）通过 ValueListenableBuilder 实现局部重建，
  // 避免整棵 VideoControls 每秒重建约 60 次
  void _onControllerChanged() {
    if (!mounted) return;
    // 仅在 isPlaying 实际变化时才同步到 Provider（供中央播放按钮显示/隐藏使用）
    final isPlaying = widget.controller.isPlaying;
    if (isPlaying != _lastIsPlaying) {
      _lastIsPlaying = isPlaying;
      ref.read(isPlayingProvider.notifier).state = isPlaying;
    }
  }

  // 格式化 Duration 为 "mm:ss" 或 "h:mm:ss"
  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      final hours = d.inHours;
      final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return '$hours:$minutes:$seconds';
    }
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // 切换播放/暂停
  void _togglePlay() {
    if (widget.controller.isPlaying) {
      widget.controller.pause();
    } else {
      widget.controller.play();
    }
    ref.read(isPlayingProvider.notifier).state =
        widget.controller.isPlaying;
  }

  // 弹出倍速选择菜单（替代原先循环切换）
  Future<void> _showRateMenu() async {
    final scheme = Theme.of(context).colorScheme;
    final rate = await showDialog<double>(
      context: context,
      builder: (context) => SimpleDialog(
        backgroundColor: scheme.surface.withOpacity(0.9),
        title: Text('播放速度',
            style: TextStyle(color: scheme.onSurface, fontSize: 16)),
        children: widget.playbackRates
            .map((r) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, r),
                  child: Text('${r.toStringAsFixed(1)}x',
                      style: TextStyle(color: scheme.onSurface, fontSize: 15)),
                ))
            .toList(),
      ),
    );
    if (rate != null) {
      if (!mounted) return;
      widget.controller.setPlaybackSpeed(rate);
      // 同步更新 playbackRateProvider，保持三种倍速方式状态一致
      ref.read(playbackRateProvider.notifier).state = rate;
    }
  }

  // 弹出字幕选择菜单（从 subtitleTracks 中挑选）
  Future<void> _showSubtitleMenu() async {
    if (widget.subtitleTracks.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未检测到可用字幕'), duration: Duration(seconds: 1)),
      );
      return;
    }
    await showSubtitleSelector(
      context: context,
      tracks: widget.subtitleTracks,
      selectedTrackId: ref.read(selectedSubtitleProvider),
      onSelected: (track) {
        if (!mounted) return;
        ref.read(selectedSubtitleProvider.notifier).state = track?.id;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final controller = widget.controller;
    final isCompact = widget.compact;

    // 进度条 + 时间 组件（供两种模式共用）
    final progressRow = ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, child) {
        final position = _isSeeking
            ? (_previewPosition ?? value.position)
            : value.position;
        final duration = value.duration;
        final progress = duration.inMilliseconds > 0
            ? position.inMilliseconds / duration.inMilliseconds
            : 0.0;
        final timeFontSize = isCompact ? 12.0 : 13.0;
        return Row(
          children: [
            Text(
              _formatDuration(position),
              style: TextStyle(color: scheme.onSurface, fontSize: timeFontSize),
            ),
            SizedBox(width: isCompact ? 6 : 8),
            Expanded(
              child: Slider(
                value: progress.clamp(0.0, 1.0),
                onChangeStart: (v) {
                  setState(() {
                    _isSeeking = true;
                    _previewPosition = Duration(
                      milliseconds: (v * duration.inMilliseconds).toInt(),
                    );
                  });
                  widget.onSeekStart?.call();
                  HapticFeedback.selectionClick();
                },
                onChanged: (v) {
                  setState(() {
                    _previewPosition = Duration(
                      milliseconds: (v * duration.inMilliseconds).toInt(),
                    );
                  });
                },
                onChangeEnd: (v) {
                  final target = Duration(
                    milliseconds: (v * duration.inMilliseconds).toInt(),
                  );
                  controller.seekTo(target);
                  setState(() {
                    _isSeeking = false;
                    _previewPosition = null;
                  });
                  widget.onSeekEnd?.call();
                  HapticFeedback.lightImpact();
                },
                activeColor: scheme.primary,
                inactiveColor: scheme.onSurfaceVariant,
              ),
            ),
            SizedBox(width: isCompact ? 6 : 8),
            Text(
              _formatDuration(duration),
              style: TextStyle(color: scheme.onSurface, fontSize: timeFontSize),
            ),
          ],
        );
      },
    );

    // 播放/暂停按钮
    final playButton = ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, child) {
        return IconButton(
          icon: Icon(
            value.isPlaying ? Icons.pause : Icons.play_arrow,
            color: scheme.onSurface,
            size: isCompact ? 24 : 28,
          ),
          onPressed: _togglePlay,
        );
      },
    );

    // 倍速按钮
    final speedButton = ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, child) {
        return TextButton(
          onPressed: _showRateMenu,
          child: Text(
            '${value.playbackSpeed.toStringAsFixed(1)}x',
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: isCompact ? 12 : 14,
            ),
          ),
        );
      },
    );

    // 全屏按钮
    final fullscreenButton = widget.onToggleFullscreen != null
        ? IconButton(
            icon: Icon(
              widget.isInFullscreen
                  ? Icons.fullscreen_exit
                  : Icons.fullscreen,
              color: scheme.onSurface,
              size: isCompact ? 20 : 24,
            ),
            onPressed: widget.onToggleFullscreen,
          )
        : null;

    // 三点菜单（紧凑模式：收纳字幕等低频功能）
    final moreButton = isCompact
        ? PopupMenuButton<String>(
            icon: Icon(Icons.more_vert,
                color: scheme.onSurface, size: 20),
            onSelected: (value) {
              if (value == 'subtitles') _showSubtitleMenu();
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'subtitles',
                child: Row(
                  children: [
                    Icon(Icons.subtitles,
                        color: scheme.onSurfaceVariant, size: 20),
                    const SizedBox(width: 10),
                    Text('字幕',
                        style: TextStyle(
                            color: scheme.onSurface, fontSize: 14)),
                  ],
                ),
              ),
            ],
          )
        : null;

    // 字幕按钮（非紧凑模式常驻）
    final subtitleButton = !isCompact
        ? IconButton(
            icon: Icon(Icons.subtitles, color: scheme.onSurface),
            onPressed: _showSubtitleMenu,
          )
        : null;

    // 上一集按钮（非紧凑模式常驻）
    final prevButton = !isCompact
        ? IconButton(
            icon: Icon(Icons.skip_previous, color: scheme.onSurface),
            onPressed: widget.onPrevEpisode,
          )
        : null;

    final horizontalPadding = isCompact ? 8.0 : 12.0;
    final verticalPadding = isCompact ? 6.0 : 8.0;
    final buttonSpacing = isCompact ? 4.0 : 8.0;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            scheme.surface.withOpacity(0.54),
            scheme.surface.withOpacity(0.87),
          ],
        ),
      ),
      child: SafeArea(
        top: false,
        child: isCompact
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 第一行：按钮
                  Row(
                    children: [
                      playButton,
                      const Spacer(),
                      speedButton,
                      SizedBox(width: buttonSpacing),
                      if (fullscreenButton != null) fullscreenButton,
                      if (moreButton != null) moreButton,
                    ],
                  ),
                  SizedBox(height: isCompact ? 4 : 0),
                  // 第二行：进度条 + 时间
                  progressRow,
                ],
              )
            : Row(
                children: [
                  if (prevButton != null) prevButton,
                  playButton,
                  SizedBox(width: buttonSpacing),
                  Expanded(child: progressRow),
                  SizedBox(width: buttonSpacing),
                  if (subtitleButton != null) subtitleButton,
                  speedButton,
                  if (fullscreenButton != null) fullscreenButton,
                ],
              ),
      ),
    );
  }
}
