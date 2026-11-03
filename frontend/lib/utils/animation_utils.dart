// 全局动画时长工具：系统开启「减少动态效果」(reduce-motion) 时动画即时完成
// U27：自定义动画时长统一经此函数换算，避免 reduce-motion 下仍播放长动画；
// 框架级动画(对话框/路由过渡等)由 ThemeData.animationDuration 在 app_theme.dart 降级。

import 'package:flutter/widgets.dart';

/// 根据系统 reduce-motion 设置返回动画时长：
/// 开启时返回 [Duration.zero]（动画即时完成），否则返回 [milliseconds] 对应的时长。
///
/// 用法：`duration: uiAnimMs(context, kToolbarAnimMs)`
Duration uiAnimMs(BuildContext context, int milliseconds) {
  if (MediaQuery.disableAnimationsOf(context)) {
    return Duration.zero;
  }
  return Duration(milliseconds: milliseconds);
}
