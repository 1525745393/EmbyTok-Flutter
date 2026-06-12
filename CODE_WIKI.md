# EmbyTok 项目 Code Wiki

> 本文档记录 EmbyTok 项目的整体架构、主要模块职责、关键类与函数说明、依赖关系以及项目运行方式等关键信息。

---

## 1. 项目概述

### 1.1 项目简介

**EmbyTok** 是一个为 **Emby 和 Plex 媒体服务器**设计的**竖屏视频浏览客户端**，提供类似 **TikTok 的沉浸式滑动浏览体验**，让用户能够以更现代、便捷的方式浏览个人媒体库。

- **原版技术栈**（EmbyTok-ai）：React 18 + TypeScript + Vite + Tailwind CSS + Capacitor + Lucide React
- **Flutter 重构版**（当前仓库 EmbyTok-Flutter）：Flutter + FastAPI + Emby API，旨在提供更流畅的原生移动端体验

### 1.2 项目版本对比

| 维度 | 原版 (React + Vite) | Flutter 新版 (Flutter + FastAPI) |
|------|----------------------|----------------------------------|
| **前端框架** | React 18 (Web) | Flutter (跨平台原生) |
| **后端服务** | 无独立后端，前端直连 Emby | FastAPI 中间层，统一 API 抽象 |
| **平台支持** | Web / PWA / Android (Capacitor) | iOS / Android / Web / Desktop |
| **视频播放** | HTML5 Video | 原生播放器，更低延迟 |
| **手势交互** | Web Touch Events | 原生手势识别，更丝滑 |
| **性能表现** | 受限于 WebView | 接近原生 60fps |

### 1.3 核心功能特性

- **TikTok 式竖屏滑动** — 上下滑动切换视频，沉浸式全屏浏览
- **智能预加载** — 预加载后续视频，切换无等待
- **多源兼容** — 通过中间层统一封装，同时支持 Emby 和 Plex
- **手势控制** — 单击暂停、双击收藏、长按倍速、滑动快进
- **收藏管理** — 创建收藏集合，跨设备同步
- **字幕支持** — 多语言字幕，可调字体/颜色/位置
- **搜索功能** — 分页搜索，按类型分类展示
- **多端适配** — 移动端 / 桌面端 / TV 模式

---

## 2. 项目技术架构

### 2.1 三层架构模型

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Flutter /  │────▶│   FastAPI   │────▶│  Emby /     │
│  React App  │◀────│  (中间层)   │◀────│  Plex API   │
│  (客户端)   │     │             │     │  (媒体服务) │
└─────────────┘     └─────────────┘     └─────────────┘
       ▲                    ▲                    ▲
       │                    │                    │
  UI 渲染 / 播放        API 统一封装         媒体库 / 认证
  手势交互              缓存 / 转码          媒体流输出
