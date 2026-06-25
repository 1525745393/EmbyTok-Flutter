# 网格视图点击跳转视频流 - The Implementation Plan (Decomposed and Prioritized Task List)

## [x] Task 1: 修复 grid→feed 跳转时 _initialItemId 干扰问题
- **Priority**: high
- **Depends On**: None
- **Description**:
  - 在 `_handleGridToFeedTransition()` 方法中添加 `_initialItemId = null` 清理逻辑
  - 防止从其他页面跳转设置的 `initialItemId` 干扰 grid 内点击跳转
  - 同时重置 `_hasRestoredScrollPosition` 和 `_hasScrolledToInitial` 标记
- **Acceptance Criteria Addressed**: AC-7, AC-1
- **Test Requirements**:
  - `programmatic` TR-1.1: 编译通过，无语法错误
  - `human-judgement` TR-1.2: 从其他页面跳转到 FeedView 后，切换到 grid 再点击视频返回 feed，播放的是点击的视频而非初始跳转的视频
- **Notes**: 已在 commit `1fb14b8` 中完成修复

## [x] Task 2: 网格点击事件设置选中视频 ID 并切换视图
- **Priority**: high
- **Depends On**: None
- **Description**:
  - `_PosterCard` 的 `onTap` 回调中设置 `gridSelectedItemIdProvider` 为当前视频 ID
  - 同步更新 `currentPlayingItemProvider` 全局播放状态
  - 调用 `viewModeProvider.notifier.setMode(ViewMode.feed)` 切换到视频流模式
- **Acceptance Criteria Addressed**: AC-1
- **Test Requirements**:
  - `programmatic` TR-2.1: 点击网格卡片后 `gridSelectedItemIdProvider` 值正确更新
  - `human-judgement` TR-2.2: 点击卡片后视图成功切换到视频流模式
- **Notes**: 已在 `poster_grid_view.dart` 的 `_PosterCard` 组件中实现

## [x] Task 3: FeedView 监听选中视频 ID 并跳转
- **Priority**: high
- **Depends On**: Task 2
- **Description**:
  - 在 `FeedView.initState` 中通过 `ref.listen` 监听 `gridSelectedItemIdProvider`
  - 收到非空 ID 时调用 `_seekToItem(itemId)` 跳转到对应视频
  - `_seekToItem` 在 `videoListProvider.items` 中线性查找对应 ID 的索引
  - 使用 `PageController.animateToPage` 平滑跳转到目标页
- **Acceptance Criteria Addressed**: AC-1, AC-2, AC-3
- **Test Requirements**:
  - `programmatic` TR-3.1: `_seekToItem` 能正确根据 itemId 找到索引
  - `human-judgement` TR-3.2: 跳转后显示的视频与点击的视频一致
- **Notes**: 已在 `feed_view.dart` 中实现，动画时长 300ms，使用 `Curves.easeOut`

## [x] Task 4: 视图模式切换时的数据裁剪（神之一手）
- **Priority**: high
- **Depends On**: Task 3
- **Description**:
  - feed → grid 切换时，根据 `currentIndex` 计算当前页码
  - 从 `items` 中裁剪出当前页的 150 条数据作为 `gridItems`
  - 设置 `gridStartIndex` 记录当前页在全量数据中的偏移
  - 支持搜索模式下的特殊处理（需要刷新时不裁剪）
- **Acceptance Criteria Addressed**: AC-2, AC-4
- **Test Requirements**:
  - `programmatic` TR-4.1: 裁剪后 `gridItems` 长度不超过 150
  - `programmatic` TR-4.2: `gridStartIndex` 是 `kGridPageSize` 的整数倍
  - `human-judgement` TR-4.3: 从 feed 切到 grid 时，显示的是当前播放视频所在的页
- **Notes**: 已在 `video_list_provider.dart` 的 `viewModeProvider` 监听中实现

## [x] Task 5: 网格滚动位置持久化与恢复
- **Priority**: medium
- **Depends On**: Task 2
- **Description**:
  - 网格滚动时防抖 500ms 保存滚动偏移量到 SharedPreferences
  - 从视频流切回网格时恢复之前的滚动位置
  - 使用 `_hasRestoredGridScrollPosition` 标记防止重复恢复
- **Acceptance Criteria Addressed**: AC-4
- **Test Requirements**:
  - `programmatic` TR-5.1: 滚动停止 500ms 后保存偏移量
  - `human-judgement` TR-5.2: 切换视图后返回网格，滚动位置保持不变
- **Notes**: 已在 `feed_view.dart` 的 `_onGridScrollChanged` 和 `_restoreGridScrollOffset` 中实现

## [x] Task 6: 验证所有场景并修复潜在问题
- **Priority**: high
- **Depends On**: Task 1, Task 2, Task 3, Task 4, Task 5
- **Description**:
  - 验证单库模式下点击跳转
  - 验证多库模式下点击跳转
  - 验证分页模式下跨页点击跳转
  - 验证随机/收藏/继续观看等不同 feedType 下的跳转
  - 验证从其他页面跳转后的 grid→feed 跳转
  - 验证反复切换后的状态一致性
  - 发现并修复两个关键 Bug：
    1. gridSelectedItemIdProvider 监听器触发时 PageView 未构建导致跳转失效
    2. FeedView 未同步 currentIndexProvider 导致神之一手裁剪失效
- **Acceptance Criteria Addressed**: AC-1, AC-2, AC-5, AC-6, AC-7
- **Test Requirements**:
  - `human-judgement` TR-6.1: 所有场景下点击网格视频都能正确跳转到对应视频
  - `human-judgement` TR-6.2: 切换过程平滑，无闪烁卡顿
  - `human-judgement` TR-6.3: 多次切换后状态正确，不出现跳回第一个视频的问题
- **Notes**: 
  - 已修复 Bug 1：在 _handleGridToFeedTransition 中使用 addPostFrameCallback 延迟跳转
  - 已修复 Bug 2：在 onPageChanged 中同步更新 currentIndexProvider
  - 代码逻辑已通过审查验证
