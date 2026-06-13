# EmbyTok Flutter v1.2 原生能力增强 - The Implementation Plan

> 总体策略：分 5 个阶段共 16 个任务推进。
> 每个 Task 由独立子代理实现并验证。
> 阶段 1-2 为基础重构（不影响现有功能），
> 阶段 3-4 为新增页面与功能，阶段 5 为打磨与发布。

---

## Phase 1: 模型与服务层重构（Task 1-2）
## Phase 2: 播放增强（Task 3-4）
## Phase 3: 发现/浏览页面（Task 5-9）
## Phase 4: 剧集结构与高级功能（Task 10-13）
## Phase 5: 发布与打磨（Task 14-16）

---

## [ ] Task 1: 扩展 MediaItem 数据模型 & 新增子模型
- **Priority**: P0
- **Depends On**: None
- **Description**: 
  - 扩展 `MediaItem`：加入 `people`（演员/导演列表）、`genreNames`、`studioNames`、`imageTags`（多种图片类型映射）、`communityRating`、`criticRating`、`officialRating`（分级）、`runTimeTicks`、`productionYear`、`premiereDate`、`dateCreated`、`seriesName`、`seasonName`、`indexNumber`（集号）、`parentIndexNumber`（季号）、`seriesId`、`seasonId`、`mediaSources`（播放源信息，含多音轨/字幕）、`userData`（PlaybackPositionTicks、PlayCount、IsFavorite、Played）、`type`（Movie/Series/Episode/MusicVideo/Person/...）
  - 新增模型：`Person`（演员/导演/编剧/制作人，含 name、role、type、imageUrl）、`MediaSource`（播放源，含 id、name、bitrate、videoStreamIndex、audioStreamIndex、subtitleStreams）、`MediaStream`（单个音轨/视频轨/字幕轨，含 language、codec、channels、bitrate、height/width、type、index、isDefault、isForced、deliveryUrl）、`SearchHint`、`Trailer`
  - 所有模型都支持 `fromJson(Map<String, dynamic>)` 与 `toJson()`
