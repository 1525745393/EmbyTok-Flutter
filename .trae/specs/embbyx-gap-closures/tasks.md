# EmbyTok Flutter - 实现计划（按优先级排序任务）

## Task 1: Feed Type 驱动列表刷新（打通 latest / random / favorites / resume） — P0
- **Priority**: P0
- **Depends On**: None（最基础）
- **Description**:
  - `app_preferences.dart` 的 `FeedType` 枚举新增 `resume` 值
  - `FeedType.fromString`/`toStorageString`/`zhLabel` 同步支持 `resume`
  - `constants.dart` 新增 `kFeedTypeResume = 'resume'` 常量
  - 修改 `video_list_provider.dart` 的 `VideoListNotifier`：
    - 在构造函数中增加 `_ref.listen<FeedType>(feedTypeProvider, ...)` 监听，feedType 变化时自动调用 `refresh()`
    - `refresh()` 内增加 switch：根据 `_ref.read(feedTypeProvider)` 选择 `getLibraryItems` / `getLibraryItems + shuffle` / `getFavoriteMovies` / `getResumeItems`
    - `loadMore()` 也需要根据 feedType 判断是否可分页（random/favorites/resume 不分页）
  - 修改 `feed_view.dart`：`_toggleFeedType()` 循环顺序为 latest → random → favorites → resume → latest
  - resume 模式下，每个条目在缩略图底部叠加一条细进度条，显示播放进度
  - resume 模式下，播放从上次位置开始（通过 `MediaItem.userData.playbackPositionTicks`）
  - 测试要求：在 latest / random / favorites / resume 之间来回切换都能立即展示对应数据
- **Acceptance Criteria Addressed**: FR-1, FR-6, AC-1, AC-6
- **Test Requirements**:
  - `programmatic`: `flutter analyze` 通过；在 `feedTypeProvider` 切换后 `videoListProvider.items` 变化；`FeedType.resume` 正常序列化反序列化
  - `human-judgment`: 手动快捷键 R 切换四次，每次列表正确更新，resume 模式显示续播进度条
- **Notes**: 需在 `feed_view.dart` 中的 `buildVideoPageView` 使用 `videoListProvider.items` 作为数据源；resume 模式下 start position 通过 `MediaItem.userData.playbackPositionTicks` 传递给 `VideoPlayerWidget`

## Task 2: 视频预加载（PageView Preload Controller 接入） — P0
- **Priority**: P0
- **Depends On**: Task 1
- **Description**:
  - 在 `video_list_provider.dart` 或新的 `preload_controller.dart` 中维护一个从索引到 `VideoPlayerController` 的缓存 `Map<int, VideoPlayerController>`
  - `PageView.builder` 的 item 构建时：
    - `index == currentIndex`：使用缓存的 controller，若不存在则动态创建
    - `index == currentIndex + 1`：预加载下一条（async 初始化但不播放，只 `initialize()`）
    - `index == currentIndex - 1`：保留（用户可能回滑）
    - 其他 index：`dispose()` 释放，从缓存移除
  - 修改 `VideoPageItem` 接收 `preloadedController` 参数，存在时直接调用 `onControllerReady` 而不走动态构造
  - 在页面销毁时清空缓存
- **Acceptance Criteria Addressed**: FR-2, AC-2
- **Test Requirements**:
  - `programmatic`: 预加载的 controller 在索引 +1 位置能在不调用网络的情况下初始化完成
  - `human-judgment`: 连续滑动 50 条不出现明显卡顿或 OOM 崩溃
- **Notes**: 预加载仅 `initialize()`，不 `play()`，避免流量和带宽浪费；播放只在 `currentIndex` 触发

## Task 3: 自动连播下一集（isAutoPlay → PageView.nextPage） — P0
- **Priority**: P0
- **Depends On**: Task 2
- **Description**:
  - 新增播放状态 provider：`playbackCompletionProvider`（或扩展现有 `isPlayingProvider`）监听每个 VideoPageItem 是否播放结束
  - 在 `VideoPageItem` 中监听 `_videoController.value.isCompleted` 或自定义阈值
  - 触发逻辑：
    1. 若 `isAutoPlayProvider` 为 true
    2. 当前位置在 `duration - 1s` 前
    3. 调用 `reportPlaybackStopped()` 上报结束位置
    4. 调用 `feed_view.dart` 的 `_goToNextVideo()`（通过回调或 GlobalKey）
  - 最后一集不自动跳转，显示 SnackBar "已播放完毕"
  - 倒数 1 秒时显示底部提示条"即将播放下一集：[标题]"（3 秒）
