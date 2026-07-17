// Material Design 3 主题系统
// 使用 ColorScheme.fromSeed() 从单一 seed color 生成完整的色彩体系
// 支持亮色 / 暗色 / 跟随系统三种模式
//
// 设计参考：
// - Seed Color: 0xFFE91E63（保持现有粉色，视觉体验无突变）
// - Material Design 3 规范自动满足 WCAG AA 对比度
//
// API 兼容性说明：仅使用 Flutter 3.10+ 稳定 API，避免使用 3.22 后的新 token

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme_extensions.dart';

/// 主题种子色：粉色（保持与旧 primaryPink 一致的视觉风格）
const Color _kSeedColor = Color(0xFFE91E63);

/// ---- 工具：构建暗色 ColorScheme ----
ColorScheme _buildDarkColorScheme() {
  return ColorScheme.fromSeed(
    seedColor: _kSeedColor,
    brightness: Brightness.dark,
  );
}

/// ---- 工具：构建亮色 ColorScheme ----
ColorScheme _buildLightColorScheme() {
  return ColorScheme.fromSeed(
    seedColor: _kSeedColor,
    brightness: Brightness.light,
  );
}

/// ---- 全面屏手势适配：状态栏 / 导航栏前景样式 ----
/// 暗色主题：背景透明，文字/图标使用浅色（light）
SystemUiOverlayStyle _darkSystemOverlayStyle() {
  return const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarDividerColor: Colors.transparent,
  );
}

/// 亮色主题：背景透明，文字/图标使用深色（dark）
SystemUiOverlayStyle _lightSystemOverlayStyle() {
  return const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarDividerColor: Colors.transparent,
  );
}

/// ---- 工具：根据 brightness 选择 overlay style ----
SystemUiOverlayStyle _overlayStyleFor(Brightness brightness) {
  return brightness == Brightness.dark
      ? _darkSystemOverlayStyle()
      : _lightSystemOverlayStyle();
}

/// ---- 统一 ThemeData 构建器（共享配置） ----
/// surfaceContainerHighest 在 Flutter 3.22 才引入，这里用 surface + 不透明度代替
/// [systemOverlayStyle] 全面屏适配：根据主题 brightness 选 dark / light foreground
ThemeData _buildBaseTheme(
  ColorScheme colorScheme, {
  required SystemUiOverlayStyle systemOverlayStyle,
}) {
  final surfaceElevated = colorScheme.brightness == Brightness.dark
      ? colorScheme.surface.withOpacity(1.0) // 暗色模式下保持纯深色
      : colorScheme.surface.withOpacity(0.95); // 亮色模式下轻微加深

  final surfaceHighest = colorScheme.brightness == Brightness.dark
      ? const Color(0xFF121212) // 暗色：近似 MD3 surfaceContainerHighest
      : const Color(0xFFE7E0EC); // 亮色：近似 MD3 surfaceContainerHighest

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    // 显式指定 scaffold 背景色（确保视频浏览页的背景与 colorScheme 对齐）
    scaffoldBackgroundColor: colorScheme.surface,
    // 全面屏适配：默认系统栏样式（被 AnnotatedRegion 覆盖前生效）
    // 配合 MainActivity 的 enableEdgeToEdge()，让 App 内容延伸到状态栏/导航栏
    extensions: <ThemeExtension<dynamic>>[
      // 使用 ThemeExtension 携带 overlay style，避免在 ThemeData 中无对应字段
      _SystemOverlayStyleTheme(systemOverlayStyle),
      // 设计 Token 系统：spacing / radius / typography / scrim
      // scrim 按当前 ColorScheme 动态生成，适配亮/暗主题
      AppTheme(scrim: AppScrimTokens.forScheme(colorScheme)),
    ],
    // AppBar 统一风格
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      centerTitle: false,
      // 全面屏适配：AppBar 上方状态栏使用同一前景色
      systemOverlayStyle: systemOverlayStyle,
    ),
    // 卡片统一风格
    cardTheme: CardTheme(
      color: surfaceHighest,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
    ),
    // 分隔线颜色
    dividerTheme: DividerThemeData(
      color: colorScheme.outlineVariant,
      thickness: 1.0,
      space: 1.0,
    ),
    // ListTile 统一风格
    listTileTheme: ListTileThemeData(
      iconColor: colorScheme.primary,
      textColor: colorScheme.onSurface,
      tileColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
    ),
    // 图标统一风格
    iconTheme: IconThemeData(
      color: colorScheme.onSurface,
      size: 24.0,
    ),
    // 按钮统一风格（保持与现有视觉一致）
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colorScheme.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colorScheme.primary,
        side: BorderSide(color: colorScheme.outline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
      ),
    ),
    // 输入框风格（登录页、搜索页等）
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceHighest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(color: colorScheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(color: colorScheme.primary, width: 2.0),
      ),
    ),
    // 对话框风格
    dialogTheme: DialogTheme(
      backgroundColor: surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
    ),
    // 底部弹窗风格（用于信息条、设置等）
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
    ),
    // 进度指示器（视频加载状态）
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colorScheme.primary,
      linearTrackColor: surfaceHighest,
    ),
    // 滑块（进度条、音量调节等）
    sliderTheme: SliderThemeData(
      activeTrackColor: colorScheme.primary,
      inactiveTrackColor: surfaceHighest,
      thumbColor: colorScheme.primary,
      overlayColor: colorScheme.primary.withOpacity(0.12),
    ),
    // 导航栏（底部 tab）
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colorScheme.surface,
      indicatorColor: colorScheme.primaryContainer,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(
          fontSize: 12.0,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    ),
    // SnackBar
    snackBarTheme: SnackBarThemeData(
      backgroundColor: colorScheme.inverseSurface,
      contentTextStyle: TextStyle(color: colorScheme.onInverseSurface),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
      behavior: SnackBarBehavior.floating,
    ),
    // 滚动条
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(
        colorScheme.onSurface.withOpacity(0.2),
      ),
      thickness: const WidgetStatePropertyAll(4.0),
      radius: const Radius.circular(2.0),
    ),
    // 弹出菜单
    popupMenuTheme: PopupMenuThemeData(
      color: surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
    ),
  );
}

