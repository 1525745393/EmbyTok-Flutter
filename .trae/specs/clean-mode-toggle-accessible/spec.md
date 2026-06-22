# 纯净模式下保留连播开关与倍速控制 - Product Requirement Document

## Overview
- **Summary**: 修复纯净模式下连播开关和倍速按钮被隐藏，导致用户无法关闭连播模式或调整倍速的问题。
- **Purpose**: 用户开启连播模式后，整个右侧操作栏被隐藏，导致用户无法关闭连播或调节倍速。需要在纯净模式下保留关键控制按钮的可见性。
- **Target Users**: EmbyTok 竖屏视频播放用户，尤其是使用连播/纯净模式的用户。

## Goals
- 纯净模式开启后，用户仍能看到并操作连播开关按钮
- 纯净模式开启后，用户仍能看到并操作倍速调节按钮
- 保持纯净模式的沉浸式体验（不恢复被隐藏的底部信息区和其他操作按钮）
- 操作交互与原模式保持一致

## Non-Goals (Out of Scope)
- 不改变连播开关的功能逻辑（仅改变可见性）
- 不改变倍速调节的功能逻辑（仅改变可见性）
- 不恢复底部信息区、全屏按钮、点赞按钮、删除按钮等其他 UI 元素
- 不新增新的交互模式（如手势滑动切换）

## Background & Context
- 当前实现：`video_page_item.dart` 第 540 行 `if (!_isFullscreen && !isAutoPlay) _buildRightActions(favorited)` 将整个右侧操作栏在纯净模式下隐藏
- 连播开关 `_buildAutoPlayButton()` 和倍速按钮 `_buildSpeedControlButton()` 位于 `_buildRightActions()` 内部（第 875-878 行）
- 纯净模式下 VideoControls 控制层已通过点击显示（第 516-533 行），但它不包含连播开关和倍速控制
- 用户反馈：开启连播后无法关闭，需要退出页面返回才能恢复

## Functional Requirements
- **FR-1**: 纯净模式（isAutoPlay=true）下，始终显示连播开关按钮（Infinity 图标）
- **FR-2**: 纯净模式下，始终显示倍速调节按钮（显示当前倍速值）
- **FR-3**: 纯净模式下，其他右侧操作按钮（全屏、静音、点赞、删除、评论、分享、上下集）仍然隐藏
- **FR-4**: 纯净模式下，底部信息区（标题、简介、类型标签）仍然隐藏
- **FR-5**: 连播开关和倍速按钮在纯净模式下的功能与非纯净模式完全一致（点击切换/弹出面板）

## Non-Functional Requirements
- **NFR-1**: 纯净模式下的按钮视觉风格与原按钮一致（圆形、半透明背景、白色图标/文字）
- **NFR-2**: 按钮布局与原位置相同（右侧垂直排列，顶部靠近其他速度徽章）
- **NFR-3**: 不引入动画性能下降

## Constraints
- **Technical**: Flutter/Dart，基于现有 Provider 状态管理
- **Dependencies**: `isAutoPlayProvider`，`playbackRateProvider`，`VideoPlayerController`

## Assumptions
- 用户在纯净模式下仍需控制连播和倍速，这是核心操作
- 仅保留连播开关和倍速按钮足以维持沉浸式体验
- 其他操作（点赞、分享、全屏等）不属于纯净模式下的频繁操作

## Acceptance Criteria

### AC-1: 纯净模式下连播开关始终可见
- **Given**: 用户已开启连播模式（isAutoPlay=true）且不在全屏状态
- **When**: 观看视频时
- **Then**: 屏幕右侧应始终可见连播开关按钮（Infinity 图标）
- **Then**: 按钮为绿色高亮显示（表示连播开启）
- **Then**: 点击按钮可以关闭连播模式，显示 Toast 提示
- **Verification**: `human-judgment`

### AC-2: 纯净模式下倍速按钮始终可见
- **Given**: 用户已开启连播模式（isAutoPlay=true）且不在全屏状态
- **When**: 观看视频时
- **Then**: 屏幕右侧应始终可见倍速调节按钮（显示当前倍速值）
- **Then**: 点击按钮可弹出倍速选择面板
- **Verification**: `human-judgment`

### AC-3: 其他按钮在纯净模式下仍保持隐藏
- **Given**: 用户已开启连播模式（isAutoPlay=true）
- **When**: 观看视频时
- **Then**: 底部信息区（标题、简介、类型标签）不应可见
- **Then**: 右侧全屏、静音、点赞、删除、评论、分享、上下集按钮不应可见
- **Verification**: `human-judgment`

### AC-4: 关闭连播后恢复完整 UI
- **Given**: 用户在纯净模式下点击连播开关按钮
- **When**: 连播模式切换为关闭状态
- **Then**: 完整的右侧操作栏和底部信息区应恢复显示
- **Verification**: `human-judgment`

### AC-5: 非纯净模式行为不变
- **Given**: 连播模式关闭（isAutoPlay=false）
- **When**: 观看视频时
- **Then**: 所有按钮和 UI 元素按原有方式显示
- **Verification**: `human-judgment`

## Open Questions
- [ ] 是否需要在纯净模式下也保留全屏按钮？（当前设计：不保留，因为全屏是独立操作）
- [ ] 是否需要在纯净模式下保留上一集/下一集按钮？（当前设计：不保留，因为视频会自动播放下一个）
