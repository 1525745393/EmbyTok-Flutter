# EmbyTok 沉浸式体验优化 - Product Requirement Document

## Overview
- **Summary**: 针对当前视频流核心体验的系统性优化——包括视频切换过渡动画、智能预加载策略、错误边界与重试、手势视觉反馈等，对标 TikTok 级别的沉浸式滑动体验。
- **Purpose**: 当前实现中视频切换为"硬切"、加载中无过渡、错误状态无引导、手势反馈单一。用户虽然"能用"，但缺乏"好用"的顺滑感。优化目标是让用户感知到的操作延迟减半，异常场景有明确出路。
- **Target Users**: 所有使用竖屏视频流模式（`ViewMode.feed`）的用户，尤其是在家庭网络带宽不稳定环境下使用的用户。

## Goals
- **核心目标**: 在竖屏视频流模式下，视频切换时提供 200ms 的渐变淡入过渡，消除"硬切"突兀感
- **核心目标**: 智能预加载——当前视频播放进度达到 60% 时开始预取下一条，切换后首帧时间 < 300ms
- **核心目标**: 所有错误/加载/空状态均有视觉化展示 + 可操作的按钮（重试/返回），不存在黑屏等待
- **核心目标**: 手势操作（双击点赞、水平拖动进度）均有视觉 + 触觉（haptic）反馈
- **次要目标**: 首次使用视频流模式时，显示上滑提示动画（3 次内自动消失）

## Non-Goals (Out of Scope)
- 不改变视频源、解码方式、协议（仍使用 `video_player` + Emby 流）
- 不引入离线缓存/下载功能（需独立立项）
- 不引入推荐算法/排序策略变更（依赖 Emby 服务端）
- 不引入深色/浅色主题切换（独立议题）
- 不修改网格视图（`ViewMode.grid`）的交互逻辑
- 不引入新的第三方依赖（仅使用已集成的 `video_player`、`flutter_riverpod`、`flutter/services`）

## Background & Context
- 当前架构：`feed_view.dart` 使用 `PageView.builder` 实现竖向滑动，`video_page_item.dart` 是每页的 `Stack`（视频 + 渐变 + 操作按钮），`gesture_overlay.dart` 处理手势
- 当前 `video_player_widget.dart` 已支持降级 `fallbackUrl`，但错误 UI 仅为一个图标 + "加载失败"文字，缺乏引导
- 当前 `gesture_overlay.dart` 已实现双击点赞（`_showHeart`），但未结合 haptic vibration
- 未使用 PageView 的 `onPageChanged` 做预加载信号，仅依赖 video_player 内部缓冲
- 用户反馈："滑动不够顺滑""加载久了以为死机了""不知道还能双击点赞"

## Functional Requirements
- **FR-1 视频切换过渡**: `PageView` 翻到新页时，新视频内容先透明（opacity = 0），200ms 内渐升至 1.0；上一页视频保持显示直到新视频 ready。
- **FR-2 智能预加载**: `video_playback_controller` 监听当前播放进度，当达到预设阈值（默认 60%，可通过 user_preferences 调整）时，对下一条 MediaItem 调用 `VideoPlayerController.network()` 初始化但不 `play()`，由后续页面接管复用。
- **FR-3 错误边界**: 在 `video_page_item.dart` 中增加三层错误 UI：（a）播放器级错误（无法播放）显示带重试按钮的卡片；（b）网络/加载错误在覆盖层显示，不破坏整体布局；（c）空列表在 feed 视图显示"暂无视频" + 返回选择媒体库按钮。
- **FR-4 手势反馈**: 双击点赞时触发 `HapticFeedback.lightImpact()` + heart 动画；水平拖动进度每跨越 5 秒触发 `HapticFeedback.selectionClick()`；长按暂停时触发 `HapticFeedback.mediumImpact()`。
- **FR-5 上滑引导**: 首次进入 feed 视图时，显示一个从底部滑入的半透明箭头图标 + "上滑看下一条"文字，滑动 3 次后自动消失；通过 `app_preferences.dart` 持久化已引导状态。
- **FR-6 加载指示器**: `video_player_widget.dart` 加载状态显示一个带 `primaryPink` 颜色的 `CircularProgressIndicator` + 骨架屏占位（已有的 `surfaceColorL2` 背景），加载超过 8 秒触发超时降级。

## Non-Functional Requirements
- **NFR-1 性能**: 视频切换的 Flutter 重建开销 < 16ms（60fps 单帧），在中低端安卓机型上不可感知卡顿
- **NFR-2 内存**: 预加载同一时间最多保留 2 个预初始化的 controller（当前 + 下一条），切换页面后立即 dispose 掉已滑走页面的 controller（`KeepAlive` 仅保留 Widget 状态，不保留视频 controller）
- **NFR-3 网络**: 预加载在非 WiFi 环境下降低为"仅缓冲 1MB 首段"，避免消耗用户流量
- **NFR-4 可访问性**: 所有新增交互提供 `Semantics` 标签（如"双击点赞""水平拖动调整进度"），屏幕阅读器可感知
- **NFR-5 代码一致性**: 所有新增颜色值统一使用 `utils/colors.dart` 中的常量，不引入新的硬编码颜色

