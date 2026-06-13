# EmbyTok Flutter v1.2 原生能力增强 - Product Requirement Document

## Overview
- **Summary**: 扩展 EmbyTok Flutter 客户端，从"竖屏流式观看个人媒体库"升级为"全面利用 Emby 原生能力的完整媒体客户端"。当前客户端仅使用 Emby API 的约 10% 能力（基本的浏览/搜索/收藏/播放）。本项目目标是系统性地接入 Emby 原生的 Continue Watching、Resume Playback、Items Detail、Actors/Directors、Genres、Similar Recommendations、Audio/Subtitle Tracks、Season/Episode、TV Show NextUp、Recently Added、Live TV、Music 等全部能力，使客户端成为一个功能丰富、体验完整的 Emby 原生第三方客户端。

- **Purpose**: 解决当前客户端功能过于简化、无法替代 Emby Web UI 进行日常使用的问题。目前的客户端只能"看"，但无法：从上次停止的位置续播、查看影片详情与演员表、按类型/演员/导演浏览、查看电视剧的季和集、选择音轨和字幕、发现服务器上新加入的内容、发现相似影片等。这些能力 Emby 服务器原生已经支持，客户端只需调用对应 API 即可提供完整体验。

- **Target Users**: 
  - 初级用户：希望用手机轻松浏览私人媒体库的普通用户（竖屏流式观看）
  - 中级用户：想要完整详情页、剧集浏览、多音轨多字幕的用户
  - 高级用户：需要全功能浏览、多服务器、播放列表、音乐播放的用户
  - 维护者：希望代码结构清晰、API 封装完整、易于扩展的开发者

## Goals
- **G1 (核心能力)**: 实现完整的影视详情展示（简介、年份、评分、演员表、类型、制作信息、相似影片、预告片、后续剧集）
- **G2 (播放增强)**: 实现多音轨选择、多字幕选择、多清晰度选择、从上次位置续播（Emby Resume）
- **G3 (发现/浏览)**: 实现按演员、导演、类型、工作室浏览；最新入库、继续观看、推荐、下一步看什么（Next Up）
- **G4 (电视剧集)**: 实现电视剧季/集结构浏览（点击剧集看 SxxExx 列表）
- **G5 (横屏详情)**: 在竖屏流式观看的基础上，加入横屏/卡片式详情页
- **G6 (音乐 / 音乐视频 - 可选)**: 支持音乐专辑列表、艺人、歌曲播放
- **G7 (多图片类型)**: 支持 Primary / Backdrop / Logo / Thumb 等多种图片类型
- **G8 (高级搜索)**: 搜索过滤（仅电影/仅剧集/仅人/按年份/按评分）
- **G9 (代码结构)**: EmbytokService 全面覆盖 Emby API，提供可扩展的统一数据模型

## Non-Goals (Out of Scope)
- 不会替换 Emby 官方 Server 端（依然为纯客户端）
- 不会实现媒体库管理（添加/删除/重命名）和用户创建，这属于管理员功能，不在本期范围
- 不会实现字幕在线下载/字幕搜索（Emby 已有此服务器功能）
- 不会实现实时聊天 / 社交功能
- 不会实现直播电视（Live TV）的完整支持（Live TV 在 v2.0 考虑）
- 不会实现 DLNA / 投屏功能（超出 Emby API 能力）
- 不会实现图片/照片画廊模式（照片/图片库不属于本版本）

## Background & Context
**当前状态**（v1.1.x）:
- 竖屏 TikTok 式浏览：✅ 已实现
- 基本 API：登录 / 媒体库 / Items 列表 / 搜索 / 收藏 / 播放进度上报
- 数据模型：`MediaItem` 只有 title、type、year、rating、overview、thumbnailUrl
- 视频播放：只支持单视频流（`/Videos/{id}/stream`），无音轨/字幕选择
- 无详情页，无演员/导演信息，无剧集结构
- 从播放位置续播：本地有 watchHistoryProvider，但未使用 Emby 的 `PlaybackPositionTicks`

