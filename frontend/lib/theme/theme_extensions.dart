// 设计 Token 系统（Design Tokens）
//
// 通过 Flutter 的 ThemeExtension<T> 机制将 spacing / radius / typography / scrim
// 纳入 ThemeData，可在任意 build 上下文中通过 `AppTheme.of(context)` 取用。
//
// 同时保留 AppSpacing / AppRadius 顶层 const 类（向后兼容），便于渐进迁移。
//
// 设计参考：Material Design 3 + 8px 基准网格。

import 'package:flutter/material.dart';

// ============================================================================
// 顶层 const 类（向后兼容 / 简单引用）
// ============================================================================

/// 间距 token（8px 基准网格）
class AppSpacing {
  AppSpacing._(); // 禁止实例化

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
}

/// 圆角 token
class AppRadius {
  AppSpacing._(); // 禁止实例化

  static const double sm = 4.0;
  static const double md = 8.0;
  static const double lg = 12.0;
  static const double xl = 16.0;
  static const double pill = 9999.0;
}

/// 动画时长 token
class AppAnimation {
  AppAnimation._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
}

// ============================================================================
// ThemeExtension：完整 token 集合
// ============================================================================

/// 应用主题扩展：聚合 spacing / radius / typography / scrim 四类 token
///
/// 通过 `AppTheme.of(context)` 在任意 build 上下文取用：
/// ```dart
/// final t = AppTheme.of(context);
/// padding: EdgeInsets.all(t.spacing.md)
/// borderRadius: BorderRadius.circular(t.radius.lg)
/// style: TextStyle(fontSize: t.typography.bodyLarge, fontWeight: FontWeight.w500)
/// ```
@immutable
class AppTheme extends ThemeExtension<AppTheme> {
  final AppSpacingTokens spacing;
  final AppRadiusTokens radius;
  final AppTypographyTokens typography;
  final AppScrimTokens scrim;

  const AppTheme({
    this.spacing = const AppSpacingTokens(),
    this.radius = const AppRadiusTokens(),
    this.typography = const AppTypographyTokens(),
    this.scrim = const AppScrimTokens(),
  });

  /// 从 BuildContext 取当前 AppTheme（未配置时返回默认值）
  static AppTheme of(BuildContext context) {
    return Theme.of(context).extension<AppTheme>() ?? const AppTheme();
  }

  @override
  AppTheme copyWith({
    AppSpacingTokens? spacing,
    AppRadiusTokens? radius,
    AppTypographyTokens? typography,
    AppScrimTokens? scrim,
  }) {
    return AppTheme(
      spacing: spacing ?? this.spacing,
      radius: radius ?? this.radius,
      typography: typography ?? this.typography,
      scrim: scrim ?? this.scrim,
    );
  }

  @override
  AppTheme lerp(ThemeExtension<AppTheme>? other, double t) {
    if (other is! AppTheme) return this;
    // spacing/radius/typography 均为离散数值，按比例插值
    return AppTheme(
      spacing: AppSpacingTokens.lerp(spacing, other.spacing, t),
      radius: AppRadiusTokens.lerp(radius, other.radius, t),
      typography: AppTypographyTokens.lerp(typography, other.typography, t),
      scrim: AppScrimTokens.lerp(scrim, other.scrim, t),
    );
  }
}

// ----------------------------------------------------------------------------
// Spacing
// ----------------------------------------------------------------------------

@immutable
class AppSpacingTokens {
  final double xs; // 4
  final double sm; // 8
  final double md; // 12
  final double lg; // 16
  final double xl; // 24
  final double xxl; // 32

  const AppSpacingTokens({
    this.xs = AppSpacing.xs,
    this.sm = AppSpacing.sm,
    this.md = AppSpacing.md,
    this.lg = AppSpacing.lg,
    this.xl = AppSpacing.xl,
    this.xxl = AppSpacing.xxl,
  });

  static AppSpacingTokens lerp(AppSpacingTokens a, AppSpacingTokens b, double t) {
    return AppSpacingTokens(
      xs: _lerpDouble(a.xs, b.xs, t),
      sm: _lerpDouble(a.sm, b.sm, t),
      md: _lerpDouble(a.md, b.md, t),
      lg: _lerpDouble(a.lg, b.lg, t),
      xl: _lerpDouble(a.xl, b.xl, t),
      xxl: _lerpDouble(a.xxl, b.xxl, t),
    );
  }
}

// ----------------------------------------------------------------------------
// Radius
// ----------------------------------------------------------------------------

