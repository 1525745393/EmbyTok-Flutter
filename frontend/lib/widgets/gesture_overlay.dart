// 手势交互层：单击/双击/长按倍速/水平拖动进度/垂直滑动音量
// 设计要点：拖动过程中只更新预览 UI，不调用 seekTo（避免高频调用导致 MediaCodec 崩溃）
//           只有松手时才执行一次 seek
// 单击行为变更：原为切换播放/暂停，现改为切换控制层显示/隐藏（TikTok 风格）
// 垂直滑动：屏幕右侧 1/2 区域上下滑动调节音量（仅在 enableVerticalVolumeDrag=true 时启用，
//           避免和小屏 PageView 的垂直滑动切换视频冲突）

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';
import 'video/video_gesture_mixin.dart';

// 手势交互层：统一处理视频画面上的手势事件
class GestureOverlay extends ConsumerStatefulWidget {
  final Widget child;
  final MediaItem item;
  final VideoPlayerController? controller;
  // 单击回调：用于切换控制层显示/隐藏（由父组件 VideoPageItem 提供）
  final VoidCallback? onSingleTap;
  // 是否启用「长按倍速 / 水平拖动 seek」手势
  //
  // - true（默认）：全手势可用（小屏场景）
  // - false：仅单击 / 双击可用，长按和水平拖动被禁用
  //   用于全屏页控制层显示时，避免和控制层 Slider 抢手势
  final bool enableGestures;
  // 是否启用垂直滑动音量调节
  // - true：使用 onPan 同时处理水平/垂直拖动（全屏场景，无 PageView 冲突）
  // - false：仅启用水平拖动 seek（小屏场景，避免和 PageView 垂直滑动切换视频冲突）
  final bool enableVerticalVolumeDrag;

  const GestureOverlay({
    super.key,
    required this.child,
    required this.item,
    required this.controller,
    this.onSingleTap,
    this.enableGestures = true,
    this.enableVerticalVolumeDrag = false,
  });

  @override
  ConsumerState<GestureOverlay> createState() => _GestureOverlayState();
}

