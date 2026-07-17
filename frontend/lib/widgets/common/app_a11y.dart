// 可访问性辅助工具
//
// 提供可复用的 Semantics 包装器与触摸目标尺寸保障函数，
// 减少散落在各 widget 中的重复 a11y 代码。

import 'package:flutter/material.dart';

/// MD3 推荐的最小触摸目标尺寸
const double kMinTouchTarget = 48.0;

/// iOS HIG 推荐的最小触摸目标尺寸
const double kMinTouchTargetIOS = 44.0;

/// 为任意可点击 widget 包裹语义标签（供屏幕阅读器朗读）
///
/// ```dart
/// accessibleTap(
///   label: '收藏',
///   button: true,
///   onTap: () => ...,
///   child: Icon(Icons.favorite),
/// )
/// ```
Widget accessibleTap({
  required String label,
  required Widget child,
  VoidCallback? onTap,
  bool button = true,
  bool enabled = true,
  bool selected = false,
}) {
  return Semantics(
    label: label,
    button: button,
    enabled: enabled,
    selected: selected,
    container: true,
    child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: child,
    ),
  );
}

/// 将任意 widget 包裹到至少 [minSize]×[minSize] 的触摸目标区域
///
/// 不改变视觉外观（在透明区域内放大点击区域），用于 IconButton 等
/// 视觉小但需要满足触摸目标的场景。
Widget ensureTouchTarget({
  required Widget child,
  double minSize = kMinTouchTarget,
}) {
  return ConstrainedBox(
    constraints: BoxConstraints(
      minWidth: minSize,
      minHeight: minSize,
    ),
    child: child,
  );
}
