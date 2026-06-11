# EmbyTok-Flutter v1 - 产品需求文档 (PRD)

## Overview

- **Summary**: 使用 **Flutter + FastAPI + Emby API** 技术栈，从零构建一款为 Emby 媒体服务器设计的竖屏视频浏览客户端，提供类似 TikTok 的沉浸式滑动浏览体验，包括视频流、手势控制、收藏管理、字幕支持与搜索功能。后端通过 FastAPI 中间层统一封装 Emby REST API，为 Flutter 客户端提供标准化的 JSON 接口。
- **Purpose**: 原版 EmbyTok 使用 React + WebView，在移动端受限于 WebView 的视频播放延迟和手势体验。重构为 Flutter 原生 + FastAPI 中间层架构后，可提供接近原生 60fps 的流畅体验，并通过统一的 API 抽象层同时兼容 Emby 和 Plex 媒体服务器。
- **Target Users**: 
  - 拥有 Emby/Plex 私有媒体库的家庭用户
  - 习惯于短视频 APP 交互体验的移动端用户
  - 希望在电视大屏浏览媒体库的用户（后续 TV 模式）

---

## Goals

- **G-1**: 构建可用的 FastAPI 后端中间层，至少完成 Emby API 的核心功能封装（认证、媒体库、视频列表、播放地址、搜索、字幕）
- **G-2**: 构建 Flutter 客户端核心体验：TikTok 式竖屏视频流（上下滑动切换视频，自动播放/暂停）
- **G-3**: 实现完整的视频播放功能：原生播放器 + 基本播放控制（播放/暂停/进度/倍速）
- **G-4**: 实现手势控制：单击暂停、双击收藏、长按倍速、左右滑动快进/快退
- **G-5**: 实现登录与服务器配置页面：输入 Emby 服务器地址、用户名密码、后端代理地址并持久化
- **G-6**: 实现智能预加载：根据滚动位置与网络状况提前加载后续视频，确保切换零等待
- **G-7**: 实现收藏管理：创建/管理收藏集合，跨设备同步（通过服务器端播放列表）
- **G-8**: 实现搜索功能：按关键词搜索，支持按类型分类展示
- **G-9**: 实现字幕支持：多语言字幕轨道切换、可调节字体/颜色/位置
- **G-10**: 提供 Docker 容器化部署方案，便于一键部署后端

## Non-Goals (Out of Scope)

- **不在本版本范围内**:
  - Plex API 兼容支持（计划在 v2 版本实现）
  - TV 模式适配（遥控器导航、大屏布局优化，规划为后续版本）
  - 桌面端（macOS/Windows/Linux）桌面应用独立优化
  - 用户账户管理（创建/删除 Emby 用户）
  - 媒体库管理（增删文件、修改元数据）
  - 实时聊天/社交功能
  - 付费/订阅系统
- **实现约束**:
  - 不重写 Emby 核心功能，仅封装现有 API
  - 不对视频流进行转码处理（直接使用 Emby 的转码能力）
  - 不自建数据库，收藏/历史等数据通过 Emby 播放列表和本地存储实现

---

## Background & Context

- **项目前身**: EmbyTok-ai（React + Vite + Capacitor，WebView 封装的移动应用）在移动端体验受限：视频播放延迟、手势响应不够丝滑。
- **技术选型理由**: 
  - **Flutter**: 跨平台一套代码，原生渲染，视频播放和手势能力远优于 WebView
  - **Riverpod**: 声明式状态管理，与 Flutter 生态深度集成
  - **FastAPI**: 异步 Python 框架，与 httpx 配合可高效转发 Emby API 请求，自动生成 OpenAPI 文档
  - **media_kit**: 高性能跨平台视频播放库，相比 video_player 有更好的定制能力
- **外部系统依赖**: 
  - Emby Server (版本 4.7+，需启用 REST API)
  - 可选：Redis 用于 API 响应缓存（降低 Emby Server 请求压力）

## Functional Requirements

