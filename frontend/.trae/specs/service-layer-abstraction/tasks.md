# 服务层抽象与依赖注入 - The Implementation Plan (Decomposed and Prioritized Task List)

## [ ] Task 1: 定义 MediaServerApi 接口与 ServerType 枚举
- **Priority**: high
- **Depends On**: None
- **Description**:
  - 在 `lib/services/` 下创建 `media_server_api.dart`，定义 `MediaServerApi` 抽象接口
  - 在 `lib/models/` 下创建 `server_type.dart`，定义 `ServerType` 枚举
  - 接口方法按功能分组：认证与用户、媒体库、播放信息、收藏、播放上报、搜索、其他
  - 每个方法添加中文文档注释，说明用途、参数含义和返回值
- **Acceptance Criteria Addressed**: AC-1, AC-5
- **Test Requirements**:
  - `programmatic` TR-1.1: 静态分析验证接口所有方法的签名与 EmbytokService 对应方法一致（参数类型、返回类型、命名）
  - `programmatic` TR-1.2: ServerType 枚举包含 emby、jellyfin、plex 三个值
  - `human-judgement` TR-1.3: 接口方法分组合理，注释清晰，每个方法都有中文文档
- **Notes**: 接口定义是后续所有工作的基础，必须确保完整性和准确性。建议先完整梳理 EmbytokService 的所有公共方法。

## [ ] Task 2: 迁移认证与用户相关 API 到 EmbyServerApi
- **Priority**: high
- **Depends On**: Task 1
- **Description**:
  - 创建 `lib/services/emby_server_api.dart`，实现 `EmbyServerApi` 类
  - 实现 `MediaServerApi` 接口中的认证与用户相关方法：login、getLibraries、getUserViews 等
  - 内部使用 `ApiClient` 进行 HTTP 请求，保持与现有 EmbytokService 完全一致的请求逻辑
  - 添加单元测试验证请求参数、URL 格式、Header 等与原实现一致
- **Acceptance Criteria Addressed**: AC-1, AC-2, AC-5
- **Test Requirements**:
  - `programmatic` TR-2.1: login 方法的请求 URL、参数、Header 与原实现完全一致
  - `programmatic` TR-2.2: getLibraries 和 getUserViews 方法的请求参数与返回值解析正确
  - `human-judgement` TR-2.3: 代码风格与现有项目一致，注释清晰

## [ ] Task 3: 迁移媒体列表与详情相关 API 到 EmbyServerApi
- **Priority**: high
- **Depends On**: Task 2
- **Description**:
  - 实现 getLibraryItems、getItemDetail、getResumeItems、getRecommendations、getSuggestions、getNextUp、getRecentlyAdded、getSimilarItems 等方法
  - 实现 getSeasons、getEpisodes、getTrailers、getChildren 等剧集/合集相关方法
  - 实现 getGenres、getItemsByGenre、getStudios、getItemsByStudio 等分类相关方法
  - 实现 getPeople、getPersonItems、getPersonDetail 等人员相关方法
- **Acceptance Criteria Addressed**: AC-1, AC-2
- **Test Requirements**:
  - `programmatic` TR-3.1: getLibraryItems 的分页参数、排序参数、过滤参数传递正确
  - `programmatic` TR-3.2: getItemDetail 返回的 MediaItem 字段完整
  - `programmatic` TR-3.3: 所有列表方法的返回值解析正确（PaginatedResponse、List 等）

## [ ] Task 4: 迁移收藏、播放状态与搜索相关 API
- **Priority**: high
- **Depends On**: Task 3
- **Description**:
  - 实现收藏相关：getFavorites、getFavoriteMovies、getFavoriteBoxSets、getFavoritePeople、toggleFavorite
  - 实现播放状态：getPlaybackInfo、getSubtitleCues、getSubtitleCuesFromFile、markAsPlayed、markAsUnplayed
  - 实现搜索相关：searchHints、searchItems、searchPersons
  - 实现观看历史：getWatchHistory
