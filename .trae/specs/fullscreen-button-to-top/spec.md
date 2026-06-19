# 全屏按钮移动到顶部操作区 - Product Requirement Document

## Overview
- **Summary**: 将视频播放页面右侧操作区的"全屏"按钮移动到新创建的顶部操作区（右上角悬浮），统一横屏/竖屏的全屏切换入口，减少右侧操作区的视觉复杂度。
- **Purpose**: 当前右侧操作区按钮过多，共 11 个按钮垂直排列，视觉拥挤。全屏是一个常用但不需要频繁点击的功能，适合放置在顶部操作区。横屏全屏模式下已有独立的退出全屏按钮，统一后交互更一致。
- **Target Users**: 使用 EmbyTok Flutter 版观看视频的所有用户，包括连播模式、非连播模式、横屏全屏模式。

## Goals
- 创建统一的顶部操作区（`_buildTopActions()`），悬浮在视频容器右上角
- 全屏按钮从右侧操作区移到顶部操作区
- 横屏全屏模式下的退出全屏按钮统一到顶部操作区（不再使用单独的 `_buildExitFullscreenButton`）
- 减少右侧操作区的按钮数量，降低视觉复杂度
- 保持功能不变：点击全屏按钮仍可切换横屏/竖屏

## Non-Goals (Out of Scope)
- 不修改右侧操作区的其他按钮顺序和位置（除删除全屏按钮）
- 不修改连播模式下的浮层按钮（`_buildCleanModeRightActions`）
- 不修改信息弹窗、底部信息条、播放控制手势等其他组件
- 不添加新的按钮到顶部操作区（除全屏按钮外）
- 不修改视频播放器的播放逻辑

## Background & Context

