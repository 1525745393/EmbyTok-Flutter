/// 演员类型标签颜色（业务语义，非 Material 语义）
///
/// Director=橙色（导演），Writer=绿色（编剧），Actor=蓝色（演员）
/// 单独定义在此处便于集中管理，并加入 hardcoded_color_lint 白名单

import 'package:flutter/material.dart';

abstract final class ActorTypeColors {
  const ActorTypeColors._();

  /// 导演：橙色
  static const director = Color(0xFFFF9800);

  /// 编剧：绿色
  static const writer = Color(0xFF4CAF50);

  /// 演员：蓝色
  static const actor = Color(0xFF2196F3);
}
