// 手势交互层：单击/双击/长按/水平拖动
// 包裹在视频播放器外层，不拦截垂直滑动（由上层 PageView 处理）

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/constants.dart';

/// 双击间隔（与单击区分）
const int _kDoubleTapMs = 300;

/// 连续两次"双击"之间的最小间隔：避免快速连点产生重复 API 请求
const int _kDoubleTapDebounceMs = 400;

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

    setState(() {
      _showHeart = true;
    });
    unawaited(ref.read(favoritesProvider.notifier).toggleFavorite(widget.item));
  }

  // ---- 长按倍速 ----
  void _onLongPressStart() {
    final c = widget.controller;
    if (c == null || !c.value.isInitialized) return;
    _isLongPressing = true;
    c.setPlaybackRate(kLongPressPlaybackRate);
  }

  void _onLongPressEnd() {
    if (!_isLongPressing) return;
    _isLongPressing = false;
    final c = widget.controller;
    if (c == null || !c.value.isInitialized) return;
    c.setPlaybackRate(ref.read(playbackRateProvider));
  }

  // ---- 水平拖动（快进/快退） ----
  void _onHorizontalDragStart(DragStartDetails d) {
    final c = widget.controller;
    if (c == null || !c.value.isInitialized) return;
    _isDragging = true;
    _dragStartX = d.globalPosition.dx;
    _dragStartPosition = c.value.position;
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
    c.seekTo(clamped);
  }

  void _onHorizontalDragEnd() {
    _isDragging = false;
  }

  // ---- 单击/双击区分：300ms 定时器 ----
  void _handleTap() {
    if (_pendingSingleTap) {
      _singleTapTimer?.cancel();
      _pendingSingleTap = false;
      _onDoubleTap();
    } else {
      _pendingSingleTap = true;
      _singleTapTimer =
          Timer(const Duration(milliseconds: _kDoubleTapMs), () {
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
              color: Color(0xFFFF5983),
              size: 96,
              shadows: [
                Shadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, 4)),
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
        color: Colors.black87,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE91E63), width: 1.5),
      ),
      child: Text(
        '${speed.toStringAsFixed(1)}x',
        style: const TextStyle(
          color: Color(0xFFFF5983),
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
