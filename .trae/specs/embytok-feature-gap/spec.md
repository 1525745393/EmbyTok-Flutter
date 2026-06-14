# EmbyTok Flutter APP 功能增强 - Product Requirement Document

## Overview
- **Summary**: 借鉴 EmbyTok React 版（React/TypeScript）的完整功能设计，对 Flutter APP 进行功能增强，使 APP 具备更完善的媒体浏览和播放体验，包括真正可用的字幕播放、主题切换、剧集层级导航、继续观看列表、高级过滤排序、图片缓存、视频预加载等核心功能。
- **Purpose**: 解决当前 Flutter APP 存在的若干核心功能缺失问题，提升用户体验：
  - 字幕功能当前 HTTP 加载实现被注释，字幕无法显示
  - 主题模式切换 Provider 已实现但 MaterialApp 未接入，无法实际生效
  - 剧集/季/集层级导航缺失，系列内容无法以结构化方式浏览
  - 继续观看列表 UI 缺失，与 Emby 服务端的 Resume 接口未打通
  - 高级过滤排序功能缺失，用户无法按年份、类型、评分筛选内容
  - CachedNetworkImage 依赖已引入但未广泛使用，图片未有效缓存
  - PageView 切换视频无预加载机制，切换时可能出现黑屏
  - 多语言国际化（i18n）完全缺失，所有文案硬编码为中文
- **Target Users**: 使用 Emby 或 Plex 媒体服务器的移动端用户，期望获得类似 TikTok 的沉浸式竖屏浏览体验，同时希望支持多语言、剧集导航、字幕显示等完整媒体应用体验。

## Goals
- 修复字幕功能，使其能从 Emby 服务器加载字幕文件并正确显示
- 使主题模式切换真正生效，支持亮色/深色/跟随系统三种模式
- 实现剧集层级导航，支持从系列 → 季 → 集的层级浏览
- 实现继续观看列表 UI，从 Emby 服务端的 Resume 接口获取数据并展示
- 实现高级过滤排序 UI，支持按年份、类型、评分、时长筛选
- 全面启用图片缓存（CachedNetworkImage），提升图片加载性能
- 实现 PageView ±1 项视频预加载，改善视频切换体验
- 实现播放完成上报，将观看状态同步回 Emby 服务端

## Non-Goals (Out of Scope)
- 视频离线下载/缓存功能（需大量本地存储管理，后续单独版本实现）
- 多语言国际化完整实现（作为未来版本，涉及大量文案翻译，工作量极大）
- Emby 账户注册、密码找回等非核心功能
- 跨平台的桌面端 UI 适配（当前仅聚焦移动端）
- Web 版适配（当前聚焦 Flutter APP）

## Background & Context
- EmbyTok React 版（https://github.com/1525745393/EmbyTok）是一个较完整的 React/TypeScript 实现，包含视频播放、搜索、收藏、字幕、观看历史、剧集导航、继续观看等核心功能
- 当前 Flutter APP 已实现基础的视频流浏览（feed 页）、搜索页、收藏页、历史页、设置页、登录页，但部分高级功能缺失或未真正生效
- 技术栈：Flutter 3.x + Dart 3.x + Riverpod 2.x + go_router + Dio + video_player + Python FastAPI（可选后端代理）
- 当前 Flutter 项目已具备完整的服务层 API 封装（embbytok_service.dart，20+ 接口），大部分功能仅缺 UI 接入
- 修改应遵循"小步重构 + 频繁提交"的开发流程，每次改动需确保可构建且行为一致

## Functional Requirements

### FR-1: 字幕功能修复与增强
- 修复视频页面的字幕内容加载（当前 _loadSubtitleContent 的 HTTP 实现被注释）
- 支持从 Emby 字幕流端点加载字幕（如 /Videos/{itemId}/{subtitleIndex}/Subtitles.{format}）
- 支持 SRT 字幕格式解析（已存在但需验证）
- 字幕样式支持字号、颜色、位置配置（provider 已存在，需验证与 UI 集成）
- 字幕选择器支持语言选择和"关闭字幕"选项（UI 已存在）
- 字幕 URL 构造应支持 Emby 认证（附加 api_key 或 X-Emby-Token 头）

### FR-2: 主题模式真正生效
- MaterialApp 接入 themeModeProvider，支持亮/暗/跟随系统三种模式
- 定义完整的 ThemeData 亮色主题和暗色主题
- 主题切换后立即生效（无需重启应用）
- 主题设置持久化到 SharedPreferences（provider 已实现，需验证 MaterialApp 集成）
- 深色主题保持当前的黑色风格，亮色主题使用白色背景 + 深色文字

