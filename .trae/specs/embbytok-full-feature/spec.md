# EmbyTok Flutter APP - Product Requirement Document (v2 全面复刻版)

## Overview

- **Summary**: 基于参考项目 [migumigu/EmbyTok](https://github.com/migumigu/EmbyTok) 的 React 实现，在当前 Flutter 项目中全面复刻所有核心功能。重点包括：视频流/网格视图切换、三种浏览模式（最新/随机/收藏）、增强手势（单击播放/双击红心/长按2倍速/横向滑进度）、自动连播/纯净模式、系列多层导航（系列→季→集）、TV 模式、方向过滤、观看进度同步等。
- **Purpose**: 原 Flutter APP 仅实现了最基础的视频播放能力（FeedView + 简单播放），缺少大量让用户获得类 TikTok 使用体验的关键交互，以及 TV/家庭影院场景所需的导航能力。本 PRD 定义全面复刻所需的功能范围。
- **Target Users**: 拥有 Emby 服务器的个人用户，包括手机短视频浏览、平板大屏浏览、家庭影院 TV 遥控器操作。

## Background & Context

### 参考项目架构（React + TypeScript）

参考项目 `migumigu/EmbyTok` 使用：
- **入口组件拆分**: `App.tsx` → 根据 `localStorage` + `navigator.userAgent` 决定渲染 `StandardRoot`（标准端/移动端）或 `TVRoot`（TV 端）
- **标准端根组件 `StandardRoot.tsx`**: 集中所有应用级状态，包括 `config / libraries / selectedLib / videos / feedType / viewMode / currentIndex / isMuted / isFullscreen / isAutoPlay / orientationMode / hiddenLibIds`
- **视频流 `VideoFeed.tsx`**: 使用 CSS `scroll-snap` + `IntersectionObserver` 实现滑动切换，支持 ±1 预加载、遥控器键、自动连播
- **视频卡片 `VideoCard.tsx`**: 单体视频卡片，集成播放器、所有手势、红心动效、2倍速显示、进度条、信息面板
- **网格视图 `VideoGrid.tsx`**: 显示封面缩略图网格，支持点击跳转、系列/季/集的层级导航
- **收藏实现**: 直接操作 Emby 的 `Playlist`，命名为 `Tok-{libraryName}`，每个库一个收藏播放列表
- **Emby API 核心端点**:
  - 登录: `POST /Users/AuthenticateByName`
  - 媒体库: `GET /Users/{userId}/Views`
  - 视频列表: `GET /Users/{userId}/Items?IncludeItemTypes=Movie,Video,Episode&SortBy=DateCreated|Random&SortOrder=Descending`
  - 播放地址: `GET /Videos/{itemId}/stream.mp4?Static=true&api_key={token}`
  - 图片: `GET /Items/{itemId}/Images/Primary?maxWidth=800&tag={tag}&quality=90&api_key={token}`
  - 继续观看: `GET /Users/{userId}/Items/Resume`
  - 删除: `DELETE /Items/{itemId}?api_key={token}`

### 当前 Flutter APP 现状

已实现：
- ✅ 登录与退出
- ✅ FeedView 视频流（PageView.builder 竖向滑动）
- ✅ GestureOverlay 基础手势（快进/快退/双击）
- ✅ VideoPlayerWidget 视频播放
- ✅ HeartAnimation 红心动画
- ✅ VideoListProvider 分页加载
- ✅ 简单的 Library 选择
- ✅ 搜索视图

**待实现（本次 PRD 覆盖的范围）**：
- ❌ 视频流/网格视图切换
- ❌ 三种浏览模式（最新/随机/收藏）
- ❌ 增强手势（长按2倍速、横向滑动画进度）
- ❌ 自动连播模式
- ❌ 纯净模式（连播时隐藏所有 UI）
- ❌ 系列多层导航（系列→季→集）
- ❌ TV 模式（遥控器键控）
- ❌ 方向过滤（竖屏/横屏/全部）
- ❌ 观看进度同步（断点续播）
- ❌ 媒体库管理（显示/隐藏媒体库）
- ❌ 全屏切换
- ❌ Emby Playlist 收藏实现
- ❌ 2倍速/静音/全屏的图标反馈
- ❌ 视频方向自动适配（横屏视频在横屏显示，竖屏视频在竖屏显示）

## Goals

1. **完整的标准端视频流体验**：复刻 `VideoCard.tsx` 全部手势与交互
2. **三种浏览模式**：最新视频 / 随机推荐 / 收藏夹，可在顶部栏切换
3. **双视图切换**：视频流视图与网格视图一键切换
4. **系列多层导航**：进入系列库后先显示剧集网格→选择一部剧→季列表→集列表→播放
5. **自动连播 + 纯净模式**：打开后自动连续播放，隐藏所有 UI
6. **观看进度同步**：与 Emby 服务器同步播放位置，切换回网格视图时标记上次观看位置
7. **方向过滤**：可选择只看竖屏/横屏/全部视频
8. **TV 模式适配**：TV 遥控器方向键导航（与标准端在根组件处分流）
9. **媒体库管理**：媒体库可被隐藏，不参与内容加载
10. **照片库支持**：照片类型的库不走视频播放路径，全屏图片浏览

## Non-Goals (Out of Scope)

1. 不实现 Plex 服务器支持（参考项目有，但当前 Flutter 版本仅锁定 Emby）
2. 不开发音乐播放功能（参考项目未重点实现，不在本次复刻范围）
3. 不实现 Android 原生签名/发布流程（在 Flutter 层完成 UI/交互后由独立流程处理）
4. 不实现自定义字幕解析器（现有字幕渲染已满足需求）
5. 不实现 iOS Safari safe-area 特化适配（Flutter 的 `SafeArea` 和 `MediaQuery` 已足够）
6. 不实现跨设备同步偏好设置（仅在本地 `SharedPreferences` 持久化）
7. 不实现 Capacitor 桥接（纯 Flutter）

## Functional Requirements

### FR-1: 根组件架构（标准模式/TV 模式分流）
- App 启动时从本地持久化读取 `forceDeviceMode`（可选值 `standard` / `tv`）
- 未指定时，使用设备特性判断：屏幕尺寸 > 10 英寸或用户明确请求 TV 模式时走 TV 根
- 标准根（StandardRoot）承载所有核心状态：`authConfig / libraries / selectedLib / videos / feedType / viewMode / currentIndex / isMuted / isFullscreen / isAutoPlay / orientationMode / hiddenLibIds`
- TV 根（TVRoot）拥有独立的 TV 仪表盘视图，支持方向键/D-pad 导航

### FR-2: 三种浏览模式（latest/random/favorites）
- 用户可在顶部导航栏选择「最新 / 随机 / 收藏」
- **最新模式** (`latest`): 按 `DateCreated` 倒序加载
- **随机模式** (`random`): 使用 Emby 的 `SortBy=Random` 一次性拉取最多 200 个
- **收藏模式** (`favorites`): 从 Emby 播放列表 `Tok-{libraryName}` 读取，保持与服务器双向同步
- 模式切换时完整重置视频列表

### FR-3: 视频流/网格视图切换
- `viewMode` 可取 `feed`（视频流）或 `grid`（网格）
- 顶部工具栏有一键切换图标（网格图标 ↔ 手机图标）
- 网格视图中每个视频卡片显示：封面图、标题、时长、已播放进度指示（如有）
- 从网格视图点击某个视频后切换到 `feed` 视图，并定位到该视频

### FR-4: 增强手势（VideoCard 级）
- **单击**: 播放/暂停切换（显示中央 Play 图标）
- **双击**: 触发红心飞行动效，同时将当前视频加入收藏（若尚未收藏）
- **长按（> 500ms）**: 进入 2 倍速播放，松开恢复 1 倍速；顶部显示「2倍速中」横幅
- **横向滑动（ΔX > 20px，且 |ΔX| > |ΔY|）**: 调整播放进度，按 `ΔX/5` 秒偏移，实时显示「快进 N 秒 / 快退 N 秒」覆盖层
- 手势优先级：长按 > 横向滑动 > 单击/双击

### FR-5: 自动连播（AutoPlay）
- `isAutoPlay = true` 时：
  - 视频结束后自动跳转到下一个视频（不 loop）
  - 顶部工具栏/底部信息面板隐藏（进入「纯净模式」）
  - 首次开启时显示 Toast 提示「自动连播已开启」
- `isAutoPlay = false` 时：视频循环播放（loop）

### FR-6: 系列多层导航（Series → Season → Episode）
- 当媒体库类型为 `tvshows` 或首次返回的项中包含 `Series` 类型时，自动切换到网格视图
- 从系列列表点击 → 季列表网格 → 集列表网格 → 点击某集 → 进入视频流从该集开始播放
- 顶部有返回箭头和当前层级标题（navStack）
- 返回上级时保持之前的浏览位置

### FR-7: 方向过滤（Orientation Filter）
- 用户可选择：`vertical`（只看竖屏视频）/ `horizontal`（只看横屏视频）/ `both`（全部）
- 在菜单中切换，默认 `vertical`
- 判断逻辑：`item.Height >= item.Width * 0.8` 视为竖屏；`item.Width > item.Height` 视为横屏；均不满足时默认为「可显示」
- 过滤在客户端完成（因为 Emby API 本身没有方向过滤参数）

### FR-8: 观看进度同步（Resume Playback）
- 进入视频时读取 Emby `UserData.PlaybackPositionTicks`，将播放器定位到对应时间
- 播放过程中（每 30 秒或退出时）调用 Emby API 同步进度
- 网格视图中对有进度的项显示进度条/「继续观看」标记
- 支持「继续观看」单独 API：`/Users/{userId}/Items/Resume`

### FR-9: 收藏功能（Emby Playlist 实现）
- 收藏操作：将视频加入名为 `Tok-{libraryName}` 的 Emby 播放列表
- 取消收藏：从该播放列表移除
- 收藏图标：空心/填充红心切换，红色表示已收藏
- 双击红心手势也触发收藏切换

### FR-10: 媒体库管理（选择/隐藏）
- 首次登录后通过 `GET /Users/{userId}/Views` 拉取所有媒体库
- 菜单中列出所有库，每个库可选择「当前正在浏览的库」或「隐藏」
- 未选择特定库时，自动将所有未隐藏库的 `ParentIds` 合并查询

### FR-11: TV 模式
- TV 根组件使用 `Focus` + `RawKeyboardListener` 监听 D-pad 事件
- 方向键 ↓/↑：切换视频；←/→：±10 秒播放进度；Enter/Space：播放/暂停
- TV 主页先展示：最近观看、按库分类的内容，遥控器选择后进入视频流或网格
- 顶部工具栏保持可见，便于切换浏览模式/视图
- TV 模式下不支持触摸手势

### FR-12: 照片库浏览
- 媒体库的 `CollectionType === 'photos'` 或返回项目 `Type === 'Photo'` 时：
  - 视频流视图切换为图片流（`PhotoPageItem` 代替 `VideoPageItem`）
  - 使用 `Image.network` 全屏居中显示，支持 pinch-to-zoom（可选）
  - 无播放控制/静音按钮，简化操作面板

### FR-13: 全屏切换
- 顶部工具栏的全屏按钮：未全屏时请求进入横屏全屏模式；已全屏时退出
- 使用 Flutter 的 `SystemChrome.setPreferredOrientations` 与 `SystemChrome.setEnabledSystemUIMode` 控制

### FR-14: 用户偏好持久化
- 持久化存储的键：
  - `emby_server_url`
  - `emby_user_id`
  - `emby_access_token`
  - `emby_username`
  - `emby_force_device_mode`（`standard` / `tv`）
  - `emby_orientation_mode`（`vertical` / `horizontal` / `both`）
  - `emby_hidden_library_ids`（JSON 数组字符串）
  - `emby_is_muted`
  - `emby_is_auto_play`
  - `emby_last_feed_type`（`latest` / `random` / `favorites`）
- 使用 `shared_preferences` 包

### FR-15: 错误处理与空状态
- 网络失败：在视频流/网格中央显示错误信息 + 「重试」按钮
- 无视频：显示「未找到视频」图标 + 刷新按钮
- 切换到空收藏夹：显示「该库暂无收藏」

### FR-16: 视频方向自适应显示
- 判断视频宽高 `isContentLandscape = item.Width > item.Height`
- 判断屏幕方向 `isScreenLandscape = constraints.maxWidth > constraints.maxHeight`
- 横屏视频在竖屏设备上显示为 `BoxFit.contain`，并在背后加一层模糊背景海报
- 竖屏视频在竖屏设备上显示为 `BoxFit.cover`（更贴近 TikTok 体验）

## Non-Functional Requirements

### NFR-1: 性能
- 视频流视图中仅渲染当前视频及其 ±1 个相邻视频，其余占位为黑色背景
- 图片网格使用 `cached_network_image` 缓存，避免重复请求
- 切换视频时保持原有已下载数据（Emby 媒体流缓存由系统网络层负责）
- 长视频（> 3 分钟）且非自动连播模式时才显示进度条，避免 UI 干扰

### NFR-2: 可靠性
- 网络层所有请求使用 Dio + 统一错误拦截器，超时 30 秒
- 播放状态通过 `VideoPlayerValueListener` 感知播放结束/错误
- 配置缺失时明确回落到登录流程，无静默崩溃

### NFR-3: 可维护性
- 类型映射常量集中在 `utils/constants.dart`
- Provider 状态管理保持一致：每个独立关注点一个 `StateNotifier`
- UI 组件按视图（标准/TV）与功能（Feed/Grid/VideoCard）分层，遵循已有 `widgets/`、`views/` 目录结构

### NFR-4: 可访问性
- 关键操作按钮最小触摸区域 ≥ 44×44dp
- 文本与背景对比度 ≥ 4.5:1

### NFR-5: 国际化
- 所有字符串支持中文/英文切换，默认跟随系统语言
- 语言切换键 `language`：`zh` / `en`

## Constraints

### 技术栈
- **Flutter SDK**: >= 3.10.0 / Dart >= 3.0.0
- **状态管理**: flutter_riverpod ^2.5.0（保持现有方案）
- **视频播放**: video_player（保持现有方案，iOS/Android/macOS/Web 全平台）
- **图片缓存**: cached_network_image（已使用）
- **持久化**: shared_preferences
- **网络**: dio（已使用）
- **手势交互**: 自定义 `GestureDetector` + `Listener`（无需引入第三方手势库）
- **不引入**: flutter_riverpod_hooks 以外的新状态管理方案（保持项目一致性）

### API 约束
- 必须严格匹配 Emby 服务器原生 API 端点（/Users/... /Items/... /Videos/...）
- 认证必须同时通过 `X-Emby-Token`（请求头）和 `?api_key=xxx`（查询参数，用于图片/视频 URL）

### 依赖
- 不新增除 `shared_preferences` 外的三方包（当前项目已包含所有必需库）
- 如需引入新的图标库需在 spec 评审阶段单独提出

## Assumptions

1. 假设 Emby 服务器版本 ≥ 4.7.0，支持 `SortBy=Random`、`/Items/Resume` 等端点
2. 假设用户的 Emby 账号拥有视频播放与收藏所需权限（非 Guest）
3. 假设 Flutter `video_player` 可正确处理循环（loop）与手动 `seekTo`
4. 假设 TV 模式下用户设备具备遥控器（Android TV / 智能电视 WebView）
5. 假设所有视频均能通过 `/Videos/{id}/stream.mp4?Static=true` 访问

## Acceptance Criteria

### AC-1: 最新模式按创建时间加载
- **Given**: 用户选择了「最新」模式
- **When**: 视频流列表加载
- **Then**: 返回结果按 `DateCreated` 倒序，最多 200 条
- **Verification**: `programmatic` — 检查请求参数 `SortBy=DateCreated`、`SortOrder=Descending`

### AC-2: 随机模式随机拉取
- **Given**: 用户选择了「随机」模式
- **When**: 视频流列表加载
- **Then**: 一次拉取 200 个，并支持底部「换一批」按钮
- **Verification**: `programmatic` — 检查请求参数 `SortBy=Random`

### AC-3: 收藏模式从 Emby Playlist 加载
- **Given**: 用户点击收藏按钮
- **When**: 服务端写入操作成功
- **Then**: 下次打开「收藏」模式能看到刚收藏的内容；取消收藏后从列表消失
- **Verification**: `programmatic` — 通过 `getTokPlaylistId` / `getTokPlaylistItemsInternal` 路径验证

### AC-4: 视频流视图上下滑动切换
- **Given**: 用户在视频流视图
- **When**: 向上/向下滑动
- **Then**: 平滑切换到上/下一个视频，当前视频播放，其他视频停止并回到 00:00
- **Verification**: `human-judgment` — 在真机上验证切换流畅度，切换后首个视频正确播放

### AC-5: 网格视图点击跳转到对应视频
- **Given**: 用户在网格视图
- **When**: 点击某个视频封面
- **Then**: 视图切换为视频流，并将当前播放位置定位到该视频
- **Verification**: `programmatic` — 验证 `currentIndex` 与点击项的索引一致

### AC-6: 单击切换播放/暂停
- **Given**: 用户在视频流视图，视频正在播放
- **When**: 单击屏幕中央
- **Then**: 视频暂停，并显示中央 Play 图标
- **Verification**: `programmatic` — 验证 `videoPlayer.value.isPlaying` 状态切换

### AC-7: 双击红心动画 + 收藏
- **Given**: 用户在视频流视图
- **When**: 300ms 内双击同一点
- **Then**: 从双击点出现红心动效，向上飘动并消失；若未收藏则加入收藏
- **Verification**: `human-judgment` — 动画流畅、红心可见且符合参考项目效果

### AC-8: 长按 2 倍速播放
- **Given**: 用户在视频流视图
- **When**: 按住屏幕 > 500ms 不移动
- **Then**: 播放器 `playbackRate = 2.0`，屏幕顶部显示「2倍速中」横幅
- **Verification**: `programmatic` — 验证 `playbackRate` 值与松开后回到 1.0

### AC-9: 横向滑动调整进度
- **Given**: 用户在视频流视图，且非自动连播模式
- **When**: 在屏幕上横向滑动 ≥ 20px，且横向位移 > 纵向位移
- **Then**: 屏幕中央显示「±N 秒」图标与时间偏移；松手后播放器 seek 到新位置
- **Verification**: `programmatic` — 验证 `seekTo` 调用参数与显示提示一致

### AC-10: 自动连播 + 纯净模式
- **Given**: 用户开启自动连播模式
- **When**: 当前视频播放完毕
- **Then**: 自动滚动到下一个视频并播放；顶部/底部操作面板隐藏
- **Verification**: `programmatic` — 验证：① `loop = false`；② `onEnded` 触发下一个视频；③ 顶部工具栏 `Opacity = 0`

### AC-11: 系列库多层导航
- **Given**: 用户选择了 `tvshows` 类型媒体库
- **When**: 加载列表
- **Then**: 自动进入网格视图，展示剧集列表；点击某剧 → 季列表 → 集列表 → 视频流
- **Verification**: `programmatic` — 验证 API 请求参数 `IncludeItemTypes` 根据层级变化

### AC-12: 方向过滤
- **Given**: 用户设置 `orientationMode = 'vertical'`
- **When**: 加载视频列表
- **Then**: 过滤结果仅包含 `Height >= Width * 0.8` 的项目
- **Verification**: `programmatic` — 验证 `applyOrientationFilter` 返回结果

### AC-13: 观看进度同步
- **Given**: 用户之前看过某视频（有 `UserData.PlaybackPositionTicks`）
- **When**: 再次进入该视频
- **Then**: 视频从上次暂停处继续播放；播放过程中进度被写回 Emby
- **Verification**: `programmatic` — 验证 `PlaybackPositionTicks` 到秒的换算

### AC-14: 顶部工具栏可见/可交互
- **Given**: 标准模式 + 非自动连播
- **When**: 用户浏览视频流
- **Then**: 顶部工具栏包含：返回/菜单按钮、中央模式切换标签、右侧（全屏/静音/视图切换）三个按钮
- **Verification**: `human-judgment` — 界面视觉检查

### AC-15: TV 模式遥控器操作
- **Given**: APP 在 TV 模式启动
- **When**: 用户按 ↑/↓/←/→ / Enter / 空格
- **Then**: 对应切换视频 / ±10 秒播放进度 / 播放暂停
- **Verification**: `programmatic` — 模拟 `RawKeyDownEvent` 验证行为

### AC-16: 照片库全屏浏览
- **Given**: 用户选择了 `photos` 类型媒体库
- **When**: 视频流视图加载项目
- **Then**: 图片项全屏居中显示，不初始化视频播放器，支持收藏/信息按钮
- **Verification**: `programmatic` — 验证 `isPhoto` 判断逻辑，VideoPlayerController 不被创建

### AC-17: 用户偏好持久化
- **Given**: 用户设置了 `isMuted = true / orientationMode = 'horizontal' / feedType = 'random'`
- **When**: APP 冷启动
- **Then**: 所有设置值与上次退出前一致
- **Verification**: `programmatic` — 验证 `SharedPreferences` 读写一致性

### AC-18: 视频方向自动适配（横屏视频在竖屏设备）
- **Given**: 用户在竖屏手机上播放横屏视频
- **When**: 渲染视频卡片
- **Then**: 视频以 `BoxFit.contain` 显示，背后叠加模糊版本的封面海报作为背景填充
- **Verification**: `human-judgment` — 在 iPhone 11 / Pixel 4 竖屏 1080p 横屏视频上检查

## Open Questions

- [ ] 是否需要在 Flutter APP 中单独实现 Emby 收藏 API（非 Playlist 方案）以支持跨客户端同步收藏？
- [ ] TV 模式是否需要支持「最近观看/继续观看」首页视图（参考项目的 TVRoot 有）？
- [ ] 搜索功能是否需要对接 `/Users/{userId}/Items?SearchTerm=xxx` 而非当前简化实现？
- [ ] 删除功能是否需要（参考项目有 Trash2 按钮，但操作有破坏性，是否默认隐藏）？
- [ ] 是否需要 Android TV 原生支持（当前仅 Flutter 框架，Android TV 原生单独构建）？
