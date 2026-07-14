# EmbyTok - 架构总览

> 本文件目标：为技术读者提供项目的整体架构视图、核心模块职责、数据模型说明以及鉴权流程。
>
> 对开发者友好提示：如果你是第一次阅读代码，建议按本文的章节顺序浏览。

---

## 一、三层架构总览

### 1.1 整体结构

```
┌──────────────────────────────────────────────────────────────────┐
│                                                                  │
│  Flutter / Dart 客户端                                          │
│  • lib/views/         — 页面 UI（登录、视频流、搜索等）       │
│  • lib/widgets/       — 可复用组件（视频播放器、字幕、手势）  │
│  • lib/providers/     — Riverpod 状态管理（认证、播放、收藏） │
│  • lib/services/      — API 服务封装（Dio HTTP 客户端）        │
│  • lib/models/        — 数据模型（不可变对象）                 │
│  • lib/utils/         — 工具函数                               │
│                                                                  │
│           HTTPS / HTTP   (Dio HTTP 客户端)                     │
│                      ↓                                           │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  FastAPI 后端中间层                                            │
│  • routers/            — API 路由（auth/libraries/items/...） │
│  • clients/            — Emby HTTP 客户端封装                  │
│  • models/             — Pydantic 数据模型                      │
│  • core/               — 配置、错误处理、响应工具              │
│  • main.py            — 应用入口，注册路由与中间件            │
│                                                                  │
│           HTTPS / HTTP   (httpx async HTTP 客户端)              │
│                      ↓                                           │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Emby 媒体服务器                                                │
│  • /Users/AuthenticateByName  — 登录认证                        │
│  • /Library/VirtualFolders  — 媒体库列表                       │
│  • /Items                — 媒体项查询与搜索                    │
│  • /Items/{id}/Download  — 视频文件直链                       │
│  • /Items/{id}/UserData  — 播放进度、收藏标记                 │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

### 1.2 各层职责

| 层级 | 职责 | 不做的事 |
|------|------|---------|
| **Flutter 客户端** | UI 渲染、用户交互、视频播放、状态管理、本地持久化 | 不直接请求 Emby 的底层 API |
| **FastAPI 中间层** | 鉴权转发、API 统一封装、错误标准化、响应转换 | 不持久化任何用户数据（完全无状态） |
| **Emby 媒体服务器** | 媒体库管理、用户认证、视频流输出 | 不提供前端 UI（除自身 Web 界面外） |

---

## 二、Flutter 端结构

### 2.1 目录结构

```
frontend/lib/
├── main.dart                  # 应用入口（ProviderScope 包装）
├── app.dart                   # 根组件（GoRouter 路由、主题、TV/标准模式切换）
│
├── models/                    # 数据模型（不可变，fromJson / toJson）
│   ├── user.dart              #   用户模型（id / name / accessToken）
│   ├── library.dart           #   媒体库模型（id / name / type / itemCount）
│   ├── media_item.dart        #   媒体项模型（id / title / type / duration / 封面）
│   ├── media_source.dart      #   媒体源模型（清晰度 / 码率 / 播放地址）
│   ├── person.dart            #   人物模型（演员 / 导演 / 编剧）
│   ├── paginated_response.dart#   分页响应泛型模型
│   ├── subtitle_track.dart    #   字幕轨道
│   ├── watch_history_item.dart#   观看历史项
│   ├── user_data.dart         #   用户数据（播放进度 / 收藏 / 已观看）
│   ├── search_hint.dart       #   搜索提示
│   ├── app_config.dart        #   应用配置
│   └── models.dart            #   统一导出
│
├── providers/                 # Riverpod 状态管理（业务逻辑核心）
│   ├── auth_provider.dart     #   登录态 / Token / 用户信息
│   ├── library_provider.dart  #   媒体库列表与选择
│   ├── video_list_provider.dart#   视频列表（分页 / 排除已观看 / 过滤）
│   ├── video_playback_controller.dart# 视频播放控制
│   ├── item_detail_provider.dart  #   媒体详情（详情 / 相似推荐 / 演员列表）
│   ├── actors_provider.dart   #   演员 / 导演 / 编剧列表与详情
│   ├── recommend_provider.dart#   推荐系统
│   ├── recommend_signals.dart #   推荐信号计算
│   ├── search_provider.dart   #   搜索状态
│   ├── search_hints_provider.dart #   搜索提示
│   ├── search_history_provider.dart# 搜索历史
│   ├── favorites_provider.dart#   收藏管理
│   ├── favorites_service_provider.dart# 收藏服务抽象
│   ├── watch_history_provider.dart# 观看历史
│   ├── watch_stats_provider.dart  #   观看统计
│   ├── theme_provider.dart    #   主题切换
│   ├── app_preferences_providers.dart# 应用偏好设置
│   ├── user_preferences_provider.dart# 用户偏好设置
│   ├── subtitle_settings_provider.dart# 字幕设置
│   ├── toolbar_visibility_provider.dart# 工具栏可见性
│   ├── page_navigation_provider.dart# 页面导航状态
│   └── providers.dart         #   统一导出
│
├── services/                  # API 服务层
│   ├── api_client.dart        #   Dio 封装（Header 注入、错误处理）
│   ├── embbytok_service.dart  #   业务 API（login / getLibraries / search / ...）
│   ├── video_pool_service.dart#   视频池预加载服务
│   └── services.dart          #   统一导出
│
├── views/                     # 页面
│   ├── login_view.dart        #   登录页
│   ├── feed_view.dart         #   视频流首页（TikTok 式滑动）
│   ├── video_grid_view.dart   #   媒体库网格视图
│   ├── fullscreen_video_page.dart #   全屏播放页
│   ├── item_detail_view.dart  #   媒体详情页
│   ├── boxset_detail_view.dart#   合集详情页
│   ├── actors_view.dart       #   演员 / 导演 / 编剧列表
│   ├── person_detail_view.dart#   人物详情页
│   ├── recommend_view.dart    #   推荐页
│   ├── search_view.dart       #   搜索页
│   ├── favorites_view.dart    #   收藏页
│   ├── history_view.dart      #   观看历史页
│   ├── settings_view.dart     #   设置页
│   ├── home_scaffold.dart     #   首页脚手架（底部导航容器）
│   ├── standard_root_view.dart#   标准模式根视图
│   ├── tv_root_view.dart      #   TV 模式根视图
│   └── views.dart             #   统一导出
│
├── widgets/                   # 可复用 UI 组件
│   ├── video/                 #   视频相关组件子目录
│   │   ├── video_action_button.dart    #   视频操作按钮
│   │   ├── video_control_buttons.dart  #   视频控制按钮组
│   │   ├── video_draggable_clean_actions.dart # 可拖拽纯净模式按钮
│   │   ├── video_progress_bars.dart    #   视频进度条
│   │   └── video_sheet_utils.dart      #   视频底部面板工具
│   ├── video_player_widget.dart#   视频播放器封装（video_player）
│   ├── video_page_item.dart   #   单个视频页（在 PageView 中）
│   ├── video_controls.dart    #   播放控制条（暂停/进度/倍速）
│   ├── gesture_overlay.dart   #   手势识别层（单击/双击/长按/拖拽）
│   ├── heart_animation.dart   #   爱心动画效果
│   ├── subtitle_renderer.dart #   字幕渲染
│   ├── subtitle_controls.dart #   字幕语言切换
│   ├── subtitle_selector.dart #   字幕选择器
│   ├── subtitle_widget.dart   #   字幕 Widget
│   ├── poster_grid_view.dart  #   海报网格视图
│   ├── video_grid_card.dart   #   视频网格卡片
│   ├── library_selector.dart  #   媒体库选择器
│   ├── top_tool_bar.dart      #   顶部工具栏
│   ├── tv_focusable.dart      #   TV 焦点组件
│   ├── empty_state_card.dart  #   空状态卡片
│   ├── error_state_card.dart  #   错误状态卡片
│   └── widgets.dart           #   统一导出
│
├── theme/                     # 主题配置
│   ├── app_theme.dart         #   应用主题（浅色 / 深色）
│   └── theme_extensions.dart  #   主题扩展
│
└── utils/                     # 工具函数
    ├── constants.dart         #   常量配置
    ├── formatters.dart        #   数字/时间格式化
    ├── colors.dart            #   颜色工具
    ├── app_preferences.dart   #   应用偏好存储
    ├── image_cache_manager.dart#  图片缓存管理
    ├── keyboard_shortcuts.dart#   键盘快捷键
    ├── logger.dart            #   日志工具
    ├── version.dart           #   版本信息
    └── utils.dart             #   通用工具
