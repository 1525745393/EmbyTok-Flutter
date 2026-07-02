// 无缝全屏切换状态管理
//
// 核心原理：
// 1. 不使用新路由（Navigator.push），在同一页面的 Stack 中叠加全屏层
// 2. 小窗进入全屏前先标记"即将切换"，让小窗的 VideoPlayerWidget 在 build 时
//    返回占位（不渲染 VideoPlayer），避免两个 VideoPlayer 同时持有 Texture 导致黑屏
// 3. 全屏层由 SeamlessFullscreenHost 组件渲染，通过 AnimationController +
//    RelativeRectTween 实现从"小窗位置"到"全屏"的平滑缩放动画
// 4. 全程复用同一个 VideoPlayerController，不 dispose、不重新初始化
// 5. 退出全屏反向动画，动画结束后小窗恢复 VideoPlayer 渲染
//
// 使用方式：
// final notifier = ref.read(seamlessFullscreenProvider.notifier);
// notifier.enter(sourceRect: rect, sourceItemId: itemId);
// notifier.exit();

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 无缝全屏切换状态
class SeamlessFullscreenState {
  final bool isFullscreen;
  final Rect sourceRect;
  final String? sourceItemId;

  const SeamlessFullscreenState({
    this.isFullscreen = false,
    this.sourceRect = Rect.zero,
    this.sourceItemId,
  });

  SeamlessFullscreenState copyWith({
    bool? isFullscreen,
    Rect? sourceRect,
    String? sourceItemId,
    bool clearItemId = false,
  }) {
    return SeamlessFullscreenState(
      isFullscreen: isFullscreen ?? this.isFullscreen,
      sourceRect: sourceRect ?? this.sourceRect,
      sourceItemId: clearItemId ? null : (sourceItemId ?? this.sourceItemId),
    );
  }
}

class SeamlessFullscreenNotifier extends StateNotifier<SeamlessFullscreenState> {
  SeamlessFullscreenNotifier() : super(const SeamlessFullscreenState());

  /// 请求进入无缝全屏
  /// [sourceRect] 小窗播放器在屏幕中的位置和大小（通过 GlobalKey + RenderBox 计算）
  /// [sourceItemId] 当前小窗播放的媒体 ID
  void enter({required Rect sourceRect, required String sourceItemId}) {
    if (state.isFullscreen) return;
    state = state.copyWith(
      isFullscreen: true,
      sourceRect: sourceRect,
      sourceItemId: sourceItemId,
    );
  }

  /// 请求退出无缝全屏（由 Host 监听触发退出动画）
  void exit() {
    if (!state.isFullscreen) return;
    // 通知 Host 开始退出动画；动画完成后由 Host 调用 markExited()
    state = state.copyWith(isFullscreen: false);
  }

  /// 退出动画完成后调用，清理状态
  void markExited() {
    state = const SeamlessFullscreenState();
  }
}

/// 全局无缝全屏状态 provider
final seamlessFullscreenProvider =
    StateNotifierProvider<SeamlessFullscreenNotifier, SeamlessFullscreenState>(
  (ref) => SeamlessFullscreenNotifier(),
);

/// 判断当前指定 itemId 的播放器是否应该隐藏 VideoPlayer（无缝全屏中时小窗侧使用）
final shouldHideVideoForItemProvider = Provider.family<bool, String>((ref, itemId) {
  final fsState = ref.watch(seamlessFullscreenProvider);
  return fsState.sourceItemId == itemId;
});