```

### 2.2 技术栈一览

| 层级 | 技术选型 | 作用 |
|------|---------|------|
| **客户端（React 版）** | React 18 + TypeScript + Vite | UI 框架与构建 |
| | Tailwind CSS | 样式系统 |
| | Lucide React | 图标库 |
| | Capacitor | 跨平台移动应用打包 |
| | HTML5 Video API | 视频播放 |
| **客户端（Flutter 版）** | Flutter 3.x + Dart | 跨平台原生 UI |
| | Riverpod | 状态管理 |
| | media_kit / video_player | 原生视频播放 |
| | GoRouter | 路由管理 |
| | Dio | 网络请求 |
| **后端** | FastAPI (Python 3.11+) | API 中间层服务 |
| | asyncio + httpx | 异步 HTTP 请求 |
| | Redis (可选) | 缓存加速 |
| | Uvicorn | ASGI 服务器 |
| **媒体服务器** | Emby / Plex | 媒体库管理与流输出 |
| **部署** | Docker / Docker Compose | 容器化部署 |
| | Nginx | 反向代理 (React 版) |

---

## 3. 项目目录结构

### 3.1 React 版项目结构

```
/workspace
├── index.tsx                  # React 应用入口
├── App.tsx                    # 应用根组件，设备检测与路由分发
├── index.css                  # 全局样式
├── types.ts                   # 全局 TypeScript 类型定义
├── vite.config.ts             # Vite 生产环境配置
├── vite.config.local.ts       # Vite 本地开发配置
├── tsconfig.json              # TypeScript 编译配置
├── tailwind.config.js         # Tailwind CSS 配置
├── postcss.config.js          # PostCSS 配置
├── package.json               # 项目依赖与 NPM 脚本
├── capacitor.config.ts        # Capacitor 跨平台配置
├── manifest.json              # PWA 清单文件
├── sw.js                      # Service Worker
├── nginx.conf                 # Nginx 反向代理配置
├── Dockerfile                 # Docker 构建文件
├── docker-compose.yml         # Docker Compose 配置
│
├── components/                # React 组件目录
│   ├── mobile/               # 移动端专用组件
│   │   └── MobileRoot.tsx    # 移动端根组件
│   ├── standard/             # 标准/桌面端组件
│   │   └── StandardRoot.tsx  # 标准端根组件
│   ├── tv/                   # 电视端组件
│   │   ├── TVDashboard.tsx   # TV 仪表盘
│   │   ├── TVRoot.tsx        # TV 根组件
│   │   ├── TVSettings.tsx    # TV 设置页面
│   │   ├── TVVideoGrid.tsx   # TV 视频网格
│   │   └── TVVideoPlayer.tsx # TV 视频播放器
│   ├── Login.tsx             # 登录组件
│   ├── VideoFeed.tsx         # 视频流（TikTok 式滑动）
│   ├── VideoCard.tsx         # 视频卡片
│   ├── VideoPlayer.tsx       # 视频播放器
│   ├── VideoControls.tsx     # 视频控制条
│   ├── VideoGrid.tsx         # 视频网格视图
│   ├── VideoInfo.tsx         # 视频信息面板
│   ├── VideoSkeleton.tsx     # 视频加载骨架屏
│   ├── HeartAnimation.tsx    # 点赞动画
│   ├── SearchBar.tsx         # 搜索栏
│   ├── SearchResults.tsx     # 搜索结果
│   ├── LibrarySelect.tsx     # 媒体库选择器
│   ├── FavoritesManager.tsx  # 收藏管理
│   ├── WatchHistoryView.tsx  # 观看历史
│   ├── SubtitleControls.tsx  # 字幕控制
│   ├── SubtitleRenderer.tsx  # 字幕渲染
│   ├── DeleteConfirmDialog.tsx # 删除确认对话框
│   └── UpdateNotification.tsx # 更新通知
│
├── services/                  # 媒体服务客户端
│   ├── MediaClient.ts        # 媒体客户端接口（抽象基类）
│   ├── EmbyClient.ts         # Emby 服务器客户端实现
│   ├── PlexClient.ts         # Plex 服务器客户端实现
│   ├── clientFactory.ts      # 客户端工厂（根据配置创建实例）
│   └── embyService.ts        # Emby 服务层封装
│
├── src/                       # 源代码目录
│   ├── hooks/                # 自定义 React Hooks
│   │   ├── index.ts          # Hooks 统一导出入口
│   │   ├── useConfig.ts      # 应用配置管理 Hook
│   │   ├── useDeviceDetection.ts # 设备类型检测 Hook
│   │   ├── useFavorites.ts   # 收藏功能 Hook
│   │   ├── useGestureControls.ts # 手势控制 Hook
│   │   ├── useImagePreload.ts # 图片预加载 Hook
│   │   ├── useLazyImage.ts   # 图片懒加载 Hook
│   │   ├── useLibraries.ts   # 媒体库管理 Hook
│   │   ├── useLocalStorageState.ts # localStorage 状态持久化 Hook
│   │   ├── useSearch.ts      # 搜索功能 Hook
│   │   ├── useSmartVideoPreload.ts # 智能视频预加载 Hook
│   │   ├── useSubtitles.ts   # 字幕管理 Hook
│   │   ├── useTranslation.ts # 国际化翻译 Hook
│   │   ├── useUIState.ts     # UI 全局状态管理 Hook
│   │   ├── useUpdateChecker.ts # 更新检测 Hook
│   │   ├── useVideoControls.ts # 视频播放控制 Hook
│   │   ├── useVideoList.ts   # 视频列表数据 Hook
│   │   └── useWatchHistory.ts # 观看历史 Hook
│   └── locales/              # 国际化文件
│       ├── index.ts          # i18n 导出入口
│       ├── en.ts             # 英文翻译
│       └── zh.ts             # 中文翻译
│
├── utils/                     # 工具函数
│   ├── index.ts              # 统一导出入口
│   ├── device.ts             # 设备检测工具函数
│   ├── media.ts              # 媒体相关工具函数
│   └── time.ts               # 时间格式化工具函数
│
├── scripts/                   # 构建与资源生成脚本
│   ├── convert-format.mjs    # 格式转换脚本
│   ├── generate-android-banner.mjs # Android Banner 生成
│   ├── generate-android-icons-proper.mjs
│   ├── generate-android-icons-simple.mjs
│   ├── generate-android-icons.mjs
│   ├── generate-banner-from-png.mjs
│   ├── generate-favicon.mjs  # Favicon 生成
│   ├── generate-icons.mjs    # 图标生成
│   ├── generate-mobile-icons.mjs
│   ├── generate-multiple-sizes.mjs
│   ├── generate-social-media.mjs
│   └── optimize-images.mjs   # 图片优化脚本
│
├── android/                   # Android 平台代码
│   ├── app/src/main/java/com/embytok/app/MainActivity.java
│   └── build.gradle
│
├── public/                    # 静态资源
│   ├── icons/                # 图标资源
│   ├── icon.svg
│   └── index.local.html      # 本地开发 HTML 模板
│
└── icons/                     # 图标源文件
    ├── banner-template.svg
    └── icon-192x192.svg
