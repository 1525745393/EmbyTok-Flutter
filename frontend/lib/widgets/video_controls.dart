// 视频控制条：播放/暂停按钮 + 进度条 + 时间 + 倍速
// TikTok 风格半透明控制层，接入 isPlayingProvider 同步播放状态

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../providers/providers.dart';
import '../utils/colors.dart';

// 视频控制条：半透明黑色背景，底部悬浮
class VideoControls extends ConsumerStatefulWidget {
  final VideoPlayerController controller;
  final List<double> playbackRates;
  final VoidCallback? onSkipPrevious; // 上一集
  final VoidCallback? onSkipNext; // 下一集
  final int currentIndex;
  final int totalCount;

  const VideoControls({
    super.key,
    required this.controller,
    this.playbackRates = const <double>[0.5, 0.75, 1.0, 1.25, 1.5, 2.0],
    this.onSkipPrevious,
    this.onSkipNext,
    this.currentIndex = 0,
    this.totalCount = 1,
  });

  @override
  ConsumerState<VideoControls> createState() => _VideoControlsState();
}

class _VideoControlsState extends ConsumerState<VideoControls> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
      // 同步播放状态到 Provider（供中央播放按钮显示/隐藏使用）
      ref.read(isPlayingProvider.notifier).state =
          widget.controller.value.isPlaying;
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

  // 显示倍速选择面板
  void _showRateSheet() async {
    final currentRate = widget.controller.value.playbackSpeed;
    final selected = await showModalBottomSheet<double>(
      context: context,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    '播放速度',
                    style: TextStyle(color: textPrimary, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 8),
                ...widget.playbackRates.map((rate) {
                  final isSelected = rate == currentRate;
                  return ListTile(
                    title: Text(
                      '${rate.toStringAsFixed(2)}x',
                      style: TextStyle(
                        color: isSelected ? primaryPink : textPrimary,
                        fontSize: 16,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    tileColor: isSelected ? primaryPink.withOpacity(0.1) : null,
                    onTap: () => Navigator.of(context).pop(rate),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null) {
      widget.controller.setPlaybackSpeed(selected);
      // 同步到 provider 以支持持久化
      ref.read(playbackRateProvider.notifier).setRate(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final position = widget.controller.value.position;
    final duration = widget.controller.value.duration;
    final isPlaying = widget.controller.value.isPlaying;
    // 自动播放状态：是否在当前视频播放完成后自动切换下一条
    final isAutoPlay = ref.watch(isAutoPlayProvider);
    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black54,
            Colors.black87,
          ],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // 上一集按钮
            IconButton(
              icon: Icon(
                Icons.skip_previous,
                color: widget.currentIndex > 0 ? textPrimary : textTertiary,
                size: 28,
              ),
              onPressed: widget.currentIndex > 0
                  ? widget.onSkipPrevious
                  : null,
            ),
            // 播放/暂停按钮
            IconButton(
              icon: Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                color: textPrimary,
                size: 28,
              ),
              onPressed: _togglePlay,
            ),
            // 下一集按钮
            IconButton(
              icon: Icon(
                Icons.skip_next,
                color: widget.currentIndex < widget.totalCount - 1
                    ? textPrimary
                    : textTertiary,
                size: 28,
              ),
              onPressed: widget.currentIndex < widget.totalCount - 1
                  ? widget.onSkipNext
                  : null,
            ),
            const SizedBox(width: 8),
            // 时间显示
            Text(
              '${_formatDuration(position)} / ${_formatDuration(duration)}',
              style: const TextStyle(color: textPrimary, fontSize: 14),
            ),
            const SizedBox(width: 8),
            // 进度条
            Expanded(
              child: Slider(
                value: progress.clamp(0.0, 1.0),
                onChanged: (value) {
                  final target = Duration(
                    milliseconds: (value * duration.inMilliseconds).toInt(),
                  );
                  widget.controller.seekTo(target);
                },
                activeColor: primaryPink,
                inactiveColor: textTertiary,
              ),
            ),
            const SizedBox(width: 8),
            // 倍速按钮
            TextButton(
              onPressed: _showRateSheet,
              child: Text(
                '${widget.controller.value.playbackSpeed.toStringAsFixed(2)}x',
                style: const TextStyle(color: textPrimary, fontSize: 14),
              ),
            ),
            const SizedBox(width: 4),
            // 自动连播开关：播放下一条视频
            IconButton(
              icon: Icon(
                isAutoPlay ? Icons.fast_forward : Icons.pause_circle_outline,
                color: isAutoPlay ? primaryPink : textPrimary,
                size: 22,
              ),
              onPressed: () {
                ref.read(isAutoPlayProvider.notifier).toggle();
              },
              tooltip: isAutoPlay ? '自动连播' : '手动切换',
            ),
          ],
        ),
      ),
    );
  }
}
