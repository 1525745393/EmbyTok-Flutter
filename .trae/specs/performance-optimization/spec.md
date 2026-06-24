# 性能优化 Spec

## Why
项目存在多处性能瓶颈：VideoControls 播放时每秒重建约60次（P0）、AppImageCacheManager 定义却从未使用（P0）、视频控制器 listener 泄漏（P1）、网络请求无去重无缓存（P1）。这些问题导致播放时高 CPU 占用和发热、磁盘缓存失控、内存泄漏。

## What Changes
- **P0：VideoControls 高频重建修复** - 使用 ValueListenableBuilder 替代 setState，局部重建
- **P0：VideoPageItem 过度重建修复** - 使用 select 选择器，拆分独立 Consumer 子组件
- **P0：启用 AppImageCacheManager** - 在所有 CachedNetworkImage 中传入分场景 cacheManager
- **P1：修复 listener 泄漏** - 提取匿名 listener 为命名方法，在 dispose 中移除
- **P1：辅助方法 ref.watch 改为 ref.read** - 非_build 方法中不应使用 ref.watch
- **P1：网络请求去重** - 在 EmbytokService 中添加请求去重机制

## Impact
- Affected specs: 无
- Affected code:
  - `lib/widgets/video_controls.dart` - 高频重建修复
  - `lib/widgets/video_page_item.dart` - 过度重建修复、listener 泄漏
  - `lib/widgets/video_player_widget.dart` - listener 统一管理
  - `lib/widgets/poster_grid_view.dart` - 启用 cacheManager
  - `lib/views/item_detail_view.dart` - 启用 cacheManager
  - `lib/views/favorites_view.dart` - 启用 cacheManager
  - `lib/views/history_view.dart` - 启用 cacheManager
  - `lib/views/search_view.dart` - 启用 cacheManager
  - `lib/services/embbytok_service.dart` - 请求去重

## ADDED Requirements

### Requirement: VideoControls 局部重建
系统 SHALL 使用 ValueListenableBuilder 包裹 VideoPlayerController.value，避免每帧 setState 触发整个 VideoControls 重建。

#### Scenario: 播放时 CPU 占用降低
- **WHEN** 视频播放中
- **THEN** VideoControls 不再每秒重建60次，仅进度条等依赖 controller.value 的组件局部更新

### Requirement: VideoPageItem 选择性监听
系统 SHALL 使用 ref.watch + select 选择器，仅监听真正需要的字段，避免任一 provider 变化触发完整重建。

#### Scenario: 播放/暂停切换时局部重建
- **WHEN** isPlayingProvider 变化
- **THEN** 仅重建依赖 isPlaying 的子组件，而非整个 VideoPageItem

### Requirement: 图片缓存管理
系统 SHALL 在所有 CachedNetworkImage 中传入 AppImageCacheManager（缩略图用 thumbnail、大图用 largeImage），控制磁盘缓存大小。

#### Scenario: 磁盘缓存可控
- **WHEN** 用户浏览大量图片
- **THEN** 缩略图缓存上限100张/7天，大图缓存上限50张/7天，不会无限增长

### Requirement: Listener 资源释放
系统 SHALL 将匿名 listener 提取为命名方法，并在 dispose 中正确移除。

#### Scenario: 控制器销毁后无残留监听
- **WHEN** VideoPageItem 销毁
- **THEN** 所有 listener 被正确移除，无内存泄漏

### Requirement: 网络请求去重
系统 SHALL 对相同 path + queryParameters 的 GET 请求进行去重，避免重复请求。

#### Scenario: 快速切换媒体库
- **WHEN** 用户快速切换媒体库
- **THEN** 相同请求只发送一次，不产生重复网络流量
