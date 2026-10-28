// 视频播放进度条组件
// - ThinProgressBar: TikTok 风格底部细线进度条（始终可见）
// - SeekableProgressBar: 可点击/可拖拽的进度条（底部信息栏内使用）

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../providers/providers.dart';
import '../../utils/logger.dart';

/// TikTok 风格底部细线进度条
/// 高度 2px，始终可见，颜色为 theme.primary，背景半透明 surface
class ThinProgressBar extends StatefulWidget {
  const ThinProgressBar({super.key, required this.controller});
  final VideoPlayerController controller;

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
///
/// batch 29：EXO 引擎由 [controller] 驱动；MPV/VLC 引擎下 controller 不可用时
/// 由 [handle]（统一控制句柄）驱动位置/时长与 seek，样式与交互保持单一实现。
class SeekableProgressBar extends StatefulWidget {
  const SeekableProgressBar({
    super.key,
    required this.controller,
    required this.formatDuration,
    this.handle,
  });
  final VideoPlayerController? controller;
  final String Function(Duration) formatDuration;
  final PlayerControlHandle? handle;

  @override
  State<SeekableProgressBar> createState() => _SeekableProgressBarState();
}

class _SeekableProgressBarState extends State<SeekableProgressBar> {
  double _dragProgress = 0.0;
  bool _isDragging = false;
  // batch154：记录 initState 实际挂载的监听器类型——与 batch151 同款问题：
  // dispose 时重新评估 _controllerUsable，EXO 初始化中进入（挂 handle 流）再
  // 退出时会错误移除 controller listener，导致 handle 监听器泄漏
  bool _useHandleListener = false;

  /// EXO controller 是否可用（已初始化）
  bool get _controllerUsable =>
      widget.controller != null && widget.controller!.value.isInitialized;

  /// 当前播放位置（三引擎统一）
  Duration get _position {
    final c = widget.controller;
    if (_controllerUsable) return c!.value.position;
    return widget.handle?.currentPosition ?? Duration.zero;
  }

  /// 视频总时长（三引擎统一）
  Duration get _duration {
    final c = widget.controller;
    if (_controllerUsable) return c!.value.duration;
    return widget.handle?.totalDuration ?? Duration.zero;
  }

  @override
  void initState() {
    super.initState();
    if (_controllerUsable) {
      widget.controller!.addListener(_onChanged);
    } else {
      _useHandleListener = true;
      widget.handle?.positionMsListenable?.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    if (_useHandleListener) {
      widget.handle?.positionMsListenable?.removeListener(_onChanged);
    } else if (_controllerUsable) {
      widget.controller!.removeListener(_onChanged);
    }
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {});
  }

  /// 计算缓冲进度（0~1）；MPV/VLC 无 buffered 概念，返回 0
  double _bufferedProgress() {
    if (!_controllerUsable) return 0.0;
    final value = widget.controller!.value;
    if (value.duration.inMilliseconds <= 0 || value.buffered.isEmpty) return 0.0;
    return (value.buffered.last.end.inMilliseconds / value.duration.inMilliseconds)
        .clamp(0.0, 1.0);
  }

  /// 三引擎统一 seek
  void _seek(Duration target) {
    try {
      final handle = widget.handle;
      if (handle != null) {
        handle.seekTo(target);
        return;
      }
      widget.controller?.seekTo(target);
    } catch (e) {
      // controller 可能已被释放（非当前页背景延迟释放），忽略避免闪退
      AppLogger.warn('进度条 seek 失败，controller 可能已释放',
          data: {'error': e.toString()});
    }
  }

  /// 根据水平点击/拖拽位置计算进度百分比并执行 seek
  void _seekToPosition(double localDx, double totalWidth) {
    final duration = _duration;
    if (duration.inMilliseconds <= 0) return;

    final progress = (localDx / totalWidth).clamp(0.0, 1.0);
    final targetMs = (progress * duration.inMilliseconds).toInt();
    _seek(Duration(milliseconds: targetMs));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final duration = _duration;
    final position = _position;
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
              onTapUp: (details) {
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
                // 拖动过程中只更新预览 UI，不调用 seekTo
                // 避免高频调用导致 MediaCodec 崩溃，与 gesture_overlay.dart 设计原则一致
              },
              onHorizontalDragEnd: (_) {
                final duration = _duration;
                if (duration.inMilliseconds > 0) {
                  final targetMs =
                      (_dragProgress * duration.inMilliseconds).toInt();
                  _seek(Duration(milliseconds: targetMs));
                }
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
                      // 缓冲进度条（灰色，在线全屏页同款）
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: _bufferedProgress(),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white38,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
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
                            color:
                                _isDragging ? scheme.primary : scheme.onSurface,
                            shape: BoxShape.circle,
                            boxShadow: _isDragging
                                ? [
                                    BoxShadow(
                                      color:
                                          scheme.primary.withValues(alpha: 0.5),
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
