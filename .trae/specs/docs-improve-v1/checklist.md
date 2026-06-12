# EmbyTok-Flutter 文档完善 - 验证检查清单 (checklist.md)

## 🔍 验证前检查
- [ ] 当前工作区是 `EmbyTok-Flutter` 项目根目录
- [ ] `git status` 显示工作区干净，或已为本次文档修改专门创建分支（建议 `docs/improve-v1`）
- [ ] 能够查看 `docs/` 目录下的所有新文件

## 📄 Task 1：README.md 改造检查
- [ ] README.md 中存在 "📚 文档导航"（或等效中文标题）区块
- [ ] 导航区块中按读者角色分区（至少分为：用户 / 开发者 / 部署）
- [ ] 导航区块至少有 5 个 Markdown 链接到 `docs/*.md`
- [ ] 每个链接的目标文件都真实存在于文件系统
- [ ] README 中存在一个 "Makefile 常用命令" 表格，至少 5 条命令
- [ ] "快速开始" 三步流程可用（克隆 → 启动后端 → 启动前端）
- [ ] README 末尾有版本/最后更新日期信息
- [ ] 原 README 的核心信息（项目简介、特性、目录结构）未被丢失

## 📄 Task 2：用户使用指南检查
- [ ] `docs/user-guide.md` 文件存在
- [ ] 开头有 1-2 行"本文件目标"的摘要
- [ ] 包含：下载 APK → 安装 → 启动 → 服务器地址配置 → 登录 → 基本浏览 的完整流程
- [ ] 手势说明齐全：上下滑动、单击暂停、双击点赞、长按倍速
- [ ] FAQ 至少 5 条，且包含：
  - [ ] "找不到文件 /api/auth/login"
  - [ ] "网络连接失败"
  - [ ] "视频无法播放 / 黑屏"
  - [ ] "字幕不显示 / 乱码"
  - [ ] "外网访问"
- [ ] 明确解释了"后端代理地址"与"Emby 服务器地址"的区别（这是最常见的配置错误）
- [ ] 文档标题风格统一（EmbyTok - xxx）

