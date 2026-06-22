# EmbyTok Flutter APP - 验证清单（Checklist）

本清单用于验证 spec 中定义的所有功能需求与非功能需求。每个检查点对应 spec 中的一个 Acceptance Criterion 或关键实现点。

## 实现验证：应用架构与状态管理（对应 tasks 1, 2, 14）

- [ ] Checkpoint 1.1: `App` 启动时从 `SharedPreferences` 读取 `emby_force_device_mode`，决定渲染标准根或 TV 根
- [ ] Checkpoint 1.2: `AppPreferences` 正确读写所有定义的持久化键（`server_url`、`user_id`、`access_token`、`force_device_mode`、`orientation_mode`、`hidden_library_ids`、`is_muted`、`is_auto_play`、`last_feed_type`）
- [ ] Checkpoint 1.3: `StandardRootView` 作为标准模式根组件，承载并通过 Riverpod Provider 暴露 `feedType`、`viewMode`、`isAutoPlay`、`isMuted`、`orientationMode`、`selectedLibraryId`、`hiddenLibraryIds` 等状态
- [ ] Checkpoint 1.4: `TVRootView` 存在且在 `emby_force_device_mode = 'tv'` 时被渲染（即使是占位实现）
- [ ] Checkpoint 1.5: 应用冷启动时，上次的静音/自动连播/浏览模式/视图模式/方向过滤/隐藏库设置均被正确恢复
- [ ] Checkpoint 1.6: Provider 之间没有循环依赖，`flutter analyze` 无警告

## 实现验证：视频列表加载与浏览模式（对应 tasks 2, 3）

- [ ] Checkpoint 2.1: 选择「最新」模式时，请求参数 `SortBy = 'DateCreated'`，`SortOrder = 'Descending'`
- [ ] Checkpoint 2.2: 选择「随机」模式时，请求参数 `SortBy = 'Random'`，单次请求 `Limit <= 200`
- [ ] Checkpoint 2.3: 选择「收藏」模式时，走 `getTokPlaylistItemsInternal(libraryName)` → 从 `Tok-{libraryName}` Playlist 读取
- [ ] Checkpoint 2.4: 三种模式切换均正确触发 `videoListProvider` 刷新并清空旧数据
- [ ] Checkpoint 2.5: `orientationMode = 'vertical'` 时，加载后列表仅保留 `item.Height >= item.Width * 0.8` 的项（或无宽高信息的项）
- [ ] Checkpoint 2.6: `orientationMode = 'horizontal'` 时，加载后列表仅保留 `item.Width > item.Height` 的项
- [ ] Checkpoint 2.7: `orientationMode = 'both'` 时不过滤，原样返回

## 实现验证：视频流视图 / 网格视图切换（对应 tasks 3, 4）

- [ ] Checkpoint 3.1: `viewMode = 'feed'` 时渲染视频流（纵向 PageView），`viewMode = 'grid'` 时渲染网格
- [ ] Checkpoint 3.2: 视频流视图使用 `PageView.builder`，仅渲染当前项及 ±1 项（其余占位黑色背景）
- [ ] Checkpoint 3.3: 网格视图每行 2 列（竖屏）或 4 列（横屏），使用 `GridView.builder` + `SliverGrid`
- [ ] Checkpoint 3.4: 网格视图中点击 `Movie / Episode / Video` 类型项 → `viewMode = 'feed'`、`currentIndex = 点击项索引`
- [ ] Checkpoint 3.5: 网格视图中点击 `Series / Season / Folder / BoxSet` 类型项 → `navStack` 加一层，重新请求子内容
- [ ] Checkpoint 3.6: 返回按钮（`navStack.length > 0` 时可见）点击 → `navStack` 减一层，回到上一层内容
- [ ] Checkpoint 3.7: 顶部中央显示当前层级标题（最上层 navStack 的 `title`），没有层级时显示模式标签（最新/随机/收藏）

## 实现验证：视频卡片增强手势（对应 task 5）

