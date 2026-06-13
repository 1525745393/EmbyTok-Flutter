# EmbyTok Flutter v1.2 原生能力增强 - Verification Checklist

> 用于验证本次重构/扩展是否达到预期功能。
> 每项建议结合代码检查 + 真机调试。

---

## Phase 1: 模型与服务层

- [ ] CL-1.1 `MediaItem.fromJson` 能解析 Emby 原生 `People` 数组 → `List<Person>`
  - [ ] 每个 Person 字段：name、role（Character / Job）、type（Actor/Director/Writer/Composer）、id、imageTag（用于生成头像 URL `{server}/Items/{id}/Images/Primary?MaxWidth=200`）
  - [ ] `Person` 有 `avatarUrl`（构造自 id + imageTag + apiKey）
  - [ ] People 数组前几位按 Actor 优先，其次是 Director/Writer

- [ ] CL-1.2 `MediaItem` 支持多种图片类型
  - [ ] `imageTags` 字段：`{'Primary': 'abc123', 'Backdrop': 'def456', 'Logo': '111'}`
  - [ ] `imageUrl(String type, {int maxWidth = 800})` → `{server}/Items/{id}/Images/{type}?MaxWidth={maxWidth}&Format=jpg&api_key={key}`
  - [ ] 多种尺寸：`MaxWidth=200`（缩略图）、`MaxWidth=400`（卡片）、`MaxWidth=1200`（背景图）

- [ ] CL-1.3 `MediaItem.userData` 解析完整
  - [ ] `playbackPositionTicks`（用于续播）
  - [ ] `playCount`（播放次数）
  - [ ] `isFavorite`
  - [ ] `played`
  - [ ] `lastPlayedDate`

- [ ] CL-1.4 `MediaItem.type` 区分：Movie / Series / Episode / MusicVideo / Trailer / Person / Boxset / MusicAlbum / MusicArtist / Studio / Genre

- [ ] CL-1.5 新增 `MediaSource` & `MediaStream` 模型
  - [ ] `MediaSource`: id, name, protocol, path, container, bitrate, mediaStreams
  - [ ] `MediaStream`: index, type (Audio/Video/Subtitle), language, codec, channels, bitrate, height, width, isDefault, isForced, deliveryUrl (for subtitles)

- [ ] CL-1.6 EmbytokService 新增方法组均调用成功，HTTP 200，解析正常
  - [ ] `getItemDetail(itemId)` → `GET /Users/{userId}/Items/{itemId}?Fields=...` 响应 200
  - [ ] `getResumeItems()` → 200
  - [ ] `getNextUp()` → 200
  - [ ] `getRecentlyAdded()` → 200
  - [ ] `getSimilarItems(itemId)` → 200
  - [ ] `getPeople(personTypes: 'Actor,Director')` → 200
  - [ ] `getPersonItems(personId)` → 200
  - [ ] `getGenres()` → 200
  - [ ] `getItemsByGenre('Action')` → 200
  - [ ] `getTrailers()` → 200
  - [ ] `markAsPlayed(itemId)` → 204 或 200
  - [ ] `markAsUnplayed(itemId)` → 204 或 200
  - [ ] `getSearchHints(query)` → 200
  - [ ] `getPlaybackInfo(itemId)` → 200
  - [ ] `getSeasons(seriesId)` → 200
  - [ ] `getEpisodes(seriesId, seasonId: ...)` → 200
  - [ ] `getSystemInfo()` → 200
  - [ ] `getUserAvatarUrl(userId)` → 返回可访问的图片 URL

---

## Phase 2: 播放增强

- [ ] CL-2.1 Resume 列表（继续观看）UI 正常
  - [ ] 页面能加载
  - [ ] 卡片显示缩略图、标题、剩余时长、进度条
  - [ ] 点击卡片播放并自动跳转到续播位置