```

### 2.2 数据流示意

```
用户点击"登录"按钮
  ↓
login_view.dart → auth_provider.login()
  ↓
embbytok_service.login(embyUrl, backendUrl, username, password)
  ↓
api_client.post('/api/auth/login', data: {...})
  ↓
Dio 请求后端 FastAPI → http://192.168.1.6:8000/api/auth/login
  ↓
FastAPI routers/auth.py → EmbyClient.authenticate()
  ↓
httpx 请求 → http://192.168.1.6:8010/Users/AuthenticateByName
  ↓
Emby 返回 AccessToken + User 信息
  ↓
FastAPI 封装为统一 AuthResponse 返回
  ↓
api_client 收到响应 → User.fromJson() 解析
  ↓
auth_provider 更新状态（isLoading → false, user → 新值）
  ↓
login_view 监听状态变化 → context.go('/feed') 跳转到视频流
```

### 2.3 核心 Provider 说明

| Provider | 职责 | 对外暴露 |
|----------|------|---------|
| `auth_provider` | 管理登录态、Token、用户信息 | `state.isLoading`, `state.error`, `state.user`, `login()`, `logout()` |
| `library_provider` | 加载并缓存媒体库列表、当前选中库 | `libraries`, `selectedLibraryId`, `loadLibraries()`, `selectLibrary()` |
| `video_list_provider` | 分页加载视频列表（预加载下一页 / 排除已观看） | `items`, `hasMore`, `loadMore()`, `refresh()`, `toggleExcludeWatched()` |
| `video_playback_controller` | 视频播放控制与状态 | `controller`, `play()`, `pause()`, `seekTo()`, `setSpeed()` |
| `item_detail_provider` | 媒体详情加载与管理 | `item`, `similarItems`, `castList`, `loadDetail()` |
| `actors_provider` | 演员 / 导演 / 编剧列表与详情 | `actors`, `actorDetail`, `actorWorks`, `loadActors()`, `toggleFollow()` |
| `recommend_provider` | 推荐系统 | `recommendations`, `loadRecommendations()`, `refresh()` |
| `recommend_signals` | 推荐信号计算 | `watchStats`, `favoriteSignals`, `genreWeights` |
| `search_provider` | 搜索状态与结果管理 | `results`, `search(keyword)`, `loadMore()` |
| `search_hints_provider` | 搜索提示建议 | `hints`, `loadHints(keyword)` |
| `favorites_provider` | 收藏管理 | `favorites`, `toggleFavorite(itemId)`, `isFavorite(itemId)` |
| `watch_history_provider` | 最近播放记录 | `history`, `addToHistory(item, progress)`, `clearHistory()` |
| `watch_stats_provider` | 观看统计数据 | `totalWatched`, `genreStats`, `watchTimeStats` |
| `theme_provider` | 主题模式切换 | `themeMode`, `setThemeMode(...)` |
| `subtitle_settings_provider` | 字幕设置 | `subtitleEnabled`, `fontSize`, `textColor`, `position` |
| `toolbar_visibility_provider` | 工具栏可见性控制 | `isVisible`, `show()`, `hide()`, `toggle()` |
| `app_preferences_providers` | 应用级偏好设置 | `viewMode`, `excludeWatched`, `autoPlay` |

**架构优点**：
- **单向数据流**：Provider 管理状态 → Widget 监听状态 → 用户操作触发 Provider 方法 → 状态更新
- **状态边界清晰**：auth / library / video_list 互不依赖，通过 API Client 共享底层
- **易于测试**：Provider 可 override，API Client 可 mock
- **分层合理**：UI 层 / 业务逻辑层 / 数据层 分离清晰

---

## 三、FastAPI 后端结构

### 3.1 目录结构

```
backend/
├── main.py                    # FastAPI 应用入口（注册路由 / 中间件 / 异常处理）
│
├── routers/                   # API 路由（每类资源一个文件）
│   ├── auth.py                #   POST /api/auth/login
│   ├── libraries.py           #   GET /api/libraries, /api/libraries/{id}/items
│   ├── items.py               #   GET /api/items/{id}, /playback, progress GET/POST
│   ├── search.py              #   GET /api/search, POST /api/search
│   ├── favorites.py           #   GET/POST/DELETE /api/favorites
│   ├── subtitles.py           #   GET /api/items/{id}/subtitles
│   └── deps.py                #   依赖注入（从 Header/Query 提取 emby_url/token/user_id）
│
├── clients/                   # 第三方客户端封装
│   └── emby_client.py         #   httpx 异步 HTTP 客户端封装（统一 URL/错误处理）
│
├── models/                    # Pydantic 数据模型（请求/响应定义）
│   └── base_models.py         #   AuthRequest / AuthResponse / Library / MediaItem / ...
│
├── core/                      # 核心基础设施
│   ├── config.py              #   配置（无环境变量时使用硬编码默认值）
│   ├── errors.py              #   错误常量与异常类型定义（400/401/502）
│   └── response_utils.py      #   通用响应工具（分页构造、Emby→Library/MediaItem 转换）
│
├── tests/                     # 测试目录
│   ├── test_health.py         #   健康检查端点测试
│   └── conftest.py            #   pytest Fixture
│
├── requirements.txt           # Python 依赖（fastapi / uvicorn / httpx / pydantic）
├── Dockerfile                 # Docker 镜像构建
└── README.md                  # 后端本地启动说明
```

### 3.2 路由设计原则

1. **资源导向**：每个路由文件对应一类资源（`auth`、`libraries`、`items`、`favorites`、`search`、`subtitles`）
2. **RESTful 方法**：GET 查询、POST 创建/提交、DELETE 删除
3. **统一前缀**：所有业务路由均有 `/api/` 前缀（如 `/api/auth/login`），健康检查除外
4. **依赖注入鉴权**：通过 `deps.py` 中的函数从请求头或查询参数提取 `emby_url` / `emby_token` / `user_id`，对上层透明
5. **无状态**：后端本身不保存用户会话，所有状态都由 Emby 服务管理

---

## 四、鉴权流程详解

### 4.1 登录流程（首次）

```
用户在登录表单填写四个字段：
  ┌ backendUrl   = http://192.168.1.6:8000  ← 后端代理地址
  │ embyUrl      = http://192.168.1.6:8010  ← Emby 服务器地址
  │ username     = FK
  └ password     = ********

                    Flutter 端
                    ┌─────────────────────────────────────┐
                    │  login_view.dart                      │
                    │  └→ auth_provider.login()           │
                    │      └→ embbytok_service.login()    │
                    │          └→ api_client.post(...)    │
                    │              请求体:                │
                    │              {                        │
                    │                "emby_url": "...",     │
                    │                "username": "FK",      │
                    │                "password": "***"      │
                    │              }                        │
                    └──────────────┬──────────────────────┘
                                   │ POST /api/auth/login
                                   │ (HTTP)
                                   ↓
                    FastAPI 端
                    ┌─────────────────────────────────────┐
                    │ routers/auth.py                       │
                    │  └→ EmbyClient.authenticate()       │
                    │      POST /Users/AuthenticateByName │
                    │      到 Emby 服务器                  │
                    │      └→ 返回: AccessToken, User      │
                    └──────────────┬──────────────────────┘
                                   │ HTTP Response
                                   │ {access_token, user_id,
                                   │  username, server_id}
                                   ↓
                    Flutter 端
                    ┌─────────────────────────────────────┐
                    │ api_client 保存 access_token         │
                    │  后续请求自动注入 Header:            │
                    │  X-Emby-Server-Url: xxx              │
                    │  X-Emby-Token: abcdef123...          │
                    │  X-Emby-User-Id: user123             │
                    └──────────────────────────────────────┘
