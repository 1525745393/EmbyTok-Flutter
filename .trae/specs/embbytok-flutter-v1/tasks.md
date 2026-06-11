# EmbyTok-Flutter v1 - 实施计划（任务分解与优先级）

> 本计划按依赖关系和优先级排序，每个任务包含明确的验收标准与测试需求。
> 状态标记：`[ ]` 待开始 · `[/]` 进行中 · `[x]` 已完成

---

## [x] Task 1: FastAPI 后端项目脚手架与核心依赖
- **Priority**: P0
- **Depends On**: None
- **Description**:
  - 创建 `backend/` 目录，搭建 FastAPI 最小可运行项目
  - 创建 `backend/requirements.txt`，包含 fastapi, uvicorn[standard], httpx, pydantic, python-multipart
  - 创建 `backend/main.py` 作为应用入口，挂载 `/health` 健康检查端点（返回版本号）
  - 创建 CORS 中间件配置，允许 Flutter 客户端跨域访问
  - 提供 `backend/README.md` 简要运行说明
- **Acceptance Criteria Addressed**: AC-11, AC-15, AC-16
- **Test Requirements**:
  - `programmatic` TR-1.1: 执行 `pip install -r requirements.txt && uvicorn main:app --port 8000` 后，`curl http://localhost:8000/health` 返回 HTTP 200 且 JSON 含 `status: "ok"`
  - `programmatic` TR-1.2: Swagger UI (`/docs`) 和 OpenAPI JSON (`/openapi.json`) 可访问
  - `human-judgment` TR-1.3: 目录结构清晰，依赖版本明确
- **Notes**: 先确保后端能跑起来，后续任务再逐步填充业务逻辑

---

## [x] Task 2: FastAPI - 数据模型与 Emby 客户端抽象
- **Priority**: P0
- **Depends On**: Task 1
- **Description**:
  - 在 `backend/models/` 创建 Pydantic 模型：`AuthRequest`, `AuthResponse`, `Library`, `MediaItem`, `PlaybackInfo`, `SearchResult`, `SubtitleTrack`
  - 在 `backend/clients/emby_client.py` 创建 `EmbyClient` 类，封装 httpx 异步客户端，核心方法：`authenticate`, `get_libraries`, `get_items`, `get_item`, `get_playback_url`, `search`, `get_subtitles`, `get_playback_progress`, `save_playback_progress`, `toggle_favorite`, `get_favorites`, `get_user_items`
  - 在 `backend/core/config.py` 管理环境变量（Emby 基础地址从请求头动态获取，不写死）
  - 在 `backend/core/errors.py` 定义统一错误处理与 HTTP 异常映射
- **Acceptance Criteria Addressed**: AC-12, AC-13, AC-14
- **Test Requirements**:
  - `programmatic` TR-2.1: `EmbyClient` 类所有方法均有完整类型签名（Pydantic 模型），可被外部调用
  - `programmatic` TR-2.2: 编写简单单元测试，验证在 mock httpx 响应下 `EmbyClient.authenticate` 正确解析返回 JSON
  - `human-judgment` TR-2.3: 代码结构分层（clients, models, core）清晰且命名合理

---

## [x] Task 3: FastAPI - 路由层实现
- **Priority**: P0
- **Depends On**: Task 2
- **Description**:
  - 在 `backend/routers/` 创建路由文件：`auth.py`, `libraries.py`, `items.py`, `search.py`, `favorites.py`, `subtitles.py`
  - `POST /api/auth/login` —— 接收 `{emby_url, username, password}`，转发至 Emby `/Users/AuthenticateByName`，返回 `access_token`, `user_id`, `server_id`
  - `GET /api/libraries` —— 返回用户媒体库列表（需要请求头 `X-Emby-Token` 和 `X-Emby-Server-Url`）
  - `GET /api/libraries/{library_id}/items` —— 返回分页视频列表，query 参数支持 `limit`, `offset`, `sort`
  - `GET /api/items/{item_id}` —— 返回视频详情（含缩略图 URL、时长、类型）
  - `GET /api/items/{item_id}/playback` —— 返回播放地址（直链或 HLS）
  - `GET /api/items/{item_id}/subtitles` —— 返回字幕轨道列表
  - `POST /api/search` —— 按关键词搜索，支持类型过滤
  - `POST /api/favorites` / `DELETE /api/favorites/{item_id}` —— 添加/移除收藏
  - `GET /api/favorites` —— 返回收藏列表
  - `POST /api/items/{item_id}/progress` —— 保存播放进度；`GET /api/items/{item_id}/progress` —— 读取播放进度
  - `GET /api/proxy/image/{path:path}` —— 代理转发 Emby 图片请求（解决跨域与鉴权）
  - 在 `main.py` 挂载所有路由
