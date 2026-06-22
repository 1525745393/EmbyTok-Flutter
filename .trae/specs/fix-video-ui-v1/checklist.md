# 视频播放与 UI 修复 - 验收清单

## MediaItem 模型增强

- [x] `MediaItem.computePlaybackUrl()` 方法正确构造 Emby 视频流 URL
- [x] `computePlaybackUrl()` 对 null 参数返回 null
- [x] `MediaItem.authHeaders` getter 返回 `{'X-Emby-Token': token}`
- [x] `imageUrl()` 方法在有 api_key 时包含认证参数
- [x] `primaryUrl()` 和 `backdropUrl()` 方法正确传递认证参数
- [x] `thumbnailUrlWithAuth()` 方法正确构造带认证的缩略图 URL

## VideoPlayerWidget 改造

- [x] `VideoPlayerWidget` 构造函数新增 `embyServerUrl` 和 `token` 参数
- [x] `_canPlayVideo` 在 `playbackUrl` 为空但有认证信息时尝试动态构造 URL
- [x] `VideoPlayerController.networkUrl` 调用时正确传递 `httpHeaders`
- [x] 播放失败时降级到缩略图 + 错误提示显示

## VideoPageItem 认证传递

- [x] `VideoPageItem` 从 `authProvider` 获取 `embyServerUrl`
- [x] `VideoPageItem` 从 `authProvider` 获取 `token`
- [x] 认证信息正确传递给 `VideoPlayerWidget`
- [x] 组件树中认证信息传递链完整

## UI 组件增强

- [x] FeedView 中的视频卡片正确显示缩略图（通过 VideoPageItem）
- [x] 搜索结果页面的缩略图正确显示（_SearchResultTile）
- [x] 收藏页面的缩略图正确显示（_FavoriteTile）
- [x] 历史记录页面的缩略图正确显示（_HistoryTile）

## 构建与测试

- [ ] `flutter analyze` 无错误和警告
- [ ] Android APK 构建成功 (`flutter build apk --release`)
- [ ] 视频播放功能正常（加载、暂停、进度条）
- [ ] 缩略图正确加载（需要认证）
- [ ] UI 布局正常（列表、网格、卡片样式正确）
- [ ] 现有功能不受影响（登录、搜索、收藏）

## 降级体验

- [x] 视频播放失败时显示缩略图
- [x] 错误提示文字清晰
- [x] 无崩溃或白屏