```

### 4.2 后续请求的 Token 注入

登录成功后，Flutter 端的 `api_client` 自动记住 `access_token`。每次发起 API 请求时，拦截器自动注入三个 HTTP Header：

```
X-Emby-Server-Url: http://192.168.1.6:8010
X-Emby-Token: abcdef1234567890abcdef
X-Emby-User-Id: user-uuid-here
```

后端 FastAPI 的 `deps.py` 从 Header 中提取这些值，传递给 `EmbyClient`，再去请求 Emby 服务器。

### 4.3 安全性说明

| 层面 | 做法 |
|------|------|
| **内网部署** | 推荐仅在局域网内暴露后端服务（192.168.x.x），对外通过 Tailscale / frp 等工具 |
| **密码传输** | 登录请求中密码为明文。局域网内使用 HTTP 可接受；公网使用必须走 HTTPS |
| **Token 存储** | Flutter 端存储在内存中（不持久化密码），Token 随应用重启失效 |
| **后端无状态** | FastAPI 本身不保存任何用户数据，所有状态依赖 Emby 服务 |

---

## 五、数据模型总览

### 5.1 模型关系图

```
                ┌──────────────┐
                │   AppConfig  │  本地配置：backendUrl / embyUrl / 主题 / 字幕开关
                └──────┬───────┘
                       │ 引用
                       ↓
                ┌──────────────┐
                │     User     │  id / name / accessToken（登录后获得）
                └──────┬───────┘
                       │ 属于
                       ↓
                ┌──────────────┐
                │   Library    │  id / name / type / itemCount / coverImageUrl
                └──────┬───────┘
                       │ 包含
                       ↓
                ┌──────────────┐
                │  MediaItem   │  id / title / type / duration / 封面 / 简介 / 类型标签
                └──┬──────┬───┘
                   │      │  关联
                   ↓      ↓
            ┌────────┐ ┌─────────────┐     ┌─────────────┐
            │ Subtitle│ │WatchHistory │     │  UserData   │  播放进度 / 收藏 / 已观看
            │  Track  │ │    Item    │     └─────────────┘
            └────────┘ └─────────────┘
                   │
                   ↓
            ┌─────────────┐
            │ MediaSource │  清晰度 / 码率 / 播放地址
            └─────────────┘

                ┌─────────────────────────────┐
                │ PaginatedResponse<MediaItem>│  items[] / total / offset / limit
                └─────────────────────────────┘

                ┌──────────────┐
                │    Person    │  演员 / 导演 / 编剧（id / name / 头像 / 简介）
                └──────┬───────┘
                       │ 出演 / 执导
                       ↓
                ┌──────────────┐
                │  MediaItem   │  人物关联的作品列表
                └──────────────┘

                ┌──────────────┐
                │  SearchHint  │  搜索提示（id / text / type）
                └──────────────┘
