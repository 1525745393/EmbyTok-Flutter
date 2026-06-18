# Emby 收藏/点赞功能修复 - Implementation Plan (Task List)

## [ ] Task 1: 确保 `favorites_provider` 使用的 Service 与认证流程共享同一实例
- **Priority**: P0 — 这是收藏功能的根因问题
- **Depends On**: None
- **Description**:
  - 修改 `FavoritesNotifier` 不再创建独立的 `EmbytokService()` 实例
  - 改为通过构造函数注入或通过 `ref.watch` 获取与 `_defaultUserId`
  - 核心改动：
    1. `favorites_provider.dart` L80 构造函数
    2. `favorites_provider.dart` L230-L235 `toggleFavorite` 调用时传 `userId` 到 service
- **Acceptance Criteria addressed**: AC-1, AC-6, AC-8
- **Implementation Approach**:
  - **方案 A（推荐）：让 `favoritesProvider` 的 `toggleFavorite` 调用时显式传 `userId` 从 `auth` 状态读取
  - **方案 B**（备选）**：让 `EmbytokService` 改为单例，全局服务
- **Steps**:
  1. 检查 `auth_provider.dart`：确认 `userId` 在 `AuthState` 中有 `user?.id`
  2. 修改 `favorites_provider.dart`：在 `toggleFavorite()` 中，将 `userId` 从 `auth` 中读取，并将 `auth.user?.id` 显式传参到服务调用（*
  3. 修改 `embbytok_service.dart`：`toggleFavorite` 方法签名新增 `{String? userId}`，路径由 `_defaultUserId` 改为优先使用传入 `userId` 传参
  4. 同步修改 `favorites_provider.dart` 中 `loadFavorites()` 方法：确保 `userId` 传参时显式传入 service
  5. 同样的，`FavoritesService` 中的 `FavoritesService`：同样需要修改 `favorites_service_provider.dart` 中构造时的方法中

- **Key Code Location**: `lib/providers/favorites_provider.dart L75-L80 和 lib/services/embbytok_service.dart L725-L748
- **Test Requirements**:
  - `programmatic` TR-1.1: `toggleFavorite` 调用时，请求路径为 `/Users/{userId}/FavoriteItems/{itemId}`格式（不是 `/UserFavoriteItems/{itemId}`
  - `programmatic` TR-1.2: `getFavoriteMovies()` 调用时使用同样使用同样传参 `userId`
  - `human-judgment` TR-1.3: 代码检查 FavoritesNotifier 不再创建新的 `EmbytokService()` 实例
- **Notes**: 此任务必须先完成，其他任务依赖此任务完成后再同步 `includeItemTypes 才能修复。

## [ ] Task 2: 在 `video_page_item.dart` 中确保 `favoritesProvider` 在进入播放页时确保 `ensureLoaded()`，不依赖 `FavoritesView`
- **Priority**: P0 — 修复"图标状态不更新问题
- **Depends On**: Task 1
- **Description**:
  - `video_page_item.dart` 的 `favorited` 依赖 `favoritesProvider`
  - 但 `favoritesProvider` 的 `favoriteIds` 是 `Set<String>`
  - 如果从未调用 `loadFavorites()` 则永远是空
  - 方案：在 `video_page_item.dart` 的 `initState` 或 `build` 中首次调用 `ref.read(favoritesProvider.notifier).ensureLoaded()`，确保即使用户直接跳过 `FavoritesView` 也能保证 `favoriteIds 加载
- **Acceptance Criteria Addressed**: AC-2
- **Implementation Approach**:
  - 在 `video_page_item.dart` 中 `video_page_item 的 `initState` 中调用
  - 或者在 `build` 方法中 `ref.read(favoritesProvider.notifier).ensureLoaded()
- **Key Code Location**: `lib/widgets/video_page_item.dart` L240-L250 附近（依赖具体位置
- **Test Requirements**:
  - `programmatic` TR-2.1: 从未打开 `FavoritesView` 之前，直接进入播放页后，`favoritesProvider.favoriteIds` 不为空
  - `human-judgment` TR-2.2: 点击收藏后图标立即改变并持久
- **Notes**: `ensureLoaded()` 已实现已已在 `favorites_provider.dart` L105-L108

## [ ] Task 3: 统一所有 `IncludeItemTypes` 值 — 统一为 `'Movie,Episode,Video,MusicVideo'` 统一值
- **Priority**: P1 — 修复 Home Video 内容类型
- **Depends On**: Task 1
- **Description**:
  - `getLibraryItems()`: `'Movie,Series,MusicVideo,Episode,Movie,Episode,Video,MusicVideo` — 补充 `'Video'`
  - `getFavoriteMovies()`: `'Movie,Series,MusicVideo,Episode,Movie,Episode,Video,MusicVideo` — 补充 `'Video'`
  - `getRecentlyAdded()`: 同样修正同样的