- **Acceptance Criteria Addressed**: AC-19（统一数据模型）
- **Test Requirements**:
  - `programmatic` TR-1.1：新增 models/*.dart 文件通过静态分析
  - `programmatic` TR-1.2：`MediaItem.fromJson` 正确解析 `People` → 生成 `List<Person>`
  - `programmatic` TR-1.3：`MediaItem.withEmbyUrls()` 保持兼容，同时为 Person/Genre 生成缩略图
  - `human-judgment` TR-1.4：代码结构清晰，便于后续 Service 层调用
- **Notes**: 保持对 `thumbnailUrl`/`playbackUrl`/`playbackHttpHeaders` 的向后兼容；不破坏现有 FeedView 渲染

## [ ] Task 2: EmbytokService 全面扩展（按功能分组的新 API 封装）
- **Priority**: P0
- **Depends On**: Task 1
- **Description**: 
  - 按功能组扩展 `EmbytokService`，每个方法封装一次网络调用：
    - **User & Auth**: `login`、`pingServer`、`setupAuth`（已存在）
    - **Item 详情**: `getItemDetail(String itemId)` → `GET /Users/{userId}/Items/{itemId}?Fields=Overview,Genres,People,CommunityRating,RuntimeTicks,ProductionYear,PremiereDate,DateCreated,Studios,MediaSources,UserData`
    - **Continue Watching**: `getResumeItems({int limit = 20, int offset = 0})` → `GET /Users/{userId}/Items/Resume?Recursive=true&Limit=20&...`
    - **Next Up**: `getNextUp({int limit = 20})` → `GET /Shows/NextUp?Limit=20&UserId=...`
    - **Recently Added**: `getRecentlyAdded({String? libraryId, int limit = 20})` → `GET /Users/{userId}/Items/Latest?Limit=20&SortBy=DateCreated&SortOrder=Descending`
    - **Similar Items**: `getSimilarItems(String itemId, {int limit = 12})` → `GET /Items/{itemId}/Similar?Limit=12&UserId=...`
    - **People**: `getPeople({String? personTypes = 'Actor,Director', int limit = 50, int offset = 0})` → `GET /Persons?PersonTypes=Actor,Director&Recursive=true&Limit=50&UserId=...`
    - **Person Detail & Works**: `getPersonItems(String personId, {int limit = 50})` → `GET /Persons/{personId}/Items?IncludeItemTypes=Movie,Series&Recursive=true&Limit=50&UserId=...`
    - **Genres / Studios / Tags**: `getGenres({int limit = 100})` → `GET /Genres?Recursive=true`；`getItemsByGenre(String genre, {int limit = 40})` → `GET /Items?Genres=<genre>&IncludeItemTypes=Movie,Series&Limit=40`
    - **Trailers**: `getTrailers({int limit = 20})` → `GET /Items?IncludeItemTypes=Trailer&Recursive=true&Limit=20`
    - **Mark Played/Unplayed**: `markAsPlayed(String itemId, {int? playedTicks})` → `POST /Users/{userId}/PlayedItems/{itemId}`；`markAsUnplayed(String itemId)` → `DELETE /Users/{userId}/PlayedItems/{itemId}`
    - **Search Hints**: `getSearchHints(String query, {int limit = 10})` → `GET /Search/Hints?SearchTerm=<query>&IncludeItemTypes=Movie,Series,Episode,MusicVideo,Person&Limit=10&UserId=...`
    - **Playback Info**: `getPlaybackInfo(String itemId)` → `GET /Items/{itemId}/PlaybackInfo?UserId=...` （返回 MediaSources 列表，含所有音轨/字幕轨索引）
    - **Seasons & Episodes**: `getSeasons(String seriesId)` → `GET /Shows/{seriesId}/Seasons?UserId=...`；`getEpisodes(String seriesId, {String? seasonId, int limit = 40, int offset = 0})` → `GET /Shows/{seriesId}/Episodes?SeasonId=<seasonId>&Limit=40&UserId=...`
    - **User Avatar**: `getUserAvatarUrl({String? userId, int maxWidth = 200})` → 构造 `/Users/{userId}/Images/Primary?MaxWidth=200&api_key=...`
    - **System Info**: `getSystemInfo()` → `GET /System/Info`（需鉴权）
  - 所有新方法通过 `_requireAuth()` 检查鉴权；失败时抛出带有可读消息的异常
- **Acceptance Criteria Addressed**: AC-19（模型）、AC-3（续播）、AC-6（Next Up）、AC-7（演员）、AC-8（类型）、AC-10（音轨）、AC-11（字幕）、AC-14（相似）、AC-17（预告片）
- **Test Requirements**:
  - `programmatic` TR-2.1：每个新方法都能正确构造 URL + 正确解析响应
  - `programmatic` TR-2.2：`getPlaybackInfo` 返回的 `MediaStreams` 被解析为音轨（type=Audio）和字幕轨（type=Subtitle），且包含 `index`（用于 `AudioStreamIndex=` 参数）
  - `programmatic` TR-2.3：`getItemDetail` 返回的 `PlaybackPositionTicks` 被正确解析
  - `human-judgment` TR-2.4：Service 代码结构清晰，按功能组划分，易于后续扩展
- **Notes**: 为防止单个文件过大，可考虑将 Service 按模块拆分（例如 item_service.dart、discovery_service.dart、playback_service.dart），但在 Task 2 阶段保持为单个 `EmbytokService` 类即可，后续 refactor 作为独立的 Task 14

---

## Phase 2: 播放增强

## [ ] Task 3: 续播（Resume from PlaybackPositionTicks）
- **Priority**: P0
- **Depends On**: Task 2
- **Description**: 
  - 在 `EmbytokService` 新增 `getResumeItems`（已在 Task 2 定义）
  - 创建 `resumeProvider`（`FutureProvider` 或 `StateNotifierProvider`）：拉取"继续观看"列表
  - 修改 `VideoPlayerWidget` / `VideoPageItem`：如果 `item.userData?.playbackPositionTicks != null` 且 > 60 秒（1 分钟），则视频播放器在初始化后自动 `seekTo` 到该位置
  - 在视频流 URL 中加入 `?StartTimeTicks=<ticks>` 或直接由 video_player `seekTo` 到 `playbackPositionTicks / 10_000_000` 秒
  - 在首页或专用"继续观看"页展示 Resume 列表
- **Acceptance Criteria Addressed**: AC-2（列表）、AC-3（自动续播）
- **Test Requirements**:
  - `programmatic` TR-3.1：Resume 列表接口正常响应
  - `programmatic` TR-3.2：播放器收到 ticks 后自动 seek 到正确时间（误差 < 2 秒）
  - `human-judgment` TR-3.3：继续观看卡片展示进度条、剩余时长，体验友好

## [ ] Task 4: 播放轨道选择（音轨/字幕/清晰度）& 增强的 PlaybackInfo
- **Priority**: P0
- **Depends On**: Task 1-3
- **Description**: 
  - 创建 `PlaybackSettings` 数据模型：`audioStreamIndex`, `subtitleStreamIndex`, `maxBitrate`
  - 创建 `playbackSettingsProvider`：保存当前选择
  - 在 `VideoPlayerWidget` 底部新增"齿轮"设置按钮 → 弹出底部 `PlaybackSettingsSheet`
  - `PlaybackSettingsSheet` 调用 `getPlaybackInfo(itemId)` 加载可用轨道；
    - 音轨：显示 `MediaStream.Type == Audio` 的列表（语言/编码/声道）
    - 字幕：显示 `MediaStream.Type == Subtitle` 的列表（语言/格式/是否内嵌）
    - 清晰度：显示 `MediaSource` 列表（如果有多个版本，如 1080p vs 480p）
  - 选择音轨后：构造新的播放 URL `/Videos/{id}/stream?static=true&AudioStreamIndex=<idx>&api_key=...`，并在需要时通过 `httpHeaders` 发送认证；重新加载 video_player 控制器
  - 选择字幕：若字幕来自 Emby 的 `deliveryUrl`（外部字幕），下载 SRT/VTT 并交给 `SubtitleRenderer`；若字幕为内嵌字幕（`IsExternal=false`），通过 `SubtitleStreamIndex=` 参数嵌入到播放器
  - 增强播放进度上报：引入 `PlaySessionId` 和 `MediaSourceId`，上报频率每 30 秒一次
- **Acceptance Criteria Addressed**: AC-10（音轨）、AC-11（字幕）、AC-18（进度上报增强）
- **Test Requirements**:
  - `programmatic` TR-4.1：`PlaybackInfo` 接口能正确解析为音轨/字幕轨列表
  - `programmatic` TR-4.2：切换音轨后视频播放器重新加载，听到正确语言
  - `programmatic` TR-4.3：选择字幕 → SubtitleRenderer 正确渲染字幕
  - `human-judgment` TR-4.4：设置按钮点击、打开、关闭流畅自然

---

## Phase 3: 发现/浏览页面

## [ ] Task 5: 影视详情页 UI（Item Detail Page）
- **Priority**: P0
- **Depends On**: Task 1, 2
- **Description**: 
  - 创建新页面 `ItemDetailView`：顶部 Backdrop 图，主海报 Primary，标题+年份+类型标签+评分+时长，简介，演员/导演网格（横向滚动头像+姓名+角色），"标记已观看/未观看"按钮，"继续观看"按钮（如果有 PlaybackPositionTicks），下方"相似影片"横向卡片列表，"预告片"按钮（如 trailer 存在），所属剧集信息（若为 Episode 显示所属剧集）
  - 创建 `itemDetailProvider(itemId)`（family provider）：加载 `getItemDetail(itemId)` 的响应
  - 在 `VideoPageItem` 上点击标题或新增"ⓘ详情"按钮 → 路由跳转到 `ItemDetailView`
  - `GoRouter` 中注册 `/item/:id` 路由
- **Acceptance Criteria Addressed**: AC-1（详情页）、AC-12（多种图片类型）
- **Test Requirements**:
  - `programmatic` TR-5.1：`ItemDetailView` 能正确渲染（Backdrop + Primary + 详情信息）
  - `programmatic` TR-5.2：点击演员跳转到 Person 详情页（Task 7 完成后验证）
  - `programmatic` TR-5.3：标记已观看/未观看功能正常（POST/DELETE 成功）
  - `human-judgment` TR-5.4：UI 美观，图片不溢出，支持横屏和竖屏

## [ ] Task 6: 继续观看（Continue Watching）页面 & 最近加入
- **Priority**: P0
- **Depends On**: Task 2
- **Description**: 
  - 修改 `HomeScaffold` 的底部导航：从 5 项 → 6 项（首页、搜索、收藏、继续、最近加入、设置），或者将"继续"和"最近加入"放在"首页"的顶部横向卡片组。推荐做法：首页顶部横滚 card 组展示 Continue Watching，下方保留 Vertical PageView 视频流。新增两个独立页面："继续观看"和"最近加入"。
  - 创建 `ContinueWatchingView`：卡片列表，每张卡片显示缩略图、标题、时长进度条、剩余时长、"继续"按钮
  - 创建 `RecentlyAddedView`：分组显示（今日/本周/本月/更早），网格卡片
  - 创建 `resumeListProvider` / `recentlyAddedProvider`
- **Acceptance Criteria Addressed**: AC-2（Continue Watching）、AC-13（Recently Added）
- **Test Requirements**:
  - `programmatic` TR-6.1：`/Items/Resume` 正常返回并渲染
  - `programmatic` TR-6.2：`Recently Added` 正确按 DateCreated 分组
  - `human-judgment` TR-6.3：进度条/剩余时长显示友好

## [ ] Task 7: 演员/导演浏览（People）
- **Priority**: P1
- **Depends On**: Task 2, Task 5
- **Description**: 
  - 创建 `PeopleBrowseView`：按出演数排序的演员/导演网格
  - 创建 `PersonDetailView`：头像、姓名、简介、出演作品列表（横向滚动卡片）
  - `peopleProvider`（FutureProvider）、`personProvider(personId)`（family provider）
  - 详情页中点击人员卡片 → `PersonDetailView`
- **Acceptance Criteria Addressed**: AC-7（演员/导演浏览）
- **Test Requirements**:
  - `programmatic` TR-7.1：`/Persons` 返回演员列表，被正确展示
  - `programmatic` TR-7.2：`/Persons/{personId}/Items` 返回作品列表，被正确展示
  - `human-judgment` TR-7.3：人员头像圆角显示、角色标签清晰

## [ ] Task 8: 类型 / 工作室 / 标签浏览（Genres/Studios/Tags）
- **Priority**: P1
- **Depends On**: Task 2
- **Description**: 
  - 创建 `GenresView` / `StudiosView`：网格或 chips 形式的类型/工作室标签，每个标签带对应数量
  - 创建 `GenreItemsView`：该类型下的影片列表（分 Movies/Series 显示）
  - 使用 API：`/Genres`、`/Studios`、`/Items?Genres=<name>`
  - 详情页中点击 Genre Chip → 进入 `GenreItemsView`
- **Acceptance Criteria Addressed**: AC-8（类型浏览）
- **Test Requirements**:
  - `programmatic` TR-8.1：`/Genres?Recursive=true` 返回结果
  - `programmatic` TR-8.2：`/Items?Genres=<name>` 返回过滤后的项

## [ ] Task 9: 高级搜索与搜索提示（Search Hints & Filters）
- **Priority**: P1
- **Depends On**: Task 2
- **Description**: 
  - 重构 `SearchView`：
    - 输入时展示 `Search Hints` 建议（来自 `/Search/Hints`），可点击直接跳转
    - 搜索结果上方新增"过滤器"按钮：弹出过滤菜单（仅电影/仅剧集/仅人员、年份范围滑块、最低评分）
    - 过滤条件：`IncludeItemTypes`、`minPremiereDate/maxPremiereDate`、`minCommunityRating`
  - 搜索结果点击 → `ItemDetailView`（Movie/Series）、`VideoPageItem`（Episode/Movie 可直接播放）、`PersonDetailView`（Person）
- **Acceptance Criteria Addressed**: AC-9（高级搜索）、AC-16（搜索提示）
- **Test Requirements**:
  - `programmatic` TR-9.1：`Search/Hints` 返回结果并展示
  - `programmatic` TR-9.2：过滤参数正确附加到 URL，返回结果仅含匹配项
  - `human-judgment` TR-9.3：过滤器 UI 易用

---

## Phase 4: 剧集结构与高级功能

## [ ] Task 10: 电视剧季/集结构浏览（Season & Episode）
- **Priority**: P0
- **Depends On**: Task 2, Task 5
- **Description**: 
  - 扩展 `ItemDetailView`：当 item.type == `Series` 时，展示下方的"季"tab 或"季"列表（S1, S2...），每个季可以展开展示该季的集列表
  - 每集卡片：缩略图、集号、标题、简介、时长、"已观看"标识、进度条（如未看完）、点击播放该集
  - API：`/Shows/{seriesId}/Seasons` → 季列表；`/Shows/{seriesId}/Episodes?SeasonId=<id>` → 某季的集
  - 创建 `SeasonCard` / `EpisodeCard` Widget
  - 创建 `seriesDetailProvider(seriesId)`（family provider，加载 Seassons + Episodes）
- **Acceptance Criteria Addressed**: AC-5（电视剧季/集）
- **Test Requirements**:
  - `programmatic` TR-10.1：Seasons 和 Episodes 接口响应正确
  - `programmatic` TR-10.2：点击某一集能正常播放该集（使用 Episode ItemId 的 `/Videos/{id}/stream`）
  - `human-judgment` TR-10.3：季/集 UI 层级清晰

## [ ] Task 11: Next Up（下一步看什么）
- **Priority**: P1
- **Depends On**: Task 2, Task 10
- **Description**: 
  - 创建 `NextUpView`：展示 `/Shows/NextUp` 返回的下一集
  - 每卡片：剧集标题、SxxExx、集标题、缩略图、时长、"播放"按钮
  - 可作为首页的一个横向 card 组或独立页面
- **Acceptance Criteria Addressed**: AC-6（Next Up）
- **Test Requirements**:
  - `programmatic` TR-11.1：`/Shows/NextUp` 返回结果被正确解析和展示
  - `human-judgment` TR-11.2：卡片格式与电视剧集一致

## [ ] Task 12: 推荐与相似影片（Similar Items）
- **Priority**: P1
- **Depends On**: Task 2, Task 5
- **Description**: 
  - 在 `ItemDetailView` 底部展示"相似影片"横向卡片列表
  - API：`/Items/{itemId}/Similar?Limit=12&UserId=...`
  - 创建 `SimilarItemsRow` Widget
  - 首页"猜你喜欢"：从 `/Items?SortBy=PlayCount,SortName&SortOrder=Descending&Limit=12&Recursive=true` 或 `/Items?IsRecommended=true`（如果 Emby 支持 `IsRecommended`）
- **Acceptance Criteria Addressed**: AC-14（相似影片）
- **Test Requirements**:
  - `programmatic` TR-12.1：`/Items/{itemId}/Similar` 返回结果
  - `human-judgment` TR-12.2：横向卡片流畅滚动

## [ ] Task 13: 预告片（Trailers）播放支持
- **Priority**: P2
- **Depends On**: Task 2, Task 4
- **Description**: 
  - `ItemDetailView` 中若有 Trailer 类型相关项显示"▶ 观看预告片"按钮
  - 使用 `/Items?ParentId=<itemId>&IncludeItemTypes=Trailer` 或 `/Trailers` 获取预告片列表
  - 复用当前视频播放器播放 trailer
- **Acceptance Criteria Addressed**: AC-17（预告片）
- **Test Requirements**:
  - `programmatic` TR-13.1：Trailer 列表接口返回正常
  - `programmatic` TR-13.2：预告片可以正常播放

---

## Phase 5: 打磨与发布

## [ ] Task 14: 用户信息页 & 多服务器管理（User Profile）
- **Priority**: P2
- **Depends On**: Task 2
- **Description**: 
  - 在 `SettingsView` 顶部展示：用户头像（`/Users/{userId}/Images/Primary`）、用户名、服务器名称、服务器版本（`/System/Info`）
  - "退出登录"按钮（清除 token，返回登录页）
  - 多服务器管理：保存多个 Emby 服务器配置；允许切换和删除。使用 `shared_preferences` 存储多个 `{serverUrl, userId, token, serverName}`。当前单用户单服务器也应正常。
- **Acceptance Criteria Addressed**: AC-15（用户头像）
- **Test Requirements**:
  - `programmatic` TR-14.1：设置页展示用户头像
  - `programmatic` TR-14.2：退出登录正确清除 token 并跳转登录页

## [ ] Task 15: 代码重构与性能优化（拆分 Service / 缓存 / 加密）
- **Priority**: P2
- **Depends On**: Task 1-14
- **Description**: 
  - 拆分 `EmbytokService` 为多个子 Service（可选）：
    - `auth_service.dart`（login/ping/setupAuth/systemInfo）
    - `item_service.dart`（items/detail/resume/next up/recently added/similar）
    - `discovery_service.dart`（people/genres/studios/tags/search hints）
    - `playback_service.dart`（markPlayed, progress/stopped, playbackInfo）
    - `series_service.dart`（seasons/episodes）
    - 由 `EmbytokService` 作为统一门面保留（不破坏现有 Provider）
  - 引入 `cached_network_image` 替代原始 `Image.network`，增加图片缓存与占位图
  - 引入 `flutter_secure_storage` 存储 Token（可选），或保留 shared_preferences 但增加命名空间
  - 图片 URL 使用 `&Quality=80&MaxWidth=...` 参数减小图片大小
- **Acceptance Criteria Addressed**: NFR-3（Token 加密）、NFR-4（图片缓存）、NFR-5（代码质量）、NFR-1（性能）
- **Test Requirements**:
  - `programmatic` TR-15.1：冷启动页面加载 ≤ 1.5 秒（首次）
  - `programmatic` TR-15.2：重复访问同一影片 → 图片来自缓存
  - `human-judgment` TR-15.3：代码结构清晰、分模块

## [ ] Task 16: 集成测试与发布准备
- **Priority**: P2
- **Depends On**: Task 1-15
- **Description**: 
  - 真机测试所有页面（Android 优先，iOS 可选）
  - 回归测试：登录、媒体库、搜索、收藏、播放、续播均正常
  - 版本号 bump：`pubspec.yaml` 1.1.x → 1.2.0；`android/app/build.gradle` versionCode/versionName
  - CHANGELOG 文档
  - GitHub Release（APK 附件）
- **Test Requirements**:
  - `human-judgment` TR-16.1：Android 真机完整走通所有核心流程
  - `human-judgment` TR-16.2：页面间导航流畅、无闪退、无 404

---

## 依赖关系图（简化）

```
┌──────────────────────────────────────────────────────────────┐
│  Phase 1: 基础（Task 1 = 模型, Task 2 = Service API）         │
│   Task 1 → Task 2 → 所有后续任务的地基                          │
└──────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────┐
│  Phase 2: 播放增强（Task 3 = 续播, Task 4 = 轨道选择）          │
│   Task 3 → Task 4                                             │
└──────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────┐
│  Phase 3: 浏览/发现（Task 5 = 详情, Task 6 = 继续/最近加入,  │
│                     Task 7 = People, Task 8 = Genres,         │
│                     Task 9 = 高级搜索）                         │
│   Task 5,6,7,8,9 可并行推进（依赖 Task 1-2）                   │
└──────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────┐
│  Phase 4: 剧集与高级功能（Task 10 = 剧集, Task 11 = NextUp,  │
│                            Task 12 = 相似, Task 13 = 预告）  │
│   Task 10 → Task 11 → Task 12, Task 13                       │
└──────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────┐
│  Phase 5: 打磨与发布（Task 14 = 用户设置, Task 15 = 重构,      │
│                       Task 16 = 测试&发布）                    │
└──────────────────────────────────────────────────────────────┘
```

## 完成预估（T-shirt size）

| 任务 | 规模 |
|------|------|
| Task 1（模型扩展） | M（2-3 天） |
| Task 2（Service API） | L（4-6 天） |
| Task 3（续播） | S（1-2 天） |
| Task 4（轨道选择） | L（3-5 天） |
| Task 5（详情页） | L（3-5 天） |
| Task 6（继续观看/最近加入） | M（2-3 天） |
| Task 7（People） | M（2-3 天） |
| Task 8（类型/工作室） | S（1-2 天） |
| Task 9（高级搜索） | M（2-3 天） |
| Task 10（剧集季/集） | L（3-5 天） |
| Task 11（Next Up） | S（1 天） |
| Task 12（相似） | S（1 天） |
| Task 13（预告片） | S（1 天） |
| Task 14（用户设置） | S（1-2 天） |
| Task 15（重构/优化） | M（2-3 天） |
| Task 16（测试发布） | M（2-3 天） |
| **合计** | **约 6-8 周** |
