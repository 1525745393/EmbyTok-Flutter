# 代码审查工作流部署指南

> 本文档指导团队按正确顺序部署代码审查工作流，并配置 GitHub Branch Protection Rules。
> 配套文档：[`docs/code-review.md`](./code-review.md)（审查标准与流程）

---

## 1. 概述

代码审查工作流由两层门禁组成，将 `docs/code-review.md` 中的审查标准落地为可自动执行的 CI 门禁：

- **pr-precheck（自动化检查层）**：PR 提交时自动运行 **8 项**检查，覆盖代码质量、测试、安全、规范四个维度。任一检查失败即阻断合并。
- **pr-gate（人工评审强门禁层）**：基于 GitHub API 解析 Reviewer 评论的严重级别前缀（`[Blocker]`/`[Major]`/`[Minor]`/`[Nit]`），结合审批人数、核心模块识别、Waiver 证据块校验，输出 PASS/FAIL 的 Status Check。

**工作流组成**：2 个 GitHub Actions workflow（`pr-precheck.yml` + `pr-gate.yml`）+ 18 个支持文件（CI 脚本、lint 工具、配置文件）。

### 8 项自动化检查（pr-precheck）

| 检查项 | 脚本 | 作用 |
| --- | --- | --- |
| `analyze` | `scripts/ci/precheck-analyze.sh` | `flutter analyze` 零 error |
| `test` | `scripts/ci/precheck-test.sh` | `flutter test` 全绿 |
| `test-backend` | `scripts/ci/precheck-test-backend.sh` | 后端 pytest 通过 |
| `lint-shell` | `scripts/ci/precheck-lint-shell.sh` | Shell 脚本 shellcheck |
| `lint-yaml` | `scripts/ci/precheck-lint-yaml.sh` | YAML 文件 yamllint |
| `security` | `scripts/ci/precheck-security.sh` | Python 安全 bandit 扫描 |
| `theme-tokens` | `scripts/ci/precheck-theme-tokens.sh` | 硬编码颜色检测（自定义 lint） |
| `pr-template` | `scripts/ci/precheck-pr-template.sh` | PR 描述三栏完整性校验 |

---

## 2. 前置条件

- **GitHub 仓库 admin 权限**：配置 Branch Protection Rules 需要 admin 角色。
- **Flutter / Python 开发环境**：项目已有的本地开发环境，确保 CI 脚本在本地可验证。
- **CODEOWNERS 已维护**：`.github/CODEOWNERS` 中需列出 Maintainer 的 GitHub login，pr-gate 依赖此文件判断团队规模与 Waiver 签名权限。

---

## 3. 部署顺序（7 步）

> ⚠️ 必须严格按以下顺序执行。步骤 1-4 合并纯代码文件（不触发 workflow），步骤 5 激活 workflow，步骤 6 配置 Branch Protection。

### 步骤 1：合并 `scripts/ci/` 下的所有脚本

合并以下 12 个文件（共享库 + 8 个 precheck 脚本 + pr-gate 逻辑 + 依赖声明）：

```
scripts/ci/
├── _common.sh                    # CI 共享工具函数库（日志 + 工具检测）
├── precheck-analyze.sh           # flutter analyze 检查
├── precheck-test.sh              # flutter test 检查
├── precheck-test-backend.sh      # 后端 pytest 检查
├── precheck-lint-shell.sh        # shellcheck 检查
├── precheck-lint-yaml.sh         # yamllint 检查
├── precheck-security.sh          # bandit 安全扫描
├── precheck-theme-tokens.sh      # 硬编码颜色检测
├── precheck-pr-template.sh       # PR 模板完整性校验
├── pr-gate.py                    # 人工评审强门禁主逻辑
├── pr_gate_lib.py                # GitHub API 封装库
└── requirements.txt              # pr-gate Python 依赖
```

**验证**：`chmod +x scripts/ci/precheck-*.sh` 确保脚本有可执行权限。

### 步骤 2：合并 `frontend/tool/lints/`

合并 Flutter 自定义 lint 工具（被 `precheck-theme-tokens.sh` 调用）：

```
frontend/tool/lints/
├── hardcoded_color_lint.dart       # 硬编码颜色检测 lint
└── hardcoded_color_allowlist.json  # 颜色白名单
```

### 步骤 3：合并配置文件

合并以下 4 个配置文件：

