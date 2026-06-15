# 视频播放与 UI 修复 - 任务清单

## Task Dependencies
- Task 2 依赖 Task 1
- Task 3 依赖 Task 2
- Task 4 依赖 Task 3
- Task 5 依赖 Task 3
- Task 6 依赖 Task 4 和 Task 5

---

## [x] Task 1: MediaItem 模型增强 - URL 构造方法
**Priority**: P0
**Depends On**: None
**Status**: ✅ Completed

**Description**:
- 在 `MediaItem` 模型中新增 `computePlaybackUrl(String? embyServerUrl, String? token)` 方法
- 在 `MediaItem` 模型中新增 `authHeaders(String? token)` getter
- URL 格式: `{embyServerUrl}/Videos/{id}/stream?api_key={urlEncodedToken}&Static=true`
- 若 `embyServerUrl` 或 `token` 为 null，返回 null
- token 需要 URL encode 以支持特殊字符

**SubTasks**:
- [x] 添加 `computePlaybackUrl()` 方法
- [x] 添加 `authHeaders()` getter
- [x] 添加 `thumbnailUrlWithAuth()` 方法
- [x] 验证 URL 构造逻辑正确

---

## [x] Task 2: MediaItem 图片 URL 增强
**Priority**: P0
**Depends On**: Task 1
**Status**: ✅ Completed

**Description**:
- 检查并增强 `imageUrl()` 方法，确保始终包含 `api_key` 参数
- 验证 `primaryUrl()` 和 `backdropUrl()` 方法正确传递认证参数

**SubTasks**:
- [x] 检查 `imageUrl()` 方法的 api_key 处理
- [x] 验证 `primaryUrl()` 方法
- [x] 验证 `backdropUrl()` 方法
- [x] 添加 `thumbnailUrlWithAuth()` 便捷方法

---

## [x] Task 3: VideoPlayerWidget 支持动态 URL 和认证头
**Priority**: P0
**Depends On**: Task 1
**Status**: ✅ Completed

**Description**:
- 修改 `VideoPlayerWidget` 构造函数，增加可选参数 `embyServerUrl` 和 `token`
- 修改 `_canPlayVideo` 逻辑：优先使用 `item.playbackUrl`，否则尝试 `computePlaybackUrl()`
- 修改 `_initVideo()` 方法：
  - 使用动态构造的 URL 初始化控制器
  - 传递 `httpHeaders: item.authHeaders(token)`
- 增强错误处理

**SubTasks**:
- [x] 添加 `embyServerUrl` 和 `token` 构造参数
- [x] 修改 `_canPlayVideo` 逻辑
- [x] 修改 `_initVideo()` 传递认证头
- [x] 添加错误处理和降级体验

---

## [x] Task 4: VideoPageItem 传递认证信息
**Priority**: P0
**Depends On**: Task 3
**Status**: ✅ Completed

**Description**:
- 在 `VideoPageItem` 的 `build` 中从 `ref.watch(authProvider)` 获取认证信息
- 将 `embyServerUrl` 和 `token` 传递给 `VideoPlayerWidget`

**SubTasks**:
- [x] 从 authProvider 获取认证信息
- [x] 传递给 VideoPlayerWidget
- [x] 确保 GestureOverlay 访问播放控制器正常

---

## [x] Task 5: VideoCard/VideoGrid 等组件增强
**Priority**: P1
**Depends On**: Task 3
**Status**: ✅ Completed

**Description**:
- 检查并修改所有使用 `MediaItem` 显示图片的组件
- 确保传递 `embyServerUrl` 和 `token` 以正确加载缩略图

**SubTasks**:
- [x] 检查 FeedView 组件（使用 VideoPageItem，已自动支持）
- [x] 增强 search_view.dart 的 _SearchResultTile
- [x] 增强 favorites_view.dart 的 _FavoriteTile
- [x] 增强 history_view.dart 的 _HistoryTile

---

## [ ] Task 6: 验证和测试
**Priority**: P1
**Depends By**: Task 4, Task 5
**Status**: ⏳ Pending

**Description**:
- 运行 `flutter analyze` 无错误
- 构建 APK 成功
- 在设备上测试视频播放
- 测试缩略图加载
- 回归测试现有功能

**SubTasks**:
- [ ] `flutter analyze` 无警告
- [ ] `flutter build apk --release` 成功
- [ ] 视频播放功能测试
- [ ] 缩略图加载测试
- [ ] UI 布局回归测试