```

### 5.2 各模型关键字段速查

**User**（[frontend/lib/models/user.dart](../frontend/lib/models/user.dart)）

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | String | Emby 用户 ID |
| `name` | String | 用户名 |
| `accessToken` | String | Emby 访问令牌 |

**Library**（[frontend/lib/models/library.dart](../frontend/lib/models/library.dart)）

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | String | 媒体库唯一 ID |
| `name` | String | 显示名称（如"电影"、"电视剧"） |
| `type` | String | 库类型（Movies / Series / Music） |
| `itemCount` | int? | 媒体项数量 |
| `coverImageUrl` | String? | 封面图 URL |

**MediaItem**（[frontend/lib/models/media_item.dart](../frontend/lib/models/media_item.dart)）

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | String | 媒体项唯一 ID |
| `title` | String | 标题 |
| `type` | String | 类型（Movie / Episode / Video） |
| `durationSeconds` | double? | 时长（秒） |
| `thumbnailUrl` | String? | 缩略图 URL |
| `overview` | String? | 剧情简介 |
| `year` | int? | 年份 |
| `rating` | double? | 评分（0-10） |
| `genres` | List\<String\>? | 类型标签（如"剧情"、"犯罪"） |
| `playbackUrl` | String? | 播放 URL（直链下载） |

**MediaSource**（[frontend/lib/models/media_source.dart](../frontend/lib/models/media_source.dart)）

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | String | 媒体源 ID |
| `name` | String | 显示名称（如"1080p"、"720p"） |
| `bitrate` | int? | 码率（bps） |
| `videoCodec` | String? | 视频编码 |
| `audioCodec` | String? | 音频编码 |
| `width` | int? | 视频宽度 |
| `height` | int? | 视频高度 |
| `url` | String? | 播放地址 |

**Person**（[frontend/lib/models/person.dart](../frontend/lib/models/person.dart)）

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | String | 人物 ID |
| `name` | String | 姓名 |
| `role` | String? | 角色（Actor / Director / Writer） |
| `imageUrl` | String? | 头像 URL |
| `overview` | String? | 人物简介 |
| `birthday` | String? | 出生日期 |
| `birthPlace` | String? | 出生地 |

**SubtitleTrack**（[frontend/lib/models/subtitle_track.dart](../frontend/lib/models/subtitle_track.dart)）

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | String | 字幕轨道 ID |
| `name` | String | 显示名称（如"简体中文"） |
| `language` | String | 语言代码（chi / eng / jpn） |
| `format` | String | 文件格式（srt / vtt / ass） |
| `url` | String? | 字幕文件下载地址 |

**UserData**（[frontend/lib/models/user_data.dart](../frontend/lib/models/user_data.dart)）

| 字段 | 类型 | 说明 |
|------|------|------|
| `itemId` | String | 媒体项 ID |
| `playbackPositionTicks` | int? | 播放进度（ticks） |
| `played` | bool | 是否已观看 |
| `isFavorite` | bool | 是否收藏 |
| `playCount` | int | 播放次数 |
| `lastPlayedDate` | DateTime? | 最后播放时间 |

**WatchHistoryItem**（[frontend/lib/models/watch_history_item.dart](../frontend/lib/models/watch_history_item.dart)）

| 字段 | 类型 | 说明 |
|------|------|------|
| `itemId` | String | 对应的媒体项 ID |
| `itemTitle` | String | 标题（便于列表展示，避免额外查询） |
| `thumbnailUrl` | String? | 缩略图 |
| `watchedAt` | DateTime | 观看时间 |
| `progressSeconds` | int | 当前播放进度（秒） |
| `totalSeconds` | int | 总时长（秒） |

**SearchHint**（[frontend/lib/models/search_hint.dart](../frontend/lib/models/search_hint.dart)）

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | String | 提示项 ID |
| `text` | String | 提示文本 |
| `type` | String | 类型（Movie / Series / Person） |

**AppConfig**（[frontend/lib/models/app_config.dart](../frontend/lib/models/app_config.dart)）

| 字段 | 类型 | 说明 |
|------|------|------|
| `backendUrl` | String | 后端代理地址 |
| `embyServerUrl` | String | Emby 服务器地址 |
| `userId` | String | 用户 ID |
| `userName` | String | 用户名 |
| `themeMode` | String | 主题模式（system / light / dark） |
| `subtitleEnabled` | bool | 是否开启字幕 |

**PaginatedResponse\<T\>**（[frontend/lib/models/paginated_response.dart](../frontend/lib/models/paginated_response.dart)）

| 字段 | 类型 | 说明 |
|------|------|------|
| `items` | List\<T\> | 当前页数据项 |
| `total` | int | 总条数 |
| `offset` | int | 起始偏移 |
| `limit` | int | 每页条数 |

---

## 六、视频播放流程

### 6.1 竖屏播放流程示意

```
用户打开视频流首页
  ↓
