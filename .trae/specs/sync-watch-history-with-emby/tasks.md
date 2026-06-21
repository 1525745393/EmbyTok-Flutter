# Tasks

- [x] Task 1: 修复 `getWatchHistory` API 调用路径与参数
  - [x] SubTask 1.1: 在 `EmbytokService.getWatchHistory` 中新增 `userId` 参数
  - [x] SubTask 1.2: 优先使用 `/Users/{userId}/Items` 路径；userId 为空时降级到 `/Items?UserId=...`
  - [x] SubTask 1.3: 保留 `Filters=IsResumable` 与 `SortBy=DatePlayed` 参数
  - [x] SubTask 1.4: 确保 `WatchHistoryNotifier.load()` 从 `authProvider` 读取 userId 并传入

- [x] Task 2: 增强 `HistoryView` 状态展示
  - [x] SubTask 2.1: 在未登录时展示“尚未登录”空状态
  - [x] SubTask 2.2: 在请求失败时展示区分错误类型的 ErrorStateCard
  - [x] SubTask 2.3: 空列表时保持现有 `EmptyStateCard.noHistory()`

- [x] Task 3: 编写单元测试验证历史拉取
  - [x] SubTask 3.1: 测试 `getWatchHistory` 使用 `/Users/{userId}/Items` 路径
  - [x] SubTask 3.2: 测试返回数据解析为 `MediaItem` 列表
  - [x] SubTask 3.3: 测试 userId 为空时降级路径
  - [x] SubTask 3.4: 测试网络错误/401/空列表三种边界

- [ ] Task 4: 回归验证
  - [ ] SubTask 4.1: 运行 `flutter test`（当前环境无 Flutter SDK，请在本地/CI 执行验证）
  - [ ] SubTask 4.2: 运行 `flutter analyze`（当前环境无 Flutter SDK，请在本地/CI 执行验证）
  - [x] SubTask 4.3: 手动检查 `HistoryView` 在登录/未登录/空数据下的表现

# Task Dependencies
- Task 2 依赖 Task 1
- Task 3 可并行于 Task 2
- Task 4 依赖 Task 1、Task 2、Task 3
