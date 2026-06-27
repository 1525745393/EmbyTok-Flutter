# 修复网格→视频流跳转被 SharedPreferences 恢复覆盖

## Why
网格点击视频后切换到视频流，`_buildVideoPageView` 中的 SharedPreferences 滚动位置恢复逻辑（`_restoreVideoIndex`）与 `_handleGridToFeedTransition` 的跳转逻辑存在竞争条件，导致网格点击跳转失效。

## What Changes
- **修复** `_handleGridToFeedTransition`：在跳转前设置 `_hasRestoredScrollPosition = true`，阻止 SharedPreferences 恢复覆盖跳转
- **修复** `_buildVideoPageView`：增加 `gridSelectedItemIdProvider` 判断，有网格选中项时跳过 SharedPreferences 恢复

## Impact
- Affected specs: grid-to-feed-navigation, embyx-alignment-check
- Affected code: `frontend/lib/views/feed_view.dart`

## 根因分析

用户点击网格视频后，以下事件顺序发生：

1. `poster_grid_view.dart` 设置 `gridSelectedItemIdProvider`，切换 `viewMode` 到 `feed`
2. `FeedView` 重建，调用 `_buildVideoPageView`
3. `_initialItemId` 为 null → 跳过初始跳转
4. `_hasRestoredScrollPosition` 为 false → **触发 SharedPreferences 恢复**，跳转到上次保存的位置
5. `viewModeProvider` 监听器触发 `_handleGridToFeedTransition` → 跳转到目标视频

步骤 4 和 5 都在 `addPostFrameCallback` 中执行，存在竞争，SharedPreferences 恢复可能覆盖正确跳转。

## MODIFIED Requirements

### Requirement: 网格→视频流跳转不被覆盖
系统 SHALL 在网格点击切换到视频流时，跳过 SharedPreferences 滚动位置恢复，确保跳转到用户点击的视频。

#### Scenario: 网格点击视频后正确跳转
- **GIVEN** 用户在网格视图中
- **WHEN** 用户点击第 N 个视频
- **THEN** 视频流切换到第 N 个视频开始播放
- **AND** 不会跳转到 SharedPreferences 中保存的上次位置

#### Scenario: 正常进入视频流时恢复位置
- **GIVEN** 用户从其他页面进入视频流（非网格点击）
- **WHEN** 视频流首次加载
- **THEN** 从 SharedPreferences 恢复上次滚动位置