```

### 3.2 Flutter 版项目结构（规划中）

```
EmbyTok-Flutter/
├── frontend/                 # Flutter 客户端
│   ├── lib/
│   │   ├── main.dart        # 应用入口
│   │   ├── app.dart         # 根组件，路由与主题配置
│   │   ├── models/          # 数据模型（视频项、配置等）
│   │   ├── views/           # 页面视图（登录、视频流、搜索等）
│   │   ├── widgets/         # UI 组件（视频卡片、播放器、控制条等）
│   │   ├── services/        # API 服务层（网络请求封装）
│   │   ├── providers/       # Riverpod 状态管理
│   │   └── utils/           # 工具函数
│   └── pubspec.yaml         # Flutter 依赖配置
│
├── backend/                  # FastAPI 后端
│   ├── main.py              # FastAPI 应用入口
│   ├── routers/             # API 路由定义
│   ├── services/            # 业务逻辑层
│   ├── models/              # Pydantic 数据模型
│   ├── clients/             # Emby / Plex API 客户端
│   └── requirements.txt     # Python 依赖
│
├── docker-compose.yml
├── Dockerfile
└── README.md
```

---

## 4. 核心模块职责说明

### 4.1 根组件层 (Root / App)

| 文件 | 核心职责 |
|------|---------|
| `App.tsx` | 应用根组件，负责**设备类型检测**（移动/桌面/TV），根据设备类型分发到对应的 Root 组件；管理登录态、全局配置加载 |
| `index.tsx` | React 应用入口，挂载根组件到 DOM，初始化全局 Provider |

### 4.2 组件层 (components/)

#### 4.2.1 视频流与播放核心

| 组件 | 功能描述 | 关键交互 |
|------|---------|---------|
| `VideoFeed.tsx` | TikTok 式竖屏滑动容器，管理视频列表的垂直分页滚动 | 上下滑动切换视频、触发预加载 |
| `VideoCard.tsx` | 单个视频卡片，包含视频播放器、视频信息、点赞/收藏按钮 | 单击暂停、双击点赞 |
| `VideoPlayer.tsx` | 视频播放器核心组件，封装 HTML5 Video API | 播放/暂停/seek/音量 |
| `VideoControls.tsx` | 视频播放控制条（进度条、播放按钮、时间显示） | 进度拖动、倍速切换 |
| `VideoSkeleton.tsx` | 视频加载骨架屏 | 提升首屏感知速度 |

#### 4.2.2 多端适配层

| 组件 | 功能描述 |
|------|---------|
| `MobileRoot.tsx` | 移动端根组件，针对竖屏优化的视频流布局 |
| `StandardRoot.tsx` | 标准/桌面端根组件，视频网格或列表视图 |
| `TVRoot.tsx` | TV 模式根组件，支持遥控器导航 |
| `TVDashboard.tsx` | TV 模式仪表盘首页 |
| `TVVideoGrid.tsx` | TV 视频网格视图，聚焦态突出显示 |
| `TVVideoPlayer.tsx` | TV 视频播放器 |
| `TVSettings.tsx` | TV 设置页面 |

#### 4.2.3 辅助组件

| 组件 | 功能描述 |
|------|---------|
| `Login.tsx` | 登录页面，支持 Emby/Plex 服务器地址、账号密码输入 |
| `SearchBar.tsx` | 搜索栏组件 |
| `SearchResults.tsx` | 搜索结果分页展示，支持按类型分类 |
| `LibrarySelect.tsx` | 媒体库选择器（电影/剧集/音乐等） |
| `FavoritesManager.tsx` | 收藏集合管理页面 |
| `WatchHistoryView.tsx` | 观看历史记录页面 |
| `VideoInfo.tsx` | 视频详情信息面板（标题、简介、评分等） |
| `SubtitleControls.tsx` | 字幕设置（语言、字体、颜色、位置） |
| `SubtitleRenderer.tsx` | 字幕内容渲染层 |
| `HeartAnimation.tsx` | 点赞动画效果 |
| `DeleteConfirmDialog.tsx` | 删除确认对话框 |
| `UpdateNotification.tsx` | 应用更新通知提示 |

### 4.3 服务层 (services/)

服务层负责与 Emby/Plex 媒体服务器的通信，使用**策略模式 + 工厂模式**设计。

| 文件 | 职责说明 | 关键设计 |
|------|---------|---------|
| `MediaClient.ts` | **抽象基类 / 接口定义**，声明媒体客户端应实现的所有方法契约 | 定义 `authenticate()`、`getLibraries()`、`getVideos()`、`search()`、`getPlaybackUrl()` 等抽象方法 |
| `EmbyClient.ts` | **Emby 客户端实现**，封装 Emby REST API | 处理 Emby 认证（用户名/密码/API Key）、媒体库查询、视频列表、播放地址拼接（HLS/直链/转码） |
| `PlexClient.ts` | **Plex 客户端实现**，封装 Plex API | 处理 Plex 认证 Token、Plex 特定的数据结构转换到通用格式 |
| `clientFactory.ts` | **客户端工厂**，根据配置动态创建 Emby 或 Plex 客户端实例 | 读取配置中的 `serverType`，返回对应的 `MediaClient` 实现 |
| `embyService.ts` | **Emby 服务层封装**，提供更便捷的业务级 API | 对底层 EmbyClient 进一步封装，处理缓存、错误重试等横切关注点 |

### 4.4 Hooks 层 (src/hooks/)

自定义 Hooks 是应用状态管理和业务逻辑复用的核心。

| Hook | 功能描述 | 关键 API |
|------|---------|---------|
| `useConfig.ts` | 应用配置管理，包括服务器地址、用户偏好等 | `config`、`updateConfig()`、`resetConfig()` |
| `useDeviceDetection.ts` | 设备类型检测（移动/桌面/TV），用于多端适配 | `isMobile`、`isDesktop`、`isTV`、`deviceType` |
| `useFavorites.ts` | 收藏功能，包括添加/移除收藏、管理收藏集合 | `favorites`、`addFavorite()`、`removeFavorite()` |
| `useGestureControls.ts` | 手势控制逻辑（单击/双击/长按/滑动） | 绑定到视频播放器的手势事件处理 |
| `useImagePreload.ts` | 图片预加载，提升浏览流畅度 | 预加载下一张图片到浏览器缓存 |
| `useLazyImage.ts` | 图片懒加载，基于 IntersectionObserver | 只在可视区域内加载图片 |
| `useLibraries.ts` | 媒体库列表管理 | `libraries`、`currentLibrary`、`switchLibrary()` |
| `useLocalStorageState.ts` | localStorage 状态持久化通用 Hook | 类似 `useState`，但状态自动持久化到浏览器存储 |
| `useSearch.ts` | 搜索功能 Hook，管理搜索关键词、结果分页 | `query`、`results`、`search()`、`loadMore()` |
| `useSmartVideoPreload.ts` | 智能视频预加载，根据网络状况动态调整预加载策略 | `preloadNext()`、`preloadCount` |
| `useSubtitles.ts` | 字幕管理，包括字幕语言切换、样式配置 | `subtitles`、`currentSubtitle`、`subtitleStyle` |
| `useTranslation.ts` | 国际化翻译 Hook，根据当前语言返回翻译文本 | `t()`、`currentLocale`、`setLocale()` |
| `useUIState.ts` | UI 全局状态管理，如暗色模式、全屏状态等 | `uiState`、`toggleTheme()`、`toggleFullscreen()` |
| `useUpdateChecker.ts` | 应用更新检测 | `hasUpdate`、`latestVersion`、`checkUpdate()` |
| `useVideoControls.ts` | 视频播放控制逻辑（播放/暂停/进度/音量） | `isPlaying`、`progress`、`togglePlay()`、`seek()` |
| `useVideoList.ts` | 视频列表数据获取与管理，支持分页 | `videos`、`loadMore()`、`hasMore`、`loading` |
| `useWatchHistory.ts` | 观看历史记录，持久化到 localStorage | `history`、`addToHistory()`、`clearHistory()` |
| `index.ts` | Hooks 统一导出入口，集中管理导出便于引用 | |

### 4.5 工具函数层 (utils/)

| 文件 | 功能描述 | 典型函数 |
|------|---------|---------|
| `device.ts` | 设备检测相关工具函数 | `isMobileDevice()`、`isTVDevice()`、`getScreenSize()` |
| `media.ts` | 媒体相关工具函数 | `formatFileSize()`、`getVideoCodec()`、`extractThumbnail()` |
| `time.ts` | 时间格式化工具 | `formatDuration()`、`formatTimestamp()`、`secondsToHMS()` |
| `index.ts` | 工具函数统一导出入口 | |

### 4.6 国际化层 (src/locales/)

| 文件 | 功能描述 |
|------|---------|
| `index.ts` | i18n 系统入口，注册语言包，提供翻译函数 |
| `en.ts` | 英文翻译键值对 |
| `zh.ts` | 中文翻译键值对 |

---

## 5. 关键类与函数说明

### 5.1 MediaClient 抽象接口（设计核心）

`MediaClient` 定义了所有媒体客户端必须实现的统一接口，是实现 **Emby/Plex 多源兼容** 的关键抽象。

**主要方法契约：**

| 方法 | 说明 | 返回值 |
|------|------|--------|
| `authenticate(serverUrl, credentials)` | 连接并认证到媒体服务器 | `Promise<AuthResult>` |
| `getLibraries()` | 获取可用媒体库列表（电影/剧集/音乐等） | `Promise<Library[]>` |
| `getVideos(libraryId, options?)` | 分页获取指定库中的视频列表 | `Promise<{ items: VideoItem[], total: number }>` |
| `search(query, options?)` | 按关键词搜索视频 | `Promise<VideoItem[]>` |
| `getPlaybackUrl(videoId, options?)` | 获取视频播放地址（直链/HLS/转码） | `Promise<string>` |
| `getSubtitles(videoId)` | 获取视频的字幕轨道列表 | `Promise<SubtitleTrack[]>` |
| `markWatched(videoId)` | 标记视频为已观看 | `Promise<void>` |
| `getWatchProgress(videoId)` | 获取视频播放进度 | `Promise<number>` (秒) |
| `saveWatchProgress(videoId, seconds)` | 保存播放进度 | `Promise<void>` |

### 5.2 clientFactory 工厂函数

**核心逻辑伪代码（设计说明）：**

```typescript
// 根据配置动态创建对应类型的媒体客户端
// 参数 config 包含: serverType ('emby' | 'plex'), serverUrl, credentials
// 返回实现 MediaClient 接口的具体实例
function createMediaClient(config: Config): MediaClient {
  switch (config.serverType) {
    case 'emby':
      return new EmbyClient(config.serverUrl, config.credentials);
    case 'plex':
      return new PlexClient(config.serverUrl, config.credentials);
    default:
      throw new Error('Unsupported server type');
  }
}
```

**设计意图：** 客户端代码通过工厂获取实例，不需要知道底层是 Emby 还是 Plex，完全面向接口编程，便于未来支持更多媒体服务器。

### 5.3 VideoFeed.tsx 核心交互逻辑

**核心流程：**

1. 使用 `useVideoList()` Hook 加载初始视频数据（第一页）
2. 渲染为**垂直滚动容器**，每个视频占满整个视口
3. 监听滚动事件，当接近当前视频底部时：
   - 调用 `useSmartVideoPreload()` 预加载下一个视频
   - 调用 `useVideoList().loadMore()` 加载下一页数据
4. 视频切换时自动暂停上一个、播放下一个

### 5.4 useVideoControls.ts 视频控制 Hook

**主要状态与方法：**

| 项目 | 类型/签名 | 说明 |
|------|----------|------|
| `isPlaying` | `boolean` | 当前是否在播放 |
| `progress` | `number` (0-100) | 播放进度百分比 |
| `currentTime` | `number` (秒) | 当前播放时间 |
| `duration` | `number` (秒) | 视频总时长 |
| `volume` | `number` (0-1) | 音量 |
| `togglePlay()` | `() => void` | 切换播放/暂停 |
| `seek(seconds)` | `(n) => void` | 跳转到指定秒数 |
| `setVolume(v)` | `(0-1) => void` | 设置音量 |
| `setPlaybackRate(rate)` | `(number) => void` | 设置倍速 |

### 5.5 useLocalStorageState.ts 通用持久化 Hook

**核心 API 设计：**

```
useLocalStorageState<T>(key: string, defaultValue: T): [T, (v: T) => void]
```

与 `useState` 用法完全一致，但状态变化自动同步到 `localStorage`，页面刷新后保留。广泛应用于：配置、收藏、观看历史、UI 偏好设置等场景。

---

## 6. 依赖关系图

### 6.1 模块依赖流向

```
                   ┌─────────────────────┐
                   │      App.tsx        │
                   │  (根组件 / 路由分发)│
                   └─────────┬───────────┘
                             │
              ┌──────────────┼──────────────┐
              ▼              ▼              ▼
        ┌──────────┐  ┌────────────┐  ┌──────────┐
        │ Mobile   │  │ Standard   │  │ TV       │
        │ Root     │  │ Root       │  │ Root     │
        └────┬─────┘  └──────┬─────┘  └─────┬────┘
             │                │               │
             ▼                ▼               ▼
        ┌─────────────────────────────────────────┐
        │           组件层 (components)            │
        │  VideoFeed / VideoPlayer / Search / ...  │
        └──────────────┬──────────────────────────┘
                       │
                       ▼
        ┌─────────────────────────────────┐
        │        Hooks 层 (src/hooks)      │
        │  useVideoList / useFavorites /   │
        │  useConfig / useSearch / ...     │
        └──────┬──────────────────┬─────────┘
               │                  │
               ▼                  ▼
        ┌─────────────┐    ┌───────────────┐
        │  utils/     │    │ services/     │
        │  (工具函数) │    │ (媒体客户端)  │
        └─────────────┘    └────┬──────────┘
                                │
                                ▼
                      ┌──────────────────────┐
                      │  MediaClient (接口)  │
                      └─────┬──────────┬─────┘
                            │          │
                            ▼          ▼
                      ┌─────────┐  ┌──────────┐
                      │ Emby    │  │ Plex     │
                      │ Client  │  │ Client   │
                      └────┬────┘  └────┬─────┘
                           │             │
                           ▼             ▼
                      ┌──────────────┐ ┌──────────────┐
                      │  Emby Server │ │ Plex Server  │
                      │  (REST API)  │ │  (REST API)  │
                      └──────────────┘ └──────────────┘
