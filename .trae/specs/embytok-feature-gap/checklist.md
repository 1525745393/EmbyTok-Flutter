# EmbyTok Flutter APP 功能增强 - Verification Checklist

## Task 1: 字幕功能修复与增强
- [ ] Checkpoint 1.1: `video_page_item.dart` 中 `_loadSubtitleContent` 方法包含有效的 HTTP 请求实现（不是注释占位符）
- [ ] Checkpoint 1.2: 字幕 URL 正确构造（包含 api_key 或 X-Emby-Token 认证）
- [ ] Checkpoint 1.3: `subtitle_widget.dart` 中的 SubtitleRenderer 能按当前播放时间匹配并显示字幕
- [ ] Checkpoint 1.4: 有字幕的视频可正常显示字幕，无字幕的视频播放不受影响
- [ ] Checkpoint 1.5: 字幕选择器 UI 可正常工作，列出可用字幕并允许用户切换

## Task 2: 主题模式真正生效
- [ ] Checkpoint 2.1: `MaterialApp` 中设置了 `themeMode` 属性，其值从 `themeModeProvider` 读取
- [ ] Checkpoint 2.2: `MaterialApp` 同时设置了 `theme`（亮色）和 `darkTheme`（暗色）两套主题
- [ ] Checkpoint 2.3: 切换主题后，当前页和返回的所有页立即显示为新主题（无需重启）
- [ ] Checkpoint 2.4: 深色主题下文本有足够对比度（白色/浅灰色文字在深色背景上）
- [ ] Checkpoint 2.5: 亮色主题下文本有足够对比度（深灰色/黑色文字在浅色背景上）
- [ ] Checkpoint 2.6: 主题设置持久化到 SharedPreferences，应用重启后保留上次选择

## Task 3: 剧集层级导航
- [ ] Checkpoint 3.1: `embbytok_service.dart` 中 `getSeasons()` 和 `getEpisodes()` 能成功返回数据
- [ ] Checkpoint 3.2: 季列表页 (SeasonListView) 展示所有季的封面、名称、集数
- [ ] Checkpoint 3.3: 集列表页 (EpisodeListView) 展示所选季的所有集，包含集号、标题、时长
- [ ] Checkpoint 3.4: 在视频信息面板中，系列/剧集内容显示"查看剧集"入口按钮
- [ ] Checkpoint 3.5: 点击集数跳转到视频播放页，从该剧集开始播放
- [ ] Checkpoint 3.6: 使用 go_router 注册了季列表和集列表的路由，可通过命名路由跳转

## Task 4: 继续观看列表 UI
- [ ] Checkpoint 4.1: `continue_watching_view.dart` 创建并通过 getResumeItems() 成功获取数据
- [ ] Checkpoint 4.2: 列表项展示缩略图、标题、进度条（百分比）、相对时间
- [ ] Checkpoint 4.3: 点击列表项跳转到视频播放页，从上次观看位置继续
- [ ] Checkpoint 4.4: 支持左滑删除（Dismissible）
- [ ] Checkpoint 4.5: 底部导航中新增"继续"或"继续观看"入口
- [ ] Checkpoint 4.6: 无数据时显示空状态提示（如"暂无继续观看内容"）

## Task 5: 高级过滤排序
- [ ] Checkpoint 5.1: `embbytok_service.dart` 中 `getLibraryItems()` 支持 `years/genres/minCommunityRating/minDuration/sortBy` 参数
- [ ] Checkpoint 5.2: `filter_provider.dart` 管理过滤状态并正确与服务层交互
- [ ] Checkpoint 5.3: Feed 页顶部工具栏包含"过滤/排序"按钮
- [ ] Checkpoint 5.4: 过滤底部面板（FilterBottomSheet）包含类型、年份、最低评分、最短时长、排序方式选项
- [ ] Checkpoint 5.5: 用户更改过滤条件后，Feed 列表正确重新加载并应用新条件
- [ ] Checkpoint 5.6: 过滤/排序状态在页面切换后保留（或持久化到 SharedPreferences）

## Task 6: 图片缓存全面启用
- [ ] Checkpoint 6.1: `search_view.dart` 中的图片使用 `CachedNetworkImage` 而非 `Image.network`
- [ ] Checkpoint 6.2: `favorites_view.dart` 中的图片使用 `CachedNetworkImage`
- [ ] Checkpoint 6.3: `history_view.dart` 中的图片使用 `CachedNetworkImage`
- [ ] Checkpoint 6.4: `video_page_item.dart` 中的缩略图使用 `CachedNetworkImage`
- [ ] Checkpoint 6.5: 每个图片组件包含 placeholder（加载中状态）和 errorWidget（加载失败状态）
- [ ] Checkpoint 6.6: 关闭网络后浏览已加载过的图片，图片仍然正常显示（从缓存读取）

## Task 7: 视频预加载
- [ ] Checkpoint 7.1: `feed_view.dart` 的 `PageView.builder` 中实现 ±1 项视频预加载逻辑
- [ ] Checkpoint 7.2: 用户停止滑动后（如 500ms 延迟），开始预初始化下一个视频的 VideoPlayerController
- [ ] Checkpoint 7.3: 快速滑动多页时，取消未完成的预初始化，仅保留当前 ±1 项
- [ ] Checkpoint 7.4: 视频资源在 dispose 时正确释放，无内存泄漏
- [ ] Checkpoint 7.5: 用户以正常速度切换视频时，下一个视频应在 500ms 内开始播放

## Task 8: 播放完成上报
- [ ] Checkpoint 8.1: 视频播放完毕时调用 `reportPlaybackStopped()` 或等价方法
- [ ] Checkpoint 8.2: 用户主动关闭视频页面时（在 dispose 前）记录并上报进度
- [ ] Checkpoint 8.3: 上报条件检查：仅当播放时长 >30 秒且 > 总时长 * 5% 时才上报
- [ ] Checkpoint 8.4: 上报内容包含 itemId、播放位置、总时长
- [ ] Checkpoint 8.5: 上报失败不阻塞用户操作（静默失败，不弹出错误 toast）
- [ ] Checkpoint 8.6: 上报成功后，在 Emby 官方客户端或 Web 界面可看到继续观看记录更新

---

**使用说明**：
- 每次完成一个 Task 后，请逐项验证对应的 Checkpoint
- 所有检查点以 `programmatic`（代码/构建验证）或 `human-judgment`（人工体验验证）方式验证
- 如有检查点未通过，需回到对应 Task 修改并重新验证
- 只有所有检查点都标记为 `[x]` 后，该 Task 才算完成
