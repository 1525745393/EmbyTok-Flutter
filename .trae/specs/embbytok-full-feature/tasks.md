# EmbyTok Flutter APP - 实施计划（全面复刻）

## 任务优先级定义
- **P0**: 必须首先完成，核心功能，阻塞后续开发
- **P1**: 重要功能，在 P0 完成后立即开发
- **P2**: 可选增强，时间充裕时实现

## 依赖约定
- 任务描述中明确 `Depends On` 的任务必须先完成
- 同一组任务可以并行开发（如不同文件的 Provider 可并行）

---

## [ ] Task 1: 基础架构重构 — 应用根组件与状态分层（P0）

- **Depends On**: None
- **Description**:
  - 将现有 `App` 组件重构为「标准模式/TV 模式」分流根
  - 使用 `SharedPreferences` 读取 `emby_force_device_mode` 决定走 `StandardRootView` 还是 `TVRootView`
  - 抽取全局 `AppPreferences` 类，集中处理 `constants.dart` 中定义的全部持久化键
  - `StandardRootView` 作为标准模式根组件，承载所有应用级状态（通过 Riverpod Provider 暴露）
  - `TVRootView` 暂以 TODO 占位，待后续 Task 10 开发
- **文件影响**（新建 / 修改）：
  - `frontend/lib/app.dart`（修改：路由前增加模式判断）
  - `frontend/lib/utils/constants.dart`（新增：持久化键常量）
  - `frontend/lib/utils/app_preferences.dart`（新建）
  - `frontend/lib/views/standard_root_view.dart`（新建）
  - `frontend/lib/views/tv_root_view.dart`（新建，占位）
  - `pubspec.yaml`（可能需要：添加 `shared_preferences` 依赖）
- **Acceptance Criteria Addressed**: AC-14（部分）、AC-17
- **Test Requirements**:
  - `programmatic` TR-1.1: `AppPreferences.load()` 正确读取全部持久化键并返回 `AppPreferences` 对象
  - `programmatic` TR-1.2: `AppPreferences.save()` 正确写入全部字段到 `SharedPreferences`
  - `programmatic` TR-1.3: `App` 组件根据 `emby_force_device_mode` 值决定渲染标准根或 TV 根
  - `human-judgment` TR-1.4: 标准模式下 UI 正常显示，无异常
- **Notes**: 此任务是后续所有功能的基础，务必优先完成。

## [ ] Task 2: 应用级 Provider 层重构 — 浏览模式/视图模式/媒体库/收藏（P0）

- **Depends On**: Task 1
- **Description**:
  - 新增或改造现有 Provider 以承载以下状态：
    - `feedTypeProvider`: `latest | random | favorites`（状态 + Notifier）
    - `viewModeProvider`: `feed | grid`（状态 + Notifier）
    - `selectedLibraryIdProvider`: `String?`（已有，保持）
    - `hiddenLibraryIdsProvider`: `Set<String>`（新建，支持持久化）
    - `isAutoPlayProvider`: `bool`（已有，但改造为持久化）
    - `isMutedProvider`: `bool`（已有，改造为持久化）
    - `orientationModeProvider`: `vertical | horizontal | both`（新建）
    - `libraryListProvider`: `AsyncValue<List<Library>>`（加载自 Emby `/Users/{userId}/Views`）
    - `favoritesServiceProvider`: 封装 Emby Playlist 操作（新建）
  - `videoListProvider` 改造为支持 `feedType`、`viewMode`、`orientationMode`、`hiddenLibraryIds`
- **文件影响**：
  - `frontend/lib/providers/feed_type_provider.dart`（新建）
  - `frontend/lib/providers/view_mode_provider.dart`（新建）
  - `frontend/lib/providers/orientation_mode_provider.dart`（新建）
  - `frontend/lib/providers/hidden_libraries_provider.dart`（新建）
  - `frontend/lib/providers/favorites_service_provider.dart`（新建）
  - `frontend/lib/providers/video_list_provider.dart`（修改）
  - `frontend/lib/providers/library_provider.dart`（修改：使用 `/Users/{userId}/Views` 端点）
  - `frontend/lib/services/embbytok_service.dart`（修改：新增 Playlist / Resume API 方法）
  - `frontend/lib/models/library.dart`（修改：支持 CollectionType 字段解析）
  - `frontend/lib/utils/constants.dart`（修改：补充类型枚举常量）
