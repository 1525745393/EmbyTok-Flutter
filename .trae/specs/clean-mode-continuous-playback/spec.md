# 纯净模式与连播增强 Spec

## Why
当前 EmbyTok 已具备基础连播功能，但缺少：
1. 沉浸式纯净模式 - 连播时不显示任何 UI 元素
2. 无限连播 - 持续自动播放不中断
3. 清晰的连播状态提示 - 用户不知道连播模式是否开启
4. 便捷的倍速控制 - 长按快速开启 2x，手动调节 1-10x

## What Changes
- **纯净模式**：连播时自动隐藏所有 UI（右侧按钮、底部信息、控制条），仅保留视频画面
- **无限连播模式**：开启后自动连续播放下一个视频，无需用户交互
- **自动播放提示**：连播开关开启时显示 Toast 提示
- **2 倍速长按**：长按视频 500ms 自动切换到 2x 速，松开恢复
- **右侧倍速滑块**：右侧操作栏可手动调节播放速度 1x-10x

## Impact
- Affected specs: `tiktok-playback-experience`（已具备基础播放体验，本次增强连播沉浸模式）
- Affected code:
  - `frontend/lib/widgets/video_page_item.dart`（主要修改：纯净模式逻辑、倍速控制）
  - `frontend/lib/widgets/video_controls.dart`（修改：倍速选择器 UI）
  - `frontend/lib/providers/video_playback_controller.dart`（修改：倍速状态管理）

## ADDED Requirements

### Requirement: 纯净模式
系统 SHALL 在连播模式下自动隐藏所有 UI 元素，仅保留视频画面。

#### Scenario: 进入纯净模式
- **WHEN** 用户开启"无限连播"模式
- **AND** 视频开始自动播放下一个
- **THEN** 隐藏右侧操作按钮列
- **AND** 隐藏底部视频信息区
- **AND** 隐藏控制条（VideoControls）
- **AND** 隐藏顶部状态栏（如果可见）
- **AND** 仅保留纯视频画面

#### Scenario: 退出纯净模式
- **WHEN** 用户点击屏幕
- **THEN** 显示控制层（3 秒后自动隐藏）
- **AND** 显示右侧操作按钮
- **AND** 显示底部信息区

### Requirement: 无限连播模式
系统 SHALL 提供无限连播开关，开启后自动连续播放列表中的视频。

#### Scenario: 开启无限连播
- **WHEN** 用户点击右侧 Infinity 图标
- **THEN** 切换 isAutoPlay 状态
- **AND** 如果开启，显示 Toast 提示"连播模式已开启"
- **AND** 当前视频播放完毕后自动播放下一个
- **AND** 进入纯净模式

#### Scenario: 关闭无限连播
- **WHEN** 用户再次点击 Infinity 图标
- **THEN** 切换 isAutoPlay 状态为关闭
- **AND** 显示 Toast 提示"连播模式已关闭"
- **AND** 当前视频播完后停止

### Requirement: 自动播放提示
系统 SHALL 在连播状态改变时显示直观的 Toast 提示。

#### Scenario: 开启连播
- **WHEN** 用户开启连播模式
- **THEN** 显示 Toast："连播模式已开启"
- **AND** Toast 持续 2 秒后自动消失

#### Scenario: 关闭连播
- **WHEN** 用户关闭连播模式
- **THEN** 显示 Toast："连播模式已关闭"
- **AND** Toast 持续 2 秒后自动消失

### Requirement: 2 倍速长按
系统 SHALL 支持长按视频快速切换 2x 播放速度。

#### Scenario: 长按开启 2x
- **WHEN** 用户长按视频画面 500ms
- **THEN** 播放速度切换到 2.0x
- **AND** 显示"2x"速度徽章
- **AND** 视频画面右上角显示 Double Speed 徽章

#### Scenario: 松手恢复正常
- **WHEN** 用户松开长按
- **THEN** 播放速度恢复正常（1.0x）
- **AND** 速度徽章消失

### Requirement: 右侧倍速滑块
系统 SHALL 在右侧操作栏提供手动倍速调节（1x-10x）。

#### Scenario: 调节倍速
- **WHEN** 用户点击右侧倍速按钮（当前显示如"2x"）
- **THEN** 弹出倍速选择面板
- **AND** 显示滑块可选择 1x - 10x
- **AND** 实时预览当前选择的倍速值
- **WHEN** 用户选择倍速并确认
- **THEN** 应用选定的倍速
- **AND** 关闭面板

## MODIFIED Requirements

### Requirement: 倍速状态管理
原行为：倍速仅通过控制条调节。
新行为：
- 长按可快速切换 2x/1x
- 右侧可手动调节 1x-10x
- 倍速状态通过 `playbackSpeedProvider` 统一管理

### Requirement: 自动播放开关
原行为：Infinity 图标仅切换状态，无提示。
新行为：
- 切换时显示 Toast 提示
- 开启后进入纯净模式
- 可通过再次点击 Infinity 关闭

## REMOVED Requirements
无
