# 收藏功能（点赞/双击红心）- Product Requirement Document

## Overview
- **Summary**: 在 EmbyTok Flutter 视频播放应用中实现完整的收藏功能：双击画面触发红心动画并切换收藏状态，右侧操作按钮提供点赞/收藏入口，收藏列表页展示与管理已收藏的媒体项。
- **Purpose**: 让用户可以快速标记喜欢的视频并在后续集中回看，提升内容消费体验。
- **Target Users**: Emby 家庭媒体库的消费者（移动端/竖屏短视频浏览风格）。

## Goals
- 用户在视频播放页双击屏幕即可"点赞/收藏"视频，并看到醒目的红心动效反馈。
- 用户可在右侧操作按钮区看到收藏状态（空心/实心）并点击切换。
- 用户可在"我的收藏"页查看全部已收藏视频，并跳转播放或左滑删除。
- 状态持久化到 Emby 服务器（UserFavoriteItems 接口），多端一致。
- Flutter 静态分析通过，代码风格统一。

## Non-Goals (Out of Scope)
- 不实现"本地离线收藏"（未登录时的收藏）；未登录状态下收藏按钮禁用。
- 不实现"点赞与收藏分离"（两者映射同一 Emby `IsFavorite` 字段以简化用户心智）。
- 不实现"评论 / 分享 / 转发"等社交功能（仅保留占位 UI）。
- 不实现服务端收藏推荐算法。

## Background & Context
- 现有代码已存在基础骨架：
  - `favorites_provider.dart`：`FavoritesNotifier` + `favoritesProvider`（StateNotifierProvider）
  - `gesture_overlay.dart`：单击/双击/长按/水平拖动手势层，内部有 `_FlyingHeart` 小部件
  - `video_page_item.dart`：右侧操作按钮含 `Icons.favorite` 与 `Icons.star`
  - `favorites_view.dart`：列表页 + `_FavoriteTile`
  - `embbytok_service.dart`：`getFavorites` / `toggleFavorite` 已对接 Emby 原生 API
- 需要改进点：
  1. `favoritesProvider` 未在应用启动时自动拉取一次收藏，导致 `isFavorite` 初次判定为空。
  2. `VideoPageItem` 中 `favorited` 仅在 init 时读一次，未随 provider 状态变化响应式更新。
  3. `GestureOverlay` 双击动画使用 `setState` + `_showHeart`，缺少"300ms 内重复双击防抖"，可能导致重复 API 请求。
  4. 右侧操作按钮缺少"按下缩放"动画，交互反馈不够明显。

## Functional Requirements

### FR-1: 双击画面切换收藏
- 视频播放页（`VideoPageItem`）内叠加 `GestureOverlay` 层处理手势。
- 区分单击（播放/暂停）与双击：300ms 内第 2 次点击 → 判定为双击。
- 双击时：
  1. 调用 `ref.read(favoritesProvider.notifier).toggleFavorite(item)`
  2. 屏幕中心显示红心动效（放大 2.8x + 渐隐，~700ms）
  3. 若当前处于收藏状态 → 切换为取消收藏；反之亦然。
- 300ms 内重复双击忽略，避免重复调用 API（防抖）。

### FR-2: 右侧操作按钮
- 展示 4 个按钮（静音 / 点赞 / 收藏 / 分享）；本版本中"点赞"与"收藏"共享同一 Emby 收藏状态，UI 上均反映 `isFavorite`。
- 点赞按钮：
  - 未收藏 → `Icons.favorite_border`（白色，32px）
  - 已收藏 → `Icons.favorite`（粉色 `0xFFE91E63`，32px）
  - 点击时 120ms 缩放到 0.8 再回弹（`AnimatedScale`）
- 收藏按钮：
  - 未收藏 → `Icons.star_border`（白色）
  - 已收藏 → `Icons.star`（琥珀色 `Colors.amber`）
- 点击任一按钮均调用 `toggleFavorite`。

### FR-3: 收藏列表页
- 入口通过 `FavoritesView` 路由（已存在）。
- 进入页面时自动调用 `loadFavorites`；下拉刷新支持（可选）。
- 每条 `_FavoriteTile` 展示：
  - 缩略图（`thumbnailUrlWithAuth`）
  - 标题 + 年份
  - 类型标签（Movie / Series / MusicVideo）
  - 时长
  - 简介（首行，最多 1 行）
- 左滑显示删除区，点击删除（调用 `toggleFavorite` 取消收藏）。
- 空状态：居中显示 `Icons.favorite_border`（80px，白色半透明）+ "还没有收藏 / 双击视频即可收藏 💖"。
- 加载中：`CircularProgressIndicator`（粉色 `0xFFE91E63`）。
- 错误状态：`Icons.error_outline` + 错误消息 + "重试"按钮（点击再次 `loadFavorites`）。

