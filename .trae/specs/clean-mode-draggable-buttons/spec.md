# 纯净模式按钮区可拖动 - Product Requirement Document

## Overview
- **Summary**: 将纯净模式下的连播开关和倍速按钮改为可拖动的悬浮组件，用户可拖拽调整位置以避免遮挡视频关键内容。
- **Purpose**: 用户在观看视频时，固定位置的按钮可能会遮挡视频画面（如人物脸部、字幕等），需要能够自由调整按钮位置。
- **Target Users**: 使用纯净模式观看视频的用户。

## Goals
- 纯净模式下的按钮区支持拖拽移动
- 拖拽过程中按钮有视觉反馈（如放大、阴影增强）
- 拖拽结束后按钮停留在目标位置
- 点击行为与拖拽行为不冲突（短按点击，长按并移动为拖拽）
- 按钮不会拖出视频画面区域（边界限制）

## Non-Goals (Out of Scope)
- 不修改非纯净模式下的右侧按钮区布局
- 不实现跨页面/跨会话的位置持久化（本次仅单页内生效，刷新后回到默认位置）
- 不实现动画回弹效果（简化实现）
- 不修改按钮的功能逻辑（点击/切换状态等保持不变）

## Background & Context
- 当前实现：`_buildCleanModeRightActions()` 返回一个 `Positioned` Widget，使用 `right: 0` + `Column` 垂直居中布局
- 按钮区包含两个按钮：连播开关（`_buildAutoPlayButton()`）和倍速按钮（`_buildSpeedControlButton()`）
- 两个按钮各自内部已有 `GestureDetector` 处理点击事件
- 外层 `Stack` 提供自由定位的布局环境

## Functional Requirements
- **FR-1**: 按钮区整体可拖拽（而非每个按钮单独拖拽），拖动时两个按钮作为一个整体移动
- **FR-2**: 点击按钮内部区域仍触发原有点击行为（切换连播 / 弹出倍速面板）
- **FR-3**: 按下并移动超过一定阈值（如 10px）视为拖拽，不再触发点击
- **FR-4**: 拖拽过程中按钮区有视觉变化（放大 10%，增加阴影），提供操作反馈
- **FR-5**: 拖拽结束后，按钮区保持在新的位置（直到页面关闭或 isAutoPlay 状态切换）
- **FR-6**: 按钮区不能拖出视频播放区域（边界限制）
- **FR-7**: isAutoPlay 切换为 true 时，按钮区从默认位置（右侧垂直居中）开始

## Non-Functional Requirements
- **NFR-1**: 拖拽手势响应时间 < 100ms，保证流畅的拖动体验
- **NFR-2**: 点击与拖拽的手势冲突处理正确率 > 95%
- **NFR-3**: 代码修改保持最小化，不破坏现有 `_buildAutoPlayButton()` 和 `_buildSpeedControlButton()` 的内部逻辑
- **NFR-4**: 不引入新的第三方依赖包

## Constraints
- **Technical**: Flutter/Dart，基于现有 Riverpod Provider 状态管理，使用 `GestureDetector` / `Listener` 等原生手势组件
- **Dependencies**: 不引入新依赖，仅使用 Flutter SDK 内置组件
- **Layout**: 按钮区必须在最外层 `Stack` 内定位，使用 `Positioned` 的 left/top 绝对定位

## Assumptions
- 用户理解"拖动整体按钮区"的行为，不需要分别拖动每个按钮
- 用户在正常点击按钮时不会误触发拖拽（10px 阈值足够区分点击和拖动）
- 默认位置（右侧垂直居中）对大多数内容合适，拖动仅作为边缘场景的微调

## Acceptance Criteria

### AC-1: 拖拽移动
- **Given**: 用户处于纯净模式（isAutoPlay=true），视频播放中
- **When**: 用户按下按钮区并拖动
- **Then**: 按钮区整体跟随手指移动
- **Verification**: `human-judgment`

### AC-2: 视觉反馈
- **Given**: 用户正在拖动按钮区
- **When**: 手指按下并移动
- **Then**: 按钮区稍微放大（1.1x）并增加阴影
- **Verification**: `human-judgment`

### AC-3: 位置保持
- **Given**: 用户完成拖拽并松开手指
- **When**: 手指离开屏幕
- **Then**: 按钮区停留在最后位置，不回弹
- **Verification**: `human-judgment`

### AC-4: 点击与拖拽区分
- **Given**: 用户点击按钮区（未移动或移动 < 10px）
- **When**: 手指按下并快速松开（点击时长 < 300ms 且位移 < 10px）
- **Then**: 触发按钮原有点击行为（连播切换或弹出倍速面板）
- **Verification**: `human-judgment`

### AC-5: 拖动不触发点击
- **Given**: 用户完成一次拖拽（位移 > 10px）
- **When**: 手指松开
- **Then**: 不触发按钮点击行为
- **Verification**: `human-judgment`

### AC-6: 边界限制
- **Given**: 用户向屏幕边缘拖动按钮区
- **When**: 按钮区触及视频播放区域边界
- **Then**: 按钮区停止移动，不超出边界
- **Verification**: `human-judgment`

### AC-7: 非纯净模式不受影响
- **Given**: 非纯净模式（isAutoPlay=false）
- **When**: 用户操作右侧按钮
- **Then**: 所有行为与修改前一致
- **Verification**: `human-judgment`

## Open Questions
- [ ] 是否需要跨页面/跨会话持久化按钮位置？（当前设计：不需要，每次进入纯净模式从默认位置开始）
- [ ] 是否需要双击/长按重置到默认位置？（当前设计：不需要，切换 isAutoPlay 状态后即重置）
