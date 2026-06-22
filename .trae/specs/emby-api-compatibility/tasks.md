# Emby 服务器 API 适配度修复 - 任务实施计划

## [x] Task 1: 在 Fields 中加入 MediaStreams + UserId 参数
- **Priority**: P0
- **Depends On**: None
- **Description**:
  - 遍历 `embbytok_service.dart` 中所有 `getLibraryItems` / `getItemDetail` / `getResumeItems` / `getNextUp` / `getRecentlyAdded` / `getSimilarItems` / `getPersonItems` / `getItemsByGenre` / `getItemsByStudio` / `getFavorites` / `getFavoriteMovies` / `getFavoriteBoxSets` / `getFavoritePeople` / `getWatchHistory` / `searchItems` 方法
  - 每个方法的 `'Fields'` 查询参数末尾添加 `,MediaStreams`
  - 同时在 `/Items` 回退路径上，当有 userId 时添加 `UserId` 查询参数
- **Acceptance Criteria Addressed**: AC-1, AC-5
- **Test Requirements**:
  - `programmatic` TR-1.1: 所有列表查询的 Fields 参数值中包含 "MediaStreams" ✅（共 15 处）
  - `programmatic` TR-1.2: 走 `/Items` 路径时参数值中包含 `UserId` ✅（共 8 处）
  - `programmatic` TR-1.3: Dart format 验证通过 ✅
- **Notes**: 已完成并验证

## [x] Task 2: 播放进度上报精度（秒 → 毫秒）
- **Priority**: P0
- **Depends On**: None
- **Description**:
  - `video_page_item.dart` L297: `(position?.inSeconds ?? 0) * 10000000` → `(position?.inMilliseconds ?? 0) * 10000`
  - `video_page_item.dart` L320: 同样的修改
  - `embbytok_service.dart` L917: `reportPlaybackStart` 方法增加可选 `positionTicks` 参数（默认为 0），在 body 中使用
  - `video_page_item.dart` 中调用 `_reportPlaybackStart` 时传入当前续播位置（`widget.item.userData?.playbackPositionTicks` 若非空）
- **Acceptance Criteria Addressed**: AC-2
- **Test Requirements**:
  - `programmatic` TR-2.1: `_reportPlaybackProgress` 使用 `inMilliseconds * 10000` 计算 ✅
  - `programmatic` TR-2.2: `_reportPlaybackStopped` 使用 `inMilliseconds * 10000` 计算 ✅
  - `programmatic` TR-2.3: `reportPlaybackStart` 支持可选 `positionTicks` 参数 ✅
- **Notes**: 已完成并验证

## [x] Task 3: 字幕 Cues 时长上限修复
- **Priority**: P1
- **Depends On**: None
- **Description**:
  - `embbytok_service.dart` 的 `getSubtitleCues` 增加 `int? startPositionTicks` 和 `int? endPositionTicks` 参数
  - URL 构造中使用传入值；未传入时默认 `start=0` 和 `end=36000000000` 保持兼容
  - 找到所有调用 `getSubtitleCues` 的位置，传入 `widget.item.runtimeTicks`（如果非空）作为 `endPositionTicks`
- **Acceptance Criteria Addressed**: AC-3
- **Test Requirements**:
  - `programmatic` TR-3.1: `getSubtitleCues` 签名支持 `startPositionTicks` 和 `endPositionTicks` ✅
  - `programmatic` TR-3.2: URL 使用传入的 ticks 值而非硬编码 1 小时 ✅
- **Notes**: 已完成并验证

## [x] Task 4: 动态 DeviceId
- **Priority**: P1
- **Depends On**: None
- **Description**:
  - `api_client.dart` 的 `_clientAuthorization` 改为动态 `_deviceId` 字段
  - 新增方法 `void setDeviceId(String deviceId)`
  - 在 `EmbytokService.setupAuth` 中调用 `_apiClient.setDeviceId()` 并基于 `userId` + `embyServerUrl` 生成稳定的 deviceId
  - 未登录时默认使用 `embbytok-client`
- **Acceptance Criteria Addressed**: AC-4
- **Test Requirements**:
  - `programmatic` TR-4.1: `ApiClient` 有可配置 DeviceId 的接口 ✅（setDeviceId 方法）
  - `programmatic` TR-4.2: `EmbytokService.setupAuth` 调用了新接口 ✅
  - `programmatic` TR-4.3: 生成的 DeviceId 稳定且基于 userId+serverUrl ✅（hashCode 方式）
- **Notes**: 已完成并验证

## [x] Task 5: 静态分析验证
- **Priority**: P0
- **Depends On**: Task 1-4
- **Description**:
  - 运行 Dart format 验证语法正确性
- **Acceptance Criteria Addressed**: AC-6
- **Test Requirements**:
  - `programmatic` TR-5.1: Dart format 验证通过 ✅
- **Notes**: Flutter SDK 未安装（需 570MB），但 Dart SDK 验证已通过，所有修改文件语法正确