# 播放器控制功能（TDD）- Product Requirement Document

## Overview
- **Summary**：完善 Flutter 视频播放应用的核心播放控制功能，包括中央播放按钮、控制条播放/暂停、手势快进/快退、长按加速、水平拖动 seek、单击显示控制条以及底部细线进度条等 TikTok 风格交互体验。
- **Purpose**：解决当前应用中播放控制按钮点击无响应、手势操作不触发、进度条不可交互等核心体验问题，确保视频播放控制的可用性和稳定性。
- **Target Users**：使用 EmbyTok Flutter 应用进行视频播放的终端用户。

## Goals
- **G1 播放/暂停控制**：中央大按钮和控制条按钮均可触发播放/暂停，状态在两者间保持同步
- **G2 手势快进/快退**：双击屏幕左 1/3 区域后退 10 秒，双击右 1/3 区域前进 10 秒，伴随视觉反馈和震动反馈
- **G3 长按加速**：长按播放区域以 2.0x 速度播放，松手恢复原速，期间显示速度徽章
- **G4 水平拖动 seek**：水平拖动屏幕进行粗略定位，期间只显示预览位置不执行 seek，松手才跳转
- **G5 单击控制层切换**：单击视频画面切换底部控制条的显示/隐藏，不直接控制播放状态
- **G6 底部细线进度条**：始终可见的 2px 高进度条，实时反映播放位置，支持点击跳转

## Non-Goals (Out of Scope)
- 视频解码和硬件加速优化（由 video_player 插件负责）
- 多音轨切换（已有专门的字幕/音轨选择组件）
- 投屏和 AirPlay 支持（独立功能模块）
- 视频缓存和预加载策略（已有预加载机制）

## Background & Context
- **技术栈**：Flutter 3.x + riverpod + video_player + cached_network_image
- **架构模式**：MVVM + Provider 状态管理
- **组件拆分**：视频播放功能已拆分为 `VideoPageItem`（主容器）、`GestureOverlay`（手势层）、`VideoControls`（控制条）、`video_control_buttons.dart`（按钮组件）、`video_progress_bars.dart`（进度条）等多个子组件
- **状态管理**：播放状态由 `isPlayingProvider`（bool）、`playbackRateProvider`（double）、`currentVideoControllerProvider`（VideoPlayerController?）等 Provider 统一管理

## Functional Requirements

### FR-1：中央播放按钮
- **实现位置**：`CenterPlayButton` in `widgets/video/video_control_buttons.dart`
- **显示条件**：VideoPlayerController 已初始化 `&& isPlaying == false`
- **交互行为**：点击调用 `_togglePlay()` → controller.play()/pause() → 同步 `isPlayingProvider`
- **视觉样式**：半透明圆形背景 + 白色播放图标

### FR-2：控制条播放/暂停按钮
- **实现位置**：`VideoControls` in `widgets/video_controls.dart`
- **图标切换**：播放时显示 `Icons.pause`，暂停时显示 `Icons.play_arrow`
- **状态来源**：从 `controller.value.isPlaying` 读取并通过 `addListener` 触发 setState
- **同步机制**：点击时同时更新 `isPlayingProvider` 状态

### FR-3：双击快进/快退
- **实现位置**：`GestureOverlay._onDoubleTap` in `widgets/gesture_overlay.dart`
- **区域判定**：屏幕宽度的 0-33% 为快退区，67-100% 为快进区，中间为点赞区
- **位移量**：±10 秒（由 `_seekBySeconds()` 方法执行）
- **视觉反馈**：半透明渐变遮罩 + 方向图标 + ±10s 文本
- **触觉反馈**：`HapticFeedback.lightImpact()`

### FR-4：长按加速播放
- **实现位置**：`GestureOverlay._onLongPressStart/End` in `widgets/gesture_overlay.dart`
- **加速倍数**：`kLongPressPlaybackRate = 2.0`（在 `utils/constants.dart` 定义）
- **状态更新**：开始时 `setPlaybackSpeed(2.0)` + 更新 `playbackRateProvider`
- **恢复逻辑**：松手时恢复 `playbackRateProvider` 记录的原始速度
- **视觉反馈**：顶部显示 `_SpeedBadge`（2.0x 文本徽章）

### FR-5：水平拖动进度预览
- **实现位置**：`GestureOverlay._onHorizontalDragStart/Update/End` in `widgets/gesture_overlay.dart`
- **拖动系数**：`kSeekPerPixelMs = 100`（每像素 100 毫秒）
- **预览机制**：拖动中只更新 `_previewPosition` 变量 + `_SeekPreviewBar` UI，不调用 `seekTo`
- **执行时机**：`_onHorizontalDragEnd` 时一次性调用 `controller.seekTo()`
- **自动隐藏**：松手后 800ms 隐藏预览条
- **触觉反馈**：进入拖动模式时 `HapticFeedback.selectionClick()`，执行 seek 时 `HapticFeedback.lightImpact()`

### FR-6：单击切换控制层
- **实现位置**：`GestureOverlay._onSingleTap` → `VideoPageItem._toggleControls`
- **单击/双击区分**：300ms 定时器（`kDoubleTapMs`），未再次点击则判定为单击
- **控制层自动隐藏**：显示后 3 秒自动隐藏
- **控制层内容**：`VideoControls`（播放按钮 + 进度条 + 倍速 + 字幕）

### FR-7：底部细线进度条
- **实现位置**：`ThinProgressBar` in `widgets/video/video_progress_bars.dart`
- **视觉样式**：2px 高度，全屏宽度，主色填充 + 半透明背景
- **实时更新**：通过 `controller.addListener` 监听播放位置变化
- **点击交互**：支持点击跳转（可选增强）

