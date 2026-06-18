# Emby 媒体库显示兼容修复 - 产品需求文档 (PRD)

## Overview

- **Summary**: 修复 EmbyTok-Flutter 在 Emby 服务器上无法显示全部媒体库和全部视频内容的问题，对齐 EmbyX 的 API 调用方式，确保所有用户有权限访问的媒体库和视频条目都能在 App 中正确显示。
- **Purpose**: EmbyX 能显示用户的全部媒体库，但 EmbyTok-Flutter 因 API 端点路径差异、`IncludeItemTypes` 参数不全、以及回退路径错误，导致部分媒体库和视频条目无法显示。本需求通过统一 API 调用方式修复此兼容性问题。
- **Target Users**: 所有使用 EmbyTok-Flutter 连接 Emby 服务器的用户（包括 Home Video、混合媒体、家庭共享视频等非标准媒体库类型）。

## Goals

1. **G1**: 媒体库列表 — 登录后能显示用户有权限访问的全部媒体库（与 EmbyX 一致）
2. **G2**: 视频条目 — 每个媒体库内能显示该库下的全部视频条目（包括 `Video` 类型的 Home Video）
3. **G3**: 收藏列表 — 能正确获取用户的全部收藏条目
4. **G4**: 续播列表 — 能正确获取用户的续播条目和最近添加条目
5. **G5**: 向后兼容 — 所有现有功能（播放、上一条/下一条、播放上报、云同步）保持不变

## Non-Goals (Out of Scope)

- 不新增 Jellyfin 或 Plex 的额外 API 支持
- 不新增播放列表（Playlist）的完整管理功能（仅在媒体库列表中以类似媒体库的方式展示 Playlist，不在本需求范围内；可后续迭代）
- 不修改 UI 样式或布局
- 不修改数据模型的序列化/反序列化格式（除非必要）
- 不涉及 Box/Collection（合集）的特殊处理

## Background & Context

**现状调查**：

当前 `EmbytokService` 的实现存在以下与 EmbyX 不一致的 API 调用方式：

| 功能 | EmbyX (可工作) | EmbyTok (当前) | 问题 |
|------|----------------|----------------|------|
| 获取媒体库列表 | `GET /Users/{userId}/Views?api_key={token}` | `GET /Users/{userId}/Views`（无 query params，回退到 `/Library/VirtualFolders`） | 某些 Emby 版本对 `/Library/VirtualFolders` 的响应与用户视图不同，且空 query params 可能导致默认行为差异 |
| 获取视频列表 | `GET /Users/{userId}/Items?...&IncludeItemTypes=Movie,Episode,Video,MusicVideo` | `GET /Items?...&IncludeItemTypes=Movie,Series,MusicVideo,Episode` | **核心问题**：①路径为 `/Items` 而非 `/Users/{userId}/Items`，部分 Emby 版本的用户权限/视图过滤可能不生效；②缺少 `Video` 类型，Home Video/普通视频文件不显示 |
| 收藏列表 | `GET /Users/{userId}/Items?Recursive=true&Filters=IsFavorite` | `GET /Items?Recursive=true&Filters=IsFavorite` | 同样的路径问题，未使用用户特定路径 |
| 续播列表 | 使用 `/Items/Resume`（全局端点，EmbyX 也用） | `GET /Items/Resume`（一致） | 此端点无问题 |
| 其他 API | 统一使用 `?api_key={token}` 查询参数 | 统一使用 `X-Emby-Token` 请求头 | Header 方式有效，但路径问题更大 |

**Emby 原生 API 说明**：

Emby 的 `/Users/{userId}/Items` 和 `/Items` 在理论上是等价的（都需要认证），但实践中：

1. `/Users/{userId}/Items` 是"用户视图"端点，某些 Emby 插件或特定版本的权限检查只会在此端点生效
2. `/Items` 是"管理员视图"端点，对权限检查可能较宽松（但也可能返回管理员而不是当前用户的内容）
3. EmbyX 选择了 `/Users/{userId}/Items` 作为所有项目获取的统一端点

**ItemType 差异**：

- `Movie`：电影
- `Series`：剧集（Series 本身不含视频文件，剧集的实际视频是 `Episode` 类型）
- `Episode`：单集
- `MusicVideo`：音乐视频
- `Video`：**通用视频**（Home Video、家庭视频、普通视频文件等，非常重要，当前 EmbyTok 漏掉）
- `Playlist`：播放列表（EmbyX 额外获取作为"库"的一种）

**核心 Root Cause**：

1. **RC-1**：`getLibraryItems()` 使用 `/Items` 而非 `/Users/{userId}/Items`，部分 Emby 服务器可能在此端点不应用用户视图过滤
2. **RC-2**：`IncludeItemTypes` 缺少 `Video` 类型，导致 Home Video 媒体库中的视频完全不显示
3. **RC-3**：`getLibraries()` 在无 userId 时回退到 `/Library/VirtualFolders`，该端点的响应格式可能与用户视图不同，且可能暴露管理员级别的文件夹
4. **RC-4**：收藏、最近添加等其他方法同样使用 `/Items` 而非用户路径

## Functional Requirements

