// 均衡器动画组件
//
// 三根跳动柱子的动态均衡器动画，参考主流音乐 App 的"正在播放"指示。
// 从 synology_music_view.dart 拆分出来，提升代码可维护性。

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 三根跳动柱子的动态均衡器动画
class EqualizerBars extends StatefulWidget {

  const EqualizerBars({super.key, required this.color, required this.size});
  final Color color;
  final double size;

  @override
  State<EqualizerBars> createState() => _EqualizerBarsState();
}

class _EqualizerBarsState extends State<EqualizerBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<double> _phases = [0.0, 2.1, 4.2];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value * 2 * math.pi;
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (final phase in _phases)
                Container(
                  width: widget.size / 4,
                  height: widget.size *
                      (0.35 + 0.55 * (0.5 + 0.5 * math.sin(t + phase))),
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