feed_view.dart 构建 PageView
  ↓
video_page_item.dart 渲染单个视频
  ↓
video_player_widget.dart 初始化 VideoPlayerController
  ↓
MediaItem.playbackUrl → 后端 /api/items/{id}/playback
  ↓
后端 → EmbyClient.get_playback_url() → 构造 Emby 直链 URL
  ↓
Flutter VideoPlayer 播放远程文件
  ↓
用户操作（单击显隐控制栏 / 双击播放暂停 / 长按倍速 / 水平拖拽进度）
  ↓
gesture_overlay.dart 识别手势 → video_playback_controller.dart 更新状态
  ↓
video_controls.dart 同步更新 UI（进度条、倍速显示）
  ↓
用户切换视频 → 自动暂停当前视频并上报进度（POST /api/items/{id}/progress）
```

### 6.2 全屏播放流程

```
用户点击全屏按钮
  ↓
video_page_item.dart → 跳转 fullscreen_video_page.dart
  ↓
设置 isFullscreenProvider = true（VideoPlayerWidget 用 Offstage 隐藏原播放器）
  ↓
fullscreen_video_page.dart 接管 VideoPlayerController（复用同一 controller 避免黑屏）
  ↓
进入全屏模式：
  - 自动横屏（可选，根据设置）
  - 显示全屏控制栏（上一集 / 下一集 / 清晰度 / 画面比例 / 字幕 / 倍速）
  - 启用亮度 / 音量手势调节
  ↓