- **Acceptance Criteria Addressed**: AC-11, AC-12, AC-13, AC-14
- **Test Requirements**:
  - `programmatic` TR-3.1: 所有路由在 Swagger UI 中可见，请求体/响应体有明确 schema
  - `programmatic` TR-3.2: 使用 curl 或 pytest 模拟请求，每一条路由（含错误路径）均返回正确的 HTTP 状态码
  - `human-judgment` TR-3.3: 返回 JSON 字段命名对前端友好（驼峰或下划线一致）

---

## [x] Task 4: FastAPI - Docker 容器化
- **Priority**: P1
- **Depends On**: Task 1
- **Description**:
  - 创建 `backend/Dockerfile`：基于 `python:3.11-slim`，拷贝代码、安装依赖、暴露 8000 端口、`CMD uvicorn main:app --host 0.0.0.0 --port 8000`
  - 创建 `backend/.dockerignore` 排除 `__pycache__`, `.venv` 等
  - 创建根目录 `docker-compose.yml`：定义 `embbytok-backend` 服务，映射 8000 端口，支持 `docker-compose up -d` 一键启动
- **Acceptance Criteria Addressed**: AC-15
- **Test Requirements**:
  - `programmatic` TR-4.1: `docker build -t embbytok-backend backend/ && docker run -p 8000:8000 embbytok-backend` 后，`curl http://localhost:8000/health` 返回 200
  - `programmatic` TR-4.2: `docker-compose up -d` 能成功启动并暴露 8000 端口
  - `human-judgment` TR-4.3: Dockerfile 层设计合理（先拷贝 requirements 再拷贝代码，充分利用缓存）

---

## [x] Task 5: Flutter 前端项目脚手架与核心依赖
- **Priority**: P0
- **Depends On**: None（与 Task 1 可并行）
- **Description**:
  - 在 `frontend/` 执行 `flutter create .` 创建 Flutter 项目骨架，或手动建立最小结构
  - 编辑 `frontend/pubspec.yaml`，引入依赖：`flutter_riverpod`, `go_router`, `dio`, `shared_preferences`, `media_kit`, `media_kit_video`, `cached_network_image`, `intl`
  - 创建 `frontend/lib/main.dart`：初始化 SharedPreferences、Dio 客户端、配置 ProviderScope
  - 创建 `frontend/lib/app.dart`：配置 GoRouter 路由（login, feed, search, favorites, history, settings）与主题
  - 创建项目目录：`models/, views/, widgets/, services/, providers/, utils/`
  - 更新 `frontend/README.md`，列出 Flutter 版本要求与运行命令
- **Acceptance Criteria Addressed**: AC-16, AC-18
- **Test Requirements**:
  - `programmatic` TR-5.1: 在 `frontend/` 执行 `flutter pub get` 成功，无依赖冲突
  - `programmatic` TR-5.2: `flutter run`（有可用设备/模拟器时）应用成功启动并展示第一屏
  - `human-judgment` TR-5.3: 目录结构符合 models/views/widgets/services/providers/utils 分层

---

