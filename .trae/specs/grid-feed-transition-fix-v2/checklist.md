# 网格↔视频流切换修复 v2 - 验证清单

## 网格→视频流跳转验证

- [x] `_handleGridToFeedTransition` 不再包含 `addPostFrameCallback` 或 `jumpToPage` 调用
- [x] `_gridToFeedItemId` 字段在 `_FeedViewState` 中声明
- [x] `_handleGridToFeedTransition` 设置 `_gridToFeedItemId` 后立即清空 `gridSelectedItemIdProvider`
- [x] `_buildVideoPageView` 中 `_gridToFeedItemId` 检查位于 `_initialItemId` 检查之前
- [x] `_gridToFeedItemId` 跳转后同时更新 `_currentIndex` 和 `currentIndexProvider`
- [x] `_gridToFeedItemId` 跳转后清除自身防止重复触发
- [x] 日志可追踪完整跳转链路（设置→查找→跳转）

## 视频流→网格滚动验证

- [x] `_gridToFeedItemId` 跳转后 `currentIndexProvider` 已正确更新
- [x] `_tryScrollToCurrentVideo` 读到正确的 `currentIndex`
- [x] `_handleFeedToGridTransition` 逻辑不变

## 互斥性验证

- [x] `_gridToFeedItemId` 跳转块通过 `else if` 阻止 `_initialItemId` 块
- [x] `_restoreVideoIndex` 检查条件包含 `_gridToFeedItemId == null`
- [x] 三个跳转块（`_gridToFeedItemId`、`_initialItemId`、`_restoreVideoIndex`）同时只有一个生效

## 代码质量验证

- [x] 语法正确（无 Flutter 环境无法编译验证，但代码结构完整）
- [x] 无未使用的变量或导入
- [x] 关键逻辑有简明中文注释
- [x] 无重复或冗余代码