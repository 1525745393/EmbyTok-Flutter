# 观看历史与 Emby 服务器对接修复 — Product Requirement Document

## Overview
- **Summary**: 修复 `EmbytokService.getWatchHistory` 与 `WatchHistoryNotifier` 中存在的三个小问题：(1) 历史请求缺少 `IncludeItemTypes` 过滤导致可能混入非视频条目；(2) 用户级路径 `/Users/{userId}/Items` 下冗余附加 `UserId` 查询参数；(3) `WatchHistoryNotifier` 构造函数与 `HistoryView.initState` 均调用 `load()` 导致首次加载产生重复请求。
- **Purpose**: 提升观看历史页面的稳定性与 API 请求效率，防止非视频类型条目污染历史列表，消除冗余的用户标识参数与网络请求。
- **Target Users**: 使用观看历史页面的全部用户。

## Goals
- **Goal 1**: `getWatchHistory` 返回结果仅包含视频类型条目（Movie/Episode/Video/MusicVideo/Series），与 `getLibraryItems`、`getRecentlyAdded` 保持一致。
- **Goal 2**: `getWatchHistory` 在用户级路径下不再附加冗余 `UserId` 查询参数，仅在降级到全局 `/Items` 路径时附加，与 `getLibraryItems` 等方法的模式保持一致。
- **Goal 3**: 进入观看历史页面时仅发起一次 `getWatchHistory` 请求，消除构造函数与 `initState` 导致的重复调用。
- **Goal 4**: 修复不改变现有对外 API（方法签名、返回类型、Provider 接口），行为差异仅体现为"返回条目类型更准确"与"请求次数减一"。

## Non-Goals (Out of Scope)
- 不修改其他方法的实现（如 `getLibraryItems`、`getRecentlyAdded`、`getFavoriteMovies` 等已正确使用 `IncludeItemTypes` 的方法）。
- 不引入分页能力（`StartIndex`），留待后续独立迭代。
- 不修改 `MediaItem.fromJson` 的解析逻辑或字段映射。
- 不修改 `HistoryView` 的 UI 展示样式（空状态/错误状态/列表卡片外观不变）。