@immutable
class AppRadiusTokens {
  final double sm; // 4
  final double md; // 8
  final double lg; // 12
  final double xl; // 16
  final double pill; // 9999

  const AppRadiusTokens({
    this.sm = AppRadius.sm,
    this.md = AppRadius.md,
    this.lg = AppRadius.lg,
    this.xl = AppRadius.xl,
    this.pill = AppRadius.pill,
  });

  static AppRadiusTokens lerp(AppRadiusTokens a, AppRadiusTokens b, double t) {
    return AppRadiusTokens(
      sm: _lerpDouble(a.sm, b.sm, t),
      md: _lerpDouble(a.md, b.md, t),
      lg: _lerpDouble(a.lg, b.lg, t),
      xl: _lerpDouble(a.xl, b.xl, t),
      pill: b.pill, // pill 不插值
    );
  }
}

// ----------------------------------------------------------------------------
// Typography（字号 + 字重）
// ----------------------------------------------------------------------------

@immutable
class AppTypographyTokens {
  // Display（大标题，详情页主标题等）
  final double displayLarge; // 32
  final double displayMedium; // 28
  final double displaySmall; // 24

  // Headline（页面/区块标题）
  final double headlineLarge; // 22
  final double headlineMedium; // 20
  final double headlineSmall; // 18

  // Title（卡片标题、列表项标题）
  final double titleLarge; // 18
  final double titleMedium; // 16
  final double titleSmall; // 14

  // Body（正文）
  final double bodyLarge; // 16
  final double bodyMedium; // 14
  final double bodySmall; // 12

  // Label（按钮文字、徽章、字幕）
  final double labelLarge; // 14
  final double labelMedium; // 12
  final double labelSmall; // 10

  const AppTypographyTokens({
    this.displayLarge = 32.0,
    this.displayMedium = 28.0,
    this.displaySmall = 24.0,
    this.headlineLarge = 22.0,
    this.headlineMedium = 20.0,
    this.headlineSmall = 18.0,
    this.titleLarge = 18.0,
    this.titleMedium = 16.0,
    this.titleSmall = 14.0,
    this.bodyLarge = 16.0,
    this.bodyMedium = 14.0,
    this.bodySmall = 12.0,
    this.labelLarge = 14.0,
    this.labelMedium = 12.0,
    this.labelSmall = 10.0,
  });

  static AppTypographyTokens lerp(AppTypographyTokens a, AppTypographyTokens b, double t) {
    return AppTypographyTokens(
      displayLarge: _lerpDouble(a.displayLarge, b.displayLarge, t),
      displayMedium: _lerpDouble(a.displayMedium, b.displayMedium, t),
      displaySmall: _lerpDouble(a.displaySmall, b.displaySmall, t),
      headlineLarge: _lerpDouble(a.headlineLarge, b.headlineLarge, t),
      headlineMedium: _lerpDouble(a.headlineMedium, b.headlineMedium, t),
      headlineSmall: _lerpDouble(a.headlineSmall, b.headlineSmall, t),
      titleLarge: _lerpDouble(a.titleLarge, b.titleLarge, t),
      titleMedium: _lerpDouble(a.titleMedium, b.titleMedium, t),
      titleSmall: _lerpDouble(a.titleSmall, b.titleSmall, t),
      bodyLarge: _lerpDouble(a.bodyLarge, b.bodyLarge, t),
      bodyMedium: _lerpDouble(a.bodyMedium, b.bodyMedium, t),
      bodySmall: _lerpDouble(a.bodySmall, b.bodySmall, t),
      labelLarge: _lerpDouble(a.labelLarge, b.labelLarge, t),
      labelMedium: _lerpDouble(a.labelMedium, b.labelMedium, t),
      labelSmall: _lerpDouble(a.labelSmall, b.labelSmall, t),
    );
  }
}

// ----------------------------------------------------------------------------
// Scrim（半透明遮罩语义化 token）
//
// 用于统一收敛散落在 35+ 文件中的 `withOpacity(0.x)` 调用。
// 每个档位对应一个明确的语义用途，避免任意透明度值。
// ----------------------------------------------------------------------------

@immutable
class AppScrimTokens {
  /// surface 极弱透明（0.05）：分组卡片背景、悬浮输入框填充
  final Color surfaceWeak;
  /// surface 弱透明（0.15）：选中态背景、悬浮指示
  final Color surfaceMedium;
  /// surface 中等透明（0.3）：占位骨架、错误图标配色
  final Color surfaceStrong;
  /// surface 浓透明（0.6）：信息卡片、悬浮按钮背景
  final Color surfaceHeavy;
  /// surface 极浓透明（0.9）：控制层、底部弹窗背景
  final Color surfaceOpaque;

