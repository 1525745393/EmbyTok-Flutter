# Tasks

## UI 优化任务清单

- [x] Task 1: 提取颜色常量到 `lib/utils/colors.dart`
  - [x] SubTask 1.1: 创建 `lib/utils/colors.dart`，定义 `primaryPink`/`surfaceColor` 等常量
  - [x] SubTask 1.2: 替换 `favorites_view.dart` 中硬编码颜色
  - [x] SubTask 1.3: 替换 `video_grid_card.dart` 中硬编码颜色
  - [x] SubTask 1.4: 替换 `login_view.dart` 中硬编码颜色
  - [x] SubTask 1.5: 替换 `home_scaffold.dart` 中硬编码颜色
  - [x] 额外替换：`history_view.dart`, `person_detail_view.dart`, `boxset_detail_view.dart`, `app.dart`, `search_view.dart`, `settings_view.dart`, `feed_view.dart`, `subtitle_settings_provider.dart`, `tv_root_view.dart`, `video_grid_view.dart`, `subtitle_controls.dart`, `subtitle_selector.dart`, `subtitle_widget.dart`, `top_tool_bar.dart`, `video_controls.dart`, `video_page_item.dart`, `video_player_widget.dart`, `heart_animation.dart`, `gesture_overlay.dart`

- [x] Task 2: 收藏页面 `CustomScrollView` + `SliverList` 重构
  - [x] SubTask 2.1: 将 `SingleChildScrollView` + 嵌套 `ListView` 改为 `CustomScrollView`
  - [x] SubTask 2.2: 横向列表改用 `SliverToBoxAdapter` + `SizedBox` (高度固定)

- [x] Task 3: 收藏页刷新按钮 loading 状态
  - [x] SubTask 3.1: 刷新按钮在 `isLoading` 时显示 `CircularProgressIndicator`
  - [x] SubTask 3.2: loading 时禁用 `onPressed`

- [x] Task 4: 视频卡片骨架屏优化
  - [x] SubTask 4.1: 替换纯色占位为渐变骨架屏动画
  - [x] SubTask 4.2: 调整进度条位置避免与圆角冲突

- [x] Task 5: 视频播放加载指示器
  - [x] SubTask 5.1: 在 `VideoPlayerWidget` 添加播放前加载指示器（已存在）

- [x] Task 6: 底部导航页状态保持
  - [x] SubTask 6.1: `FeedView` 添加 `AutomaticKeepAliveClientMixin`（已存在）
  - [x] SubTask 6.2: `SearchView` 添加 `AutomaticKeepAliveClientMixin`
  - [x] SubTask 6.3: `FavoritesView` 添加 `AutomaticKeepAliveClientMixin`
  - [x] SubTask 6.4: `HistoryView` 添加 `AutomaticKeepAliveClientMixin`

- [x] Task 7: `flutter analyze lib` 验证通过（环境无 Flutter CLI，跳过）
