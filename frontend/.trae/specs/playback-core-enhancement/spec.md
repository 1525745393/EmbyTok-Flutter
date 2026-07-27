# 播放核心能力补全 Spec

## Why
EmbyTok 作为 Emby 客户端，播放进度双向同步和音频焦点/后台播放是核心刚需。当前播放进度仅单向上报（本地→服务端），多端进度互通不完整；音频焦点完全缺失，来电或其他 App 播放时不会自动暂停；后台播放不支持，进入后台即暂停视频，无法覆盖"听剧"场景。

## What Changes
- 补全播放进度双向同步：从服务端拉取最新播放进度并应用到本地播放器，实现多端进度互通
- 引入 `audio_session` 管理音频焦点：来电/其他 App 播放时自动暂停，焦点恢复时可选续播
- 引入 `audio_service` 实现 MediaSession：锁屏/通知栏媒体控制（播放/暂停/下一集）
- 配置 Android 前台服务和 iOS 后台音频模式，支持后台音频播放
- 修改后台行为：从"主动暂停"改为"由 AudioHandler 接管后台播放"

## Impact
- Affected specs: service-layer-abstraction（MediaServerApi 接口扩展）
- Affected code:
  - `lib/widgets/video_page_item.dart` — 播放上报链改造，接入 AudioHandler
  - `lib/widgets/video_player_widget.dart` — 播放器集成音频焦点
  - `lib/providers/video_playback_controller.dart` — 新增音频焦点 Provider
  - `lib/services/embytok_service.dart` — 新增进度拉取方法
  - `lib/services/emby_server_api.dart` — 实现进度拉取 API
  - `lib/services/media_server_api.dart` — 接口新增方法
  - `android/app/src/main/AndroidManifest.xml` — 添加 service 和权限
  - `ios/Runner/Info.plist` — 添加 UIBackgroundModes
  - `pubspec.yaml` — 添加 audio_session、audio_service 依赖

## ADDED Requirements

### Requirement: 服务端进度双向同步
系统 SHALL 在播放开始前从 Emby 服务端获取最新播放进度，并应用到本地播放器，实现多端进度互通。

#### Scenario: 用户在另一台设备看了 30 分钟后切换到本设备
- **WHEN** 用户在 EmbyTok 中点击一个视频开始播放
- **THEN** 系统从 Emby 服务端获取该视频的最新播放进度（UserData.PlaybackPositionTicks）
- **AND** 如果服务端进度比本地记录新（时间戳更晚），系统 SHALL 跳转到服务端进度位置播放
- **AND** 如果本地进度比服务端新（本设备刚上报过），系统 SHALL 使用本地进度

#### Scenario: 播放过程中其他设备上报了新进度
- **WHEN** 播放器处于运行中状态
- **THEN** 系统不主动拉取服务端进度（避免打断播放），仅在播放开始时拉取

### Requirement: 音频焦点管理
系统 SHALL 在播放视频时请求音频焦点，在焦点丢失时自动暂停，在焦点恢复时按用户设置决定是否续播。

#### Scenario: 来电时自动暂停
- **WHEN** 用户正在播放视频，此时来电
- **THEN** 系统自动暂停播放
- **AND** 来电结束后，系统根据"焦点恢复自动续播"设置决定是否恢复播放

#### Scenario: 其他 App 播放音乐时暂停
- **WHEN** 用户正在播放视频，此时打开音乐 App 播放音乐
- **THEN** 系统自动暂停视频播放
- **AND** 音乐 App 停止播放后，系统根据设置决定是否恢复

#### Scenario: 被其他 App 短暂打断后恢复
- **WHEN** 系统收到瞬态焦点丢失（如通知提示音）
- **THEN** 系统暂停播放，焦点恢复后自动续播（不打断用户）

### Requirement: MediaSession 锁屏控制
系统 SHALL 注册 MediaSession，在锁屏和通知栏显示媒体控制（播放/暂停/下一集），并在播放状态变化时同步更新。

#### Scenario: 锁屏显示媒体控制
- **WHEN** 用户播放视频时锁屏
- **THEN** 锁屏界面显示媒体控制（播放/暂停按钮、视频标题）
- **AND** 用户点击播放/暂停按钮时，系统正确响应

#### Scenario: 通知栏媒体控制
- **WHEN** 用户播放视频时切换到其他 App
- **THEN** 通知栏显示媒体控制通知
- **AND** 用户可通过通知栏控制播放/暂停

### Requirement: 后台音频播放
系统 SHALL 支持后台音频播放，当 App 进入后台时不暂停音频，由 AudioHandler 接管播放控制。

#### Scenario: 切换到其他 App 继续听剧
- **WHEN** 用户正在播放视频，切换到其他 App
- **THEN** 音频继续播放（视频画面暂停）
- **AND** 用户可通过通知栏控制播放/暂停

#### Scenario: 屏幕熄灭后继续播放
- **WHEN** 用户正在播放视频，屏幕自动熄灭
- **THEN** 音频继续播放
- **AND** 系统保持 WakeLock 防止 CPU 休眠

## MODIFIED Requirements

### Requirement: 后台生命周期行为
当前行为：App 进入后台时主动暂停播放。修改为：App 进入后台时由 AudioHandler 决定是否继续播放音频。

#### Scenario: 后台时保持音频播放
- **WHEN** App 从前台切换到后台
- **THEN** 系统不主动暂停播放器
- **AND** AudioHandler 接管，音频继续播放
- **AND** 视频画面渲染暂停（节约 GPU），仅保留音频

#### Scenario: 从后台回到前台
- **WHEN** App 从后台回到前台
- **THEN** 视频画面渲染恢复
- **AND** 播放状态与 AudioHandler 同步

### Requirement: 播放进度上报
当前已实现单向上报（本地→服务端）。保持现有上报机制不变，新增进度拉取能力（服务端→本地）。

#### Scenario: 播放开始时拉取服务端进度
- **WHEN** 播放器初始化视频时
- **THEN** 系统从服务端获取最新播放进度
- **AND** 与本地缓存的进度比较，取较新者作为播放起点
