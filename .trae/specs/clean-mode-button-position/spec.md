# 连播模式按钮位置调整 - Product Requirement Document

## Overview
- **Summary**: 将连播模式（纯净模式）下的控制按钮从视频播放区域内部调整到屏幕右下角，以浮层按钮的形式展示，避免遮挡视频内容，提升沉浸式观看体验。
- **Purpose**: 当前连播模式下，控制按钮（连播开关 + 倍速调节）覆盖在视频画面内，遮挡了视频内容，影响观看体验。需要将其移动到屏幕右下角作为浮层按钮。
- **Target Users**: 使用 EmbyTok Flutter 版观看视频并启用连播模式的所有用户。

## Goals
- 连播模式启用后，控制按钮不再出现在视频播放区域内部
- 连播按钮显示为屏幕右下角的浮层按钮（Floating Action Button 风格）
- 按钮包含：连播开关 + 倍速调节（与当前一致，仅位置改变）
- 保持按钮的可拖动特性，支持用户自由调整位置
- 底部安全区域适配（避开底部导航栏和手势条）

## Non-Goals (Out of Scope)
- 不修改视频播放器核心播放逻辑
- 不修改非连播模式下的 UI 布局
- 不改变按钮的功能（仅改变位置和视觉样式）
- 不修改信息弹窗、进度条等其他组件
- 不修改横屏全屏模式的按钮布局

## Background & Context