**Emby 原生 API 全景**:
- `/Items?ParentId=` — 列表（已使用）
- `/Users/{userId}/Items/{itemId}` — 单个项详情（未使用：含 People、Genres、Studios 等）
- `/Items/Resume` — 继续观看（Continue Watching）
- `/Shows/NextUp` — 剧集下一步看什么
- `/Shows/{showId}/Seasons` + `/Shows/{showId}/Episodes` — 剧集季/集列表
- `/Persons?personTypes=Actor,Director&Recursive=true` — 演员/导演
- `/Persons/{personId}/Items` — 某演员出演的所有作品
- `/Genres?Recursive=true` — 类型标签
- `/Items/{itemId}/Similar` — 相似影片
- `/Items/{itemId}/PlaybackInfo` — 播放信息（音频/字幕/清晰度轨道）
- `/Videos/{id}/{mediaSourceId}/Subtitles/{index}/Stream.{format}` — 字幕文件
- `/Items/{itemId}/Images/{imageType}` — 多种图片（Primary/Backdrop/Logo/Thumb/Art/Box/BoxRear/Menu 等）
- `/Trailers?Recursive=true` — 预告片
- `/Library/MediaFolders?IsHidden=false` — 媒体文件夹
- `/Library/SelectableMediaFolders` — 可选择的媒体文件夹
- `/System/Info` — 系统信息
- `/Users/{userId}/Images` — 用户头像
- `/Users/{userId}/PlayedItems/{itemId}` (POST/DELETE) — 标记为已观看/未观看
- `/Users/{userId}/PlayingItems/{itemId}/Progress` (POST) — 上报播放进度（已部分实现，不完整：缺 MediaSourceId 和 PlaySessionId）
- `/Sessions` — 当前会话
- `/Users/{userId}/Items/{itemId}/Download` — 下载

**技术栈约束**:
- Flutter 3.x + Dart 3.x（null-safe）
- 无后端、直接连接 Emby 服务器
- 必须保持竖屏流式观看为核心体验，但允许加入横屏详情卡页面

## Functional Requirements

### FR-1: 影视详情页
- 视频流卡片上点击标题或新增"详情"按钮 → 打开全屏详情页
- 详情页展示：标题、年份、分级、社区评分、类型标签、时长、简介、演员/导演卡片列表、相似影片、预告片、所属剧集（如果是电视剧集则显示所属剧集）、标记为已观看/未观看按钮、从上次位置播放按钮
- 图片：主海报（Primary）、背景图（Backdrop）、缩略图（Thumb）、Logo（如有）
- 点击演员 → 跳转到演员/导演详情页（该演员出演的作品列表）
- 点击类型标签 → 跳转到该类型的所有影片列表

### FR-2: 继续观看（Resume Playback / Continue Watching）
- 首页顶部或新增的"继续"页显示：用户上次未看完、且未过 7 天的影片
- 使用 Emby 原生的 `/Items/Resume`，从 `PlaybackPositionTicks` 计算续播位置
- 每个卡片显示：缩略图、标题、进度条、剩余时长、"继续观看"按钮
- 播放某个视频时：如果服务器有 `PlaybackPositionTicks` 且大于 0 且不接近结尾，则自动跳转到该位置开始播放
- 视频播放结束时（或用户点击"标记已观看"）：调用 POST `/Users/{userId}/PlayedItems/{itemId}`

### FR-3: 剧集结构浏览（Season / Episode）
- 当前列表中点击一个"Series"类型的项 → 展示该剧详情页，包含：海报、标题、简介、评分、季列表
- 每个季可以展开：展示该季的集列表，每集有：标题、集号、简介、缩略图、时长、是否已观看、上次观看位置
- 点击某一集 → 竖屏播放该集
- Next Up：用户看到"下一步看什么"列表（按剧的下一集未看集排序）
- Recently Added Episodes：新加入的集数

### FR-4: 人员浏览（演员/导演）
- 支持浏览服务器上所有演员/导演/编剧/制作人
- 按出演作品数量排序
- 演员详情页：头像、姓名、简介、出演作品列表（电影分开展示）
- 点击作品 → 播放该作品

### FR-5: 按类型、工作室、年份浏览
- 类型页面：展示所有类型标签（动作、喜剧、科幻等），按每项数量排序
- 类型详情页：该类型下所有影片（电影/剧集分开）
- 同样支持工作室（Studios）、关键词（Tags）浏览

