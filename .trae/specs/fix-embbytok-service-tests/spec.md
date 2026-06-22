# 修正 EmbytokService 测试文件 Spec

## Why
`frontend/test/services/embbytok_service_test.dart` 中大量测试仍基于旧后端代理接口（如 `/api/auth/login`、`/api/libraries`、`/api/progress/*`），而当前 `EmbytokService` 已改为直接调用 Emby 原生 API（如 `/Users/AuthenticateByName`、`/Users/{userId}/Views`、`/UserPlayedItems/{id}`）。这导致测试方法签名、mock 路径、请求/响应字段均与实际实现不匹配，运行 `flutter test` 会批量失败。

## What Changes
- 修正测试中对 `EmbytokService` 的方法调用签名，匹配当前实现
- 修正所有 Dio mock 路径为 Emby 原生端点
- 修正请求/响应字段为 Emby PascalCase 格式
- 删除已移除方法（`getItem`、`getPlaybackUrl`、`search`、`saveProgress`、`getProgress`）的旧测试，或迁移到对应的新方法/行为
- 保留并修正 `toggleFavorite`、`getFavorites` 等仍有效方法的测试
- 确保 `getWatchHistory` 新增测试与修正后的测试文件风格一致

## Impact
- 受影响代码：
  - [frontend/test/services/embbytok_service_test.dart](file:///workspace/frontend/test/services/embbytok_service_test.dart)
- 不影响业务代码

## ADDED Requirements
### Requirement: 测试与实际实现一致
The system SHALL 保证 `embbytok_service_test.dart` 中所有测试用例的调用方式、mock 路径、字段命名与当前 `EmbytokService` 实现一致。

#### Scenario: 运行全量测试
- **GIVEN** 当前 `EmbytokService` 实现
- **WHEN** 执行 `flutter test test/services/embbytok_service_test.dart`
- **THEN** 所有测试通过，无因接口不匹配导致的失败

## MODIFIED Requirements
### Requirement: 测试方法签名
**现有实现**：测试调用 `service.login(testEmbyUrl, testBackendUrl, username, password)`、`service.getItem(...)`、`service.getPlaybackUrl(...)`、`service.search(...)`、`service.saveProgress(...)`、`service.getProgress(...)` 等已不存在或签名已变更的方法。
**修改后**：测试使用 `service.login(embyServerUrl: ..., username: ..., password: ...)`、`service.getItemDetail(...)`、`service.searchItems(...)`、`service.markAsPlayed(...)` 等当前实际存在的方法。

### Requirement: Mock 端点
**现有实现**：mock 路径为 `/api/auth/login`、`/api/libraries`、`/api/libraries/{id}/items`、`/api/items/{id}`、`/api/search`、`/api/favorites`、`/api/progress/{id}`。
**修改后**：mock 路径改为 `/Users/AuthenticateByName`、`/Users/{userId}/Views`、`/Users/{userId}/Items`、`/Users/{userId}/Items/{id}`、`/Search/Hints`、`/Items`、`/UserPlayedItems/{id}` 等 Emby 原生端点。

## REMOVED Requirements
无。