- **Acceptance Criteria Addressed**: AC-1、AC-2、AC-3、AC-6、AC-7、AC-10、AC-12、AC-17
- **Test Requirements**:
  - `programmatic` TR-2.1: `videoListProvider.refresh()` 根据 `feedType` 使用不同的 `SortBy` 参数
  - `programmatic` TR-2.2: 当 `orientationMode = 'vertical'` 时，加载后的列表被客户端过滤为仅 `Height >= Width * 0.8` 的项
  - `programmatic` TR-2.3: `favoritesServiceProvider` 实现 `getFavorites(libraryName)` → `Set<String>` 和 `toggleFavorite(itemId, isFavorite, libraryName)`
  - `programmatic` TR-2.4: 切换 feedType 后 `videoListProvider` 状态刷新并正确调用 API
  - `human-judgment` TR-2.5: Provider 状态变更后 UI 立即响应
- **Notes**: `favoritesServiceProvider` 参考 `VideoCard.tsx` 中的 `getTokPlaylistId`、`getTokPlaylistItemsInternal`、`toggleFavorite` 实现。

## [ ] Task 3: 视频流核心重构 — FeedView 升级支持两种浏览模式（P0）

- **Depends On**: Task 2
- **Description**:
  - 将现有的 `FeedView` 升级，增加顶部工具栏和视频流/网格的切换逻辑：
    - 顶部左：返回按钮（若有层级）或菜单按钮（媒体库选择）
    - 顶部中：浏览模式标签（最新/随机/收藏）
    - 顶部右：全屏/静音/视图切换 三个按钮
  - `viewMode = 'feed'`: 走原有的 PageView 视频流逻辑
  - `viewMode = 'grid'`: 新开发 `VideoGridView`（见 Task 4）
  - 顶部导航栏在 `isAutoPlay = true` 时隐藏（纯净模式）
  - 支持多层级导航 `navStack`：从系列→季→集；返回按钮按层级回退
- **文件影响**：
  - `frontend/lib/views/feed_view.dart`（重构）
  - `frontend/lib/widgets/top_tool_bar.dart`（新建：顶部工具栏）
  - `frontend/lib/providers/navigation_stack_provider.dart`（新建：`navStack` 状态）
- **Acceptance Criteria Addressed**: AC-14、AC-10（部分）、AC-11（部分）
- **Test Requirements**:
  - `programmatic` TR-3.1: `viewMode` 切换后路由到正确视图
  - `programmatic` TR-3.2: `navStack` 增加一层后顶部显示返回按钮
  - `human-judgment` TR-3.3: 顶部工具栏布局对齐参考项目

## [ ] Task 4: 网格视图 — VideoGridView 新建（P0）

- **Depends On**: Task 2、Task 3
- **Description**:
  - 新建 `VideoGridView`，展示当前库或层级下的内容：
    - 2 列（竖屏）/ 4 列（横屏）网格
    - 每个网格卡片展示：封面图（`cached_network_image`）、标题、时长
    - 有播放进度的视频显示进度条覆盖层
    - `Series` / `Folder` / `BoxSet` / `Season` 类型项有额外的角标（如「剧集」「季」）
  - 点击：
    - 若为视频（Movie/Episode/Video）→ 进入视频流视图，定位到该视频（`currentIndex`）
    - 若为系列/季/文件夹 → 进入下一层，`navStack` 加一层，重新请求
  - 下拉刷新 / 底部滚动加载更多
  - 网格空状态：「未找到视频」图标 + 刷新按钮
- **文件影响**：
  - `frontend/lib/views/video_grid_view.dart`（新建）
  - `frontend/lib/widgets/video_grid_card.dart`（新建）
  - `frontend/lib/widgets/video_progress_bar.dart`（新建：小进度条）
  - `frontend/lib/models/media_item.dart`（修改：补充字段映射）
