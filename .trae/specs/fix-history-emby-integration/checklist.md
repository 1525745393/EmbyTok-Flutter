# 观看历史与 Emby 服务器对接修复 — Verification Checklist

- [x] Checkpoint 1: `EmbytokService.getWatchHistory` 的 `params` 中包含 `IncludeItemTypes: 'Movie,Episode,Video,MusicVideo,Series'`。
- [x] Checkpoint 2: 传入有效 `userId` 时，`getWatchHistory` 的请求路径为 `/Users/{userId}/Items`，且 `queryParameters` 中**不含** `UserId` 字段。
- [x] Checkpoint 3: `effectiveUserId`（`userId ?? _defaultUserId`）为空时，`getWatchHistory` 走降级路径 `/Items`，且 `queryParameters` 中**包含** `UserId`；`_defaultUserId` 存在时走用户级路径 `/Users/{_defaultUserId}/Items` 且不含 `UserId`。级联逻辑正确。
- [x] Checkpoint 4: `getWatchHistory` 的 `Limit`、`Recursive`、`SortBy`、`SortOrder`、`Fields` 五个现有参数保持不变。
- [x] Checkpoint 5: `WatchHistoryNotifier` 构造函数不再调用 `load()`；`state` 的初始值仍为 `WatchHistoryState(items: [], isLoading: false, error: null)`。
- [x] Checkpoint 6: `HistoryView.initState` 中的 `addPostFrameCallback` → `load()` 调用保留为唯一的自动加载入口。
- [x] Checkpoint 7: `test/services/embbytok_service_test.dart` 中 `buildExpectedQueryParams` 的期望参数已同步更新（增加 `IncludeItemTypes`，移除无条件 `UserId`）。
- [ ] Checkpoint 8: `flutter test test/services/embbytok_service_test.dart` 运行通过，`getWatchHistory` 组下的六个测试用例全部 green。（需本地/CI 环境执行）
- [ ] Checkpoint 9: `flutter analyze` 无新增错误或警告。（需本地/CI 环境执行）
- [ ] Checkpoint 10: 手动操作验证 —— 未登录进入"观看历史"页面显示"尚未登录"提示，不发起网络请求。（需本地/CI 环境执行）
- [ ] Checkpoint 11: 手动操作验证 —— 已登录且 Emby 返回空列表时显示 `EmptyStateCard.noHistory()`。（需本地/CI 环境执行）
- [ ] Checkpoint 12: 手动操作验证 —— 已登录且 Emby 返回正常数据时显示历史列表，AppLogger 中仅记录一次"观看历史加载成功"。（需本地/CI 环境执行）
- [ ] Checkpoint 13: 手动操作验证 —— 模拟网络错误 / 500 响应时显示可重试的错误卡片，点击重试后重新发起请求且状态正常切换。（需本地/CI 环境执行）
- [x] Checkpoint 14: 代码风格检查 —— `getWatchHistory` 的 `effectiveUserId → path → params` 流程模式与 `getLibraryItems`、`getItemDetail`、`getRecentlyAdded` 保持一致；在降级路径下附加 `UserId` 是相比 `getLibraryItems` 更完善的补充。