## [x] Task 6: Flutter - 数据模型与 API 服务层
- **Priority**: P0
- **Depends On**: Task 3, Task 5
- **Description**:
  - 在 `frontend/lib/models/` 创建 Dart 数据类：`User`, `Library`, `MediaItem`, `PlaybackInfo`, `SubtitleTrack`, `AppConfig`, `WatchHistoryItem`。使用 `freezed` 或手写 `fromJson/toJson`
  - 在 `frontend/lib/services/api_client.dart` 创建 `ApiClient` 类：封装 Dio，提供统一的 `get/post/put/delete` 方法，自动注入 Token header；提供 `setBaseUrl`, `setToken` 方法
  - 在 `frontend/lib/services/embytok_service.dart` 创建业务服务：`login()`, `getLibraries()`, `getItems()`, `getItem()`, `getPlaybackUrl()`, `search()`, `toggleFavorite()`, `getFavorites()`, `saveProgress()`, `getProgress()`, `getSubtitles()`
- **Acceptance Criteria Addressed**: AC-1, AC-12, AC-13, AC-14
- **Test Requirements**:
  - `programmatic` TR-6.1: 所有模型类提供 `fromJson` 方法，`flutter test` 可解析 mock JSON
  - `programmatic` TR-6.2: `ApiClient` 在 Dio 拦截器中正确注入 Token，无 Token 时不报错但不发起请求或返回错误
  - `human-judgment` TR-6.3: 服务层方法命名与 API 路由语义一致，便于理解

---

## [x] Task 7: Flutter - 状态管理（Providers）
## [x] Task 8: Flutter - 登录与服务器配置页面
- **Priority**: P0
- **Depends On**: Task 6
- **Description**:
  - `frontend/lib/providers/auth_provider.dart` —— 登录态、Token、用户信息、服务器地址管理；提供 `login/logout/isAuthenticated`；使用 `shared_preferences` 持久化
  - `frontend/lib/providers/library_provider.dart` —— 当前媒体库与库列表管理
  - `frontend/lib/providers/video_list_provider.dart` —— 视频列表数据与分页加载管理（StateNotifier）
  - `frontend/lib/providers/favorites_provider.dart` —— 收藏列表与操作
  - `frontend/lib/providers/search_provider.dart` —— 搜索状态与结果
  - `frontend/lib/providers/theme_provider.dart` —— 主题与用户 UI 偏好
  - `frontend/lib/providers/app_router.dart` —— GoRouter 路由定义，基于 auth state 做路由守卫（未登录重定向到登录页）
- **Acceptance Criteria Addressed**: AC-1, AC-2, AC-7, AC-8, AC-10, AC-13
- **Test Requirements**:
  - `programmatic` TR-7.1: `auth_provider` 的持久化验证：设置后重启 ProviderScope，值正确恢复
  - `programmatic` TR-7.2: `video_list_provider` 分页状态机测试：初始 loading → 成功 → 继续加载下一页
  - `human-judgment` TR-7.3: Provider 之间的依赖关系合理，无循环依赖

---

## [x] Task 8: Flutter - 登录与服务器配置页面
- **Priority**: P0
- **Depends On**: Task 7
- **Description**:
  - `frontend/lib/views/login_view.dart` —— 表单包含：后端代理地址、Emby 服务器地址、用户名、密码、API Key（可选替代密码）
  - 输入验证：URL 格式、非空校验；提交时展示 loading 状态；失败展示中文错误提示（"服务器地址无效"、"用户名或密码错误"等）
  - 登录成功后保存配置到 shared_preferences，路由跳转到视频流页面
  - 已登录状态下直接进入应用，跳过登录页
- **Acceptance Criteria Addressed**: AC-1
- **Test Requirements**:
  - `programmatic` TR-8.1: 表单验证单元测试：空值、非法 URL 应阻止提交
  - `programmatic` TR-8.2: mock service 返回成功时，shared_preferences 中可读到 token
  - `human-judgment` TR-8.3: UI 美观且符合现代移动端登录页风格

---

## [x] Task 9: Flutter - 视频流页面（TikTok 式竖屏滑动）
- **Priority**: P0
- **Depends On**: Task 7, Task 6
- **Description**:
  - `frontend/lib/views/feed_view.dart` —— 使用 `PageView.builder` 实现竖向全屏滑动，每页一个视频
  - `frontend/lib/widgets/video_page_item.dart` —— 单页视频容器：视频播放器 + 视频信息覆盖层（标题、简介、用户信息、右侧操作按钮列）
  - `frontend/lib/widgets/video_feed_loader.dart` —— 分页加载：到达列表底部触发 `video_list_provider.loadMore()`
  - 每个视频使用独立的播放器控制器；当前页自动播放，其他页暂停
  - 提供媒体库选择器（下拉或底部抽屉），切换媒体库后重新加载列表