- **Acceptance Criteria Addressed**: AC-5、AC-11、AC-15
- **Test Requirements**:
  - `programmatic` TR-4.1: 点击 `Episode` 类型卡片 → `viewMode = 'feed'`、`currentIndex = 该 item 索引`
  - `programmatic` TR-4.2: 点击 `Series` 类型卡片 → `navStack` 加一层，重新请求该系列下的季
  - `human-judgment` TR-4.3: 网格布局对齐参考项目，封面比例合理（16:9 或 2:3）

## [ ] Task 5: 视频卡片增强 — VideoPageItem 增强版（P0）

- **Depends On**: Task 2
- **Description**:
  - 将现有 `VideoPageItem` 按参考项目 `VideoCard.tsx` 全面升级：
    - 单击：播放/暂停（中央 Play 图标）
    - 双击：红心飞行动效 + 若未收藏则加入收藏
    - 长按（>500ms）：进入 2x 倍速，顶部显示「2倍速中」横幅
    - 横向滑动：显示 `±N 秒` 覆盖层 + seek 调整
    - 纵向滑动（ΔY > ΔX）：不处理（交给 PageView 处理上下切换）
  - 视频方向自动适配：
    - 判断 `isContentLandscape = item.Width > item.Height`
    - 判断 `isScreenLandscape = constraints.maxWidth > constraints.maxHeight`
    - `VideoPlayer` 组件的 `fit` = 两者一致时 `BoxFit.cover`，否则 `BoxFit.contain` + 背后加一层模糊封面图
  - 底部信息面板：标题、年份、时长、类型标签、简介（可收起）
  - 右侧操作按钮：收藏、信息、静音、自动连播开关
  - 进度条：长视频（> 3 分钟）+ 非自动连播时才显示
  - 照片类型（`item.isPhoto = true`）：不创建 VideoPlayerController，改走 `PhotoPageItem`（已在之前的 spec 中规划）
- **文件影响**：
  - `frontend/lib/widgets/video_page_item.dart`（重构）
  - `frontend/lib/widgets/gesture_overlay.dart`（重构：集成长按/横向滑/双击识别的统一手势）
  - `frontend/lib/widgets/heart_animation.dart`（重构：按参考项目飞行动效）
  - `frontend/lib/widgets/two_speed_indicator.dart`（新建：2 倍速顶部横幅）
  - `frontend/lib/widgets/seek_indicator.dart`（新建：快进/快退覆盖层）
  - `frontend/lib/widgets/play_pause_icon.dart`（新建：中央播放/暂停覆盖）
  - `frontend/lib/widgets/bottom_info_panel.dart`（新建：底部信息面板）
  - `frontend/lib/widgets/right_action_panel.dart`（新建：右侧操作按钮）
- **Acceptance Criteria Addressed**: AC-6、AC-7、AC-8、AC-9、AC-18
- **Test Requirements**:
  - `programmatic` TR-5.1: 单击 → `isPlaying` 切换
  - `programmatic` TR-5.2: 300ms 内两次点击 → `addHeart(x, y)` 动画触发 + 若未收藏 → `favoritesService.toggleFavorite(item.id, false, libName)`
  - `programmatic` TR-5.3: 长按 > 500ms → `videoPlayer.setPlaybackSpeed(2.0)`；松手 → `setPlaybackSpeed(1.0)`
  - `programmatic` TR-5.4: 横向滑动，`seekOffset = ΔX/5` 秒，松手后 `seekTo(currentTime + seekOffset)`
  - `human-judgment` TR-5.5: 横屏视频在竖屏设备上显示带模糊背景的效果

## [ ] Task 6: 自动连播与纯净模式（P1）

- **Depends On**: Task 2、Task 5
- **Description**:
  - `isAutoPlay = true` 时：
    - `VideoPlayer` `loop = false`（不循环，允许播放结束事件触发）
    - 顶部工具栏、底部信息面板、右侧操作按钮全部隐藏（`Opacity = 0` 或 `Offstage`）
    - 首次开启时显示 Toast「自动连播已开启」（3 秒自动消失）
  - `isAutoPlay = false` 时：
    - `VideoPlayer` `loop = true`（循环播放）
    - 所有 UI 正常显示
  - `VideoFeed` 层监听 `onVideoEnded` → 自动滚动到下一个视频
