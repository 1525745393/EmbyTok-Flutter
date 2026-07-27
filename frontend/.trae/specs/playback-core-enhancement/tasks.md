# Tasks

- [x] Task 1: 添加依赖与平台配置
  - [x] SubTask 1.1: 在 pubspec.yaml 中添加 `audio_session: ^0.1.21` 和 `audio_service: ^0.18.15` 依赖
  - [x] SubTask 1.2: 修改 `android/app/src/main/AndroidManifest.xml`，添加 FOREGROUND_SERVICE、FOREGROUND_SERVICE_MEDIA_PLAYBACK、WAKE_LOCK 权限，注册 AudioService 和 MediaButtonService
  - [x] SubTask 1.3: 修改 `ios/Runner/Info.plist`，添加 `UIBackgroundModes: [audio]` 配置
  - [ ] SubTask 1.4: 运行 `flutter pub get` 验证依赖安装成功（待本地环境执行）

- [x] Task 2: 实现服务端进度拉取能力
  - [x] SubTask 2.1: 在 `media_server_api.dart` 接口中新增 `getPlaybackPosition` 方法，通过 `GET /Users/{userId}/Items/{itemId}` 获取 `UserData.PlaybackPositionTicks`
  - [x] SubTask 2.2: 在 `emby_server_api.dart` 中实现 `getPlaybackPosition` 方法
  - [x] SubTask 2.3: 在 `embytok_service.dart` 中委托该方法
  - [x] SubTask 2.4: 为 `getPlaybackPosition` 添加单元测试

- [x] Task 3: 实现播放开始时的进度双向同步
  - [x] SubTask 3.1: 在 `video_page_item.dart` 的 `_startPlaybackIfCurrent` 方法中，播放开始前调用 `getPlaybackPosition` 拉取服务端最新进度
  - [x] SubTask 3.2: 比较服务端进度与本地 `item.userData.playbackPositionTicks`，取较新者作为播放起点
  - [x] SubTask 3.3: 若服务端进度更新，更新本地 `MediaItem.userData` 并 seek 到对应位置
  - [x] SubTask 3.4: 保持现有进度上报逻辑不变（Start/Position/Stopped）

- [x] Task 4: 实现音频焦点管理
  - [x] SubTask 4.1: 创建 `lib/services/audio_session_handler.dart`，封装 `audio_session` 的 AudioSession 管理
  - [x] SubTask 4.2: 在播放开始时请求音频焦点（`AudioSession.instance.requestFocus`）
  - [x] SubTask 4.3: 注册音频焦点中断监听（`interruptionEvent`），来电/其他 App 播放时暂停
  - [x] SubTask 4.4: 焦点恢复时根据设置决定是否续播（新增"焦点恢复自动续播"偏好设置）
  - [x] SubTask 4.5: 在播放停止时释放音频焦点
  - [x] SubTask 4.6: 创建 `audioFocusHandlerProvider`，通过 Riverpod 管理音频焦点生命周期

- [x] Task 5: 实现 AudioHandler 和 MediaSession
  - [x] SubTask 5.1: 创建 `lib/services/embytok_audio_handler.dart`，继承 `BaseAudioHandler`，实现 `play`、`pause`、`stop`、`skipToNext` 方法
  - [x] SubTask 5.2: 在 `play`/`pause`/`stop` 方法中操作 `currentVideoControllerProvider` 控制实际播放器
  - [x] SubTask 5.3: 播放状态变化时更新 `playbackState`（MediaSession 状态），包含标题、艺术家、封面
  - [x] SubTask 5.4: 创建 `audioHandlerProvider`，在 App 启动时初始化 AudioHandler
  - [x] SubTask 5.5: 在 `app.dart` 中初始化 AudioHandler，注册到 `audio_service`

- [x] Task 6: 集成 AudioHandler 到播放器
  - [x] SubTask 6.1: 在 `video_page_item.dart` 播放开始时通过 AudioHandler 更新 MediaSession 状态
  - [x] SubTask 6.2: 在播放进度上报时同步更新 MediaSession 位置
  - [x] SubTask 6.3: 在播放停止时通过 AudioHandler 清除 MediaSession
  - [x] SubTask 6.4: 实现锁屏"下一集"按钮（`skipToNext`）跳转下一个视频

- [x] Task 7: 修改后台播放行为
  - [x] SubTask 7.1: 修改 `video_page_item.dart` 的 `didChangeAppLifecycleState`，后台时不主动暂停，改由 AudioHandler 接管
  - [x] SubTask 7.2: 后台时暂停视频画面渲染（节约 GPU），仅保留音频
  - [x] SubTask 7.3: 从后台回到前台时恢复视频画面渲染
  - [x] SubTask 7.4: 确保 `video_player_widget.dart` 的 `_syncPlaybackState` 与 AudioHandler 状态一致

- [x] Task 8: 新增"焦点恢复自动续播"偏好设置
  - [x] SubTask 8.1: 在 `app_preferences.dart` 中添加 `autoResumeAfterInterruption` 偏好项（默认 true）
  - [x] SubTask 8.2: 创建对应的 Provider（`autoResumeAfterInterruptionProvider`）
  - [x] SubTask 8.3: 在设置页面添加开关项

# Task Dependencies
- [Task 2] depends on [Task 1]（依赖 audio_session 但接口层无依赖，可并行）
- [Task 3] depends on [Task 2]（进度同步依赖 getPlaybackPosition 方法）
- [Task 4] depends on [Task 1]（依赖 audio_session 包）
- [Task 5] depends on [Task 1]（依赖 audio_service 包）
- [Task 6] depends on [Task 4, Task 5]（集成音频焦点和 AudioHandler）
- [Task 7] depends on [Task 5, Task 6]（后台行为依赖 AudioHandler）
- [Task 8] depends on [Task 4]（偏好设置被音频焦点使用）
- [Task 1] 和 [Task 2] 可并行
