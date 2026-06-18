# Emby 收藏/点赞功能修复 - Product Requirement Document

## Overview
- **Summary**: 修复项目中 "点赞/收藏" 功能无法正常工作的问题。参考 EmbyX 的实现，确保在任意 Emby 服务器上，用户点击心形或星形图标后能正确向服务器上报收藏状态，且图标状态能立即反映到 UI 上。
- **Purpose**: 用户反馈 EmbyX 中可以正常收藏/点赞，但本项目不行。这是一个核心交互功能，影响用户体验和内容管理。
- **Target Users**: Emby 媒体库用户（电影、剧集、家庭视频/音乐视频等内容的播放者和收藏者）。

## Goals
1. **收藏功能可用**：点击视频播放页面的"收藏"按钮能成功向 Emby 服务器上报，并立即更新图标状态
2. **点赞功能可用**：双击视频或点击"点赞"图标能立即触发收藏切换，并显示心跳动画
3. **状态一致性**：服务器返回的收藏状态应与本地 UI 状态保持一致
4. **跨页面同步**：切换视频或切换页面后，已收藏的视频应继续显示为已收藏状态
5. **支持所有内容类型**：电影、剧集、音乐视频、家庭视频 (Video) 都能正确收藏

## Non-Goals (Out of Scope)
1. 不新增本地-only 的"点赞"数据模型（仅修复现有功能，不引入新的本地持久化方案）
2. 不引入 Emby Playlist / Collection 作为替代收藏机制
3. 不修改收藏数据的 Cloud Sync 方案（仅保持 Emby 服务器侧的收藏状态）
4. 不改变 UI 布局（仅修复图标点击不生效/状态不更新的问题）

## Background & Context

### 当前实现架构
项目通过 `EmbytokService` 与 Emby 原生 API 交互。收藏功能由三层组成：

1. **UI 层** (`lib/widgets/video_page_item.dart`、`gesture_overlay.dart`):
   - `video_page_item.dart` 右侧操作栏：心形(❤️ "点赞")和星形(⭐ "收藏")图标
   - `gesture_overlay.dart`：双击视频触发动画并收藏

2. **状态管理层** (`lib/providers/favorites_provider.dart`):
   - `FavoritesState`：维护 `favoriteIds` Set、`movies`/`boxSets`/`people` 三个列表、loading/error 状态
   - `FavoritesNotifier`：管理 `loadFavorites()` 和 `toggleFavorite()`

3. **服务层** (`lib/services/embbytok_service.dart`):
   - `toggleFavorite()`：调用 `/Users/{userId}/FavoriteItems/{itemId}` (POST=收藏 / DELETE=取消)
   - `getFavoriteMovies()` / `getFavoriteBoxSets()` / `getFavoritePeople()`：通过 `Filters: IsFavorite` 查询收藏列表

### 已识别问题

#### 问题 1: `favorites_provider` 创建独立的 `EmbytokService` 实例，丢失 `_defaultUserId`

`favorites_provider.dart` 中：
```dart
FavoritesNotifier(this._ref, {EmbytokService? service})
    : _service = service ?? EmbytokService(),  // ← 新实例！
```

这导致 FavoritesNotifier 内部的 `_service._defaultUserId == null`。

在 `embbytok_service.dart` 的 `toggleFavorite` 中：
```dart
final uid = _defaultUserId ?? '';
final path = uid.isNotEmpty
    ? '/Users/$uid/FavoriteItems/$itemId'   // ✅ 正确路径
    : '/UserFavoriteItems/$itemId';         // ⚠️ 回退路径（可能被部分服务器拒绝）
```

当 `_defaultUserId` 为空时，API 使用了回退路径 `/UserFavoriteItems/$itemId`，这在某些 Emby 服务器上不会正确关联到用户的收藏列表。

**影响范围**：所有 `toggleFavorite()` 调用，以及 `getFavoriteMovies()` 等列表拉取。

#### 问题 2: `loadFavorites()` 触发条件不足，可能从未被调用

`favoritesProvider.notifier.loadFavorites()` 的触发路径：
- `FavoritesView` 页面的 `initState` 中调用 ✅
- 登录时 `authProvider` 状态变化 → `FavoritesNotifier` 内部监听 ✅

**缺失的场景**：
- 用户直接进入首页（feed）→ 视频播放 → 点击心形图标。此时：
  1. `toggleFavorite()` 被调用 → API 上报（假设成功）
  2. 但 `loadFavorites()` 可能从未被调用 → `favoriteIds` 为空
  3. `video_page_item.dart` 中的 `favorited = ref.watch(favoritesProvider).favoriteIds.contains(item.id)` → 返回 false
  4. → 图标永远显示为"未收藏"状态（即使用户已点击）

**表现**：点击图标后短暂有心跳动画，或图标瞬间变亮后立即恢复。服务器可能已保存收藏状态，但 UI 显示不正确。

#### 问题 3: `IncludeItemTypes` 缺失 `'Video'` 类型，导致 Home Video 内容不显示

