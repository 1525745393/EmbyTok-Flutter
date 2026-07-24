# 需求实施计划

- [ ] 1. 环境准备和依赖配置
  - 在 pubspec.yaml 中将 `video_player: ^2.8.0` 替换为 `flutter_vlc_player: ^7.4.0`
  - 运行 `flutter pub get` 拉取依赖
  - 验证 Android 平台最低版本 API 21 满足 VLC 要求
  - [ ] 1.1 为 flutter_vlc_player 依赖兼容性编写测试用例

- [ ] 2. 实现核心抽象层
  - [ ] 2.1 创建 IPlaybackController 抽象接口
    - 在 `lib/services/playback/i_playback_controller.dart` 中定义接口
    - 包含方法签名：`initialize()`, `play()`, `pause()`, `seekTo()`, `setPlaybackSpeed()`, `setVolume()`, `dispose()`
    - 包含属性：`position`, `duration`, `isInitialized`, `isPlaying`, `hasError`, `playbackSpeed`, `playerId`
    - 包含回调：`onPositionChanged`, `onPlaybackStateChanged`, `onError`
    - 对应需求 R3.1（播放引擎替换兼容）

  - [ ] 2.2 创建 PlaybackUrlResolver 接口
    - 在 `lib/services/playback/playback_url_resolver.dart` 中定义 `resolveUrls(MediaItem, String serverUrl, String token)` 方法签名
    - 对应需求 R3.1（播放引擎替换兼容）

  - [ ] 2.3 实现 EmbyPlaybackUrlResolver
    - 在 `lib/services/playback/emby_playback_url_resolver.dart` 中实现三级 URL 构建
    - 依次返回 DirectPlay → DirectStream → HLS Transcode URL
    - 从 `MediaItem.computePlaybackUrl()` / `computeDirectStreamUrl()` / `computeHlsUrl()` 提取逻辑
    - 对应需求 R5.4（三级降级兜底）

  - [ ] 2.4 实现 VlcControllerAdapter
    - 在 `lib/services/playback/vlc_controller_adapter.dart` 中实现 IPlaybackController
    - 内部委托 `VlcPlayerController`，设置 `HwAcc.auto` 启用硬解优先
    - 配置网络缓冲 `networkCaching(2000)`
    - 暴露 `playerId` 供 VlcPlayer widget 纹理渲染
    - 对应需求 R1.1（HEVC 软解回退）、R1.2（硬解优先）

  - [ ] 2.5 实现 ControllerFactory
    - 在 `lib/services/playback/controller_factory.dart` 中实现
    - 接收 `PlaybackUrlResolver` 注入，遍历 URL 列表创建 VlcControllerAdapter
    - 12 秒超时，失败时 dispose 当前 controller 并尝试下一级 URL
    - 对应需求 R5.4（三级降级兜底）

  - [ ] 2.6 为核心抽象层编写单元测试
    - 为 VlcControllerAdapter 接口方法委托编写测试（需要 mock VlcPlayerController）
    - 为 EmbyPlaybackUrlResolver URL 构建正确性编写测试
    - 为 ControllerFactory 降级链逻辑编写测试

- [ ] 3. 检查点 - 确保核心抽象层编译通过
  - 运行 `flutter analyze` 确认无编译错误
  - 确保所有新文件无编译问题

- [ ] 4. 更新数据模型
  - [ ] 4.1 扩展 MediaSource 模型
    - 在 `lib/models/media_source.dart` 中新增 `videoCodec`、`videoBitDepth`、`videoLevel` 字段
    - 从 Emby API 响应中解析对应的编解码信息
    - 对应需求 R1.4（8-bit/10-bit 色深支持）

  - [ ] 4.2 更新 PlaybackSession 模型
    - 在 `lib/services/video_pool_service.dart` 中将 `VideoPlayerController` 字段类型替换为 `IPlaybackController`
    - 新增 `decodeMode` 字段记录解码模式（hardware/software/unknown）
    - 对应需求 R3.1（播放引擎替换兼容）

- [ ] 5. 适配 VideoPoolService
  - [ ] 5.1 重构 preload() 方法
    - 注入 `ControllerFactory` 替代直接调用 `VideoPlayerController.networkUrl`
    - 使用 `PlaybackUrlResolver` 获取 URL 列表
    - 保持 LRU 淘汰和并发防护逻辑不变
    - 对应需求 R3.1、R5.4

  - [ ] 5.2 更新 take() 和 returnSession() 方法
    - 返回类型从 `PlaybackSession`（含具体类型）保持不变，内部使用 IPlaybackController
    - 池释放逻辑适配 IPlaybackController.dispose()
    - 对应需求 R3.1

  - [ ] 5.3 为 VideoPoolService 编写测试
    - 测试池满 LRU 淘汰行为
    - 测试 take/return 生命周期
    - 测试降级链失败->全部失败路径

- [ ] 6. 检查点 - 确保服务层适配完成
  - 确保 VideoPoolService 所有公开接口签名不变
  - 调用方无编译错误