```

### 6.2 关键 NPM 依赖

| 依赖包 | 版本范围 | 用途 |
|-------|---------|------|
| `react` | ^18.x | React 核心库 |
| `react-dom` | ^18.x | React DOM 渲染 |
| `typescript` | ^5.x | TypeScript 编译器 |
| `vite` | ^5.x | 构建工具与开发服务器 |
| `tailwindcss` | ^3.x | CSS 框架，原子化样式 |
| `@capacitor/core` | ^6.x | 跨平台移动应用框架 |
| `lucide-react` | ^0.x | React 图标库 |

### 6.3 Flutter 版关键依赖（规划中）

| 依赖 | 用途 |
|------|------|
| `flutter_riverpod` | Riverpod 状态管理 |
| `go_router` | 声明式路由 |
| `dio` | HTTP 网络请求 |
| `media_kit` | 高性能视频播放 |
| `video_player` | Flutter 官方视频播放 |
| `shared_preferences` | 本地键值存储 |
| `cached_network_image` | 图片缓存 |

### 6.4 FastAPI 后端关键依赖（规划中）

| 依赖 | 用途 |
|------|------|
| `fastapi` | Web 框架 |
| `uvicorn` | ASGI 服务器 |
| `httpx` | 异步 HTTP 客户端（调用 Emby/Plex API） |
| `pydantic` | 数据验证与序列化 |
| `python-multipart` | 文件上传支持 |
| `redis-py` (可选) | Redis 缓存客户端 |

---

## 7. 项目运行与构建方式

### 7.1 React 版运行方式

#### 环境要求

- **Node.js**: v14 或更高版本（推荐 v18+）
- **npm** 或 **yarn**
- **Git**
- **Android Studio**（如需构建 Android 应用）

#### 本地开发

```bash
# 1. 克隆仓库
git clone <repository-url>
cd embytok

