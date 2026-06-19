# EmbyTok Flutter - 与 EmbyX 功能差距补齐

## 概述
当前 EmbyTok Flutter 版本（1.13.0）的核心框架已经搭好（视频流 UI、Emby API 对接、收藏/播放上报等），但在实际使用体验上与 EmbyX（iOS 原生版本）存在明显差距。本规格文档定义需要补齐的功能点：让 EmbyTok Flutter 达到可日常使用的"完整度"，并在关键体验上对齐 EmbyX。

## 目标用户
- **重度 Emby 用户**：每日使用 Emby 观看竖屏视频或剧集的用户
- **跨平台用户**：同时使用 iOS 和 Android，希望两个 App 有一致的体验
- **大屏幕用户**：电视/盒子上使用（TV Mode）

## 目标
1. **Feed Type 全功能**：latest / random / favorites / resume 四种浏览模式完全可用，切换后列表立即刷新
2. **无缝切换体验**：PageView 上下滑动秒开，不出现黑屏、转圈、加载指示器
3. **播放体验完整**：倍速、自动下一集、子标题、手势快进快退、暂停恢复位置均正常工作
4. **TV Mode 可用**：遥控器方向键能正常导航，焦点清晰可辨
5. **Continue Watching**：与 EmbyX 共享续播书签，能看到未看完的视频并从上次位置继续
6. **详情页**：点击影片可查看简介、演员、评分、集数列表等
7. **性能**：滚动流畅、图片秒开、首屏进入不卡顿
8. **稳定性**：所有错误有降级路径，不崩溃、不卡死

## 非目标
- 不做完整的 Emby 管理后台（用户管理、媒体库管理等）
- 不做离线下载
- 不做直播/iptv
- 不做音乐播放器
- 不写 iOS 原生代码（纯 Flutter 解决）

## 背景与上下文
当前代码基础（截至 commit 033adfd）：
- **UI 框架**：Flutter + Riverpod
- **播放**：`video_player` + 三级降级链（DirectPlay → DirectStream → HLS）
- **网络**：Dio + `EmbytokService` 封装
- **页面**：feed_view / favorites_view / history_view / search_view / settings_view
- **Providers**：video_list / favorites / playback / auth / library / preload / theme 等

已实现但未联通的"半完成功能"（即 Gap）：
- `feedTypeProvider` 只改状态不驱动列表刷新
- `isAutoPlayProvider` 只写状态不真正自动切换下一集
- `preloadController` / `videoReadyProvider` 理论存在但没接入 PageView
- `subtitle_widget.dart` / `subtitle_selector.dart` 存在但 `VideoPageItem` 没渲染
- `getResumeItems` / `getNextUp` 在服务层存在但无 UI
- `item_detail_provider.dart` 存在但没有对应的 `item_detail_view.dart`

## 功能需求（Functional Requirements）

### FR-1: 四种浏览模式的实际可用（Latest / Random / Favorites / Resume）
`video_list_provider.dart` 的 `refresh()` / `loadMore()` 必须读取 `feedTypeProvider` 并选择对应的加载逻辑：
- **latest**：沿用 `getLibraryItems`（当前逻辑），分页 offset/limit
- **random**：一次拉取 80 条（`kRandomListSize`），打乱 shuffle，不分页
- **favorites**：从 `getFavoriteMovies` 拉取纯列表，显示类型 tag，按 DateCreated 降序
- **resume**：从 `getResumeItems()` 拉取"继续观看"列表，每个条目显示已播放进度条，点击从上次位置继续播放
- `FeedType` 枚举新增 `resume` 值，`fromString`/`toStorageString`/`zhLabel` 同步支持
- `constants.dart` 新增 `kFeedTypeResume = 'resume'`
- 切换 feedType 后 `videoListProvider` 自动刷新；快捷键 R 循环顺序：latest → random → favorites → resume → latest

### FR-2: 视频预加载（PageView 相邻项预加载）
- 当前页面初始化时，预加载下一个视频（+1）的控制器
- 前一个视频（-1）可保留已初始化的控制器（避免滑回去再加载）
- 预加载使用 `VideoPlayerController.networkUrl()` + `initialize()`，完成后将控制器缓存
- `VideoPageItem` 接收 `preloadedController` 并优先使用，若存在则跳过动态构造
- 超出 2 个位置外的已加载控制器主动 `dispose()` 避免 OOM

