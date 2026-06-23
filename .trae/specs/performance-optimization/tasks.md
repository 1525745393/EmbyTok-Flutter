# Tasks

- [x] Task 1: 修复 VideoControls 高频 setState 重建
  - **Priority**: high
  - **Depends On**: None
  - **Description**:
    - 将 `_onControllerChanged` 中的 `setState(() {})` 替换为 `ValueListenableBuilder`
    - 进度条、播放时间、缓冲进度使用 `ValueListenableBuilder` 局部重建
    - `isPlaying` 状态变更检查：仅在 `isPlaying` 实际变化时才写入 `isPlayingProvider`
  - **Acceptance Criteria Addressed**: AC-1
  - **Test Requirements**:
    - `human-judgement` TR-1.1: 播放时 VideoControls 不再每帧重建，进度条正常更新
    - `human-judgement` TR-1.2: 播放/暂停按钮状态正确切换
    - `programmatic` TR-1.3: `_onControllerChanged` 中不再调用 `setState`

- [x] Task 2: 修复 VideoPageItem 过度重建
  - **Priority**: high
  - **Depends On**: Task 1
  - **Description**:
    - `favorited` 改为 `ref.watch(favoritesProvider.select((s) => s.favoriteIds.contains(widget.item.id)))`
    - `isReady` 改为 `ref.watch(videoReadyProvider.select((s) => s.contains(widget.item.id)))`
    - 将 `isPlaying` 相关 UI（CenterPlayButton）拆分为独立 Consumer 子组件
    - `ref.listen` 从 build 方法移到 initState
  - **Acceptance Criteria Addressed**: AC-2
  - **Test Requirements**:
    - `human-judgement` TR-2.1: 播放/暂停切换时仅局部重建，不触发整个 VideoPageItem 重建
    - `programmatic` TR-2.2: `_authServerUrl()` 和 `_authToken()` 改为 `ref.read`

- [x] Task 3: 启用 AppImageCacheManager
  - **Priority**: high
  - **Depends On**: None
  - **Description**:
    - 在所有 CachedNetworkImage 中传入 `cacheManager` 参数
    - 缩略图（网格卡片、列表项）使用 `AppImageCacheManager.thumbnail`
    - 大图（详情页背景、演员头像）使用 `AppImageCacheManager.largeImage`
    - 涉及文件：poster_grid_view.dart、video_player_widget.dart、item_detail_view.dart、favorites_view.dart、history_view.dart、search_view.dart
  - **Acceptance Criteria Addressed**: AC-3
  - **Test Requirements**:
    - `programmatic` TR-3.1: 所有 CachedNetworkImage 实例都传入了 cacheManager 参数
    - `human-judgement` TR-3.2: 图片加载正常，无闪烁

- [x] Task 4: 修复 listener 泄漏
  - **Priority**: high
  - **Depends On**: None
  - **Description**:
    - 将 video_page_item.dart 中 onControllerReady 回调里的匿名 listener 提取为命名方法 `_onVideoChangedForReport`
    - 在 dispose 中移除该 listener
    - 检查 video_player_widget.dart 中各路径的 listener，统一为命名方法
  - **Acceptance Criteria Addressed**: AC-4
  - **Test Requirements**:
    - `programmatic` TR-4.1: dispose 中移除了所有命名 listener
    - `programmatic` TR-4.2: 不存在未被移除的匿名 listener

- [x] Task 5: 网络请求去重
  - **Priority**: medium
  - **Depends On**: None
  - **Description**:
    - 在 EmbytokService 中添加请求去重机制
    - 基于path + queryParameters 生成请求 key
    - 相同 key 的并发 GET 请求返回同一个 Future
  - **Acceptance Criteria Addressed**: AC-5
  - **Test Requirements**:
    - `programmatic` TR-5.1: 相同参数的并发 GET 请求只发送一次网络请求
    - `programmatic` TR-5.2: 请求完成后 key 被清理，下次请求正常发送

# Task Dependencies
- Task 2 depends on Task 1
