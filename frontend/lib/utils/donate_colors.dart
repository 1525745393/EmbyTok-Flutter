// 打赏对话框专用品牌色
//
// 这些颜色是特定品牌的官方主色调，与主题无关。
// 单独定义在此文件中，并加入 hardcoded_color_lint 白名单，
// 避免污染 settings_view.dart 等业务文件。

import 'package:flutter/material.dart';

/// 打赏相关品牌色集合
class DonateColors {
  DonateColors._();

  /// 微信品牌绿（微信收款码图标）
  static const Color wechat = Color(0xFF07C160);

  /// 支付宝品牌蓝（支付宝收款码图标）
  static const Color alipay = Color(0xFF1677FF);

  /// 打赏主色（红色，用于打赏图标 - volunteer_activism）
  /// 使用独立常量而非 scheme.error，因为这是支持性图标而非错误状态
  static const Color donateAccent = Color(0xFFF44336);
}
