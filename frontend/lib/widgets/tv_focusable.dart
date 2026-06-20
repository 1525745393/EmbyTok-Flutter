// TV 遥控器焦点高亮组件
// 为任意子组件添加 D-pad 焦点支持：粉色圆角边框 + 缩放 1.05 动画
// 用于 TV 模式下的按钮、卡片、Chip 等可聚焦元素

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// TV 焦点高亮容器
///
/// 包裹任意子组件，在获得焦点时显示粉色圆角边框 + 缩放 1.05 动画。
/// 支持点击回调，兼容触屏和 D-pad 遥控器。
class TvFocusable extends StatefulWidget {
  /// 子组件
  final Widget child;

  /// 点击回调（触屏点击或 D-pad 确认键）
  final VoidCallback? onTap;

  /// 焦点边框圆角，默认 12
  final double borderRadius;

  /// 焦点边框宽度，默认 2
  final double borderWidth;

  /// 焦点缩放比例，默认 1.05
  final double focusScale;

  /// 动画时长，默认 150ms
  final Duration duration;

  /// 是否自动获取焦点（首次构建时）
  final bool autofocus;

  /// 焦点变化回调
  final ValueChanged<bool>? onFocusChange;

  const TvFocusable({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = 12,
    this.borderWidth = 2,
    this.focusScale = 1.05,
    this.duration = const Duration(milliseconds: 150),
    this.autofocus = false,
    this.onFocusChange,
  });

  @override
  State<TvFocusable> createState() => _TvFocusableState();
}

class _TvFocusableState extends State<TvFocusable> {
  late final FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'TvFocusable');
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
      setState(() {
        _isFocused = focused;
      });
      widget.onFocusChange?.call(focused);
    }
  }

  // 处理 D-pad 确认键（Enter/Select）
  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    // Enter / Select / D-pad Center 确认键
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.gameButtonA) {
      widget.onTap?.call();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onKeyEvent: _onKeyEvent,
      child: GestureDetector(
        onTap: () {
          // 触屏点击：请求焦点并触发回调
          _focusNode.requestFocus();
          widget.onTap?.call();
        },
        child: AnimatedScale(
          scale: _isFocused ? widget.focusScale : 1.0,
          duration: widget.duration,
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: widget.duration,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: _isFocused
                  ? Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: widget.borderWidth,
                    )
                  : Border.all(color: Colors.transparent, width: widget.borderWidth),
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