# 2. 安装依赖
npm install

# 3. 启动开发服务器
npm run dev
```

开发服务器将在 **http://localhost:5173** 启动（默认端口）。

#### 生产构建

```bash
# 构建生产版本（输出到 dist/ 目录）
npm run build

# 本地预览构建产物
npm run preview

# 完整 TypeScript 类型检查
tsc --noEmit
```

#### Android 应用构建

```bash
# 添加 Android 平台（首次）
npm run cap:add

# 同步 Web 构建产物到 Android 项目
npm run cap:sync

# 构建 Android APK
npm run build:android
```

### 7.2 Flutter 版运行方式（规划中）

#### 环境要求

- **Flutter SDK** 3.x
- **Dart** 3.x
- **Python** 3.11+
- **Emby** 或 **Plex** 媒体服务器

#### 完整启动流程

```bash
# 克隆仓库
git clone https://github.com/1525745393/EmbyTok-Flutter.git
cd EmbyTok-Flutter

# ===== 后端启动 =====
cd backend
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000

# ===== Flutter 客户端启动 =====
cd ../frontend
flutter pub get
flutter run         # 运行到已连接的设备 / 模拟器
```

#### 配置 Emby 服务器

在应用登录页面输入三项配置：

1. **Emby 服务器地址**（如 `http://192.168.1.100:8096`）
2. **用户名和密码**
3. **后端代理地址**（如 `http://localhost:8000`，即 FastAPI 服务地址）