- **Acceptance Criteria Addressed**: AC-2, AC-3, AC-4
- **Test Requirements**:
  - `programmatic` TR-9.1: `PageView` 切换时，新页面的 controller 处于播放状态，旧页面的 controller 被 dispose 或 pause
  - `programmatic` TR-9.2: 分页加载测试：列表数据触底时触发新请求，追加 items 且不重复
  - `human-judgment` TR-9.3: 滑动动画流畅，切页无明显卡顿（人工体验判断）

---

## [x] Task 10: Flutter - 视频播放器与控制条
- **Priority**: P0
- **Depends On**: Task 9
- **Description**:
  - `frontend/lib/widgets/video_player_widget.dart` —— 封装 media_kit / video_player，对外暴露统一的播放控制接口，方便未来替换底层库
  - `frontend/lib/widgets/video_controls.dart` —— 控制条：播放/暂停按钮、进度条、时间显示、倍速选择（0.5x/1x/1.5x/2x）、全屏按钮
  - 支持点击画面切换显示/隐藏控制条；控制条默认 3 秒后自动隐藏
  - 播放进度变化时调用 `saveProgress` 保存到服务器
- **Acceptance Criteria Addressed**: AC-4, AC-10
- **Test Requirements**:
  - `programmatic` TR-10.1: 播放器组件状态流测试：isPlaying, position, duration 正确更新
  - `programmatic` TR-10.2: 倍速切换接口可用（0.5x/1x/1.5x/2x）
  - `human-judgment` TR-10.3: 控制条样式美观，进度条拖动手感顺畅

---

## [x] Task 11: Flutter - 手势交互层
- **Priority**: P1
- **Depends On**: Task 9, Task 10
- **Description**:
  - `frontend/lib/widgets/gesture_overlay.dart` —— 使用 `GestureDetector` 封装手势：单击（切换播放/暂停）、双击（触发收藏 + 点赞动画）、长按（切换 2x 倍速）、水平拖动（快进/快退，显示进度提示）
  - `frontend/lib/widgets/heart_animation.dart` —— 双击画面时心形图标放大渐隐动画
  - 手势不与 `PageView` 竖向滑动冲突（合理配置 behavior 与 hitTest）
- **Acceptance Criteria Addressed**: AC-5
- **Test Requirements**:
  - `programmatic` TR-11.1: 双击触发收藏状态变化且持久化
  - `programmatic` TR-11.2: 长按期间倍速为 2.0，松开恢复 1.0
  - `human-judgment` TR-11.3: 手势响应及时，与滑动不冲突，点赞动画美观

---

## [x] Task 12: Flutter - 智能预加载
- **Priority**: P1
- **Depends On**: Task 9, Task 10
- **Description**:
  - 在 `video_list_provider` 或 `feed_view` 内实现：当前索引为 N 时，提前初始化第 N+1（和 N+2）视频的 `MediaController` 并调用 `open()` 开始缓冲
  - 图片：使用 `cached_network_image` 并在 `video_page_item` 内提前预热下一项的缩略图
  - 根据网络状况（连接状态可在 `ApiClient` 侧检测）动态调整预加载数量（WiFi 预加载 2 项，移动网络预加载 1 项）
- **Acceptance Criteria Addressed**: AC-6
- **Test Requirements**:
  - `programmatic` TR-12.1: 切到下一项时，目标 controller 已处于 `playing` 或 `buffering` 状态而非 idle
  - `human-judgment` TR-12.2: 体感上切页后视频在 500ms 内开始播放

---

## [x] Task 13: Flutter - 收藏管理页面
- **Priority**: P1
- **Depends On**: Task 7, Task 9
- **Description**:
  - `frontend/lib/views/favorites_view.dart` —— 展示收藏列表，每行显示视频缩略图、标题、时长
  - 每行支持左滑或长按删除；点击进入视频播放（复用播放器或跳转到 feed_view 的对应位置）
  - 与 `favorites_provider` 联动；空状态展示友好提示
