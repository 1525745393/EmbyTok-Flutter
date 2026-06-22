# 观看历史对接 Emby 服务器 Spec

## Why
用户反馈观看历史页面空白/加载失败，说明当前 `HistoryView` 未能正确从 Emby 服务器拉取最近观看记录。现有代码虽已调用 Emby `/Items` 接口，但路径与参数可能不兼容部分 Emby 服务器部署，导致请求失败或返回空列表。

## What Changes
- 修复 `EmbytokService.getWatchHistory` 的 API 调用，使用用户级路径 `/Users/{userId}/Items`
- 移除 `Filters=IsResumable`，改为拉取所有最近播放过的条目（已看完 + 未看完），确保完整的观看历史展示
- 确保 `WatchHistoryNotifier.load()` 在登录态有效时正确传递 `serverUrl`、`token`、`userId`
- 在 `HistoryView` 增加更明确的空状态与错误重试提示
- 补充单元测试覆盖成功、空列表、未登录、请求失败四种场景

## Impact
- 受影响能力：观看历史展示、继续观看、播放进度同步
- 受影响代码：
  - [frontend/lib/services/embbytok_service.dart](file:///workspace/frontend/lib/services/embbytok_service.dart)
  - [frontend/lib/providers/watch_history_provider.dart](file:///workspace/frontend/lib/providers/watch_history_provider.dart)
  - [frontend/lib/views/history_view.dart](file:///workspace/frontend/lib/views/history_view.dart)
  - [frontend/test/services/embbytok_service_test.dart](file:///workspace/frontend/test/services/embbytok_service_test.dart)（新增/补充）

## ADDED Requirements
### Requirement: 用户级历史拉取
The system SHALL 使用已登录用户的 `userId` 调用 Emby `/Users/{userId}/Items` 接口获取观看历史。

#### Scenario: 正常加载
- **GIVEN** 用户已登录且服务器可达
- **WHEN** 打开观看历史页面
- **THEN** 页面展示从 Emby 返回的最近观看条目（最多 50 条），并按 `DatePlayed` 倒序排列

#### Scenario: 空历史
- **GIVEN** 用户已登录但 Emby 没有可恢复的观看记录
- **WHEN** 打开观看历史页面
- **THEN** 页面展示“暂无观看历史”空状态，不报错

#### Scenario: 未登录
- **GIVEN** 用户未登录
- **WHEN** 打开观看历史页面
- **THEN** 展示“尚未登录”提示，不发起网络请求

## MODIFIED Requirements
### Requirement: 历史 API 端点
**现有实现**：`getWatchHistory` 调用全局 `/Items` 路径。
**修改后**：优先使用 `/Users/{userId}/Items`；若 `userId` 为空则降级到 `/Items` 并附加 `UserId` 查询参数，保证向后兼容。

### Requirement: 错误提示
**现有实现**：仅展示通用错误信息。
**修改后**：区分网络错误、未授权、服务器返回空三种情况，并在错误卡片中提供“重试”按钮。

## REMOVED Requirements
无。