- [ ] 7. 适配 Providers 和 PlaybackCoordinator
  - [ ] 7.1 修改 currentVideoControllerProvider
    - 在 `lib/providers/video_playback_controller.dart` 中将类型从 `StateProvider<VideoPlayerController?>` 改为 `StateProvider<IPlaybackController?>`
    - 同步更新所有 `.watch()` 和 `.read()` 该 Provider 的调用处
    - 对应需求 R3.1

  - [ ] 7.2 修改 PlaybackCoordinator
    - 在 `lib/coordinators/playback_coordinator.dart` 中将 `VideoPlayerController` 引用替换为 `IPlaybackController`
    - 更新 `preloadNeighbors()` 内部的预加载调用链路
    - 对应需求 R3.1

  - [ ] 7.3 全局类型替换
    - 使用 Grep 搜索所有 `VideoPlayerController` 引用，逐一替换为 `IPlaybackController`
    - 确保无遗漏的类型引用
    - 对应需求 R3.1

- [ ] 8. 适配播放器 UI 组件
  - [ ] 8.1 修改 VideoPlayerWidget
    - 在 `lib/widgets/video_player_widget.dart` 中将 `VideoPlayerController` 替换为 `IPlaybackController`
    - 将 `VideoPlayer(controller)` widget 替换为 `VlcPlayer(controller: adapter.vlcController)`
    - 保持 `_initVideo()` 的预加载路径1和动态创建路径2逻辑结构不变
    - 保持字幕渲染层（SubtitleRenderer）叠加在 VlcPlayer 上方不变
    - 对应需求 R3.2（保持播放控制接口兼容）、R3.3（保持手势交互不变）

  - [ ] 8.2 修改 VideoPageItem
    - 在 `lib/widgets/video_page_item.dart` 中将 `_videoController` 类型改为 `IPlaybackController?`
    - 修改 `onControllerReady` 回调参数类型
    - `preloadedSession?.controller` 传递路径适配新类型
    - 对应需求 R3.2、R3.3

  - [ ] 8.3 修改 FullscreenVideoPage
    - 在 `lib/views/fullscreen_video_page.dart` 中将 `_watchedController` 类型改为 `IPlaybackController?`
    - 修改 `ref.listen<IPlaybackController?>(currentVideoControllerProvider, ...)` 完整链路
    - 保持透明覆盖层策略不变（VLC 同样支持单一 Texture 多 widget 引用）
    - 验证全屏进出时 Texture 不黑屏
    - 对应需求 R3.2、R3.3

  - [ ] 8.4 修改 video_gesture_mixin.dart
    - 将 `controller.value.position` / `controller.value.duration` 替换为 `controller.position` / `controller.duration`
    - 将 `controller.seekTo()` 替换为 `controller.seekTo()`
    - Seek 拖动释放逻辑保持不变
    - 对应需求 R3.3（保持手势交互不变）

  - [ ] 8.5 修改 video_controls.dart
    - 将控制器相关属性访问从 `VideoPlayerControllerValue` 改为 `IPlaybackController` 直接属性
    - 保持播放/暂停/进度条/倍速/字幕选择/全屏切换按钮布局不变
    - 对应需求 R3.2、R3.4（六档倍速）

- [ ] 9. 检查点 - 确保 UI 组件完整适配
  - 运行 `flutter analyze` 确认无类型错误
  - 检查所有组件中不再有 `VideoPlayerController` 直接引用

- [ ] 10. 实现错误处理和用户提示
  - [ ] 10.1 实现播放初始化失败的错误 UI
    - 在 VideoPlayerWidget 中为 `_hasError = true` 状态渲染错误提示界面
    - 包含"无法解码该视频格式或网络异常"文案、重试按钮
    - 对应需求 R5.5（连续 3 次失败提示）、R2.3（HLS 分片失败重试）

  - [ ] 10.2 实现三级降级链的 VLC 版本
    - 在 `_initVideo()` 中通过 ControllerFactory 执行降级链
    - 三级全部失败时展示错误 UI
    - 对应需求 R5.4（降级兜底）

- [ ] 11. 最终验证和清理
  - [ ] 11.1 清理旧依赖
    - 确认 pubspec.yaml 中已移除 `video_player` 依赖
    - 运行 `flutter clean && flutter pub get` 确保无残留引用

  - [ ] 11.2 全局代码审查
    - Grep 搜索 `VideoPlayerController` 确保无遗漏引用
    - Grep 搜索 `import 'package:video_player` 确保无遗留 import
    - 检查 `lib/services/playback/` 目录结构完整性

  - [ ] 11.3 集成测试
    - 验证 HEVC 8-bit 测试视频可播放
    - 验证 HEVC 10-bit 测试视频可播放（或降级到 HLS）
    - 验证 HLS 多码率流自适应切换
    - 验证倍速切换 0.5x ~ 2.0x 六档均正常
    - 验证全屏进出 Texture 不黑屏
    - 验证视频流上下滑动切换不泄漏 controller
