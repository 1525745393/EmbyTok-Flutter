import 'dart:async';

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
/// batch156-F1：弹幕严格按播放时间对齐——按 DanmakuItem.startMs 排序维护
/// 发射游标，仅发射 startMs 落在 [positionMs, positionMs+提前窗口] 内的弹幕；
/// 不再随机取整集弹幕（此前弹幕与视频内容完全错乱）。
class DanmakuOverlay extends StatefulWidget {

  const DanmakuOverlay({
    super.key,
    required this.positionMs,
    required this.danmakus,
    this.enabled = true,
    this.fontSize = 16,
    this.opacity = 1.0,
    this.scrollSpeed = 0.3,
  });
  /// 当前播放位置（毫秒）
  final ValueNotifier<int> positionMs;

  /// 弹幕列表
  final List<DanmakuItem> danmakus;

  /// 是否启用
  final bool enabled;

  /// 弹幕字号（P3 高级设置）
  final double fontSize;

  /// 弹幕透明度 0~1（P3 高级设置）
  final double opacity;

  /// 滚动速度：每毫秒水平移动比例（P3 高级设置，越小越慢）
  final double scrollSpeed;

  @override
  State<DanmakuOverlay> createState() => _DanmakuOverlayState();
}

class _DanmakuOverlayState extends State<DanmakuOverlay>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  int _lastPosition = 0;
  final List<_ActiveDanmaku> _active = [];
  Timer? _emitTimer;
  // batch156-F1：按 startMs 排序后的弹幕池 + 发射游标（弹幕时间对齐）
  List<DanmakuItem> _sortedDanmakus = const [];
  int _emitCursor = 0;
  /// 发射提前窗口：startMs 落在 [pos, pos+提前窗口] 内的弹幕立即发射（毫秒）
  static const int _emitAheadMs = 4000;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    _sortDanmakus();
    // 每 500ms 尝试发射一次新弹幕（原 2s 一次太慢，时间窗口内多条弹幕会堆积延迟）
    _emitTimer = Timer.periodic(const Duration(milliseconds: 500), (_) => _emit());
  }

  @override
  void didUpdateWidget(covariant DanmakuOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 弹幕池变化（切集/换视频）时重置游标并重新排序
    if (!identical(oldWidget.danmakus, widget.danmakus)) {
      _emitCursor = 0;
      _sortDanmakus();
    }
  }

  void _sortDanmakus() {
    final list = List<DanmakuItem>.from(widget.danmakus)
      ..sort((a, b) => a.startMs.compareTo(b.startMs));
    _sortedDanmakus = list;
  }

  void _onTick(Duration elapsed) {
    if (!widget.enabled || !mounted) return;
    final pos = widget.positionMs.value;
    final delta = pos - _lastPosition;
    _lastPosition = pos;
    if (delta <= 0) return;

    setState(() {
      // 移动现有弹幕（P3：速度可配置）
      for (final d in _active) {
        d.x -= delta * widget.scrollSpeed;
      }
      _active.removeWhere((d) => d.x < -200);
    });
  }

  void _emit() {
    if (!widget.enabled || !mounted || _sortedDanmakus.isEmpty) return;
    final pos = widget.positionMs.value;
    // 跳过已远过期（seek 前进越过）的弹幕，避免补发
    while (_emitCursor < _sortedDanmakus.length &&
        _sortedDanmakus[_emitCursor].startMs < pos - 500) {
      _emitCursor++;
    }
    // 发射落在 [pos, pos + 提前窗口] 内的全部弹幕
    final windowEnd = pos + _emitAheadMs;
    final toEmit = <DanmakuItem>[];
    while (_emitCursor < _sortedDanmakus.length &&
        _sortedDanmakus[_emitCursor].startMs <= windowEnd) {
      toEmit.add(_sortedDanmakus[_emitCursor]);
      _emitCursor++;
    }
    if (toEmit.isEmpty) return;
    setState(() {
      for (final d in toEmit) {
        _active.add(_ActiveDanmaku(
          text: d.text,
          color: d.color,
          y: d.y,
          x: 1.0, // 从右侧开始（比例）
        ));
      }
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
                    color: d.color.withValues(alpha: widget.opacity),
                    fontSize: widget.fontSize,
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
