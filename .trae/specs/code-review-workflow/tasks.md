# 代码审查工作流 - 实现计划（分解与优先级排序的任务列表）

## [x] Task 1: 创建 scripts/ci/ 基础设施与共享工具
- **Priority**: high
- **Depends On**: None
- **Description**:
  - 创建 `scripts/ci/` 目录
  - 创建 `scripts/ci/_common.sh`，封装共享工具函数：`require_tool()`（工具缺失降级）、`log_info()`/`log_success()`/`log_error()`/`log_warn()`（彩色日志输出）
  - 创建 8 个 `precheck-*.sh` 脚本骨架，每个脚本调用 `require_tool` 后执行对应命令，以退出码决定 PASS/FAIL
  - 8 个脚本：`precheck-analyze.sh`、`precheck-test.sh`、`precheck-test-backend.sh`、`precheck-lint-shell.sh`、`precheck-lint-yaml.sh`、`precheck-security.sh`、`precheck-theme-tokens.sh`、`precheck-pr-template.sh`
  - `precheck-pr-template.sh` 需用 Python 内联脚本解析 PR body（通过 `gh pr view --json body` 获取），检查三栏必填字段非空
- **Acceptance Criteria Addressed**: AC-1, AC-7
- **Test Requirements**:
  - `programmatic` TR-1.1: `bash -n scripts/ci/_common.sh` 语法检查通过
  - `programmatic` TR-1.2: 对每个 precheck-*.sh 执行 `bash -n` 语法检查通过
  - `programmatic` TR-1.3: 在无 shellcheck 的环境中执行 `precheck-lint-shell.sh`，退出码为 0 且输出含 `::warning::`
  - `programmatic` TR-1.4: `precheck-analyze.sh` 在有 `error •` 的代码上执行返回非零退出码
  - `human-judgement` TR-1.5: 代码风格审查 — 中文注释解释"为什么"，4 空格缩进，函数单一职责
- **Notes**: precheck-pr-template.sh 是最复杂的脚本，需解析 GitHub PR body。可用 `gh` CLI 或环境变量 `PR_BODY` 传入。

## [x] Task 2: 自研 hardcoded_color_lint.dart 与白名单
- **Priority**: high
- **Depends On**: None
- **Description**:
  - 创建 `tool/lints/hardcoded_color_lint.dart`：使用 `package:analyzer` 遍历 AST，检测 `Color(0x...)`、`Colors.xxx`（白名单 `Colors.transparent`）、`Color.fromARGB()`、`Color.fromRGBO()` 调用
  - 创建 `tool/lints/hardcoded_color_allowlist.json`：白名单 `frontend/lib/theme/` 目录（合法定义颜色的位置）
  - 修改 `frontend/pubspec.yaml`：在 `dev_dependencies` 中添加 `analyzer` package
  - 输出格式：`HardcodedColor: <file>:<line>:<col>  <匹配内容>`
  - 退出码：有违规 = 1，无违规 = 0
- **Acceptance Criteria Addressed**: AC-1
- **Test Requirements**:
  - `programmatic` TR-2.1: `dart run tool/lints/hardcoded_color_lint.dart` 在含 `Color(0xFF1A1A1A)` 的测试文件上输出 `HardcodedColor` 且退出码 1
  - `programmatic` TR-2.2: 在 `theme/app_theme.dart` 中的颜色定义不触发违规（白名单生效）
  - `programmatic` TR-2.3: `Colors.transparent` 不触发违规
  - `programmatic` TR-2.4: 无硬编码颜色的代码上退出码 0
- **Notes**: `package:analyzer` API 可能随 Flutter 版本变化，需确认当前 stable channel 的 API 兼容性。

