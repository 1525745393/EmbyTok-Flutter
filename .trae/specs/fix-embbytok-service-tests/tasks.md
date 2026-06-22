# Tasks

- [x] Task 1: 审查当前测试文件与实现的不匹配项
  - [x] SubTask 1.1: 列出测试中调用的所有不存在或签名已变更的方法
  - [x] SubTask 1.2: 列出所有需要替换的旧后端 mock 路径
  - [x] SubTask 1.3: 确认响应字段需从 snake_case 改为 PascalCase 的位置

- [x] Task 2: 修正登录相关测试
  - [x] SubTask 2.1: 将 `service.login(...)` 改为命名参数调用
  - [x] SubTask 2.2: 将 mock 路径改为 `/Users/AuthenticateByName`
  - [x] SubTask 2.3: 将响应字段改为 Emby 原生结构（`User`、`AccessToken` 等）

- [x] Task 3: 修正媒体库/视频列表/详情/搜索测试
  - [x] SubTask 3.1: 修正 `getLibraries` 测试的 mock 路径为 `/Users/{userId}/Views`
  - [x] SubTask 3.2: 修正 `getLibraryItems` 测试的 mock 路径为 `/Users/{userId}/Items`
  - [x] SubTask 3.3: 将 `getItem` 测试迁移到 `getItemDetail` 并修正路径
  - [x] SubTask 3.4: 将 `getPlaybackUrl` 测试迁移到 `getPlaybackInfo` 或直接删除
  - [x] SubTask 3.5: 将 `search` 测试迁移到 `searchItems` 并修正路径与字段

- [x] Task 4: 修正收藏与播放进度测试
  - [x] SubTask 4.1: 修正 `toggleFavorite` 测试的 mock 路径为 `/Users/{userId}/FavoriteItems/{id}`
  - [x] SubTask 4.2: 修正 `getFavorites` 测试的 mock 路径为 `/Items` 或 `/Users/{userId}/Items`
  - [x] SubTask 4.3: 将 `saveProgress` 与 `getProgress` 测试迁移到 `markAsPlayed` / `markAsUnplayed` 或直接删除

- [x] Task 5: 统一测试风格并验证
  - [x] SubTask 5.1: 确保常量命名、helper 函数与 `getWatchHistory` 新增测试风格一致
  - [ ] SubTask 5.2: 在本地/CI 运行 `flutter test test/services/embbytok_service_test.dart`（当前环境无 Flutter SDK）
  - [ ] SubTask 5.3: 运行 `flutter analyze` 确保无新增问题（当前环境无 Flutter SDK）

# Task Dependencies
- Task 2 依赖 Task 1
- Task 3 依赖 Task 1
- Task 4 依赖 Task 1
- Task 5 依赖 Task 2、Task 3、Task 4
