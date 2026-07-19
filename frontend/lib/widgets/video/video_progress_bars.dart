// 视频播放进度条组件
// - ThinProgressBar: TikTok 风格底部细线进度条（始终可见）
// - SeekableProgressBar: 可点击/可拖拽的进度条（底部信息栏内使用）

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// TikTok 风格底部细线进度条
/// 高度 2px，始终可见，颜色为 theme.primary，背景半透明 surface
class ThinProgressBar extends StatefulWidget {
  final VideoPlayerController controller;

  const ThinProgressBar({super.key, required this.controller});

  @override
  State<ThinProgressBar> createState() => _ThinProgressBarState();
}

class _ThinProgressBarState extends State<ThinProgressBar> {
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
      color: scheme.surface.withValues(alpha: 0.3),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress,
        child: Container(color: scheme.primary),
      ),
    );
  }
}

/// 可点击/可拖拽的进度条（用于底部信息栏）
/// 支持点击跳转和水平拖拽 seek
class SeekableProgressBar extends StatefulWidget {
  final VideoPlayerController controller;
  final String Function(Duration) formatDuration;

  const SeekableProgressBar({
    super.key,
    required this.controller,
    required this.formatDuration,
  });

  @override
  State<SeekableProgressBar> createState() => _SeekableProgressBarState();
}

class _SeekableProgressBarState extends State<SeekableProgressBar> {
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

    final progress = (localDx / totalWidth).clamp(0.0, 1.0);
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
        const barHeight = 12.0;
        const indicatorRadius = 6.0;
        final currentTime = widget.formatDuration(position);
        final totalTime = widget.formatDuration(duration);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTapDown: (details) {
                _seekToPosition(details.localPosition.dx, totalWidth);
              },
              onHorizontalDragStart: (details) {
                setState(() => _isDragging = true);
                _seekToPosition(details.localPosition.dx, totalWidth);
              },
              onHorizontalDragUpdate: (details) {
                final localDx = details.localPosition.dx;
                final newProgress = (localDx / totalWidth).clamp(0.0, 1.0);
                setState(() => _dragProgress = newProgress);
                _seekToPosition(localDx, totalWidth);
              },
              onHorizontalDragEnd: (_) {
                setState(() => _isDragging = false);
              },
              child: Container(
                height: barHeight,
                width: totalWidth,
                color: Colors.transparent,
                alignment: Alignment.center,
                child: Container(
                  height: 4,
                  width: totalWidth,
                  decoration: BoxDecoration(
                    color: scheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Stack(
                    children: [
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
                      Positioned(
                        left: (displayProgress * totalWidth)
                                .clamp(0.0, totalWidth - indicatorRadius * 2) -
                            indicatorRadius,
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
                                      color: scheme.primary.withValues(alpha: 0.5),
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
            const SizedBox(height: 4),
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
