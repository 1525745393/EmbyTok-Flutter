# Emby 收藏分栏页面重构 - 产品需求文档

## Overview
- **Summary**: 将 EmbyTok Flutter 的收藏页面从单一列表重构为 Emby 官方风格的三栏布局，按类型展示"收藏影片 / 收藏合集 / 收藏人物"，并保持与 Emby 服务器的收藏状态实时同步。
- **Purpose**: 当前 `getFavorites` 接口将所有类型（Movie, Series, BoxSet, Person 等）混在一个扁平列表中，用户无法快速定位想看的内容。新设计将 Emby 原生收藏按类型分区展示，提供更接近 Emby 官方 App 的使用体验。
- **Target Users**: Emby 服务器用户，使用 EmbyTok Flutter 观看和管理自己的收藏媒体。

## Goals
- 收藏页面按类型分三个独立的横向滚动区："收藏影片"、"收藏合集"、"收藏人物"
- 三个分区的数据均来自 Emby 服务器的 `Filters: IsFavorite`，与服务器实时同步
- 保留现有双击/点击切换收藏状态的交互（红心动画、乐观更新、错误回滚）
- 不同类型的条目点击后跳转到对应的详情/播放页

## Non-Goals (Out of Scope)
- 不实现"首页 / 收藏"Tab 切换（当前项目不需要）
- 不引入本地持久化收藏（所有收藏数据始终从 Emby 服务器拉取）
- 不修改播放页、搜索页等其他模块的 UI
- 不实现收藏的离线缓存

## Background & Context

