# 视频播放与 UI 修复 - Product Requirement Document

## Overview
- **Summary**: 用户反馈 APP 可以登录媒体库但不显示视频，且 UI 界面也有问题。问题根源在于 Emby API 不返回直接的播放 URL，需要动态构造；同时图片 URL 需要正确的认证参数。
- **Purpose**: 修复视频播放和 UI 显示问题，让用户能够正常浏览和播放 Emby 媒体库内容。
- **Target Users**: 已登录 Emby 服务器的所有用户。

## 问题分析

### 问题 1: 视频不播放
1. `MediaItem.playbackUrl` 字段从未被填充：Emby 原生 API 不返回 `playback_url` 字段
2. `MediaItem` 缺少动态构造 Emby 视频流 URL 的方法
3. `VideoPlayerWidget` 只检查 `playbackUrl`，结果始终为 null
4. 视频播放器未传递认证请求头（`X-Emby-Token` 或 `api_key`）

### 问题 2: UI 界面异常
1. 缩略图无法加载：Emby 图片 URL 需要 `api_key` 参数
2. `MediaItem` 的 `thumbnailUrl` 是可选的，但 Emby 图片需要动态构造
3. `MediaItem` 缺少从 Emby 服务器获取正确图片 URL 的方法
4. 组件树中认证信息传递链可能断裂

### Emby API 知识
- **视频流 URL**: `{embyServerUrl}/Videos/{itemId}/stream?api_key={token}&Static=true`
- **图片 URL**: `{embyServerUrl}/Items/{itemId}/Images/{type}?MaxWidth=xxx&Tag={tag}&api_key={token}`
- **认证方式**: `api_key` 查询参数 或 `X-Emby-Token` HTTP 请求头

## Why
用户可以成功登录 Emby 媒体库，但：
- 视频列表不显示视频内容（无法播放）
- UI 界面显示异常（缩略图无法加载）

这严重影响了用户体验，APP 的核心功能无法使用。

## What Changes

### 前端修改
1. **MediaItem 模型增强**
   - 新增 `computePlaybackUrl(String? embyServerUrl, String? token)` 方法
   - 新增 `authHeaders(String? token)` getter
   - 增强 `imageUrl()` 方法，确保图片 URL 包含认证参数

2. **VideoPlayerWidget 改造**
   - 新增 `embyServerUrl` 和 `token` 构造参数
   - 在 `playbackUrl` 为空时动态构造视频流 URL
   - 初始化 `VideoPlayerController` 时传递认证 `httpHeaders`

3. **VideoPageItem 认证传递**
   - 从 `authProvider` 获取 `embyServerUrl` 和 `token`
   - 传递给 `VideoPlayerWidget`

4. **VideoCard/VideoGrid 等组件增强**
   - 正确传递认证信息以显示缩略图

### 后端修改（如需要）
- 检查 `/api/items/{id}` 返回的数据是否包含必要的图片标签

## Impact
- **Affected specs**: `fix-video-playback` (扩展)
- **Affected code**:
  - `frontend/lib/models/media_item.dart`
  - `frontend/lib/widgets/video_player_widget.dart`
  - `frontend/lib/widgets/video_page_item.dart`
  - `frontend/lib/widgets/video_card.dart` (如存在)

## ADDED Requirements

### Requirement: 视频播放 URL 动态构造
系统 SHALL 提供 `MediaItem.computePlaybackUrl(embyServerUrl, token)` 方法，用于动态构造 Emby 视频流 URL。

#### Scenario: 正常情况
- **WHEN**: 用户进入视频播放页面，`playbackUrl` 为 null
- **THEN**: 系统自动构造 URL `{serverUrl}/Videos/{itemId}/stream?api_key={token}&Static=true`

#### Scenario: 缺少认证信息
- **WHEN**: `embyServerUrl` 或 `token` 为 null
- **THEN**: 返回 null，显示缩略图占位

### Requirement: 图片 URL 正确构造
系统 SHALL 在构造图片 URL 时包含 `api_key` 参数，确保认证通过。

#### Scenario: 获取缩略图
- **WHEN**: 组件需要显示缩略图
- **THEN**: 使用 `item.imageUrl('Primary', embyServerUrl: xxx, apiKey: yyy)` 获取完整 URL

### Requirement: 认证信息传递
`VideoPageItem` SHALL 从 `authProvider` 获取认证信息并传递给子组件。

#### Scenario: 页面初始化
- **WHEN**: `VideoPageItem.build()` 被调用
- **THEN**: 从 `ref.watch(authProvider)` 获取 `embyServerUrl` 和 `token`

## Acceptance Criteria

### AC-1: 视频播放
- **Given**: 用户已登录并拥有有效的 Emby 服务器地址和 token
- **When**: 用户进入视频播放页面
- **Then**: 视频应在 3 秒内开始加载和播放

### AC-2: 缩略图显示
- **Given**: 媒体项有图片标签
- **When**: 视频加载中或播放失败
- **Then**: 正确显示缩略图

### AC-3: UI 界面正常
- **Given**: 用户登录后浏览媒体库
- **When**: 查看视频列表/网格
- **Then**: 缩略图正确加载，界面布局正常

### AC-4: 降级体验
- **Given**: 无法获取播放 URL 或网络错误
- **When**: 视频播放器初始化失败
- **Then**: 显示缩略图 + 错误提示，不崩溃

## Non-Goals
- 不修改 Emby 服务器配置
- 不添加外部转码服务
- 不实现 DRM 加密内容的特殊处理
- 不添加字幕显示功能（独立功能）

## Constraints
- **Technical**: Flutter `video_player` 插件 2.8.0 支持 `httpHeaders` 参数
- **Dependencies**: 不引入新依赖
- **Security**: token 需 URL encode

## Open Questions
- [ ] 视频格式是否都被 `video_player` 支持？
- [ ] 是否需要测试 HLS/DASH 自适应流？
- [ ] UI 问题的具体表现是什么？（需用户进一步说明）