- **Acceptance Criteria Addressed**: FR-3, AC-3
- **Test Requirements**:
  - `programmatic`: 模拟 3 条视频，第 1 条结束后自动跳到第 2 条，日志中包含 reportPlaybackStopped
  - `human-judgment`: 手动设置 isAutoPlay=true/false 验证行为

## Task 4: 图片缓存优化（Image.network → CachedNetworkImage） — P1
- **Priority**: P1
- **Depends On**: None
- **Description**:
  - 在 `video_grid_card.dart`、`poster_grid_view.dart`、`feed_view.dart`（若存在缩略图）、`item_detail_view.dart` 中，将 `Image.network` 全部替换为 `CachedNetworkImage`
  - `CachedNetworkImage` 参数：`placeholder` → `CircularProgressIndicator`（或骨架色），`errorWidget` → 渐变 + 图标
  - 设置 `memCacheWidth` / `memCacheHeight` 用于限制解码大小（如 400x400），避免大图内存溢出
  - 统一在 `utils/colors.dart` 或 `constants.dart` 添加 cache 相关常量
- **Acceptance Criteria Addressed**: FR-5, AC-5
- **Test Requirements**:
  - `programmatic`: 所有 Image.network 替换完成；`flutter analyze` 通过
  - `human-judgment`: 下滑 50 条再回滑，图像无重复 spinner

## Task 5: 键盘/遥控器快捷键完善（A/D 真正 seek） — P1
- **Priority**: P1
- **Depends On**: None
- **Description**:
  - 在 `feed_view.dart` 的 `_handleKeyEvent` 中：
    - `LogicalKeyboardKey.keyA` / `LogicalKeyboardKey.arrowLeft` → 调用 `_videoController.seekTo(currentPosition - 15s)`
    - `LogicalKeyboardKey.keyD` / `LogicalKeyboardKey.arrowRight` → 调用 `_videoController.seekTo(currentPosition + 15s)`
  - 需要从 `VideoPageItem` 暴露当前 controller 引用（通过 Provider：`currentVideoControllerProvider`）或通过回调
  - 新增 `currentVideoControllerProvider`：`StateProvider<VideoPlayerController?>`，当前视频初始化时写入
- **Acceptance Criteria Addressed**: FR-9, AC-9
- **Test Requirements**:
  - `programmatic`: 模拟按键 A，position 减少 15 秒
  - `human-judgment`: 真机键盘测试 A/D 快捷键

## Task 6: 子标题渲染与选择器集成 — P1
- **Priority**: P1
- **Depends On**: Task 1
- **Description**:
  - 在 `VideoPageItem` 的 `Stack` 中增加 `SubtitleWidget`
  - SubtitleWidget 读取 `selectedSubtitleProvider`
  - 当 `selectedSubtitleProvider` 非 null 时：
    - 根据 `itemId + mediaSourceId` 请求 WebVTT 文件（`/Videos/{itemId}/Subtitles/{index}.vtt`）
    - 解析 VTT 后根据当前播放时间显示文本
  - 控制条增加字幕按钮：点击弹出语言选择 BottomSheet
  - 字幕样式：半透明黑底 + 白字（16sp 竖屏 / 22sp 横屏）
- **Acceptance Criteria Addressed**: FR-4, AC-4
- **Test Requirements**:
  - `programmatic`: VTT 解析逻辑在单元测试中可验证
  - `human-judgment`: 选择不同语言后字幕正确切换

## Task 7: 续播位置上报与服务器同步 — P2
- **Priority**: P2
- **Depends On**: Task 1（resume feedType 基础）, Task 3（自动连播）
- **Description**:
  - 在 `VideoPageItem.dispose()` / 视频切换时自动向服务器上报当前播放位置（reportPlaybackStopped 已存在）
  - 播放完毕（position ≥ duration - 1s 且 isAutoPlay 为 false）时从 resume 列表移除当前条目
  - resume 列表项底部叠加一条细进度条（粉色 2px），显示 `playbackPositionTicks / runTimeTicks`
  - 点击 resume 条目时，从 `userData.playbackPositionTicks` 位置开始播放（不是 0）
  - 处理 `userData == null` 的情况：视为未开始，从 0 播放
- **Acceptance Criteria Addressed**: FR-6, AC-6
- **Test Requirements**:
  - `programmatic`: `getResumeItems()` 返回的条目与 UI 一致；从 resume 条目播放时初始 position 与 userData.playbackPositionTicks 一致
  - `human-judgment`: 手动中途退出视频，再回到 feed 页，resume 模式下能看到进度条；点击续播从上次位置开始

