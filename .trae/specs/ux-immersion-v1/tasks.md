# EmbyTok 沉浸式体验优化 - The Implementation Plan (Decomposed and Prioritized Task List)

## [x] Task 1: 视频切换过渡动画（Video Page Fade Transition）
- **Priority**: P0
- **Depends On**: None
- **Description**:
  - 在 `video_page_item.dart` 中，给视频播放区（`VideoPlayerWidget` + `GestureOverlay`）的容器包裹 `AnimatedOpacity`
  - 初始 opacity = 0.0，挂载后 200ms 内曲线 `Curves.easeOut` 渐变到 1.0
  - 在 `video_playback_controller.dart` 中，暴露一个 `bool isReady` 状态：`controller` 初始化完成 + 首帧渲染后，标记为 ready
  - `AnimatedOpacity` 依赖 isReady 触发；冷启动首条视频也应有淡入
  - 上一页视频在 onPageChanged 完成后，由 `FeedView` 调用其 dispose，保持切换期间上一页仍可见
- **Acceptance Criteria Addressed**: AC-1
- **Test Requirements**:
  - `programmatic` TR-1.1: `video_page_item.dart` 内存在 `AnimatedOpacity` 或等效动画组件，duration = 200ms
  - `programmatic` TR-1.2: `video_playback_controller.dart` 暴露 `isReadyProvider`（或等效 provider），其在 `controller.value.isInitialized && controller.value.duration != Duration.zero` 时为 true
  - `human-judgement` TR-1.3: 滑动切换视频时，观察者可感知到新视频"渐入"效果，而非瞬间切换；首次启动冷切换也有明显淡入
- **Notes**: 动画时长参数统一放在 `utils/constants.dart` 中，命名为 `kVideoFadeInDuration`

## [x] Task 2: 智能预加载（Smart Preload）
- **Priority**: P0
- **Depends On**: Task 1（Task 1 的 isReady 是预加载的信号源之一）
- **Description**:
  - 在 `providers/video_playback_controller.dart`（或新建 `providers/preload_controller.dart`）中新增预加载逻辑：
    - 监听 `PageView.onPageChanged` 的当前 index
    - 监听当前播放进度（`controller.addListener` 读取 position/duration）
    - 当前视频 position / duration > 0.6（或 user_preferences 中 `preloadThreshold`，默认 0.6）时，预取下一条
    - 预取 = 为下一条 `MediaItem` 调用 `VideoPlayerController.network(url)` + `initialize()`，但 **不** 调用 `play()`
    - 预加载的 controller 存入一个 `Map<String, VideoPlayerController>`，键为 item.id，最多保留 2 个（当前 + 下一条），超出时 dispose 最早的
    - 切到已预取页面时，`VideoPageItem` 从 map 中取已初始化的 controller 并复用
    - 非 WiFi 环境下（通过 `ConnectivityResult` 检测），预取降级为：仅请求首段 1MB（video_player 的 `httpHeaders` 中 `Range: bytes=0-1048575` 不可用，则退化为不预取，只做 URL 预热）
  - `feed_view.dart` 中修改 `_buildVideoPageView`：`PageView.builder` 的 itemBuilder 先从预加载缓存里取 controller，取不到再新建
- **Acceptance Criteria Addressed**: AC-2, AC-8
- **Test Requirements**:
  - `programmatic` TR-2.1: 预加载阈值可通过 `ref.watch(preloadThresholdProvider)` 获取，默认值 0.6
  - `programmatic` TR-2.2: 预加载缓存 map 大小 ≤ 2；超出时触发 dispose；代码中可看到清理逻辑
  - `human-judgement` TR-2.3: 播放到视频中段后滑动到下一条，下一条视频应在 1s 内开始播放（而非重新加载 3-5 秒）
- **Notes**: 预加载逻辑独立为一个 Provider，方便将来替换策略；预加载的 URL 构造方式复用 `VideoPlayerWidget` 中的逻辑，不重复造轮子

## [x] Task 3: 错误边界与重试（Error Boundary + Retry）
- **Priority**: P0
- **Depends On**: None
- **Description**:
  - 在 `video_page_item.dart` 中，`VideoPlayerWidget` 之外包裹一层错误监听：
    - 当 `controller.value.hasError == true` 时，显示一个居中的错误卡片（含 Icon(Icons.error_outline) + "播放失败" + "重试"按钮）
    - 点击重试调用 `controller.initialize().then((_) => controller.play())`，最多重试 3 次，每次递增延迟（1s / 2s / 3s）
    - 3 次重试仍失败，显示降级错误 UI："无法播放此视频" + "查看详情"展开错误信息
  - 在 `video_player_widget.dart` 中，增加加载超时计时：`_controller` 初始化 8 秒仍未完成，强制置为 hasError=true
  - 在 `feed_view.dart` 中，空列表（`filteredVideoListProvider.isEmpty && videoState.status == AsyncData`）时，显示空状态卡片，包含"选择其他媒体库"按钮，点击跳转设置页或触发 `ref.read(libraryProvider.notifier).refresh()`
