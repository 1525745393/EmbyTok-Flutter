# EmbyTok UI 优化规范

## Why
APP 界面存在多个 UX 问题影响用户体验：收藏页滚动性能差、刷新无反馈、图片加载无骨架屏、导航页切换状态丢失。

## What Changes

### 1. 收藏页面性能优化
- `FavoritesView` 将 `SingleChildScrollView` + 嵌套 `ListView` 改为 `CustomScrollView` + `SliverList`，保留滑动惯性
- 刷新按钮在 loading 时显示 `CircularProgressIndicator` 并禁用点击

### 2. 视频卡片骨架屏
- `VideoGridCard` 的 `CachedNetworkImage` placeholder 改为渐变骨架屏动画
- 进度条与圆角不再冲突

### 3. 登录页密码可见性
- 密码切换按钮尺寸优化，确保触摸目标 ≥ 48dp

### 4. 视频播放加载反馈
- `VideoPlayerWidget` 添加播放前的加载指示器

### 5. 底部导航状态保持
- `FeedView`/`SearchView`/`FavoritesView`/`HistoryView` 使用 `AutomaticKeepAliveClientMixin` 保持页面状态

### 6. 颜色常量提取
- 提取 `primaryPink = Color(0xFFE91E63)` 等硬编码颜色到 `lib/utils/colors.dart`

## Impact
- **Affected specs**: `embbytok-flutter-v1`
- **Affected code**:
  - `frontend/lib/views/favorites_view.dart`
  - `frontend/lib/widgets/video_grid_card.dart`
  - `frontend/lib/views/login_view.dart`
  - `frontend/lib/widgets/video_player_widget.dart`
  - `frontend/lib/views/home_scaffold.dart`
  - `frontend/lib/utils/colors.dart` (新增)

## ADDED Requirements

### Requirement: 收藏页滑动性能
收藏页面 SHALL 使用 `CustomScrollView` + `SliverList` 实现，禁止在 `ListView` 外层嵌套 `SingleChildScrollView`。

### Requirement: 刷新按钮状态反馈
刷新按钮在 `isLoading == true` 时 SHALL 显示 `CircularProgressIndicator` 并禁用点击。

### Requirement: 图片骨架屏
图片加载中 SHALL 显示渐变骨架屏动画，而非纯色占位。

### Requirement: 导航页状态保持
底部导航切换时 SHALL 保持各页面滚动位置和表单状态。

## MODIFIED Requirements

### Requirement: 视频播放加载反馈
原有视频播放器无加载状态指示。**MODIFIED**: 视频开始播放前 SHALL 显示加载指示器。

## REMOVED Requirements
无

## Non-Goals
- 不修改应用主题色方案
- 不添加深色/浅色模式切换
- 不添加动画效果（Lottie 等）