- [ ] Checkpoint 4.1: **单击播放/暂停**：点击视频 → `isPlaying` 切换，屏幕中央显示 Play/Pause 图标
- [ ] Checkpoint 4.2: **双击红心动画**：300ms 内两次点击 → 从点击点出现飞行动效并消失；若视频未收藏则加入收藏
- [ ] Checkpoint 4.3: **长按 2 倍速**：按住 > 500ms 且无明显横向移动 → `videoPlayer.setPlaybackSpeed(2.0)`，顶部显示「2倍速中」横幅；松手 → `setPlaybackSpeed(1.0)`，横幅消失
- [ ] Checkpoint 4.4: **横向滑动调整进度**：`ΔX > 20px` 且 `|ΔX| > |ΔY|` → 中央显示「±N 秒」+ 时间轴覆盖；松手 → `seekTo(currentTime + ΔX/5)`
- [ ] Checkpoint 4.5: 手势互斥：长按触发后不再触发单击；横向滑动触发后不再触发上下切换视频（交给 PageView 的 scrollDirection: Axis.vertical）
- [ ] Checkpoint 4.6: 纵向滑动（上下切换）不影响当前视频播放状态，上下滑动切换视频后新视频从 00:00 开始
- [ ] Checkpoint 4.7: 视频卡片底部显示标题、年份、时长、类型标签（如「电影」「剧集」「短视频」）
- [ ] Checkpoint 4.8: 视频卡片右侧显示操作按钮（收藏、信息、静音、自动连播开关）
- [ ] Checkpoint 4.9: 进度条仅在「长视频（> 3min）且非自动连播」条件下显示

## 实现验证：视频方向自适应（对应 task 5）

- [ ] Checkpoint 5.1: `isContentLandscape` 正确判断：`item.Width > item.Height`
- [ ] Checkpoint 5.2: `isScreenLandscape` 正确判断：`constraints.maxWidth > constraints.maxHeight`
- [ ] Checkpoint 5.3: 横屏视频在竖屏设备上 → `BoxFit.contain` + 背后一层模糊背景海报
- [ ] Checkpoint 5.4: 竖屏视频在竖屏设备上 → `BoxFit.cover`（贴近 TikTok 观感）
- [ ] Checkpoint 5.5: 横屏视频在横屏设备上 → `BoxFit.cover`（全屏填充）

## 实现验证：自动连播与纯净模式（对应 task 6）

- [ ] Checkpoint 6.1: `isAutoPlay = true` → `VideoPlayer.loop = false`
- [ ] Checkpoint 6.2: `isAutoPlay = false` → `VideoPlayer.loop = true`
- [ ] Checkpoint 6.3: 视频播放结束 → `isAutoPlay = true` 时自动滚动到下一个视频并播放
- [ ] Checkpoint 6.4: `isAutoPlay = true` 时顶部工具栏、底部信息面板、右侧操作按钮隐藏（或 Opacity = 0）
- [ ] Checkpoint 6.5: 首次开启自动连播时显示 Toast「自动连播已开启」，3 秒后消失
- [ ] Checkpoint 6.6: `isAutoPlay` 值在切换后持久化到 `SharedPreferences`

## 实现验证：观看进度同步（对应 task 7）

- [ ] Checkpoint 7.1: 进入视频时若 `item.userData.playbackPositionTicks > 0` → `seekTo(playbackPositionTicks / 10,000,000)` 秒
- [ ] Checkpoint 7.2: 播放过程中每 30 秒 + 退出视频时写回播放位置到 Emby
- [ ] Checkpoint 7.3: 网格视图中有播放进度的项显示：右下角「继续观看」角标 + 底部细进度条
- [ ] Checkpoint 7.4: `/Items/Resume` 端点被实现（由 `getResumeItems` 方法），返回继续观看列表

## 实现验证：媒体库管理（对应 task 8）

- [ ] Checkpoint 8.1: 菜单面板从 `/Users/{userId}/Views` 读取所有媒体库
- [ ] Checkpoint 8.2: 每个库显示名称 + 类型标签（中文）
- [ ] Checkpoint 8.3: 选中某库后，`selectedLibraryId` 更新 → `videoListProvider` 刷新
- [ ] Checkpoint 8.4: 切换「隐藏」开关后，`hiddenLibraryIds` 更新并持久化
- [ ] Checkpoint 8.5: 未选择特定库时，使用 `ParentIds = 所有未隐藏库的 Id 列表` 合并查询

## 实现验证：照片库支持（对应 task 9）

