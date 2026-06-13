# EmbyTok-Flutter

> 为 Emby 媒体服务器设计的竖屏视频浏览客户端，直接连接 Emby 服务器，提供类似 TikTok 的沉浸式滑动体验。

[![Flutter 3.x](https://img.shields.io/badge/Flutter-3.x-0175C2?logo=flutter)](https://flutter.dev)
[![Dart 3.x](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)](https://dart.dev)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

---

## 📚 文档导航

> 完整的文档体系已迁移到 `docs/` 目录，按读者角色推荐阅读路径如下：

| 你是…… | 推荐阅读路径 | 核心文档 |
|--------|-------------|---------|
| 👤 **普通用户** | 📖 先了解基本用法 → 遇到问题看故障排查 | [用户使用指南](docs/user-guide.md) → [故障排查指南](docs/troubleshooting.md) |
| 👨‍💻 **开发者** | 🏗️ 先理解整体架构 → 搭建开发环境 → 看代码规范 | [架构总览](docs/architecture.md) → [开发者指南](docs/developer-guide.md) → [API 参考](docs/api-reference.md) → [故障排查指南](docs/troubleshooting.md) |
| 🛠 **部署工程师** | 🚀 看部署方案 → 运维命令 → 故障排查 | [部署指南](docs/deployment.md) → [故障排查指南](docs/troubleshooting.md) |

**📑 文档索引**：[docs/index.md](docs/index.md)（所有文档的入口）

---

## 项目简介

EmbyTok-Flutter 是一款跨平台的 **Emby 原生**客户端，将海量电影 / 剧集 / 音乐视频以**上下滑动的竖屏信息流**呈现，结合**手势交互、倍速播放、字幕渲染、智能搜索、收藏与历史**等核心能力，让用户可以在移动端、桌面端获得流畅的观影体验。

**不需要任何额外部署的后端或中间层** —— 安装 App 后直接填入你的 Emby 服务器地址、用户名、密码即可使用。

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
| **网络请求** | Dio（封装为 `EmbytokService`，直连 Emby API） |
| **视频播放** | video_player（全平台） |
| **本地持久化** | shared_preferences（搜索历史 / 观看历史 / 用户设置） |
| **图片缓存** | cached_network_image |
| **国际化** | intl |
| **认证方式** | Emby `AccessToken`（登录接口换取 Token，后续请求通过 `X-Emby-Token` 鉴权） |

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
│   │       └── utils.dart
│   │           ├── constants.dart
│   │           ├── formatters.dart
│   │           └── utils.dart
│   ├── pubspec.yaml                 # 依赖清单
│   └── README.md                    # 前端开发指南
├── backend/                          # （预留扩展：可选 FastAPI 中间层
│   └── main.py                   # 未来扩展用
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
         (HTTP / X-Emby-Token)
                 │
        ┌────────┴─────────┐
        │   Emby / Jellyfin │      媒体库 & 转码
        └──────────────────┘

  【可选扩展】 ────┐
                    │   FastAPI 中间层（预留，可插入缓存/多源/统计等）
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
- **iOS** (macOS 开发环境) / **Android** / **macOS** / **Windows** / **Linux** / **Web**
- **Emby Server** 4.7+ 或 **Jellyfin** 10.8+（自托管）
- **Python**: >= 3.11（仅在需要扩展后端中间层时）
- **Docker**（可选，用于后端镜像构建 & 部署）

### 一行命令启动（推荐）

项目根目录提供 `Makefile`，统一所有开发命令：

```bash
# 1. 安装依赖（Flutter）
make setup-frontend

# 2. 运行 Flutter App
cd frontend && flutter run
```

> ✅ **不需要额外启动任何后端服务**：App 直连你的 Emby 服务器。
> （`backend/` 目录中的 FastAPI 项目仅作为预留扩展）

### 常用命令速查表

| 命令 | 说明 |
| --- | --- |
| `make help` | 显示所有可用命令 |
| `make setup-frontend` | 安装 Flutter 依赖（仅 App 开发） |
| `make run-frontend` | 启动 Flutter 应用 |
| `make lint` | 代码质量检查（flutter analyze） |
| `make build-apk` | 构建 Android APK（Release） |
| `make clean` | 清理构建产物 |

| **可选：中间层相关命令** | |
| --- | --- |
| `make setup` | 安装 Flutter + Python 全部依赖 |
| `make run-all` | 同时启动前后端服务 |
| `make run-backend` | 启动后端服务（Docker） |
| `make test-all` | 运行 Flutter 和 Python 测试 |
| `make build-docker` | 构建后端 Docker 镜像 |

---

## 发布配置

在触发自动发布前，需要在 GitHub 仓库中配置以下 Secrets：

### Android 签名（必需）

| Secret | 用途 |
|--------|------|
| `ANDROID_KEYSTORE` | keystore 文件的 base64 编码 |
| `ANDROID_KEYSTORE_PWD` | keystore 密码 |
| `ANDROID_KEY_ALIAS` | key 别名（默认 `embbytok`） |
| `ANDROID_KEY_PWD` | key 密码 |

### Docker 镜像（可选——仅在启用中间层时需要）

| Secret | 用途 |
|--------|------|
| `DOCKER_USERNAME` | Docker Hub 用户名 |
| `DOCKER_PASSWORD` | Docker Hub Access Token |
| `DOCKER_REGISTRY` | 镜像仓库（可选，默认 `docker.io`） |

详细配置步骤请参阅 [.github/SECRETS.md](.github/SECRETS.md)。

### 触发发布

- **自动触发**：推送以 `v` 开头的 git tag（如 `git tag v1.0.0 && git push --tags`）
- **手动触发**：在 Actions 页面选择对应工作流 → Run workflow

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

# 2. 安装 Flutter 依赖（核心）
cd frontend && flutter pub get && cd ..

# 3. 运行 Flutter App
cd frontend && flutter run      # 默认连接你的 Emby 服务器
```

**可选——启用中间层时使用：**

```bash
make setup        # 安装 Flutter + Python
make run-all      # 同时启动前后端
make test-all     # 统一测试
make build-all    # 构建 APK + Docker 镜像
```

### 手动启动（不使用 Make）

```bash
# Flutter App（核心）
cd frontend
flutter pub get
flutter devices          # 查看可用设备
flutter run              # 启动到默认设备
flutter run -d chrome    # Web 调试
```

> 💡 **启动后在 App 中填入你的 Emby 服务器地址 + 用户名 + 密码即可**

---

**可选——启用中间层时的手动启动：**

```bash
cd backend
python -m venv .venv
source .venv/bin/activate          # Windows: .venv\Scripts\activate
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000
```



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
