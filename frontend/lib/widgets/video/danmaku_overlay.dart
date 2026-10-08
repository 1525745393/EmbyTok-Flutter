import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// 弹幕条目
class DanmakuItem { // 垂直位置比例 0~1

  const DanmakuItem({
    required this.text,
    required this.startMs,
    required this.y,
    this.color = Colors.white,
  });
  final String text;
  final Color color;
  final double startMs; // 起始时间（毫秒）
  final double y;
}

/// 弹幕叠加层：在视频上层滚动显示弹幕
///
/// 简单实现：根据当前播放时间显示匹配的弹幕，从右向左滚动。
/// 后续接入 dandanplay 等弹幕源时，只需替换弹幕数据源。
class DanmakuOverlay extends StatefulWidget {

  const DanmakuOverlay({
    super.key,
    required this.positionMs,
    required this.danmakus,
    this.enabled = true,
  });
  /// 当前播放位置（毫秒）
  final ValueNotifier<int> positionMs;

  /// 弹幕列表
  final List<DanmakuItem> danmakus;

  /// 是否启用
  final bool enabled;

  @override
  State<DanmakuOverlay> createState() => _DanmakuOverlayState();
}

class _DanmakuOverlayState extends State<DanmakuOverlay>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  int _lastPosition = 0;
  final List<_ActiveDanmaku> _active = [];
  Timer? _emitTimer;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    // 每 2 秒尝试发射一条新弹幕
    _emitTimer = Timer.periodic(const Duration(seconds: 2), (_) => _emit());
  }

  void _onTick(Duration elapsed) {
    if (!widget.enabled || !mounted) return;
    final pos = widget.positionMs.value;
    final delta = pos - _lastPosition;
    _lastPosition = pos;
    if (delta <= 0) return;

    setState(() {
      // 移动现有弹幕
      for (final d in _active) {
        d.x -= delta * 0.3; // 滚动速度
      }
      _active.removeWhere((d) => d.x < -200);
    });
  }

  void _emit() {
    if (!widget.enabled || !mounted || widget.danmakus.isEmpty) return;
    // 随机选一条弹幕
    final d = widget.danmakus[math.Random().nextInt(widget.danmakus.length)];
    setState(() {
      _active.add(_ActiveDanmaku(
        text: d.text,
        color: d.color,
        y: d.y,
        x: 1.0, // 从右侧开始（比例）
      ));
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _emitTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || _active.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: _active.map((d) {
              return Positioned(
                left: d.x * constraints.maxWidth,
                top: d.y * constraints.maxHeight,
                child: Text(
                  d.text,
                  style: TextStyle(
                    color: d.color,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    shadows: const [
                      Shadow(color: Colors.black, blurRadius: 4),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _ActiveDanmaku { // 水平位置比例 0~1

  _ActiveDanmaku({
    required this.text,
    required this.color,
    required this.y,
    required this.x,
  });
  final String text;
  final Color color;
  final double y;
  double x;
}