### FR-3: 自动连播下一集
- `isAutoPlayProvider` 为 true 时，视频播放完成（position ≥ duration - 1s）后自动跳转到下一页
- 跳转前：先调用 reportPlaybackStopped 上报当前条目结束位置
- 跳转后：PageView 的 `nextPage(duration: 300ms, curve: Curves.easeOut)`
- 最后一集时不自动跳转，显示"播放完毕"提示
- 提供用户可感知的视觉反馈（切换前最后 1 秒显示"即将播放下一集"提示条）

### FR-4: 子标题渲染集成
- `VideoPageItem` 中渲染 `SubtitleWidget`，使用 `selectedSubtitleProvider` 控制显示哪条轨道
- 子标题数据来源：`MediaItem.mediaSources[].MediaStreams[]` 或 Emby API `/Videos/{itemId}/Subtitles/{index}.vtt`
- 提供子标题选择器：右操作栏或控制条上增加字幕按钮
- 支持显示/关闭字幕
- 字体大小自适应：竖屏 16sp，横屏 22sp

### FR-5: 图片缓存优化
- 所有 `Image.network` 替换为 `CachedNetworkImage`
- 海报/缩略图使用 placeholder + fade-in（300ms）
- 错误时降级为渐变背景 + 图标
- 竖屏视频的缩略图走与横屏不同的 cache key 策略（避免尺寸不符）

### FR-6: 继续观看（Continue Watching / Resume）
- 首页/feed 页面顶部或新增 tab 展示"继续观看"
- 数据源：`EmbytokService.getResumeItems()`（服务层已存在）
- 每个 item 显示缩略图、标题、已播放进度条（百分比）
- 点击从上次播放位置（`userData.playbackPositionTicks` 或 `item.runTimeTicks` 判断）开始播放
- 位置通过 `/Items/{itemId}/Playing/Stopped` 上报，与 EmbyX 同源

### FR-7: NextUp（接下来看什么）
- 剧集类型视频播放结束时，若 `isAutoPlay` 开启，优先跳转到下一集（NextUp）而不是 feed 中的下一条
- `EmbytokService.getNextUp()` 已存在，需要 UI 在播放集数结束时查询
- 提供"播放下一集 X"提示条（5 秒倒计时），可跳过

### FR-8: 条目详情页（Item Detail View）
- 新增 `item_detail_view.dart`
- 包含：横屏海报大图、标题、年份、评分、简介、类型标签、演员头像网格（横滑）、集数列表（Series）、"播放"按钮、"收藏"按钮
- 点击演员 → 跳转到 `person_detail_view.dart`（已有）
- 点击集数 → 立即播放对应集数（使用 `mediaSources` 或动态构造 URL）
- 点击收藏 → 调用 `favoritesProvider.toggleFavorite()` 乐观更新