- **Acceptance Criteria Addressed**: AC-1, AC-2
- **Test Requirements**:
  - `programmatic` TR-4.1: toggleFavorite 的 HTTP 方法（POST/DELETE）和 URL 正确
  - `programmatic` TR-4.2: getPlaybackInfo 的参数传递正确，返回 MediaSource 解析正确
  - `programmatic` TR-4.3: searchHints 返回的 SearchHint 列表解析正确

## [ ] Task 5: 迁移播放上报、云同步与其他 API
- **Priority**: medium
- **Depends On**: Task 4
- **Description**:
  - 实现播放上报相关：reportCapabilities、reportPlaybackStart、reportPlaybackPosition、reportPlaybackStopped
  - 实现云同步相关：saveCloudSync、checkCloudSync
  - 实现其他：deleteItem、postRaw、deleteRaw
  - 确保 EmbyServerApi 完整实现了 MediaServerApi 接口的所有方法
- **Acceptance Criteria Addressed**: AC-1, AC-2
- **Test Requirements**:
  - `programmatic` TR-5.1: 播放上报的三个方法请求参数正确
  - `programmatic` TR-5.2: EmbyServerApi 没有未实现的接口方法（静态分析检查）

## [ ] Task 6: 重构 EmbytokService 为业务门面，依赖 MediaServerApi 接口
- **Priority**: high
- **Depends On**: Task 5
- **Description**:
  - EmbytokService 内部持有 `MediaServerApi` 实例，通过构造函数注入
  - 移除 EmbytokService 中所有直接的 Dio/ApiClient 调用，改为委托给 `_api`
  - 保留纯业务逻辑方法（如字幕解析缓存、播放重试逻辑等）
  - 提供默认构造函数，默认使用 EmbyServerApi 实现，确保向后兼容
  - 保留 `withClient` 命名构造函数，用于测试注入
- **Acceptance Criteria Addressed**: AC-2, AC-3
- **Test Requirements**:
  - `programmatic` TR-6.1: 所有现有单元测试无需修改即可通过
  - `programmatic` TR-6.2: EmbytokService 构造函数支持注入自定义 MediaServerApi
  - `human-judgement` TR-6.3: EmbytokService 文件中不再有直接的 Dio 或 ApiClient 调用

## [ ] Task 7: 建立 Provider 依赖注入体系
- **Priority**: high
- **Depends On**: Task 6
- **Description**:
  - 创建 `mediaServerApiProvider`，默认返回 EmbyServerApi 实例
  - 修改 `embytokServiceProvider`，从 `mediaServerApiProvider` 获取适配层实例
  - 在 `providers.dart` 中导出新的 Provider
  - 验证 override 机制正常工作（测试中可替换为 Mock）
- **Acceptance Criteria Addressed**: AC-3, AC-4
- **Test Requirements**:
  - `programmatic` TR-7.1: embytokServiceProvider 能正确获取 MediaServerApi 实例
  - `programmatic` TR-7.2: 通过 ProviderScope.overrides 替换 mediaServerApiProvider 后，EmbytokService 使用 Mock 实例
  - `programmatic` TR-7.3: 所有使用 embytokServiceProvider 的现有测试仍然通过

## [ ] Task 8: 代码审查与优化
- **Priority**: medium
- **Depends On**: Task 7
- **Description**:
  - 检查所有文件大小，超过 500 行的考虑进一步拆分
  - 检查代码注释完整性
  - 检查命名一致性
  - 运行 flutter analyze 确保无静态警告
  - 运行完整测试套件确保全量通过
- **Acceptance Criteria Addressed**: AC-5, AC-6
- **Test Requirements**:
  - `programmatic` TR-8.1: flutter analyze 无错误、无警告
  - `programmatic` TR-8.2: 所有单元测试和集成测试通过
  - `human-judgement` TR-8.3: 代码结构清晰，职责划分合理，符合项目规范