  /// onSurface 弱透明（0.3）：占位/不可用图标
  final Color onSurfaceWeak;
  /// onSurface 中弱透明（0.5）：次要文字、辅助图标
  final Color onSurfaceMedium;
  /// onSurface 中等透明（0.7）：正文文字、卡片标题
  final Color onSurfaceStrong;
  /// onSurface 强透明（0.85）：主要按钮文字、顶栏图标
  final Color onSurfaceHeavy;

  /// primary 弱透明（0.12）：滑块 overlay、选中态背景
  final Color primaryWeak;
  /// primary 中等透明（0.3）：选中边框
  final Color primaryMedium;

  const AppScrimTokens({
    this.surfaceWeak = const Color(0x0DFFFFFF),
    this.surfaceMedium = const Color(0x26FFFFFF),
    this.surfaceStrong = const Color(0x4DFFFFFF),
    this.surfaceHeavy = const Color(0x99FFFFFF),
    this.surfaceOpaque = const Color(0xE6FFFFFF),
    this.onSurfaceWeak = const Color(0x4DFFFFFF),
    this.onSurfaceMedium = const Color(0x80FFFFFF),
    this.onSurfaceStrong = const Color(0xB3FFFFFF),
    this.onSurfaceHeavy = const Color(0xD9FFFFFF),
    this.primaryWeak = const Color(0x1FE91E63),
    this.primaryMedium = const Color(0x4DE91E63),
  });

  /// 按当前 ColorScheme 动态生成 scrim 颜色
  ///
  /// 静态常量用白色基底（暗色主题默认场景），
  /// 调用此方法传入实际 ColorScheme 以获得适配亮/暗主题的颜色。
  factory AppScrimTokens.forScheme(ColorScheme scheme) {
    return AppScrimTokens(
      surfaceWeak: scheme.surface.withOpacity(0.05),
      surfaceMedium: scheme.surface.withOpacity(0.15),
      surfaceStrong: scheme.surface.withOpacity(0.3),
      surfaceHeavy: scheme.surface.withOpacity(0.6),
      surfaceOpaque: scheme.surface.withOpacity(0.9),
      onSurfaceWeak: scheme.onSurface.withOpacity(0.3),
      onSurfaceMedium: scheme.onSurface.withOpacity(0.5),
      onSurfaceStrong: scheme.onSurface.withOpacity(0.7),
      onSurfaceHeavy: scheme.onSurface.withOpacity(0.85),
      primaryWeak: scheme.primary.withOpacity(0.12),
      primaryMedium: scheme.primary.withOpacity(0.3),
    );
  }

  static AppScrimTokens lerp(AppScrimTokens a, AppScrimTokens b, double t) {
    // Color.lerp 对带 alpha 的颜色做线性插值
    return AppScrimTokens(
      surfaceWeak: Color.lerp(a.surfaceWeak, b.surfaceWeak, t)!,
      surfaceMedium: Color.lerp(a.surfaceMedium, b.surfaceMedium, t)!,
      surfaceStrong: Color.lerp(a.surfaceStrong, b.surfaceStrong, t)!,
      surfaceHeavy: Color.lerp(a.surfaceHeavy, b.surfaceHeavy, t)!,
      surfaceOpaque: Color.lerp(a.surfaceOpaque, b.surfaceOpaque, t)!,
      onSurfaceWeak: Color.lerp(a.onSurfaceWeak, b.onSurfaceWeak, t)!,
      onSurfaceMedium: Color.lerp(a.onSurfaceMedium, b.onSurfaceMedium, t)!,
      onSurfaceStrong: Color.lerp(a.onSurfaceStrong, b.onSurfaceStrong, t)!,
      onSurfaceHeavy: Color.lerp(a.onSurfaceHeavy, b.onSurfaceHeavy, t)!,
      primaryWeak: Color.lerp(a.primaryWeak, b.primaryWeak, t)!,
      primaryMedium: Color.lerp(a.primaryMedium, b.primaryMedium, t)!,
    );
  }
}

// ----------------------------------------------------------------------------
// 内部工具
// ----------------------------------------------------------------------------

double _lerpDouble(double a, double b, double t) {
  return a + (b - a) * t;
}