### 7.3 Docker 部署（React 版）

```bash
# 使用 Docker Compose 一键部署
docker-compose up -d

# 或仅构建 Web 镜像
docker build -t embytok .
docker run -p 80:80 embytok
```

Nginx 作为反向代理托管构建后的静态资源。

---

## 8. 核心数据结构

### 8.1 VideoItem（视频项）

```typescript
interface VideoItem {
  id: string;              // 视频唯一 ID
  title: string;           // 标题
  description?: string;    // 简介
  thumbnailUrl?: string;   // 缩略图地址
  duration?: number;       // 时长（秒）
  libraryId: string;       // 所属媒体库 ID
  type: 'movie' | 'episode' | 'music' | 'other';
  year?: number;           // 年份
  rating?: number;         // 评分
  genres?: string[];       // 类型标签
  playbackUrl?: string;    // 播放地址（由 MediaClient 填充）
  subtitles?: SubtitleTrack[];
}
```

### 8.2 Library（媒体库）

```typescript
interface Library {
  id: string;
  name: string;            // 库名称（如 "电影"、"剧集"）
  type: string;            // 库类型
  itemCount?: number;      // 项目数量
  coverImageUrl?: string;  // 封面图
}
```

### 8.3 Config（应用配置）

```typescript
interface Config {
  serverType: 'emby' | 'plex';
  serverUrl: string;       // 媒体服务器地址
  proxyUrl?: string;       // 后端代理地址（Flutter 版使用）
  username: string;
  password: string;        // 建议加密存储，不持久化明文
  apiKey?: string;         // Emby/Plex API Key（可选替代密码）
  locale: 'zh' | 'en';
  theme: 'light' | 'dark';
  preloadCount: number;    // 预加载视频数量
  subtitleEnabled: boolean;
  subtitleLanguage?: string;
}
```

