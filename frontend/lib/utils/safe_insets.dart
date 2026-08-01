import 'dart:math' show max;

import 'package:flutter/widgets.dart';

/// 物理安全区取值工具。
///
/// 在任意 [SystemUiMode] 下都能返回设备物理刘海 / 挖孔 / 系统栏的避让值，
/// 解决沉浸式模式下 [MediaQueryData.padding] 被系统置 0 但物理刘海仍存在的缺口。
///
/// 取值策略（逐边取最大值）：
/// - [MediaQueryData.padding]：系统栏可见时的避让值，沉浸式（immersiveSticky /
///   leanBack）下被系统置 0；
/// - [MediaQueryData.viewPadding]：始终反映物理 inset（刘海 / 挖孔 / 系统栏），
///   不受沉浸式影响。
///
/// 取两者最大值即可在两种模式下都拿到正确的物理避让值，无需感知当前模式，
/// 也避免维护全局沉浸式状态。
class SafeInsets {
  const SafeInsets._();

  /// 返回当前方向下应避让的物理安全区 [EdgeInsets]。
  static EdgeInsets of(BuildContext context) {
    final mq = MediaQuery.of(context);
    return EdgeInsets.only(
      left: max(mq.padding.left, mq.viewPadding.left),
      top: max(mq.padding.top, mq.viewPadding.top),
      right: max(mq.padding.right, mq.viewPadding.right),
      bottom: max(mq.padding.bottom, mq.viewPadding.bottom),
    );
  }

  /// 顶部物理安全区高度（刘海 / 状态栏）。
  static double topOf(BuildContext context) => of(context).top;

  /// 底部物理安全区高度（手势条 / 导航栏）。
  static double bottomOf(BuildContext context) => of(context).bottom;

  /// 左侧物理安全区宽度（横屏时的侧边刘海 / 挖孔）。
  static double leftOf(BuildContext context) => of(context).left;

  /// 右侧物理安全区宽度（横屏时的侧边刘海 / 挖孔）。
  static double rightOf(BuildContext context) => of(context).right;
}