### FR-9: 增强键盘/遥控器快捷键
- **A / ArrowLeft**：快退 15 秒（真正执行 seek，而不是当前的占位空转）
- **D / ArrowRight**：快进 15 秒
- **W / ArrowUp**：上一条视频（已有部分逻辑，但实际要检查是否在 feed view 生效）
- **S / ArrowDown**：下一条视频（同上）
- **Space**：播放/暂停（已有，但要检查是否所有播放页都响应）
- **U**：收藏/取消收藏（已有）
- **R**：切换浏览模式（最新/随机/收藏，已有）
- **E**：切换视图/网格（已有）
- **G**：媒体库选择器（已有）
- **F**：全屏（已有）
- **M**：静音（已有）
- **? / /**：显示快捷键帮助（已有）

### FR-10: TV Mode 遥控器导航优化
- `tv_root_view.dart` 中所有可交互元素（按钮、卡片、Chips）设置 `focusNode` + `Focus`
- 选中焦点高亮（粉色外边框 + 缩放 1.05）
- 视频流 PageView 支持遥控器 D-pad 上下切换条目
- `libraryChips`（顶部媒体库切换）支持 D-pad 左右切换焦点，Center/OK 选中
- 焦点滚动跟随：当焦点元素超出可视区域时，自动滚动到可见位置

### FR-11: 错误状态/空状态优化
- 网络超时：显示"网络不稳定，点击重试"卡片 + 刷新按钮
- API 返回空列表：显示暂无内容图示 + 文字说明（如"这个媒体库还没有视频"）
- 未登录：所有页面展示统一的"请先登录"引导（而非空白页）
- 服务器连接失败：提供"重新配置服务器地址"入口（指向设置页）

### FR-12: 性能优化（滚动与加载）
- `ListView` / `PageView` 使用 `const` 构造子项，减少重建
- 大图片缩略图优先加载后再解码（`ResizeImage` / `cacheWidth`）
- 首屏：优先显示缓存，网络数据到达时动画更新
- 列表项 key：使用 `item.id` 保证 stable key，避免切换时整列表重建

## 非功能需求（Non-Functional Requirements）

### NFR-1: 性能 - 滑动流畅度
- 在 3 年以内的中端 Android 手机（如骁龙 7xx 级别）上，feed 页滑动帧率稳定 55+ FPS
- 视频流上下滑动切换时不出现明显卡顿（下一帧需在 300ms 内显示画面）

### NFR-2: 稳定性
- 启动崩溃率 < 0.1%
- 连续播放 1 小时无闪退
- 网络抖动/丢包后自动降级到 HLS/低码率，不卡死

### NFR-3: 可访问性
- 所有按钮有 semantic label（语义描述）
- 对比度 ≥ WCAG AA（4.5:1）
- 支持 TV 遥控器/键盘操作（FR-9/10 已覆盖）

### NFR-4: 代码质量
- 所有公共 API/Provider 有 dart doc 注释
- 新增代码走 review checklist（见项目根目录的 CODE_REVIEW_CHECKLIST.md）
- 保持函数单一职责，不超过 80 行

### NFR-5: 向后兼容
- 不破坏现有登录流程和服务器地址配置
- 不改变现有 Provider 的语义（可扩展，但不可突变）
- `pubspec.yaml` 依赖只加不减（如需移除单独评估）

## 约束
- **技术栈**：必须使用 Flutter 3.24.0 / Dart 3.x，不可引入原生 Android/iOS 插件（除已在 `pubspec.yaml` 中存在的依赖外）
- **运行环境**：Android 7.0+、Web（Chrome/Safari）、TV（Android TV）
- **依赖不可突破**：仅使用现有 `video_player`、`cached_network_image`、`flutter_riverpod`、`dio`、`shared_preferences`、`go_router`、`connectivity_plus`、`intl` 等
- **发布流程**：所有变更必须通过 CI（`flutter analyze` + `flutter test`）后才能合入 main
- **权限**：不新增非必要 Android 权限（如 READ_PHONE_STATE、ACCESS_FINE_LOCATION 等）

## 假设
1. Emby 服务器 API 与文档一致：`/Users/{userId}/Items`、`/Videos/{itemId}/Subtitles`、`/Items/{itemId}/PlaybackInfo` 都可访问
2. 用户都使用标准 Emby/Jellyfin 服务器，不会遇到自定义插件的特殊 API
3. 视频格式以 H.264/MP4/WebM/HLS 为主，AV1 等新兴格式依赖系统解码能力，不额外做软件解码
4. 子标题以 WebVTT 为主，支持 SRT 通过服务器转码

## 验收标准（Acceptance Criteria）

### AC-1: 四种浏览模式切换正确
- **Given** 用户已登录并进入 feed 页
- **When** 用户点击 "R" 快捷键或通过其他方式切换 feedType（latest → random → favorites → resume → latest）
- **Then**
  1. 视频列表立即刷新显示对应模式的内容
  2. latest 模式下按 DateCreated 降序、分页加载
  3. random 模式下显示 80 条随机视频，每次刷新顺序不同
  4. favorites 模式下显示用户已收藏的所有影片/合集/人物（若为空则显示空状态提示）
  5. resume 模式下显示"继续观看"列表，每个条目有播放进度条，点击从上次位置继续
- **Verification**: programmatic（`flutter analyze`）+ human judgment（手动切换验证）
- **Notes**: 切换后 2 秒内应有结果展示；不出现"点击无反应"的情况

### AC-2: 相邻视频预加载秒开体验
- **Given** 用户在 feed 页第 2 条（索引 1）正在观看视频
- **When** 用户向下滑动到第 3 条
- **Then**
  1. 第 3 条视频在 300ms 内显示画面（不出现 2 秒以上的黑屏或加载动画）
  2. 预加载的控制器正确地通过 `onControllerReady` 传递
  3. 继续向下/向上滑动，相邻条目都能秒开
  4. 超出 ±2 位置外的条目正确释放控制器，内存不持续增长
- **Verification**: programmatic（内存 dump 检查）+ human judgment

### AC-3: 自动连播下一集
- **Given** `isAutoPlayProvider` 为 true，当前播放倒数第 2 条视频
- **When** 当前视频播放到末尾（position + 1s ≥ duration）
- **Then**
  1. 自动调用 `reportPlaybackStopped` 上报结束位置
  2. PageView 自动跳转到下一页（动画 300ms）
  3. 新页面的视频自动开始播放
  4. 最后一条时显示"全部播放完毕"并停止
- **Verification**: programmatic（日志校验 + API 调用记录）

### AC-4: 子标题正确渲染与切换
- **Given** 视频存在 WebVTT 子标题轨道
- **When** 用户在控制条上点击字幕按钮并选择某语言
- **Then**
  1. 字幕内容在视频下方以半透明黑底白字样式显示
  2. 切换到"关闭"字幕时无任何字幕
  3. 字体大小随横竖屏自动适配
- **Verification**: human judgment（多语言字幕文件实测）

### AC-5: 图片缓存降低重复加载
- **Given** 用户在 feed 页滑动一段距离后回滑
- **When** 回滑到之前已显示过的条目
- **Then** 缩略图/海报立即从缓存展示，不出现网络加载 spinner（除首次加载外）
- **Verification**: programmatic（网络请求计数对比）+ human judgment

### AC-6: Continue Watching 续播体验
- **Given** 用户此前看过某视频但未看完（服务端存在播放位置记录）
- **When** 用户进入 feed 页
- **Then**
  1. 顶部出现"继续观看"区域（或作为 feedType 的一个选项）
  2. 每个条目的缩略图上叠加一条细进度条
  3. 点击后从上次位置继续播放
  4. 播完后自动从"继续观看"列表中移除
- **Verification**: programmatic（服务端 mock + 状态验证）

### AC-7: NextUp 剧集自动播放
- **Given** 用户正在观看某剧集 S1E5，且服务端存在 S1E6
- **When** 当前视频播放结束时
- **Then**
  1. 优先跳转到 S1E6 而不是 feed 中的下一条随机视频
  2. 跳转前显示 5 秒倒计时提示条
  3. 用户点击"跳过"则立即开始播放下一集
  4. 没有下一集时回退到 FR-3 的自动连播逻辑
- **Verification**: programmatic（NextUp API mock）+ human judgment

### AC-8: 条目详情页信息完整
- **Given** 用户在 feed 页点击某条（或在网格页点击海报）
- **When** 跳转到详情页
- **Then** 能看到：标题、年份、类型标签、社区评分、简介、演员头像横滑列表、集数列表（Series）、播放按钮、收藏按钮
- **Verification**: human judgment（视觉检查）

### AC-9: 键盘/遥控器 A/D 真正快进快退
- **Given** 视频正在播放
- **When** 用户按下 A 或 ArrowLeft
- **Then** position 向回调整 15 秒（实际 seek，而非仅 UI 指示）
- 同样 D/ArrowRight 对应向前 15 秒
- **Verification**: programmatic（播放进度检查）

### AC-10: TV Mode 焦点导航
- **Given** 在 Android TV 上运行（或模拟器）
- **When** 用户使用遥控器方向键
- **Then** 焦点能在所有可交互元素（按钮/卡片/chip/列表项）之间清晰移动，选中元素有明显的粉色高亮 + 缩放
- **Verification**: human judgment（TV 实测）

### AC-11: 错误与空状态友好
- **Given** 发生网络超时 / 空列表 / 未登录等情况
- **When** 用户访问对应页面
- **Then** 看到带图标 + 说明文字 + 可点击重试/跳转按钮的友好提示，而不是空白页或英文错误栈
- **Verification**: human judgment + programmatic（异常路径测试）

### AC-12: flutter analyze 与现有测试通过
- **Given** 代码提交前
- **When** 执行 `flutter analyze --no-pub lib` 和 `flutter test`
- **Then** 0 errors、0 warnings（或仅既有 warnings，不新增）
- **Verification**: programmatic（CI 自动执行）

## 开放性问题
1. **Continue Watching 的 UI 位置**：是作为单独的 feedType（latest / random / favorites / resume），还是 feed 页顶部固定的水平滚动列表？
2. **NextUp 的"下一集"跳转策略**：当用户在 random 模式时，遇到剧集应该优先跳 NextUp 还是继续随机？需要确认行为。
3. **子标题语言选择**：是否需要在设置页记住用户偏好的字幕语言，下次自动开启？还是默认为关闭？
4. **离线使用**：用户偶尔在无网络情况下打开 APP，当前设计是否需要做"上次已加载的列表缓存"？
5. **TV Mode 与 Phone Mode 的导航差异**：TV Mode 用 D-pad 滚动时是否禁用滑动手势？还是两者并存？