- **文件影响**：
  - `frontend/lib/widgets/video_page_item.dart`（修改：根据 `isAutoPlay` 切换 UI）
  - `frontend/lib/views/feed_view.dart`（修改：监听视频结束事件，进行滚动）
  - `frontend/lib/providers/is_auto_play_provider.dart`（已有，但增强持久化）
- **Acceptance Criteria Addressed**: AC-10
- **Test Requirements**:
  - `programmatic` TR-6.1: `isAutoPlay = true` 且视频播放结束 → `nextIndex = currentIndex + 1` → 新视频自动播放
  - `programmatic` TR-6.2: `isAutoPlay = true` 时顶部/底部 UI 为隐藏状态
  - `human-judgment` TR-6.3: Toast 提示样式与位置对齐参考项目

## [ ] Task 7: 观看进度同步（Resume Playback）（P1）

- **Depends On**: Task 2
- **Description**:
  - 进入视频时：若 `item.userData?.playbackPositionTicks > 0`，`seekTo(playbackPositionTicks / 10000000)` 秒
  - 播放过程中：每 30 秒或退出视频时，调用 Emby API「同步播放位置」（参考项目未显式实现，但 Emby 提供接口）
  - 网格视图中对有进度的项显示：
    - 右下角「继续观看」小圆点
    - 底部一条细进度条（已播放比例）
  - TV 模式首页展示「继续观看」行（使用 `/Items/Resume` 端点），留给 Task 10
- **文件影响**：
  - `frontend/lib/services/embbytok_service.dart`（修改：新增 `syncPlaybackPosition` / `getResumeItems` 方法）
  - `frontend/lib/widgets/video_grid_card.dart`（修改：进度条 + 角标）
  - `frontend/lib/widgets/video_page_item.dart`（修改：进入时恢复进度，播放过程中写回进度）
- **Acceptance Criteria Addressed**: AC-13
- **Test Requirements**:
  - `programmatic` TR-7.1: 进入视频后 `videoPlayer.position` 约等于 `playbackPositionTicks / 10,000,000` 秒
  - `programmatic` TR-7.2: 播放超过 30 秒时 API 被调用
  - `human-judgment` TR-7.3: 网格视图中进度条显示比例直观

## [ ] Task 8: 媒体库管理 — 隐藏/选择库（P1）

- **Depends On**: Task 2
- **Description**:
  - 菜单面板从 `/Users/{userId}/Views` 拉取所有媒体库
  - 每个库显示：
    - 名称（如「电影」「家庭视频」）
    - 类型标签（根据 `CollectionType` 映射到中文）
    - 「当前」选中状态（选中则作为当前库）
    - 「隐藏」开关（切换 `hiddenLibraryIds`）
  - 顶部中央显示当前库名；未选择库时显示「全部媒体库」
  - 未选择特定库时，服务层使用 `ParentIds` 参数合并查询所有未隐藏库
- **文件影响**：
  - `frontend/lib/widgets/library_menu_panel.dart`（新建）
  - `frontend/lib/services/embbytok_service.dart`（修改：`getVideos` 支持 `includeIds`）
  - `frontend/lib/utils/constants.dart`（修改：补充类型→中文映射）
- **Acceptance Criteria Addressed**: AC-14（部分）、FR-10
- **Test Requirements**:
  - `programmatic` TR-8.1: 切换库 → `selectedLibraryId` 变化 → `videoListProvider` 重新请求
  - `programmatic` TR-8.2: 隐藏/显示库 → `hiddenLibraryIds` 变化 → 视频列表自动刷新
  - `human-judgment` TR-8.3: 菜单面板 UI 清晰、可访问

## [ ] Task 9: 照片库支持（P2）

- **Depends On**: Task 2、Task 5
- **Description**:
  - 已在之前的 spec 中规划，此处整合为一项独立任务：
    - Library 的 `isPhotoLibrary` 属性判断（已有）
    - `PhotoPageItem` 全屏图片显示（新建）
    - 网格视图对 Photo 类型也能显示（已在 Task 4 考虑）
  - 照片项不创建 `VideoPlayerController`
  - 照片项支持收藏、信息按钮，不支持静音/自动连播
  - 图片加载使用 `cached_network_image`，显示 `loadingBuilder` / `errorBuilder`
