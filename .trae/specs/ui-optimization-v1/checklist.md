# Checklist

## UI 优化验证清单

- [x] `lib/utils/colors.dart` 已创建并包含 `primaryPink` 等常量
- [x] `favorites_view.dart` 使用颜色常量，无硬编码颜色值
- [x] `video_grid_card.dart` 使用颜色常量，无硬编码颜色值
- [x] `login_view.dart` 使用颜色常量，无硬编码颜色值
- [x] `home_scaffold.dart` 使用颜色常量，无硬编码颜色值
- [x] `favorites_view.dart` 使用 `CustomScrollView` + `SliverList`，无 `SingleChildScrollView` 嵌套
- [x] `favorites_view.dart` 刷新按钮在 loading 时显示 `CircularProgressIndicator` 并禁用
- [x] `video_grid_card.dart` 图片 placeholder 为渐变骨架屏，非纯色
- [x] `video_grid_card.dart` 进度条不与卡片圆角冲突（`bottom: 0` → `bottom: 4`）
- [x] `VideoPlayerWidget` 播放前显示加载指示器（已有 CircularProgressIndicator）
- [x] `FeedView` 使用 `AutomaticKeepAliveClientMixin` 并重写 `wantKeepAlive`（已有）
- [x] `SearchView` 使用 `AutomaticKeepAliveClientMixin` 并重写 `wantKeepAlive`
- [x] `FavoritesView` 使用 `AutomaticKeepAliveClientMixin` 并重写 `wantKeepAlive`
- [x] `HistoryView` 使用 `AutomaticKeepAliveClientMixin` 并重写 `wantKeepAlive`
- [x] 所有 lib/ 下硬编码颜色已替换为颜色常量（grep 验证通过）