- [ ] Checkpoint 9.1: `CollectionType = 'photos'` 的库 → `includeItemTypes = 'Photo'`
- [ ] Checkpoint 9.2: `MediaItem.type = 'Photo'` → `isPhoto = true`
- [ ] Checkpoint 9.3: Photo 类型项在视频流中 → `PhotoPageItem`（全屏图片），不创建 `VideoPlayerController`
- [ ] Checkpoint 9.4: Photo 类型项保留收藏按钮和信息按钮，但不显示静音/自动连播按钮
- [ ] Checkpoint 9.5: 图片加载失败时显示错误图标，加载中显示加载指示器

## 实现验证：TV 模式（对应 task 10）

- [ ] Checkpoint 10.1: `TVRootView` 作为 TV 模式根组件
- [ ] Checkpoint 10.2: `TVDashboard` 包含「继续观看」行 + 按库分区的内容行
- [ ] Checkpoint 10.3: 方向键 ↓/↑：切换视频；←/→：±10 秒；Enter/Space：播放/暂停
- [ ] Checkpoint 10.4: TV 模式下内容项使用 `Focus` + `FocusNode` 管理焦点，选中项有明显高亮
- [ ] Checkpoint 10.5: TV 模式不响应触摸手势

## 实现验证：全屏切换（对应 task 11）

- [ ] Checkpoint 11.1: 点击顶部全屏按钮 → 屏幕横屏 + 系统 UI 隐藏
- [ ] Checkpoint 11.2: 再次点击全屏按钮 → 恢复竖屏 + 系统 UI
- [ ] Checkpoint 11.3: `SystemChrome.setPreferredOrientations` 与 `SystemChrome.setEnabledSystemUIMode` 正确使用

## 实现验证：错误处理与空状态（对应 task 12）

- [ ] Checkpoint 12.1: 网络请求失败 → 视频流/网格中央显示错误信息 + 「重试」按钮
- [ ] Checkpoint 12.2: 无数据 → 显示「未找到视频」图标 + 刷新按钮
- [ ] Checkpoint 12.3: 收藏夹为空 → 显示「该库暂无收藏」提示文案
- [ ] Checkpoint 12.4: 网络超时 → 显示「网络连接不稳定」

## 实现验证：Emby API 服务层（贯穿 tasks 2, 7, 8）

- [ ] Checkpoint 13.1: 登录端点 `POST /Users/AuthenticateByName` 正确请求
- [ ] Checkpoint 13.2: 媒体库端点 `GET /Users/{userId}/Views` 正确解析返回的 Items
- [ ] Checkpoint 13.3: 视频列表端点 `GET /Users/{userId}/Items` 携带正确参数：`IncludeItemTypes`、`SortBy`、`Limit`、`ParentId` 或 `ParentIds`
- [ ] Checkpoint 13.4: 播放地址 `GET /Videos/{itemId}/stream.mp4?Static=true&api_key={token}` 正确构造
- [ ] Checkpoint 13.5: 图片地址 `GET /Items/{itemId}/Images/Primary?maxWidth=800&tag={tag}&quality=90&api_key={token}` 正确构造
- [ ] Checkpoint 13.6: 收藏 Playlist `Tok-{libraryName}` 的创建/查询/添加/移除均有对应方法实现
- [ ] Checkpoint 13.7: 继续观看 `GET /Users/{userId}/Items/Resume` 正确实现
- [ ] Checkpoint 13.8: 所有 API 请求携带正确的 `X-Emby-Token` 头（Dio 拦截器）和查询参数 `api_key`

## 实现验证：模型层（MediaItem/Library）

- [ ] Checkpoint 14.1: `Library.fromJson` 正确解析 `Id`、`Name`、`CollectionType`（Emby 原生字段）
- [ ] Checkpoint 14.2: `MediaItem.fromJson` 正确解析：`Id`、`Name`、`Type`、`MediaType`、`Overview`、`ProductionYear`、`Width`、`Height`、`RunTimeTicks`、`ImageTags`、`UserData`
- [ ] Checkpoint 14.3: `MediaItem.imageUrl()` 根据 `ImageTags.Primary` 构造带 `api_key` 的图片 URL
- [ ] Checkpoint 14.4: `MediaItem.computePlaybackUrl()` 对 Photo 类型返回 `null`
- [ ] Checkpoint 14.5: 所有模型支持 `toJson()`（用于调试/缓存）

