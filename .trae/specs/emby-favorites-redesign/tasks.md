# Emby 收藏分栏页面重构 - 实施计划（分解任务清单）

> **依赖图**: 任务 1 → 任务 2 → 任务 3 → 任务 4
> 所有任务共享同一个底层 Provider 变化（任务 2 完成后，UI 任务可以并行，但为了简化，这里按顺序组织）

## Task 1: EmbytokService 新增三个按类型获取收藏的方法
- **Priority**: P0
- **Depends On**: None
- **Description**:
  - 在 `embbytok_service.dart` 中新增三个方法：
    1. `getFavoriteMovies({int limit, int offset, String? serverUrl, String? token})`
       - `IncludeItemTypes: 'Movie,Series,MusicVideo,Episode'` + `Filters: 'IsFavorite'`
    2. `getFavoriteBoxSets({int limit, int offset, String? serverUrl, String? token})`
       - `IncludeItemTypes: 'BoxSet'` + `Filters: 'IsFavorite'`
    3. `getFavoritePeople({int limit, int offset, String? serverUrl, String? token})`
       - `IncludeItemTypes: 'Person'` + `Filters: 'IsFavorite'`
  - 三个方法的返回类型均为 `Future<List<MediaItem>>`
  - 共享相同的 `Fields`：`'Overview,Genres,CommunityRating,RunTimeTicks,ProductionYear,ImageTags,UserData'`
  - 保留现有 `getFavorites` 方法（向后兼容，供视频页收藏状态判断使用）
- **Acceptance Criteria Addressed**: AC-1, AC-6
- **Test Requirements**:
  - `programmatic` TR-1.1: 编译通过，`flutter analyze` 无错误
  - `programmatic` TR-1.2: 三个方法均正确传入 `Filters: 'IsFavorite'` 和不同的 `IncludeItemTypes`
  - `human-judgment` TR-1.3: 代码审查确认三个方法结构一致，与现有 `getFavorites` 风格一致
- **Notes**: 对于 `Person` 类型，`ImageTags.Primary` 可能存在但与影片的不同，需要确保 `MediaItem.thumbnailUrlWithAuth` 能正确生成头像 URL

## Task 2: FavoritesNotifier 重构 - 支持三栏数据 + 并行请求
- **Priority**: P0
- **Depends On**: Task 1
- **Description**:
  - 修改 `FavoritesState`：
    ```dart
    class FavoritesState {
      final List<MediaItem> movies;        // 新增
      final List<MediaItem> boxSets;       // 新增
      final List<MediaItem> people;        // 新增
      final bool isLoading;
      final String? error;
      final Set<String> favoriteIds;       // 保留，供视频页快速判断
    }
    ```
  - 新增 `FavoritesState copyWith({...})` 方法
  - 修改 `loadFavorites`：
    - 使用 `Future.wait([getFavoriteMovies(), getFavoriteBoxSets(), getFavoritePeople()])` 并行请求
    - 成功后用三个列表构造新 state，并合并 `favoriteIds`
    - 失败时 state.error 记录错误信息，但仍展示已获取的数据
  - 保留 `toggleFavorite` 的乐观更新 + 失败回滚逻辑
  - 保留 `isFavorite(String itemId)` 快速查询
  - 保留 `reset()` 账号切换清理
  - 保留 `_pendingToggles` 去重机制
- **Acceptance Criteria Addressed**: AC-1, AC-4, AC-5, AC-6
- **Test Requirements**:
  - `programmatic` TR-2.1: `FavoritesState.favoriteIds` 是三组列表 `id` 的并集
  - `programmatic` TR-2.2: `isFavorite` 能正确判断任意类型条目的收藏状态
  - `human-judgment` TR-2.3: 代码审查确认 `Future.wait` 并行请求正确，错误处理不阻塞其他数据
- **Notes**: `favoriteIds` 需要从三个列表合并，用于视频页/列表页快速显示收藏状态

