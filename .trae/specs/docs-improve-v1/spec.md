# EmbyTok-Flutter 文档完善 - 产品需求文档 (PRD)

## Overview
- **Summary**：EmbyTok-Flutter 项目当前缺乏系统化、面向多类读者的文档体系。现有文档（README.md、CODE_WIKI.md 等）覆盖了基础信息，但在 API 参考、架构总览、部署指南、故障排查、开发者贡献指南等维度存在显著缺口。本次完善的目标是构建一套结构化、互相关联、便于读者快速定位答案的文档体系。
- **Purpose**：
  1. 降低**终端用户**上手成本（安装、配置、登录、基本浏览）
  2. 降低**开发者**贡献成本（本地环境搭建、测试、提 PR）
  3. 降低**部署工程师**部署成本（Docker、环境变量、生产环境、常见问题排查）
  4. 让 **AI 代理**（本项目内部使用的代码助手）在贡献代码时有明确参考依据
- **Target Users**：
  - 终端用户（家庭 NAS 用户、电影爱好者）
  - Flutter 开发者（希望贡献代码的工程师）
  - Python 后端开发者（维护 FastAPI 中间层）
  - DevOps 工程师（Docker 部署、CI/CD 配置）
  - AI 代码助手（需要通过文档理解项目结构和约定）

## Goals
- **G1 (用户文档)**：在 `docs/` 下提供一份完整的用户使用指南（安装、配置、登录、基础功能、常见问题）
- **G2 (API 文档)**：提供一份后端 API 参考文档（所有 `/api/*` 路由的输入输出说明）
- **G3 (架构文档)**：提供一份项目架构总览（三层架构图、数据模型说明、核心模块职责）
- **G4 (部署文档)**：提供一份完整的部署指南（Docker Compose、环境变量、生产部署、健康检查）
- **G5 (开发者文档)**：提供一份开发者贡献指南（本地开发、代码规范、测试、提交规范）
- **G6 (索引文档)**：在根 README.md 中提供清晰的文档索引，读者从首页即可一键跳转到所需文档

## Non-Goals (Out of Scope)
- 不修改任何业务代码（API 实现、UI 组件），本次只增/改文档
- 不编写用户手册中的多语言翻译（中文为主，英文为可选项，后续迭代）
- 不编写 Emby 原始服务器的使用手册（只说明 EmbyTok 如何与它交互）
- 不提供 Flutter 或 Python 的基础教程（假定读者具备相应语言基础）
- 不维护 Plex 相关文档（当前后端只实现了 Emby 客户端，Plex 为后续规划）

## Background & Context

**现有文档现状**（基于 2026-06-12 实际调研）：

| 文档 | 位置 | 现状评估 |
|------|------|---------|
| `README.md` | 项目根目录 | 有基础介绍、特性列表、快速启动、目录结构；但缺少架构图、API 索引、部署说明、故障排查 |
| `frontend/README.md` | `frontend/` | 有 Flutter 环境说明，部分命令示例；缺少打包签名说明的索引、测试命令 |
| `frontend/README_PACKAGING.md` | `frontend/` | 描述打包流程；缺少 Android/iOS 具体差异、注意事项 |
| `CODE_WIKI.md` | 项目根目录 | 架构说明较完整，但偏向 React 旧版本，与当前 Flutter+FastAPI 的实现有偏差（例如目录结构与实际文件不符） |
| `frontend/android/README_ANDROID_SIGN.md` | `frontend/android/` | 签名说明存在，但未在任何索引文档中引用 |
| `Makefile` | 项目根目录 | 命令清单较完整，但有几处 shell 语法问题（grep 括号匹配、引号不闭合），命令说明在代码注释中重复，且没有在 README 中索引 |
| `docker-compose.yml` | 项目根目录 | 存在但未在 README 中引用 |
| `.github/workflows/*.yml` | `.github/workflows/` | CI/CD 工作流存在但无文档说明 |

