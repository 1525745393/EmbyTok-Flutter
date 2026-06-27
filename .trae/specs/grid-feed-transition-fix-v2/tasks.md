# 网格↔视频流切换修复 v2 - 实施计划

## [x] Task 1: 添加 `_gridToFeedItemId` 专用字段并重构 `_handleGridToFeedTransition`
- **Priority**: high
- **Depends On**: None
- **Description**:
  - 在 `_FeedViewState` 中添加 `String? _gridToFeedItemId` 字段
  - 重写 `_handleGridToFeedTransition`：仅设置 `_gridToFeedItemId = selectedItemId`、`_hasRestoredScrollPosition = true`，不再调用 `addPostFrameCallback` 或 `jumpToPage`
  - 读取 `gridSelectedItemIdProvider` 后立即清空
  - 添加日志：`AppLogger.debug('网格→视频流：设置 _gridToFeedItemId', data: {'itemId': selectedItemId})`
- **Acceptance Criteria Addressed**: AC-1
- **Steps**:
  - [x] 1.1 添加 `String? _gridToFeedItemId` 字段声明
  - [x] 1.2 重写 `_handleGridToFeedTransition` 方法
  - [x] 1.3 添加日志追踪

## [x] Task 2: 在 `_buildVideoPageView` 中实现 `_gridToFeedItemId` 优先跳转
- **Priority**: high
- **Depends On**: Task 1
- **Description**:
  - 在 `_buildVideoPageView` 的跳转逻辑区新增 `_gridToFeedItemId` 处理块（放在 `_initialItemId` 和 `_restoreVideoIndex` 之前）
  - 在 `items` 中查找 `_gridToFeedItemId` 对应的索引
  - 找到后通过 `addPostFrameCallback` 调用 `jumpToPage`
  - 同步更新 `_currentIndex` 和 `currentIndexProvider`
  - 跳转后清除 `_gridToFeedItemId` 防止重复
  - 添加日志：`AppLogger.debug('网格→视频流跳转完成', data: {'index': initialIndex, 'itemId': _gridToFeedItemId})`
- **Acceptance Criteria Addressed**: AC-1, AC-2
- **Steps**:
  - [x] 2.1 在 `_initialItemId` 检查之前插入 `_gridToFeedItemId` 检查
  - [x] 2.2 实现索引查找和 `jumpToPage` 跳转
  - [x] 2.3 同步更新 `currentIndexProvider`
  - [x] 2.4 添加日志追踪

## [x] Task 3: 确保跳转优先级互斥
- **Priority**: high
- **Depends On**: Task 2
- **Description**:
  - 在 `_gridToFeedItemId` 跳转块中设置 `_hasScrolledToInitial = true`，阻止后续 `_initialItemId` 块执行
  - 在 `_gridToFeedItemId` 跳转块中设置 `_hasRestoredScrollPosition = true`，阻止 `_restoreVideoIndex` 执行
  - 验证 `_initialItemId` 块的检查条件 `!_hasScrolledToInitial` 与 `_gridToFeedItemId` 互斥
  - 验证 `_restoreVideoIndex` 块的检查条件 `_initialItemId == null` 与 `_gridToFeedItemId` 互斥（因为 `_gridToFeedItemId` 非空时 `_initialItemId` 可能也为空，需额外保护）
- **Acceptance Criteria Addressed**: AC-3
- **Steps**:
  - [x] 3.1 在 `_gridToFeedItemId` 跳转后设置 `_hasScrolledToInitial = true`
  - [x] 3.2 在 `_restoreVideoIndex` 检查中增加 `_gridToFeedItemId == null` 条件
  - [x] 3.3 验证三个跳转块互斥逻辑正确

## [x] Task 4: 验证并提交
- **Priority**: medium
- **Depends On**: Task 1, Task 2, Task 3
- **Description**:
  - 审查完整代码，确认无残留竞争逻辑
  - 验证日志输出可追踪完整跳转链路
  - 提交并推送
- **Acceptance Criteria Addressed**: NFR-3
- **Steps**:
  - [x] 4.1 代码审查
  - [x] 4.2 git commit & push

## Task Dependencies
- Task 2 depends on Task 1
- Task 3 depends on Task 2
- Task 4 depends on Task 1, Task 2, Task 3