### 当前实现分析
当前代码位于 [video_page_item.dart](file:///workspace/frontend/lib/widgets/video_page_item.dart)：

#### 右侧操作区（`_buildRightActions`）[L968-L1056](file:///workspace/frontend/lib/widgets/video_page_item.dart#L968-L1056)
包含 11 个按钮（从上到下）：
1. 连播（∞）- 由 `_buildAutoPlayButton()` 渲染
2. 演员头像/海报 - 由 `_buildPosterAvatar()` 渲染
3. ❤️ 点赞 - 由 `_buildActionButton(Icons.favorite)` 渲染
4. ℹ️ 信息 - 由 `_buildInfoButton()` 渲染
5. 🗑️ 删除 - 由 `_buildDeleteButton()` 渲染
6. 倍速 - 由 `_buildSpeedControlButton()` 渲染
7. 播放模式 - 由 `_buildPlayModeButton()` 渲染
8. 字幕 - 由 `_buildSubtitleButton()` 渲染
9. 💿 唱片/静音 - 由 `_buildDiscMuteButton()` 渲染
10. **全屏** - 由 `_buildActionButton(Icons.fullscreen/exit)` 渲染（**需要移动**）
11. 下一集（仅剧集类）- 由 `_buildActionButton(Icons.chevron_right)` 渲染

#### 横屏全屏模式下的退出全屏按钮（`_buildExitFullscreenButton`）[L736-L746](file:///workspace/frontend/lib/widgets/video_page_item.dart#L736-L746)
- 简单的 `IconButton`，位于屏幕右上角
- 仅在 `_isFullscreen == true` 时显示
- 显示的是 `fullscreen_exit` 图标

#### Build 方法中的渲染逻辑 [L629-L640](file:///workspace/frontend/lib/widgets/video_page_item.dart#L629-L640)
```dart
// 底部渐变 + 标题/简介/类型标签
if (!_isFullscreen && (_isInfoExpanded || !isAutoPlay)) _buildBottomGradient(),
// 右侧渐变 + 操作按钮（横屏全屏模式或纯净模式下隐藏）
if (!_isFullscreen && !isAutoPlay) _buildRightActions(favorited),
// 纯净模式下显示简化的右侧按钮区（仅连播开关 + 倍速按钮）
if (!_isFullscreen && isAutoPlay) _buildCleanModeRightActions(),
// 横屏全屏模式下显示退出按钮（右上角）
if (_isFullscreen) _buildExitFullscreenButton(),
```

#### 全屏切换方法（`_toggleFullscreen`）[L525-L556](file:///workspace/frontend/lib/widgets/video_page_item.dart#L525-L556)
通过改变 `PreferredOrientations` 和 `SystemUiMode` 实现横竖屏切换。

### 问题
- 右侧操作区有 11 个按钮，视觉拥挤
- 全屏按钮在竖屏和横屏下使用不同组件（`_buildActionButton` vs `_buildExitFullscreenButton`），代码重复
- 全屏按钮是高频功能，但在右侧操作区的底部位置，远离用户自然点击区域

## Functional Requirements
- **FR-1**: 新建 `_buildTopActions()` 方法，返回一个 `Positioned` Widget，悬浮在视频容器的右上角。
- **FR-2**: 顶部操作区包含一个全屏切换按钮，图标随状态变化：竖屏时 `Icons.fullscreen`，横屏时 `Icons.fullscreen_exit`。
- **FR-3**: 点击顶部操作区的全屏按钮触发 `_toggleFullscreen()` 方法切换横竖屏。
- **FR-4**: `_buildRightActions()` 中删除原来的全屏按钮（第 10 项），其他按钮保留不变。
- **FR-5**: 删除 `_buildExitFullscreenButton()` 方法，横屏全屏模式下使用统一的 `_buildTopActions()`。
- **FR-6**: 在 build 方法中，`_buildTopActions()` 在竖屏和横屏模式下都应渲染（右侧操作区的显示条件不变）。
- **FR-7**: 顶部操作区不遮挡视频内容主体，使用半透明背景 + 圆角卡片风格，与连播模式浮层按钮视觉一致。
- **FR-8**: 连播模式（纯净模式）下也显示顶部操作区的全屏按钮（连播模式下右侧操作区被隐藏，但顶部操作区独立显示）。

## Non-Functional Requirements
- **NFR-1**: 顶部操作区使用 `AnimatedOpacity` 或类似动画实现出现/消失过渡（200-300ms）。
- **NFR-2**: 顶部操作区使用响应式尺寸适配不同屏幕大小（`responsiveSize()`）。
- **NFR-3**: 顶部操作区的按钮具有点击反馈（与右侧操作区按钮一致）。
- **NFR-4**: 顶部操作区的视觉风格与连播模式浮层按钮一致（半透明黑色背景 + 圆角 + 悬浮效果）。

## Constraints
- **Technical**: Flutter 3.x + Dart 3.x。修改仅限于 `video_page_item.dart` 文件。不引入新的依赖。
- **Business**: 保持全屏功能的行为不变（点击即切换横竖屏）。
- **Dependencies**: 依赖现有的 `_isFullscreen` 状态和 `_toggleFullscreen()` 方法。依赖 `responsiveSize()` 方法进行响应式尺寸计算。

## Assumptions
- 顶部操作区的初始位置：视频容器右上角，距离顶部 `topPadding + 8px`，距离右侧 `16px`
- 顶部操作区仅包含一个按钮：全屏/退出全屏
- 连播模式下用户仍需要切换全屏功能
- 横屏全屏模式下用户需要退出全屏回到竖屏

## Acceptance Criteria

### AC-1: 顶部操作区存在并显示全屏按钮
- **Given**: 用户进入视频播放页面
- **When**: 视频正常播放（竖屏模式）
- **Then**: 视频容器右上角显示一个悬浮按钮，图标为 `fullscreen`，具有半透明背景和圆角
- **Verification**: `human-judgment`

### AC-2: 点击顶部按钮触发全屏切换
- **Given**: 用户在竖屏模式下观看视频
- **When**: 用户点击右上角的全屏按钮
- **Then**: 应用切换到横屏全屏模式，视频旋转为横屏播放
- **Verification**: `human-judgment`

### AC-3: 横屏模式下显示退出全屏按钮
- **Given**: 用户在横屏全屏模式下观看视频
- **When**: 观察屏幕右上角
- **Then**: 顶部操作区显示一个悬浮按钮，图标为 `fullscreen_exit`，点击后回到竖屏模式
- **Verification**: `human-judgment`

### AC-4: 右侧操作区不再显示全屏按钮
- **Given**: 用户在竖屏非连播模式下观看视频
- **When**: 观察右侧操作区的按钮列表
- **Then**: 右侧操作区不包含全屏按钮（原来的第 10 项被删除），其他按钮顺序不变
- **Verification**: `human-judgment`

### AC-5: 不再使用独立的 _buildExitFullscreenButton
- **Given**: 代码库变更后
- **When**: 检查 `_buildExitFullscreenButton` 方法的调用
- **Then**: `_buildExitFullscreenButton` 方法被删除，或不再被任何地方调用
- **Verification**: `programmatic`（通过 grep 检查）

### AC-6: 连播模式下显示顶部操作区
- **Given**: 用户开启连播模式（纯净模式）
- **When**: 观察屏幕右上角
- **Then**: 顶部操作区的全屏按钮正常显示，可点击切换全屏
- **Verification**: `human-judgment`

### AC-7: 视觉风格一致性
- **Given**: 连播模式下同时看到顶部操作区和右下角浮层按钮
- **When**: 比较两者视觉风格
- **Then**: 两者使用相同的半透明黑色背景（`Color(0x66000000)`）和圆角风格
- **Verification**: `human-judgment`

### AC-8: 响应式尺寸适配
- **Given**: 在不同尺寸的设备上（小屏手机 / 大屏手机 / 平板）
- **When**: 观察顶部操作区按钮大小
- **Then**: 按钮尺寸根据屏幕宽度自适应（使用 `responsiveSize()`），不显得过大或过小
- **Verification**: `human-judgment`

### AC-9: 动画与反馈
- **Given**: 开启/关闭连播模式或切换全屏时
- **When**: 顶部操作区出现/消失
- **Then**: 有 200-300ms 的渐入渐出动画，点击按钮时有按下缩放反馈
- **Verification**: `human-judgment`

### AC-10: 代码变更最小化
- **Given**: 当前代码库状态
- **When**: 查看变更后的 `video_page_item.dart`
- **Then**: 变更仅限于：(a) 新增 `_buildTopActions()` 方法；(b) 删除 `_buildRightActions()` 中的全屏按钮；(c) 删除或不再调用 `_buildExitFullscreenButton()`；(d) 修改 build 方法中的渲染逻辑。不修改其他功能
- **Verification**: `programmatic`（通过 diff 审查）

## Open Questions
- [ ] 顶部操作区是否需要添加其他按钮？（如：倍速、播放/暂停指示？）**暂不添加，仅放全屏按钮**
- [ ] 连播模式下的浮层按钮（右下角）是否需要继续保留？**保留，因为有连播开关和倍速**
- [ ] 顶部操作区的按钮图标颜色和大小是否需要与右侧操作区一致？**是的，使用相同的 textPrimary 颜色和 responsiveSize(40) 尺寸**
