# EmbyTok-Flutter 文档完善 - 实施任务清单 (tasks.md)

## [ ] Task 1：README.md 改造 - 顶部加入文档导航
- **Priority**：P0
- **Depends On**：无
- **Description**：
  - 在现有 `README.md` 的顶部（项目标题和简介之后），加入"📚 文档导航"区块
  - 按三类读者分区：用户（指向 user-guide + troubleshooting）、开发者（developer-guide + architecture + api-reference）、部署工程师（deployment）
  - 调整"快速开始"为 3 步：克隆 → 启动后端 → 启动 Flutter
  - 在 README 中加入 Makefile 常用命令的简明表格（参考 `Makefile`）
  - 在 README 末尾加入"版本/更新日期"行
- **Acceptance Criteria Addressed**：AC-1, AC-8
- **Test Requirements**：
  - `programmatic` TR-1.1：README.md 中出现字符串 "📚 文档导航"，且该区块内至少出现 5 个指向 `docs/*.md` 的 Markdown 链接
  - `programmatic` TR-1.2：README.md 中包含一个表格，列出至少 5 个常用 Makefile 命令
  - `human-judgment` TR-1.3：导航区块布局清晰、不过长（不超过整个 README 的 30%）
- **Notes**：注意保持 README 现有信息不丢失（项目简介、特性、目录结构等）

## [ ] Task 2：创建 docs/user-guide.md - 用户使用指南
- **Priority**：P0
- **Depends On**：无
- **Description**：
  - 覆盖：下载 APK / 安装 / 首次启动 / 服务器地址填写 / 登录 / 基本浏览（上下滑动、单击暂停、双击点赞、长按倍速、拖动快进）
  - FAQ 至少 5 条，包含："提示找不到文件 /api/auth/login"、"网络连接失败"、"视频无法播放"、"字幕不显示"、"如何在外面（非局域网）访问 Emby"
- **Acceptance Criteria Addressed**：AC-2, AC-8
- **Test Requirements**：
  - `programmatic` TR-2.1：文档中出现至少 5 个 FAQ 小节
  - `programmatic` TR-2.2：文档中出现"后端代理地址"字样（这是用户最容易填错的字段）
  - `human-judgment` TR-2.3：按文档真实操作一遍，是否能成功浏览视频
- **Notes**：重点是告诉用户两个地址如何填：后端代理地址 = FastAPI 服务地址（通常是 `http://<电脑IP>:8000`）；Emby 服务器地址 = 实际的 Emby 服务器（通常是 `http://<电脑IP>:8092` 或 `8010`）

## [ ] Task 3：创建 docs/api-reference.md - 后端 API 参考
- **Priority**：P0
- **Depends On**：无
- **Description**：
  - 列出所有路由：`/health`、`/`、`/api/auth/login`、`/api/libraries/*`、`/api/items/*`、`/api/search`、`/api/favorites/*`、`/api/subtitles/*`、`/api/progress/*`
  - 每条路由要包含：HTTP 方法、路径、请求体 JSON 字段表、响应体 JSON 字段表、示例请求/响应 JSON、常见错误码
  - 引用对应源码文件（`backend/routers/auth.py`、`backend/clients/emby_client.py` 等）
- **Acceptance Criteria Addressed**：AC-3, AC-8
- **Test Requirements**：
  - `programmatic` TR-3.1：运行 `grep -c '^@router\.' backend/routers/*.py | awk -F: '{s+=$2} END {print s}'` 得到路由注册数量；API 文档中条目数应 ≥ 该数量
  - `programmatic` TR-3.2：至少出现 5 个 ` ```json ` 代码块（示例 JSON）
  - `human-judgment` TR-3.3：每条路由的请求/响应字段表是否与实际 Pydantic 模型一致
- **Notes**：FastAPI 自带 `/docs` Swagger UI 可用作补充参考；文档中应提及这一点

## [ ] Task 4：创建 docs/architecture.md - 架构总览
- **Priority**：P1
- **Depends On**：无
- **Description**：
  - 三层架构 ASCII 图 + Mermaid 图（Flutter → FastAPI → Emby）
  - 核心模块职责表：前端 providers / views / widgets / services / models；后端 routers / clients / models / core
  - 数据模型表：User、Library、MediaItem、PaginatedResponse、SubtitleTrack、WatchHistoryItem、AppConfig（关键字段、类型、含义）
  - 鉴权流程图：登录 → 获取 Token → 后续请求 Header 携带
- **Acceptance Criteria Addressed**：AC-4, AC-8
- **Test Requirements**：
  - `human-judgment` TR-4.1：ASCII 架构图是否清晰表达三层关系
  - `programmatic` TR-4.2：数据模型表是否至少包含 5 个模型
- **Notes**：可参考 `CODE_WIKI.md` 的旧架构说明，但要把 React 相关内容标记为历史/参考

## [ ] Task 5：创建 docs/deployment.md - 部署指南
- **Priority**：P0
- **Depends On**：无
- **Description**：
  - Docker Compose 一键部署（直接引用根目录 `docker-compose.yml`，说明端口、持久化）
  - 本地裸机部署（Python venv + uvicorn + Flutter 构建）
  - 生产环境建议（反向代理 nginx / Caddy、HTTPS、防火墙、日志收集）
  - 环境变量参考表（后端无显式 .env，但可通过命令行参数调整 host/port/timeout）
  - 健康检查命令（`curl http://host:8000/health`）
