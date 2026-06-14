# EmbyTok Flutter APP 功能增强 - The Implementation Plan

## [ ] Task 1: 字幕功能修复与增强
- **Priority**: P0
- **Depends On**: None
- **Description**:
  - 修复 `video_page_item.dart` 中 `_loadSubtitleContent` 的 HTTP 加载实现（当前被注释）
  - 从 Emby 字幕流端点加载字幕（格式：`/Videos/{itemId}/{subtitleIndex}/Subtitles.srt` 或类似 URL）
  - 验证 `subtitle_renderer.dart` 中的 SRT 解析器（支持逗号/点号毫秒分隔符）
  - 验证字幕 URL 构造是否正确附加 api_key 认证
  - 测试：有字幕的视频应能正确显示字幕，无字幕的视频应保持正常播放
- **Acceptance Criteria Addressed**: FR-1, AC-1
- **Test Requirements**:
  - `programmatic` TR-1.1: 确保 subtitle_track.dart 的 url 字段正确构造（带 api_key）
  - `programmatic` TR-1.2: 确保 subtitle_widget.dart 的字幕显示逻辑正确（按时间匹配 cue）
  - `human-judgement` TR-1.3: 播放带字幕的视频，选择字幕后字幕应在底部正确显示，随播放时间切换
- **Notes**: 当前 HTTP 请求代码被注释为占位符，需确认 Emby 字幕流 URL 格式和认证方式。

## [ ] Task 2: 主题模式真正生效
- **Priority**: P0
- **Depends On**: None
- **Description**:
  - 修改 `lib/views/app.dart` 或 `main.dart`，在 `MaterialApp.router` 中接入 `themeModeProvider`
  - 定义完整的亮色 `ThemeData` 和暗色 `ThemeData` 两套主题
  - 深色主题保持当前的黑色风格（scaffoldBackgroundColor: Colors.black）
  - 亮色主题采用白色背景 + 深色文字 + Material Design 风格
  - 主题切换通过 `Consumer` 或 `ref.watch(themeModeProvider)` 动态响应
  - 确保所有使用固定颜色的 Widget 改为从主题获取颜色
- **Acceptance Criteria Addressed**: FR-2, AC-2
- **Test Requirements**:
  - `programmatic` TR-2.1: MaterialApp 必须设置 themeMode 属性，其值来自 themeModeProvider
  - `programmatic` TR-2.2: MaterialApp 必须设置 theme（亮色）和 darkTheme（暗色）两套主题
  - `human-judgement` TR-2.3: 在设置页切换主题后，所有页面（包括视频信息面板、按钮颜色）应立即切换样式，无需重启
- **Notes**: 需检查所有 Widget 中硬编码的颜色（如 Colors.white, Colors.black），确保在暗色主题下有良好对比度。

## [ ] Task 3: 剧集层级导航（系列/季/集）
- **Priority**: P1
- **Depends On**: None
- **Description**:
  - 创建 `lib/widgets/series/season_list_view.dart` - 季列表页，展示系列的所有季
  - 创建 `lib/widgets/series/episode_list_view.dart` - 集列表页，展示所选季的所有集
  - 在 `video_page_item.dart` 的信息面板中添加"查看剧集"入口（当 MediaItem 是 series/season 类型时）
  - 服务层 `getSeasons()` 和 `getEpisodes()` 已存在，需验证 API 参数和返回解析
  - 点击集数跳转到视频播放页，传递 itemId 和播放进度（如有）
  - `MediaItem` 模型中检查 seasonNumber/episodeNumber/seriesName 等字段是否存在
- **Acceptance Criteria Addressed**: FR-3, AC-3
- **Test Requirements**:
  - `programmatic` TR-3.1: getSeasons() 和 getEpisodes() 返回的数据能正确解析为 MediaItem 列表
  - `programmatic` TR-3.2: 季列表页和集列表页使用 go_router 路由注册，可通过命名路由跳转
  - `human-judgement` TR-3.3: 进入剧集视频，点击"查看剧集"，应能看到所有季和集，点击集数从该剧集开始播放
