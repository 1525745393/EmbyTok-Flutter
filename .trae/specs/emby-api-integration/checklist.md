# EmbyTok × Emby API 对接 —— 验收检查清单（checklist.md）

以下所有检查项在最终提交时均应为 [x]。

## 基础对接（对齐 EmbyX）

- [x] 登录端点使用 `POST /Users/AuthenticateByName` 并持久化
  `serverUrl`、`AccessToken`、`UserId` 三项
- [x] 媒体库默认使用 `/Users/{userId}/Views`，在无 `userId` 时
  fallback 到 `/Library/VirtualFolders`
- [x] 视频列表 `Fields` 参数显式包含 `MediaSources` 与 `Path`
- [x] 图片 URL 统一通过 `MediaItem.imageUrl(type, maxWidth, apiKey)`
  构造，带 `Tag` 与 `Format=jpg`

## 播放降级链

- [ ] `MediaItem` 暴露 `computePlaybackUrl`（Level 0）、
  `computeDirectStreamUrl`（Level 1）、`computeHlsUrl`（Level 2）
  三个独立方法
- [ ] widget 层在初始化失败时从 Level 0 自动降级到 Level 1 → Level 2
- [ ] widget 层在运行时（已初始化但检测到
  `controller.value.hasError`）也触发同样的降级逻辑
- [ ] 降级时保留当前播放位置，并在新 URL 初始化成功后 seek 回去
- [ ] 三级降级均失败时，显示占位图 + 文字提示，不崩溃

## 播放状态上报链

- [ ] 播放开始前调用一次 `reportCapabilities`
- [ ] 视频进入播放时调用 `reportPlaybackStart`（含
  `PlaySessionId`、`MediaSourceId`、`PlayMethod` 字段）
- [ ] 播放期间每 5 秒调用一次 `reportPlaybackPosition`，
  payload 中同时包含 `PositionTicks / IsPaused / IsMuted /
  VolumeLevel / PlayMethod / EventName / CanSeek /
  QueueableMediaTypes / MediaSourceId / PlaySessionId`
- [ ] 用户手动暂停时额外调用一次 `reportPlaybackPosition`，
  `EventName = "Pause"`
- [ ] 切换视频 / 退出页面时调用 `reportPlaybackStopped`
- [ ] `PlayMethod` 与当前实际使用的降级 Level 保持一致
  （Level 0/1 → "DirectPlay"，Level 2 → "Transcode"）
- [ ] `PlaySessionId` 在整个播放会话内唯一且一致

## 收藏

- [x] 双击心形 / 收藏按钮时本地先更新 `UserData.isFavorite`，
  远端失败再回滚（乐观更新）
- [x] 收藏列表使用 `GET /Items?Filters=IsFavorite` 拉取
- [ ] 端点路径统一为带 userId 变体
  `/Users/{userId}/FavoriteItems/{id}`（Task 6 完成后 [x]）

## 跨设备续播云同步

- [ ] 进入首页时拉取一次 `checkCloudSync`，若存在其它设备写入
  的续播信息，以 SnackBar 形式提示用户
- [ ] 切换到新视频时，对"旧视频"调用 `saveCloudSync`
- [ ] 冲突时以 `date` 时间戳最新者为准

## 字段兼容与健壮性

- [x] `MediaItem.fromJson` 同时解析 `RunTimeTicks`（Emby 原生）
  与 `runtime_ticks`（后端代理）
- [x] 所有 API 调用失败均被捕获并写 `AppLogger.debug`，
  不直接 throw 到 UI 层
- [ ] 上报调用使用 `unawaited(Future)` 方式调用，不阻塞 UI

## 日志与安全

- [x] 日志中不打印完整 `apiKey` / `token`
- [ ] 新增播放上报的 payload 字段中无敏感信息泄漏
- [x] `authHeaders()` 返回值仅传递给 video_player 的 HTTP 头

## 后端代理路径（次路径）

- [ ] `backend/clients/emby_client.py` 的 `get_items` / `get_item`
  `Fields` 参数包含 `MediaSources,Path`
- [ ] `backend/clients/emby_client.py` 的 `toggle_favorite`
  路径与前端保持一致（Task 6 完成后 [x]）

## 测试

- [x] 已存在 `frontend/test/services/embbytok_service_test.dart`
- [ ] 为 Task 3 的完整上报链新增测试：
  - mock `ApiClient`，播放视频 12 秒，断言 `reportPlaybackPosition`
    调用 ≥ 2 次
  - 断言 payload 包含 `PlayMethod`、`EventName`、`PlaySessionId`
- [ ] 为 Task 2 的降级链新增 widget 测试：
  - 在 mock controller 上设置 `hasError = true`，断言
    `_fallbackLevel` 递增并调用 `_initVideo`

---

### 检查项完成状态标记约定

- `[x]`：本 Spec 前已实现，已通过代码阅读确认
- `[ ]`：在本 Spec 对应 Task 完成后需人工或自动化检查