用户操作：
  - 左侧上下滑 → 调节系统亮度（screen_brightness）
  - 右侧上下滑 → 调节系统音量
  - 水平拖拽 → 快进快退
  - 双击 → 播放/暂停
  - 单击 → 显隐控制栏
  ↓
用户退出全屏：
  - 同步播放进度
  - 销毁全屏控制层
  - isFullscreenProvider = false（原视频恢复显示）
  - 返回竖屏页面
```

### 6.3 视频预加载与缓存策略

| 机制 | 说明 |
|------|------|
| **PageView 预渲染** | Flutter 的 PageView 默认预渲染下一屏，下一个视频的初始化在用户滑动前完成 |
| **视频池预加载** | VideoPoolService 预创建一定数量的 VideoPlayerController，滑动时可立即播放 |
| **缩略图缓存** | 视频封面图由网络加载，前端使用 cached_network_image 缓存 |
| **进度持久化** | 切换视频时自动调用进度上报 API，下次打开自动恢复到上次观看位置 |
| **全屏复用 Controller** | 全屏播放复用同一个 VideoPlayerController，避免重建 texture 导致黑屏 |

---

## 七、搜索与收藏流程

### 7.1 搜索

```
search_view.dart 输入关键词
  ↓
search_provider.search(keyword)
  ↓
