# Emby 服务器适配度全面检查 - 任务列表

## [x] Task 1: API 端点适配检查
- 检查 `EmbytokService` 所有方法的 API 端点路径 ✅
- 验证请求参数（Fields、IncludeItemTypes、Filters 等）✅
- 验证响应解析逻辑 ✅
- 输出每个方法的适配状态 ✅

## [x] Task 2: 认证机制适配检查
- 检查 `ApiClient` 的 `X-Emby-Authorization` 头构造 ✅
- 验证 DeviceId 动态生成逻辑 ✅
- 检查 `X-Emby-Token` 注入方式 ✅
- 验证登录流程与 Emby `AuthenticateByName` 对接 ✅

## [x] Task 3: 播放功能适配检查
- 检查 `VideoPlayerWidget` 的播放 URL 构造（DirectPlay/DirectStream/HLS）✅
- 验证 `computePlaybackUrl` / `computeDirectStreamUrl` / `computeHlsUrl` 方法 ✅
- 检查 `VideoPageItem` 的播放进度上报精度 ✅（毫秒级）
- 验证 `reportPlaybackStart/Progress/Stopped` 参数 ✅

## [x] Task 4: 模型解析适配检查
- 检查 `MediaItem.fromJson` 字段映射 ✅（支持 PascalCase + snake_case）
- 检查 `UserData.fromJson` 字段映射 ✅
- 检查 `MediaSource.fromJson` 和 `MediaStream.fromJson` ✅
- 验证 Emby 响应字段与模型字段匹配 ✅

## [x] Task 5: 生成适配度报告
- 综合以上检查结果 ✅
- 按模块评分 ✅
- 计算总体适配度评分 ✅
- 列出剩余问题和改进建议 ✅