## Non-Functional Requirements
- **NFR-1 性能**：手势事件处理延迟 < 16ms，无明显 UI 卡顿
- **NFR-2 稳定性**：高频 seek 操作不会导致 MediaCodec 崩溃（通过拖动预览 + 单次 seek 实现）
- **NFR-3 可维护性**：所有播放控制相关状态集中由 `video_playback_controller.dart` 的 Provider 管理
- **NFR-4 兼容性**：兼容 Flutter 3.x，无未定义 context/常量引用
- **NFR-5 主题一致性**：所有颜色使用 `Theme.of(context).colorScheme` 语义化颜色，不硬编码颜色值

## Constraints
- **技术约束**：必须使用 `video_player` 官方插件，不能引入第三方播放器
- **状态约束**：必须使用 `riverpod` 进行跨组件状态同步
- **UI 约束**：必须遵循 Material Design 3 主题系统，颜色必须从 `ColorScheme` 派生
- **交互约束**：单击切换控制层，双击快进/快退/点赞，长按加速，水平拖动 seek，各手势冲突由 `GestureDetector` 内部优先级处理

## Assumptions
- 用户设备支持震动反馈（`HapticFeedback`），不支持时静默忽略
- 视频内容有足够的播放时长（> 30 秒）来测试 seek 操作
- 手势事件传递机制正常，`GestureOverlay` 的 `HitTestBehavior.opaque` 能正确拦截点击

## Acceptance Criteria

### AC-1：中央播放按钮控制播放/暂停
- **Given**：视频已加载且处于暂停状态
- **When**：用户点击屏幕中央的播放按钮
- **Then**：视频开始播放，中央按钮消失，`isPlayingProvider` 变为 true
- **Verification**：programmatic + human-judgment
- **Notes**：验证 controller.play() 被调用，Provider 状态更新，UI 消失动画

### AC-2：控制条按钮控制播放/暂停
- **Given**：视频正在播放，控制条可见
- **When**：用户点击控制条的播放/暂停按钮
- **Then**：视频暂停/播放切换，图标从 pause 变为 play_arrow（或相反），中央按钮状态同步
- **Verification**：programmatic + human-judgment

### AC-3：双击左区域快退 10 秒
- **Given**：视频播放中，当前播放位置 > 10 秒
- **When**：用户快速双击屏幕左 1/3 区域
- **Then**：播放位置后退 10 秒，显示快退视觉反馈动画，触发轻震动
- **Verification**：programmatic + human-judgment
- **Notes**：验证 `_seekBySeconds(-10)` 被正确调用，动画在 600ms 内完成

### AC-4：双击右区域快进 10 秒
- **Given**：视频播放中，当前位置距结束 > 10 秒
- **When**：用户快速双击屏幕右 1/3 区域
- **Then**：播放位置前进 10 秒，显示快进视觉反馈动画，触发轻震动
- **Verification**：programmatic + human-judgment

### AC-5：长按加速至 2.0x
- **Given**：视频以 1.0x 速度播放
- **When**：用户长按屏幕 > 300ms
- **Then**：播放速度切换至 2.0x，顶部显示 "2.0x" 速度徽章，`playbackRateProvider` 同步为 2.0
- **Verification**：programmatic + human-judgment

### AC-6：松手恢复原始播放速度
- **Given**：用户正在长按加速播放
- **When**：用户松开手指
- **Then**：播放速度恢复到长按之前的速度值（从 `playbackRateProvider` 读取），速度徽章消失
- **Verification**：programmatic + human-judgment

### AC-7：水平拖动预览进度
- **Given**：视频播放中，总时长 > 1 分钟
- **When**：用户在屏幕上水平拖动手指
- **Then**：显示 `_SeekPreviewBar` 预览条，实时更新目标位置和时间偏移文本
- **Verification**：programmatic + human-judgment
- **Notes**：关键验证点：拖动中**不**调用 `seekTo`，只更新 UI

### AC-8：松手执行 seek
- **Given**：用户正在水平拖动，预览位置已更新
- **When**：用户松手
- **Then**：一次性调用 `controller.seekTo(previewPosition)`，震动提示，预览条 800ms 后隐藏
- **Verification**：programmatic + human-judgment

### AC-9：单击画面切换控制条
- **Given**：视频播放中，控制条当前不可见（或可见）
- **When**：用户单击屏幕任意位置（无后续第二次点击）
- **Then**：300ms 后判定为单击，控制条从底部滑入（或滑出）
- **Verification**：programmatic + human-judgment
- **Notes**：验证 `_toggleControls()` 被调用，不触发 `_togglePlay()`

### AC-10：底部细线进度条实时更新
- **Given**：视频正在播放
- **When**：播放位置随时间推进
- **Then**：底部 2px 进度条按比例填充主色，平滑反映播放进度
- **Verification**：programmatic + human-judgment

### AC-11：播放状态在中央按钮和控制条间同步
- **Given**：视频暂停中，中央按钮可见
- **When**：用户点击中央按钮开始播放
- **Then**：中央按钮消失，控制条按钮图标变为 pause，`isPlayingProvider` 为 true
- **Verification**：programmatic + human-judgment

### AC-12：空安全和初始化检查
- **Given**：VideoPlayerController 未初始化或已 dispose
- **When**：用户执行任意播放控制操作
- **Then**：操作被静默忽略，不抛出异常
- **Verification**：programmatic

## Open Questions
- [ ] **Q1**：底部细线进度条是否需要支持点击跳转？当前 `ThinProgressBar` 无点击事件，需确认是否增强
- [ ] **Q2**：纯净模式（isAutoPlay=true）下是否需要禁用部分手势？例如纯净模式下双击应该只做点赞，不触发快进
- [ ] **Q3**：水平拖动的最小触发距离是多少？当前实现没有设置最小位移阈值，轻微滑动可能误触发