- **文件影响**：
  - `frontend/lib/widgets/photo_page_item.dart`（新建，若之前未创建）
- **Acceptance Criteria Addressed**: AC-16
- **Test Requirements**:
  - `programmatic` TR-9.1: `MediaItem.type = 'Photo'` → 不创建 VideoPlayerController
  - `human-judgment` TR-9.2: 照片全屏居中，加载中显示指示器

## [ ] Task 10: TV 模式 — TVRootView + TVDashboard（P2）

- **Depends On**: Task 1、Task 2、Task 4、Task 7
- **Description**:
  - `TVRootView` 作为 TV 模式入口：
    - 顶部栏：模式切换（标准/TV）、库选择
    - 主内容：
      - 「继续观看」横向滚动行（调用 `getResumeItems`）
      - 按媒体库分区的纵向列表（每行一个库，横向滚动其内容）
    - 焦点移动：D-pad 左右上下选择；Enter 点击
  - 内容项点击后：
    - 若为剧集库 → 进入 TV 模式下的网格视图（TVGridView）→ 视频流播放
    - 若为电影/短视频库 → 直接进入视频流，默认从第一个开始
  - `RawKeyboardListener` 监听 `LogicalKeyboardKey`：arrowDown/arrowUp/arrowLeft/arrowRight/enter/space
  - 视频流播放时：
    - ←/→：±10 秒
    - Enter / Space：播放/暂停
    - ↑/↓：切换视频
  - TV 模式下不支持触摸手势（依赖遥控器）
- **文件影响**：
  - `frontend/lib/views/tv_root_view.dart`（新建，从 Task 1 的占位升级为实际实现）
  - `frontend/lib/views/tv_dashboard.dart`（新建）
  - `frontend/lib/widgets/tv_video_grid_view.dart`（新建，TV 模式下的网格视图）
  - `frontend/lib/widgets/tv_focus_wrapper.dart`（新建，焦点高亮包装组件）
- **Acceptance Criteria Addressed**: AC-15、AC-11（TV 端）
- **Test Requirements**:
  - `programmatic` TR-10.1: `RawKeyboardListener` 正确拦截方向键并触发对应行为
  - `programmatic` TR-10.2: `getResumeItems` 返回的「继续观看」列表正确渲染
  - `human-judgment` TR-10.3: TV 首页焦点高亮清晰、层级导航直观

## [ ] Task 11: 全屏切换与屏幕旋转（P2）

- **Depends On**: Task 2
- **Description**:
  - 顶部右侧工具栏的「全屏」按钮：
    - 未全屏 → 切换为横屏全屏模式（`SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight])` + `SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive)`）
    - 已全屏 → 退出全屏，恢复系统 UI
  - 视频播放时，底部信息面板可点击「全屏」按钮实现相同效果
- **文件影响**：
  - `frontend/lib/widgets/top_tool_bar.dart`（修改：添加全屏按钮）
  - `frontend/lib/widgets/video_page_item.dart`（修改：可能添加底部全屏按钮）
- **Acceptance Criteria Addressed**: FR-13
- **Test Requirements**:
  - `programmatic` TR-11.1: 点击全屏按钮 → 屏幕旋转到横屏 + 系统 UI 隐藏
  - `human-judgment` TR-11.2: 横屏模式视频比例合理

## [ ] Task 12: 错误处理与空状态增强（P2）

- **Depends On**: Task 2、Task 3、Task 4
- **Description**:
  - 视频流/网格视图加载失败：显示错误信息 + 「重试」按钮
  - 无数据：显示「未找到视频」图标 + 刷新按钮
  - 收藏夹为空：显示「该库暂无收藏，点击红心收藏喜欢的内容」文案
  - 网络超时：友好提示（「网络连接不稳定」）+ 重试
- **文件影响**：
  - `frontend/lib/views/feed_view.dart`（修改：添加空状态与错误状态）
  - `frontend/lib/views/video_grid_view.dart`（修改：添加空状态与错误状态）
  - `frontend/lib/widgets/error_view.dart`（新建：统一错误/空状态组件）
