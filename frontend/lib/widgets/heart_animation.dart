// 双击点赞动画：心形图标放大 + 渐隐

import 'package:flutter/material.dart';

import '../utils/colors.dart';

// 双击触发的点赞心形动画（单次播放）
class HeartAnimation extends StatefulWidget {
  final bool visible;
  final Widget child;
  final Duration duration;
  final double scale;

  const HeartAnimation({
    super.key,
    required this.visible,
    required this.child,
    this.duration = const Duration(milliseconds: 700),
    this.scale = 2.5,
  });

  @override
  State<HeartAnimation> createState() => _HeartAnimationState();
}

class _HeartAnimationState extends State<HeartAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _opacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _scale = Tween<double>(begin: 1.0, end: widget.scale).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(covariant HeartAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && !oldWidget.visible) {
      _controller.reset();
      _controller.forward().whenComplete(() {
        // 动画结束后保持状态；再次收到 visible 变化才会重置
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        widget.child,
        if (widget.visible)
          AnimatedBuilder(
            animation: _controller,
            builder: (_, __) {
              return IgnorePointer(
                child: Opacity(
                  opacity: _opacity.value,
                  child: Transform.scale(
                    scale: _scale.value,
                    child: const Icon(
                      Icons.favorite,
                      color: historyPink,
                      size: 96,
                      shadows: [
                        Shadow(
                          color: Colors.black54,
                          blurRadius: 16,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