- **Acceptance Criteria Addressed**：AC-5, AC-8
- **Test Requirements**：
  - `programmatic` TR-5.1：文档中至少出现 `docker compose up -d` 或等价命令
  - `programmatic` TR-5.2：文档中包含 `curl http://.../health` 健康检查命令
  - `human-judgment` TR-5.3：按文档执行，能成功在一台新机器上部署前后端
- **Notes**：提醒用户，"从外面访问"需要内网穿透 / 公网 IP（frp、Tailscale、Cloudflare Tunnel 等）

## [ ] Task 6：创建 docs/developer-guide.md - 开发者贡献指南
- **Priority**：P1
- **Depends On**：无
- **Description**：
  - 本地环境搭建：Flutter SDK 版本、Python 3.11+、Emby 测试服务器
  - 代码规范：Flutter `flutter analyze`、Python `ruff` / `flake8`
  - 测试：`flutter test`、`python -m pytest backend/tests/`
  - 提交规范：Conventional Commits（feat / fix / docs / chore / refactor / test）
  - PR 流程：fork → feature 分支 → lint + test → PR → review → merge
  - CI/CD 工作流简要说明（`.github/workflows/android-release.yml`、`docker-release.yml`、`ci.yml`、`secrets-check.yml`）
- **Acceptance Criteria Addressed**：AC-6, AC-8
- **Test Requirements**：
  - `programmatic` TR-6.1：文档中至少出现 `flutter test` 和 `python -m pytest` 各一次
  - `programmatic` TR-6.2：文档中出现 Conventional Commits 关键词
  - `human-judgment` TR-6.3：新开发者按文档能否跑通测试

## [ ] Task 7：创建 docs/troubleshooting.md - 故障排查指南
- **Priority**：P0
- **Depends On**：无
- **Description**：
  - 每条问题格式：`# 问题 X：<症状>` → `可能原因` → `排查步骤` → `解决方案`
  - 至少 5 条：
    1. "找不到文件 /api/auth/login"（把后端代理地址指到了 Emby 服务器）
    2. "网络连接失败，请检查服务器地址"（手机和电脑不在同一局域网 / 防火墙拦截 / 端口不对）
    3. "splits.abi 构建失败"（AGP 8.x 下 Flutter 与手动 splits 冲突）
    4. "Dio 401 未授权"（Token 过期 / 密码变更）
    5. "APK 安装后闪退"（ABI 不匹配 / 签名问题）
    6. "提示 404 Not Found"（Emby 服务路径写错）
- **Acceptance Criteria Addressed**：AC-7, AC-8
- **Test Requirements**：
  - `programmatic` TR-7.1：文档中至少有 5 个带编号或标题的问题小节
  - `human-judgment` TR-7.2：每条问题的"排查步骤"是否能让读者定位到根源

## [ ] Task 8：创建 docs/index.md - 文档索引页
- **Priority**：P2
- **Depends On**：Task 2-7
- **Description**：
  - 在 `docs/` 目录内放置一个索引文档，按读者角色推荐阅读路径（新用户 → user-guide；新开发者 → developer-guide；部署工程师 → deployment）
  - 这个文件相对 Task 1（README 导航）是"内部索引"，README 导航是"对外首页索引"
- **Acceptance Criteria Addressed**：AC-1, AC-8
- **Test Requirements**：
  - `programmatic` TR-8.1：文件 `docs/index.md` 存在，且至少有 3 个到其他 `docs/*.md` 的链接

## [ ] Task 9：Makefile shell 语法小修复
- **Priority**：P2
- **Depends On**：无
- **Description**：
  - `Makefile` 中 `awk ... | grep -E '^\s+(setup|lint'` 缺少右括号
  - 注释行"EmbyTok - 统一 Makefile (中文工作流入口"缺少右括号
  - 几处 `test-backend` 目标的 `if [ -d ... ]` 中引号不匹配（`tests ]` 应为 `tests" ]`）
  - 不改变逻辑，只修复 shell 语法层面的警告/错误
- **Acceptance Criteria Addressed**：AC-9
- **Test Requirements**：
  - `programmatic` TR-9.1：在 Linux bash 下运行 `make help` 不出现 shell 语法错误
  - `programmatic` TR-9.2：`bash -n Makefile`（或 make -n）不产生语法警告
- **Notes**：保持任务命令语义不变

## [ ] Task 10：CODE_WIKI.md 更新（Flutter+FastAPI 补充）
- **Priority**：P2
- **Depends On**：Task 4
- **Description**：
  - 在 `CODE_WIKI.md` 顶部标记"本文档同时覆盖历史 React 版与当前 Flutter 版"
  - 在架构章节新增 "Flutter 版" 小节，引用 `docs/architecture.md` 内容摘要
  - 修正文档中的目录结构引用（如 `services/` 实际是 `frontend/lib/services/`，不是 `src/hooks/`）
  - 删除或标注过时内容（如 Capacitor / React 特有文档）
- **Acceptance Criteria Addressed**：AC-4, AC-8
- **Test Requirements**：
  - `human-judgment` TR-10.1：阅读 CODE_WIKI.md 时不会把 React 版的实现误认为 Flutter 版
  - `programmatic` TR-10.2：文档中出现 "Flutter" 关键词 ≥ 10 次

---
*文档版本：v1.0 | 最后更新：2026-06-12 | 对应项目版本：EmbyTok-Flutter v1.0.x*