embbytok_service.search(keyword, limit, offset)
  ↓
API 调用 GET /api/search?q=keyword
  ↓
后端 → EmbyClient.search() → GET /Items?SearchTerm=keyword
  ↓
返回 PaginatedResponse<MediaItem>
  ↓
search_provider 更新状态 → search_view 渲染列表
```

### 7.2 收藏

```
用户双击视频（或点击收藏按钮）
  ↓
favorites_provider.toggleFavorite(itemId, isFavorite)
  ↓
embbytok_service.toggleFavorite(itemId, isFavorite)
  ↓
API 调用 POST 或 DELETE /api/favorites/{item_id}
  ↓
后端 → EmbyClient.toggle_favorite()
  ↓
favorites_provider 同步本地状态（避免重新加载整个列表）
```

---

## 八、演员与人物浏览流程

### 8.1 演员列表加载

```
用户进入演员页面
  ↓
actors_view.dart 构建 Tab（演员 / 导演 / 编剧）
  ↓
actors_provider.loadActors(personType)
  ↓
embbytok_service.getPersons(personType, limit, offset)
  ↓
API 调用 GET /api/persons?type=Actor&limit=20&offset=0
  ↓
后端 → EmbyClient.get_persons() → GET /Items?PersonTypes=Actor
  ↓
返回 PaginatedResponse<Person>
  ↓
actors_provider 更新状态 → actors_view 渲染网格列表
```

### 8.2 人物详情与出演作品

```
用户点击演员卡片
  ↓
GoRouter 跳转 /person/:personId
  ↓
person_detail_view.dart 加载详情
  ↓
actors_provider.loadPersonDetail(personId)
  ↓
embbytok_service.getPersonDetail(personId)
  ↓
API 调用 GET /api/persons/{id}
  ↓
返回 Person 详情 + 出演作品列表
  ↓
person_detail_view 渲染：
  - 人物头像 / 简介 / 基本信息
  - 出演作品网格
  - 关注按钮