| 文件 | 作用 |
| --- | --- |
| `.yamllint` | yamllint 规则配置（被 `precheck-lint-yaml.sh` 读取） |
| `.bandit` | bandit 安全扫描配置（被 `precheck-security.sh` 读取） |
| `.github/CODEOWNERS` | 维护者列表（pr-gate 读取以判断团队规模与签名权限） |
| `.github/PULL_REQUEST_TEMPLATE.md` | PR 模板（三栏：改了什么 / 为什么 / 如何验证） |

### 步骤 4：合并 `scripts/build-android.sh`

合并 CI 构建脚本（Android 发布构建用）：

```
scripts/build-android.sh
```

> 步骤 1-4 均为纯代码文件，不含 workflow 定义，合并后不会触发任何 CI 检查。

### 步骤 5：激活 workflow

合并以下 2 个 workflow 文件——**此时 CI 开始运行，Status Check 开始出现在 PR 上**：

```
.github/workflows/pr-precheck.yml   # 8 项自动化检查
.github/workflows/pr-gate.yml       # 人工评审强门禁
```

> ⚠️ 此步骤完成后、步骤 6 完成前存在窗口期（见第 4 节），请勿在此期间合并任何 PR。

### 步骤 6：配置 Branch Protection Rules

进入 GitHub 仓库 **Settings → Branches → Branch protection rules**，点击 **Add rule**，按以下配置：

- **Branch name pattern**：`main`
- ☑ **Require a pull request before merging**
  - ☑ **Require approvals**: `1`
    > GitHub 原生最低值。实际审批人数校验由 `pr-gate.py` 执行：非核心模块 ≥1，核心模块 ≥2，Solo 模式（Maintainer ≤2 人）降级为 ≥1。
- ☑ **Require status checks to pass before merging**
  - **Required checks**（共 **9 项**，必须与下方清单完全一致）：
    ```
    precheck / analyze
    precheck / test
    precheck / test-backend
    precheck / lint-shell
    precheck / lint-yaml
    precheck / security
    precheck / theme-tokens
    precheck / pr-template
    pr-gate / gate-check
    ```
  - ☑ **Require branches to be up to date before merging**
- ☑ **Require conversation resolution before merging**
- ☑ **Do not allow bypassing the above settings**

> **如何添加 Required checks**：在搜索框中输入上述名称，从下拉列表中选择。若某项未出现，说明对应 workflow 尚未在任何 PR 上运行过——先提交一个测试 PR 触发 workflow，待运行完成后即可在列表中找到。

### 步骤 7：团队通知

通知所有 Reviewer 与 Maintainer 以下约定：

1. **评论前缀强制**：所有评审评论必须以 `[Blocker]` / `[Major]` / `[Minor]` / `[Nit]` 前缀开头，否则 pr-gate 不计入评审结论（仅标记为 unprefixed 警告）。
2. **PR 描述三栏必填**：必须填写「改了什么 / 为什么 / 如何验证」三栏，`precheck-pr-template` 会校验完整性。
3. **核心模块需 2 人审批**：播放器、鉴权、后端路由、发布流程的变更需 ≥2 名审批（Solo 模式除外）。

---

## 4. 部署窗口期说明

步骤 5（激活 workflow）与步骤 6（配置 Branch Protection）之间存在 **< 5 分钟**的窗口期：

- **workflow 已激活**：PR 上开始出现 Status Check。
- **Branch Protection 未配置**：此时 PR 仍可不经审查直接合并。

**应对措施**：部署者在此期间**不合并任何 PR**，并通知团队暂停 PR 合并操作，直至步骤 6 配置完成。

---

## 5. 降级策略说明

工作流设计了 5 种降级场景，确保 CI 故障不会阻塞正常开发流程：

| 场景 | 触发条件 | 降级行为 |
| --- | --- | --- |
| **工具缺失** | CI 环境未安装 shellcheck / bandit / yamllint 等 | 自动跳过该项检查 + 发出 GitHub Actions `::warning::` 注解（`exit 0`） |
| **API 限流** | GitHub API 限流，剩余等待 < 5min 则重试，> 5min 则降级 | < 5min：sleep 等待后重试；> 5min：Gate 降级为 PASS + 标注「⚠️ API 限流，结果不可靠」 |
| **Workflow 故障** | pr-gate 执行抛出非限流异常 | Gate 降级为 PASS + 标注「⚠️ Gate Check 工具故障，请人工确认」 |
| **Solo 模式** | CODEOWNERS 中 Maintainer ≤ 2 人 | 核心模块审批要求从 ≥2 降级为 ≥1，避免 PR 长期阻塞 |
| **紧急绕过** | Maintainer 在 PR 描述中签发 `emergency-bypass` 块 | Gate 降级为 PASS + 自动创建 post-review issue 追踪事后复核 |

