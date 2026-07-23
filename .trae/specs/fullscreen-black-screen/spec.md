# 全屏视频播放黑屏问题分析 - Product Requirement Document

## Overview
- **Summary**: 分析并修复点击全屏观看按钮后不显示视频画面（黑屏）的问题
- **Purpose**: 确保用户点击全屏观看按钮后能正常看到视频画面，提供流畅的全屏观看体验
- **Target Users**: 所有使用全屏观看功能的用户

## Goals
- Goal 1: 修复 isControllerUsableForFullscreen 未检查视频尺寸导致的黑屏
- Goal 2: 修复全屏页 isControllerReady 判断过于严格导致的加载指示器显示异常
- Goal 3: 修复 VideoPlayer 渲染时机问题，确保进入全屏时视频画面正确显示

## Non-Goals (Out of Scope)
- 不修改视频播放器的核心解码逻辑
- 不修改全屏页的 UI 布局和交互逻辑
- 不修改视频预加载策略

## Background & Context
- 用户反馈点击全屏观看按钮后，视频画面不显示，只看到黑屏或加载指示器
- 全屏页复用全局 VideoPlayerController，不重新初始化
- 已有防御性检查 `isControllerUsableForFullscreen`，但存在漏洞

## 根本原因分析

### 原因 1：isControllerUsableForFullscreen 未检查视频尺寸
**位置**: [fullscreen_navigator.dart:26-37](file:///workspace/frontend/lib/utils/fullscreen_navigator.dart#L26-L37)
```dart
static bool isControllerUsableForFullscreen(VideoPlayerController? controller) {
  if (controller == null) return false;
  try {
    final v = controller.value;
    if (v.hasError) return false;
    if (!v.isInitialized) return false;
    return true;  // 缺少 !v.size.isEmpty 检查
  } catch (_) {
    return false;
  }
}
```
**影响**: 视频已初始化但尺寸尚未获取时，允许进入全屏，但全屏页的 `isControllerReady` 检查包含尺寸判断，导致显示加载指示器而非视频画面。

### 原因 2：全屏页 isControllerReady 判断与加载状态不一致
**位置**: [fullscreen_video_page.dart:721-731](file:///workspace/frontend/lib/views/fullscreen_video_page.dart#L721-L731)
```dart
bool isControllerReady;
if (controller != null) {
  final v = controller.value;
  isControllerReady = v.isInitialized && !v.hasError && !v.size.isEmpty;
  ...
}
```
**影响**: 当视频尺寸为空时（常见于网络视频初始化阶段），`isControllerReady` 为 false，显示加载指示器。但 VideoPlayer 实际上已经可以渲染画面，只是尺寸信息还未到达。

### 原因 3：VideoPlayer 渲染表面构建时机问题
**位置**: [fullscreen_video_page.dart:770-774](file:///workspace/frontend/lib/views/fullscreen_video_page.dart#L770-L774)
```dart
if (isControllerReady && controller != null)
  Offstage(
    offstage: hasError || !videoVisible,
    child: _buildVideoSurface(controller),
  ),
```
**影响**: 只有 `isControllerReady` 为 true 才构建 VideoPlayer 组件。如果尺寸始终为空，VideoPlayer 永远不会被构建，导致黑屏。

## Functional Requirements
- **FR-1**: isControllerUsableForFullscreen 必须检查视频尺寸（!size.isEmpty）
- **FR-2**: 全屏页应在尺寸为空时也显示 VideoPlayer（使用占位尺寸），避免黑屏
- **FR-3**: 全屏页的加载指示器只在真正需要时显示（controller 未初始化或有错误）

## Non-Functional Requirements
- **NFR-1**: 全屏页进入动画 < 200ms
- **NFR-2**: 视频画面显示延迟 < 500ms
- **NFR-3**: 不引入新的性能问题

## Constraints
- **Technical**: Flutter + Riverpod，video_player 包
- **Business**: 向后兼容，不破坏现有功能
- **Dependencies**: currentVideoControllerProvider, isFullscreenProvider

## Acceptance Criteria

### AC-1: isControllerUsableForFullscreen 正确检查视频尺寸
- **Given**: VideoPlayerController 已初始化但尺寸为空
- **When**: 调用 isControllerUsableForFullscreen
- **Then**: 返回 false，不允许进入全屏
- **Verification**: `programmatic`

### AC-2: 全屏页在尺寸为空时仍显示 VideoPlayer
- **Given**: VideoPlayerController 已初始化、无错误，但尺寸为空
- **When**: 进入全屏页
- **Then**: VideoPlayer 组件被构建（使用占位尺寸），不显示黑屏
- **Verification**: `programmatic`

### AC-3: 全屏页加载指示器只在真正需要时显示
- **Given**: VideoPlayerController 已初始化且无错误
- **When**: 进入全屏页
- **Then**: 不显示加载指示器，直接显示视频或 VideoPlayer 组件
- **Verification**: `human-judgment`

### AC-4: 尺寸更新后视频画面正常显示
- **Given**: 全屏页已进入，视频尺寸从空变为有效
- **When**: 尺寸更新回调触发
- **Then**: VideoPlayer 自动切换到正确尺寸，画面正常显示
- **Verification**: `programmatic`

## Open Questions
- [ ] 是否需要在尺寸为空时显示占位画面（如封面图）？