**现有实现分析** ([favorites_provider.dart](file:///workspace/frontend/lib/providers/favorites_provider.dart), [favorites_view.dart](file:///workspace/frontend/lib/views/favorites_view.dart)):

1. `favorites_provider.dart` 的 `loadFavorites` 调用 `EmbytokService.getFavorites`:
   ```dart
   final params = <String, dynamic>{
     'Limit': '$limit',
     'StartIndex': '$offset',
     'Recursive': 'true',
     'Filters': 'IsFavorite',          // ← 只有这一个过滤条件
     'Fields': 'Overview,...',
     'SortBy': 'DateCreated',
     'SortOrder': 'Descending',
   };
   // 发请求到 /Items
   ```
   **问题**: 不区分 `IncludeItemTypes`，返回的列表把 Movie / Series / BoxSet / Person 全部混在一起。

2. `favorites_view.dart` 是单一的 `ListView.separated` 展示所有条目，没有类型分组。

**参考设计**: 用户提供的 Emby 官方 App 截图展示了正确的信息架构：
- 收藏影片：卡片式横向滚动，海报缩略图 + 标题 + 年份
- 收藏合集（BoxSet）：卡片式横向滚动，合集封面 + 标题
- 收藏人物：圆形头像卡片 + 姓名

**Emby API 对应关系**:
- 收藏影片: `/Items` + `Filters: IsFavorite` + `IncludeItemTypes: Movie,Series,MusicVideo,Episode`
- 收藏合集: `/Items` + `Filters: IsFavorite` + `IncludeItemTypes: BoxSet`
- 收藏人物: `/Items` + `Filters: IsFavorite` + `IncludeItemTypes: Person` (或 `/Persons` + `Filters: IsFavorite`)
- 收藏状态切换: `POST /UserFavoriteItems/{itemId}` / `DELETE /UserFavoriteItems/{itemId}`

## Functional Requirements

### FR-1: 收藏数据按类型分离获取
- 新增 `EmbytokService` 三个方法：
  - `getFavoriteMovies({...})` → 影片
  - `getFavoriteBoxSets({...})` → 合集
  - `getFavoritePeople({...})` → 人物
- 三个请求使用相同的 `Filters: IsFavorite` 但不同的 `IncludeItemTypes`
- 保留原有 `getFavorites` 用于向后兼容（供视频页收藏状态判断使用）

### FR-2: FavoritesState 支持分栏数据
- `FavoritesState` 由 `List<MediaItem> items` 改为三组数据：
  - `List<MediaItem> movies` - 收藏影片
  - `List<MediaItem> boxSets` - 收藏合集
  - `List<MediaItem> people` - 收藏人物
  - `bool isLoading` / `String? error` / `Set<String> favoriteIds` 保持不变

### FR-3: 三栏横向滚动布局
- 收藏页面主体为 `SingleChildScrollView` + `Column`：
  - 每个分栏有 `分栏标题 + 数量 + 箭头`
  - 标题下是 `ListView.builder(scrollDirection: Axis.horizontal)`
  - 卡片样式：圆角 12px，带海报图 + 标题 + 年份/人名
  - 空状态：显示灰色占位卡片"还没有收藏影片/合集/人物"

### FR-4: 各类型点击行为
- 影片 (Movie/Series/MusicVideo/Episode): 跳转到播放页 (`_FavoritePlayPage`)
- 合集 (BoxSet): 跳转到合集详情页（新建，展示合集名称 + 包含的影片列表）
- 人物 (Person): 跳转到人员作品列表页（新建，展示人物头像 + 姓名 + 出演的作品列表）

### FR-5: 保留现有收藏切换交互
- 视频页双击画面 → 切换收藏 + 红心动画
- 视频页点击右侧按钮 → 切换收藏，图标颜色/填充实时变化
- 所有切换乐观更新 UI，服务器请求失败回滚

### FR-6: 自动拉取与账号隔离
- `FavoritesNotifier` 监听 `authProvider`，登录后自动拉取三栏数据
- 登出/切换账号时清空所有本地状态，防止展示上一账号数据

## Non-Functional Requirements

### NFR-1: 性能
- 三栏数据请求**并行**发出（使用 `Future.wait`），减少用户等待时间
- 列表滚动使用 `ListView.builder` 懒加载，不一次性创建所有卡片
- 图片使用 `Image.network` 带 errorBuilder，网络失败时降级为图标占位

### NFR-2: 健壮性
- 每个分栏独立处理错误和空状态，一个分栏失败不影响其他分栏
- 请求失败时在对应分栏显示"加载失败，点击重试"，不阻塞整个页面
- 保留现有 `_pendingToggles` 去重机制，防止快速连点产生重复请求

### NFR-3: UI 一致性
- 颜色方案与现有项目一致：主色 `Color(0xFFE91E63)`，背景纯黑 `Colors.black`
- 卡片圆角、间距、文字大小与其他页面保持一致
- 新页面（合集详情、人员作品列表）风格与主收藏页一致

### NFR-4: 兼容性
- Flutter 3.16+ 兼容（CI 使用 Flutter 3.24）
- 不引入新的第三方依赖
- 静态分析通过 `flutter analyze --no-pub lib`

## Constraints

- **Technical**: Flutter Riverpod 2.x 状态管理架构，保持现有 `FavoritesNotifier` 设计
- **API**: 必须使用 Emby 原生 API，不走自建后端
- **Data Model**: 所有条目继续使用 `MediaItem` 模型，不新建模型
- **Dependencies**: 仅允许使用 `pubspec.yaml` 中已声明的依赖
- **Version**: 版本号更新至 1.4.0（功能增强 + 结构变化）

## Assumptions

- Emby `/Items` 接口对 `IncludeItemTypes: Person` 返回的数据包含 `ImageTags.Primary`（人物头像）
- Emby `/Items` 接口对 `IncludeItemTypes: BoxSet` 返回的条目可通过 `Children` 接口获取包含的影片列表
- 用户的 Emby 服务器版本 ≥ 4.7，支持上述所有 API

## Acceptance Criteria

### AC-1: 三栏数据正确分离
- **Given**: 用户已登录 Emby 服务器
- **When**: 进入收藏页面
- **Then**: 页面顶部展示"收藏影片"、中间展示"收藏合集"、底部展示"收藏人物"三个分栏；每个分栏显示的条目类型正确（影片无 BoxSet，合集无 Movie，人物是头像卡片）
- **Verification**: `programmatic`
- **Notes**: 通过 `flutter test` 验证 `getFavoriteMovies/getFavoriteBoxSets/getFavoritePeople` 的 `IncludeItemTypes` 参数

### AC-2: 分栏空状态
- **Given**: 用户在 Emby 服务器上没有任何合集收藏
- **When**: 进入收藏页面，"收藏合集"分栏无数据
- **Then**: "收藏合集"分栏显示"暂无收藏合集"占位图/文字；其他分栏正常展示；整个页面仍然可用
- **Verification**: `human-judgment`

### AC-3: 点击跳转逻辑
- **Given**: 用户在收藏页面
- **When**: 点击影片卡片 → 进入播放页；点击合集卡片 → 进入合集详情；点击人物卡片 → 进入人员作品页
- **Then**: 三个目标页面均能正常打开并展示对应内容；返回键能正确回到收藏页
- **Verification**: `human-judgment`

### AC-4: 收藏状态实时同步
- **Given**: 用户在视频页双击切换某影片的收藏状态
- **When**: 返回收藏页面
- **Then**: 该影片在"收藏影片"分栏中出现/消失；`favoriteIds` Set 与服务器状态一致
- **Verification**: `programmatic`

### AC-5: 账号隔离
- **Given**: 用户 A 登出，用户 B 登录
- **When**: B 进入收藏页面
- **Then**: B 看到的是自己账号的收藏，不包含 A 的任何数据
- **Verification**: `programmatic`

### AC-6: CI 通过
- **Given**: 代码提交到 main 分支
- **When**: GitHub Actions 执行 `flutter analyze --no-pub lib`
- **Then**: 0 errors, 0 warnings
- **Verification**: `programmatic`

## Open Questions

- [ ] **人物头像 API**: Emby 对 `Person` 类型返回的 `ImageTags.Primary` 是否与 `MediaItem.thumbnailUrlWithAuth` 兼容？需要实测确认；如果不兼容，需要在 `MediaItem` 中添加人员头像 URL 构建逻辑。
- [ ] **合集子项 API**: `BoxSet` 类型是否可以通过 `getChildren(boxSetId)` 获取其包含的影片？如果返回的 `Children` 接口需要额外权限，需要在合集详情页做降级处理。
- [ ] **横向滚动卡片数量**: 每栏首次加载默认显示多少条？是否需要"查看全部"按钮进入完整列表页？参考截图每栏至少显示 5~8 张卡片，后续可加。