> 降级 PASS 并非「无问题」，而是「不阻断合并」。Summary 评论会明确标注降级原因，Maintainer 需人工确认。

---

## 6. Reviewer 评论前缀约定

pr-gate 通过正则 `^\s*\[(Blocker|Major|Minor|Nit)\]` 识别评论严重级别。**不带前缀的评论不计入评审结论**。

| 前缀 | 级别 | 合并要求 |
| --- | --- | --- |
| `[Blocker]` | 阻断 | 必须解决或显式 resolve |
| `[Major]` | 严重 | 必须解决或有 Waiver |
| `[Minor]` | 次要 | 建议修复，不阻断 |
| `[Nit]` | 建议 | 可选 |

**示例**：

```
[Blocker] lib/views/feed_view.dart:142 SQL 注入风险
[Major] backend/api/routes/media.py:85 缺少权限检查
[Minor] lib/utils/colors.dart:30 命名不规范
[Nit] lib/widgets/card.dart:15 可以简化为 ternary
```

> **合并准入条件**：0 个未关闭的 Blocker；0 个未 waiver 的 Major；审批人数达标。

---

## 7. Waiver 使用说明

当 `[Major]` 问题无法立即修复但需要合并时，Maintainer 在 PR 描述中添加 Waiver 证据块：

```html
<!-- waiver: MAJOR-001
signed-by: @maintainer-login
issue: #123
reason: 临时豁免，将在 #123 中修复
-->
```

**校验规则**（`pr-gate.py` `validate_waivers`）：

- `signed-by` 必须在 `.github/CODEOWNERS` 维护者列表中。
- `issue` 必须存在且状态为 `open`。
- 四个字段（编号 / 签名 / issue / 原因）缺一不可，格式不符的块会被丢弃。

校验通过的 Waiver 会抵消对应数量的未解决 Major。

---

## 8. 紧急绕过说明

生产 P0 故障热修复时，Maintainer 在 PR 描述中添加紧急绕过块：

```html
<!-- emergency-bypass
signed-by: @maintainer-login
reason: 生产 P0 故障 hotfix
ticket: #INCIDENT-001
-->
```

**行为说明**：

- `signed-by` 必须在 CODEOWNERS 维护者列表中，否则绕过无效。
- 生效后 Gate 降级为 PASS，并自动创建带 `post-review` label 的 issue 追踪事后复核。
- ⚠️ **紧急绕过不跳过 pr-precheck**（代码质量检查仍执行），仅跳过人工评审流程。

---

## 9. 故障排查

| 现象 | 排查方向 |
| --- | --- |
| pr-gate Check 显示红色但 PR 可以合并 | 检查 Branch Protection 是否配置了 **Require status checks**，且 `pr-gate / gate-check` 在 Required checks 清单中 |
| pr-precheck 某项 Check 不执行 | 检查 `scripts/ci/precheck-<name>.sh` 是否有可执行权限（`chmod +x`）；查看 CI 日志是否有 `::warning::工具未安装` 降级提示 |
| Reviewer 评论未计入评审 | 检查评论是否以 `[Blocker]` / `[Major]` / `[Minor]` / `[Nit]` 前缀开头；多行评论中任意一行以前缀开头即可识别 |
| Waiver 校验失败 | 检查 `signed-by` 是否在 CODEOWNERS 中；检查 `issue` 编号是否存在且为 `open` 状态；检查四个字段是否齐全 |
| 紧急绕过未生效 | 检查 `signed-by` 是否在 CODEOWNERS 维护者列表中；检查 `ticket` 是否为整数 |
| Status Check 名称在 Branch Protection 搜索不到 | 该 workflow 需至少在一个 PR 上运行过才会出现；提交测试 PR 触发 workflow 后刷新 |
| Solo 模式未触发 | 检查 `.github/CODEOWNERS` 是否存在且格式正确；Maintainer 数量需 ≤ 2 才触发降级 |
