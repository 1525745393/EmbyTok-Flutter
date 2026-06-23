// 视频控制条：播放/暂停按钮 + 上一集/下一集 + 进度条 + 时间 + 倍速 + 字幕
// TikTok 风格半透明控制层，接入 isPlayingProvider 同步播放状态

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import 'subtitle_selector.dart';

// 视频控制条：半透明黑色背景，底部悬浮
class VideoControls extends ConsumerStatefulWidget {
  final VideoPlayerController controller;
  // 字幕轨道列表（从 MediaSource.MediaStreams 提取）
  final List<SubtitleTrack> subtitleTracks;
  // 上一集/下一集回调（剧集类内容）
  final VoidCallback? onPrevEpisode;
  final VoidCallback? onNextEpisode;
  // 倍速档位（支持常见的 0.5x ～ 2.0x 六档）
  final List<double> playbackRates;
  // 全屏切换回调
  final VoidCallback? onToggleFullscreen;
  // 是否已经在全屏模式（用于切换图标）
  final bool isInFullscreen;

  const VideoControls({
    super.key,
    required this.controller,
    this.subtitleTracks = const <SubtitleTrack>[],
    this.onPrevEpisode,
    this.onNextEpisode,
    this.playbackRates = const <double>[0.5, 0.75, 1.0, 1.25, 1.5, 2.0],
    this.onToggleFullscreen,
    this.isInFullscreen = false,
  });

  @override
  ConsumerState<VideoControls> createState() => _VideoControlsState();
}

class _VideoControlsState extends ConsumerState<VideoControls> {
  // 记录上一次的播放状态，仅在 isPlaying 实际变化时才写入 Provider，
  // 避免播放时每帧重复写入 isPlayingProvider
  late bool _lastIsPlaying;

  @override
  void initState() {
    super.initState();
    _lastIsPlaying = widget.controller.value.isPlaying;
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
    final isPlaying = widget.controller.value.isPlaying;
    if (isPlaying != _lastIsPlaying) {
      _lastIsPlaying = isPlaying;
      ref.read(isPlayingProvider.notifier).state = isPlaying;
    }
  }

  // 格式化 Duration 为 "mm:ss"
  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // 切换播放/暂停
  void _togglePlay() {
    if (widget.controller.value.isPlaying) {
      widget.controller.pause();
    } else {
      widget.controller.play();
    }
    ref.read(isPlayingProvider.notifier).state =
        widget.controller.value.isPlaying;
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
      widget.controller.setPlaybackSpeed(rate);
      // 同步更新 playbackRateProvider，保持三种倍速方式状态一致
      ref.read(playbackRateProvider.notifier).state = rate;
    }
  }

  // 弹出字幕选择菜单（从 subtitleTracks 中挑选）
  Future<void> _showSubtitleMenu() async {
    if (widget.subtitleTracks.isEmpty) {
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
        ref.read(selectedSubtitleProvider.notifier).state = track?.id;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final controller = widget.controller;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
        child: Row(
          children: [
            // 上一集（静态，不随播放进度重建）
            IconButton(
              icon: Icon(Icons.skip_previous, color: scheme.onSurface),
              onPressed: widget.onPrevEpisode,
            ),
            // 播放/暂停按钮：仅 isPlaying 变化时局部重建
            ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: controller,
              builder: (context, value, child) {
                return IconButton(
                  icon: Icon(
                    value.isPlaying ? Icons.pause : Icons.play_arrow,
                    color: scheme.onSurface,
                    size: 28,
                  ),
                  onPressed: _togglePlay,
                );
              },
            ),
            // 下一集（静态）
            IconButton(
              icon: Icon(Icons.skip_next, color: scheme.onSurface),
              onPressed: widget.onNextEpisode,
            ),
            const SizedBox(width: 8),
            // 时间显示 + 进度条：共享 position/duration，合并为一个监听器
            // Expanded 保证进度条填充剩余水平空间
            Expanded(
              child: ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: controller,
                builder: (context, value, child) {
                  final position = value.position;
                  final duration = value.duration;
                  final progress = duration.inMilliseconds > 0
                      ? position.inMilliseconds / duration.inMilliseconds
                      : 0.0;
                  return Row(
                    children: [
                      Text(
                        '${_formatDuration(position)} / ${_formatDuration(duration)}',
                        style:
                            TextStyle(color: scheme.onSurface, fontSize: 14),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Slider(
                          value: progress.clamp(0.0, 1.0),
                          onChanged: (v) {
                            final target = Duration(
                              milliseconds:
                                  (v * duration.inMilliseconds).toInt(),
                            );
                            controller.seekTo(target);
                          },
                          activeColor: scheme.primary,
                          inactiveColor: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            // 字幕按钮（静态）
            IconButton(
              icon: Icon(Icons.subtitles, color: scheme.onSurface),
              onPressed: _showSubtitleMenu,
            ),
            // 倍速按钮：仅 playbackSpeed 变化时局部重建
            ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: controller,
              builder: (context, value, child) {
                return TextButton(
                  onPressed: _showRateMenu,
                  child: Text(
                    '${value.playbackSpeed.toStringAsFixed(1)}x',
                    style: TextStyle(color: scheme.onSurface, fontSize: 14),
                  ),
                );
              },
            ),
            // 全屏切换按钮（静态）
            if (widget.onToggleFullscreen != null)
              IconButton(
                icon: Icon(
                  widget.isInFullscreen
                      ? Icons.fullscreen_exit
                      : Icons.fullscreen,
                  color: scheme.onSurface,
                ),
                onPressed: widget.onToggleFullscreen,
              ),
          ],
        ),
      ),
    );
  }
}