- [ ] CL-2.2 续播（自动 seekTo）
  - [ ] 视频加载后自动 seek 到 `PlaybackPositionTicks / 10_000_000` 秒处
  - [ ] 若 `PlaybackPositionTicks == 0` 或无此字段 → 不自动 seek
  - [ ] 若 `PlaybackPositionTicks` 非常接近结尾（剩余 < 30 秒）→ 从头播放或提示

- [ ] CL-2.3 播放进度上报（增强）
  - [ ] 每 30 秒上报一次 `POST /Users/{userId}/PlayingItems/{itemId}/Progress`
  - [ ] 上报携带：`ItemId`, `PositionTicks`, `MediaSourceId`, `PlaySessionId`, `IsPaused`, `UserId`
  - [ ] 播放结束上报 `Stopped`，携带 `PositionTicks = runtime`

- [ ] CL-2.4 音轨选择
  - [ ] 播放页齿轮按钮 → 弹出轨道选择面板
  - [ ] `getPlaybackInfo(itemId)` 返回多个 Audio MediaStream
  - [ ] 显示：语言 / 编码 / 声道
  - [ ] 当前选中项高亮
  - [ ] 选择后：重新构造播放 URL `/Videos/{id}/stream?static=true&AudioStreamIndex=<idx>&api_key=...`
  - [ ] 新 URL 播放器重新加载，切换到目标语言

- [ ] CL-2.5 字幕选择
  - [ ] 齿轮 → 字幕面板
  - [ ] 列出 Subtitle MediaStream 列表（含是否内嵌、语言）
  - [ ] 选择外部字幕 → 从 `deliveryUrl` 下载 VTT/SRT → `SubtitleRenderer` 渲染
  - [ ] 选择内嵌字幕 → 通过 `SubtitleStreamIndex=` 参数传递给播放器
  - [ ] 可切换为"关闭字幕"

- [ ] CL-2.6 清晰度/多版本选择（可选）
  - [ ] 如 MediaSources 有多个（1080p / 720p / 480p），允许切换
  - [ ] 切换后重新构造播放 URL

---

## Phase 3: 浏览/发现

- [ ] CL-3.1 影视详情页 `ItemDetailView`
  - [ ] Backdrop 顶部大图（若存在）
  - [ ] Primary 海报（若存在）
  - [ ] 标题 + 年份 + 类型 chips
  - [ ] 时长 / 评分 / 分级
  - [ ] 简介
  - [ ] 演员/导演网格（横向滚动）
  - [ ] 演员点击 → 跳转到 `PersonDetailView`
  - [ ] "继续观看"/"从头播放" 按钮
  - [ ] "已观看"切换按钮
  - [ ] 底部 "相似影片" 横向卡片列表

- [ ] CL-3.2 继续观看页面
  - [ ] 列表从 `/Items/Resume` 加载
  - [ ] 每卡片：缩略图、标题、进度条、剩余时长
  - [ ] 点击播放

- [ ] CL-3.3 最近加入
  - [ ] 按 `DateCreated` 降序
  - [ ] 分组标题（今日 / 本周 / 本月 / 更早）
  - [ ] 网格卡片

- [ ] CL-3.4 演员/导演
  - [ ] 人员列表页（按出演数排序）
  - [ ] 人员详情页：头像、姓名、简介、出演作品横向卡片列表
  - [ ] 作品卡片 → 点击跳转到 `ItemDetailView`

- [ ] CL-3.5 类型 / 工作室 / 标签浏览
  - [ ] 类型页面：网格展示所有类型（chips / card grid）
  - [ ] 点击类型 → 该类型影片列表
  - [ ] 工作室页面同理

- [ ] CL-3.6 高级搜索与搜索提示
  - [ ] 输入过程中显示 `Search Hints` 建议列表
  - [ ] 点击建议直接进入该项详情或播放
  - [ ] 结果页顶部"过滤器"按钮
  - [ ] 过滤器：仅电影 / 仅剧集 / 仅人员 / 年份范围 / 最低评分
  - [ ] 应用过滤器后请求 URL 含 `IncludeItemTypes`/`minPremiereDate`/`maxPremiereDate`/`minCommunityRating`
  - [ ] 过滤结果正确