## [x] Task 3: 实现 pr-gate.py 评审流程强门禁主逻辑
- **Priority**: high
- **Depends On**: None
- **Description**:
  - 创建 `scripts/ci/pr_gate_lib.py`：封装 GitHub API 调用（获取 PR files / reviews / comments / reviewThreads / PR body / issue 验证 / 发布评论 / 设置 Status Check / 添加 label）
  - 创建 `scripts/ci/pr-gate.py`：主逻辑，5 步校验
    - Step 1: 核心模块变更识别（glob 匹配变更文件路径）
    - Step 2: 审批人数统计（排除 PR 作者，Solo 降级逻辑）
    - Step 3: 评论严重级别前缀解析（正则提取 + GraphQL reviewThreads isResolved）
    - Step 4: Waiver 证据块校验（signed-by Maintainer + issue 存在 + 紧急绕过块）
    - Step 5: 超时提醒（48h 巡检 + review-overdue label 去重）
  - 顶层 `try/except` 捕获所有异常，降级为 exit 0 + 警告评论
  - API 限流处理：检测 403 + X-RateLimit-Remaining，<5min sleep 重试，>5min 降级 PASS
  - 创建 `scripts/ci/requirements.txt`：依赖 `PyGithub`（或 `requests`）
- **Acceptance Criteria Addressed**: AC-2, AC-3, AC-4, AC-5, AC-6, AC-8
- **Test Requirements**:
  - `programmatic` TR-3.1: `python3 -c "import ast; ast.parse(open('scripts/ci/pr-gate.py').read())"` 语法检查通过
  - `programmatic` TR-3.2: `python3 -c "import ast; ast.parse(open('scripts/ci/pr_gate_lib.py').read())"` 语法检查通过
  - `programmatic` TR-3.3: 单元测试 — 正则 `^\s*\[(Blocker|Major|Minor|Nit)\]` 对 `[Blocker] xxx` 匹配成功，对 `xxx` 匹配失败
  - `programmatic` TR-3.4: 单元测试 — `get_required_approvals(is_core=True, maintainers=['a'])` 返回 1（Solo 降级）
  - `programmatic` TR-3.5: 单元测试 — `get_required_approvals(is_core=True, maintainers=['a','b','c'])` 返回 2
  - `programmatic` TR-3.6: 单元测试 — waiver 块解析对合法格式提取成功，对缺字段格式提取失败
  - `human-judgement` TR-3.7: 代码审查 — 5 步校验逻辑清晰分离，每步独立可测试
- **Notes**: GitHub GraphQL API 的 reviewThreads 查询需注意分页（cursor）。Waiver 和 emergency-bypass 块解析逻辑可共享。

## [x] Task 4: 创建配置文件（.yamllint + .bandit + CODEOWNERS + PR Template）
- **Priority**: high
- **Depends On**: None
- **Description**:
  - 创建 `.yamllint`：yamllint 配置，规则宽松适度（允许 GitHub Actions 常用的 `on:` 缩进）
  - 创建 `.bandit`：bandit 配置，仅报 HIGH/MEDIUM severity，排除 `tests/` 目录
  - 创建 `.github/CODEOWNERS`：核心模块路径映射到 `@1525745393`
  - 创建 `.github/PULL_REQUEST_TEMPLATE.md`：三栏必填（改了什么 / 为什么 / 如何验证）+ Waiver 证据块占位 + 紧急绕过块占位
- **Acceptance Criteria Addressed**: AC-1, AC-4, AC-5
- **Test Requirements**:
  - `programmatic` TR-4.1: `yamllint -c .yamllint .github/workflows/android-release.yml` 退出码 0（现有 YAML 合规）
  - `programmatic` TR-4.2: `bandit -r backend/ -c .bandit` 退出码 0（现有后端代码无 HIGH/MEDIUM）
  - `programmatic` TR-4.3: CODEOWNERS 文件格式正确（`git check-ignore` 验证路径匹配）
  - `human-judgement` TR-4.4: PR 模板三栏清晰、Waiver 块格式注释正确