- **FR-1 (认证)**: 用户可在登录页面输入 Emby 服务器地址、用户名、密码、后端代理地址，提交后通过 FastAPI 中间层代理请求到 Emby `/Users/AuthenticateByName` 接口，成功后保存 Access Token 和用户信息。
- **FR-2 (媒体库列表)**: 登录成功后，展示用户可用的媒体库列表（电影、剧集、音乐等），支持切换当前浏览的媒体库。
- **FR-3 (视频流)**: 在竖屏全屏模式下展示视频流，每屏一个视频，用户可上下滑动切换视频；进入时自动播放当前视频，切出时自动暂停。
- **FR-4 (视频播放)**: 使用原生播放器播放 Emby 提供的视频流地址（直链或 HLS），支持播放/暂停、进度拖动、倍速切换。
- **FR-5 (手势控制)**: 单击画面暂停/播放；双击画面触发收藏并展示点赞动画；长按画面切换至 2x 倍速，松开恢复；左右滑动画面可快进/快退。
- **FR-6 (智能预加载)**: 根据当前滚动位置，提前加载下 1~2 个视频的首帧和部分数据流，滑动切换时可立即播放。
- **FR-7 (收藏管理)**: 用户可查看当前收藏集合、将视频添加到收藏、从收藏中移除；收藏数据通过 Emby 播放列表 API 保存到服务器。
- **FR-8 (搜索)**: 用户可输入关键词搜索视频，搜索结果按类型（电影/剧集/音乐）分组展示，支持分页加载。
- **FR-9 (字幕)**: 播放视频时可切换字幕轨道（如视频包含多语言字幕），可调整字幕字体大小、颜色、显示位置。
- **FR-10 (播放历史)**: 自动记录观看进度，下次播放同一视频时从上次位置继续；记录完整的观看历史供用户查看。
- **FR-11 (FastAPI 中间层)**: 提供统一的 REST/JSON API，封装 Emby 的认证与媒体接口，处理跨域、请求转发、错误转换；提供 `/health` 健康检查端点；生成 OpenAPI/Swagger 文档。
- **FR-12 (Docker 部署)**: 提供 Dockerfile 和 docker-compose.yml，支持一条命令部署 FastAPI 后端。
- **FR-13 (配置持久化)**: Flutter 客户端使用 `shared_preferences` 保存服务器地址、Token、用户偏好（主题、字幕设置），应用重启后自动恢复。

## Non-Functional Requirements

- **NFR-1 (性能)**: Flutter 客户端在中高端手机上视频流滑动帧率不低于 55fps；首次进入视频流页面的加载时间不超过 3 秒（在 10Mbps 网络环境下）。
- **NFR-2 (错误处理)**: 网络请求失败、认证失败、视频播放失败均需向用户展示清晰的中文错误提示；不出现未捕获的崩溃。
- **NFR-3 (安全)**: 密码不在客户端本地持久化存储（仅保存 Token）；Token 在请求头中使用标准 Authorization Bearer 方式传递；FastAPI 不记录请求体中的敏感字段。
- **NFR-4 (代码质量)**: Flutter 项目遵循 Dart 官方风格；FastAPI 项目遵循 Python PEP 8 规范；关键模块包含单元测试。
- **NFR-5 (可维护性)**: 前后端代码按分层目录组织（models/views/widgets/services/providers/clients/routers）；公共组件与工具函数抽离复用。
- **NFR-6 (文档)**: FastAPI 自动生成 Swagger UI；项目根目录 README 包含完整的安装与运行说明。
- **NFR-7 (国际化)**: Flutter 客户端默认中文，UI 字符串集中管理，便于后续增加英文。

## Constraints

- **技术**:
  - Flutter SDK >= 3.10, Dart >= 3.0
  - Python >= 3.11, FastAPI >= 0.100
  - 主要状态管理库固定为 flutter_riverpod
  - 路由固定为 go_router
  - 网络请求固定为 dio
  - 视频播放优先使用 media_kit（必要时兼容 video_player）
- **业务**:
  - 必须兼容 Emby Server 4.7+ 官方 REST API
  - 认证方式使用 Emby 官方的用户名/密码认证 + API Key 两种