- **Acceptance Criteria addressed**: AC-3
- **Implementation Approach**:
  - 在 `embbytok_service.dart`：搜索 `IncludeItemTypes`
  - 替换所有视频列表和收藏列表的 `IncludeItemTypes` 字段值
- **Test Requirements**:
  - `programmatic` TR-3.1: `getFavoriteMovies` 的 `IncludeItemTypes` 包含 `'Video'`
  - `programmatic` TR-3.2: `getLibraryItems` 的 `IncludeItemTypes` 包含 `'Video'`
  - `human-judgment` TR-3.3: 普通视频 (Home Video 类型)出现在收藏列表中
- **Notes**: 与 Task 1 完成后可一起完成本任务

## [ ] Task 4: 确保 `toggleFavorite` 在 `toggleFavorite` 修复图标语义 — 使心形象征"点赞"、星形"收藏" 两者绑到同一 `favorited` 状态
- **Priority**: P2 — UX 优化，保持现状但确保行为正确
- **Depends On**: Task 1, Task 2
- **Description**:
  - 两者都调用 `toggleFavorite` → 但应保持现状但保持行为正确
  - 两者都绑定到同一 `favorited` 状态
  - 不需要两个图标做不同的事
- **Acceptance Criteria Addressed**: AC-4
- **Implementation Approach**:
  - 保持当前两个图标都调用 `toggleFavorite` 的行为不变
  - 只需确保当一个图标被点击后两个图标都正确响应
  - 图标状态从同一 `favorited` 源读取
- **Key Code Location**: `lib/widgets/video_page_item.dart` L558-L572
- **Test Requirements**:
  - `human-judgment` TR-4.1: 点击心形图标后，星形象标变，两图标都变亮
  - `human-judgment` TR-4.2: 点击星形图标后，心形图标也变亮

## [ ] Task 5: 确保双击视频触发 `toggleFavorite` 并显示动画
- **Priority**: P1 — TikTok 风格基础交互
- **Depends On**: Task 1, Task 2
- **Description**:
  - `gesture_overlay.dart` L80 的 `_onDoubleTap` 调用 `toggleFavorite`
  - 确保 `ref.read(favoritesProvider.notifier).toggleFavorite(widget.item)` 正确调用
  - 确保动画也显示心形动画
- **Acceptance Criteria addressed**: AC-5
- **Implementation Approach**:
  - 检查 `gesture_overlay.dart` 的 `_onDoubleTap` 是否正确调用
  - 检查 `heart_animation.dart` 是否正常工作
- **Test Requirements**:
  - `human-judgment` TR-5.1: 双击画面显示心形动画，并正确触发 `toggleFavorite`

## [ ] Task 6: 错误反馈和回滚
- **Priority**: P1 — 健壮性改进
- **Depends On**: Task 1, Task 2
- **Description**:
  - 当 `toggleFavorite` API 调用失败时，向用户显示错误提示
  - 当前已实现回滚逻辑（`favorites_provider.dart` L237-L274），但需要确保错误消息被捕获和显示
  - 在 `video_page_item.dart` 中增加 SnackBar 或 Toast 错误反馈
- **Acceptance Criteria addressed**: AC-7
- **Implementation Approach**:
  - 在 `video_page_item.dart` 中 `onTap` handler 中增加 try-catch
  - 当调用失败时显示错误提示
  - 显示 SnackBar 或 Toast 错误提示
- **Key Code Location**: `lib/widgets/video_page_item.dart` 中图标点击 handler
- **Test Requirements**:
  - `human-judgment` TR-6.1: 断网后点击收藏图标显示错误提示
  - `programmatic` TR-6.2: 图标状态正确回滚
- **Notes**: 验证乐观更新回滚已实现，需验证正确性

## [ ] Task 7: 代码检查和 flutter analyze 验证
- **Priority**: P0 — 完成所有子任务后必须验证代码质量
- **Depends On**: Task 1-6
- **Description**:
  - 运行 `flutter analyze --no-pub lib/` 确保无警告和错误
  - 确保代码通过静态分析
  - 确保无语法错误
- **Acceptance Criteria Addressed**: NFR-4 (向后兼容)
- **Implementation Approach**:
  - 运行 flutter analyze
  - 修复所有警告和错误
- **Test Requirements**:
  - `programmatic` TR-7.1: flutter analyze 输出无 error
  - `programmatic` TR-7.2: 代码可编译运行

## [ ] Task 8: 验证和提交代码
- **Priority**: P0 — 完成所有开发和提交
- **Depends On**: Task 1-7
- **Description**:
  - 验证所有功能在真实设备或模拟器上运行
  - 提交修改到 main 分支
- **Acceptance Criteria addressed**: 所有 AC
- **Implementation Approach**:
  - 手动测试收藏、点赞功能
  - 验证 Home Video/电影/剧集/音乐视频的收藏
  - 验证 FavoritesView 页面的显示
  - 提交代码
- **Test Requirements**:
  - `human-judgment` TR-8.1: 真实设备操作验证通过
  - `human-judgment` TR-8.2: 代码已提交到 GitHub main 分支
