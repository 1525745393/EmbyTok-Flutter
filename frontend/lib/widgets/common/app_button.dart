// 通用按钮组件
//
// 统一替换散落在 login_view / item_detail_view / settings_view 等处
// 自定义 padding 与圆角不一致的 ElevatedButton / FilledButton。
//
// 使用：
// ```dart
// AppButton.primary(onTap: () => ..., child: Text('登录'))
// AppButton.tonal(onTap: () => ..., child: Text('收藏'))
// ```

import 'package:flutter/material.dart';

import '../../theme/theme_extensions.dart';

/// 通用应用按钮
///
/// 三种变体：
/// - [AppButtonVariant.primary]：实心 primary，用于主要 CTA（登录、确认）
/// - [AppButtonVariant.tonal]：tonal（primaryContainer），用于次要操作（收藏、跳转）
/// - [AppButtonVariant.text]：文本按钮，用于低优先级操作（取消）
class AppButton extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;
  final AppButtonVariant variant;
  final bool enabled;
  final bool expanded; // 是否撑满父宽度

  const AppButton._({
    super.key,
    required this.onTap,
    required this.child,
    required this.variant,
    this.enabled = true,
    this.expanded = false,
  });

  /// 主要 CTA 按钮（实心 primary）
  const AppButton.primary({
    Key? key,
    required VoidCallback? onTap,
    required Widget child,
    bool enabled = true,
    bool expanded = false,
  }) : this._(
          key: key,
          onTap: onTap,
          child: child,
          variant: AppButtonVariant.primary,
          enabled: enabled,
          expanded: expanded,
        );

  /// 次要操作按钮（tonal primaryContainer）
  const AppButton.tonal({
    Key? key,
    required VoidCallback? onTap,
    required Widget child,
    bool enabled = true,
    bool expanded = false,
  }) : this._(
          key: key,
          onTap: onTap,
          child: child,
          variant: AppButtonVariant.tonal,
          enabled: enabled,
          expanded: expanded,
        );

  /// 文本按钮（低优先级）
  const AppButton.text({
    Key? key,
    required VoidCallback? onTap,
    required Widget child,
    bool enabled = true,
    bool expanded = false,
  }) : this._(
          key: key,
          onTap: onTap,
          child: child,
          variant: AppButtonVariant.text,
          enabled: enabled,
          expanded: expanded,
        );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AppTheme.of(context);
    // 统一圆角与 padding，替换散落魔法数字
    final radius = BorderRadius.circular(tokens.radius.lg); // 12
    const padding = EdgeInsets.symmetric(horizontal: 16, vertical: 12);

    Widget button;
    switch (variant) {
      case AppButtonVariant.primary:
        button = FilledButton(
          onPressed: enabled ? onTap : null,
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: radius),
            padding: padding,
            minimumSize: const Size(48, 48), // 触摸目标 ≥48dp
          ),
          child: child,
        );
        break;
      case AppButtonVariant.tonal:
        button = FilledButton.tonal(
          onPressed: enabled ? onTap : null,
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.primaryContainer,
            foregroundColor: theme.colorScheme.onPrimaryContainer,
            shape: RoundedRectangleBorder(borderRadius: radius),
            padding: padding,
            minimumSize: const Size(48, 48),
          ),
          child: child,
        );
        break;
      case AppButtonVariant.text:
        button = TextButton(
          onPressed: enabled ? onTap : null,
          style: TextButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: radius),
            padding: padding,
            minimumSize: const Size(48, 48),
          ),
          child: child,
        );
        break;
    }

    if (expanded) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}

enum AppButtonVariant { primary, tonal, text }