### FR-3: 剧集层级导航（系列/季/集）
- 视频播放页或信息面板添加"剧集信息"入口（如 MediaItem.type == 'series' 时显示）
- 季列表页：展示系列的所有季度，封面、季号、名称、集数
- 集列表页：展示所选季度的所有集数，封面、集号、标题、时长、播放状态
- 点击集数跳转到视频播放页，传递 itemId 和从集数恢复的初始位置
- 底部导航或 Feed 页不增加新入口，通过内容详情页进入
- 服务层已有 getSeasons() 和 getEpisodes()，需验证并接入 UI

### FR-4: 继续观看列表 UI
- 新增"继续观看"页面或在 Feed 页顶部增加 ContinueWatching 区域
- 从 Emby 服务端 getResumeItems() 获取播放进度数据（ItemId、播放时间、总时长）
- 列表项展示缩略图、标题、进度条（百分比）、相对时间（如"昨天观看"）
- 点击列表项跳转到视频播放页，从上次观看位置继续播放
- 支持左滑删除（从本地记录移除，不同步到 Emby 服务端的删除操作）
- 在首页 Feed 的顶部可选地展示"继续观看"分区（横向滑动）

### FR-5: 高级过滤排序
- 在 Feed 页或媒体库页面添加"过滤/排序"入口（顶部工具栏按钮）
- 过滤选项支持：年份范围、类型（电影/剧集/音乐）、最低评分、最短时长
- 排序选项支持：最近添加、评分、字母序、时长
- 过滤状态持久化到本地（可选）
- 服务层 getLibraryItems 需扩展支持 years/genres/minCommunityRating/minDuration/sortBy 参数
- 过滤/排序弹窗采用底部弹出式设计（BottomSheet）

### FR-6: 图片缓存全面启用
- 将所有 Image.network 调用替换为 CachedNetworkImage
- 覆盖范围：视频卡片缩略图、搜索结果、收藏列表、历史列表、剧集列表
- 使用 placeholder 显示加载中状态（圆形/方形进度指示器）
- 使用 errorWidget 显示加载失败状态
- 缓存策略由 cached_network_image 默认提供，无需额外配置

### FR-7: 视频预加载
- 在 PageView.builder 中实现 ±1 页视频的预加载
- 当用户停留在当前页时，预初始化前后视频的 VideoPlayerController
- 使用 Future.delayed 或帧回调延迟预初始化，避免抢占当前页资源
- 当用户滑动到下一页时，目标视频应已初始化完毕，减少切换时延
- 不预加载超过 ±1 页，避免资源浪费
- 当用户快速滑动多页时，取消未完成的预初始化，仅保留当前页及相邻页

### FR-8: 播放完成上报
- 在视频播放完毕或用户退出视频页时，上报观看进度到 Emby 服务端
- 使用 reportPlaybackStopped 接口（如有）或手动构造播放记录
- 上报内容：itemId、播放位置、总时长
- 仅当播放进度 >30 秒且 >总时长的 5% 时才上报（避免误操作）
- 上报失败时本地缓存重试策略（简化版：仅在失败时记录，不实现复杂重试）

## Non-Functional Requirements

### NFR-1: 代码质量
- 所有新增代码遵循项目现有代码规范（Riverpod Provider 命名、Widget 分层、服务层封装）
- 保持"函数只做一件事"原则，避免多层嵌套
- 新增 Provider 必须在 providers/providers.dart 导出

### NFR-2: 性能
- 图片缓存后，同一张图片二次加载应显著快于首次加载（用户感知层面）
- 视频预加载后，从 PageView 一页切换到下一页时，视频应在 500ms 内开始播放
- 过滤/排序操作不应阻塞主线程，复杂计算在异步任务中完成

### NFR-3: 向后兼容
- 主题切换不应破坏现有的深色主题默认样式（深色应为默认 fallback）
- 字幕功能增强不应破坏无字幕视频的正常播放
- 剧集导航是可选入口，不会影响单一视频内容的播放流程

### NFR-4: 可维护性
- 每个功能模块应有独立的 Provider 和 Widget
- 复杂交互逻辑应封装在可测试的 Hook 或 Provider 中
- 避免直接在 Build 方法中执行异步 IO 操作

## Constraints

### Technical
- Flutter 版本保持 3.x（按 pubspec.yaml 当前声明）
- Riverpod 版本保持 2.x（当前项目使用的 StateNotifier 模式）
- video_player 插件保持当前版本（如有版本不兼容需谨慎处理）
- 必须支持 Android 平台（应用的主要发布渠道）

### Business
- 所有功能应保持与 Emby 服务端 API 的直连能力
- 后端代理仅为可选方案，不应成为功能必需依赖
- 功能变更不应破坏现有登录流程、媒体库浏览、视频播放的基础能力

### Dependencies
- Emby API 接口（/Users/AuthenticateByName, /Items, /Videos, /Shows 等）
- cached_network_image 包（已引入）
- SharedPreferences（已引入）

