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

  const VideoControls({
    super.key,
    required this.controller,
    this.playbackRates = const <double>[1.0, 1.5, 2.0],
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

  // 切换倍速
  void _cycleRate() {
    final current = widget.controller.value.playbackSpeed;
    final rates = widget.playbackRates;
    final nextIndex = (rates.indexOf(current) + 1) % rates.length;
    widget.controller.setPlaybackSpeed(rates[nextIndex]);
  }

  @override
  Widget build(BuildContext context) {
    final position = widget.controller.value.position;
    final duration = widget.controller.value.duration;
    final isPlaying = widget.controller.value.isPlaying;
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
            // 播放/暂停按钮
            IconButton(
              icon: Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                color: textPrimary,
                size: 28,
              ),
              onPressed: _togglePlay,
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
              onPressed: _cycleRate,
              child: Text(
                '${widget.controller.value.playbackSpeed.toStringAsFixed(1)}x',
                style: const TextStyle(color: textPrimary, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
