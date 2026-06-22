# Emby API 适配增强改进 Spec

## Why
当前项目与 Emby 服务器适配度已达 9.5/10，但仍有 P2/P3 级改进项可进一步提升兼容性和效率，特别是引入 `PlaybackInfo` 端点以正确处理多版本视频。

## What Changes
- 引入 `GET /Items/{itemId}/PlaybackInfo` 端点调用，获取真实 MediaSourceId 和转码决策
- 移除 URL 中重复的 `api_key` 参数（已有 `X-Emby-Token` 请求头）
- 从 Fields 中移除未使用的 `Path` 字段
- 更新播放 URL 构造逻辑，使用 PlaybackInfo 返回的真实数据

## Impact
- Affected specs: emby-api-compatibility, emby-api-compatibility-review
- Affected code:
  - `lib/services/embbytok_service.dart`（新增 getPlaybackInfo 方法）
  - `lib/models/media_item.dart`（computePlaybackUrl 使用真实 MediaSourceId）
  - `lib/widgets/video_player_widget.dart`（调用 PlaybackInfo 获取播放信息）

## ADDED Requirements

### Requirement: PlaybackInfo 端点集成
系统 SHALL 在播放前调用 `GET /Items/{itemId}/PlaybackInfo` 获取真实播放信息。

#### Scenario: 多版本视频选择
- **WHEN** 视频有多个版本（如 1080p/4K）
- **THEN** 系统根据 PlaybackInfo 返回的 MediaSources 选择正确版本

#### Scenario: 转码决策
- **WHEN** 客户端不支持直接播放
- **THEN** 系统使用 PlaybackInfo 返回的 TranscodingUrl 进行播放

### Requirement: 移除重复认证参数
系统 SHALL 移除 URL 中重复的 `api_key` 参数。

#### Scenario: 图片 URL 构造
- **WHEN** 构造图片 URL
- **THEN** 仅使用 `X-Emby-Token` 请求头认证，不在 URL 中添加 `api_key`

### Requirement: 移除未使用字段
系统 SHALL 从 Fields 参数中移除未使用的 `Path` 字段。

#### Scenario: 列表查询优化
- **WHEN** 查询媒体列表
- **THEN** Fields 参数不包含 `Path` 字段