- **FR-1 [getLibraries]**: `EmbytokService.getLibraries()` 应始终使用 `/Users/{userId}/Views` 端点获取媒体库列表（无论是否提供 userId 参数，应有默认行为）
- **FR-2 [getLibraryItems]**: `EmbytokService.getLibraryItems()` 应使用 `/Users/{userId}/Items` 端点获取视频列表，并将 `IncludeItemTypes` 修改为 `Movie,Episode,Video,MusicVideo`
- **FR-3 [getFavorites]**: `EmbytokService.getFavorites()` 和 `getFavoriteMovies()` 应使用 `/Users/{userId}/Items` 端点
- **FR-4 [getResumeItems]**: `EmbytokService.getResumeItems()` 和 `getNextUp()` 保持不变（它们已使用正确的端点）
- **FR-5 [getRecentlyAdded]**: `EmbytokService.getRecentlyAdded()` 应使用 `/Users/{userId}/Items/Latest` 或 `/Users/{userId}/Items`（与原 Latest 端点等价的用户路径版本）
- **FR-6 [getPeople]**: `EmbytokService.getPeople()` 应使用 `/Users/{userId}/Items` 或 `/Persons`（后者是全局端点，通常是正确的）
- **FR-7 [searchHints/searchItems]**: EmbyX 使用类似的用户路径端点，保持当前实现（搜索通常在全局搜索），除非验证有问题
- **FR-8 [Library model]**: `Library` 模型应正确处理 `CollectionType` 字段，以区分不同类型的媒体库（movies / tvshows / homevideos / musicvideos 等）
- **FR-9 [UserId 传递]**: 确保在所有服务方法中正确传递 userId，优先使用登录后保存的 `_defaultUserId`

## Non-Functional Requirements

- **NFR-1 (Performance)**: API 调用响应时间与之前持平，不因路径变更引入额外延迟
- **NFR-2 (Backward Compatibility)**: 若用户使用的 Emby 版本不支持 `/Users/{userId}/Items`（极少见），应有合理的回退行为（降级到 `/Items`）
- **NFR-3 (Error Handling)**: API 失败时保留当前的错误处理逻辑，不引入新的崩溃路径
- **NFR-4 (Code Clarity)**: 修改后的代码结构应保持清晰，不引入与 EmbyX 相同的反模式（如硬编码 api_key 查询参数）

## Constraints

- **Technical**: 使用 Dart / Flutter，保持 Dio 客户端不变，不更换 HTTP 客户端库
- **Dependence**: 依赖 Emby 服务器原生 API（无后端中转）
- **Backward Compatibility**: 必须兼容 Emby 4.x 及以上版本，不应破坏与 Jellyfin 的兼容性（尽管本项目主要面向 Emby）

## Assumptions

- 登录流程正确保存了 userId（代码中已有 `_defaultUserId`）
- `X-Emby-Token` Header 认证方式在所有 `/Users/{userId}/...` 端点上有效
- 不同 Emby 服务器版本对 `/Users/{userId}/Items` 的行为一致（经验上正确，但需用户反馈验证）

## Acceptance Criteria

### AC-1: 媒体库列表显示完整
- **Given**: 用户已登录到 Emby 服务器
- **When**: 进入首页或媒体库选择界面
- **Then**: 显示的媒体库数量与 EmbyX 中显示的媒体库数量一致（不考虑 Playlist）
- **Verification**: 代码 review + 实际环境测试
- **Notes**: 按 CollectionType=playlists 和 boxsets 过滤的行为应保留

### AC-2: Home Video 类型的视频可显示
- **Given**: 用户的 Emby 服务器中有 Home Video 类型的媒体库，其中包含视频文件
- **When**: 选中该媒体库查看视频列表
- **Then**: 视频列表中能看到该库的全部视频条目（数量与 EmbyX 一致）
- **Verification**: 代码 review + 实际环境测试
- **Notes**: 关键是 `IncludeItemTypes` 中添加了 `Video`

### AC-3: 收藏列表与 EmbyX 一致
- **Given**: 用户在 Emby 中有收藏的视频（包括 Home Video 类型）
- **When**: 查看收藏列表
- **Then**: 收藏列表内容与 EmbyX 一致
- **Verification**: 代码 review

### AC-4: 播放功能不受影响
- **Given**: 用户在修正后的应用中选择任一视频播放
- **When**: 点击播放
- **Then**: 视频正常播放、播放进度正常上报、续播位置正常同步
- **Verification**: 手动测试

### AC-5: 无用户 ID 时的降级行为
- **Given**: 某些罕见场景下 `userId` 为空（如测试环境）
- **When**: 调用 `getLibraries` 或 `getLibraryItems`
- **Then**: 应回退到当前的 `/Library/VirtualFolders` 或 `/Items` 端点，并记录警告日志，不应崩溃
- **Verification**: 代码 review + 单元测试

### AC-6: 最近添加功能正常
- **Given**: 用户的 Emby 服务器中有最近添加的视频
- **When**: 查看最近添加列表
- **Then**: 最近添加列表内容与 EmbyX 显示一致
- **Verification**: 代码 review + 实际环境测试

## Open Questions

- [ ] Q1: 是否需要在媒体库列表中展示 Playlist（播放列表）作为可选"媒体库"？EmbyX 有此功能，但当前 EmbyTok 没有。（默认不在本次修复范围内）
- [ ] Q2: 是否需要调整 `SortBy` 排序参数以更接近 EmbyX？EmbyX 默认按 `DateCreated,Descending`，而 EmbyTok 是 `DateCreated,SortName`。（默认保持当前值不变，除非用户反馈排序问题）
- [ ] Q3: `/Items/Latest` 的用户路径版本是 `/Users/{userId}/Items/Latest` 吗？需要在实际服务器上验证。（计划中采用后者）