/// ===== 暴露给 app.dart 的三个入口 =====

/// 亮色主题
ThemeData buildLightTheme() {
  final colorScheme = _buildLightColorScheme();
  return _buildBaseTheme(
    colorScheme,
    systemOverlayStyle: _lightSystemOverlayStyle(),
  );
}

/// 暗色主题
ThemeData buildDarkTheme() {
  final colorScheme = _buildDarkColorScheme();
  return _buildBaseTheme(
    colorScheme,
    systemOverlayStyle: _darkSystemOverlayStyle(),
  );
}

/// 根据字符串模式返回 ThemeMode 枚举（settings_view 使用）
/// mode: 'dark' | 'light' | 'system'
ThemeMode parseThemeMode(String mode) {
  switch (mode) {
    case 'dark':
      return ThemeMode.dark;
    case 'light':
      return ThemeMode.light;
    default:
      return ThemeMode.system;
  }
}

// ---- 全面屏手势适配 ----

/// 用 ThemeExtension 包装 SystemUiOverlayStyle，让 buildLightTheme/buildDarkTheme
/// 能把"系统栏前景色"作为 ThemeData 的一部分传出。
/// AnnotatedRegion 只需要 ThemeData，就能拿到对应主题的 overlay style。
class _SystemOverlayStyleTheme extends ThemeExtension<_SystemOverlayStyleTheme> {
  final SystemUiOverlayStyle style;
  const _SystemOverlayStyleTheme(this.style);

  @override
  _SystemOverlayStyleTheme copyWith({SystemUiOverlayStyle? style}) {
    return _SystemOverlayStyleTheme(style ?? this.style);
  }

  @override
  _SystemOverlayStyleTheme lerp(
    ThemeExtension<_SystemOverlayStyleTheme>? other,
    double t,
  ) {
    // SystemUiOverlayStyle 不支持插值，直接在 t < 0.5 时取 this
    return this;
  }
}

/// 公共读取入口：从 BuildContext 的 ThemeData 中拿到当前主题对应的 overlay style
SystemUiOverlayStyle systemOverlayStyleOf(BuildContext context) {
  final ext = Theme.of(context).extension<_SystemOverlayStyleTheme>();
  return ext?.style ?? _lightSystemOverlayStyle();
}