- **Acceptance Criteria Addressed**: AC-7
- **Test Requirements**:
  - `programmatic` TR-13.1: 列表正确渲染 `favorites_provider` 返回的数据；删除后状态同步更新
  - `programmatic` TR-13.2: 双击收藏与页面收藏按钮行为一致（都调用 `toggleFavorite`）
  - `human-judgment` TR-13.3: 空状态与加载状态 UI 美观

---

## [x] Task 14: Flutter - 搜索页面
- **Priority**: P1
- **Depends On**: Task 7
- **Description**:
  - `frontend/lib/views/search_view.dart` —— 顶部搜索栏 + 结果区
  - 结果区按类型（电影/剧集/音乐）分组展示；每组支持 "加载更多"
  - 点击结果项进入视频流页面并定位到该视频，或直接打开播放器
  - 支持搜索历史（本地存储最近 10 条关键词）
- **Acceptance Criteria Addressed**: AC-8
- **Test Requirements**:
  - `programmatic` TR-14.1: 提交搜索后 `search_provider` 正确发起请求，UI 展示结果
  - `programmatic` TR-14.2: 搜索历史写入 shared_preferences，重启应用后仍可读取
  - `human-judgment` TR-14.3: 搜索输入与结果分组清晰美观

---

## [x] Task 15: Flutter - 字幕支持
- **Priority**: P2
- **Depends On**: Task 10
- **Description**:
  - 在 `video_player_widget.dart` 内集成字幕渲染：从 `getSubtitles` 获取轨道列表，解析 SRT/VTT 文本，在视频画面底部叠加 `Text` 组件
  - `frontend/lib/widgets/subtitle_renderer.dart` —— 字幕渲染组件
  - `frontend/lib/widgets/subtitle_controls.dart` —— 字幕轨道选择 + 样式调整（字体大小、颜色、垂直偏移）
  - 字幕偏好写入 `theme_provider` 持久化
- **Acceptance Criteria Addressed**: AC-9
- **Test Requirements**:
  - `programmatic` TR-15.1: 解析 SRT 文本后按时间戳展示正确字幕
  - `programmatic` TR-15.2: 切换轨道后当前字幕清空并显示新轨道内容
  - `human-judgment` TR-15.3: 字幕字号/颜色可调整且清晰可读

---

## [x] Task 16: Flutter - 观看历史页面
- **Priority**: P2
- **Depends On**: Task 7
- **Description**:
  - `frontend/lib/views/watch_history_view.dart` —— 展示最近观看的视频，按时间倒序，显示视频缩略图、标题、已观看进度百分比
  - 点击历史项进入播放并跳转到上次位置
  - 支持清空历史
- **Acceptance Criteria Addressed**: AC-10
- **Test Requirements**:
  - `programmatic` TR-16.1: 观看视频并退出后，历史记录中出现该条目，进度值正确
  - `programmatic` TR-16.2: 清空操作移除所有历史记录项
  - `human-judgment` TR-16.3: 历史列表样式与收藏页风格一致

---

## [x] Task 17: Flutter - 主题与设置页面
- **Priority**: P2
- **Depends On**: Task 7
- **Description**:
  - `frontend/lib/views/settings_view.dart` —— 设置项：主题（深色/浅色/跟随系统）、默认倍速、字幕默认样式、是否自动播放下一个、清除缓存、退出登录
  - 所有设置项写入 `theme_provider` / `shared_preferences` 持久化
  - `frontend/lib/utils/theme.dart` —— 定义 Flutter ThemeData（深色为主，类似 TikTok 的沉浸感）
- **Acceptance Criteria Addressed**: AC-17, AC-18
- **Test Requirements**:
  - `programmatic` TR-17.1: 切换主题后 Widget tree 中 Theme.of(context) 返回的 brightness 变化
  - `programmatic` TR-17.2: 退出登录后 token 从 shared_preferences 清除，路由跳回登录页
  - `human-judgment` TR-17.3: 设置页面布局整齐，选项分组清晰

---