在 `getFavoriteMovies()` 中：
```dart
'IncludeItemTypes': 'Movie,Series,MusicVideo,Episode',
```

Emby 中**普通视频文件**（如 Home Video 类型）的 `Type` 字段是 `'Video'`（不是 `Movie`）。上述过滤条件会排除所有普通视频。

**影响**：用户点击普通视频后，图标显示为"未收藏"；即便收藏了，重新加载列表时普通视频不会出现在收藏列表中。

#### 问题 4: `video_page_item.dart` 中两个图标调用同一 `toggleFavorite`

```dart
// 心形图标：标记为"点赞"
_buildActionButton(
  favorited ? Icons.favorite : Icons.favorite_border,
  '点赞',
  color: favorited ? primaryPink : textPrimary,
  onTap: () => ref.read(favoritesProvider.notifier).toggleFavorite(widget.item),
),
// 星形图标：标记为"收藏"
_buildActionButton(
  favorited ? Icons.star : Icons.star_border,
  '收藏',
  color: favorited ? amberColor : textPrimary,
  onTap: () => ref.read(favoritesProvider.notifier).toggleFavorite(widget.item),
),
```

两者都调用 `toggleFavorite()`，导致：
1. 两者图标都绑定到同一状态 → 点击一个会同时改变另一个的图标
2. 语义混乱（"点赞" 和 "收藏" 本应是不同语义，这里做同一件事）
3. 用户可能反复点击两个图标，服务器状态可能进入不一致

## Functional Requirements

### FR-1: 收藏状态正确上报到 Emby 服务器
- 用户点击"收藏"按钮后，向 Emby `/Users/{userId}/FavoriteItems/{itemId}` 发送正确的 HTTP 请求（POST=收藏 / DELETE=取消）
- 必须**始终**使用带 `userId` 的路径（`/Users/{userId}/...`），不使用无 `userId` 的回退路径
- API 调用失败时应向用户提供错误反馈（snackbar 或 toast）

### FR-2: 收藏状态立即响应并持久显示
- 点击后图标立即切换为"已收藏"状态（乐观更新）
- 即使用户跳过 `FavoritesView` 页面（从未显式调用 `loadFavorites()`），图标状态也应正确
- 切换到其他视频再切换回来，状态应保持一致
- **来源优先级**：优先使用 `favoritesProvider.favoriteIds`；若 item 本身带 `userData.isFavorite`，也应同步更新

### FR-3: 支持所有 Emby 内容类型的收藏
- Movie（电影）、Episode（剧集）、MusicVideo（音乐视频）、Video（普通视频/家庭视频）、BoxSet（合集）、Person（演员）
- `getFavoriteMovies()` 的 `IncludeItemTypes` 应包含 `'Video'`

### FR-4: 图标语义清晰 — 区分"点赞"与"收藏"
- 心形（❤️）与星形（⭐）图标应：
  - **方案 A**（推荐）：两者都做 Emby 收藏（同一件事），但心形显示为"点赞交互"，星形为"正式收藏"——即使用户点击的是心形，底层也调用同一个服务器 API，两个图标显示相同的状态（因为它们共享同一 `favorited` 数据源）
  - **但图标不应互相干扰**：若两者都绑到同一 `favorited` 值，逻辑上是正确的，只需确保状态一致

### FR-5: 双击视频触发收藏（TikTok 风格）
- 在视频播放页，双击画面时：
  - 显示心形动画（`heart_animation.dart`）
  - 同时触发 `toggleFavorite` 切换状态
- 单次点击应显示/隐藏播放控件栏，不触发收藏

### FR-6: `favoritesProvider` 使用与认证流程共享的 `EmbytokService` 实例
- `FavoritesNotifier` 不应再创建独立的 `EmbytokService()` 实例
- 应通过 `ref` 或外部注入获取全局唯一的、经过 `setupAuth` 配置的 service，确保 `_defaultUserId` 正确

## Non-Functional Requirements

### NFR-1: 响应性
- 点击收藏按钮后，图标变化延迟应 < 200ms（乐观更新实现）
- 网络失败时的错误反馈应 < 3s

### NFR-2: 健壮性
- 网络失败时进行乐观更新回滚（已部分实现，需验证）
- 同一 itemId 的快速重复点击应自动合并（已通过 `_pendingToggles` 去重，需验证）
- `_defaultUserId` 缺失时应显式错误提示，而非静默使用可能失效的回退路径

### NFR-3: 代码一致性
- 所有 `IncludeItemTypes` 字段的值统一：视频列表和收藏列表使用同一值集 `'Movie,Episode,Video,MusicVideo'`
- 所有 `get*` 方法的 API 路径统一：`/Users/{userId}/Items` 替代 `/Items`

### NFR-4: 向后兼容
- 修改不得破坏其他页面（feed_view / search_view / favorites_view）
- 无 `userId` 场景（如某些测试环境）应抛出清晰错误，而非静默失败