- **依赖**:
  - Emby Server (外部系统，用户自备)
  - Python packages: fastapi, uvicorn, httpx, pydantic, python-multipart
  - Flutter packages: flutter_riverpod, go_router, dio, media_kit, shared_preferences, cached_network_image

## Assumptions

- 终端用户已拥有一台可访问的 Emby Server 实例（4.7 及以上版本）
- Emby Server 已启用公开的 REST API 端口（默认 8096 HTTP / 8920 HTTPS）
- 用户在 Flutter 客户端和 Emby Server 之间有可用的网络连接（局域网或公网）
- FastAPI 后端部署在可同时访问 Emby Server 和 Flutter 客户端的网络位置
- Flutter 客户端运行在 Android 8+ 或 iOS 13+ 设备上

## Acceptance Criteria

### AC-1: 登录与服务器配置
- **Given**: 用户首次打开应用且未配置过服务器
- **When**: 用户在登录页面输入有效的 Emby 服务器地址、用户名、密码和后端代理地址后点击"登录"按钮
- **Then**: 应用通过 FastAPI 中间层成功认证；保存 Token 到本地存储；跳转到视频流页面；下次打开应用自动恢复登录状态
- **Verification**: `programmatic`
- **Notes**: 需验证错误场景：服务器地址无效、用户名密码错误、后端代理不可用

### AC-2: 媒体库列表展示
- **Given**: 用户已成功登录
- **When**: 用户打开媒体库选择器
- **Then**: 展示 Emby 服务器返回的所有媒体库（名称、封面、项目数量），用户可点击切换当前库
- **Verification**: `programmatic` + `human-judgment`（视觉一致性）

### AC-3: 竖屏视频流
- **Given**: 用户已选择一个视频类型的媒体库
- **When**: 用户进入视频流页面并上下滑动
- **Then**: 每屏展示一个视频并自动播放；向上滑动展示下一个视频；向下滑动回退到上一个；切换时自动暂停当前视频并播放新视频
- **Verification**: `programmatic` + `human-judgment`（流畅度体验）

### AC-4: 视频播放控制
- **Given**: 视频正在播放
- **When**: 用户通过控制条操作
- **Then**: 可暂停/继续播放；可拖动进度条跳转；可选择播放速度（0.5x / 1x / 1.5x / 2x）；可显示当前时间/总时长
- **Verification**: `programmatic`

### AC-5: 手势交互
- **Given**: 视频正在播放且控制条已隐藏
- **When**: 用户单击/双击/长按/左右滑动画面
- **Then**: 单击暂停；双击触发收藏动画并加入收藏；长按期间以 2x 速度播放，松开恢复；左右滑动可快进/快退固定时长
- **Verification**: `human-judgment` + `programmatic`（收藏状态持久化验证）

### AC-6: 智能预加载
- **Given**: 用户正在浏览视频流，当前播放第 N 个视频
- **When**: 网络状况良好且用户未快速滚动
- **Then**: 第 N+1 个视频的缩略图已预加载完成，视频首段数据已缓冲，滑动切换后可在 500ms 内开始播放
- **Verification**: `human-judgment`（体感流畅度）

### AC-7: 收藏功能
- **Given**: 用户已登录并在视频流中浏览
- **When**: 用户双击视频或点击收藏按钮
- **Then**: 视频被添加到"我的收藏"集合（通过 Emby 播放列表实现），在"我的收藏"页面可查看和管理所有收藏视频
- **Verification**: `programmatic`

### AC-8: 搜索功能
- **Given**: 用户已登录
- **When**: 用户在搜索页面输入关键词并提交
- **Then**: 展示匹配的视频列表，按类型分组，支持分页加载更多结果；点击结果项进入视频播放
- **Verification**: `programmatic`

### AC-9: 字幕支持
- **Given**: 当前播放的视频包含字幕轨道
- **When**: 用户点击字幕按钮选择轨道或调整样式
- **Then**: 画面底部显示选中语言的字幕；用户可在设置中调整字幕字体大小、颜色、位置
- **Verification**: `programmatic` + `human-judgment`（字幕渲染可读性）

