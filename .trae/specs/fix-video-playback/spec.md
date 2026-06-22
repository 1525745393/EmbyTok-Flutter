# 视频播放功能修复 - Product Requirement Document

## Overview
- **Summary**: 当前应用视频无法播放的问题。Emby API 不会直接返回 `playbackUrl` 字段，需要根据 Emby 服务器地址、媒体项 ID 和认证 token 动态构造视频流 URL。同时视频播放器需要正确传递认证请求头。
- **Purpose**: 让用户可以直接在 EmbyTok 应用中播放 Emby 服务器上的视频内容。
- **Target Users**: 已登录 Emby 服务器的所有用户。

## Goals
- 视频播放器能够从 Emby 服务器获取并播放视频流
- 视频播放支持认证（通过 URL 参数或 HTTP 请求头）
- 播放失败时提供清晰的降级体验
- 保持现有 UI（TikTok 风格卡片）不变

## Non-Goals (Out of Scope)
- 不修改 Emby 服务器配置
- 不添加外部转码服务
- 不实现 DRM 加密内容的特殊处理
- 不在本次修复中实现字幕显示（字幕作为独立功能）

## Background & Context
### 问题分析
1. `MediaItem.playbackUrl` 字段从未被填充：该字段只从 JSON 的 `playback_url` 和 `playbackUrl` 解析，但 Emby 原生 API 不会返回这两个字段
2. Emby 的视频流 URL 需要动态构造：`{serverUrl}/Videos/{itemId}/stream?api_key={token}&Static=true`
3. 视频播放器未传递认证请求头或参数：`X-Emby-Token` 或 `api_key` 查询参数
4. `VideoPlayerWidget._canPlayVideo` 检查 `item.playbackUrl`，结果始终为 null → 始终显示缩略图占位

### Emby 视频流 API
- **直接流 URL**: `{embyServerUrl}/Videos/{itemId}/stream?api_key={token}&Static=true`
- **原始文件 URL**: `{embyServerUrl}/Items/{itemId}/File?api_key={token}`
- **带媒体源**: `{embyServerUrl}/Videos/{itemId}/stream?MediaSourceId={mediaSourceId}&api_key={token}&Static=true`
- **认证方式**: `api_key` 查询参数 或 `X-Emby-Token` HTTP 请求头

## Functional Requirements
- **FR-1**: `MediaItem` 模型应提供方法 `computePlaybackUrl(embyServerUrl, token)` 来动态构造 Emby 视频流 URL
- **FR-2**: `MediaItem` 模型应提供方法获取认证所需的 HTTP 请求头
- **FR-3**: `VideoPlayerWidget` 应接受可选的 `embyServerUrl` 和 `token` 参数，并在 `playbackUrl` 为空时自动构造流 URL
- **FR-4**: `VideoPlayerWidget` 初始化 `VideoPlayerController` 时需传递认证 `httpHeaders`
- **FR-5**: `VideoPageItem` 组件应从 `authProvider` 获取 `embyServerUrl` 和 `token` 并传递给 `VideoPlayerWidget`
- **FR-6**: 视频播放器加载失败时应降级显示缩略图和错误提示

## Non-Functional Requirements
- **NFR-1**: 视频播放初始化时间应在 3 秒内（在良好网络条件下）
- **NFR-2**: 代码改动不应破坏现有页面的静态展示功能
- **NFR-3**: 构造的 URL 必须兼容不同版本的 Emby/Jellyfin 服务器
- **NFR-4**: token 传递应同时支持 URL 参数和 HTTP 请求头（双保险）

## Constraints
- **Technical**: Flutter `video_player` 插件 2.8.0 版本支持 `httpHeaders` 参数
- **Dependencies**: 不引入新依赖，仅使用现有 `video_player` 和 `flutter_riverpod`
- **Security**: token 应正确编码（URL encode），避免 URL 注入

## Assumptions
- 用户已通过 Emby 登录认证并持有有效的 token
- Emby 服务器的 `Videos` 端点是公开且可用的（需要认证访问）
- Emby 服务器返回的媒体格式（mp4/mkv/ts 等）被 `video_player` 插件支持
- 网络连接可用且允许 HTTP/HTTPS 流播放

## Acceptance Criteria

### AC-1: 视频播放 URL 正确构造
- **Given**: 用户已登录并拥有有效的 Emby 服务器地址和 token
- **When**: 视频播放器初始化时 `playbackUrl` 为 null
- **Then**: 系统应自动构造 URL 格式 `{serverUrl}/Videos/{itemId}/stream?api_key={token}&Static=true`
- **Verification**: `programmatic` - 单元测试验证 URL 构造逻辑
- **Notes**: token 需进行 URL encode

### AC-2: 认证信息正确传递给视频播放器
- **Given**: 视频播放器正在初始化
- **When**: 创建 `VideoPlayerController.networkUrl` 时
- **Then**: 应传递 `httpHeaders` 包含 `{'X-Emby-Token': token}`
- **Verification**: `programmatic` - 代码审查确认参数传递

### AC-3: 视频可以正常播放
- **Given**: 有效的 Emby 视频项和网络连接
- **When**: 用户进入视频播放页面
- **Then**: 视频应在 3 秒内开始加载和播放
- **Verification**: `human-judgment` - 在真实设备上测试播放
- **Notes**: 不同格式（mp4/mkv）和不同码率都应测试

### AC-4: 播放失败降级处理
- **Given**: 视频流无法加载（格式不支持/网络错误/权限错误）
- **When**: `VideoPlayerController.initialize()` 抛出异常
- **Then**: 显示缩略图 + 播放图标占位 + 错误提示文字
- **Verification**: `human-judgment` - 手动测试错误场景

### AC-5: 认证信息从 authProvider 获取
- **Given**: 视频播放页面正在构建
- **When**: 组件状态初始化时
- **Then**: 应从 `ref.watch(authProvider)` 获取 `embyServerUrl` 和 `token`
- **Verification**: `programmatic` - 代码审查确认数据流

### AC-6: 不影响现有页面功能
- **Given**: 应用启动后
- **When**: 用户浏览列表、搜索、收藏等页面
- **Then**: 所有现有功能保持正常
- **Verification**: `human-judgment` - 回归测试

## Open Questions
- [ ] 是否需要在播放前调用 `/PlaybackInfo` 获取更详细的媒体源信息？（可能会增加延迟，但可以获得更准确的 URL 和格式信息）
- [ ] 如何处理 HLS/DASH 等自适应流格式？（当前方案假设直接流播放）
- [ ] 是否需要实现播放进度上报给 Emby 服务器？（代码中已有 `reportPlaybackPosition` 方法，但未被调用）
