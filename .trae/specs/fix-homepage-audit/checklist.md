# 首页页面问题修复 - Verification Checklist

## 严重问题验证（2 项）

- [x] **Checkpoint 1 - isFeedVisible 覆盖层逻辑**
  - [x] `PageNavigationState(currentIndex=search, isOverlayPage=true).isFeedVisible` 返回 `true`（page_navigation_provider.dart:45，新增 isOverlayPage || 判断）
  - [x] `PageNavigationState(currentIndex=history, isOverlayPage=true).isFeedVisible` 返回 `true`（同上）
  - [x] `PageNavigationState(currentIndex=favorites, isOverlayPage=false).isFeedVisible` 返回 `false`（确保切主 Tab 仍不可见）
  - [x] `PageNavigationState(currentIndex=feed, isOverlayPage=false).isFeedVisible` 返回 `true`
  - [x] `applyFeedVisibilityChange` 在 Feed→搜索/历史覆盖层场景**不调用** `pause()`（feed_autopause_test.dart 中两个用例已改为 verifyNever(pause())）
  - [x] `applyFeedVisibilityChange` 在 Feed→收藏/演员/设置场景仍正确调用 `pause()`（未改动）

- [x] **Checkpoint 2 - isPageScrollingProvider 监听器注册**
  - [x] FeedView.initState 中的 `isScrollingNotifier.addListener` 调用位于 `addPostFrameCallback` 回调中（而非直接在 if(hasClients) 块内）（feed_view.dart initState 末尾）
  - [ ] FeedView 实例化 + pump 后，手动设置 PageController.position.isScrollingNotifier 为 true，`isPageScrollingProvider` 同步为 true（代码位置正确，需运行时验证）
  - [x] dispose 时监听器被正确移除（try-catch 包裹 hasClients 检查后 removeListener，防御性清理）
  - [x] 代码审查确认 `_onScrollingChanged` 中访问 `_pageController.position` 不会抛错（已用 try-catch 包裹）

## 代码质量问题验证（5 项）

- [x] **Checkpoint 3 - onUpdateHelpVisibility 回调**
  - [x] FeedViewModel 的 `onUpdateHelpVisibility` 签名与 FeedView 传入的闭包签名一致（统一改为 `void Function()?` 无参）
  - [x] 传入参数不再被静默忽略（改为无参 VoidCallback，参数无需使用，不再存在 unused parameter）

- [x] **Checkpoint 4 - Build 无副作用**
  - [x] `_buildVideoPageView` 方法（及被 build 调用的路径）中不存在 `waitForInitialItem`、`setPlaying`、`addPostFrameCallback` 等副作用调用（两处代码块已删除）
  - [x] `widget.initialItemId` 的处理移至 `initState` + `addPostFrameCallback`，且只执行一次（`_initialItemProcessed` bool 守卫）
  - [x] 首 item 播放初始化逻辑从 build 移出，含幂等保护（`_firstItemInitProcessed` bool 守卫 + `playbackState.id != null` 检查）

- [x] **Checkpoint 5 - Magic Number 提取**
  - [x] constants.dart 新增常量：`kInitialItemPollIntervalMs=100`、`kInitialItemPollMaxRetries=50`、`kVideoPoolDisposeBatchSize=2`、`kVideoPreloadInitTimeoutSec=12`、`kFullscreenTransitionMs=300`
  - [x] playback_coordinator.dart 中原 `100ms`、`50` 两处硬编码替换为常量引用
  - [x] video_pool_service.dart 中原 `2`、`12s` 两处硬编码替换为常量引用
  - [x] fullscreen_navigator.dart 中原 `300ms` 硬编码替换为常量引用
  - [x] 每个新增常量均有注释说明用途/取值依据（中文注释，含取值理由）

- [x] **Checkpoint 6 - PopScope 冗余条件移除**
  - [x] onPopInvokedWithResult 逻辑中 `currentIndex != PageIndices.search` 和 `currentIndex != PageIndices.history` 两个判断已被移除（home_scaffold.dart:185，简化为仅 `currentIndex != PageIndices.feed`）
  - [ ] 现有 `home_scaffold_test.dart` 测试全部通过（Tab 切换无回归）（需运行时验证）

- [x] **Checkpoint 7 - VideoPoolService 统一常量**
  - [x] VideoPoolService 构造函数默认 `maxSize` 参数从硬编码 `1` 改为引用 `kMaxPreloadControllers`（video_pool_service.dart:55）
  - [x] 两处（常量定义和默认参数）值一致，不存在重复定义分歧（kMaxPreloadControllers=1，引用=1）

## 测试与回归验证（1 项）

- [ ] **Checkpoint 8 - 完整测试套件通过**
  - [ ] `home_scaffold_test.dart` 全部通过（需运行时验证）
  - [x] `feed_autopause_test.dart` 已修改：覆盖层 isFeedVisible 断言改为 isTrue，覆盖层 applyFeedVisibilityChange 断言改为 verifyNever(pause())，TC-1 和 TC-2 两个新增回归测试
  - [ ] `feed_view_valuekey_test.dart` 全部通过（需运行时验证）
  - [ ] `feed_view_transition_test.dart` 全部通过（需运行时验证）
  - [x] 新增的 isFeedVisible 回归测试（feed_autopause_test.dart 末尾）：覆盖层 → true、切主 Tab → false
  - [ ] 如 flutter 环境可用：`flutter test` 全量退出码 0，所有 test 文件通过（Flutter SDK 当前环境未安装，待 CI 验证）
  - [x] 代码级编译检查：import 完整、符号引用正确、常量值一致（=100/50/2/12/300，与原硬编码相同）
