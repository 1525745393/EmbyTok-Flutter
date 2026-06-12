# EmbyTok-Flutter

> 为 Emby 媒体服务器设计的竖屏视频浏览客户端，提供类似 TikTok 的沉浸式滑动体验。

[![Flutter 3.x](https://img.shields.io/badge/Flutter-3.x-0175C2?logo=flutter)](https://flutter.dev)
[![Dart 3.x](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)](https://dart.dev)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

---

## 项目简介

EmbyTok-Flutter 是一款跨平台的 Emby 媒体库客户端，将海量电影 / 剧集 / 音乐视频以**上下滑动的竖屏信息流**呈现，结合**手势交互、倍速播放、字幕渲染、智能搜索、收藏与历史**等核心能力，让用户可以在移动端、桌面端获得流畅的观影体验。

### 核心体验

- 🎞️ **TikTok 式竖屏滑动** — 上下滑动切换视频，全屏沉浸浏览
- 👆 **丰富手势交互** — 单击暂停、双击收藏并爱心动画、长按倍速、水平拖拽进度
- 🔍 **实时搜索** — 300ms 防抖、搜索历史本地缓存、结果快速跳转播放
- ❤️ **收藏管理** — 支持收藏列表管理、左滑删除、快速播放
- 📜 **字幕支持** — SRT 格式解析、字号 / 颜色 / 位置可调、多语言轨道切换
- ⚡ **倍速播放** — 0.5x – 2.0x 可选，长按临时加速
- 🕘 **观看历史** — 记录进度百分比、已看时长、自动记录

---

## 技术栈

| 层 | 技术 |
| --- | --- |
| **UI 框架** | Flutter 3.x + Dart 3 (null safety / patterns / records) |
| **状态管理** | flutter_riverpod 2.x（全局 Provider + StateNotifier） |
| **路由导航** | Material PageRoute（原生 Navigator） |
| **网络请求** | Dio（封装为 `EmbytokService`） |
| **视频播放** | video_player（全平台） |
| **本地持久化** | shared_preferences（搜索历史 / 观看历史 / 用户设置） |
| **图片缓存** | cached_network_image |
| **国际化** | intl |
| **后端服务** | Emby API / FastAPI（可选中间层） |

---

## 功能清单

### ✅ 已实现（v0.1.x）

- 竖屏视频流 (`feed_view.dart`)
- 视频播放器封装 (`video_player_widget.dart`)
- 播放页信息栏 / 操作按钮 / 类型标签 (`video_page_item.dart`)
- 手势覆盖层：单击 / 双击 / 长按 / 水平拖拽 (`gesture_overlay.dart`)
- 双击爱心动画 (`heart_animation.dart` / `_FlyingHeart`)
- 搜索页 + 300ms 防抖 + 本地搜索历史 (`search_view.dart`)
- 收藏页：列表 + 左滑删除 + 点击播放 (`favorites_view.dart`)
- 观看历史：进度条 + 时间 + 跳转 (`history_view.dart`)
- 字幕渲染器 + 控制面板 (`subtitle_renderer.dart` / `subtitle_controls.dart`)
- 设置页：主题 / 默认倍速 / 字幕 / 缓存 / 用户 / 退出登录 (`settings_view.dart`)
- 统一 Provider 状态管理 (`providers/providers.dart`)

### 🚀 规划中

- GoRouter 命名路由与深层链接
- 剧集/季 切换的多段式播放列表
- Emby Jellyfin / Plex 多源支持
- 离线缓存下载
- 投屏 (Chromecast / DLNA)
- 媒体库多语言 & 字幕 AI 翻译
- TV 模式适配 (遥控器方向键)

---

## 目录结构

```
EmbyTok-Flutter/
├── frontend/                         # Flutter 客户端
│   ├── lib/
│   │   ├── main.dart                # 应用入口（ProviderScope）
│   │   ├── models/                  # 数据模型
│   │   │   ├── media_item.dart
│   │   │   ├── subtitle_track.dart
│   │   │   ├── watch_history_item.dart
│   │   │   └── user.dart
│   │   ├── providers/               # 状态管理（Riverpod）
│   │   │   ├── providers.dart          # 统一导出
│   │   │   ├── auth_provider.dart
│   │   │   ├── library_provider.dart
│   │   │   ├── video_list_provider.dart
│   │   │   ├── favorites_provider.dart
│   │   │   ├── search_provider.dart
│   │   │   ├── watch_history_provider.dart
│   │   │   ├── theme_provider.dart
│   │   │   ├── subtitle_settings_provider.dart
│   │   │   ├── user_preferences_provider.dart
│   │   │   └── video_playback_controller.dart
│   │   ├── services/                # 后端 / API 封装
│   │   │   └── embbytok_service.dart
│   │   ├── views/                   # 页面视图
│   │   │   ├── feed_view.dart         # 视频流
│   │   │   ├── search_view.dart       # 搜索
│   │   │   ├── favorites_view.dart    # 收藏
│   │   │   ├── history_view.dart      # 观看历史
│   │   │   ├── settings_view.dart     # 设置
│   │   │   └── login_view.dart        # 登录
│   │   ├── widgets/                 # UI 组件
│   │   │   ├── video_page_item.dart
│   │   │   ├── video_player_widget.dart
│   │   │   ├── gesture_overlay.dart
│   │   │   ├── heart_animation.dart
│   │   │   ├── subtitle_renderer.dart
│   │   │   └── subtitle_controls.dart
│   │   └── utils/                   # 工具与常量
│   │       ├── constants.dart
│   │       ├── formatters.dart
│   │       └── utils.dart
│   ├── pubspec.yaml                 # 依赖清单
│   └── README.md                    # 前端开发指南
├── backend/                          # FastAPI 中间层（可选）
│   └── main.py
├── docker-compose.yml
└── README.md                        # 本文档
```

---

## 架构设计总览

```
────────────────────────────────────────────────────────────
        ┌──────────────────┐
        │     Flutter      │      Widgets
        │                  │      Views
        │  (UI & 交互层)   │      Providers
        └────────▲─────────┘
                 │
          ref.watch / ref.read
                 │
        ┌────────┴─────────┐
        │ Riverpod State   │      — authProvider
        │ Notifiers        │      — favoritesProvider
        │  (状态管理层)     │      — searchProvider
        └────────▲─────────┘      — watchHistoryProvider
                 │                  — themeModeProvider
            async / await           — ...
                 │
        ┌────────┴─────────┐
        │ EmbytokService   │      Dio HTTP 客户端
        │ (API Service层)  │      Emby API 抽象
        └────────▲─────────┘
                 │
         (HTTP / WebSocket)
                 │
        ┌────────┴─────────┐
        │   FastAPI 中间层  │      统一鉴权、缓存、跨源
        └────────▲─────────┘
                 │
        ┌────────┴─────────┐
        │   Emby / Jellyfin │      媒体库 & 转码
        └──────────────────┘
────────────────────────────────────────────────────────────
```

**设计原则：**

1. **分层清晰**：`models` ↔ `services` ↔ `providers` ↔ `widgets/views`，各层单向依赖
2. **Provider 单一职责**：每个 Provider 只负责一个领域（收藏、搜索、主题……）
3. **乐观更新优先**：favoritesProvider 等先更新本地 UI，异步确认后端
4. **本地持久化**：搜索历史、观看历史、用户偏好等使用 `shared_preferences` JSON 化存储
5. **UI 状态三态**：每个列表页处理 `isLoading / error / data` 三种视觉状态

---

## 快速开始

[![CI 状态](https://github.com/1525745393/EmbyTok-Flutter/actions/workflows/ci.yml/badge.svg)](https://github.com/1525745393/EmbyTok-Flutter/actions)

### 环境要求

- **Flutter SDK**: >= 3.10.0
- **Dart SDK**: >= 3.0.0 (null safety)
- **Python**: >= 3.11（后端中间层）
- **Docker**（可选，用于后端镜像构建 & 部署）
- **iOS** (macOS 开发环境) / **Android** / **macOS** / **Windows** / **Linux** / **Web**
- **Emby Server** 4.7+ 或 **Jellyfin** 10.8+（自托管）

### 一行命令启动（推荐）

项目根目录提供 `Makefile`，统一所有开发命令：

```bash
# 1. 安装依赖（Flutter + Python）
make setup

# 2. 同时启动前后端
make run-all
```

### 常用命令速查表

| 命令 | 说明 |
| --- | --- |
| `make help` | 显示所有可用命令 |
| `make setup` | 安装 Flutter 和 Python 依赖 |
| `make run-all` | 同时启动前后端服务 |
| `make run-backend` | 启动后端服务（Docker） |
| `make run-frontend` | 启动 Flutter 应用 |
| `make test-all` | 运行 Flutter 和 Python 测试 |
| `make lint` | 代码质量检查（flutter analyze） |
| `make build-apk` | 构建 Android APK（Release） |
| `make build-docker` | 构建后端 Docker 镜像 |
| `make clean` | 清理构建产物 |

也可使用 `scripts/` 下的 Shell 脚本：

```bash
bash scripts/setup.sh       # 环境检查与依赖安装
bash scripts/run-all.sh     # 一键启动前后端
bash scripts/run-tests.sh   # 统一测试执行
bash scripts/build-all.sh   # 全量构建（APK + Docker 镜像）
bash scripts/docker-push.sh # 镜像推送（需配置仓库账号）
```

### 标准流程（分步骤）

```bash
# 1. 克隆仓库
git clone https://github.com/1525745393/EmbyTok-Flutter.git
cd EmbyTok-Flutter

# 2. 安装依赖
make setup
# 或手动：
#   cd frontend && flutter pub get
#   cd ../backend && pip install -r requirements.txt

# 3. 运行测试
make test-all

# 4. 启动应用
make run-all
# 或分别启动：
#   make run-backend   # 后端（http://localhost:8000）
#   make run-frontend  # Flutter 应用
```

### 手动启动（不使用 Make）

```bash
# 前端
cd frontend
flutter pub get
flutter devices          # 查看可用设备
flutter run              # 启动到默认设备
flutter run -d chrome    # Web 调试

# 后端（可选，使用 EmbyTok 中间层）
cd backend
python -m venv .venv
source .venv/bin/activate          # Windows: .venv\Scripts\activate
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000
```

也可直接连接已有的 Emby 服务器地址，无需启动中间层。

---

## Docker 部署

### 构建前端镜像（Web）

```bash
cd frontend
flutter build web --release
docker build -t embbytok-flutter-web:latest .
docker run -p 8080:80 embbytok-flutter-web:latest
```

### docker-compose 完整链路

```yaml
version: '3.8'

services:
  embby:
    image: emby/embyserver:latest
    ports:
      - '8096:8096'
    volumes:
      - ./media:/media
      - ./config:/config
    restart: unless-stopped

  backend:
    image: embbytok-backend:latest
    ports:
      - '8000:8000'
    environment:
      EMBY_SERVER_URL: http://embby:8096
    restart: unless-stopped

  web:
    image: embbytok-flutter-web:latest
    ports:
      - '8080:80'
    restart: unless-stopped
```

---

## 贡献指南

1. **Fork 本仓库** 并克隆到本地
2. 新建分支：`git checkout -b feat/xxx` / `fix/xxx`
3. 提交代码：遵循 [Conventional Commits](https://www.conventionalcommits.org) 规范
4. 执行静态检查：

   ```bash
   flutter analyze
   flutter test
   ```

5. 提交 Pull Request，描述改动与截图

### 代码风格约定

- 使用 Dart 3 特性：`null safety`、`patterns`、`records`
- Widget 拆分粒度：一个 UI 块一个私有类，避免长方法
- Provider 命名：`xxxProvider`（顶层） / `XxxNotifier`（状态机）
- 中文 UI 文案、英文注释、英文类名/变量名
- 所有 `Future` 必须包在 `try/catch` 中，错误以中文提示

---

## 许可证

MIT License © 2024 EmbyTok-Flutter Contributors

See [LICENSE](LICENSE) for details.