## 实现验证：性能（NFR-1）

- [ ] Checkpoint 15.1: 视频流视图 `PageView.builder` 仅构建当前 ±1 项，其余占位黑色背景
- [ ] Checkpoint 15.2: 网格视图图片全部通过 `cached_network_image` 缓存，相同 `tag` 的图片第二次加载无网络请求
- [ ] Checkpoint 15.3: 切换视频时 `VideoPlayerController` 正确 `dispose`/重建，不产生内存泄漏
- [ ] Checkpoint 15.4: 长视频（> 3min）+ 非自动连播时才显示进度条，其他情况下不渲染进度条（减少不必要的 rebuild）

## 实现验证：可靠性（NFR-2）

- [ ] Checkpoint 16.1: Dio 配置 `connectTimeout = 30s`，超时返回统一的错误信息
- [ ] Checkpoint 16.2: 视频播放失败时通过 `VideoPlayerValueListener` 捕获 `errorDescription`，显示错误提示
- [ ] Checkpoint 16.3: 所有 Provider 在 `dispose` 时正确清理（Riverpod 自动处理）
- [ ] Checkpoint 16.4: 配置缺失时（如 `emby_server_url` 为空）自动回到登录流程，不崩溃

## 实现验证：可维护性（NFR-3）

- [ ] Checkpoint 17.1: 所有类型字符串常量集中在 `utils/constants.dart`（如 `'Movie'`、`'Photo'`、`'latest'`、`'random'`、`'favorites'` 等），不分散在代码各处
- [ ] Checkpoint 17.2: 每个 Provider 关注点单一，不承担多件事
- [ ] Checkpoint 17.3: `widgets/` 与 `views/` 目录结构清晰：小部件在 widgets、完整页面在 views
- [ ] Checkpoint 17.4: 新增的文件命名与现有风格一致（`snake_case`）

## 实现验证：国际化（NFR-5）

- [ ] Checkpoint 18.1: 所有展示给用户的字符串支持 zh/en 切换
- [ ] Checkpoint 18.2: 默认语言跟随系统（`Localizations.localeOf(context)`）
- [ ] Checkpoint 18.3: 语言切换后 UI 立即更新（无需重启）

## 实现验证：测试（Task 13）

- [ ] Checkpoint 19.1: `flutter test` 全部通过
- [ ] Checkpoint 19.2: 覆盖 15+ 个核心 Provider/Widget
- [ ] Checkpoint 19.3: 关键 API 方法有单元测试（Mock Dio）
- [ ] Checkpoint 19.4: Widget 测试包含单击、双击、长按、横向滑动四种手势场景

---

## 参考项目关键代码位置（对照实现用）

以下为参考项目（migumigu/EmbyTok）中的关键实现文件，供 Flutter 实现时作行为对照：

- **参考：App.tsx**（入口/模式分流）
  - `components/standard/StandardRoot.tsx`（标准端根组件，集中所有状态）
  - `components/VideoFeed.tsx`（视频流：PageView + IntersectionObserver）
  - `components/VideoCard.tsx`（单体视频卡片：播放/手势/UI/红心/进度条/信息面板）
  - `components/LibrarySelect.tsx`（媒体库选择/隐藏/语言切换/模式切换）
  - `services/EmbyClient.ts`（全部 Emby API 方法）
  - `services/MediaClient.ts`（抽象接口，PlexClient 实现相同接口）
  - `types.ts`（全部类型定义）
  - `components/DeleteConfirmDialog.tsx`（删除确认，可选实现）

---

## 交付前最后检查

- [ ] Checkpoint 20.1: `flutter analyze` 无严重错误（error/warning 数量为 0 或已备案）
- [ ] Checkpoint 20.2: `flutter test` 全部通过
- [ ] Checkpoint 20.3: 在至少 2 种物理设备（一部 Android 手机、一部 Android TV 或 TV 模拟器）上功能验证通过
- [ ] Checkpoint 20.4: 所有用户偏好设置冷启动后仍保持
- [ ] Checkpoint 20.5: 登录/退出流程完整，退出时能重新登录
- [ ] Checkpoint 20.6: README 中添加了新功能说明与截图
- [ ] Checkpoint 20.7: 所有新增的文件都有明确的中文注释，关键函数有文档注释
