# Emby 服务器 API 适配度修复 - 任务实施计划

## Task 1: 在 Fields 中加入 MediaStreams + UserId 参数
- **Priority**: P0
- **Depends On**: None
- **Description**:
  - 遍历 `embbytok_service.dart` 中所有 `getLibraryItems` / `getItemDetail` / `getResumeItems` / `getNextUp` / `getRecentlyAdded` / `getSimilarItems` / `getPersonItems` / `getItemsByGenre` / `getItemsByStudio` / `getFavorites` / `getFavoriteMovies` / `getFavoriteBoxSets` / `getFavoritePeople` / `getWatchHistory` / `searchItems` 方法
  - 每个方法的 `'Fields'` 查询参数末尾添加 `,MediaStreams`
  - 同时在 `/Items` 回退路径上，当有 userId 时添加 `UserId` 查询参数
- **Acceptance Criteria Addressed**: AC-1, AC-5
- **Test Requirements**:
  - `programmatic` TR-1.1: 所有列表查询的 Fields 参数值中包含 "MediaStreams"
  - `programmatic` TR-1.2: 走 `/Items` 路径时参数值中包含 `UserId`
  - `programmatic` TR-1.3: `flutter analyze --no-pub lib` 输出 0 errors
- **Notes**: 精确的字段匹配不区分大小写（Emby 对 Fields 值大小写不敏感），但建议保持与其他字段一致的 PascalCase 格式

## Task 2: 播放进度上报精度（秒 → 毫秒）
- **Priority**: P0
- **Depends On**: None
- **Description**:
  - `video_page_item.dart` L297: `(position?.inSeconds ?? 0) * 10000000` → `(position?.inMilliseconds ?? 0) * 10000`
  - `video_page_item.dart` L320: 同样的修改
  - `embbytok_service.dart` L917: `reportPlaybackStart` 方法增加可选 `positionTicks` 参数（默认为 0），在 body 中使用
  - `video_page_item.dart` 中调用 `_reportPlaybackStart` 时传入当前续播位置（`widget.item.userData?.playbackPositionTicks` 若非空）
- **Acceptance Criteria Addressed**: AC-2
- **Test Requirements**:
  - `programmatic` TR-2.1: `_reportPlaybackProgress` 使用 `inMilliseconds * 10000` 计算
  - `programmatic` TR-2.2: `_reportPlaybackStopped` 使用 `inMilliseconds * 10000` 计算
  - `programmatic` TR-2.3: `reportPlaybackStart` 支持可选 `positionTicks` 参数

## Task 3: 字幕 Cues 时长上限修复
- **Priority**: P1
- **Depends On**: None
- **Description**:
  - `embbytok_service.dart` 的 `getSubtitleCues` 增加 `int? startPositionTicks` 和 `int? endPositionTicks` 参数
  - URL 构造中使用传入值；未传入时默认 `start=0` 和 `end=36000000000` 保持兼容
  - 找到所有调用 `getSubtitleCues` 的位置，传入 `widget.item.runtimeTicks`（如果非空）作为 `endPositionTicks`
- **Acceptance Criteria Addressed**: AC-3
- **Test Requirements**:
  - `programmatic` TR-3.1: `getSubtitleCues` 签名支持 `startPositionTicks` 和 `endPositionTicks`
  - `programmatic` TR-3.2: URL 使用传入的 ticks 值而非硬编码 1 小时

## Task 4: 动态 DeviceId
- **Priority**: P1
- **Depends On**: None
- **Description**:
  - `api_client.dart` 的 `_clientAuthorization` 改为 `String? _clientAuthorization` 字段（可 null）
  - 新增方法 `void updateAuthorization({required String deviceId, String client = 'EmbyTok', String version = '1.0.0'})`
  - 在 `EmbytokService.setupAuth` 中调用 `_apiClient.updateAuthorization(deviceId: ...)` 并基于 `userId` + `embyServerUrl` 生成稳定的 deviceId（如 `embbytok-{first 8 chars of hash}`）
  - 未登录时 `_clientAuthorization` 默认使用 `'MediaBrowser Client="EmbyTok", Device="Mobile", DeviceId="embbytok-client", Version="1.0.0"'`
- **Acceptance Criteria Addressed**: AC-4
- **Test Requirements**:
  - `programmatic` TR-4.1: `ApiClient` 有可配置 DeviceId 的接口
  - `programmatic` TR-4.2: `EmbytokService.setupAuth` 调用了新接口
  - `programmatic` TR-4.3: 生成的 DeviceId 稳定且基于 userId+serverUrl

## Task 5: 静态分析验证
- **Priority**: P0
- **Depends On**: Task 1-4
- **Description**:
  - 运行 `flutter analyze --no-pub lib` 确保 0 errors
- **Acceptance Criteria Addressed**: AC-6
- **Test Requirements**:
  - `programmatic` TR-5.1: `flutter analyze --no-pub lib` 输出 "0 errors"
