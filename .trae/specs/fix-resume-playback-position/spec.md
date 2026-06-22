# 修复视频播放未同步 Emby 服务器播放进度

## Why
当前 APP 播放视频时始终从头开始，未能从 Emby 服务器的播放进度续播。根本原因是 `VideoPlayerWidget._initVideo()` 中存在竞态条件：`onControllerReady` 回调中通过 `Future.microtask` 异步执行 `seekTo`，但 `_initVideo` 紧接着就调用 `play()` 从位置 0 开始播放，导致 seek 晚于 play 执行或失败被静默吞掉。

## What Changes
- 在 `VideoPlayerWidget` 中新增 `startFromResumePosition` 参数
- 将续播位置 seek 逻辑从 `video_page_item.dart` 的 `onControllerReady` 回调移至 `VideoPlayerWidget._initVideo()`
- 确保 seek 在 play 之前执行，消除竞态条件
- 为 seek 失败添加日志记录，替代静默 `catch (_) {}`

## Impact
- Affected specs: fix-video-playback, fix-video-ui-v1
- Affected code:
  - `/workspace/frontend/lib/widgets/video_player_widget.dart` - 新增参数，移动 seek 逻辑
  - `/workspace/frontend/lib/widgets/video_page_item.dart` - 移除 `onControllerReady` 中的 seek 逻辑，传递 `startFromResumePosition` 参数

## ADDED Requirements
### Requirement: VideoPlayerWidget 支持续播位置
系统 SHALL 在 `VideoPlayerWidget` 中接受 `startFromResumePosition` 参数，当该参数为 true 时，在 `_initVideo()` 中先执行 seek 到续播位置，再调用 play。

#### Scenario: 有播放进度的视频续播
- **WHEN** `startFromResumePosition` 为 true 且 `item.userData.playbackPositionTicks > 0`
- **THEN** 系统先 seek 到对应位置，再开始播放

#### Scenario: 无播放进度的视频
- **WHEN** `startFromResumePosition` 为 false 或 `item.userData` 无播放进度
- **THEN** 系统直接从位置 0 开始播放（保持现有行为）

## MODIFIED Requirements
### Requirement: VideoPlayerWidget 初始化流程
`VideoPlayerWidget._initVideo()` 的流程 SHALL 调整为：
1. 初始化/获取控制器
2. 调用 `onControllerReady` 回调（仅通知外部，不包含 seek 逻辑）
3. 如果 `startFromResumePosition` 为 true，执行 seek 到续播位置
4. 调用 `play()` 开始播放

## REMOVED Requirements
### Requirement: video_page_item onControllerReady 中的 seek 逻辑
**Reason**: seek 逻辑移至 VideoPlayerWidget 内部，确保在 play 之前执行
**Migration**: 从 `video_page_item.dart` 的 `onControllerReady` 回调中移除 seek 代码，改为传递 `startFromResumePosition` 参数给 `VideoPlayerWidget`