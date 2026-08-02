# 代码审查工作流 - 验证清单

## 脚本语法与结构验证

- [x] Checkpoint 1: `bash -n scripts/ci/_common.sh` 退出码 0
- [x] Checkpoint 2: 对 `scripts/ci/precheck-*.sh` 的 8 个脚本逐一执行 `bash -n`，全部退出码 0
- [ ] Checkpoint 3: `python3 -c "import ast; ast.parse(open('scripts/ci/pr-gate.py').read())"` 退出码 0
- [ ] Checkpoint 4: `python3 -c "import ast; ast.parse(open('scripts/ci/pr_gate_lib.py').read())"` 退出码 0
- [ ] Checkpoint 5: `dart analyze tool/lints/hardcoded_color_lint.dart` 退出码 0

## 功能逻辑验证

- [ ] Checkpoint 6: 正则 `^\s*\[(Blocker|Major|Minor|Nit)\]` 对 `[Blocker] test` 匹配成功，对 `test` 不匹配
- [ ] Checkpoint 7: `get_required_approvals(is_core=True, maintainers=['a'])` 返回 1（Solo 降级生效）
- [ ] Checkpoint 8: `get_required_approvals(is_core=True, maintainers=['a','b','c'])` 返回 2（核心模块需 2 审批）
- [ ] Checkpoint 9: Waiver 块解析器对合法格式（含 signed-by + issue + reason）提取成功
- [ ] Checkpoint 10: Waiver 块解析器对缺 `signed-by` 字段的格式提取失败
- [x] Checkpoint 11: `hardcoded_color_lint.dart` 对 `Color(0xFF1A1A1A)` 报违规且退出码 1
- [x] Checkpoint 12: `hardcoded_color_lint.dart` 对 `theme/app_theme.dart` 中的颜色不报违规（白名单生效）
- [x] Checkpoint 13: `hardcoded_color_lint.dart` 对 `Colors.transparent` 不报违规

## 降级策略验证

- [x] Checkpoint 14: 在无 `shellcheck` 的环境中执行 `precheck-lint-shell.sh`，退出码 0 且输出含 `::warning::shellcheck 未安装`
- [ ] Checkpoint 15: 在无 `bandit` 的环境中执行 `precheck-security.sh`，退出码 0 且输出含 `::warning::`（CORS grep 部分仍执行）
- [ ] Checkpoint 16: pr-gate.py 顶层 try/except 捕获模拟异常后 exit 0 且评论含"⚠️ Gate Check 工具故障"

## 配置文件验证

- [ ] Checkpoint 17: `yamllint -c .yamllint .github/workflows/android-release.yml` 退出码 0
- [ ] Checkpoint 18: `bandit -r backend/ -c .bandit` 退出码 0
- [ ] Checkpoint 19: `.github/CODEOWNERS` 文件格式正确，核心模块路径与 pr-gate.py 中的 CORE_MODULES 一致
- [ ] Checkpoint 20: `.github/PULL_REQUEST_TEMPLATE.md` 包含三栏必填 + Waiver 块占位 + 紧急绕过块占位

## Workflow YAML 验证

- [ ] Checkpoint 21: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/pr-precheck.yml'))"` 退出码 0
- [ ] Checkpoint 22: pr-precheck.yml 中 `matrix.check` 列表含 8 项（analyze/test/test-backend/lint-shell/lint-yaml/security/theme-tokens/pr-template）
- [ ] Checkpoint 23: pr-precheck.yml 中 `fail-fast: false` 存在
- [ ] Checkpoint 24: pr-precheck.yml 中 `permissions` 仅含 `contents: read` + `pull-requests: write` + `checks: write`
- [ ] Checkpoint 25: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/pr-gate.yml'))"` 退出码 0
- [ ] Checkpoint 26: pr-gate.yml 的 `if` 条件包含 `github.event.issue.pull_request != null`（排除非 PR issue_comment）
- [ ] Checkpoint 27: pr-gate.yml 的 `schedule.cron` 值为 `'0 */6 * * *'`
- [ ] Checkpoint 28: pr-gate.yml 中 `GITHUB_TOKEN` 通过 `env` 传入

## 部署完整性验证

- [ ] Checkpoint 29: 新增的 18 个文件全部存在于仓库中（2 workflow + 10 脚本 + 1 lint + 1 allowlist + 1 CODEOWNERS + 1 PR Template + 1 .yamllint + 1 .bandit）
- [ ] Checkpoint 30: `frontend/pubspec.yaml` 的 `dev_dependencies` 含 `analyzer` package
- [ ] Checkpoint 31: 部署指南文档存在且包含 7 步部署顺序
- [ ] Checkpoint 32: 部署指南中的 Required Status Checks 清单含 9 项（8 precheck + 1 pr-gate）
