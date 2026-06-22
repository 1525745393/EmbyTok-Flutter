# Tasks

- [x] Task 1: 补齐视频列表 Fields 参数，添加 MediaSources 和 Path
  - [x] 修改 `embbytok_service.dart` 的 `getLibraryItems` 方法，Fields 添加 `MediaSources,Path`
  - [x] 验证返回数据中包含 MediaSources 数组
- [x] Task 2: 实现三级播放降级链
  - [x] 在 `media_item.dart` 添加 `computeDirectStreamUrl` 方法（stream.mp4 + AllowVideoStreamCopy）
  - [x] 在 `media_item.dart` 添加 `computeHlsUrl` 方法（master.m3u8 + 转码参数）
  - [x] 在 `video_player_widget.dart` 实现 error 回调降级逻辑：Direct Play → Direct Stream → HLS
  - [x] 添加 MediaSource 编码判定逻辑（h264+mp4 直接 Direct Play，hevc 走 Direct Stream）
- [x] Task 3: 完善播放进度上报
  - [x] 在 `embbytok_service.dart` 添加 `reportCapabilities` 方法（POST /Sessions/Capabilities/Full）
  - [x] 在 `embbytok_service.dart` 添加 `reportPlaybackStart` 方法（POST /Sessions/Playing）
  - [x] 修改 `reportPlaybackPosition` 补充字段：IsPaused、IsMuted、VolumeLevel、PlayMethod、EventName、CanSeek、QueueableMediaTypes
  - [x] 在 `video_player_widget.dart` 播放开始时调用 reportCapabilities + reportPlaybackStart
- [x] Task 4: 媒体库列表改用 Views 端点
  - [x] 修改 `embbytok_service.dart` 的 `getLibraries` 方法，改用 `/Users/{userId}/Views`（带 userId 回退到 /Library/VirtualFolders）
  - [x] 添加 `getUserViews` 方法（GET /Users/{userId}/Views）替代 `/Library/VirtualFolders`
- [x] Task 5: 实现续播云同步
  - [x] 在 `embbytok_service.dart` 添加 `saveCloudSync` 方法（POST /DisplayPreferences/EmbyTok-Resume）
  - [x] 在 `embbytok_service.dart` 添加 `checkCloudSync` 方法（GET /DisplayPreferences/EmbyTok-Resume）
  - [x] 在视频切换时自动保存续播位置

# Task Dependencies
- [Task 2] depends on [Task 1]（降级链需要 MediaSources 数据）
- [Task 3] 无依赖，可与 Task 2 并行
- [Task 4] 无依赖，可并行
- [Task 5] 无依赖，可并行