### FR-4: 状态管理与同步
- `favoritesProvider`（StateNotifierProvider）管理：
  - `items: List<MediaItem>`
  - `favoriteIds: Set<String>`（O(1) 判定）
  - `isLoading: bool`
  - `error: String?`
- `toggleFavorite` 采用乐观更新：先本地反转 favoriteIds/items，再发 POST/DELETE，失败回滚并设置 error。
- 提供 `isFavorite(id) -> bool` 便捷方法。
- 应用启动/登录后，provider 自动懒加载一次收藏列表（`ref.watch` 首次调用时懒加载）。

## Non-Functional Requirements
- **NFR-1 性能**: 双击到动画开始 < 16ms；`toggleFavorite` 乐观更新 UI 无感知延迟。
- **NFR-2 健壮性**: 网络失败自动回滚 UI 状态，绝不出现"UI 显示已收藏 / 服务端实际未收藏"的不一致。
- **NFR-3 可维护性**: `flutter analyze --no-pub lib` 无 warning/error；公共 API 含 doc 注释。
- **NFR-4 交互一致性**: 所有动画时长、颜色、字号与项目已有规范一致（粉色 `0xFFE91E63`，动效 700ms）。

## Constraints
- Flutter 3.10+ / Dart 3.x；仅使用已引入的依赖（`flutter_riverpod`, `video_player`, `dio` 等）。
- 直接对接 Emby 原生 API（`/UserFavoriteItems/{itemId}` POST/DELETE，`/Items?Filters=IsFavorite`），不经过后端 `/api/favorites` 代理（保持与项目其他模块一致的直连风格）。
- Android / iOS / Web 均需通过编译。

## Assumptions
- 用户已登录 Emby 并获取到有效的 `X-Emby-Token`。
- Emby 服务器对 `UserFavoriteItems` 接口启用写权限（通常默认开启）。
- 同一用户在多设备上以同一 Emby 用户身份登录，因此 `favoriteIds` 在多端通过服务器同步。

## Acceptance Criteria

### AC-1: 双击画面收藏与动效（human-judgment + programmatic）
- **Given**: 用户进入 `VideoPageItem` 播放某个视频
- **When**: 300ms 内快速双击视频画面
- **Then**:
  1. 屏幕中心出现红心 `Icons.favorite`（粉色，约 120px），从 0.6x 放大至 2.8x 并在 700ms 内渐隐
  2. 该视频的 `isFavorite` 状态切换为相反值
  3. 右侧点赞/收藏按钮图标同步更新为实心样式
  4. 300ms 内的重复双击不产生额外 API 请求（programmatic：在 `toggleFavorite` 处增加计数器断言）
- **Verification**: 手动测试 + widget 测试模拟双击事件并检查 provider state 变化

### AC-2: 右侧按钮反映并控制收藏状态（human-judgment + programmatic）
- **Given**: 用户已打开 `VideoPageItem`
- **When**: 用户点击右侧"点赞"或"收藏"按钮
- **Then**: `favoritesProvider.favoriteIds` 包含/移除该 `item.id`；图标颜色与填充状态与 `isFavorite` 保持一致
- **Verification**: Riverpod 测试 `expectLater` + 视觉检查

### AC-3: 收藏列表页正确展示与操作（human-judgment）
- **Given**: 用户至少收藏过 1 个视频
- **When**: 用户进入"我的收藏"页
- **Then**: 看到以 `DateCreated` 降序排列的收藏条目，点击条目可播放，左滑条目可取消收藏
- **Verification**: 手动测试 + 若有 Mock，可测试 `loadFavorites` 后 `state.items.length > 0`

### AC-4: Flutter 静态分析通过（programmatic）
- **Given**: 本次改动的所有文件
- **When**: 执行 `flutter analyze --no-pub lib`
- **Then**: 0 issues，无 `undefined_method`、`prefer_const_constructors`、`unawaited_futures` 等告警
- **Verification**: CI 脚本 + 本地运行

### AC-5: 空状态 / 错误状态正确（human-judgment）
- **Given**: 用户无任何收藏，或 Emby 服务器返回错误
- **When**: 打开收藏列表页
- **Then**: 分别显示空状态插图 + 提示，或错误图标 + 消息 + 重试按钮
- **Verification**: 手动测试

## Open Questions
- [ ] 产品上是否需要后续将"点赞"和"收藏"拆为两个独立状态？（当前 PRD 中两者统一映射为 `IsFavorite`）
- [ ] 是否需要在 `VideoPageItem` 中增加"长按快进"的倍速值可配置项（目前为 2x）？（与收藏功能非直接相关，记录但不阻塞本次开发）