- **Notes**: 需要先验证 `MediaItem` 模型是否包含 seasonNumber/episodeNumber 字段，若缺失需补充。剧集入口在信息面板中以"展开全部剧集"形式呈现。

## [ ] Task 4: 继续观看列表 UI
- **Priority**: P1
- **Depends On**: None
- **Description**:
  - 创建 `lib/views/continue_watching_view.dart` - "继续观看"页面
  - 使用 `EmbytokService.getResumeItems()` 获取服务端播放记录
  - 列表项展示：缩略图（CachedNetworkImage）、标题、进度条（LinearProgressIndicator）、相对时间
  - 点击列表项跳转到视频播放页，传递 itemId 和 playbackPositionTicks
  - 支持左滑删除（Dismissible） - 仅从本地视图删除，同步到 Emby 服务端为可选
  - 在 `home_scaffold.dart` 底部导航中新增"继续"或"继续观看"入口
  - 可选：在 Feed 页顶部添加横向滑动的继续观看区域（类似 Netflix）
- **Acceptance Criteria Addressed**: FR-4, AC-4
- **Test Requirements**:
  - `programmatic` TR-4.1: getResumeItems() 调用成功并正确解析返回的媒体项列表
  - `programmatic` TR-4.2: 列表项的进度条百分比计算正确（playbackPositionTicks / runTimeTicks）
  - `human-judgement` TR-4.3: 用户点击继续观看项后，视频从上次暂停位置继续播放
- **Notes**: 需要验证 Emby API 返回的 Resume 数据结构中是否包含播放位置字段（通常是 UserData.PlaybackPositionTicks）。

## [ ] Task 5: 高级过滤排序
- **Priority**: P1
- **Depends On**: None
- **Description**:
  - 扩展 `embbytok_service.dart` 中 `getLibraryItems()` 方法，支持 `years/genres/minCommunityRating/minDuration/sortBy` 参数
  - 在 `lib/providers/` 创建 `filter_provider.dart` - 管理过滤状态（年份、类型、评分、排序方式）
  - 在 Feed 页顶部工具栏添加"过滤/排序"按钮（图标：filter_list 或 tune）
  - 创建 `lib/widgets/filter_bottom_sheet.dart` - 底部弹出的过滤/排序选择面板
  - 过滤面板包含：类型筛选（电影/剧集/音乐）、年份范围选择器、最低评分滑块、最短时长、排序方式选择
  - 过滤状态变更后，重新加载 Feed 列表
  - 过滤状态持久化到 SharedPreferences（可选）
- **Acceptance Criteria Addressed**: FR-5, AC-5
- **Test Requirements**:
  - `programmatic` TR-5.1: getLibraryItems() 正确传递过滤参数到 API 调用
  - `programmatic` TR-5.2: filter_provider.dart 状态管理正确，异步加载过程中 UI 不报错
  - `human-judgement` TR-5.3: 用户选择"电影+按评分排序"后，Feed 列表重新加载，内容仅含电影且按评分排序
- **Notes**: Emby API 的过滤参数名需实际验证（可能是 RecursiveYears, Genres, MinCommunityRating, SortBy 等）。

## [ ] Task 6: 图片缓存全面启用
- **Priority**: P1
- **Depends On**: None
- **Description**:
  - 在以下文件中，将 `Image.network` 替换为 `CachedNetworkImage`：
    - `lib/views/search_view.dart` - 搜索结果缩略图
    - `lib/views/favorites_view.dart` - 收藏列表缩略图
    - `lib/views/history_view.dart` - 历史列表缩略图
    - `lib/widgets/video_page_item.dart` - 视频卡片的封面图
    - 其他可能使用 `Image.network` 的地方
  - 为每个 CachedNetworkImage 添加 placeholder（如 CircularProgressIndicator）和 errorWidget（如 Icon(Icons.broken_image)）
  - 无需修改 feed_view.dart 中的视频流（PageView 中的视频是 video_player，不受此任务影响）
