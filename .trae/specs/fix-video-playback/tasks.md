# 视频播放修复 - The Implementation Plan

## [ ] Task 1: MediaItem 增加播放 URL 构造方法
- **Priority**: P0
- **Depends On**: None
- **Description**: 
  - 在 `MediaItem` 模型中新增 `computePlaybackUrl(String? embyServerUrl, String? token)` 方法
  - 在 `MediaItem` 模型中新增 `authHeaders(String? token)` getter
  - URL 格式: `{embyServerUrl}/Videos/{id}/stream?api_key={urlEncodedToken}&Static=true`
  - 若 `embyServerUrl` 或 `token` 为 null，返回 null
  - 同时支持使用 `MediaSource` 的 `directPlayUrl` 作为备选（如果存在）
- **Acceptance Criteria Addressed**: AC-1, AC-2
- **Test Requirements**:
  - `programmatic` TR-1.1: `computePlaybackUrl('http://emby.local:8096', 'token123')` 返回 `http://emby.local:8096/Videos/{id}/stream?api_key=token123&Static=true`
  - `programmatic` TR-1.2: `computePlaybackUrl(null, 'token123')` 返回 null
  - `programmatic` TR-1.3: `computePlaybackUrl('http://emby.local', null)` 返回 null
  - `programmatic` TR-1.4: `authHeaders('token123')` 返回 `{'X-Emby-Token': 'token123'}`
- **Notes**: token 需要 URL encode 以支持特殊字符

## [ ] Task 2: VideoPlayerWidget 支持动态 URL 和认证头
- **Priority**: P0
- **Depends On**: Task 1
- **Description**: 
  - 修改 `VideoPlayerWidget` 构造函数，增加可选参数 `String? embyServerUrl` 和 `String? token`
  - 修改 `_canPlayVideo` 逻辑：优先使用 `item.playbackUrl`，否则尝试 `item.computePlaybackUrl(embyServerUrl, token)`
  - 修改 `_initVideo()` 方法：
    - 使用动态构造的 URL 初始化 `VideoPlayerController.networkUrl`
    - 传递 `httpHeaders: item.authHeaders(token)`（如果 token 存在）
  - 增强错误处理：捕获初始化异常时显示具体错误信息
- **Acceptance Criteria Addressed**: AC-1, AC-2, AC-4
- **Test Requirements**:
  - `programmatic` TR-2.1: `_canPlayVideo` 在 `playbackUrl` 为空但有 `embyServerUrl` 和 `token` 时返回 true
  - `programmatic` TR-2.2: `VideoPlayerController.networkUrl` 调用时传递 `httpHeaders`
  - `human-judgment` TR-2.3: 播放失败时显示缩略图和错误提示

## [ ] Task 3: VideoPageItem 传递认证信息给播放器
- **Priority**: P0
- **Depends On**: Task 2
- **Description**: 
  - 在 `VideoPageItem` 的 `build` 中通过 `ref.watch(authProvider)` 获取 `embyServerUrl` 和 `token`
  - 将 `embyServerUrl` 和 `token` 传递给 `VideoPlayerWidget`
  - 确保在 `GestureOverlay` 中也能访问播放控制器（保持现有行为）
- **Acceptance Criteria Addressed**: AC-5
- **Test Requirements**:
  - `programmatic` TR-3.1: 编译通过，authProvider 的状态被正确读取
  - `human-judgment` TR-3.2: 登录状态下视频可以播放，未登录状态显示缩略图

## [ ] Task 4: 验证和集成测试
- **Priority**: P1
- **Depends On**: Task 3
- **Description**: 
  - 检查 `item_detail_provider.dart` 中是否有播放相关逻辑需要调整
  - 检查 `favorites_provider.dart` 中的 toggleFavorite 是否正常工作
  - 确保所有页面（feed/search/favorites/history）的视频项都能正确播放
  - 在 Android 设备/模拟器上进行实测
- **Acceptance Criteria Addressed**: AC-3, AC-6
- **Test Requirements**:
  - `human-judgment` TR-4.1: 在真实设备上测试视频播放功能正常
  - `programmatic` TR-4.2: 运行 `flutter analyze` 无错误
  - `programmatic TR-4.3: 构建 APK 成功
- **Notes**: 测试不同格式（mp4, mkv）和不同码率的视频

## Task Dependencies
- Task 2 depends on Task 1
- Task 3 depends on Task 2
- Task 4 depends on Task 3