## [x] Task 18: 项目 README、错误处理与最终打磨
- **Priority**: P1
- **Depends On**: Task 1-17（大部分完成后进行）
- **Description**:
  - 更新根目录 `README.md`，包含：项目简介、技术栈、环境要求、分步安装与运行说明（Flutter、FastAPI、Docker）、功能列表、目录结构说明、已知限制
  - 在 Flutter 端实现全局错误捕获 (`FlutterError.onError` + `runZonedGuarded`)，所有未捕获错误展示 SnackBar 提示
  - 在 FastAPI 端增加统一异常处理器（Exception Middleware），返回标准化 JSON 错误响应
  - 在 Flutter 端实现网络状态监听（Connectivity 包），断网时在顶部展示红色提示条
  - 完善 `CODE_WIKI.md`（已存在于仓库根），加入核心架构图和关键数据流说明
- **Acceptance Criteria Addressed**: AC-17, AC-18
- **Test Requirements**:
  - `programmatic` TR-18.1: README 中的命令复制粘贴可完整运行（install → run）
  - `programmatic` TR-18.2: 全局错误处理器能捕获未捕获异常且不崩溃应用
  - `human-judgment` TR-18.3: 整体应用体验流畅，错误提示友好清晰

---

## 任务汇总（按优先级与依赖顺序）

| 任务 | 优先级 | 依赖 | 对应 AC |
|------|--------|------|---------|
| Task 1: FastAPI 后端脚手架 | P0 | - | AC-11, AC-15, AC-16 |
| Task 2: FastAPI 模型与 Emby 客户端 | P0 | Task 1 | AC-12, AC-13, AC-14 |
| Task 3: FastAPI 路由层 | P0 | Task 2 | AC-11 ~ AC-14 |
| Task 5: Flutter 前端脚手架 | P0 | - | AC-16, AC-18 |
| Task 4: FastAPI Docker 容器化 | P1 | Task 1 | AC-15 |
| Task 6: Flutter 模型与 API 服务 | P0 | Task 3, Task 5 | AC-1, AC-12 ~ AC-14 |
| Task 7: Flutter Providers | P0 | Task 6 | AC-1, AC-2, AC-7, AC-8, AC-10, AC-13 |
| Task 8: Flutter 登录页面 | P0 | Task 7 | AC-1 |
| Task 9: Flutter 视频流页面 | P0 | Task 6, Task 7 | AC-2, AC-3, AC-4 |
| Task 10: Flutter 视频播放器 | P0 | Task 9 | AC-4, AC-10 |
| Task 11: Flutter 手势交互 | P1 | Task 9, Task 10 | AC-5 |
| Task 12: Flutter 智能预加载 | P1 | Task 9, Task 10 | AC-6 |
| Task 13: Flutter 收藏管理 | P1 | Task 7, Task 9 | AC-7 |
| Task 14: Flutter 搜索页面 | P1 | Task 7 | AC-8 |
| Task 15: Flutter 字幕支持 | P2 | Task 10 | AC-9 |
| Task 16: Flutter 观看历史 | P2 | Task 7 | AC-10 |
| Task 17: Flutter 主题与设置 | P2 | Task 7 | AC-17, AC-18 |
| Task 18: README 与打磨 | P1 | Task 1-17 | AC-17, AC-18 |

## 可并行执行的任务组

- **组 A（后端启动）**: Task 1 → Task 2 → Task 3 → Task 4
- **组 B（前端启动）**: Task 5 可与组 A 并行执行；Task 6 开始前需组 A 的 Task 3 完成（API 契约确定）
- **组 C（核心体验）**: Task 7 → Task 8 → Task 9 → Task 10 串行；Task 11/12 在 Task 10 后可并行
- **组 D（辅助功能）**: Task 13, 14, 15, 16, 17 可在 Task 7 完成后按需并行推进
- **组 E（收尾）**: Task 18 最后进行

---

## 里程碑

- **M1 (Alpha)**: Task 1-10 完成，后端可用 + Flutter 可跑通登录到视频播放主路径
- **M2 (Beta)**: Task 11-17 全部完成，所有功能可用
- **M3 (Release)**: Task 18 完成，文档齐全，可发布 v1.0
