import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../views/fullscreen_video_page.dart';
import '../services/playback/i_playback_controller.dart';

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
  /// - 视频尺寸为空（size.isEmpty=true）
  ///
  /// 防御场景：onControllerReleased 回调未同步清除
  /// currentVideoControllerProvider 时，provider 可能持有已 disposed 的 controller，
  /// 直接进入全屏会导致黑屏。
  ///
  /// 尺寸检查：视频已初始化但尺寸尚未获取时，进入全屏会显示加载指示器而非视频画面，
  /// 因此必须等待尺寸有效后才允许进入全屏。
  static bool isControllerUsableForFullscreen(IPlaybackController? controller) {
    if (controller == null) return false;
    try {
      if (controller.hasError) return false;
      if (!controller.isInitialized) return false;
      if (controller.duration == Duration.zero) return false;
      return true;
    } catch (_) {
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
    // 设置 isFullscreenProvider，使 VideoPageItem 隐藏 UI 控件（但 VideoPlayer 保持渲染）
    // 全屏页为透明覆盖层，画面由底层 VideoPageItem 的 VideoPlayer 提供
    ref.read(isFullscreenProvider.notifier).state = true;

    // 使用 showGeneralDialog 创建透明覆盖层路由
    // RawDialogRoute 默认 opaque: false，专为透明覆盖场景设计，
    // 能正确处理 hit testing 和控件渲染
    await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'fullscreen',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (_, animation, __, child) {
        // 从底部滑入过渡，与 fullscreenDialog 行为一致
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        );
      },
      pageBuilder: (_, __, ___) => FullscreenVideoPage(onExit: onExit),
    );

    onExit?.call();
    return true;
  }
}
