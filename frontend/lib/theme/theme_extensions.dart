// 自定义主题扩展（Design Tokens：间距 / 圆角）
//
// 目前暂不引入自定义主题扩展（Flutter 的 ThemeExtension<T> 机制）
// 原因：
//   1. 阶段 1 目标是搭建主题框架而非替换组件代码
//   2. 现有的 colors.dart 常量保留作为兼容层，不需要额外暴露 token
//   3. Flutter 的 ColorScheme / TextTheme 已提供足够的语义化 token
//
// 阶段 2 开始后将在此处引入：
//   - AppSpacing（间距 token: xs, sm, md, lg, xl, xxl）
//   - AppRadius（圆角 token: sm, md, lg, xl, pill）
//   - AppAnimation（动画时长 token）
//
// 目前仅提供简单的 spacing / radius 常量，供 utils/constants.dart 同步引用。

// 间距（8px 基准）
class AppSpacing {
  AppSpacing._(); // 禁止实例化

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
}

// 圆角
class AppRadius {
  AppRadius._(); // 禁止实例化

  static const double sm = 4.0;
  static const double md = 8.0;
  static const double lg = 12.0;
  static const double xl = 16.0;
  static const double pill = 9999.0;
}
