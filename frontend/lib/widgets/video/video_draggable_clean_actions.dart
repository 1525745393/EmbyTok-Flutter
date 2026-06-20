// 纯净模式下的可拖动按钮区组件
// 初始位置：屏幕右下角（受 bottomSafeArea 和 rightSafeArea 约束）

import 'package:flutter/material.dart';

class DraggableCleanActions extends StatefulWidget {
  final Size containerSize;
  final double buttonWidth;
  final Widget buttons;
  final double bottomSafeArea; // 底部安全区（导航栏 + 手势条 + 边距）
  final double rightSafeArea; // 右侧安全区（边距）

  const DraggableCleanActions({
    super.key,
    required this.containerSize,
    required this.buttonWidth,
    required this.buttons,
    this.bottomSafeArea = 100,
    this.rightSafeArea = 16,
  });

  @override
  DraggableCleanActionsState createState() => DraggableCleanActionsState();
}

class DraggableCleanActionsState extends State<DraggableCleanActions> {
  late Offset _offset;
  Offset? _startPointer;
  Offset? _startOffset;
  bool _isDragging = false;
  double _dragDistance = 0.0;
  double _opacity = 0.0;

  static const double _kDragThreshold = 10.0;
  static const double _kScaleFactor = 1.1;
  static const int _kHeightApprox = 140;

  @override
  void initState() {
    super.initState();
    _offset = Offset(
      widget.containerSize.width - widget.buttonWidth - widget.rightSafeArea,
      widget.containerSize.height - _kHeightApprox - widget.bottomSafeArea,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _opacity = 1.0);
    });
  }

  @override
  void didUpdateWidget(covariant DraggableCleanActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.containerSize != widget.containerSize) {
      setState(() {
        _offset = Offset(
          _offset.dx.clamp(0.0, widget.containerSize.width - widget.buttonWidth),
          _offset.dy.clamp(0.0, widget.containerSize.height - _kHeightApprox),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        AnimatedPositioned(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          left: _offset.dx,
          top: _offset.dy,
          child: AnimatedOpacity(
            opacity: _opacity,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: Listener(
              onPointerDown: (event) {
                _startPointer = event.localPosition;
                _startOffset = _offset;
                _dragDistance = 0.0;
              },
              onPointerMove: (event) {
                if (_startPointer == null || _startOffset == null) return;
                final delta = event.localPosition - _startPointer!;
                _dragDistance = delta.distance;

                if (!_isDragging && _dragDistance > _kDragThreshold) {
                  setState(() => _isDragging = true);
                }

                if (_isDragging) {
                  setState(() {
                    double newX = _startOffset!.dx + delta.dx;
                    double newY = _startOffset!.dy + delta.dy;
                    newX = newX.clamp(
                        0.0, widget.containerSize.width - widget.buttonWidth);
                    newY = newY
                        .clamp(0.0, widget.containerSize.height - _kHeightApprox);
                    _offset = Offset(newX, newY);
                  });
                }
              },
              onPointerUp: (_) {
                _startPointer = null;
                _startOffset = null;
                if (_isDragging) setState(() => _isDragging = false);
                _dragDistance = 0.0;
              },
              child: IgnorePointer(
                ignoring: _isDragging,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  transform: Matrix4.identity()
                    ..scale(_isDragging ? _kScaleFactor : 1.0),
                  child: Container(
                    width: widget.buttonWidth,
                    height: _kHeightApprox.toDouble(),
                    padding: const EdgeInsets.only(right: 16),
                    alignment: Alignment.centerRight,
                    decoration: _isDragging
                        ? BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: scheme.onSurface.withOpacity(0.25),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ],
                          )
                        : null,
                    child: widget.buttons,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