## Constraints
- **技术**: Flutter 3.24.0 / Dart SDK 与当前一致；仅使用现有依赖（`video_player`、`flutter_riverpod`、`vibration` 不可用则使用 `HapticFeedback`）
- **平台**: 同时支持 Web/Android/iOS，但 haptic 反馈在 Web 上降级为视觉动画替代
- **依赖**: `video_player` 插件不可变更为其他播放器（如 exoplayer_flutter 或 better_player），保持现状
- **版本管理**: 功能合并后发布版本号需遵循 `MAJOR.MINOR.PATCH+BUILD_NUMBER` 规则

## Assumptions
- 预加载不会显著影响当前播放的视频（`video_player` 的多实例缓冲不会互相抢占带宽）
- `app_preferences.dart` 中已有的持久化机制可直接用于保存"已显示引导"和"预加载阈值"
- 切换页面后，旧页面的 `VideoPlayerController` 可以被安全 dispose，不会中断新页面的播放
- Emby 服务器提供的媒体 URL 可以被同一页面内的多个 controller 同时请求（无并发限制）

## Acceptance Criteria

### AC-1: 视频切换过渡动画
- **Given**: 用户在视频流视图中播放任意视频
- **When**: 向上滑动切换到下一条视频
- **Then**: 新视频从透明（opacity 0）渐变至可见（opacity 1.0），动画时长 200ms，期间上一页保持可见直到新视频 ready
- **Verification**: `human-judgment`
- **Notes**: 冷启动第一条视频无过渡（没有上一页），直接显示

### AC-2: 智能预加载触发
- **Given**: 用户正在播放一条视频，网络可用
- **When**: 当前播放进度达到 60%（或用户设置的阈值）
- **Then**: 下一条 MediaItem 的 `VideoPlayerController` 被预初始化（调用 `initialize()` 但不 `play()`），滑动到该页时使用预加载的 controller 可在 300ms 内开始播放
- **Verification**: `programmatic`
- **Notes**: 非 WiFi 环境下仅缓存首段 1MB，而不是完整预加载

### AC-3: 错误状态展示与重试
- **Given**: 视频因网络失败、格式不支持或超时无法播放
- **When**: `VideoPlayerController` 报告 `hasError == true` 或加载超过 8 秒超时
- **Then**: 视频区域显示错误卡片，含错误图标、"播放失败，点击重试"文字和一个按钮；点击按钮重新调用 `controller.initialize() + play()`；最多重试 3 次
- **Verification**: `programmatic` + `human-judgment`

### AC-4: 手势视觉 + 触觉反馈
- **Given**: 用户在视频区域进行手势操作
- **When**: 双击点赞 / 长按暂停 / 水平拖动进度每跨越 5 秒
- **Then**: 触发对应 haptic 反馈（lightImpact / mediumImpact / selectionClick），Web 平台降级为视觉抖动动画；heart 动画仍保留
- **Verification**: `human-judgment`

### AC-5: 首次引导提示
- **Given**: 用户首次进入视频流视图，`app_preferences` 中 `feedGuideShown` 为 false
- **When**: Feed 视图首次渲染完成
- **Then**: 显示一个从底部滑入的半透明箭头图标 + "上滑看下一条"文字；用户完成 3 次向上滑动后，文字淡出并将 `feedGuideShown` 标记为 true
- **Verification**: `programmatic`

### AC-6: 加载超时降级
- **Given**: 视频加载中，`CircularProgressIndicator` 持续显示
- **When**: 加载时间超过 8 秒仍未完成
- **Then**: 触发超时逻辑，显示降级错误 UI（同 AC-3），并在日志中记录 "video load timeout"
- **Verification**: `programmatic`

### AC-7: 空列表状态
- **Given**: 筛选后的视频列表为空（`filteredVideoListProvider` 返回空）
- **When**: 用户在 feed 视图中等待加载完成
- **Then**: 显示空状态卡片："当前媒体库没有视频" + "选择其他媒体库"按钮，点击跳转到设置或媒体库选择
- **Verification**: `human-judgment`

### AC-8: 性能指标
- **Given**: 用户连续滑动 20 条视频
- **When**: 使用 Flutter Performance Overlay 观测帧率
- **Then**: 平均帧率 ≥ 55fps，单次切换重建耗时 < 16ms（Profile 模式），内存峰值相比优化前不增长 > 15%
- **Verification**: `programmatic`

### AC-9: 代码规范一致性
- **Given**: 提交的所有新代码
- **When**: 通过 `flutter analyze lib` 静态检查
- **Then**: 无 error，warning 数量不超过优化前的 baseline
- **Verification**: `programmatic`

## Open Questions
- [ ] 预加载的阈值（60%）是否需要通过用户偏好 UI 暴露？（默认内置即可，当前不做 UI）
- [ ] Web 平台的 haptic 降级方案：仅使用视觉动画是否足够？还是需要接入 Web Vibration API？（当前仅做视觉动画）
- [ ] 8 秒超时时长：弱网环境下是否需要更长的超时？（当前保持 8s，后续根据用户反馈调整）
- [ ] 错误重试策略（3 次上限）的退避间隔：固定还是指数退避？（当前使用 1s + 2s + 3s 的线性退避）