### AC-10: 播放历史与进度记忆
- **Given**: 用户播放某个视频到第 15 分钟后退出
- **When**: 用户再次打开同一视频
- **Then**: 视频从第 15 分钟位置继续播放；用户可在"观看历史"页面看到该条记录
- **Verification**: `programmatic`

### AC-11: FastAPI 后端健康检查
- **Given**: 后端服务已启动
- **When**: 向 `/health` 发送 GET 请求
- **Then**: 返回 HTTP 200 和包含版本信息的 JSON 响应
- **Verification**: `programmatic`

### AC-12: FastAPI 后端代理认证
- **Given**: 后端服务已启动，Emby Server 可访问
- **When**: 向 `/api/auth/login` 发送包含有效用户名密码的 POST 请求
- **Then**: 后端将请求转发至 Emby，成功后返回 Access Token 和用户信息；密码错误返回 401
- **Verification**: `programmatic`

### AC-13: FastAPI 后端视频列表接口
- **Given**: 已获取有效 Token
- **When**: 向 `/api/libraries/{library_id}/items` 发送 GET 请求
- **Then**: 返回分页后的视频列表 JSON，字段包含 id、title、thumbnail、duration、type 等
- **Verification**: `programmatic`

### AC-14: FastAPI 后端搜索与播放地址
- **Given**: 已获取有效 Token
- **When**: 向 `/api/search` 发送搜索请求，或向 `/api/items/{item_id}/playback` 获取播放地址
- **Then**: 搜索返回匹配结果；播放地址返回可直接在播放器中使用的 URL
- **Verification**: `programmatic`

### AC-15: Docker 容器化
- **Given**: 主机已安装 Docker 和 docker-compose
- **When**: 执行 `docker-compose up -d`
- **Then**: FastAPI 后端服务在指定端口（默认 8000）启动，可访问健康检查和 Swagger UI
- **Verification**: `programmatic`

### AC-16: Flutter 项目可运行
- **Given**: 开发机已安装 Flutter SDK 3.10+ 和对应平台工具链
- **When**: 在 frontend/ 目录执行 `flutter pub get && flutter run`
- **Then**: 应用成功编译并安装到连接的设备或模拟器，启动后展示登录页面
- **Verification**: `programmatic`

### AC-17: 错误处理与用户提示
- **Given**: 网络断开或 Emby Server 不可达
- **When**: 应用发起网络请求
- **Then**: 展示清晰的错误提示（中文），不崩溃；网络恢复后重试按钮有效
- **Verification**: `human-judgment`

### AC-18: 代码结构与文档
- **Given**: 项目代码已完成
- **When**: 开发者查看目录结构
- **Then**: frontend/ 下按 lib/models/views/widgets/services/providers/utils 分层组织；backend/ 下按 main/routers/services/models/clients 分层组织；README 包含完整运行说明
- **Verification**: `human-judgment`

---

## Open Questions

- [ ] **Q1**: Flutter 视频播放库选择 `media_kit` 还是 `video_player`？media_kit 功能更强但在 iOS 上配置较复杂，video_player 是官方库但定制能力有限。是否可以在一个抽象接口下同时支持两者？
- [ ] **Q2**: 收藏同步机制——使用 Emby 播放列表 API 保存到服务器是强依赖 Emby 的方案，是否需要在 FastAPI 侧维护独立的收藏存储（如 SQLite + Redis）以实现多端一致性？
- [ ] **Q3**: 字幕渲染——media_kit 内置字幕渲染能力是否满足多轨切换和样式定制需求？还是需要在 Flutter 端自己解析 SRT/VTT 并叠加渲染？
- [ ] **Q4**: 视频流预加载策略——在 Flutter 中预加载视频数据的最佳实践是什么？是否使用 PageView + 提前初始化 VideoPlayerController？
- [ ] **Q5**: FastAPI 后端是否需要引入用户会话管理？还是每次请求都由 Flutter 端直接携带 Emby Token 转发即可？
- [ ] **Q6**: 主题设计——需要深色/浅色模式切换，还是统一深色主题（类似 TikTok 的沉浸式体验）？
- [ ] **Q7**: 版权和许可证——代码是否沿用 MIT License 与原项目一致？