---

## 9. 设计要点与最佳实践

### 9.1 架构设计原则

- **面向接口编程**：`MediaClient` 抽象层隔离了不同媒体服务器的差异，上层组件无感知底层实现
- **工厂模式**：`clientFactory` 根据配置动态创建客户端实例，解耦使用方与具体实现
- **Hooks 优先**：业务逻辑通过自定义 Hooks 抽取，保持组件简洁、可测试
- **状态集中管理**：`useLocalStorageState` + 各业务 Hook 构成轻量状态管理体系，避免引入 Redux 等重型框架

### 9.2 性能优化要点

| 优化点 | 实现方式 | 预期效果 |
|--------|---------|---------|
| **视频预加载** | `useSmartVideoPreload` 根据网络与滚动位置提前加载后续视频 | 视频切换零等待 |
| **图片懒加载** | `useLazyImage` 基于 IntersectionObserver，仅加载可视区域图片 | 降低首屏带宽占用 |
| **图片预加载** | `useImagePreload` 提前加载下一张图到缓存 | 滚动时图片无闪烁 |
| **骨架屏** | `VideoSkeleton` 在数据加载时展示占位结构 | 提升感知速度 |
| **状态持久化** | `useLocalStorageState` 避免重复请求配置类数据 | 提升二次启动速度 |
| **避免重复计算** | Hooks 中使用 `useMemo` / `useCallback` 缓存计算结果 | 减少不必要渲染 |