class _GestureOverlayState extends ConsumerState<GestureOverlay>
    with VideoGestureMixin {
  // ===== VideoGestureMixin 钩子实现 =====

  @override
  VideoPlayerController? get videoController => widget.controller;

  @override
  bool get gesturesEnabled => widget.enableGestures;

  @override
  void onSingleTap() {
    widget.onSingleTap?.call();
  }

  @override
  void onDoubleTapLeft() {
    super.onDoubleTapLeft();
  }

  @override
  void onDoubleTapRight() {
    super.onDoubleTapRight();
  }

  @override
  void onDoubleTapCenter() {
    triggerHeart();
    try {
      ref.read(favoritesProvider.notifier).toggleFavorite(widget.item);
    } catch (e) {
      AppLogger.warn('双击点赞失败', data: {'error': e.toString()});
    }
  }

  @override
  bool get handleLeftVerticalDrag => false;

  @override
  MediaItem? get currentItem => widget.item;

  @override
  void onLongPressEnd(LongPressEndDetails details) {
    super.onLongPressEnd(details);
    ref.read(playbackRateProvider.notifier).state = originalRate;
  }

  @override
  void dispose() {
    disposeGestureTimers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final duration = (c != null && c.value.isInitialized)
        ? c.value.duration
        : Duration.zero;

    final usePan = widget.enableVerticalVolumeDrag;

    return Stack(
      alignment: Alignment.center,
      children: [
        widget.child,
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: handleTapDown,
            onTap: handleTap,
            onLongPressStart: widget.enableGestures ? onLongPressStart : null,
            onLongPressEnd:
                widget.enableGestures ? onLongPressEnd : null,
            onLongPressCancel:
                widget.enableGestures ? () => onLongPressEnd(LongPressEndDetails()) : null,
            // Pan 模式：同时支持水平/垂直（全屏无 PageView 冲突）
            onPanStart: (widget.enableGestures && usePan) ? onPanStart : null,
            onPanUpdate: (widget.enableGestures && usePan) ? onPanUpdate : null,
            onPanEnd: (widget.enableGestures && usePan) ? onPanEnd : null,
            onPanCancel: (widget.enableGestures && usePan) ? onPanCancel : null,
            // 纯水平模式：小屏场景，不影响 PageView 垂直滑动
            onHorizontalDragStart: (widget.enableGestures && !usePan)
                ? onHorizontalDragStart
                : null,
            onHorizontalDragUpdate: (widget.enableGestures && !usePan)
                ? onHorizontalDragUpdate
                : null,
            onHorizontalDragEnd: (widget.enableGestures && !usePan)
                ? onHorizontalDragEnd
                : null,
            onHorizontalDragCancel: (widget.enableGestures && !usePan)
                ? onHorizontalDragCancel
                : null,
            child: const SizedBox.expand(),
          ),
        ),
        // 拖动进度条
        ValueListenableBuilder<Duration>(
          valueListenable: previewPositionNotifier,
          builder: (context, previewPos, _) {
            if (previewPos == Duration.zero) return const SizedBox.shrink();
            final currentPosition = previewPos;
            return Positioned(
              top: 48,
              left: 32,
              right: 32,
              child: _SeekPreviewBar(
                current: currentPosition,
                total: duration,
                offset: previewPos - dragStartPosition,
              ),
            );
          },
        ),
        // 音量调节 UI
        ValueListenableBuilder<bool>(
          valueListenable: showVolumeUINotifier,
          builder: (context, showVolume, _) {
            if (!showVolume || !isVolumeSide || dragAxis != 'v') {
              return const SizedBox.shrink();
            }
            return ValueListenableBuilder<double>(
              valueListenable: previewVolumeNotifier,
              builder: (context, volume, _) {
                return IgnorePointer(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            volume <= 0
                                ? Icons.volume_off
                                : volume < 0.5
                                    ? Icons.volume_down
                                    : Icons.volume_up,
                            color: Colors.white,
                            size: 36,
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: 120,
                            child: LinearProgressIndicator(
                              value: volume,
                              backgroundColor: Colors.white24,
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                              minHeight: 4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${(volume * 100).round()}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            '音量',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
        // 长按倍速中央大图标反馈
        ValueListenableBuilder<bool>(
          valueListenable: showSpeedBadgeNotifier,
          builder: (context, showSpeed, _) {
            if (!showSpeed) return const SizedBox.shrink();
            return IgnorePointer(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${kLongPressPlaybackRate.toStringAsFixed(0)}x',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -1,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        // 双击心形动画
        if (showHeart)
          const IgnorePointer(child: _FlyingHeart()),
        // 双击快进/快退视觉反馈
        if (showSeekFeedback)
          IgnorePointer(
            child: Positioned(
              top: 0,
              bottom: 0,
              left: isSeekForward ? null : 0,
              right: isSeekForward ? 0 : null,
              width: MediaQuery.of(context).size.width / 3,
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: isSeekForward
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    end: isSeekForward
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    colors: [
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.22),
                      Colors.transparent
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSeekForward
                          ? Icons.fast_forward
                          : Icons.fast_rewind,
                      color: Theme.of(context).colorScheme.onPrimary,
                      size: 48,
                      shadows: [
                        Shadow(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.33),
                            blurRadius: 8),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      // 累积偏移：连续双击时显示 +20s/+30s 等
                      '${isSeekForward ? '+' : '-'}${seekFeedbackCount * 10}s',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        shadows: [
                          Shadow(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.33),
                              blurRadius: 4),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ---- 内部子组件：拖动进度预览条 ----
class _SeekPreviewBar extends StatelessWidget {
  final Duration current;
  final Duration total;
  final Duration offset;

  const _SeekPreviewBar({
    required this.current,
    required this.total,
    required this.offset,
  });

  String _format(Duration d) {
    if (d.inSeconds < 0) return '0:00';
    if (d.inHours > 0) {
      final h = d.inHours;
      final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return '$h:$m:$s';
    }
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return '${m.toString().padLeft(1, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final progress = total.inMilliseconds > 0
        ? current.inMilliseconds / total.inMilliseconds
        : 0.0;
    final clampedProgress = progress.clamp(0.0, 1.0);

    final isForward = offset >= Duration.zero;
    final offsetText =
        '${isForward ? '+' : '-'}${(offset.inSeconds.abs() ~/ 1)}s';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: Theme.of(context).colorScheme.primary, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                isForward ? Icons.fast_forward : Icons.fast_rewind,
                color: Theme.of(context).colorScheme.primary,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                offsetText,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${_format(current)} / ${_format(total)}',
                style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: clampedProgress,
            backgroundColor:
                Theme.of(context).colorScheme.onSurface.withOpacity(0.14),
            valueColor:
                AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
          ),
        ],
      ),
    );
  }
}

// ---- 内部子组件：飞行心形 ----
class _FlyingHeart extends StatefulWidget {
  const _FlyingHeart();

  @override
  State<_FlyingHeart> createState() => _FlyingHeartState();
}

class _FlyingHeartState extends State<_FlyingHeart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _opacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _scale = Tween<double>(begin: 0.6, end: 2.8).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.scale(
            scale: _scale.value,
            child: Icon(
              Icons.favorite,
              color: Theme.of(context).colorScheme.primary,
              size: 96,
              shadows: [
                Shadow(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.33),
                    blurRadius: 16,
                    offset: Offset(0, 4)),
              ],
            ),
          ),
        );
      },
    );
  }
}
