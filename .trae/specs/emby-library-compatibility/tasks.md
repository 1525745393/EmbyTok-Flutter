# Emby 媒体库显示兼容修复 - 实现任务清单 (Tasks)

## [ ] Task 1: 统一 EmbytokService 中 API 端点路径为用户视图路径
- **Priority**: P0
- **Depends On**: None
- **Description**:
  - 在 `EmbytokService` 中为所有获取项目列表的方法添加 userId 参数，或统一使用内部保存的 `_defaultUserId` 构建路径
  - **修改的方法清单**:
    1. `getLibraries()`: 确保始终使用 `/Users/{userId}/Views`，移除 `/Library/VirtualFolders` 回退（若无 userId 则记录警告并使用 Views）
    2. `getLibraryItems()`: 路径从 `/Items` 改为 `/Users/{userId}/Items`，`IncludeItemTypes` 从 `Movie,Series,MusicVideo,Episode` 改为 `Movie,Episode,Video,MusicVideo`
    3. `getFavorites()`: 路径从 `/Items` 改为 `/Users/{userId}/Items`，`IncludeItemTypes` 添加 `Video`
    4. `getFavoriteMovies()`: 同上
    5. `getFavoriteBoxSets()`: 路径从 `/Items` 改为 `/Users/{userId}/Items`
    6. `getFavoritePeople()`: 路径从 `/Items` 改为 `/Users/{userId}/Items`
    7. `getRecentlyAdded()`: 路径从 `/Items/Latest` 改为 `/Users/{userId}/Items/Latest`（或保持 `/Items/Latest` 并添加 `UserId` 查询参数）
    8. `getPeople()`: 路径从 `/Persons` 改为 `/Users/{userId}/Items` 并使用 `IncludeItemTypes=Person`，或保持 `/Persons`
    9. `getItemsByGenre()`: 路径改为 `/Users/{userId}/Items`
    10. `getItemsByStudio()`: 路径改为 `/Users/{userId}/Items`
    11. `getItemDetail()`: 路径从 `/Items/{itemId}` 改为 `/Users/{userId}/Items/{itemId}`
    12. `searchItems()`: 路径从 `/Items` 改为 `/Users/{userId}/Items`
  - 注意：`getResumeItems()` 和 `getNextUp()` 以及 `getSeasons()`/`getEpisodes()` 已有正确的端点，保持不变
  - 为每个修改的方法添加 userId 回退逻辑：优先使用传入的 userId 参数，其次使用 `_defaultUserId`，最后回退到原路径并记录警告
- **Acceptance Criteria Addressed**: FR-1, FR-2, FR-3, FR-5, FR-6, FR-7, FR-9
- **Test Requirements**:
  - `programmatic` TR-1.1: `getLibraryItems()` 调用时，若 `_defaultUserId` 存在，请求路径应包含 `/Users/{userId}/Items`
  - `programmatic` TR-1.2: `getLibraryItems()` 的 `IncludeItemTypes` 参数应包含 `Video`
  - `programmatic` TR-1.3: `getLibraries()` 始终使用 `/Users/{userId}/Views` 路径
  - `programmatic` TR-1.4: 无 userId 时应有回退逻辑并记录警告，不应抛异常
  - `human-judgement` TR-1.5: 代码 reviewer 确认所有相关方法都已应用用户路径修改，且保持错误处理一致
- **Notes**: 修改范围集中在 `embbytok_service.dart`，无需修改 Provider 层

## [ ] Task 2: 验证 Library 模型的 CollectionType 支持
- **Priority**: P1
- **Depends On**: Task 1
- **Description**:
  - 检查 `Library` 模型的 `fromJson` 是否正确读取 `CollectionType` 字段
  - 若 `Library.type` 字段当前从 `CollectionType` 读取，确认其正确性（当前代码似乎从 `CollectionType` 映射）
  - 在媒体库列表 UI 中（如 `library_selector.dart`），确认不同 CollectionType 的库都能正常显示（movies/tvshows/homevideos/musicvideos）
- **Acceptance Criteria Addressed**: FR-8
- **Test Requirements**:
  - `programmatic` TR-2.1: `Library.fromJson` 能正确解析含 `CollectionType` 字段的 JSON
  - `human-judgement` TR-2.2: reviewer 确认媒体库列表中不同类型的库图标/名称显示正确
- **Notes**: 可能需要为不同 CollectionType 添加图标映射

## [ ] Task 3: 测试 Emby 服务器上的实际行为
- **Priority**: P0
- **Depends On**: Task 1, Task 2
- **Description**:
  - 在实际的 Emby 服务器上验证以下场景：
    1. 登录后媒体库列表数量与 EmbyX 一致
    2. Home Video 类型的库中能显示视频
    3. 收藏列表内容正确
    4. 最近添加列表正常显示
    5. 视频播放功能正常（包括播放上报）
  - 对比 EmbyX 中每个视图的条目数量
- **Acceptance Criteria Addressed**: AC-1, AC-2, AC-3, AC-4, AC-6
- **Test Requirements**:
  - `human-judgement` TR-3.1: 在测试设备上安装并对比 EmbyX，确认各视图内容一致
  - `human-judgement` TR-3.2: 播放测试：选择不同类型的视频播放，确认播放与上报正常
  - `programmatic` TR-3.3: `flutter analyze` 无新引入的错误或警告
  - `programmatic` TR-3.4: 构建 `flutter build apk --debug` 成功
- **Notes**: 若某端点在实际 Emby 服务器上返回空或错误，需针对性调整（可能某些端点不存在于用户路径，需要全局路径回退）

## [ ] Task 4: 代码清理与文档更新
- **Priority**: P2
- **Depends On**: Task 1, Task 2, Task 3
- **Description**:
  - 确保所有修改的方法有清晰的中文注释说明路径变更的原因
  - 验证 PRD 中的开放问题（Q1/Q2/Q3）是否需要在本次迭代中解决
  - 检查 `_ensureConfig` 中的 baseUrl 切换逻辑在新路径下是否正常
- **Acceptance Criteria Addressed**: G5 (向后兼容)
- **Test Requirements**:
  - `human-judgement` TR-4.1: 代码 reviewer 确认代码风格和注释符合项目规范
  - `programmatic` TR-4.2: 确保 `_ensureConfig` 对新路径的 baseUrl 切换正确
- **Notes**: 此 Task 为清理性质的工作，不引入新功能
