# 全屏黑屏 Bug 修复 - 产品需求文档

## Overview
- **Summary**: 修复从竖屏视频流进入全屏播放时出现的短暂纯黑屏问题
- **Purpose**: 消除用户进入全屏时的视觉闪烁和黑屏体验，提供平滑的过渡和加载反馈
- **Target Users**: 所有使用全屏播放功能的用户

## Goals
- 修复全屏进入时 `controller.value.isInitialized == true` 但 `controller.value.size == Size.zero` 导致的黑屏
- 在尺寸为空时显示加载指示器，保持用户反馈
- 使用占位尺寸确保 VideoPlayer 渲染管线持续运行，加速尺寸恢复

## Non-Goals (Out of Scope)
- 不修改视频播放核心逻辑或控制器生命周期
- 不调整全屏模式的其他 UI 元素（如字幕、控制条等）
- 不优化全屏退出时的过渡效果

## Background & Context
全屏黑屏问题的根因是 `fullscreen_video_page.dart` 中 `isControllerReady` 判断与 `_buildVideoSurface` 处理不一致：

1. **`isControllerReady` 判断**（第 722 行）：只检查 `v.isInitialized && !v.hasError`，**未检查尺寸**
2. **`_buildVideoSurface`**（第 600-602 行）：当 `videoSize.isEmpty` 时返回 `SizedBox.shrink()`

当从 `VideoPageItem` 进入 `FullscreenVideoPage` 时：
- `isFullscreenProvider = true` → `VideoPageItem` 中的 `VideoPlayer` 被 `Offstage` 隐藏
- `FullscreenVideoPage` 创建自己的 `VideoPlayer(controller)` widget
- 平台纹理重新挂载时出现短暂窗口：`isInitialized == true` 但 `size == Size.zero`
- 此时 `isControllerReady == true` → spinner 不显示
- `_buildVideoSurface` 返回 `SizedBox.shrink()` → 用户看到纯黑屏

对比 `VideoPlayerWidget`（第 511-541 行）的正确处理：
- 使用 1x1 占位尺寸保证渲染管线不断
- 尺寸为空时持续显示加载指示器

## Functional Requirements
- **FR-1**: `isControllerReady` 判断必须包含 `!videoSize.isEmpty` 条件
- **FR-2**: `_buildVideoSurface` 在 `videoSize.isEmpty` 时使用 1x1 占位尺寸而非返回空组件
- **FR-3**: 尺寸为空时显示加载指示器

## Non-Functional Requirements
- **NFR-1**: 修复不应引入性能退化（如额外的 rebuild）
- **NFR-2**: 修复应保持与现有代码风格一致
- **NFR-3**: 修复应与 `VideoPlayerWidget` 的处理逻辑保持一致

## Constraints
- **Technical**: Flutter 框架、VideoPlayerController API
- **Dependencies**: `video_player_widget.dart` 的处理方式作为参考

## Assumptions
- `VideoPlayerController` 在初始化后尺寸会逐步恢复正常
- 1x1 占位尺寸不会影响最终视频显示效果

## Acceptance Criteria

### AC-1: isControllerReady 包含尺寸检查
- **Given**: `controller.value.isInitialized == true` 且 `controller.value.size == Size.zero`
- **When**: 构建 `FullscreenVideoPage`
- **Then**: `isControllerReady == false`，显示加载指示器而非黑屏
- **Verification**: `programmatic`

### AC-2: _buildVideoSurface 使用占位尺寸
- **Given**: `controller.value.size == Size.zero`
- **When**: 调用 `_buildVideoSurface`
- **Then**: 返回包含 1x1 `SizedBox` 的 `VideoPlayer` 组件，而非 `SizedBox.shrink()`
- **Verification**: `programmatic`

### AC-3: 尺寸恢复后正常显示
- **Given**: `controller.value.size` 恢复为有效尺寸
- **When**: 尺寸变化触发 rebuild
- **Then**: 使用实际尺寸渲染视频，隐藏加载指示器
- **Verification**: `human-judgment`

## Open Questions
- [ ] 无

## Quality Checklist
- [x] Every goal has at least one acceptance criterion
- [x] Every acceptance criterion has a verification type
- [x] Non-goals are explicitly stated
- [x] Constraints are realistic and complete
- [x] No requirement contradicts another
- [x] Ambiguous user language has been clarified or flagged
