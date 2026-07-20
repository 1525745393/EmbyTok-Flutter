import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../views/fullscreen_video_page.dart';

/// 统一的全屏导航工具
///
/// 集中管理进入全屏的前置操作（设置 isFullscreenProvider、隐藏工具栏）
/// 和退出全屏后的恢复操作，避免多个地方重复实现相同逻辑。
class FullscreenNavigator {
  FullscreenNavigator._();

  /// 进入全屏播放页
  ///
  /// [ref] - 用于读取/修改 Provider 状态
  /// [context] - 用于导航
  /// [onExit] - 退出全屏后的回调（可选），用于恢复 UI 状态
  ///
  /// 返回值：是否成功进入全屏
  static Future<bool> open({
    required WidgetRef ref,
    required BuildContext context,
    VoidCallback? onExit,
  }) async {
    final controller = ref.read(currentVideoControllerProvider);
    if (controller == null) return false;

    // 进入前隐藏工具栏（沉浸感）
    ref.read(toolbarVisibilityProvider.notifier).hide();
    // 同步设置 isFullscreenProvider，使 VideoPageItem 中的 VideoPlayer 立即 Offstage，
    // 避免与 FullscreenVideoPage 中的 VideoPlayer 短暂同时渲染同一 controller
    ref.read(isFullscreenProvider.notifier).state = true;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const FullscreenVideoPage(),
        fullscreenDialog: true,
      ),
    );

    onExit?.call();
    return true;
  }
}
