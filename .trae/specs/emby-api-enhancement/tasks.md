# Emby API 适配增强改进 - 任务列表

## [ ] Task 1: 引入 PlaybackInfo 端点
- 在 `EmbytokService` 中新增 `getPlaybackInfo(itemId)` 方法
- 调用 `GET /Items/{itemId}/PlaybackInfo?UserId={userId}`
- 返回包含 `MediaSources` 和 `TranscodingUrl` 的完整播放信息
- **Priority**: P0
- **Depends On**: None

## [ ] Task 2: 更新播放 URL 构造逻辑
- 修改 `MediaItem.computePlaybackUrl` 方法，接收可选的 `MediaSourceId` 参数
- 在 `VideoPlayerWidget._initVideo()` 中先调用 `getPlaybackInfo` 获取真实 MediaSourceId
- 使用 PlaybackInfo 返回的 `DirectStreamUrl` 或 `TranscodingUrl`（如果存在）
- **Priority**: P0
- **Depends On**: Task 1

## [ ] Task 3: 移除重复 api_key 参数
- 检查 `EmbytokService` 中所有构造图片 URL 的位置
- 移除 URL 中的 `&api_key=$token` 参数（已有 X-Emby-Token 请求头）
- 涉及方法：`getPeople()`、`searchHints()` 等
- **Priority**: P1
- **Depends On**: None

## [ ] Task 4: 移除未使用的 Path 字段
- 从 `getLibraryItems`、`getItemDetail` 等方法的 Fields 参数中移除 `Path`
- 验证移除后不影响功能（Path 字段当前未被使用）
- **Priority**: P2
- **Depends On**: None

## [ ] Task 5: 验证和测试
- 运行 Dart format 验证语法
- 确认所有修改不影响现有功能
- **Priority**: P0
- **Depends On**: Task 1-4

# Task Dependencies
- Task 2 depends on Task 1
- Task 5 depends on Task 1-4