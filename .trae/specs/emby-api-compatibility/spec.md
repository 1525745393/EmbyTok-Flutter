# Emby 服务器 API 适配度修复 - Product Requirement Document

## Overview
- **Summary**: 系统性修复前端 Flutter 应用与 Emby 原生 API 的适配问题，包括播放进度上报精度、字幕获取、用户可见性过滤、设备 ID 唯一性等问题，提升在多用户环境下的兼容性。
- **Purpose**: 根据之前适配度分析报告（综合评分 8.2/10），修复所有 P0（高优）和 P1（中优）问题。
- **Target Users**: EmbyTok 所有用户，尤其是在多用户 Emby 服务器上的普通用户。

## Goals
- **G-1**: 修复播放进度上报的精度问题（秒级 → 毫秒级），减少续播位置偏差
- **G-2**: 修复字幕 Cues 获取的时长上限问题（1小时 → 实际时长），确保长视频字幕完整
- **G-3**: 在列表查询中统一加入 UserId 查询参数，确保返回当前用户可见内容
- **G-4**: DeviceId 动态生成，确保多设备识别正确性
- **G-5**: 在列表/详情 Fields 中加入 MediaStreams，使字幕轨道信息在列表页即可获取

## Non-Goals (Out of Scope)
- 不引入新的 PlaybackInfo 端点调用（当前硬编码 URL 对大多数单源视频可正常工作，需更大改动应单独规划）
- 不改变后端 Python EmbyClient（保持作为辅助能力）
- 不修改路由/页面 UI 布局
- 不改变 Emby 认证逻辑（登录、收藏、历史等功能保持不变）

## Background & Context
现有代码结构：
- **EmbytokService** (`lib/services/embbytok_service.dart`)：所有 Emby API 调用集中在这里
- **MediaItem** (`lib/models/media_item.dart`)：媒体项模型，包含 `computePlaybackUrl` / `computeDirectStreamUrl` / `computeHlsUrl`
- **VideoPageItem** (`lib/widgets/video_page_item.dart`)：播放页 Widget，负责发起播放进度上报
- **ApiClient** (`lib/services/api_client.dart`)：Dio 封装，注入 `X-Emby-Authorization` 头
- **AuthState** (`lib/providers/auth_provider.dart`)：存储 embyServerUrl / token / userId

## Functional Requirements

### FR-1: Fields 中加入 MediaStreams
在 `getLibraryItems`、`getItemDetail`、`getResumeItems`、`getNextUp`、`getRecentlyAdded`、`getSimilarItems`、`getPersonItems`、`getItemsByGenre`、`getItemsByStudio`、`getFavorites`、`getFavoriteMovies`、`getFavoriteBoxSets`、`getFavoritePeople`、`getWatchHistory`、`searchItems` 方法的 `'Fields'` 查询参数值中加入 `MediaStreams`（保留原有的 `MediaSources` 不变）。

### FR-2: 列表查询附加 UserId 查询参数
所有访问 `/Items` 的方法中，当有 userId 但走 `/Users/{userId}/Items` 路径时无需额外参数；当走 `/Items` 回退路径时，附加 `UserId` 查询参数以实现用户内容过滤。

受影响方法：
- `getLibraryItems`（已有 userId 分支已有 `/Users/{userId}/Items`，但 `/Items` 分支缺失 UserId）
- `getFavoriteMovies`（同上）
- `getFavoriteBoxSets`（同上）
- `getFavoritePeople`（同上）
- `getRecentlyAdded`（同上）

### FR-3: 播放进度上报毫秒级精度
- `VideoPageItem._reportPlaybackProgress()` 中 `(position?.inSeconds ?? 0) * 10000000` → `(position?.inMilliseconds ?? 0) * 10000`
- `VideoPageItem._reportPlaybackStopped()` 中同样的修改
- `EmbytokService.reportPlaybackStart` 中 `PositionTicks: 0` 改为接收可选的 `positionTicks` 参数，播放页传入当前续播位置（若有）

### FR-4: 字幕 Cues 时长上限
`EmbytokService.getSubtitleCues` 增加 `startPositionTicks` / `endPositionTicks` 参数。默认 `startPositionTicks = 0`（起始位置），默认 `endPositionTicks` 使用传入值；若未传入则回退为 `36000000000`（1 小时）兼容旧行为。实际调用时（从 `VideoPlayerWidget` / `_loadSubtitle` 路径），将 `MediaItem.runTimeTicks` 传入。

### FR-5: 动态 DeviceId
`ApiClient._clientAuthorization` 不再硬编码 `DeviceId='embbytok-client'`。改为：
- 在 `setupAuth` 时生成一个动态 DeviceId：`embbytok-{first8CharsOf(sha256(userId+serverUrl)}`
- 将生成的值缓存，不破坏现有会话
- 若无法确定（匿名模式）则回退到 `embbytok-client`

实现方式：在 `_clientAuthorization` 中改为使用一个 `String` 字段，`setupAuth` 时更新。

## Acceptance Criteria

### AC-1: 列表查询包含 MediaStreams
- **Given**: 用户已登录且 Emby 服务器
- **When**: 用户打开首页/搜索/历史等页面，发起媒体列表
- **Then**: API 请求的 Fields 参数包含 "MediaStreams"
- **Verification**: programmatic
- **Notes**: 影响到 `subtitleTracks` 的数据可正常显示字幕语言列表

### AC-2: 播放进度上报使用毫秒精度
- **Given**: 用户正在播放一个视频
- **When**: 触发 `_reportPlaybackProgress` 或 `_reportPlaybackStopped` 被调用
- **Then**: `PositionTicks` 值精确到毫秒（不是秒×10000000 改为毫秒×10000）
- **Verification**: programmatic

### AC-3: 字幕 Cues 支持超过 1 小时的视频
- **Given**: 用户播放超过 1 小时的视频
- **When**: 加载字幕
- **Then**: 字幕请求使用实际视频时长而非固定 1 小时
- **Verification**: programmatic

### AC-4: 多设备使用不同 DeviceId
- **Given**: 两个不同的 Emby 用户登录
- **When**: 两个设备上分别登录
- **Then**: 它们的 `X-Emby-Authorization` 头中的 `DeviceId` 不同
- **Verification**: programmatic

### AC-5: 列表查询对当前用户可见
- **Given**: 多用户 Emby 服务器
- **When**: 发起 `/Items` 回退路径请求
- **Then**: `UserId` 参数被正确附加
- **Verification**: programmatic

### AC-6: 无编译错误
- **Given**: 所有修改完成后
- **When**: 运行 `flutter analyze --no-pub lib`
- **Then**: 零 error（0 errors）
- **Verification**: programmatic

## Open Questions
- 无。所有改动均基于现有代码的增量调整，不涉及新的 API 端点或显著架构变更。
