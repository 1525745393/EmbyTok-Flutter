// 手势交互层：单击/双击/长按/水平拖动/垂直滑动
// 包裹在视频播放器外层，支持快进快退视觉反馈、倍速提示、下滑切换

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/constants.dart';

// 手势交互层：根据任务要求，统一处理视频画面上的手势事件
class GestureOverlay extends ConsumerStatefulWidget {
  final Widget child;
  final MediaItem item;
  final VideoPlayerController? controller;
  final VoidCallback? onSwipeDown; // 向下滑动切换下一个视频
  final VoidCallback? onTap; // 单击回调（用于显示信息面板）

  const GestureOverlay({
    super.key,
    required this.child,
    required this.item,
    required this.controller,
    this.onSwipeDown,
    this.onTap,
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
  bool _showHeart = false;

  // 快进/快退视觉反馈
  int? _seekOffset; // 当前偏移秒数（正数为快进，负数为快退）
  bool _showSeekFeedback = false;

  // 向下滑动检测
  double _verticalDragStartY = 0.0;
  bool _isVerticalDragging = false;

  // ---- 单击 ----
  void _onSingleTap() {
    // 先调用 onTap 回调（显示信息面板）
    widget.onTap?.call();
    
    // 然后切换播放/暂停
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
    setState(() {
      _showHeart = true;
    });
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) {
        setState(() {
          _showHeart = false;
        });
      }
    });
    unawaited(ref.read(favoritesProvider.notifier).toggleFavorite(widget.item));
  }

  // ---- 长按倍速 ----
  void _onLongPressStart() {
    final c = widget.controller;
    if (c == null || !c.value.isInitialized) return;
    _isLongPressing = true;
    c.setPlaybackSpeed(kLongPressPlaybackRate);
  }

  void _onLongPressEnd() {
    if (!_isLongPressing) return;
    _isLongPressing = false;
    final c = widget.controller;
    if (c == null || !c.value.isInitialized) return;
    c.setPlaybackSpeed(ref.read(playbackRateProvider));
  }

  // ---- 水平拖动（快进/快退） ----
  void _onHorizontalDragStart(DragStartDetails d) {
    final c = widget.controller;
    if (c == null || !c.value.isInitialized) return;
    _isDragging = true;
    _dragStartX = d.globalPosition.dx;
    _dragStartPosition = c.value.position;
    setState(() {
      _showSeekFeedback = true;
      _seekOffset = 0;
    });
  }

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

    // 更新视觉反馈
    final seekSeconds = (seekMs / 1000).round();
    setState(() {
      _seekOffset = seekSeconds;
    });

    c.seekTo(clamped);
  }

  void _onHorizontalDragEnd() {
    _isDragging = false;
    setState(() {
      _showSeekFeedback = false;
      _seekOffset = null;
    });
  }

  // ---- 单击/双击区分：300ms 定时器 ----
  void _handleTap() {
    if (_pendingSingleTap) {
      // 300ms 内第二次点击 -> 双击
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

  // ---- 垂直滑动（向下滑动切换下一个视频） ----
  void _onVerticalDragStart(DragStartDetails d) {
    _isVerticalDragging = true;
    _verticalDragStartY = d.globalPosition.dy;
  }

  void _onVerticalDragUpdate(DragUpdateDetails d) {
    // 可选：添加向下滑动的视觉提示
  }

  void _onVerticalDragEnd(DragEndDetails d) {
    if (!_isVerticalDragging) return;
    _isVerticalDragging = false;

    // 检测向下滑动的速度或距离
    final velocity = d.primaryVelocity ?? 0;
    // 如果向下滑动速度足够快（> 500），触发切换
    if (velocity > 500 && widget.onSwipeDown != null) {
      widget.onSwipeDown!();
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
        // 手势识别层：透明覆盖层，处理水平、垂直和点击手势
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
            onVerticalDragStart: _onVerticalDragStart,
            onVerticalDragUpdate: _onVerticalDragUpdate,
            onVerticalDragEnd: _onVerticalDragEnd,
            child: Container(color: Colors.transparent),
          ),
        ),
        // 双击心形动画
        if (_showHeart)
          const IgnorePointer(
            child: _FlyingHeart(),
          ),
        // 快进/快退视觉反馈
        if (_showSeekFeedback && _seekOffset != null)
          IgnorePointer(
            child: Positioned(
              top: 96,
              child: _SeekFeedbackBadge(offset: _seekOffset!),
            ),
          ),
        // 长按倍速提示
        if (_isLongPressing)
          const IgnorePointer(
            child: Positioned(
              top: 96,
              child: _SpeedBadge(speed: kLongPressPlaybackRate),
            ),
          ),
      ],
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
    with TickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;
  late final Animation<double> _rotation;
  late final Animation<Offset> _position;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // 淡出动画
    _opacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );

    // 缩放动画：先放大再缩小
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.6, end: 1.4), weight: 0.3),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 2.5), weight: 0.7),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    // 旋转动画
    _rotation = Tween<double>(begin: -0.1, end: 0.1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );

    // 位置动画：向上飘动
    _position = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -0.15),
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

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
        return SlideTransition(
          position: _position,
          child: Opacity(
            opacity: _opacity.value,
            child: Transform.scale(
              scale: _scale.value,
              child: Transform.rotate(
                angle: _rotation.value,
                child: const Icon(
                  Icons.favorite,
                  color: Color(0xFFFF5983),
                  size: 96,
                  shadows: [
                    Shadow(
                      color: Colors.black54,
                      blurRadius: 20,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
              ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 黄色闪电图标
          const Icon(
            Icons.bolt,
            color: Color(0xFFFFD700),
            size: 18,
          ),
          const SizedBox(width: 8),
          // 倍速文字
          Text(
            '${speed.toStringAsFixed(1)}x',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 8),
          // 双箭头图标
          const Icon(
            Icons.fast_forward,
            color: Colors.white,
            size: 16,
          ),
        ],
      ),
    );
  }
}

// ---- 内部子组件：快进/快退视觉反馈徽章 ----
class _SeekFeedbackBadge extends StatelessWidget {
  final int offset; // 偏移秒数（正数为快进，负数为快退）

  const _SeekFeedbackBadge({required this.offset});

  @override
  Widget build(BuildContext context) {
    final isForward = offset > 0;
    final icon = isForward ? Icons.fast_forward : Icons.fast_rewind;
    final displayText = offset > 0 ? '+${offset}s' : '${offset}s';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 快进/快退图标
          Icon(
            icon,
            color: Colors.white.withOpacity(0.9),
            size: 28,
          ),
          const SizedBox(height: 8),
          // 偏移秒数
          Text(
            displayText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}
