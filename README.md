# EmbyTok-Flutter

> 为 Emby 媒体服务器设计的竖屏视频浏览客户端，提供类似 TikTok 的体验，让用户能够以更现代、便捷的方式浏览个人媒体库。

## 项目简介

EmbyTok-Flutter 是 EmbyTok 项目的跨平台重构版本，采用 **Flutter + FastAPI + Emby API** 技术栈，旨在提供比原 React Web 版本更流畅的原生移动端体验。

### 为什么选择 Flutter + FastAPI？

| 维度 | 原版 (React + Vite) | 新版 (Flutter + FastAPI) |
|------|----------------------|--------------------------|
| **前端框架** | React 18 (Web) | Flutter (跨平台原生) |
| **后端服务** | 无独立后端，前端直连 Emby | FastAPI 中间层，统一 API 抽象 |
| **平台支持** | Web / PWA / Android (Capacitor) | iOS / Android / Web / Desktop |
| **视频播放** | HTML5 Video | 原生播放器，更低延迟 |
| **手势交互** | Web Touch Events | 原生手势识别，更丝滑 |
| **性能表现** | 受限于 WebView | 接近原生 60fps |

### 核心体验

- **TikTok 式竖屏滑动** — 上下滑动切换视频，沉浸式全屏浏览
- **智能预加载** — 预加载后续视频，切换无等待
- **多源兼容** — 通过 FastAPI 统一封装，同时支持 Emby 和 Plex
- **手势控制** — 单击暂停、双击收藏、长按倍速、滑动快进
- **收藏管理** — 创建收藏集合，跨设备同步
- **字幕支持** — 多语言字幕，可调字体/颜色/位置
- **搜索功能** — 分页搜索，按类型分类展示

## 技术架构

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Flutter App │────▶│   FastAPI   │────▶│  Emby API   │
│  (客户端)    │◀────│  (中间层)   │◀────│  (媒体服务器) │
└─────────────┘     └─────────────┘     └─────────────┘
```

### 前端：Flutter

- **UI 框架**: Flutter 3.x + Dart
- **状态管理**: Riverpod
- **视频播放**: media_kit / video_player
- **手势交互**: 原生 GestureDetector
- **路由**: GoRouter
- **网络请求**: Dio

### 后端：FastAPI

- **框架**: FastAPI (Python 3.11+)
- **异步**: asyncio + httpx
- **媒体抽象**: 统一 Emby / Plex API 接口
- **缓存**: Redis (可选)
- **部署**: Docker / Uvicorn

### 媒体服务器：Emby API

- **认证**: 用户名/密码 / API Key
- **媒体库**: 电影、剧集、音乐、图片
- **转码**: HLS / 直接播放 / 自适应码率
- **收藏**: 播放列表模拟收藏系统

## 快速开始

### 环境要求

- Flutter SDK 3.x
- Dart 3.x
- Python 3.11+
- Emby 或 Plex 媒体服务器

### 安装与运行

```bash
# 克隆仓库
git clone https://github.com/1525745393/EmbyTok-Flutter.git
cd EmbyTok-Flutter

# 安装 Flutter 依赖
flutter pub get

# 启动 FastAPI 后端
cd backend
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000

# 启动 Flutter 客户端
cd frontend
flutter run
```

### 配置 Emby 服务器

在应用登录页面输入：
1. Emby 服务器地址（如 `http://192.168.1.100:8096`）
2. 用户名和密码
3. 后端代理地址（如 `http://localhost:8000`）

## 项目结构

```
EmbyTok-Flutter/
├── frontend/                # Flutter 客户端
│   ├── lib/
│   │   ├── main.dart       # 应用入口
│   │   ├── app.dart        # 根组件
│   │   ├── models/         # 数据模型
│   │   ├── views/          # 页面视图
│   │   ├── widgets/        # UI 组件
│   │   ├── services/       # API 服务
│   │   ├── providers/      # 状态管理
│   │   └── utils/          # 工具函数
│   ├── pubspec.yaml
│   └── ...
├── backend/                 # FastAPI 后端
│   ├── main.py             # 应用入口
│   ├── routers/            # API 路由
│   ├── services/           # 业务逻辑
│   ├── models/             # 数据模型
│   ├── clients/            # Emby/Plex 客户端
│   └── requirements.txt
├── docker-compose.yml
├── Dockerfile
└── README.md
```

## 功能路线图

- [x] 项目架构设计
- [ ] FastAPI 后端 - Emby API 封装
- [ ] FastAPI 后端 - Plex API 封装
- [ ] Flutter 前端 - 登录页面
- [ ] Flutter 前端 - 竖屏视频滑动
- [ ] Flutter 前端 - 视频播放器
- [ ] Flutter 前端 - 手势控制
- [ ] Flutter 前端 - 收藏功能
- [ ] Flutter 前端 - 搜索功能
- [ ] Flutter 前端 - 字幕支持
- [ ] Flutter 前端 - TV 模式适配
- [ ] Docker 部署配置
- [ ] CI/CD 工作流

## 相关项目

- [EmbyTok-ai](https://github.com/1525745393/EmbyTok-ai) — 原版 React Web 实现

## 许可证

MIT License