### 当前实现分析
当前代码位于 [video_page_item.dart](file:///workspace/frontend/lib/widgets/video_page_item.dart)：

- **`_buildCleanModeRightActions()`** ([L1689-L1709](file:///workspace/frontend/lib/widgets/video_page_item.dart#L1689-L1709)): 纯净模式按钮区，使用 `Positioned.fill` 覆盖整个视频区域，内部放置 `_DraggableCleanActions` 组件。当前包含：连播开关 (`_buildAutoPlayButton`) 和倍速按钮 (`_buildSpeedControlButton`)。

- **`_DraggableCleanActions`** ([L2416-L2510](file:///workspace/frontend/lib/widgets/video_page_item.dart#L2416-L2510)): 可拖动的浮层按钮容器，初始位置为 `(width - buttonWidth, height/2 - 70)`，即右侧中间位置，初始高度约 140px。

- **显示条件**: 在 build 方法中通过 `if (!_isFullscreen && isAutoPlay) _buildCleanModeRightActions()` 控制（[L637](file:///workspace/frontend/lib/widgets/video_page_item.dart#L637)）。

- **隐藏条件**: 连播模式下已正确隐藏右侧操作按钮（[L634](file:///workspace/frontend/lib/widgets/video_page_item.dart#L634)）和底部信息条（[L631](file:///workspace/frontend/lib/widgets/video_page_item.dart#L631)）。

### 问题
当前 `_DraggableCleanActions` 的初始位置为右侧中间（`height/2 - 70`），即按钮显示在视频画面内部，遮挡了视频内容。用户希望按钮显示在视频区域之外的屏幕右下角。

## Functional Requirements
- **FR-1**: 连播模式下的控制按钮初始位置为屏幕右下角，距离底部边缘保留安全区（底部导航栏高度 + 手势条高度 + 16px 边距），距离右侧边缘保留 16px 边距。
- **FR-2**: 按钮保持可拖动特性，用户可通过长按拖动改变位置，松开后按钮停留在当前位置。
- **FR-3**: 按钮拖动范围限制在屏幕可视区域内（避免拖出屏幕外）。
- **FR-4**: 关闭连播模式后，连播按钮立即消失；重新开启后恢复到屏幕右下角位置。
- **FR-5**: 横屏全屏模式 (`_isFullscreen`) 下不显示连播浮层按钮（保持当前行为）。
- **FR-6**: 按钮容器使用紧凑布局，避免占用过多屏幕空间。

## Non-Functional Requirements
- **NFR-1**: 按钮位置变化应平滑（使用 `AnimatedContainer` / `AnimatedPositioned` 过渡），动画时长 200-300ms。
- **NFR-2**: 按钮应具有半透明背景 + 模糊效果，确保视频内容透过按钮区域时仍可辨识但不干扰。
- **NFR-3**: 按钮响应式尺寸适配不同屏幕大小（手机 / 平板 / 桌面）。
- **NFR-4**: 点击按钮时应有按下缩放反馈（当前 `_PressableActionButton` 已实现）。

## Constraints
- **Technical**: Flutter 3.x + Dart 3.x。修改仅限于 `video_page_item.dart` 文件。保持 `_DraggableCleanActions` 的可拖动机制不变，仅改变其初始位置和样式。
- **Business**: 保持按钮功能不变（连播开关切换、倍速调节）。不改变用户交互的核心体验。
- **Dependencies**: 依赖现有 Provider：`isAutoPlayProvider`、`playbackLevelProvider`。依赖现有常量 `kBottomNavHeight`（底部导航栏高度）。

## Assumptions
- 假设 `kBottomNavHeight` 常量在代码库中已定义（用于底部边距计算）。
- 假设底部安全区（手势条）通过 `MediaQuery.of(context).padding.bottom` 获取。
- 假设连播模式的开启/关闭通过 `isAutoPlayProvider` 状态管理，状态变化会触发 Widget 重建。
- 按钮的拖动位置不需要持久化保存（下次进入连播模式恢复默认位置）。

## Acceptance Criteria

### AC-1: 按钮初始位置在屏幕右下角
- **Given**: 用户打开连播模式（`isAutoPlay = true`）
- **When**: 视频正常播放，当前页面处于竖屏模式（非全屏）
- **Then**: 连播控制按钮显示在屏幕右下角，距离底部 = `kBottomNavHeight + MediaQuery.padding.bottom + 16px`，距离右侧 = `16px`
- **Verification**: `human-judgment`

### AC-2: 按钮不遮挡视频播放区域的核心内容
- **Given**: 连播模式已开启
- **When**: 视频正常播放
- **Then**: 按钮以紧凑的浮层样式呈现，不覆盖视频的主要视觉区域（按钮自身尺寸较小，位于视频区域之外或边缘）
- **Verification**: `human-judgment`

### AC-3: 按钮保持可拖动
- **Given**: 连播模式已开启，按钮显示在屏幕右下角
- **When**: 用户按下按钮并拖动
- **Then**: 按钮跟随手指移动，松开后停留在当前位置，且不会超出屏幕可视范围边界
- **Verification**: `human-judgment`

### AC-4: 关闭连播模式后按钮消失
- **Given**: 连播模式已开启，按钮显示在屏幕右下角
- **When**: 用户点击连播开关按钮关闭连播模式
- **Then**: 连播浮层按钮立即从屏幕上消失，同时恢复显示右侧操作按钮和底部信息条
- **Verification**: `human-judgment`

### AC-5: 横屏全屏模式下不显示连播按钮
- **Given**: 连播模式已开启
- **When**: 用户切换到横屏全屏模式（`_isFullscreen = true`）
- **Then**: 连播浮层按钮不显示（与当前 `!_isFullscreen && isAutoPlay` 条件保持一致）
- **Verification**: `human-judgment`

### AC-6: 按钮视觉样式 - 半透明浮层
- **Given**: 连播模式已开启
- **When**: 观察按钮视觉效果
- **Then**: 按钮容器具有半透明黑色背景（如 `Color(0x66000000)`），圆形按钮之间有合理间距，整体呈现悬浮卡片效果
- **Verification**: `human-judgment`

### AC-7: 响应式尺寸适配
- **Given**: 连播模式已开启
- **When**: 在不同尺寸的设备上查看（小屏手机 / 大屏手机 / 平板 / 桌面窗口）
- **Then**: 按钮尺寸根据屏幕宽度自适应（使用已有的 `responsiveSize()` 方法），在大屏设备上不显得过小，在小屏设备上不占用过多空间
- **Verification**: `human-judgment`

### AC-8: 底部安全区适配
- **Given**: 连播模式已开启，设备为带有底部手势条的现代手机（如 iPhone 15 Pro、Android 全面屏手机）
- **When**: 观察按钮底部位置
- **Then**: 按钮底部距离屏幕底边保留 `kBottomNavHeight + padding.bottom + 16px` 的空间，确保不与底部导航栏或手势条重叠
- **Verification**: `human-judgment`

### AC-9: 拖动动画与点击反馈
- **Given**: 连播模式已开启
- **When**: 用户拖动按钮或点击按钮
- **Then**: 拖动时有轻微放大效果（当前已有 `_kScaleFactor = 1.1`），点击时有按下缩放反馈（当前 `_PressableActionButton` 已有 0.8 scale）
- **Verification**: `human-judgment`

### AC-10: 代码变更范围最小化
- **Given**: 当前代码库状态
- **When**: 查看变更后的 `video_page_item.dart`
- **Then**: 变更仅限于：(a) `_buildCleanModeRightActions` 的布局调整；(b) `_DraggableCleanActions` 的初始位置参数更新；(c) 可能的新位置计算辅助方法。不修改任何与非连播模式相关的代码
- **Verification**: `programmatic` (通过 diff 审查)

## Open Questions
- [ ] 连播浮层按钮是否需要显示当前倍速值文字？（当前实现：倍速按钮显示图标，不显示数值）
- [ ] 连播按钮的背景色是否需要与其他按钮保持一致的绿色/灰色高亮？（当前已实现，连播开启后连播按钮变绿）
- [ ] 是否需要在连播按钮上添加"连播模式"文字标签？（当前：仅显示图标）
