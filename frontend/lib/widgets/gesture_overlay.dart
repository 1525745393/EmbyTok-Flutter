// 手势交互层：单击/双击/长按/水平拖动
// 包裹在视频播放器外层，不拦截垂直滑动（由上层 PageView 处理）

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/colors.dart';
import '../utils/constants.dart';

/// 连续两次"双击"之间的最小间隔：避免快速连点产生重复 API 请求
const int _kDoubleTapDebounceMs = 400;

/// 将 Duration 格式化为时间字符串：>=1 小时显示 HH:MM:SS，<1 小时显示 MM:SS
String _formatDuration(Duration d) {
  if (d.isNegative) return '00:00'; // 安全处理：避免负时长
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  if (h >= 1) {
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

class GestureOverlay extends ConsumerStatefulWidget {
  final Widget child;
  final MediaItem item;
  final VideoPlayerController? controller;

  const GestureOverlay({
    super.key,
    required this.child,
    required this.item,
    required this.controller,
  });

  @override
  ConsumerState<GestureOverlay> createState() => _GestureOverlayState();
}

class _GestureOverlayState extends ConsumerState<GestureOverlay> {
  Timer? _singleTapTimer;
  bool _pendingSingleTap = false;
  bool _isLongPressing = false;
  bool _isDragging = false;
  double _dragStartX = 0.0;
  Duration _dragStartPosition = Duration.zero;
  Duration? _currentTargetPosition;      // 拖动中的目标位置（用于显示进度条）
  Duration _dragOffset = Duration.zero;   // 相对于起始点的偏移量
  bool _showHeart = false;
  DateTime? _lastDoubleTapAt;

  // ---- 单击 ----
  void _onSingleTap() {
    final c = widget.controller;
    if (c == null || !c.value.isInitialized) return;
    if (c.value.isPlaying) {
      c.pause();
    } else {
      c.play();
    }
    ref.read(isPlayingProvider.notifier).state = c.value.isPlaying;
  }

  // ---- 双击 ----
  void _onDoubleTap() {
    // 400ms 内的重复"双击"忽略，避免反复触发 API
    final now = DateTime.now();
    if (_lastDoubleTapAt != null &&
        now.difference(_lastDoubleTapAt!).inMilliseconds < _kDoubleTapDebounceMs) {
      return;
    }
    _lastDoubleTapAt = now;

    // 触觉反馈 + 心形动画
    HapticFeedback.lightImpact();
    setState(() {
      _showHeart = true;
    });
    unawaited(ref.read(favoritesProvider.notifier).toggleFavorite(widget.item));
  }

  // ---- 长按倍速 ----
  void _onLongPressStart() {
    final c = widget.controller;
    if (c == null || !c.value.isInitialized) return;
    HapticFeedback.mediumImpact();
    _isLongPressing = true;
    c.setPlaybackSpeed(kLongPressPlaybackRate);
  }

  void _onLongPressEnd() {
    if (!_isLongPressing) return;
    _isLongPressing = false;
    final c = widget.controller;
    if (c == null || !c.value.isInitialized) return;
    HapticFeedback.lightImpact();
    c.setPlaybackSpeed(ref.read(playbackRateProvider));
  }

  // ---- 水平拖动（快进/快退） ----
  void _onHorizontalDragStart(DragStartDetails d) {
    final c = widget.controller;
    if (c == null || !c.value.isInitialized) return;
    setState(() {
      _isDragging = true;
      _dragStartX = d.globalPosition.dx;
      _dragStartPosition = c.value.position;
      _currentTargetPosition = c.value.position;
      _dragOffset = Duration.zero;
    });
    HapticFeedback.selectionClick();
  }

  int _lastSeenSeconds = -1;
  void _onHorizontalDragUpdate(DragUpdateDetails d) {
    if (!_isDragging) return;
    final c = widget.controller;
    if (c == null || !c.value.isInitialized) return;
    final dx = d.globalPosition.dx - _dragStartX;
    final seekMs = (dx * kSeekPerPixelMs).toInt();
    final target = _dragStartPosition + Duration(milliseconds: seekMs);
    final clamped = target < Duration.zero
        ? Duration.zero
        : target > c.value.duration
            ? c.value.duration
            : target;
    c.seekTo(clamped);
    // 每跨越 5 秒边界触发一次 haptic 反馈
    final secs = clamped.inSeconds ~/ kSwipeProgressIntervalSeconds;
    if (_lastSeenSeconds != secs) {
      _lastSeenSeconds = secs;
      HapticFeedback.selectionClick();
    }
    // 更新进度条显示（通过 setState 触发 UI 重绘）
    setState(() {
      _currentTargetPosition = clamped;
      _dragOffset = clamped - _dragStartPosition;
    });
  }

  void _onHorizontalDragEnd() {
    HapticFeedback.lightImpact(); // 拖动结束的稍强震动
    // 先隐藏 _isDragging（让 build 中进度条开始淡出），延迟清除位置数据（让 AnimatedOpacity 有时间完成淡出）
    setState(() {
      _isDragging = false;
    });
    Future.delayed(
        Duration(milliseconds: kProgressBarFadeOutMs), () {
      if (mounted) {
        setState(() {
          _currentTargetPosition = null;
        });
      }
    });
    _lastSeenSeconds = -1;
  }

  // ---- 单击/双击区分：300ms 定时器 ----
  void _handleTap() {
    // 防御性：拖动中忽略单击，避免手势竞技场残留事件触发播放/暂停
    if (_isDragging) return;
    if (_pendingSingleTap) {
      _singleTapTimer?.cancel();
      _pendingSingleTap = false;
      _onDoubleTap();
    } else {
      _pendingSingleTap = true;
      _singleTapTimer =
          Timer(const Duration(milliseconds: kDoubleTapMs), () {
        if (_pendingSingleTap) {
          _pendingSingleTap = false;
          _onSingleTap();
        }
      });
    }
  }

  @override
  void dispose() {
    _singleTapTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        widget.child,
        // 手势识别层：透明覆盖层，仅处理水平 & 点击，不拦截垂直滑动
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _handleTap,
            onLongPressStart: (_) => _onLongPressStart(),
            onLongPressEnd: (_) => _onLongPressEnd(),
            onLongPressCancel: _onLongPressEnd,
            onHorizontalDragStart: _onHorizontalDragStart,
            onHorizontalDragUpdate: _onHorizontalDragUpdate,
            onHorizontalDragEnd: (_) => _onHorizontalDragEnd(),
            onHorizontalDragCancel: _onHorizontalDragEnd,
            child: Container(color: Colors.transparent),
          ),
        ),
        // 双击心形动画
        if (_showHeart)
          IgnorePointer(
            child: _FlyingHeart(
              onComplete: () {
                if (mounted) {
                  setState(() {
                    _showHeart = false;
                  });
                }
              },
            ),
          ),
        // 长按倍速提示
        if (_isLongPressing)
          const IgnorePointer(
            child: Positioned(
              top: 48,
              child: _SpeedBadge(speed: kLongPressPlaybackRate),
            ),
          ),
        // 水平拖动进度条浮层
        // 用 AnimatedOpacity 做淡入淡出动画：
        //   _isDragging = true  且 _currentTargetPosition != null → opacity=1.0 (淡入/显示)
        //   _isDragging = false 且 _currentTargetPosition != null → opacity=0.0 (淡出中，300ms 后状态被清除)
        if (_currentTargetPosition != null)
          IgnorePointer(
            child: Positioned(
              top: 120,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                duration: Duration(
                  milliseconds: _isDragging
                      ? kProgressBarFadeInMs
                      : kProgressBarFadeOutMs,
                ),
                opacity: _isDragging ? 1.0 : 0.0,
                curve: Curves.easeOut,
                child: _ProgressBarOverlay(
                  currentPosition: _currentTargetPosition!,
                  totalDuration:
                      widget.controller?.value.duration ?? Duration.zero,
                  offsetFromStart: _dragOffset,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ---- 内部子组件：飞行心形 ----
class _FlyingHeart extends StatefulWidget {
  final VoidCallback onComplete;
  const _FlyingHeart({required this.onComplete});

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
    _ctrl.forward().whenComplete(() {
      widget.onComplete();
    });
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
            child: const Icon(
              Icons.favorite,
              color: historyPink,
              size: 96,
              shadows: [
                Shadow(color: black54, blurRadius: 16, offset: Offset(0, 4)),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---- 内部子组件：倍速徽章（长按期间显示） ----
class _SpeedBadge extends StatelessWidget {
  final double speed;
  const _SpeedBadge({required this.speed});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: black87,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryPink, width: 1.5),
      ),
      child: Text(
        '${speed.toStringAsFixed(1)}x',
        style: const TextStyle(
          color: historyPink,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ---- 内部子组件：水平拖动进度条浮层 ----
/// 显示当前播放位置、目标位置、方向图标和可视化进度条
class _ProgressBarOverlay extends StatelessWidget {
  final Duration currentPosition;
  final Duration totalDuration;
  final Duration offsetFromStart;

  const _ProgressBarOverlay({
    required this.currentPosition,
    required this.totalDuration,
    required this.offsetFromStart,
  });

  @override
  Widget build(BuildContext context) {
    // 安全检查：总时长为 0 时不显示（避免除零）
    if (totalDuration.inMilliseconds <= 0) return const SizedBox.shrink();

    final progress = currentPosition.inMilliseconds / totalDuration.inMilliseconds;
    final clampedProgress = progress.clamp(0.0, 1.0);
    final isForward = !offsetFromStart.isNegative; // 正向（快进）true / 反向（快退）false
    final offsetSeconds = (offsetFromStart.inMilliseconds / 1000).truncate().abs();

    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: overlayBlack,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: primaryPink.withOpacity(0.6), width: 1.0),
          boxShadow: const [
            BoxShadow(
              color: black54,
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 上排：方向图标 + 偏移量 + 时间信息
            Row(
              children: [
                Icon(
                  isForward ? Icons.fast_forward : Icons.fast_rewind,
                  color: primaryPink,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '${isForward ? '+' : '-'}$offsetSeconds s',
                  style: const TextStyle(
                    color: textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDuration(currentPosition),
                  style: const TextStyle(
                    color: textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  ' / ${_formatDuration(totalDuration)}',
                  style: const TextStyle(
                    color: textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // 下排：可视化进度条（灰色底 + 粉色填充）
            LayoutBuilder(
              builder: (context, constraints) {
                final barWidth = constraints.maxWidth;
                return Stack(
                  children: [
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    // 填充动画：从 0 平滑扩展到目标进度
                    AnimatedContainer(
                      duration: const Duration(milliseconds: kProgressBarAnimMs),
                      curve: Curves.easeOut,
                      height: 6,
                      width: barWidth * clampedProgress,
                      decoration: BoxDecoration(
                        color: primaryPink,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    // 当前位置小指示器
                    Positioned(
                      left: barWidth * clampedProgress - 6,
                      top: -3,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: primaryPink,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: primaryPink.withOpacity(0.6),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
