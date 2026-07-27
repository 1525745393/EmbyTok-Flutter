# Playback Core Enhancement Checklist

## 依赖与平台配置
- [ ] pubspec.yaml 已添加 audio_session 和 audio_service 依赖
- [ ] flutter pub get 安装依赖成功
- [ ] AndroidManifest.xml 已添加 FOREGROUND_SERVICE 权限
- [ ] AndroidManifest.xml 已添加 FOREGROUND_SERVICE_MEDIA_PLAYBACK 权限
- [ ] AndroidManifest.xml 已添加 WAKE_LOCK 权限
- [ ] AndroidManifest.xml 已注册 AudioService（com.ryanheise.audioservice.AudioService）
- [ ] AndroidManifest.xml 已注册 MediaButtonService（com.ryanheise.audioservice.MediaButtonService）
- [ ] iOS Info.plist 已添加 UIBackgroundModes 配置，包含 audio 模式

## 服务端进度拉取
- [ ] MediaServerApi 接口新增 getPlaybackPosition 方法
- [ ] EmbyServerApi 实现 getPlaybackPosition 方法（GET /Users/{userId}/Items/{itemId}）
- [ ] EmbytokService 委托 getPlaybackPosition 方法
- [ ] getPlaybackPosition 单元测试通过

## 播放进度双向同步
- [ ] 播放开始时从服务端拉取最新播放进度
- [ ] 比较服务端进度与本地进度，取较新者作为播放起点
- [ ] 服务端进度更新时，更新本地 MediaItem.userData 并 seek
- [ ] 现有进度上报逻辑（Start/Position/Stopped）保持不变
- [ ] 多端进度同步场景测试通过

## 音频焦点管理
- [ ] 创建 audio_session_handler.dart 封装音频焦点管理
- [ ] 播放开始时请求音频焦点
- [ ] 来电/其他 App 播放时自动暂停
- [ ] 焦点恢复时根据设置决定是否续播
- [ ] 播放停止时释放音频焦点
- [ ] 创建 audioFocusHandlerProvider
- [ ] 瞬态焦点丢失（通知提示音）后自动恢复

## AudioHandler 和 MediaSession
- [ ] 创建 EmbytokAudioHandler 继承 BaseAudioHandler
- [ ] 实现 play/pause/stop 方法，操作 currentVideoControllerProvider
- [ ] 实现 skipToNext 跳转下一集
- [ ] 播放状态变化时更新 MediaSession 状态
- [ ] MediaSession 包含标题、艺术家、封面
- [ ] 创建 audioHandlerProvider
- [ ] App 启动时初始化 AudioHandler

## AudioHandler 集成到播放器
- [ ] 播放开始时通过 AudioHandler 更新 MediaSession 状态
- [ ] 播放进度上报时同步更新 MediaSession 位置
- [ ] 播放停止时通过 AudioHandler 清除 MediaSession
- [ ] 锁屏"下一集"按钮可跳转下一个视频

## 后台播放行为
- [ ] App 进入后台时不主动暂停，由 AudioHandler 接管
- [ ] 后台时暂停视频画面渲染，仅保留音频
- [ ] 从后台回到前台时恢复视频画面渲染
- [ ] video_player_widget.dart 的 _syncPlaybackState 与 AudioHandler 状态一致
- [ ] 屏幕熄灭后音频继续播放（WakeLock）

## 偏好设置
- [ ] app_preferences.dart 添加 autoResumeAfterInterruption 偏好项
- [ ] 创建 autoResumeAfterInterruptionProvider
- [ ] 设置页面添加"焦点恢复自动续播"开关

## 回归测试
- [ ] 现有播放上报逻辑不受影响
- [ ] 现有播放器初始化流程不受影响
- [ ] 现有进度上报（Start/Position/Stopped）正常工作
- [ ] 现有观看历史功能正常工作
- [ ] 现有字幕加载功能不受影响