### 9.3 代码规范

- **TypeScript 优先**：全量使用 TypeScript，禁止 `any` 类型（明确标注的例外除外）
- **函数单一职责**：每个函数/组件只做一件事，便于测试与维护
- **小步提交**：每次只做一个小改动，然后测试，保持代码随时可工作
- **注释说明**：关键逻辑添加中文注释，解释"为什么"而非"做什么"
- **命名语义化**：变量/函数/组件使用有意义的名称，避免缩写（除通用的 `i`/`j` 等）

### 9.4 多端适配策略

通过 `useDeviceDetection` Hook 在应用启动时识别设备类型，`App.tsx` 根据识别结果渲染不同的根组件：

| 设备类型 | 根组件 | 布局策略 |
|---------|--------|---------|
| 移动端 | `MobileRoot.tsx` | 竖屏视频流，手势优先 |
| 桌面端 | `StandardRoot.tsx` | 视频网格/列表，鼠标+键盘 |
| TV | `TVRoot.tsx` | 大尺寸网格，遥控器焦点导航 |

---

## 10. 功能路线图

| 模块 | 状态 | 说明 |
|------|------|------|
| 项目架构设计 | ✅ 已完成 | 三层架构（客户端 / FastAPI / Emby） |
| FastAPI 后端 - Emby API 封装 | ⏳ 进行中 | 封装 Emby REST API 到统一接口 |
| FastAPI 后端 - Plex API 封装 | ⏳ 规划中 | 封装 Plex API |
| Flutter 前端 - 登录页面 | ⏳ 规划中 | 服务器地址与账号配置 |
| Flutter 前端 - 竖屏视频滑动 | ⏳ 规划中 | 核心 TikTok 式体验 |
| Flutter 前端 - 视频播放器 | ⏳ 规划中 | 原生播放组件集成 |
| Flutter 前端 - 手势控制 | ⏳ 规划中 | 单击/双击/长按/滑动 |
| Flutter 前端 - 收藏功能 | ⏳ 规划中 | 收藏集合与同步 |
| Flutter 前端 - 搜索功能 | ⏳ 规划中 | 分页搜索与分类展示 |
| Flutter 前端 - 字幕支持 | ⏳ 规划中 | 多语言字幕渲染 |
| Flutter 前端 - TV 模式适配 | ⏳ 规划中 | 遥控器导航优化 |
| Docker 部署配置 | ⏳ 规划中 | 容器化部署方案 |
| CI/CD 工作流 | ⏳ 规划中 | 自动化构建与发布 |

---

## 11. 相关文档索引

| 文档 | 说明 |
|------|------|
| `README.md` | 项目主文档与快速入门 |
| `README_CN.md` | 中文文档 |
| `AGENTS.md` | AI 代理角色与协作流程说明 |
| `CLAUDE.md` | Claude AI 助手使用指南（开发原则、命令、策略） |
| `CLAUDE.local.md` | 本地开发环境 Claude 配置指南（目录结构详解） |
| `ANDROID_BUILD.md` | Android 应用构建指南 |
| `SYNOLOGY_DEPLOY.md` | Synology NAS 部署指南 |
| `CODE_REVIEW_CHECKLIST.md` | 代码审查检查清单 |
| `CODE_REVIEW_PROCESS.md` | 代码审查流程说明 |
| `CODE_REVIEW_STANDARDS.md` | 代码审查标准 |
| `本地构建指南.md` | 本地构建详细指南（中文） |

---

## 12. 相关项目

- **[EmbyTok-ai](https://github.com/1525745393/EmbyTok-ai)** — 原版 React Web 实现（本 Wiki 所描述的版本）
- **EmbyTok-Flutter** — 本仓库，Flutter + FastAPI 跨平台重构版本

---

*文档版本：v1.0  |  适用范围：EmbyTok 全项目  |  最后更新：基于仓库当前架构设计生成*
