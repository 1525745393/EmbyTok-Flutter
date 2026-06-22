// 通用操作按钮：图标 + 标签，带按下缩放动画
// 支持 TV 遥控器焦点高亮：获得焦点时显示粉色圆角边框 + 缩放 1.05

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 带按下缩放动画的操作按钮
class PressableActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const PressableActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  State<PressableActionButton> createState() => _PressableActionButtonState();
}

class _PressableActionButtonState extends State<PressableActionButton> {
  bool _pressed = false;
  late final FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'ActionButton_${widget.label}');
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    final focused = _focusNode.hasFocus;
    if (_isFocused != focused) {
      setState(() => _isFocused = focused);
    }
  }

  // D-pad 确认键处理
  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.gameButtonA) {
      widget.onTap?.call();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // 响应式尺寸计算（按屏幕宽度缩放）
  double _responsiveSize(double base, [double maxScale = 1.7]) {
    final screenWidth = MediaQuery.of(context).size.width;
    final double scale;
    if (screenWidth <= 480.0) {
      scale = 1.0;
    } else if (screenWidth <= 800.0) {
      scale = 1.0 + ((screenWidth - 480.0) / 320.0) * 0.3;
    } else if (screenWidth <= 1200.0) {
      scale = 1.3 + ((screenWidth - 800.0) / 400.0) * 0.3;
    } else {
      scale = 1.6 + ((screenWidth - 1200.0) / 720.0) * 0.1;
    }
    return base * (scale > maxScale ? maxScale : scale);
  }

  @override
  Widget build(BuildContext context) {
    const duration = Duration(milliseconds: 120);
    final rs = _responsiveSize;

    // 焦点缩放优先级高于按下缩放
    final scale = _isFocused ? 1.05 : (_pressed ? 0.8 : 1.0);
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _onKeyEvent,
      child: GestureDetector(
        onTapDown: (_) {
          if (mounted) setState(() => _pressed = true);
        },
        onTapUp: (_) {
          if (mounted) setState(() => _pressed = false);
          widget.onTap?.call();
        },
        onTapCancel: () {
          if (mounted) setState(() => _pressed = false);
        },
        child: AnimatedScale(
          scale: scale,
          duration: duration,
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: duration,
            padding: EdgeInsets.all(rs(4)),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(rs(6)),
              border: _isFocused
                  ? Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    )
                  : Border.all(color: Colors.transparent, width: 2),
            ),
            child: Icon(
              widget.icon,
              color: widget.color,
              size: rs(26),
            ),
          ),
        ),
      ),
    );
  }
}