### FR-6: 高级搜索与过滤器
- 搜索栏下方显示：仅电影、仅剧集、仅人、全部
- 搜索结果页：支持按年份范围过滤、按评分过滤、按类型过滤、按工作室过滤
- 搜索建议（Search Hints）：`/Search/Hints`

### FR-7: 多音轨、多字幕选择
- 播放页右下角新增"齿轮"图标 → 打开轨道选择
- 获取 PlaybackInfo → 解析 MediaStreams
- 列出所有 Audio 轨道（语言/编码/位率）
- 列出所有 Subtitle 轨道（语言/格式/外部或内嵌）
- 选中的字幕由 Emby 服务器提供 `Stream.{format}` URL（subrip/vtt/ttml 等）
- 选中的音轨通过 `?AudioStreamIndex=` 参数传递给 `/Videos/{id}/stream`
- 选中的字幕通过 `?SubtitleStreamIndex=` 参数传递给播放器（或从字幕 URL 下载渲染）

### FR-8: 图片类型扩展（Backdrop / Logo / Thumb 等）
- MediaItem 支持多种图片类型：Primary（海报）、Backdrop（背景）、Logo、Thumb、Art、Banner
- 支持多尺寸：请求时带 `MaxWidth` 参数
- 详情页顶部使用 Backdrop 作为背景
- 横屏播放页可以显示 Logo

### FR-9: 最近加入（Recently Added）
- 页面显示服务器最近加入的媒体
- 按时间分组（今日、本周、本月）
- 使用 `SortBy=DateCreated,SortOrder=Descending`

### FR-10: 推荐与相似影片
- `/Items/{itemId}/Similar`：与当前影片相似
- 详情页底部：横向滚动的相似影片卡片
- 首页"猜你喜欢"：根据观看历史推荐

### FR-11: 用户信息与头像
- 顶部显示当前用户头像（`/Users/{userId}/Images/Primary`）
- 用户设置中显示用户名、用户 ID、EmbyConnect 状态
- 支持多服务器（未来扩展）

### FR-12: 统一数据模型
- 扩展 `MediaItem`：加入 Genres、Studios、People、ImageTags、RunTimeTicks、UserData、MediaSources 等全部 Emby 字段
- 新增 `Person`、`Genre`、`Studio`、`MediaSource`、`MediaStream`、`Trailer`、`SearchHint` 等模型
- EmbytokService 按功能拆分为多个方法组

### FR-13: 增强的搜索（Search Hints）
- 使用 `/Search/Hints` 获取搜索建议
- 支持区分类型（Movie/Series/Person/Episode/MusicVideo）

### FR-14: 播放会话管理
- 播放时上报 PlaySessionId、MediaSourceId
- 播放过程中定时上报进度（已部分实现，增强字段）
- 支持播放信息更新（每次 30 秒上报一次 PlaybackProgress）

## Non-Functional Requirements

- **NFR-1 (性能)**: 页面首次加载 ≤ 1.5 秒；详情页图片懒加载；分页 20/页，滚动预加载
- **NFR-2 (网络)**: 网络错误统一处理；无网络时显示"无网络连接"；断网后恢复自动重连
- **NFR-3 (缓存)**: 用户 Token 加密持久化（当前 shared_preferences → 使用 flutter_secure_storage）
- **NFR-4 (图像缓存)**: 使用 `cached_network_image` 或 equivalent 缓存缩略图，避免重复请求
- **NFR-5 (代码质量)**: EmbytokService 拆分清晰，API 封装完整；新增 Provider 遵循现有模式
- **NFR-6 (无障碍)**: 所有按钮/卡片/列表项均有语义标签
- **NFR-7 (屏幕方向)**: 竖屏为主，详情页支持横屏（MediaQuery orientation）
- **NFR-8 (可测试)**: 所有 Service 方法可测试，Provider 支持 Override

