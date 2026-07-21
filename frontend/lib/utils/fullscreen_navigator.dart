import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../providers/providers.dart';
import '../views/fullscreen_video_page.dart';

/// 统一的全屏导航工具
///
/// 集中管理进入全屏的前置操作（设置 isFullscreenProvider、隐藏工具栏）
/// 和退出全屏后的恢复操作，避免多个地方重复实现相同逻辑。
class FullscreenNavigator {
  FullscreenNavigator._();

  /// 检查 controller 是否可用于全屏播放
  ///
  /// 返回 false 的情况：
  /// - null
  /// - 已 disposed（访问 value 抛异常）
  /// - 有错误（hasError=true）
  /// - 未初始化（isInitialized=false）
  ///
  /// 防御场景：onControllerReleased 回调未同步清除
  /// currentVideoControllerProvider 时，provider 可能持有已 disposed 的 controller，
  /// 直接进入全屏会导致黑屏。
  static bool isControllerUsableForFullscreen(VideoPlayerController? controller) {
    if (controller == null) return false;
    try {
      final v = controller.value;
      if (v.hasError) return false;
      if (!v.isInitialized) return false;
      return true;
    } catch (_) {
      // controller 已 disposed，访问 value 会抛异常
      return false;
    }
  }

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
    // 防御性检查：不仅检查 null，还要检查 controller 是否已 disposed 或有错误
    if (!isControllerUsableForFullscreen(controller)) return false;

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