- **Notes**: .yamllint 规则需兼容 GitHub Actions 的 YAML 格式（如 `on:` 是保留字在 YAML 1.1 中）。

## [x] Task 5: 创建 pr-precheck.yml workflow
- **Priority**: high
- **Depends On**: Task 1, Task 2
- **Description**:
  - 创建 `.github/workflows/pr-precheck.yml`
  - 触发: `pull_request: [opened, synchronize, reopened]`
  - matrix strategy: 8 项 check 并行，`fail-fast: false`
  - 条件安装: Flutter（analyze/test/theme-tokens）、Python（test-backend/security）
  - 每项调用对应 `scripts/ci/precheck-*.sh`
  - permissions: `contents: read`, `pull-requests: write`, `checks: write`
- **Acceptance Criteria Addressed**: AC-1, AC-7
- **Test Requirements**:
  - `programmatic` TR-5.1: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/pr-precheck.yml'))"` YAML 语法通过
  - `programmatic` TR-5.2: YAML 中 `matrix.check` 列表含 8 项
  - `programmatic` TR-5.3: YAML 中 `fail-fast: false` 存在
  - `programmatic` TR-5.4: YAML 中 `permissions` 最小化（无 `packages: write` 等多余权限）
- **Notes**: Flutter cache 用 `subosito/flutter-action@v2` 的 `cache: true`。Python 用 `actions/setup-python@v5`。

## [x] Task 6: 创建 pr-gate.yml workflow
- **Priority**: high
- **Depends On**: Task 3
- **Description**:
  - 创建 `.github/workflows/pr-gate.yml`
  - 触发: `pull_request` + `pull_request_review` + `issue_comment` + `schedule`（每 6h 巡检）
  - `if` 条件排除非 PR 的 issue_comment
  - 安装 Python 依赖（`pip install -r scripts/ci/requirements.txt`）
  - 调用 `python3 scripts/ci/pr-gate.py`
  - permissions: `contents: read`, `pull-requests: write`, `issues: write`, `statuses: write`
- **Acceptance Criteria Addressed**: AC-2, AC-3, AC-4, AC-5, AC-6, AC-8
- **Test Requirements**:
  - `programmatic` TR-6.1: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/pr-gate.yml'))"` YAML 语法通过
  - `programmatic` TR-6.2: YAML 中 `if` 条件正确排除非 PR issue_comment（`github.event.issue.pull_request != null`）
  - `programmatic` TR-6.3: `schedule.cron` 值为 `'0 */6 * * *'`
  - `programmatic` TR-6.4: `GITHUB_TOKEN` 通过 `env` 传入而非直接写在 run 命令中
- **Notes**: `issue_comment` 事件不包含 `pull_request` 对象，脚本需通过 `github.event.issue.pull_request.url` 反查 PR 编号。

## [x] Task 7: 部署文档与 Branch Protection 配置指南
- **Priority**: medium
- **Depends On**: Task 5, Task 6
- **Description**:
  - 创建部署指南 `docs/code-review-workflow-deploy.md`（或更新现有 docs/code-review.md 追加部署章节）
  - 内容包含：7 步部署顺序、Branch Protection Rules 配置截图说明、Required Status Checks 清单（9 项）、团队通知模板（Reviewer 前缀约定）
  - 更新 [docs/code-review.md](file:///workspace/docs/code-review.md) 末尾追加"自动化执行"章节，引用本工作流
- **Acceptance Criteria Addressed**: AC-1, AC-2
- **Test Requirements**:
  - `human-judgement` TR-7.1: 部署指南步骤清晰可执行，无歧义
  - `human-judgement` TR-7.2: Required Status Checks 清单与 workflow 实际输出的 Check 名称一致
  - `programmatic` TR-7.3: docs/code-review.md 的"自动化执行"章节链接指向正确的 workflow 文件路径
- **Notes**: Branch Protection Rules 无法通过文件自动化，部署指南必须明确标注"需在 GitHub Web UI 手动配置"。