## Task 8: NextUp（下一集） — P2
- **Priority**: P2
- **Depends On**: Task 3（自动连播逻辑）, Task 7
- **Description**:
  - 在 `VideoPageItem` 播放结束时，先检查 `getNextUp(itemId)` 是否有下一集
  - 如果存在下一集：
    - 显示 NextUp 提示条（底部 5 秒）："即将播放：下一集标题 · 5秒后自动开始 · 点击立即播放"
    - 用户点击立即播放 → 把下一集作为 `MediaItem` 注入到当前位置或打开新 `VideoPageItem`
    - 倒计时结束自动播放下一集
  - 如果不存在下一集 → 回退到 Task 3 的自动连播逻辑（切换到 feed 的下一条）
- **Acceptance Criteria Addressed**: FR-7, AC-7
- **Test Requirements**:
  - `programmatic`: `getNextUp()` 返回有值时不走默认 nextPage 逻辑
  - `human-judgment`: 剧集结束时能看到 NextUp 提示条

## Task 9: 条目详情页 Item Detail View — P2
- **Priority**: P2
- **Depends On**: Task 4（图片缓存）
- **Description**:
  - 新建 `views/item_detail_view.dart`
  - 顶部大图（横屏海报），使用 `CachedNetworkImage`
  - 主信息区：标题、类型标签（Movie/Series/Episode）、年份、社区评分（⭐ + 数字）
  - 简介区：可展开折叠的 Overview 文本
  - 演员区：`people` 列表横向滚动，头像 + 名称
  - 集数区（Series）：从 `getEpisodes()` 或 `getChildren()` 获取，显示 SxEy 标题 + 缩略图
  - 操作栏："立即播放"按钮、"收藏"按钮（调用 favoritesProvider）
  - 使用 `go_router` 路由：`/item/:itemId`
- **Acceptance Criteria Addressed**: FR-8, AC-8
- **Test Requirements**:
  - `human-judgment`: 影片、剧集、音乐视频三类都能正确展示信息

## Task 10: TV Mode 遥控器焦点导航优化 — P2
- **Priority**: P2
- **Depends On**: Task 1
- **Description**:
  - 为 `feed_view.dart` 的顶部 LibraryChips 增加 `Focus` + `FocusNode`
  - 为 `video_page_item.dart` 的右操作栏按钮增加 `Focus`
  - 为 `video_grid_card.dart` 增加 `Focus`（网格模式）
  - 焦点高亮样式：粉色圆角边框 2px + 缩放 1.05（动画 150ms）
  - 自动滚动跟随：使用 `Scrollable.ensureVisible(context)`
  - D-pad Up/Down 控制 PageView 翻页（已有部分逻辑但需检查）
- **Acceptance Criteria Addressed**: FR-10, AC-10
- **Test Requirements**:
  - `human-judgment`: 在 Android TV / 机顶盒上测试所有页面

## Task 11: 错误状态与空状态统一 — P2
- **Priority**: P2
- **Depends On**: None
- **Description**:
  - 新建 `widgets/error_state_card.dart`：图标 + 标题 + 副标题 + 操作按钮
  - 新建 `widgets/empty_state_card.dart`：类似结构，不同图标和文案
  - 在 `feed_view.dart`、`favorites_view.dart`、`history_view.dart`、`search_view.dart` 中统一替换原有的零散错误/空状态 UI
  - 网络错误：显示"网络不稳定，点击重试"
  - 空列表：显示"这里还没有内容"
  - 未登录：显示"请先登录到 Emby 服务器"
- **Acceptance Criteria Addressed**: FR-11, AC-11
- **Test Requirements**:
  - `human-judgment`: 断网、空列表、未登录三种场景下的 UI

## Task 12: 性能优化与代码整洁 — P2
- **Priority**: P2
- **Depends On**: 所有 Task（作为 cleanup 做）
- **Description**:
  - 列表项添加 `const` 构造子项、使用 `Key(key: item.id)` 稳定 key
  - 大图片使用 `ResizeImage` / `cacheWidth` / `cacheHeight`
  - `provider` 增加 `///` doc 注释（公共 API 级）
  - 清理不再使用的 `import`
  - `flutter format .` 统一格式
  - 过长函数（>80 行）拆分为多个子函数
- **Acceptance Criteria Addressed**: FR-12, NFR-1, NFR-4
- **Test Requirements**:
  - `programmatic`: `flutter analyze --no-pub lib` 0 errors
  - `programmatic`: `flutter test` 通过（如果有测试）

## 实现流程建议
1. **第一轮（P0）**: Task 1 → Task 2 → Task 3（让核心使用体验可用）
2. **第二轮（P1）**: Task 4 → Task 5 → Task 6（优化细节体验）
3. **第三轮（P2）**: Task 7 → Task 8 → Task 9 → Task 10 → Task 11 → Task 12（补齐功能 + 性能 + TV）
4. 每完成一个 Task 立即提交并推送，让 CI 校验，保持每 commit 可回退