---

## Phase 4: 剧集与高级功能

- [ ] CL-4.1 电视剧季列表
  - [ ] 点击 Series → `ItemDetailView` 展示季列表（S1, S2...）
  - [ ] 每季卡片：海报、名称、集数、是否已看进度

- [ ] CL-4.2 剧集集列表
  - [ ] 展开某季 → 显示 Episodes（Ep01、Ep02...）
  - [ ] 每集卡片：缩略图、集号、标题、简介、时长、"已观看"/"未观看"/"部分观看"状态+进度条
  - [ ] 点击某集 → 播放该集

- [ ] CL-4.3 Next Up（下一步看什么）
  - [ ] 列表展示 `/Shows/NextUp`
  - [ ] 每卡片：剧名、SxxExx、集标题、缩略图
  - [ ] 点击 → 播放

- [ ] CL-4.4 相似影片
  - [ ] 详情页底部横向卡片
  - [ ] 从 `/Items/{itemId}/Similar` 加载
  - [ ] 点击 → 进入对应 `ItemDetailView`

- [ ] CL-4.5 预告片
  - [ ] 详情页有"观看预告片"按钮（如预告片存在）
  - [ ] 点击 → 复用 `VideoPlayerWidget` 播放预告片

---

## Phase 5: 用户设置 / 打磨

- [ ] CL-5.1 用户头像
  - [ ] 设置页顶部显示用户头像（`/Users/{userId}/Images/Primary?MaxWidth=200`）
  - [ ] 显示用户名、服务器名称、服务器版本
  - [ ] 按钮"退出登录"正常清除 token 并跳转登录页

- [ ] CL-5.2 图片缓存与懒加载
  - [ ] `cached_network_image` 正常工作
  - [ ] 占位图（loading）
  - [ ] 错误占位图
  - [ ] 相同 URL 重复加载时命中缓存

- [ ] CL-5.3 Token 安全存储（可选）
  - [ ] Token 使用 `flutter_secure_storage` 而非 `shared_preferences`
  - [ ] 多服务器/多用户 token 独立存储
  - [ ] 退出登录正确清除

- [ ] CL-5.4 代码结构与可读性
  - [ ] Service 层按模块清晰
  - [ ] Provider 命名规范
  - [ ] 无明显 500+ 行巨型文件
  - [ ] 关键方法有简明中文注释

- [ ] CL-5.5 集成测试（真机走通）
  - [ ] 登录 → 首页加载 → 滑动视频 → 搜索 → 播放 → 标记已观看 → 退出登录
  - [ ] Android 至少 2 款机型
  - [ ] 无 crash、无 404、无明显 UI 错位

---

## 总体验收

- [ ] **功能清单（与 v1.1 对比）**
  - [ ] ✅ 竖屏流式观看保留且更稳定
  - [ ] ✅ 完整详情页（简介/演员/评分/类型/相似）
  - [ ] ✅ 电视剧季/集结构
  - [ ] ✅ 继续观看 & 自动续播
  - [ ] ✅ 多音轨、多字幕选择
  - [ ] ✅ 演员/导演/类型/工作室浏览
  - [ ] ✅ 高级搜索与过滤器
  - [ ] ✅ Next Up / 最近加入 / 相似影片
  - [ ] ✅ 所有新功能通过 Emby 原生 API 实现，无后端依赖

- [ ] **性能与稳定性**
  - [ ] 首屏加载 ≤ 1.5 秒（已登入状态）
  - [ ] 滑动 50 个视频卡片无明显掉帧
  - [ ] 切换页面无白屏/闪烁

- [ ] **代码质量**
  - [ ] 编译无 warning（或仅有可解释的少量）
  - [ ] `flutter analyze` 通过
  - [ ] `flutter build apk --release` 成功
  - [ ] CI 构建通过