## Assumptions
- Emby 服务端版本不会出现破坏性 API 变更（4.x+ 的 API 应稳定）
- 用户设备已安装并可正常访问 Emby 服务器
- 字幕文件为 SRT 格式（Emby 默认提供）
- 主题系统中，默认主题为深色，与当前应用视觉风格一致

## Acceptance Criteria

### AC-1: 字幕正常显示
- **Given**: 用户正在播放的视频包含可用字幕轨道
- **When**: 用户点击字幕按钮，选择一个可用语言
- **Then**: 字幕文本在视频下方正常显示，随播放时间自动切换不同字幕条目
- **Verification**: `human-judgment`
- **Notes**: 可通过 Emby 管理界面确认视频是否有字幕

### AC-2: 主题切换立即生效
- **Given**: 用户在设置页中选择"亮色主题"
- **When**: 用户点击确认选择
- **Then**: 整个应用（包括当前页和返回的所有页）立即切换为亮色设计，背景变为浅色，文字变为深色
- **Verification**: `human-judgment`
- **Notes**: 需验证标题栏、底部导航、视频信息面板等所有区域

### AC-3: 剧集层级导航可用
- **Given**: 用户播放的视频属于某一剧集（Series）
- **When**: 用户点击视频信息面板的"剧集信息"或"查看全集"入口
- **Then**: 用户进入季列表页，选择季后进入集列表页，点击集数可从该剧集开始播放
- **Verification**: `human-judgment`
- **Notes**: 需确认 MediaItem 的 type 字段或 IsSeries 属性

### AC-4: 继续观看列表展示
- **Given**: 用户之前在 Emby 服务器上有观看记录（通过 Resume 接口可查询）
- **When**: 用户进入"继续观看"页或 Feed 页顶部
- **Then**: 系统展示继续观看列表，每项含缩略图、标题、进度条（百分比）、相对时间，点击可从上次位置继续播放
- **Verification**: `human-judgment`
- **Notes**: 若无 Emby 服务端观看记录，该页面应显示空状态

### AC-5: 过滤排序可用
- **Given**: 用户在 Feed 页或媒体库页
- **When**: 用户点击"过滤/排序"按钮，选择"仅电影"且"按评分排序"
- **Then**: 列表重新加载，仅显示电影类型内容，且按评分从高到低排序
- **Verification**: `human-judgment`

### AC-6: 图片缓存生效
- **Given**: 用户浏览过的视频缩略图已加载过一次
- **When**: 用户返回 Feed 页或进入相同内容的其他页面
- **Then**: 图片应几乎瞬间显示（从本地缓存读取），无需重新发起网络请求
- **Verification**: `human-judgment`
- **Notes**: 可通过关闭网络连接后验证图片是否仍可正常显示

### AC-7: 视频预加载改善体验
- **Given**: 用户正在播放视频，且后续视频可在当前 Feed 流中
- **When**: 用户向上滑动切换到下一个视频
- **Then**: 视频在 500ms 内开始播放（而非黑屏等待数秒）
- **Verification**: `human-judgment`
- **Notes**: 首次进入 Feed 流时预加载可能不生效（属于预期）

### AC-8: 播放完成上报成功
- **Given**: 用户播放视频超过 30 秒（或超过总时长的 5%）
- **When**: 用户关闭视频或播放完毕
- **Then**: 观看进度上报到 Emby 服务端，服务端的"继续观看"列表中出现该条记录
- **Verification**: `human-judgment`
- **Notes**: 需在 Emby 管理界面或官方客户端中验证继续观看列表的更新

## Open Questions
- [ ] **剧集数据模型**：Emby 的 series/season/episode 数据结构是否需要在 MediaItem 中新增专门字段？当前 MediaItem 可能没有 seasonNumber/episodeNumber 等属性。
- [ ] **过滤参数 API**：Emby API 对过滤参数（years, genres, minCommunityRating, sortBy）的具体命名和取值范围需要在实际开发时验证。
- [ ] **字幕流格式**：Emby 字幕流端点返回的是纯 SRT 文本还是需要特殊处理的编码格式？需实际测试。
- [ ] **继续观看的进度存储**：Emby 服务端返回的 Resume 数据包含播放时间，这与我们本地 watch_history_provider 存储的进度是否一致？若不一致，以谁为准？
- [ ] **主题亮色模式的细节设计**：亮色主题下，视频信息面板、操作按钮的颜色需要单独设计，是否需要 UI/UX 层面的补充设计？
- [ ] **视频预加载的资源控制**：预加载是否会导致网络带宽过度消耗？是否需要在移动网络下禁用预加载？

---

**文档版本**: v1.0  
**创建日期**: 2026-06-14
