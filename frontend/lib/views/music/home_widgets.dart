// 音乐库首页专用组件
//
// 从 synology_music_view.dart 拆分出来，提升代码可维护性。
//
// 包含：
// - QuickEntry：快捷入口数据模型
// - QuickEntryButton：快捷入口按钮（圆形渐变背景 + 图标 + 文字）

import 'package:flutter/material.dart';

// ===== 首页组件常量 =====

/// 快捷入口按钮大小
const double kQuickEntryButtonSize = 48;

/// 快捷入口按钮圆角
const double kQuickEntryButtonRadius = 14;

/// 快捷入口图标大小
const double kQuickEntryIconSize = 24;

/// 快捷入口标签字体大小
const double kQuickEntryLabelFontSize = 11;

/// 快捷入口按钮阴影模糊半径
const double kQuickEntryShadowBlurRadius = 8;

/// 快捷入口按钮阴影偏移
const double kQuickEntryShadowOffset = 3;

/// 快捷入口间距
const double kQuickEntrySpacing = 6;

/// 快捷入口数据
class QuickEntry {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const QuickEntry({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

/// 快捷入口按钮（圆形渐变背景 + 图标 + 文字）
class QuickEntryButton extends StatelessWidget {
  final QuickEntry entry;

  const QuickEntryButton({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: entry.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: kQuickEntryButtonSize,
            height: kQuickEntryButtonSize,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  entry.color.withValues(alpha: 0.9),
                  entry.color,
                ],
              ),
              borderRadius: BorderRadius.circular(kQuickEntryButtonRadius),
              boxShadow: [
                BoxShadow(
                  color: entry.color.withValues(alpha: 0.3),
                  blurRadius: kQuickEntryShadowBlurRadius,
                  offset: const Offset(0, kQuickEntryShadowOffset),
                ),
              ],
            ),
            child: Icon(
              entry.icon,
              color: Colors.white,
              size: kQuickEntryIconSize,
            ),
          ),
          const SizedBox(height: kQuickEntrySpacing),
          Text(
            entry.label,
            style: TextStyle(
              fontSize: kQuickEntryLabelFontSize,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
