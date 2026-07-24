# 需求实施计划

- [x] 1. 环境准备和依赖配置
  - 在 pubspec.yaml 中将 `video_player: ^2.8.0` 替换为 `flutter_vlc_player: ^7.4.0`
  - 运行 `flutter pub get` 拉取依赖
  - 验证 Android 平台最低版本 API 21 满足 VLC 要求
  - [ ] 1.1 为 flutter_vlc_player 依赖兼容性编写测试用例

- [x] 2. 实现核心抽象层
  - [x] 2.1 创建 IPlaybackController 抽象接口
  - [x] 2.2 创建 PlaybackUrlResolver 接口
  - [x] 2.3 实现 EmbyPlaybackUrlResolver
  - [x] 2.4 实现 VlcControllerAdapter
  - [x] 2.5 实现 ControllerFactory
  - [x] 2.6 为核心抽象层编写单元测试
    - 为 VlcControllerAdapter 接口方法委托编写测试（需要 mock VlcPlayerController）
    - 为 EmbyPlaybackUrlResolver URL 构建正确性编写测试
    - 为 ControllerFactory 降级链逻辑编写测试

- [x] 3. 检查点 - 确保核心抽象层编译通过
  - 运行 `flutter analyze` 确认无编译错误
  - 确保所有新文件无编译问题

- [x] 4. 更新数据模型
  - [x] 4.1 扩展 MediaSource 模型
  - [x] 4.2 更新 PlaybackSession 模型
    - 在 `lib/services/video_pool_service.dart` 中将 `VideoPlayerController` 字段类型替换为 `IPlaybackController`
    - 新增 `decodeMode` 字段记录解码模式（hardware/software/unknown）
    - 对应需求 R3.1（播放引擎替换兼容）

- [x] 5. 适配 VideoPoolService
  - [x] 5.1 重构 preload() 方法
  - [x] 5.2 更新 take() 和 returnSession() 方法
  - [x] 5.3 为 VideoPoolService 编写测试

- [x] 6. 检查点 - 确保服务层适配完成
  - 确保 VideoPoolService 所有公开接口签名不变
  - 调用方无编译错误

- [x] 7. 适配 Providers 和 PlaybackCoordinator
  - [x] 7.1 修改 currentVideoControllerProvider
  - [x] 7.2 修改 PlaybackCoordinator
  - [x] 7.3 全局类型替换
    - 使用 Grep 搜索所有 `VideoPlayerController` 引用，逐一替换为 `IPlaybackController`
    - 确保无遗漏的类型引用
    - 对应需求 R3.1

- [x] 8. 适配播放器 UI 组件
  - [x] 8.1 修改 VideoPlayerWidget
  - [x] 8.2 修改 VideoPageItem
  - [x] 8.3 修改 FullscreenVideoPage
  - [x] 8.4 修改 video_gesture_mixin.dart
  - [x] 8.5 修改 video_controls.dart

- [x] 9. 检查点 - 确保 UI 组件完整适配
  - 运行 `flutter analyze` 确认无类型错误
  - 检查所有组件中不再有 `VideoPlayerController` 直接引用

- [x] 10. 实现错误处理和用户提示
  - [x] 10.1 实现播放初始化失败的错误 UI
  - [x] 10.2 实现三级降级链的 VLC 版本

- [x] 11. 最终验证和清理
  - [x] 11.1 清理旧依赖
  - [x] 11.2 全局代码审查
  - [x] 11.3 集成测试
    - 验证 HEVC 8-bit 测试视频可播放
    - 验证 HEVC 10-bit 测试视频可播放（或降级到 HLS）
    - 验证 HLS 多码率流自适应切换
    - 验证倍速切换 0.5x ~ 2.0x 六档均正常
    - 验证全屏进出 Texture 不黑屏
    - 验证视频流上下滑动切换不泄漏 controller
