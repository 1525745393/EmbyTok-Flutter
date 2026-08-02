# 首页页面问题修复 - The Implementation Plan (Decomposed and Prioritized Task List)

---

## [x] Task 1: 修复 isFeedVisible 逻辑矛盾（覆盖层仍视为 Feed 可见）
- **Priority**: high
- **Depends On**: None
- **Description**: 
  - 修改 [page_navigation_provider.dart](file:///workspace/frontend/lib/providers/page_navigation_provider.dart) 中的 `isFeedVisible` getter
  - 当前实现：`currentIndex == PageIndices.feed`（覆盖层 search/history 被视为不可见，导致视频暂停）
  - 修复为：搜索/历史覆盖层（isOverlayPage=true）时，Feed 仍在 IndexedStack 中可见，应视为可见
  - 同步更新 [home_scaffold.dart](file:///workspace/frontend/lib/views/home_scaffold.dart) 中 `applyFeedVisibilityChange` 的注释（第 399 行），确保与实现一致
  - 更新 [feed_autopause_test.dart](file:///workspace/frontend/test/views/feed_autopause_test.dart) 中的 4 个测试用例（search/history 覆盖层 isFeedVisible 断言和 applyFeedVisibilityChange 行为）
- **Acceptance Criteria Addressed**: AC-1, AC-2, AC-3
- **Test Requirements**:
  - `programmatic` TR-1.1: `isFeedVisible` 在 `currentIndex=search, isOverlayPage=true` 时返回 `true`（原返回 false，需修改测试和实现）
  - `programmatic` TR-1.2: `isFeedVisible` 在 `currentIndex=history, isOverlayPage=true` 时返回 `true`
  - `programmatic` TR-1.3: Feed → 搜索覆盖层场景，`applyFeedVisibilityChange` **不调用** `controller.pause()`（原测试期望 pause，需改为期望不调用）
  - `programmatic` TR-1.4: Feed → 历史覆盖层场景，同上，不触发 pause
  - `programmatic` TR-1.5: Feed → 收藏 Tab 场景，仍触发 pause（不变，确保未引入回归）
- **Notes**: 本任务修改会影响 4 个已有测试的期望值。先修改生产代码 `isFeedVisible`，然后同步修改测试。修改后 `_pauseIfPlaying` 只在切到主 Tab（favorites/actors/settings）时触发。不要执行 git commit/push/stash 操作，只做代码编辑。提交由主代理统一处理。

---

## [x] Task 2: 修复 isPageScrollingProvider 监听器注册时机
- **Priority**: high
- **Depends On**: Task 1
- **Description**:
  - 在 [feed_view.dart](file:///workspace/frontend/lib/views/feed_view.dart) 的 `initState` 中，将 `_pageController.position.isScrollingNotifier.addListener(_onScrollingChanged)` 从 `if (hasClients)` 直接执行改为 `addPostFrameCallback` 后执行
  - 原因：`initState` 时 PageView 尚未 build，PageController 的 `hasClients` 必为 false，导致监听器永远不注册
  - 修复：延迟到第一帧后（PageView 已 build，controller 已 attach）再注册
  - 同时在 `_onScrollingChanged` 中保持 `_pageController.position` 访问的健壮性（注意 position 可能在 dispose 后不可用）
  - 新增测试：验证 FeedView pump 完成后，手动触发 isScrollingNotifier 能正确更新 `isPageScrollingProvider`
- **Acceptance Criteria Addressed**: AC-4, AC-5
- **Test Requirements**:
  - `programmatic` TR-2.1: 在测试环境 pump 一个最小 FeedView（登录状态 + mock 视频列表），读取初始 `isPageScrollingProvider` 值为 false
  - `programmatic` TR-2.2: 触发 PageController.position.isScrollingNotifier 变为 true（构造 ScrollController 模拟或直接访问 position），验证 `isPageScrollingProvider` 被同步更新为 true
  - `programmatic` TR-2.3: （若 Task 2.1 无法直接触发，退化为）代码审查确认：监听器注册逻辑移到 `addPostFrameCallback` 中，且在注册前不再检查 `hasClients`（因为回调时已为 true）
  - `programmatic` TR-2.4: `video_player_widget` 代码审查：当 `isPageScrollingProvider=true` 时，非当前页走 `_releaseCurrentController` 立即释放分支（逻辑不变，仅验证其依赖的 provider 现在会正确赋值）
- **Notes**: 由于 PageView 滚动在 widget test 中较难精确模拟，TR-2.2 允许退化为代码位置审查 + provider 初始值测试。不要执行 git commit/push/stash 操作，只做代码编辑。提交由主代理统一处理。

---

## [x] Task 3: 清理代码质量问题（中等问题）
- **Priority**: medium
- **Depends On**: Task 1
- **Description**:
  - **子任务 3.1** `onUpdateHelpVisibility` 回调参数修复：将 FeedViewModel 的 `onUpdateHelpVisibility` 回调类型从 `void Function(bool visible)?` 改为 `VoidCallback?`，同步更新 FeedView 传入的闭包（移除 unused `visible` 参数或改为 `_`）。若保留有参版本，则必须在实现中使用该参数（如同步到本地 state 而不是仅 setState）。
  - **子任务 3.2** PopScope 冗余条件移除：在 [home_scaffold.dart:185](file:///workspace/frontend/lib/views/home_scaffold.dart#L185) 移除 `currentIndex != PageIndices.search && currentIndex != PageIndices.history` 两个判断（因为 isOverlayPage=false 时这两种 index 不可能出现，先检查的 isOverlayPage 分支已 return）。
  - **子任务 3.3** VideoPoolService maxSize 统一常量引用：在 `video_pool_service.dart` 构造函数默认参数中，从硬编码 `1` 改为引用 `constants.dart` 的 `kMaxPreloadControllers`，并 import 常量文件。
- **Acceptance Criteria Addressed**: AC-6, AC-9, AC-10
- **Test Requirements**:
  - `human-judgment` TR-3.1: FeedViewModel 构造回调签名与调用点一致，参数不再被静默忽略（代码审查）
  - `human-judgment` TR-3.2: 移除冗余条件后逻辑等价（代码审查 + 运行已有 home_scaffold_test.dart 全部通过）
  - `human-judgment` TR-3.3: VideoPoolService 默认 maxSize 与 kMaxPreloadControllers 一致且引用同一常量（代码审查）
- **Notes**: 所有子任务属于清理型修改，不改变公共行为。修改后运行所有现有测试，确保 0 失败。不要执行 git commit/push/stash 操作，只做代码编辑。提交由主代理统一处理。

---

## [x] Task 4: 构建期副作用移到生命周期方法
- **Priority**: medium
- **Depends On**: Task 2
- **Description**:
  - 将 [feed_view.dart](file:///workspace/frontend/lib/views/feed_view.dart) 中 `_buildVideoPageView` 内的两处副作用从 build 树中移出：
    - **a) initialItemId 处理**：`widget.initialItemId` 非空时调用 `_viewModel.waitForInitialItem(initialId)`。应在 `didChangeDependencies` 或 `initState` + `addPostFrameCallback` 中执行，且只处理一次（`_initialItemProcessed` 标记防止重复）。注意 widget.initialItemId 是 final，不会变。
    - **b) 首 item 播放初始化**：`videoState.items.isNotEmpty && playbackState.id == null` 时设置首项为播放项。移到 `addPostFrameCallback` 中，且添加幂等保护。
  - 重构后 `_buildVideoPageView` 仅包含 UI 构建逻辑。
- **Acceptance Criteria Addressed**: AC-7
- **Test Requirements**:
  - `programmatic` TR-4.1: 代码审查：`build` 方法（含 `_buildVideoPageView`）中不再包含 `waitForInitialItem`、`setPlaying`、`addPostFrameCallback` 等副作用调用
  - `programmatic` TR-4.2: 重构后运行 `feed_view_valuekey_test.dart`、`feed_view_transition_test.dart`、`feed_autopause_test.dart` 全部通过，无回归
  - `programmatic` TR-4.3: 构造带 `initialItemId` 的 FeedView，确保 `waitForInitialItem` 在 PlaybackCoordinator 上被调用一次（可通过 mock 验证，或审查调用位置确保只在 init 路径调用一次）
- **Notes**: 本任务重构需要谨慎处理 `widget.initialItemId` 的生命周期。若 widget 重建但参数不变，不能重复触发。不要执行 git commit/push/stash 操作，只做代码编辑。提交由主代理统一处理。

---

## [x] Task 5: Magic Number 提取为具名常量
- **Priority**: low
- **Depends On**: Task 3
- **Description**:
  - 在 [constants.dart](file:///workspace/frontend/lib/utils/constants.dart) 中新增以下具名常量（含注释说明取值依据）：
    - `kInitialItemPollIntervalMs = 100` — PlaybackCoordinator 轮询间隔
    - `kInitialItemPollMaxRetries = 50` — PlaybackCoordinator 轮询重试上限（~5s 超时）
    - `kVideoPoolDisposeBatchSize = 2` — VideoPoolService 分批释放大小
    - `kVideoPreloadInitTimeoutSec = 12` — 预加载 controller 初始化超时
    - `kFullscreenTransitionMs = 300` — 全屏进入/退出动画时长
  - 在以下文件中替换硬编码值为上述常量引用：
    - [playback_coordinator.dart](file:///workspace/frontend/lib/coordinators/playback_coordinator.dart) — `tick > 50`、`100ms`
    - [video_pool_service.dart](file:///workspace/frontend/lib/services/video_pool_service.dart) — `batchSize = 2`、`12s`
    - [fullscreen_navigator.dart](file:///workspace/frontend/lib/utils/fullscreen_navigator.dart) — `300ms`
- **Acceptance Criteria Addressed**: AC-8
- **Test Requirements**:
  - `human-judgment` TR-5.1: constants.dart 新增 5 个常量，每个带有用途注释
  - `human-judgment` TR-5.2: 3 个目标文件中原硬编码数字处已替换为常量引用，且行为一致（值相同）
  - `programmatic` TR-5.3: 常量值与原有值完全相同（==100、==50、==2、==12、==300），运行所有测试通过
- **Notes**: 本任务属于纯清理，不改变逻辑，只提取常量。不要执行 git commit/push/stash 操作，只做代码编辑。提交由主代理统一处理。

---

## [x] Task 6: 回归测试 + 新增测试验证
- **Priority**: high
- **Depends On**: Task 1, Task 2, Task 3, Task 4, Task 5
- **Description**:
  - 运行 `flutter test` 完整测试套件，确保 0 failure、0 compilation error
  - 若出现因 Task 1 导致的测试断言失败（如 feed_autopause_test.dart 中覆盖层期望 pause 的 2 个用例），更新断言使其与修复后逻辑一致
  - 补充 2 个新测试用例：
    - **TC-1**：isFeedVisible 覆盖层回归测试（`PageIndices.search, isOverlayPage=true` → true）
    - **TC-2**：isFeedVisible 切主 Tab 仍正确（`PageIndices.favorites` → false）
- **Acceptance Criteria Addressed**: AC-11
- **Test Requirements**:
  - `programmatic` TR-6.1: `flutter test` 全量运行，退出码 0，输出中 "All tests passed"
  - `programmatic` TR-6.2: 新增 TC-1 和 TC-2 两个测试用例通过
  - `programmatic` TR-6.3: 具体到首页相关的 4 个测试文件全部通过：home_scaffold_test、feed_view_valuekey_test、feed_view_transition_test、feed_autopause_test
- **Notes**: 若 Flutter SDK 未安装，可在支持的环境中执行 `flutter test`。本任务仅在测试可运行时要求 TR-6.1，否则退化为代码编译级检查 + 测试代码逻辑审查。不要执行 git commit/push/stash 操作，只做代码编辑。提交由主代理统一处理。