- **Acceptance Criteria Addressed**: AC-3, AC-6, AC-7
- **Test Requirements**:
  - `programmatic` TR-3.1: `video_player_widget.dart` 中有 8 秒超时检测代码，触发后设置 hasError=true 并记录日志
  - `programmatic` TR-3.2: 重试计数器在 3 次后停止，错误 UI 显示 "无法播放此视频" 提示
  - `human-judgement` TR-3.3: 网络断开后播放视频，用户看到的是清晰的错误 UI 而非黑屏或无限 loading
- **Notes**: 错误信息不要直接向用户展示 Dio 原始堆栈，记录到 logger 中，UI 仅提示 "播放失败"

## [x] Task 4: 手势视觉 + 触觉反馈（Haptic Feedback）
- **Priority**: P1
- **Depends On**: None
- **Description**:
  - `gesture_overlay.dart` 中，`_onDoubleTap`（双击点赞）后调用 `HapticFeedback.lightImpact()`
  - 长按暂停（`_onLongPressStart`/`_onLongPressEnd`）调用 `HapticFeedback.mediumImpact()`
  - 水平拖动进度（`_onHorizontalDragUpdate`）中，每次跨越 5 秒整数边界，调用 `HapticFeedback.selectionClick()`
  - Web 平台（`kIsWeb`）下，haptic 降级为：视频播放区做一次 20ms 的轻微 scale 抖动动画（scale 1.0 → 1.02 → 1.0）
  - 所有新增手势操作均添加 `Semantics` 标签（如 "双击点赞此视频"、"水平拖动调整进度"）
- **Acceptance Criteria Addressed**: AC-4, NFR-4
- **Test Requirements**:
  - `programmatic` TR-4.1: `gesture_overlay.dart` 中至少调用 1 次 `HapticFeedback.*`
  - `programmatic` TR-4.2: Web 平台有 `kIsWeb` 判断的降级视觉反馈代码
  - `human-judgement` TR-4.3: 移动端测试时，双击视频时可以感知到轻微振动
- **Notes**: 不需要引入 `vibration` 等新依赖，`flutter/services.dart` 自带的 `HapticFeedback` 足够

## [x] Task 5: 首次使用上滑引导（Onboarding Guide）
- **Priority**: P2
- **Depends On**: None
- **Description**:
  - 在 `app_preferences.dart`（或等效 provider）中新增 `feedGuideShown` 布尔键，持久化到 shared_preferences
  - 在 `feed_view.dart` 的 `_buildVideoPageView` 顶层 `Stack` 中，条件渲染引导层：
    - `feedGuideShown == false` 时显示：半透明箭头图标（从屏幕底部 1/3 处向上缓慢位移 + 淡出的循环动画）+ "上滑看下一条视频" 文字
    - 动画循环播放，不阻塞用户操作
    - 检测到 `onPageChanged` 被调用 3 次后，标记 `feedGuideShown = true`，引导层淡出（500ms）并从 tree 移除
- **Acceptance Criteria Addressed**: AC-5
- **Test Requirements**:
  - `programmatic` TR-5.1: `app_preferences.dart` 或 provider 中新增 `feedGuideShown` 读写逻辑
  - `programmatic` TR-5.2: `feed_view.dart` 中引导层在 onPageChanged 计数 ≥ 3 后触发淡出并消失
  - `human-judgement` TR-5.3: 首次安装时可以看到引导提示，清除数据后第二次进入也能看到（持久化正确）
- **Notes**: 动画参数也放到 `utils/constants.dart` 中（`kGuideFadeDuration`、`kGuideSlideDistance`）

## [x] Task 6: 代码规范与静态检查
- **Priority**: P1
- **Depends On**: Task 1-5（全部完成后统一检查）
- **Description**:
  - 所有新增颜色值必须来自 `utils/colors.dart`，不允许硬编码
  - 所有新文件顶部加一行中文注释说明功能
  - 运行 `flutter analyze lib`，修复所有 error 和 info-level warning（保留必要的 // ignore 需有注释说明）
  - 确保 `providers/providers.dart` 中导出所有新增的 provider
- **Acceptance Criteria Addressed**: AC-9
- **Test Requirements**:
  - `programmatic` TR-6.1: `flutter analyze lib` 输出中 no errors
  - `human-judgement` TR-6.2: 代码 review 中不存在未使用的 import 和悬空注释

## Task Dependencies
```
Task 1 ─┐
        ├─→ Task 6
Task 2 ─┘
Task 3 ─┐
Task 4 ─├─→ Task 6
Task 5 ─┘
```
- Task 1 完成后可立即开始 Task 2（isReady 是预加载的依赖）
- Task 3/4/5 互相独立，可并行开发
- Task 6 依赖全部代码合并