- **Acceptance Criteria Addressed**: AC-15（空状态）
- **Test Requirements**:
  - `programmatic` TR-12.1: `videoListProvider` 返回错误时 → `ErrorView` 正确显示
  - `human-judgment` TR-12.2: 空状态文案合理，鼓励用户操作

## [ ] Task 13: 单元测试与 Widget 测试（P2）

- **Depends On**: Task 1-12 全部完成
- **Description**:
  - 为核心 Provider 编写 `flutter_test` 单元测试：
    - `feedTypeProvider`
    - `favoritesServiceProvider`（使用 `MockApiClient`）
    - `videoListProvider`（Mock Emby 服务）
  - 为核心 Widget 编写 Widget 测试：
    - `VideoPageItem`：模拟单击/双击/长按/横向滑四种手势
    - `VideoGridCard`：模拟点击事件
    - `TopToolBar`：模拟按钮点击切换状态
  - 使用 `mockito` 或原生 Mock 实现服务层隔离
- **文件影响**：
  - `frontend/test/providers/*_test.dart`（新建若干）
  - `frontend/test/widgets/*_test.dart`（新建若干）
  - `pubspec.yaml`（可能添加 dev_dependencies）
- **Acceptance Criteria Addressed**: NFR-2（可靠性）
- **Test Requirements**:
  - `programmatic` TR-13.1: `flutter test` 全部通过
  - `programmatic` TR-13.2: 覆盖 15+ 个核心 Provider/Widget

## [ ] Task 14: 用户偏好持久化与启动恢复（P2）

- **Depends On**: Task 1、Task 2
- **Description**:
  - 在 `AppPreferences` 中实现：
    - `isMuted` / `isAutoPlay` / `orientationMode` / `feedType` / `viewMode` / `hiddenLibraryIds` 的读写
  - 启动 `StandardRootView` 时从 `AppPreferences` 恢复所有状态
  - 任何状态变更时自动同步到持久化（使用 `ref.listen` 或在 `Notifier.build` 中保存）
- **文件影响**：
  - `frontend/lib/utils/app_preferences.dart`（修改：补充字段与读写）
  - `frontend/lib/views/standard_root_view.dart`（修改：启动恢复逻辑）
- **Acceptance Criteria Addressed**: AC-17
- **Test Requirements**:
  - `programmatic` TR-14.1: 设置任意值后冷启动 APP → 值保持
  - `programmatic` TR-14.2: 未设置过时使用默认值（`isMuted = true`、`orientationMode = 'vertical'`、`feedType = 'latest'`、`viewMode = 'feed'`）

---

## 任务总览与建议开发顺序

1. **Task 1**（P0）: 架构重构 → 1 周
2. **Task 2**（P0）: Provider 层 → 1.5 周（需与 Task 1 并行准备模型）
3. **Task 3**（P0）: FeedView 顶部工具栏 → 3 天（与 Task 2 后半并行）
4. **Task 4**（P0）: 网格视图 → 1 周
5. **Task 5**（P0）: 视频卡片增强 → 1.5 周（核心开发，独立开发周期最长）
6. **Task 6**（P1）: 自动连播 → 3 天（依赖 Task 5 的手势层）
7. **Task 7**（P1）: 观看进度 → 3 天（服务层 API 扩展 + UI 标记）
8. **Task 8**（P1）: 媒体库管理 → 3 天（Provider + UI）
9. **Task 9**（P2）: 照片库 → 2 天（Task 5 已有 isPhoto 基础，补充 PhotoPageItem）
10. **Task 10**（P2）: TV 模式 → 1 周（待标准端稳定后）
11. **Task 11**（P2）: 全屏切换 → 1 天
12. **Task 12**（P2）: 空状态 → 2 天
13. **Task 13**（P2）: 测试 → 1 周
14. **Task 14**（P2）: 持久化 → 2 天

**预计总工期**：8-10 周（两人团队），P0 功能约 4-5 周可完成 MVP。

**MVP 交付标准**：完成 Task 1-5 + Task 8 后，可向内部用户发布 alpha 版本验证播放体验。