## Constraints
- **技术约束**: Flutter / Dart；无后端；使用 Dio 进行 HTTP 请求；video_player 作为视频播放引擎
- **API 约束**: 仅使用 Emby 原生 REST API（版本 ≥ 4.7.0）
- **UI 约束**: 竖屏流式观看（TikTok 风格）为核心交互；详情页为横屏/卡片式
- **安全约束**: Token 必须通过请求头 `X-Emby-Token` 发送；不可在 URL 查询参数中长期暴露 Token（除了视频流 URL 和图片 URL）

## Assumptions
- 目标用户的 Emby 服务器版本 ≥ 4.7
- 用户已在 Emby 服务器上完成媒体库配置与元数据抓取
- 设备有良好的网络连接（本地 WiFi / 5G / 远程通过 emby.connect）
- 播放视频的设备使用 video_player 可正常播放主流格式（MP4 / MKV / HLS）

## Acceptance Criteria

### AC-1: 影视详情页
- **Given**: 用户在首页或搜索页看到一个视频卡片
- **When**: 用户点击该卡片上的"详情"按钮或点击信息区域
- **Then**: 打开全屏详情页，显示：标题、年份、时长、评分、类型标签、简介、演员/导演卡片（含头像）、相似影片横向列表
- **Verification**: `programmatic`（页面正确路由、API 返回 200）
- **Notes**:

### AC-2: 继续观看列表
- **Given**: 用户有已开始观看但未完成的视频（服务器有 PlaybackPositionTicks）
- **When**: 用户进入"继续"页
- **Then**: 展示从 `/Items/Resume` 获得的列表，每个卡片显示缩略图、标题、进度条、剩余时长
- **Verification**: `programmatic`（API 返回有 resume Ticks 的项渲染进度条）

### AC-3: 自动续播位置
- **Given**: 用户上次在 12 分 30 秒处关闭一个影片（服务器 `PlaybackPositionTicks > 0`）
- **When**: 用户再次点击播放该影片
- **Then**: 视频播放器自动跳转到 12 分 30 秒处开始播放
- **Verification**: `programmatic`（从服务器获取 PlaybackPositionTicks，传入 video_player seekTo）

### AC-4: 标记为已观看/未观看
- **Given**: 用户在详情页看到当前影片状态
- **When**: 点击"已观看"按钮
- **Then**: 调用 `POST /Users/{userId}/PlayedItems/{itemId}`；再次点击未观看 → `DELETE`；UI 即时更新
- **Verification**: `programmatic`（调用成功、状态切换、乐观更新）

### AC-5: 电视剧季/集结构
- **Given**: 用户点击一个 Series 类型的项
- **When**: 进入剧集详情页
- **Then**: 显示该剧的概述，下方为季列表（S1, S2...），展开某季显示该季集列表；点击某集播放该集
- **Verification**: `programmatic`（`/Shows/{showId}/Seasons` 和 `/Shows/{showId}/Episodes` 返回正常）

### AC-6: Next Up（下一步看什么）
- **Given**: 用户正在追某部电视剧
- **When**: 进入"下一步看什么"页
- **Then**: 展示 `/Shows/NextUp` 返回的剧集列表，按未看集的下一集排序
- **Verification**: `programmatic`

### AC-7: 演员/导演浏览
- **Given**: 服务器有演员元数据
- **When**: 用户点击详情页的演员
- **Then**: 进入演员详情页，展示头像、简介、出演作品列表
- **Verification**: `programmatic`（`/Persons/{personId}/Items` 返回正常）

### AC-8: 类型、工作室、年份浏览
- **Given**: 服务器有多个类型
- **When**: 用户进入"类型"页面
- **Then**: 展示所有类型标签（每项带数量），点击进入该类型影片列表
- **Verification**: `programmatic`（`/Genres?Recursive=true` 正常，Items 过滤带 GenreIds）

### AC-9: 高级搜索与过滤器
- **Given**: 用户在搜索栏输入查询词
- **When**: 打开过滤菜单选择"仅电影 / 评分 ≥ 7 / 年份 ≥ 2020"
- **Then**: `/Items?SearchTerm=...&IncludeItemTypes=Movie&minCommunityRating=7&minPremiereDate=2020-01-01` 返回筛选后的结果
- **Verification**: `programmatic`

