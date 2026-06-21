# 观看历史与 Emby 服务器对接修复 — The Implementation Plan

## [/] Task 1: 在 `getWatchHistory` 中添加 `IncludeItemTypes` 参数
- **Priority**: P0
- **Depends On**: None
- **Description**:
  - 在 `EmbytokService.getWatchHistory` 的 `params` Map 中新增键值 `'IncludeItemTypes': 'Movie,Episode,Video,MusicVideo,Series'`。
  - 插入位置建议在 `Fields` 之前或之后，保持与 `getLibraryItems`([L163-L173](file:///workspace/frontend/lib/services/embbytok_service.dart#L163-L173)) 的参数顺序风格一致。
  - 同时更新 `test/services/embbytok_service_test.dart` 中 `buildExpectedQueryParams`([L768-L784](file:///workspace/frontend/test/services/embbytok_service_test.dart#L768-L784)) 的期望参数，加入 `'IncludeItemTypes': 'Movie,Episode,Video,MusicVideo,Series'`。
- **Acceptance Criteria Addressed**: AC-1, AC-5
- **Test Requirements**:
  - `programmatic` TR-1.1: `getWatchHistory(userId: 'user-abc-123', ...)` 发起的请求 `queryParameters` 中含 `IncludeItemTypes=Movie,Episode,Video,MusicVideo,Series`。
  - `programmatic` TR-1.2: `getWatchHistory`（无 userId，降级路径）的请求参数中同样含 `IncludeItemTypes`。
  - `programmatic` TR-1.3: `buildExpectedQueryParams` 的新参数与实际实现一致，原有六个测试用例继续通过。
- **Notes**: 仅修改 params 构造，不改变 `path` 逻辑、`_defaultUserId` 逻辑或响应解析。

## [ ] Task 2: 在用户级路径下移除冗余 `UserId` 查询参数
- **Priority**: P1
- **Depends On**: None（可与 Task 1 并行或顺序执行）
- **Description**:
  - 修改 `EmbytokService.getWatchHistory` 的参数构建逻辑：将 `UserId` 字段的加入条件从"有效 `effectiveUserId` 非空"改为"仅当使用降级路径 `/Items` 且 `effectiveUserId` 非空"。
  - 参考同文件中 `getLibraryItems`([L175-L178](file:///workspace/frontend/lib/services/embbytok_service.dart#L175-L178))、`getItemDetail`([L209-L212](file:///workspace/frontend/lib/services/embbytok_service.dart#L209-L212)) 的模式：先决定 `path`，再根据是否走 `/Items` 路径决定是否附加 `UserId`。
  - 更新单元测试 `buildExpectedQueryParams`：区分用户级路径 / 降级路径两种期望，用户级路径下 `UserId` 不应出现在 params 中，降级路径下 `UserId` 应存在。
- **Acceptance Criteria Addressed**: AC-2, AC-5
- **Test Requirements**:
  - `programmatic` TR-2.1: 传入 `userId: 'user-abc-123'` 时，请求走 `/Users/user-abc-123/Items` 路径，且 `queryParameters` **不包含** `UserId` 键。
  - `programmatic` TR-2.2: `userId` 为 `null` 时，请求走 `/Items` 路径，且 `queryParameters` **包含** `UserId=<defaultUserId>`（若 `_defaultUserId` 有值）。
  - `programmatic` TR-2.3: 测试"空历史 / 网络错误 / 401 / 500"四个用例在新参数下继续通过。
- **Notes**: 代码结构建议：先计算 `effectiveUserId`，再计算 `path`，最后根据 `path` 是否以 `/Users/` 开头来决定是否在 `params` 中加入 `UserId`。

## [ ] Task 3: 消除 `load()` 重复调用
- **Priority**: P1
- **Depends On**: None
- **Description**:
  - 从 `WatchHistoryNotifier` 构造函数中移除 `load()` 调用（[L43](file:///workspace/frontend/lib/providers/watch_history_provider.dart#L43)），保留 `HistoryView.initState`([L26-L28](file:///workspace/frontend/lib/views/history_view.dart#L26-L28)) 的显式调用作为唯一加载入口。
  - 构造函数简化为：初始化 `_service` 和 `state`，不再触发网络请求。
  - `refresh()` 方法保持不变，作为手动刷新入口。
  - 无需新增单元测试，因为行为仅由"两次请求"变为"一次请求"，现有的状态转换测试逻辑仍然有效。
- **Acceptance Criteria Addressed**: AC-3, AC-4
- **Test Requirements**:
  - `programmatic` TR-3.1: 构建 `WatchHistoryNotifier` 实例时不立即发起网络请求（`state.isLoading` 仍为 `false`，直到手动调用 `load()`）。
  - `programmatic` TR-3.2: `load()` 被调用一次后，`state.isLoading` 正常切换为 `true` 并在完成后更新 `items`。
  - `human-judgment` TR-3.3: 进入观看历史页面时 AppLogger 中仅出现一条"观看历史加载成功/失败"日志记录。
- **Notes**: 此修改对已登录用户可减少一次无用网络请求；未登录用户因 `authProvider` 提前返回"尚未登录"，无网络影响。

## [ ] Task 4: 回归测试与分析
- **Priority**: P0
- **Depends On**: Task 1, Task 2, Task 3
- **Description**:
  - 运行 `flutter test test/services/embbytok_service_test.dart` 确认全部通过。
  - 运行 `flutter analyze` 确认无新增警告或错误。
  - 手动打开 App 进入"观看历史"页面，观察：未登录提示 / 空列表提示 / 错误重试 / 正常列表四种场景表现与修复前一致。
- **Acceptance Criteria Addressed**: AC-4, AC-5
- **Test Requirements**:
  - `programmatic` TR-4.1: `flutter test test/services/embbytok_service_test.dart` 全部通过，exit code 为 0。
  - `programmatic` TR-4.2: `flutter analyze` 无错误，exit code 为 0。
  - `human-judgment` TR-4.3: 人工操作下历史页面四种场景展示正确，无白屏或异常。
- **Notes**: 当前构建环境可能无 Flutter SDK，需在本地或 CI 环境执行。