## 📄 Task 3：API 参考文档检查
- [ ] `docs/api-reference.md` 文件存在
- [ ] 列出所有路由（`/health`、`/`、`/api/auth/login`、`/api/libraries/*`、`/api/items/*`、`/api/search`、`/api/favorites/*`、`/api/subtitles/*`、`/api/progress/*`）
- [ ] 每条路由都有：HTTP 方法、路径、请求体字段表、响应体字段表
- [ ] 至少有 5 个 ` ```json ` 示例代码块
- [ ] 在每条路由说明中引用了实际的 Python 源文件（如 `backend/routers/auth.py`）
- [ ] 提及 FastAPI 自带 `/docs` Swagger UI
- [ ] 路由数量 ≥ `grep -c '^@router\.' backend/routers/*.py | awk -F: '{s+=$2} END {print s}'` 的执行结果

## 📄 Task 4：架构文档检查
- [ ] `docs/architecture.md` 文件存在
- [ ] 有 ASCII 三层架构图（Flutter App → FastAPI Backend → Emby Server）
- [ ] 每一层有明确职责描述
- [ ] 有核心模块职责表（Flutter 端 providers / views / widgets / services / models；后端 routers / clients / models / core）
- [ ] 有数据模型表（User、Library、MediaItem、PaginatedResponse、SubtitleTrack、WatchHistoryItem、AppConfig），每个含关键字段、类型、含义
- [ ] 有鉴权流程说明（从登录到 Token 注入）
- [ ] 文档中引用的文件路径真实存在（如 `frontend/lib/providers/auth_provider.dart`、`backend/clients/emby_client.py`）
- [ ] （可选）提供 Mermaid 流程图/架构图

## 📄 Task 5：部署指南检查
- [ ] `docs/deployment.md` 文件存在
- [ ] Docker Compose 部署步骤完整（含命令：`docker-compose up -d`、端口说明、持久化、健康检查）
- [ ] 引用或展示了根目录 `docker-compose.yml` 的关键内容
- [ ] 本地裸机部署步骤完整（Python venv、uvicorn、Flutter 构建）
- [ ] 生产环境注意事项（反向代理、HTTPS、防火墙、日志）
- [ ] 有环境变量参考表（即使当前只有少量，也要列出可调参数）
- [ ] 有健康检查命令（`curl http://host:8000/health`）
- [ ] 有外网访问建议（frp / Tailscale / Cloudflare Tunnel）
- [ ] 文档中出现的命令在 Linux/macOS bash 下可直接运行（人工验证）

## 📄 Task 6：开发者贡献指南检查
- [ ] `docs/developer-guide.md` 文件存在
- [ ] 有本地环境搭建步骤：Flutter SDK、Python 3.11+、Emby 测试服务器
- [ ] 有 Flutter 依赖安装命令（`flutter pub get`）
- [ ] 有代码规范说明（`flutter analyze`、Python linter）
- [ ] 有测试命令（`flutter test`、`python -m pytest backend/tests/`）
- [ ] 有 Conventional Commits 提交规范说明（feat / fix / docs / chore / refactor / test）
- [ ] 有 PR 流程说明（fork → feature 分支 → lint + test → PR → review → merge）
- [ ] 有 CI/CD 工作流说明（`.github/workflows/android-release.yml`、`docker-release.yml`、`ci.yml`、`secrets-check.yml` 的职责）
- [ ] 有 Makefile 命令索引或引用

## 📄 Task 7：故障排查指南检查
- [ ] `docs/troubleshooting.md` 文件存在
- [ ] 每条问题含：症状、可能原因、排查步骤、解决方案四部分
- [ ] 至少 5 条问题，覆盖：
  - [ ] "找不到文件 /api/auth/login"（后端地址填错到 Emby 地址）
  - [ ] "网络连接失败，请检查服务器地址"（网络/防火墙/端口）
  - [ ] "splits.abi 构建失败"（AGP 8.x 构建问题）
  - [ ] "Dio 401 未授权"（Token / 密码变更）
  - [ ] "APK 安装后闪退"（ABI / 签名）
- [ ] 每条问题的"解决方案"可操作（不只是笼统建议）

## 📄 Task 8：文档索引页检查
- [ ] `docs/index.md` 文件存在
- [ ] 按读者角色推荐阅读路径（新用户 / 新开发者 / 部署工程师）
- [ ] 至少有 3 个到其他 `docs/*.md` 的链接
- [ ] 首页 README 的导航区块也引用了这个 index（双向链接）

## 📄 Task 9：Makefile shell 语法检查
- [ ] `Makefile` 第 2 行 `中文工作流入口` 右括号已修复
- [ ] `grep -E '^\s+(setup|lint'` 的括号已修复
- [ ] `test-backend` 目标的 `if [ -d "..." ]` 引号已修复
- [ ] `make help` 在 Linux bash 下无语法错误 / grep 警告
- [ ] `make setup` 流程无 shell 语法错误（可用 `make -n setup` dry-run 检查）
- [ ] Makefile 原有命令逻辑未被破坏

## 📄 Task 10：CODE_WIKI.md 更新检查
- [ ] `CODE_WIKI.md` 顶部有关于"本文档同时覆盖历史 React 版与当前 Flutter 版"的说明
- [ ] 架构章节中新增 "Flutter 版" 小节
- [ ] 文档中引用的 Flutter 相关路径与实际文件系统一致（如 `frontend/lib/services/`、`frontend/lib/providers/`）
- [ ] 文档中出现 "Flutter" 关键词 ≥ 10 次
- [ ] 历史 React 版的内容（Capacitor、React 组件等）已标注为历史/参考

## ✅ 文档质量总览
- [ ] **可发现性**：所有 `docs/*.md` 文档都在 README 导航区块中被引用
- [ ] **交叉引用**：文档之间互相引用（用户指南引用部署指南；开发者指南引用架构文档；故障排查引用用户指南等）
- [ ] **一致性**：所有文档使用中文、UTF-8、标题层级不超过 3 级
- [ ] **可维护性**：每个文档末尾有"文档版本 / 最后更新日期 / 对应项目版本"标记
- [ ] **准确性**：文档中引用的代码路径均真实存在（可用简单脚本批量验证）
- [ ] **无错误链接**：README 和 docs/ 之间的所有 Markdown 链接有效
- [ ] **无重复**：各文档的职责边界清晰，相同主题不在多个文档中重复长篇描述

## 📊 验收标准完成情况
- [ ] **AC-1**：README 有清晰文档导航（Task 1 检查项全部通过）
- [ ] **AC-2**：用户使用指南覆盖完整流程 + 5 条以上 FAQ（Task 2 检查项全部通过）
- [ ] **AC-3**：API 参考覆盖所有后端路由（Task 3 检查项全部通过，且路由数量比对通过）
- [ ] **AC-4**：架构文档含三层架构图（Task 4 检查项全部通过）
- [ ] **AC-5**：部署文档覆盖 Docker + 本地两种场景（Task 5 检查项全部通过）
- [ ] **AC-6**：开发者文档含完整的本地环境搭建（Task 6 检查项全部通过）
- [ ] **AC-7**：故障排查至少 5 条真实问题（Task 7 检查项全部通过）
- [ ] **AC-8**：文档之间交叉引用完整（文档质量总览第 2 条通过）
- [ ] **AC-9**：Makefile shell 语法问题修复（Task 9 检查项全部通过）

---
*文档版本：v1.0 | 最后更新：2026-06-12 | 对应项目版本：EmbyTok-Flutter v1.0.x*
