# 📚 EmbyTok-Flutter 文档索引

> 本文档是所有技术文档的入口。按读者角色与需求场景分类，便于快速找到所需文档。

---

## 🗂 文档目录结构

```
docs/
├── index.md                    # 📌 本文件（文档导航入口）
│
├── 用户指南（面向终端用户）
│   └── user-guide.md          # 安装、配置、使用教程
│
├── 开发指南（面向开发者）
│   ├── architecture.md         # 三层架构与核心模块说明
│   ├── api-reference.md       # 后端 FastAPI 接口参考
│   ├── developer-guide.md     # 开发环境、代码规范、提交流程
│   └── troubleshooting.md     # 常见问题与解决方案（开发与部署问题）
│
└── 部署与运维（面向运维）
    └── deployment.md          # Docker、裸机、Nginx 等部署方案
```

同时，项目根目录下还有以下重要文档：

| 文档 | 说明 |
|------|------|
| `README.md` | 项目简介、快速启动、特性总览 |
| `CODE_WIKI.md` | 完整架构说明（包含 React 版与 Flutter 版对比） |
| `Makefile` | 统一命令入口（`make help` 查看所有命令） |
| `frontend/README.md` | Flutter 端开发说明 |
| `frontend/README_PACKAGING.md` | Flutter 打包发布说明 |
| `frontend/android/README_ANDROID_SIGN.md` | Android 签名配置 |

---

## 👤 终端用户（你想安装和使用这个应用）

### 推荐阅读顺序

| 步骤 | 文档 | 你将学会 |
|------|------|---------|
| 1. 👀 快速了解 | [README.md](../README.md) | 项目是什么，有哪些核心特性 |
| 2. 📱 安装与使用 | [user-guide.md](user-guide.md) | 下载 APK、配置服务器、使用视频流、搜索、收藏等操作 |
| 3. 🛠 遇到问题 | [troubleshooting.md](troubleshooting.md) | 解决登录失败、视频无法播放、字幕乱码等常见问题 |

---

## 👨‍💻 开发者（你想为项目贡献代码或修改功能）

### 推荐阅读顺序

| 步骤 | 文档 | 你将学会 |
|------|------|---------|
| 1. 👀 了解项目 | [README.md](../README.md) | 快速了解项目概览 |
| 2. 🏗 理解架构 | [architecture.md](architecture.md) | 三层架构（Flutter → FastAPI → Emby）、核心模块、数据模型 |
| 3. 🛠 搭建环境 | [developer-guide.md](developer-guide.md) | 安装 Flutter、Python、配置开发环境、运行测试 |
| 4. 📡 API 参考 | [api-reference.md](api-reference.md) | 后端所有接口的请求/响应格式、错误码、示例 |
| 5. 📚 参考 Wiki | [CODE_WIKI.md](../CODE_WIKI.md) | 更详细的模块说明与设计思路 |
| 6. 🐛 遇到问题 | [troubleshooting.md](troubleshooting.md) | 解决构建失败、依赖冲突、编译错误等问题 |

---

## 🛠 部署工程师（你负责部署和运维）

### 推荐阅读顺序

| 步骤 | 文档 | 你将学会 |
|------|------|---------|
| 1. 👀 了解项目 | [README.md](../README.md) | 快速了解系统构成 |
| 2. 🚀 部署方案 | [deployment.md](deployment.md) | Docker Compose / Nginx 反向代理 / HTTPS / 公网暴露 |
| 3. 🐛 问题排查 | [troubleshooting.md](troubleshooting.md) | 容器无法启动、网络不通、性能问题等 |

---

## 📑 各文档快速摘要

| 文档 | 核心内容摘要 | 预计阅读时间 |
|------|------------|------------|
| **[user-guide.md](user-guide.md)** | APK 下载、安装、登录配置、视频流播放、手势交互、搜索/收藏等操作说明，FAQ 回答常见使用问题 | 10-15 分钟 |
| **[developer-guide.md](developer-guide.md)** | Flutter SDK、Python 3.11 环境配置，`make` 命令使用，测试与 lint 流程，提交规范，CI/CD 工作流说明 | 20-30 分钟 |
| **[architecture.md](architecture.md)** | 三层架构总览（Flutter → FastAPI → Emby），核心模块职责，鉴权流程，数据模型，视频播放与搜索流程 | 15-20 分钟 |
| **[api-reference.md](api-reference.md)** | 所有后端路由（auth / libraries / items / search / favorites / subtitles）的请求体、响应体、示例与错误码 | 30+ 分钟（按需查阅） |
| **[deployment.md](deployment.md)** | Docker Compose 一键部署、裸机部署、Nginx 反向代理、HTTPS、性能监控、备份恢复 | 15-20 分钟 |
| **[troubleshooting.md](troubleshooting.md)** | 登录失败、视频无法播放、字幕乱码、APK 构建失败、Docker 部署问题、性能优化等 | 5-15 分钟 |

---

## 🔗 跨文档引用导航

当你在某个文档中看到引用另一个文档时，可直接在本索引中跳转：

```
常见引用路径：
├── user-guide.md           ←  "详见用户指南"
├── architecture.md         ←  "关于架构说明"
├── api-reference.md        ←  "API 参考文档"
├── developer-guide.md      ←  "开发者指南"
├── deployment.md           ←  "部署指南"
└── troubleshooting.md      ←  "故障排查"
```

---

## 📖 参考阅读

| 外部资源 | 说明 |
|---------|------|
| [Flutter 官方文档](https://docs.flutter.dev/) | Flutter 开发参考 |
| [FastAPI 官方文档](https://fastapi.tiangolo.com/) | Python Web 框架 |
| [Riverpod 文档](https://riverpod.dev/) | Flutter 状态管理 |
| [Emby Server 文档](https://emby.media/docs.html) | 媒体服务器说明 |
| [Dart 语言文档](https://dart.dev/guides) | Dart 语言参考 |

---

## 📝 文档维护说明

- 每次发布新版本前，请检查并同步文档内容
- 新增功能时请同步更新相关文档（特别是 `api-reference.md`、`user-guide.md`）
- 发现文档错误或过时内容，请提交 Issue 或 PR
- 文档中的文件路径引用需保持与实际代码结构一致

---

*文档版本：v1.0 | 最后更新：2026-06-12 | 对应项目版本：EmbyTok-Flutter v1.0.x*