**关键问题**：
1. 读者无法从首页清晰地知道"我该看哪份文档"
2. 后端 API 无统一参考，开发者只能翻代码
3. 部署步骤（Docker/本地/生产）分散在各文件的代码注释中
4. CODE_WIKI.md 的架构章节与 Flutter 版实现不符（误导读者）
5. 常见问题（如"登录失败"、"连接超时"、"splits.abi 构建失败"）无 FAQ

**技术栈参考**（方便文档读者理解上下文）：
- 前端：Flutter 3.x + Dart 3.x + Riverpod + GoRouter + Dio + video_player
- 后端：FastAPI (Python 3.11+) + httpx (async HTTP client for Emby) + Pydantic v2
- 媒体服务器：Emby Server（通过 `/Users/AuthenticateByName`、`/Items` 等 REST API 通信）
- 构建与部署：Dockerfile 两份（frontend/backend），docker-compose.yml 一份，Makefile 一份
- CI/CD：GitHub Actions（android-release.yml, docker-release.yml, ci.yml, secrets-check.yml）

## Functional Requirements

### FR-1：文档索引首页 (README.md 改造)
- 根 README.md 顶部应有清晰的"📚 文档导航"区块
- 按读者角色分区（用户 / 开发者 / 部署），每类链接到对应文档
- 提供"快速开始"三步（克隆 → 启动后端 → 启动前端）

### FR-2：用户使用指南 (docs/user-guide.md)
- 覆盖：下载 APK / 安装 / 首次启动 / 服务器配置 / 登录 / 基本浏览（上下滑动、双击点赞、长按倍速）
- 提供常见问题章节（对应之前对话中遇到的真实问题：后端代理地址填错、404 错误、APK 安装失败等）

### FR-3：后端 API 参考 (docs/api-reference.md)
- 列出所有 `/api/*` 路由（目前有 auth / libraries / items / search / favorites / subtitles / progress）
- 每个接口包含：HTTP 方法、路径、请求体 JSON 示例、响应体 JSON 示例、错误码
- 引用实际代码文件作为权威来源（如 `backend/routers/auth.py`、`backend/models/base_models.py`、`backend/clients/emby_client.py`）

### FR-4：架构总览 (docs/architecture.md)
- 三层架构图（Flutter App → FastAPI Backend → Emby Server），纯文本 ASCII + Mermaid 两种形式
- 核心模块职责表：Flutter 端 providers / views / widgets / services / models；后端 routers / clients / models / core
- 数据模型总览：User、Library、MediaItem、PaginatedResponse、SubtitleTrack、WatchHistoryItem、AppConfig
- 鉴权流程说明：用户在 Flutter 输入密码 → FastAPI 透传 `/Users/AuthenticateByName` 到 Emby → 返回 AccessToken → Flutter 后续请求在 `X-Emby-Token` 和 `Authorization: Bearer` 双 Header 中携带

### FR-5：部署指南 (docs/deployment.md)
- Docker Compose 一键部署（含端口说明、持久化卷）
- 本地裸机部署（后端 + Flutter 客户端）
- 生产环境注意事项（反向代理、HTTPS、防火墙、日志收集）
- 环境变量参考（前端无，后端无显式 .env，但有可配置的超时等）
- 健康检查命令（`curl http://host:8000/health`）