## Constraints
- **技术约束**：使用现有 Flutter + Riverpod 架构，不引入新的状态管理方案
- **API 约束**：仅使用 Emby 原生 API，不引入 EmbyX 的自定义 API 包装
- **数据约束**：不改变 `MediaItem` 模型的字段（但可补充 `userData` 字段的使用）
- **UI 约束**：保持当前 TikTok 风格布局，仅修复点击逻辑

## Assumptions
1. Emby 服务器的 `/Users/{userId}/FavoriteItems/{itemId}` 端点是收藏功能的正确路径（参考 EmbyX 的实现）
2. Emby 服务器返回的 `UserData.IsFavorite` 字段反映了该用户的收藏状态
3. 项目中 `favoritesProvider` 作为单一数据源管理收藏状态是合理的
4. 双击视频即收藏是 TikTok 风格应用的标准交互

## Acceptance Criteria

### AC-1: 点击收藏/点赞图标能正确上报服务器
- **Given**: 用户已登录到 Emby 服务器
- **When**: 用户点击视频播放页面右侧的"心形"或"星形"图标
- **Then**: 
  1. 图标立即切换（空 ↔ 实心）
  2. 向 `POST /Users/{userId}/FavoriteItems/{itemId}` 或 `DELETE ...` 发送请求
  3. API 调用的 `userId` 与登录用户 ID 一致
  4. 服务器响应 200 OK（或等价成功状态）
- **Verification**: `programmatic` — 检查 API 请求路径包含 `/Users/{userId}/...`；`human-judgment` — 在 Emby 服务器管理面板确认收藏状态已同步

### AC-2: 收藏状态持久显示（不依赖 favoritesView 预加载）
- **Given**: 用户直接进入首页 → 选择视频 → 进入播放页（从未打开过 FavoritesView）
- **When**: 用户点击收藏图标
- **Then**: 图标状态从空心变为实心，并在以下场景保持一致：
  1. 切换到下一个视频再切换回来
  2. 退出播放页返回首页 → 再次进入同一视频
  3. 关闭并重新打开 App 后，同一视频仍显示为已收藏（若服务器保存了收藏状态）
- **Verification**: `human-judgment` — 通过真实设备操作验证

### AC-3: 所有内容类型（含 Home Video）均能正确收藏
- **Given**: 媒体库包含电影、剧集、音乐视频、普通视频
- **When**: 用户在任意类型视频的播放页点击收藏图标
- **Then**: 图标状态正确切换；在 FavoritesView 页面该视频出现在收藏列表中
- **Verification**: `programmatic` — `getFavoriteMovies()` 的 `IncludeItemTypes` 包含 `'Video'`；`human-judgment` — 验证列表中出现普通视频

### AC-4: 双击视频触发收藏与动画
- **Given**: 用户在视频播放页
- **When**: 用户双击视频画面（不在图标区域）
- **Then**: 画面中央显示心形动画，同时触发 `toggleFavorite` 切换状态
- **Verification**: `human-judgment`

### AC-5: 并发点击防护
- **Given**: 用户快速连续点击收藏图标
- **When**: 连续点击 < 5 次
- **Then**: 只产生一次服务器 API 调用（而不是 5 次），图标状态稳定（不抖动）
- **Verification**: `programmatic` — 查看日志或网络请求数量

### AC-6: API 路径始终包含 userId
- **Given**: 用户已登录（有 userId）
- **When**: 任意收藏相关 API 调用（收藏/取消/拉取收藏列表）
- **Then**: 请求路径格式为 `/Users/{userId}/...`（如 `/Users/123/FavoriteItems/456`），而非 `/UserFavoriteItems/456`
- **Verification**: `programmatic` — 检查代码中是否移除了无 userId 的回退路径，或确保 `_defaultUserId` 始终被设置

### AC-7: 错误反馈
- **Given**: 用户在视频播放页点击收藏图标，但网络不通或服务器返回错误
- **When**: API 调用失败
- **Then**: 
  1. 图标状态回滚到点击前状态（乐观更新回滚）
  2. 向用户显示简洁错误信息（如"收藏失败，请检查网络"）
- **Verification**: `human-judgment` — 断网后测试收藏功能

### AC-8: favoritesProvider 中的 EmbytokService 与认证流程一致
- **Given**: 用户通过登录流程获取了 userId 和 accessToken
- **When**: `favoritesProvider.notifier.toggleFavorite()` 被调用
- **Then**: Service 内部使用的 `_defaultUserId`、`_defaultServerUrl`、`_defaultToken` 与认证流程中设置的值一致
- **Verification**: `programmatic` — 代码中确认 `FavoritesNotifier` 不再创建新的 `EmbytokService()` 实例

## Open Questions
- [ ] Q1: 是否需要区分"点赞"和"收藏"为两个独立概念？（当前两者都调用 `toggleFavorite`，功能上无问题但 UX 上可能有混淆）
- [ ] Q2: 是否需要在 `FavoritesView` 页面长按某个条目可取消收藏？（当前只能通过播放页按钮或图标切换）
- [ ] Q3: 双击收藏后，是否需要额外的"已收藏"视觉反馈（如 toast）？（当前依赖图标切换）