## Background & Context
- 当前 `EmbytokService` 中，`getLibraryItems`([L172](file:///workspace/frontend/lib/services/embbytok_service.dart#L172))、`getRecentlyAdded`([L295](file:///workspace/frontend/lib/services/embbytok_service.dart#L295))、`getFavoriteMovies`([L589](file:///workspace/frontend/lib/services/embbytok_service.dart#L589))、`searchItems`([L1128](file:///workspace/frontend/lib/services/embbytok_service.dart#L1128)) 均在 `params` 中显式声明 `IncludeItemTypes: 'Movie,Episode,Video,MusicVideo,Series'`，仅 `getWatchHistory` 缺失，可能导致 Emby 返回非视频条目（如文件夹、艺人、音乐专辑等）。
- `getWatchHistory` 在构建 `params` 时无条件附加 `UserId=effectiveUserId`，但用户级路径 `/Users/{userId}/Items` 本身已带用户上下文，无需重复传递；仅当降级到全局 `/Items` 路径时才需要 `UserId` 参数以标识查询对象。`getLibraryItems`([L175-L178](file:///workspace/frontend/lib/services/embbytok_service.dart#L175-L178))、`getItemDetail`([L209-L212](file:///workspace/frontend/lib/services/embbytok_service.dart#L209-L212)) 等方法均遵循后者模式。
- `WatchHistoryNotifier` 在构造函数中调用 `load()`（[L43](file:///workspace/frontend/lib/providers/watch_history_provider.dart#L43)），同时 `HistoryView.initState` 也通过 `addPostFrameCallback` 再次调用 `load()`（[L26-L28](file:///workspace/frontend/lib/views/history_view.dart#L26-L28)）。由于 `watchHistoryProvider` 使用 `StateNotifierProvider`，每次进入页面都会创建新的 Notifier 实例，导致第一帧发起两次 API 请求，第二次请求虽无害但浪费网络资源且日志产生重复条目。
- 现有单元测试 `embbytok_service_test.dart`([L747-L920](file:///workspace/frontend/test/services/embbytok_service_test.dart#L747-L920)) 已覆盖 `getWatchHistory` 的六种场景，修复后需要同步更新期望的查询参数断言。

## Functional Requirements
- **FR-1**: `EmbytokService.getWatchHistory` 在请求参数中加入 `IncludeItemTypes: 'Movie,Episode,Video,MusicVideo,Series'`，与 `getLibraryItems` 保持一致。
- **FR-2**: `EmbytokService.getWatchHistory` 仅在使用降级路径 `/Items` 时在 `params` 中附加 `UserId`；使用用户级路径 `/Users/{userId}/Items` 时不再附加 `UserId`。
- **FR-3**: `WatchHistoryNotifier` 构造函数中移除对 `load()` 的调用，仅保留 `HistoryView.initState` 中的 `load()` 调用作为单一加载入口。或采取反向策略：保留构造函数调用，移除 `initState` 调用。两者任选其一，目标是首次进入页面仅发起一次请求。
- **FR-4**: 所有相关单元测试的期望参数断言需更新以匹配新的 `params`（增加 `IncludeItemTypes`、移除用户级路径下的 `UserId`）。

## Non-Functional Requirements
- **NFR-1 向后兼容**: 修复后 `getWatchHistory` 的方法签名与返回值类型不变，仅缩小返回结果范围并微调查询参数；调用方代码（`WatchHistoryNotifier.load`、`HistoryView`）无需改动。
- **NFR-2 请求次数**: 进入观看历史页面时，AppLogger 中仅记录一条"观看历史加载成功"或"加载观看历史失败"日志，不再重复。
- **NFR-3 测试完整性**: 所有现有测试（包括 `getWatchHistory` 组下的六个测试）在修复后应继续通过，且新增/更新的断言需与新参数规范一致。
- **NFR-4 代码一致性**: 参数构造模式与 `getLibraryItems`、`getItemDetail`、`getRecentlyAdded` 保持一致，便于后续维护与代码阅读。

## Constraints
- **Technical**: Flutter/Dart 项目，测试框架为 `flutter_test` + `mockito`/自定义 `dio` adapter（当前使用的是自定义 `dioAdapter`）。
- **Business**: 修复需保持零破坏性变更，不得改变 `watchHistoryProvider` 对外暴露的状态结构。
- **Dependencies**: 无外部依赖变更。

## Assumptions
- Emby 服务器的 `/Items` 端点在未指定 `IncludeItemTypes` 时会返回所有类型的条目（含非视频）。此假设基于对 Emby API 行为的通用理解及同文件其他方法均显式指定 `IncludeItemTypes` 的事实。
- `/Users/{userId}/Items` 路径本身已隐式绑定用户上下文，附加 `UserId=userId` 在大多数 Emby 版本上无害但冗余。
- `StateNotifierProvider` 每次页面构建都会创建新 Notifier 实例，因此构造函数内的 `load()` 与 `initState` 内的 `load()` 在每次进入页面时都会执行一次。

## Acceptance Criteria

### AC-1: `getWatchHistory` 附加 `IncludeItemTypes` 参数
- **Given**: 用户已登录并进入观看历史页面，`WatchHistoryNotifier.load()` 调用 `getWatchHistory(userId: 'xxx', ...)`。
- **When**: `getWatchHistory` 构造并发送 HTTP GET 请求。
- **Then**: 请求查询参数包含 `IncludeItemTypes=Movie,Episode,Video,MusicVideo,Series`；其他已有参数（`Limit`、`Recursive`、`SortBy`、`SortOrder`、`Fields`）保持不变。
- **Verification**: `programmatic`
- **Notes**: 单元测试 `buildExpectedQueryParams` 期望需同步更新。

### AC-2: 用户级路径不再冗余附加 `UserId`
- **Given**: `getWatchHistory` 调用时 `userId` 非空（如 `user-abc-123`）。
- **When**: 构造请求路径与查询参数。
- **Then**: 使用路径 `/Users/user-abc-123/Items`，且 `params` 中**不包含** `UserId` 字段；当 `userId` 为空时，使用路径 `/Items` 且 `params` 中**包含** `UserId=effectiveUserId`（若 `_defaultUserId` 存在）。
- **Verification**: `programmatic`

### AC-3: 进入观看历史页面仅发起一次请求
- **Given**: 用户已登录。
- **When**: 首次打开观看历史页面。
- **Then**: 仅向 Emby 发起一次 `GET /Users/{userId}/Items`（或降级的 `/Items`）请求，AppLogger 中仅记录一次"观看历史加载成功/失败"日志。
- **Verification**: `programmatic`（通过日志计数或网络请求计数）
- **Notes**: 移除构造函数中的 `load()` 调用保留 `initState` 调用，或反之。

### AC-4: 空历史 / 错误 / 未登录行为不变
- **Given**: 用户处于未登录、Emby 返回空列表或返回 500 错误的场景。
- **When**: 进入观看历史页面。
- **Then**: `HistoryView` 的 UI 展示逻辑与修复前一致：未登录显示"尚未登录"，空列表显示 `EmptyStateCard.noHistory()`，错误显示可重试的错误卡片。
- **Verification**: `human-judgment`

### AC-5: 单元测试全部通过
- **Given**: 修复后的代码与更新后的单元测试。
- **When**: 运行 `flutter test test/services/embbytok_service_test.dart`。
- **Then**: `getWatchHistory` 测试组下的全部六个测试用例通过，断言检查参数已更新为新规范。
- **Verification**: `programmatic`

## Open Questions
- [ ] 确认是否有 Emby 服务器版本在用户级路径下仍要求 `UserId` 查询参数才能正确返回数据（此情况目前未在任何文档中提及，若存在需回滚此项修复）。
- [ ] 对于"首次加载仅一次请求"的修复方向（保留 `initState` / 保留构造函数）是否有偏好？当前默认保留 `initState` 的调用，因为它是显式的 UI 驱动加载入口，语义更清晰。
