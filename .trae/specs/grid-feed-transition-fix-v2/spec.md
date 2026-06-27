# 网格↔视频流切换修复 v2 - Spec

## Why
`grid-feed-transition-fix` 的修复方案未能彻底解决竞态条件。`_handleGridToFeedTransition` 与 `_buildVideoPageView` 中 `_initialItemId` 和 `_restoreVideoIndex` 三套 `addPostFrameCallback` 跳转逻辑仍然互相竞争，同时 `_initialItemId` 跳转后未更新 `currentIndexProvider`，导致切回网格时滚动位置错误。

## What Changes
- 用专用 `_gridToFeedItemId` 字段替代复用 `_initialItemId`（避免与路由跳转的 `_initialItemId` 语义混淆）
- 删除 `_handleGridToFeedTransition` 中的跳转逻辑，改为仅设置 `_gridToFeedItemId`
- 在 `_buildVideoPageView` 中，`_gridToFeedItemId` 优先于 `_initialItemId` 和 `_restoreVideoIndex` 执行
- `_gridToFeedItemId` 跳转后同步更新 `currentIndexProvider`
- 添加日志追踪完整跳转链路

## Impact
- Affected specs: grid-feed-transition-fix
- Affected code: `frontend/lib/views/feed_view.dart`

## ADDED Requirements
### Requirement: 网格→视频流专用跳转字段
系统 SHALL 使用 `_gridToFeedItemId` 字段存储网格点击选中的视频 ID，与路由跳转的 `_initialItemId` 独立。

#### Scenario: 网格点击视频
- **WHEN** 用户在网格视图点击视频卡片
- **THEN** `_handleGridToFeedTransition` 设置 `_gridToFeedItemId` 为选中视频 ID
- **AND** 设置 `_hasRestoredScrollPosition = true` 阻止 SharedPreferences 恢复
- **AND** 不再通过 `addPostFrameCallback` 自行跳转

#### Scenario: 视频流构建时处理网格跳转
- **WHEN** `_buildVideoPageView` 被调用且 `_gridToFeedItemId` 非空
- **THEN** 系统优先处理 `_gridToFeedItemId` 跳转（在 `_initialItemId` 和 `_restoreVideoIndex` 之前）
- **AND** 跳转后同步更新 `currentIndexProvider`
- **AND** 清除 `_gridToFeedItemId` 防止重复触发

### Requirement: 视频流→网格滚动位置同步
系统 SHALL 在 `_gridToFeedItemId` 跳转后同步更新 `currentIndexProvider`，确保 `_tryScrollToCurrentVideo` 读到正确位置。

#### Scenario: 网格→视频流→网格
- **WHEN** 用户从网格点击视频 → 视频流播放 → 切回网格
- **THEN** 网格滚动到当前视频位置（垂直居中）
- **AND** 不受 `_restoreVideoIndex` 干扰

## MODIFIED Requirements
### Requirement: 跳转优先级（修改自 grid-feed-transition-fix AC-3）
`_buildVideoPageView` 中跳转逻辑优先级：
1. `_gridToFeedItemId`（网格点击）—— 最高优先级
2. `_initialItemId`（路由跳转，如从搜索页进入）
3. `_restoreVideoIndex`（SharedPreferences 恢复，首次进入）

三者互斥，同时只有一个生效。

## REMOVED Requirements
无