- **Acceptance Criteria Addressed**: FR-6, AC-6
- **Test Requirements**:
  - `programmatic` TR-6.1: 项目中不再出现任何 `Image.network` 调用（视频海报除外）
  - `human-judgement` TR-6.2: 关闭网络连接后浏览已加载过的图片，图片应仍然显示（从缓存读取）
- **Notes**: 注意 CachedNetworkImage 的参数与 Image.network 不同（需使用 imageUrl, placeholder, errorWidget），可能需要封装一个辅助函数统一处理。

## [ ] Task 7: 视频预加载
- **Priority**: P1
- **Depends On**: None
- **Description**:
  - 修改 `lib/views/feed_view.dart` 的 `PageView.builder` 逻辑：
    - 当前 index 稳定后（用户停止滑动 >500ms），初始化 index+1 的 VideoPlayerController
    - 可选项：也初始化 index-1（若存在）
  - 修改 `lib/widgets/video_page_item.dart`：
    - 在 State 中暴露方法 `preload()`：异步创建并初始化 VideoPlayerController
    - 在 `dispose()` 中正确释放预加载的控制器
  - 使用 `AutomaticKeepAliveClientMixin`（已混入）保持页面状态，但视频资源在切换时合理初始化和释放
  - 不在网络类型为移动网络时预加载（可选，简化版：始终预加载 ±1 项）
- **Acceptance Criteria Addressed**: FR-7, AC-7
- **Test Requirements**:
  - `programmatic` TR-7.1: PageView 切换页面时，目标页的视频应已初始化完成（controller.value.isInitialized == true）
  - `programmatic` TR-7.2: 快速滑动多页时，未完成的预加载被取消，仅保留当前 ±1 项
  - `human-judgement` TR-7.3: 用户正常速度滑动切换视频，下一个视频应在 500ms 内开始播放（无黑屏等待）
- **Notes**: 视频预加载可能消耗较多网络和内存资源，需谨慎控制预加载数量（建议 ±1 项）。注意在 release 模式下的性能表现。

## [ ] Task 8: 播放完成上报
- **Priority**: P2
- **Depends On**: None
- **Description**:
  - 在 `lib/widgets/video_page_item.dart` 或 `video_player_widget.dart` 中：
    - 监听视频播放完毕事件（已有的 onVideoEnded 回调）
    - 监听用户主动关闭/返回事件（dispose 前记录当前进度）
  - 调用 `embbytok_service.dart` 中的上报方法（如 reportPlaybackStopped，若不存在需新增）
  - 上报条件：播放时长 > 30 秒 且 > 总时长 * 5%
  - 上报内容：itemId、播放位置（秒或 tick）、总时长
  - 上报失败不阻塞用户操作（静默失败，不弹出错误提示）
- **Acceptance Criteria Addressed**: FR-8, AC-8
- **Test Requirements**:
  - `programmatic` TR-8.1: 视频播放完毕后发起了 API 调用（可通过日志或断点验证）
  - `programmatic` TR-8.2: 播放时长 <30 秒时不上报
  - `human-judgement` TR-8.3: 播放视频超过 30 秒后退出，在 Emby 官方客户端或 Web 界面查看继续观看列表，能看到该条记录
- **Notes**: 需确认 Emby 上报播放进度的 API（/Sessions/Playing/Progress 和 /Sessions/Playing/Stopped），可能需要维护 sessionId。若实现复杂，可简化为仅使用本地 watch_history_provider。

---

**任务依赖图**（无环，可按编号顺序或前 3 项并行开始）：
```
Task 1 (字幕修复)    ──┐
Task 2 (主题)          │  可并行启动
Task 3 (剧集导航)      │
Task 4 (继续观看)      ├── 全部 P0/P1
Task 5 (过滤排序)      │
Task 6 (图片缓存)      │
Task 7 (视频预加载)    │
Task 8 (播放上报)    ──┘
```

**建议的实现顺序**：先做 P0 的 Task 1/Task 2，再做 P1 的 Task 3-7，最后做 P2 的 Task 8。其中 Task 6（图片缓存）改动最小且收益高，可优先安排。
