import 'dart:async';
import 'package:flutter/material.dart';
import 'danmaku_service.dart';

/// 弹幕渲染层
/// 叠加在视频上层，按播放时间滚动显示弹幕
class DanmakuOverlay extends StatefulWidget {
  /// 播放控制器，用于获取当前时间
  final Stream<Duration> positionStream;
  final List<DanmakuItem> danmakus;
  final bool enabled;
  final double fontSize;
  final double opacity;

  const DanmakuOverlay({
    super.key,
    required this.positionStream,
    required this.danmakus,
    this.enabled = true,
    this.fontSize = 18,
    this.opacity = 0.9,
  });

  @override
  State<DanmakuOverlay> createState() => _DanmakuOverlayState();
}

class _DanmakuOverlayState extends State<DanmakuOverlay>
    with SingleTickerProviderStateMixin {
  late StreamSubscription<Duration> _sub;
  final List<_ActiveDanmaku> _active = [];
  int _laneCount = 8; // 轨道数
  final List<double> _laneY = [];
  double _currentTime = 0;
  double _width = 0;
  double _height = 0;

  @override
  void initState() {
    super.initState();
    _sub = widget.positionStream.listen((pos) {
      _onPosition(pos.inMilliseconds / 1000.0);
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  void _onPosition(double time) {
    if (!widget.enabled) return;
    _currentTime = time;
    // 清理超过5秒未出现的弹幕（已滚出屏幕）
    _active.removeWhere((d) => time - d.startTime > 8);
    // 查找在当前时间点应该出现的新弹幕
    for (final dm in widget.danmakus) {
      if (dm.time <= time && dm.time > time - 0.5) {
        // 检查是否已经在活跃列表中
        if (!_active.any((a) => a.item == dm)) {
          _spawn(dm);
        }
      }
    }
    if (mounted) setState(() {});
  }

  void _spawn(DanmakuItem dm) {
    // 找一条空闲轨道
    int lane = -1;
    for (int i = 0; i < _laneCount; i++) {
      final last = _active.where((a) => a.lane == i).toList();
      if (last.isEmpty || _currentTime - last.last.startTime > 3) {
        lane = i;
        break;
      }
    }
    lane = lane < 0 ? 0 : lane;
    _active.add(_ActiveDanmaku(
      item: dm,
      lane: lane,
      startTime: _currentTime,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      _width = constraints.maxWidth;
      _height = constraints.maxHeight;
      // 按高度计算轨道数
      _laneCount = (_height / 30).floor().clamp(4, 12);
      _laneY.clear();
      for (int i = 0; i < _laneCount; i++) {
        _laneY.add(i * 30.0);
      }

      return IgnorePointer(
        child: Stack(
          children: [
            for (final a in _active)
              _buildDanmaku(a, _laneY[a.lane.clamp(0, _laneY.length - 1)]),
          ],
        ),
      );
    });
  }

  Widget _buildDanmaku(_ActiveDanmaku a, double top) {
    final dm = a.item;
    final elapsed = _currentTime - a.startTime;
    // 滚动弹幕：从右到左，8秒滚完
    final travel = (_width + 200) * (elapsed / 8.0);
    final left = _width - travel;

    Color color;
    try {
      color = Color(int.parse(dm.color.replaceFirst('#', '0xFF')));
    } catch (_) {
      color = Colors.white;
    }

    return Positioned(
      top: top,
      left: left,
      child: Opacity(
        opacity: widget.opacity,
        child: Text(
          dm.text,
          style: TextStyle(
            color: color,
            fontSize: widget.fontSize,
            fontWeight: FontWeight.w500,
            shadows: const [
              Shadow(blurRadius: 2, color: Colors.black, offset: Offset(1, 1)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveDanmaku {
  final DanmakuItem item;
  final int lane;
  final double startTime;
  _ActiveDanmaku({required this.item, required this.lane, required this.startTime});
}
