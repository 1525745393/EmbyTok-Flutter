# Checklist: EmbyX API 对齐

## 代码实现检查

- [x] `getLibraries` 方法已更新使用 `/Users/{userId}/Views` 端点
- [x] `getLibraries` 正确解析 `Items` 数组中的 `Id`, `Name`, `CollectionType`
- [x] `buildStreamUrl` 方法已创建，包含完整参数
- [x] `buildStreamUrl` 包含 `VideoCodec=h264,hevc,av1` 参数
- [x] `buildStreamUrl` 包含 `AudioCodec=aac,mp3,ac3` 参数
- [x] `buildStreamUrl` 包含 `AllowVideoStreamCopy=true` 参数
- [x] `buildStreamUrl` 包含 `AllowAudioStreamCopy=true` 参数
- [x] `buildStreamUrl` 包含 `DeviceId` 参数
- [x] `reportCapabilities` 方法已创建
- [x] `reportCapabilities` 上报 `PlayableMediaTypes` 为 `["Video", "Audio"]`
- [x] `reportCapabilities` 上报 `SupportedCommands` 包含基本命令
- [x] `api_client.dart` 支持 `DeviceId` 配置
- [x] `Library` 模型支持 `CollectionType` 字段
- [x] `Library.fromJson` 正确解析 `CollectionType`

## 功能验证检查

- [ ] 连接 Emby 服务器成功
- [ ] 获取用户媒体库列表成功（使用 Views API）
- [ ] 媒体库包含正确的类型标识（movies, tvshows 等）
- [ ] 获取媒体列表成功
- [ ] 视频流 URL 正确构建
- [ ] 视频可以正常播放（Direct Play）
- [ ] 收藏功能正常工作
- [ ] 播放进度正确上报
- [ ] 会话能力正确上报

## 测试覆盖检查

- [ ] `embbytok_service_test.dart` 中 `getLibraries` 测试通过
- [ ] `buildStreamUrl` 单元测试通过
- [ ] `reportCapabilities` 单元测试通过
- [ ] API 集成测试通过

## Flutter Analyze 检查

- [ ] `flutter analyze` 无错误
- [ ] 无未使用的导入
- [ ] 无类型警告