## Task 3: 重构收藏页面 UI - 三栏横向滚动布局
- **Priority**: P0
- **Depends On**: Task 2
- **Description**:
  - 重写 `favorites_view.dart`，将 `ListView.separated` 改为：
    - `Scaffold` + `AppBar`（保持现有标题和刷新按钮）
    - `SingleChildScrollView` + `Column` 主体
    - 每个分栏：
      - `Padding` → `Row(mainAxisAlignment: MainAxisAlignment.spaceBetween)` + `Text('收藏影片  >')`
      - `SizedBox(height: 16)`
      - `SizedBox(height: 200)` → `ListView.builder(scrollDirection: Axis.horizontal)`
      - 卡片：`Container(decoration: rounded + white10 border)` + `Image.network` + `Text`
      - 卡片宽度 ~ 120px，高度固定 180px
      - 底部显示标题（最大 2 行 + ellipsis），可能显示年份
    - 三个分栏之间间距 `SizedBox(height: 24)`
  - 加载状态：整页 `Center(child: CircularProgressIndicator(color: Color(0xFFE91E63)))`
  - 空状态：某分栏为空时，在该位置显示灰色占位文字"暂无收藏影片/合集/人物"
  - 收藏状态变化触发的重绘通过 `ref.watch(favoritesProvider)` 实现
- **Acceptance Criteria Addressed**: AC-1, AC-2, AC-4, AC-6
- **Test Requirements**:
  - `programmatic` TR-3.1: `flutter analyze` 通过，无 `undefined_method` 等错误
  - `human-judgment` TR-3.2: UI 审查 — 卡片风格、颜色、间距与整体项目一致
  - `human-judgment` TR-3.3: 三个分栏滚动互不干扰，横向滚动流畅
- **Notes**: 人物卡片可以用圆形头像或圆角矩形，保持视觉一致性；影片/合集卡片用矩形封面

## Task 4: 新增两个详情页面 - 合集详情 + 人员作品页
- **Priority**: P1
- **Depends On**: Task 3
- **Description**:
  - **4a 合集详情页 (`BoxSetDetailView`)**:
    - 从收藏页点击合集卡片时跳转
    - 顶部显示合集封面图（大尺寸，宽高比 16:9）
    - 标题 + 简介（`Overview`）
    - 下方显示包含的影片列表：通过 `getChildren(boxSetId)` 获取
    - 影片列表样式与现有项目一致，点击跳转到播放页（`_FavoritePlayPage`）
  - **4b 人员作品页 (`PersonWorksView`)**:
    - 从收藏页点击人物卡片时跳转
    - 顶部显示人员头像（圆形或圆角矩形）+ 姓名 + 简介
    - 下方显示该人员出演的作品列表：通过 `getPersonItems(personId)` 获取
    - 作品列表样式与合集详情页一致
  - 两个新页面的风格（颜色、圆角、间距）与收藏页一致
- **Acceptance Criteria Addressed**: AC-3, AC-6
- **Test Requirements**:
  - `programmatic` TR-4.1: `flutter analyze` 通过
  - `human-judgment` TR-4.2: 新页面能正确从 Emby 加载内容并展示
  - `human-judgment` TR-4.3: 返回导航正确（返回键 → 收藏页）
- **Notes**: 如果 `BoxSet` 的 `Children` 接口需要特殊权限或返回空数据，需要降级显示"暂无数据"；同理对人员作品列表

## Task 5: 版本号 + CHANGELOG 更新
- **Priority**: P2
- **Depends On**: Task 4
- **Description**:
  - 更新 `frontend/pubspec.yaml` 版本号: `1.4.0`
  - 更新 `CHANGELOG.md`: 新增 `[1.4.0]` 条目，描述三栏收藏页面重构、新详情页
- **Acceptance Criteria Addressed**: AC-6
- **Test Requirements**:
  - `programmatic` TR-5.1: `pubspec.yaml` 和 `CHANGELOG.md` 版本号一致
  - `human-judgment` TR-5.2: CHANGELOG 条目清晰描述了改动范围

## 实现优先级总结

| 优先级 | 任务 | 核心价值 |
|---|---|---|
| P0 | Task 1, 2, 3 | 核心功能 — 三栏收藏页面 |
| P1 | Task 4 | 功能增强 — 详情页点击跳转 |
| P2 | Task 5 | 版本管理 — 发布前准备 |

**建议工作流**: Task 1 → Task 2 → Task 3 是一个连续的完整 MVP（功能可用），  
Task 4 是增量增强，可以作为第二阶段。
