# 代码审查工作流 - 产品需求文档 (PRD)

## Overview

- **Summary**: 为 EmbyTok 项目设计并实现一套可执行的代码审查工作流系统，将现有 [docs/code-review.md](file:///workspace/docs/code-review.md) 中的 8 大维度评审条款落地为自动化 CI 门禁与人工评审强约束。系统包含两个 GitHub Actions workflow：`pr-precheck.yml`（8 项可自动化检查，并行执行）和 `pr-gate.yml`（人工评审流程强门禁，含 Reviewer 数量统计、严重级别前缀解析、Waiver 证据块校验、超时提醒）。所有逻辑纯 GitHub 原生实现，无外部 SaaS 依赖。

- **Purpose**: 解决"代码质量参差不齐"问题，把评审从"凭感觉"变成"可按清单执行、可复盘"的机制。现有 docs/code-review.md 已写明 8 大维度条款但无强制执行手段，本工作流让每一条款真正落地，阻断未通过审查的 PR 合并。

- **Target Users**:
  - 项目维护者（@1525745393）：执行审查、签字 Waiver、紧急绕过
  - CI/CD 工程师：维护 workflow 与脚本
  - 贡献者：提交 PR、响应审查意见

## Goals

1. **条款落地**: 将 docs/code-review.md §3.1-§3.8 的可自动化条款映射为 8 项独立 CI Check，每项对应一个 GitHub Status Check
2. **强门禁**: 未解决 Blocker = 0、未解决 Major（无 Waiver）= 0、审批人数达标（核心模块 ≥2 / 非核心 ≥1，solo 降级 ≥1），否则 GitHub Merge 按钮灰掉
3. **严重级别可追溯**: Reviewer 评论必须带 `[Blocker]/[Major]/[Minor]/[Nit]` 前缀，否则不计入评审结论
4. **Waiver 证据链**: Major 问题可由 Maintainer 签字豁免，需关联 issue 并留痕
5. **优雅降级**: API 限流、工具缺失、workflow 故障时不误杀，降级为 PASS + 警告标注

## Non-Goals (Out of Scope)

1. **新增评审条款**: 不扩写 docs/code-review.md 的 8 大维度，仅做已有条款的自动化落地
2. **常驻 Bot 服务**: 不部署 GitHub App / Webhook 服务，纯 workflow 驱动
3. **第三方 SaaS 接入**: 不接入 CodeRabbit / Codacy / DeepCode 等外部服务
4. **质量仪表盘**: 不做平均 Blocker 数 / 评审时长等统计仪表盘（属方案 B 范围）
5. **测试用例编写**: 不为本工作流自身编写单元测试（workflow 脚本以集成验证为主）

## Background & Context

**现有基础**:
- [docs/code-review.md](file:///workspace/docs/code-review.md) 已定义 8 大维度（架构/Riverpod、UI/主题、性能、健壮性、测试、安全、无障碍、文档/提交）和 4 级严重级别（Blocker/Major/Minor/Nit）
- 项目已有 `.github/workflows/` 目录，含 `android-release.yml` 等工作流
- 项目使用 Flutter 3.24+ / Dart / Riverpod / GoRouter / Material 3 前端 + FastAPI / Python 后端
- 当前维护者仅 1 人（solo 模式），需自动降级审批要求

**技术约束**:
- GitHub Actions runner = ubuntu-latest，预装 shellcheck / Python 3.11 / Node 20
- `GITHUB_TOKEN` 由 Actions 自动注入，无需额外 secret 配置
- Branch Protection Rules 需在 GitHub Web UI 手动配置（无法通过文件自动化）

**设计决策记录**:
- 选择方案 A（纯 GitHub 原生 + 自定义 Actions），否决方案 B（常驻 Bot，部署过重）和方案 C（SaaS，安全合规风险）
- 选择强门禁（Blocker 未解决禁止合并），否决中/弱门禁
- 两段并行 workflow 设计：pr-precheck（机器审代码质量）与 pr-gate（审流程合规）互不阻塞

## Functional Requirements

### FR-1: pr-precheck.yml — 8 项可自动化检查

系统提供 8 项独立 CI Check，每项映射 docs/code-review.md 的具体条款，以 matrix 并行执行，`fail-fast: false` 确保所有问题一次性暴露。

| Check 名称 | 映射条款 | 执行命令 | FAIL 条件 |
|---|---|---|---|
| analyze | §3.1 架构 + §3.4 健壮性 | `flutter analyze --no-pub lib` | stdout 含 `error •` |
| test | §3.5 测试 | `flutter test --coverage` | 退出码 ≠ 0 |
| test-backend | §3.5 测试 | `python3 -m pytest -v` | 退出码 ≠ 0 |
| lint-shell | §3.1 + §3.8 文档 | `shellcheck scripts/*.sh` | 退出码 ≠ 0 |
| lint-yaml | §3.8 文档 | `yamllint -c .yamllint .github/workflows/*.yml` | 退出码 ≠ 0 |
| security | §3.6 安全 | `bandit -r backend/` + CORS 通配符 grep | bandit 退出码 ≠ 0 或 CORS 通配符命中 |
| theme-tokens | §3.2 主题 | `dart run tool/lints/hardcoded_color_lint.dart` | stdout 含 `HardcodedColor` |
| pr-template | §3.8 文档 | 解析 PR body 三栏 + Waiver 块 | 任一必填栏为空 |

### FR-2: pr-gate.yml — 人工评审流程强门禁

系统在 PR 生命周期事件（opened/synchronize/reopened/ready_for_review/review_submitted/review_dismissed/comment_created/comment_edited/comment_deleted）触发时，执行 5 步校验：

- **Step 1 核心模块识别**: 通过 GitHub API 获取 PR 变更文件列表，用 glob 匹配核心模块（播放器/鉴权/后端路由/发布流程/CI配置），命中则需 ≥2 审批
- **Step 2 审批人数统计**: 排除 PR 作者自己的 approval，统计有效 approval 数量
- **Step 3 评论严重级别解析**: 收集所有 review body 和 inline comment，用正则 `^\s*\[(Blocker|Major|Minor|Nit)\]` 提取级别；查询 GraphQL reviewThreads 获取 isResolved 状态
- **Step 4 Waiver 证据块校验**: 解析 PR body 中 `<!-- waiver: MAJOR-NNN ... -->` 块，校验 signed-by 是 Maintainer、issue 存在且 open
- **Step 5 超时提醒**: PR 创建超 48h 未合并，自动评论 @Maintainer，每 24h 提醒一次

最终输出一条 Summary 评论（更新而非新建）+ 一个 Status Check `pr-gate / gate-check`（exit 0=PASS / 1=FAIL）。

### FR-3: 自研 hardcoded_color_lint.dart

使用 `package:analyzer` 遍历 Dart AST，检测：
- `Color(0x...)` 构造调用 → 违规
- `Colors.xxx` 静态访问 → 违规（白名单：`Colors.transparent`）
- `Color.fromARGB(...)` / `Color.fromRGBO(...)` → 违规

输出 machine-readable 格式，支持 `tool/lints/hardcoded_color_allowlist.json` 白名单（排除 `theme/` 目录等合法定义颜色的位置）。

### FR-4: CODEOWNERS 核心模块映射

将播放器、鉴权、后端路由、发布流程、CI/CD 配置等核心文件路径映射到 Maintainer，GitHub 原生自动要求这些人审批。

### FR-5: PR 模板强约束

PR 模板包含三个必填栏（改了什么 / 为什么 / 如何验证）+ Waiver 证据块占位 + 紧急绕过块占位。空栏被 precheck-pr-template Check 阻断。

### FR-6: 降级与紧急绕过

- **工具缺失**: `command -v` 检测后 exit 0 + warning
- **API 限流**: <5min 等待重试，>5min 降级 PASS + 标注不可靠
- **Workflow 故障**: 顶层 try/except 捕获异常，exit 0 + 标注工具故障
- **Solo 降级**: Maintainer ≤2 人时审批要求降级为 ≥1
- **紧急绕过**: Maintainer 在 PR 描述签名 `<!-- emergency-bypass -->` 块，Gate 降级 PASS + 自动创建事后补审 issue

## Non-Functional Requirements

### NFR-1: 无外部依赖
- 所有工具均为 GitHub Actions runner 预装或通过 `pub.dev` / `pip` 安装
- 不依赖外部 SaaS 服务、不部署常驻进程
- 认证仅用 `GITHUB_TOKEN`（Actions 自动注入）

### NFR-2: 不误杀
- 工具故障 / API 限流 / workflow 自身异常时永远 exit 0（不阻断合并）
- 降级时必须在 Summary 评论中显式标注"不可靠"，让 Maintainer 知道需人工确认

### NFR-3: 可观测性
- pr-gate 每次运行在 PR 下发布/更新一条 Summary 评论，含检查项结果表格
- precheck 每项 Check 的 `$GITHUB_STEP_SUMMARY` 写入详细结果
- 安全扫描产物（SARIF）上传到 GitHub code scanning

### NFR-4: 跨平台兼容
- Bash 脚本兼容 Bash 3.2+（macOS）和 Bash 4+（Linux）
- Python 脚本兼容 3.9+
- 不使用 GNU 特有命令选项

## Constraints

- **技术**: GitHub Actions ubuntu-latest runner，预装工具集；Flutter stable channel；Python 3.11
- **安全**: PR 内容不出仓库（不接入第三方 SaaS）；`GITHUB_TOKEN` 权限最小化（仅 `pull-requests: write`、`statuses: write`、`issues: write`）
- **部署**: Branch Protection Rules 需在 GitHub Web UI 手动配置，存在 <5 分钟部署窗口期
- **团队**: 当前 solo 模式（1 Maintainer），审批要求自动降级

## Assumptions

1. 项目维护者愿意在评审评论中遵守 `[Blocker]/[Major]/[Minor]/[Nit]` 前缀约定
2. GitHub Actions 的 `GITHUB_TOKEN` 权限足以创建 Status Check 和 PR 评论
3. `package:analyzer` 的 API 在 Flutter stable channel 中可用且稳定
4. Branch Protection Rules 配置者拥有仓库 admin 权限
5. 团队规模增长到 ≥3 人时降级自动解除（无需改代码）

## Acceptance Criteria

### AC-1: pr-precheck 8 项 Check 落地
- **Given**: 一个包含 `error •` 的 Flutter 文件的 PR
- **When**: pr-precheck workflow 运行
- **Then**: `precheck / analyze` Check 显示红色 FAIL，其余 7 项仍执行（不被取消）
- **Verification**: `programmatic` — 在 PR Checks 标签页观察到 8 个独立 Status Check，FAIL 的项为红色

### AC-2: pr-gate 强门禁阻断
- **Given**: 一个 PR 有 1 条未解决的 `[Blocker]` 评论
- **When**: pr-gate workflow 运行
- **Then**: `pr-gate / gate-check` Check 显示红色 FAIL，Summary 评论列出未解决 Blocker，GitHub Merge 按钮灰掉
- **Verification**: `programmatic` — Status Check state = failure

### AC-3: 严重级别前缀解析
- **Given**: 一条不含 `[Blocker]/[Major]/[Minor]/[Nit]` 前缀的评审评论
- **When**: pr-gate 运行评论解析
- **Then**: 该评论被归入 `unprefixed` 列表，Summary 评论显示警告"3 条评论未标注严重级别"，但不阻断合并
- **Verification**: `programmatic` — Summary 评论包含"未标注"警告

### AC-4: Waiver 证据块校验
- **Given**: 一个 PR 有 1 条未解决 `[Major]` 评论，PR 描述含合法 waiver 块（signed-by 是 Maintainer，issue 存在）
- **When**: pr-gate 运行 Waiver 校验
- **Then**: 该 Major 被标记为 waived，Gate Check PASS
- **Verification**: `programmatic` — Summary 评论显示"Waiver 校验: ✅ 全部通过"

### AC-5: Solo 降级
- **Given**: CODEOWNERS 中仅 1 名 Maintainer
- **When**: 核心模块 PR 提交
- **Then**: 审批要求自动降级为 ≥1，Summary 评论标注"⚠️ Solo 模式"
- **Verification**: `programmatic` — Summary 评论包含"Solo 模式"标注

### AC-6: 紧急绕过
- **Given**: PR 描述含 `<!-- emergency-bypass -->` 块，signed-by 是 Maintainer
- **When**: pr-gate 运行
- **Then**: Gate Check 降级为 PASS，Summary 评论标注"🚨 紧急绕过"，自动创建 `post-review` label 的 issue
- **Verification**: `programmatic` — issue 被创建且含 label `post-review` + `emergency-bypass`

### AC-7: 工具缺失降级
- **Given**: runner 上未安装 `shellcheck`
- **When**: `precheck / lint-shell` 运行
- **Then**: Check 显示绿色 PASS，Step Summary 含 `::warning::shellcheck 未安装，跳过`
- **Verification**: `programmatic` — Status Check state = success

### AC-8: API 限流降级
- **Given**: GitHub API 返回 403 + `X-RateLimit-Remaining: 0`
- **When**: pr-gate 调用 API
- **Then**: 若剩余等待 <5min 则 sleep 重试；若 >5min 则 Gate 降级 PASS，Summary 评论标注"⚠️ API 限流，结果不可靠"
- **Verification**: `programmatic` — Summary 评论包含"API 限流"标注

## Open Questions

- [ ] **问题 1**: `package:analyzer` 作为 dev_dependency 添加到 pubspec.yaml 后，是否会影响 `flutter pub get` 在 CI 中的执行时间？是否需要单独的 `tool/pubspec.yaml`？
- [ ] **问题 2**: `issue_comment` 事件触发时，`pr-gate.py` 需要反查 PR 编号。如果评论是在普通 issue（非 PR）下，脚本是否会正确跳过？需确认 `github.event.issue.pull_request` 字段判断逻辑。
- [ ] **问题 3**: 紧急绕过自动创建的 `post-review` issue 是否应该自动分配给 PR 作者？当前设计未指定 assignee。