```

---

## 九、核心文件引用速查

| 功能 | Flutter 端 | 后端路由 | Emby 客户端 |
|------|-----------|---------|-----------|
| 登录 | `providers/auth_provider.dart` | `routers/auth.py` | `clients/emby_client.py` |
| 媒体库列表 | `providers/library_provider.dart` | `routers/libraries.py` | `EmbyClient.get_libraries()` |
| 视频列表 | `providers/video_list_provider.dart` | `routers/libraries.py` | `EmbyClient.get_items()` |
| 播放地址 | `widgets/video_player_widget.dart` | `routers/items.py` | `EmbyClient.get_playback_url()` |
| 全屏播放 | `views/fullscreen_video_page.dart` | - | - |
| 媒体详情 | `providers/item_detail_provider.dart` | `routers/items.py` | `EmbyClient.get_item_detail()` |
| 演员列表 | `providers/actors_provider.dart` | `routers/items.py` | `EmbyClient.get_persons()` |
| 人物详情 | `providers/actors_provider.dart` | `routers/items.py` | `EmbyClient.get_person_detail()` |
| 搜索 | `views/search_view.dart` | `routers/search.py` | `EmbyClient.search()` |
| 搜索提示 | `providers/search_hints_provider.dart` | `routers/search.py` | `EmbyClient.get_search_hints()` |
| 收藏 | `providers/favorites_provider.dart` | `routers/favorites.py` | `EmbyClient.toggle_favorite()`, `get_favorites()` |
| 字幕 | `widgets/subtitle_renderer.dart` | `routers/subtitles.py` | `EmbyClient.get_subtitles()` |
| 播放进度 | `providers/video_playback_controller.dart` | `routers/items.py` | `EmbyClient.save_playback_progress()`, `get_playback_progress()` |
| 用户数据 | `models/user_data.dart` | `routers/items.py` | `EmbyClient.get_user_data()` |
| 推荐系统 | `providers/recommend_provider.dart` | `routers/items.py` | `EmbyClient.get_similar_items()` |
| 观看统计 | `providers/watch_stats_provider.dart` | - | 本地计算 |
| 视频池预加载 | `services/video_pool_service.dart` | - | - |
| 网格视图 | `views/video_grid_view.dart` | - | - |

---

## 十、设计原则与未来扩展

### 10.1 当前设计的核心取舍

| 决策 | 理由 | 代价 |
|------|------|------|
| **后端无状态** | 简化部署、降低复杂度，利于水平扩展 | 不能做复杂的服务端缓存（但可外挂 Redis） |
| **后端只做 API 封装** | 保持薄中间层，业务逻辑都在 Flutter 端，便于移动端开发者理解 | 未来若要支持 Plex，需要在后端抽象统一接口 |
| **使用 Riverpod 而非 BLoC** | Riverpod 学习成本更低，代码更简洁，符合项目规模 | 重度复杂场景可能需要引入 BLoC 模式 |
| **不使用数据库** | 所有状态由 Emby 管理（观看历史、收藏等） | 跨设备同步依赖 Emby 的用户数据功能 |
| **全屏复用 Controller** | 避免重建 texture 导致黑屏，切换更流畅 | 状态共享需要小心处理，避免并发问题 |
| **双视图模式** | 兼顾 TikTok 式刷片和海报墙浏览两种使用场景 | 代码复杂度增加，需要维护两套 UI 交互 |

### 10.2 未来可扩展方向

| 方向 | 说明 |
|------|------|
| **Plex 支持** | 类似 `EmbyClient` 新增 `PlexClient`，后端通过 `?server_type=plex` 参数区分 |
| **服务端缓存** | 引入 Redis，缓存媒体库列表和搜索结果，降低 Emby 压力 |
| **多用户管理** | 前端支持切换用户（不同家庭成员有不同的观看历史和收藏） |
| **硬件加速解码** | Android 端使用 MediaCodec，提升 4K 视频播放性能 |
| **字幕在线翻译** | 结合翻译 API（如 DeepL、百度翻译），把中文字幕实时翻译为其他语言 |
| **剧集播放列表** | 支持电视剧多季多集的连续播放与季切换 |
| **离线缓存下载** | 支持下载视频到本地，无网络时也可观看 |
| **投屏功能** | Chromecast / DLNA 投屏到电视播放 |
| **更多推荐算法** | 基于观看历史、收藏、类型标签的个性化推荐 |

---

*文档版本：v1.2 | 最后更新：2026-07-15 | 对应项目版本：EmbyTok-Flutter v1.126.x*
