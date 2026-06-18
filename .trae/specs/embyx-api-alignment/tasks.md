# Tasks: EmbyX API 对齐

## 任务清单

- [x] Task 1: 更新 `getLibraries` 使用 `/Users/{userId}/Views` API
  - 修改 `embbytok_service.dart` 中的 `getLibraries` 方法
  - 从 `data['Items']` 解析媒体库列表
  - 验证返回数据包含 `Id`, `Name`, `CollectionType`
  - ✅ 已完成：添加 `_defaultUserId` 字段，更新 `getLibraries` 使用 Views API

- [x] Task 2: 添加视频流 URL 构建方法
  - 在 `embbytok_service.dart` 中添加 `buildStreamUrl` 方法
  - 包含完整的 Direct Play 参数：`VideoCodec`, `AudioCodec`, `AllowStreamCopy`
  - 支持 `DeviceId` 参数
  - ✅ 已完成：添加 `buildStreamUrl` 和 `buildHlsStreamUrl` 方法

- [x] Task 3: 添加会话能力上报功能
  - 在 `embbytok_service.dart` 中添加 `reportCapabilities` 方法
  - 上报 `PlayableMediaTypes` 和 `SupportedCommands`
  - ✅ 已完成：添加 `reportCapabilities` 方法

- [x] Task 4: 更新 `api_client.dart` 支持 DeviceId
  - 添加 `DeviceId` 配置项
  - 在所有视频流请求中包含 `DeviceId`
  - ✅ 已完成：在 `EmbytokService` 中添加 `_defaultDeviceId` 和 `setDeviceId` 方法

- [x] Task 5: 更新 `Library` 模型
  - 添加 `CollectionType` 字段支持
  - 确保 `fromJson` 解析正确
  - ✅ 已完成：模型已有 `type` 字段存储 `CollectionType`，无需修改

- [ ] Task 6: 验证兼容性
  - 测试与 Emby 服务器的连接
  - 测试媒体库列表获取
  - 测试视频流播放
  - 测试收藏同步
  - ⏳ 待验证：需要实际连接 Emby 服务器进行测试

## 任务依赖

- Task 1 无依赖，可最先执行 ✅
- Task 2 依赖 Task 4（需要 DeviceId）✅
- Task 3 无依赖，可独立执行 ✅
- Task 4 无依赖，可最先执行 ✅
- Task 5 无依赖，可最先执行 ✅
- Task 6 依赖 Task 1-5

## 可并行执行的任务

- Task 1, Task 4, Task 5 可并行执行 ✅
- Task 2 依赖 Task 4 ✅
- Task 3 独立 ✅
- Task 6 最后执行 ⏳

## 实现总结

已完成以下代码修改：

1. **EmbytokService 新增字段**：
   - `_defaultUserId`：存储当前用户ID
   - `_defaultDeviceId`：存储设备ID

2. **更新 `setupAuth` 方法**：
   - 保存 `userId` 参数

3. **更新 `login` 方法**：
   - 登录成功后保存 `user.id` 到 `_defaultUserId`

4. **更新 `clearAuth` 方法**：
   - 清除认证时清空 `_defaultUserId`

5. **新增 `setDeviceId` 方法**：
   - 设置设备ID

6. **重写 `getLibraries` 方法**：
   - 端点从 `/Library/VirtualFolders` 改为 `/Users/$userId/Views`

7. **新增 `reportCapabilities` 方法**：
   - 上报客户端播放能力到 `/Sessions/Capabilities/Full`

8. **新增 `buildStreamUrl` 方法**：
   - 构建直接流 URL，支持 Direct Play

9. **新增 `buildHlsStreamUrl` 方法**：
   - 构建 HLS 流 URL 作为备选