### AC-10: 音轨选择
- **Given**: 正在播放有多条音轨的视频（例如英语+国语+粤语）
- **When**: 用户点击齿轮图标 → "音轨"
- **Then**: 展示可用的音轨，选择后以 `AudioStreamIndex=` 参数重新加载视频流
- **Verification**: `programmatic`（`PlaybackInfo` 返回 MediaStreams，选择更新播放 URL）

### AC-11: 字幕轨道选择
- **Given**: 正在播放有多条字幕的视频
- **When**: 用户点击齿轮图标 → "字幕"
- **Then**: 展示可用的字幕，选择后从 Emby 服务器获取该字幕的 `Stream.vtt` 或 `Stream.srt`，渲染到视频
- **Verification**: `programmatic`（`SubtitleStreamIndex` 更新，下载字幕文件并渲染）

### AC-12: 多种图片类型
- **Given**: MediaItem 支持 Backdrop 等图片
- **When**: 进入详情页
- **Then**: 顶部显示 Backdrop 图片，主海报显示 Primary；Logo 角标显示 Logo（如有）
- **Verification**: `programmatic`（`/Items/{id}/Images/Backdrop?MaxWidth=1200` URL 正确）

### AC-13: 最近加入
- **Given**: 服务器有最近添加的媒体
- **When**: 进入"最近加入"页
- **Then**: 展示按 DateCreated 降序的列表，分组显示（今日/本周/本月/更早）
- **Verification**: `programmatic`

### AC-14: 推荐与相似影片
- **Given**: 正在查看某个影片的详情页
- **When**: 滚动到底部
- **Then**: 展示"相似影片"横向列表；从 `/Items/{itemId}/Similar` 获取
- **Verification**: `programmatic`

### AC-15: 用户头像
- **Given**: 用户已登录且服务器中有用户头像图片
- **When**: 进入设置页或首页顶部
- **Then**: 显示用户头像图片
- **Verification**: `programmatic`（`/Users/{userId}/Images/Primary?MaxWidth=200` URL 正确）

### AC-16: 增强的搜索提示
- **Given**: 用户在搜索栏输入文字
- **When**: 输入过程中
- **Then**: 显示 `Search/Hints` 返回的搜索建议（"星球大战"、"斯皮尔伯格"等），可点击直接跳转
- **Verification**: `programmatic`

### AC-17: 预告片
- **Given**: 某个影片有预告片
- **When**: 详情页有"预告片"按钮
- **Then**: 点击播放预告片（类型为 Trailer 的项的 `/Videos/{id}/stream`）
- **Verification**: `programmatic`

### AC-18: 播放进度上报（增强）
- **Given**: 用户正在播放视频
- **When**: 播放中每 30 秒或位置变化超过阈值
- **Then**: 上报 `POST /Users/{userId}/PlayingItems/{itemId}/Progress`，带上 PlaySessionId、MediaSourceId、PositionTicks
- **Verification**: `programmatic`（Emby 服务器其他客户端能看到位置同步）

### AC-19: 数据模型统一与扩展
- **Given**: 开发者打开 `models/` 目录
- **When**: 检查 MediaItem
- **Then**: MediaItem 包含来自 Emby `BaseItemDto` 的完整字段（People、Genres、Studios、ImageTags 等）
- **Verification**: `human-judgment`（代码审查）

### AC-20: 无后端继续有效
- **Given**: 所有改动
- **When**: 用户使用客户端直接连 Emby
- **Then**: 所有新功能都通过 Emby 原生 API 工作，不依赖后端
- **Verification**: `programmatic`（所有请求 target 为 Emby 服务器地址）

## Open Questions
- [ ] 音乐/音乐视频是否在本期纳入？（倾向：音乐视频 yes，纯音乐 v1.3 再做）
- [ ] 预告片需要专用播放器吗？还是复用当前播放器？（倾向：复用）
- [ ] Live TV / 图片画廊是否保留给 v2.0？（倾向：是，不在本期）
- [ ] 是否需要离线缓存/下载功能？（倾向：不在本期，由 v1.3 做）
- [ ] Emby Connect 登录支持？（倾向：本期不做）
- [ ] 多用户切换？（倾向：本期仅单用户）