### FR-6：开发者贡献指南 (docs/developer-guide.md)
- 本地环境搭建（前置条件：Flutter SDK、Python 3.11+、Emby Server 测试实例）
- 代码规范（Flutter `flutter analyze`、Python `ruff` / `flake8`）
- 测试命令（`flutter test`、`python -m pytest backend/tests/`）
- 提交信息约定（推荐 Conventional Commits：feat/fix/docs/chore/...）
- PR 提交流程
- CI/CD 工作流说明（.github/workflows/*.yml 各文件职责）

### FR-7：故障排查指南 (docs/troubleshooting.md)
- 基于真实问题整理："找不到文件 /api/auth/login"、"网络连接失败"、"APK 安装后闪退"、"splits.abi 构建失败"、"Dio 401 未授权"
- 每个问题含：症状描述、可能原因、排查步骤、解决方案

### FR-8：Makefile 与 Shell 脚本的文档注释修复
- `Makefile` 中现存几处 shell 语法问题（grep 括号匹配不完整、注释说明 "中文工作流入口" 缺少右括号），需要在文档中同时标记并修复
- Makefile 命令应在 README 中以表格形式索引（读者不必翻阅长脚本）

### FR-9：CODE_WIKI.md 更新
- 将旧架构说明中 React 相关内容标注为历史/参考
- 新增 Flutter + FastAPI 架构章节
- 同步实际目录结构与文件路径（确保文档中的引用路径正确存在）

## Non-Functional Requirements

### NFR-1：可维护性
- 文档中引用的代码文件路径必须真实存在（写文档时要实际检查）
- 每个新文档末尾应有"最后更新"时间戳与"对应版本"标记（如 v1.0.x+）
- 文档结构扁平化：`docs/*.md` 不超过 10 个文件，避免过度分层

### NFR-2：可发现性
- 所有新建文档必须在 README.md 的"📚 文档导航"区块中被列出并链接
- 每个文档开头有 1-2 行简短的"本文件目标"摘要
- 文档标题层级不超过 3 级（#、##、###）

### NFR-3：可读性
- 关键步骤使用编号列表
- 命令使用代码块包裹（```bash）
- 复杂的架构图使用 ASCII 或 Mermaid（` ```mermaid `）
- 避免长篇大段纯文本，合理使用表格和项目符号

### NFR-4：一致性
- 所有文档使用中文（与现有 CODE_WIKI.md 一致）
- 统一使用 UTF-8 / LF 换行
- 统一文档标题风格：`EmbyTok - {文档标题}`（如 `EmbyTok - 用户使用指南`）

## Constraints
- **技术约束**：只修改 `.md` 文档文件；可修复 Makefile 中明显的 shell 语法 bug（不改变逻辑）；不修改 Flutter/Dart/Python 业务代码
- **项目结构约束**：新增文档统一放到 `docs/` 目录；保留现有 `frontend/README.md` 等位置不变
- **依赖约束**：不引入新的构建工具，文档由 Markdown 构成，可由任意 Markdown 渲染器（GitHub / mkdocs / mdbook）直接阅读
- **时间约束**：文档撰写在单个开发迭代内完成（约 2-4 小时）

## Assumptions
- 读者能访问 GitHub（文档以 GitHub 渲染为主要目标）
- 终端用户的设备至少满足 Flutter 支持的最低 Android/iOS 版本
- 开发者在本地有 Emby 服务器实例（或使用公共测试实例）
- Docker 部署场景假定读者了解基础 Docker / Docker Compose 概念

## Acceptance Criteria

### AC-1：README.md 有清晰的文档导航
- **Given** 读者打开项目根目录 README.md
- **When** 他们浏览页面顶部
- **Then** 他们能看到一个名为"📚 文档导航"的区块，其中按读者角色（用户/开发者/部署）列出了所有核心文档的链接，且每个链接目标文件真实存在
- **Verification**：`human-judgment`（人工检查导航块）+ `programmatic`（脚本验证链接文件存在）
- **Notes**：导航块不应长于整个 README 的 30%，避免喧宾夺主

### AC-2：用户使用指南覆盖完整使用流程
- **Given** 读者按 `docs/user-guide.md` 的说明操作
- **When** 他们从 0 开始，目标是成功浏览 Emby 媒体库
- **Then** 文档中提供的步骤能引导他们完成：下载 APK → 安装 → 填写服务器地址 → 登录 → 浏览视频 → 使用手势交互；且文档含 FAQ 至少 5 条
- **Verification**：`human-judgment`（真人按文档走一遍）
- **Notes**：FAQ 中必须包含"后端代理地址填错怎么办"、"提示找不到文件 /api/auth/login"、"播放无声音"等已在对话中遇到的真实问题

### AC-3：API 参考文档覆盖所有后端路由
- **Given** 开发者查阅 `docs/api-reference.md`
- **When** 他们查找某个路由的输入输出
- **Then** 每个在 `backend/routers/` 中注册的路由都有对应的接口说明，且包含：HTTP 方法、路径、请求体字段说明、响应体字段说明、至少一个示例 JSON；各 API 的实现代码文件在文档中被引用
- **Verification**：`programmatic`（通过统计 `backend/routers/*.py` 中的 `@router.` 数量，与 API 文档中的条目对比）+ `human-judgment`（检查示例 JSON 的合理性）
- **Notes**：`/health` 和 `/` 根路由也应列出（虽然它们不是 `/api/*` 前缀）

### AC-4：架构文档含三层架构图
- **Given** 读者阅读 `docs/architecture.md`
- **When** 他们浏览"整体架构"章节
- **Then** 能看到一张三层架构图（Flutter App → FastAPI Backend → Emby Server），每一层标注关键职责；数据模型章节至少列出 5 个核心模型（User、Library、MediaItem、PaginatedResponse、AppConfig），并以表格形式展示其关键字段
- **Verification**：`human-judgment`
- **Notes**：架构图优先使用 ASCII，便于纯文本阅读；可额外提供 Mermaid 作为可选渲染版本

### AC-5：部署文档覆盖 Docker Compose + 本地两种场景
- **Given** 部署工程师阅读 `docs/deployment.md`
- **When** 他们选择 Docker Compose 部署
- **Then** 文档提供可直接复制运行的 `docker-compose.yml` 片段（或引用项目根目录的文件），并说明端口映射、持久化、健康检查；本地部署场景同样有完整步骤
- **Verification**：`human-judgment` + `programmatic`（运行 `docker-compose config` 验证 YAML 语法）
- **Notes**：文档中的命令必须能在 Linux / macOS 上直接工作（Windows WSL 注明）

### AC-6：开发者文档含完整的"本地环境搭建"流程
- **Given** 新开发者首次克隆项目
- **When** 他们按 `docs/developer-guide.md` 操作
- **Then** 能在 30 分钟内完成：依赖安装 → 本地后端启动 → 本地 Flutter 启动 → 运行测试 → 提交代码；且文档中明确列出所有需要的外部依赖（Flutter SDK 版本、Python 版本）
- **Verification**：`human-judgment`（真人尝试按文档搭建）

### AC-7：故障排查文档至少 5 条真实问题
- **Given** 读者遇到问题
- **When** 他们打开 `docs/troubleshooting.md` 的目录
- **Then** 能找到至少 5 条已在实际使用或 CI 中出现过的问题（如"找不到文件 /api/auth/login"、"网络连接失败"、"splits.abi 构建失败"、"APK 签名失败"、"401 未授权"），每条含：症状 / 原因 / 解决步骤
- **Verification**：`human-judgment`

### AC-8：文档之间交叉引用完整
- **Given** 读者在某个文档中遇到一个超出该文档范围的话题
- **When** 他们浏览文档
- **Then** 该话题在文档中至少有一个指向其他更合适文档的链接（例如"关于 API 细节，请参阅 `docs/api-reference.md`"）
- **Verification**：`human-judgment` + `programmatic`（简单统计跨文档链接数量）

### AC-9：Makefile shell 语法问题修复（若发现）
- **Given** 开发者运行 `make help` 或 `make setup`
- **When** 命令在 Linux / macOS bash 下执行
- **Then** 不出现 grep / shell 语法警告或错误
- **Verification**：`programmatic`（在 CI 环境实际执行 `make help`、`make setup --dry-run` 变体确认）

## Open Questions
- [ ] **Q1**：`docs/` 目录是否需要用 mkdocs 或 mdbook 构建静态站点？（当前只要求纯 Markdown，后续可评估）
- [ ] **Q2**：API 文档是否需要提供一份 OpenAPI/Swagger JSON 的生成指引？（FastAPI 自带 `/openapi.json`）
- [ ] **Q3**：是否需要英文版文档（`*.en.md`）？（当前需求默认中文；若有海外用户需后续规划）
- [ ] **Q4**：是否要在 README 的导航区加入一个"❓ 先读哪份"的推荐阅读路径图？（例如新用户 → user-guide.md；新开发者 → developer-guide.md；运维 → deployment.md）

---
*文档版本：v1.0 | 最后更新：2026-06-12 | 对应项目版本：EmbyTok-Flutter v1.0.x*
