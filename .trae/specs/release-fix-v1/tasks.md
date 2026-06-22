# 发布流程问题修复 - 实施计划

## [x] Task 1: 跨平台 sed 替换 - 修复 release.sh 中 6 处 sed -i 调用

- **Priority**: P0
- **Depends On**: None
- **Description**:
  - 在 `scripts/release.sh` 中引入 `sed_inplace()` 辅助函数，根据 `uname -s` 自动选择 BSD sed 或 GNU sed 的正确语法
  - 替换第 183、187、188、192、193、197 行共 6 处 `sed -i` 硬编码调用
  - 方案选择: 用 `uname` 检测 + 条件分支，而非引入 `perl`，以符合 NFR-4（无新依赖）
- **Acceptance Criteria Addressed**: FR-1, AC-1
- **Test Requirements**:
  - `programmatic` TR-1.1: `bash -n scripts/release.sh` 语法检查通过
  - `programmatic` TR-1.2: 在 Linux 环境下，`uname -s` 返回 "Linux" 时选择 GNU sed 路径
  - `programmatic` TR-1.3: 在 macOS 模拟环境下（`uname -s` 返回 "Darwin"）选择 BSD sed 路径
  - `programmatic` TR-1.4: 手动执行 dry-run 后，对测试文件执行 `sed_inplace "s/old/new/" test_file` 后内容正确更新，无 `.bak` 残留
  - `human-judgment` TR-1.5: 新函数命名有意义、注释清晰、中文注释解释为什么要做 OS 检测
- **Notes**: 函数定义放置在 `release.sh` 颜色/日志函数之后，主流程之前的位置（约第 33 行）

---

## [x] Task 2: 精确文件提交 - 替换 release.sh 的 `git add -A`

- **Priority**: P0
- **Depends On**: None
- **Description**:
  - 将 `scripts/release.sh` 第 258 行的 `git add -A` 替换为显式文件列表：`git add frontend/pubspec.yaml frontend/android/app/build.gradle frontend/lib/utils/version.dart backend/core/version.py CHANGELOG.md`
  - 为防止未来添加新文件时遗漏，同时在此步骤前输出将被添加的文件列表供日志审阅
- **Acceptance Criteria Addressed**: FR-2, AC-2
- **Test Requirements**:
  - `programmatic` TR-2.1: 在干净工作树中创建临时文件 `test.log`，执行 dry-run，然后查看 `git diff --cached` 不包含 `test.log`
  - `programmatic` TR-2.2: `bash -n scripts/release.sh` 语法检查通过
  - `human-judgment` TR-2.3: 新代码中文件列表中的路径与 `sed` 修改的文件一致（即实际会被修改的文件）
  - `human-judgment` TR-2.4: 有清晰的日志说明"仅添加以下发布相关文件"
- **Notes**: Task 2 与 Task 1 修改的是同一文件，但彼此独立，可以任意顺序实施

---

## [x] Task 3: release.sh 命令存在性检查

- **Priority**: P0
- **Depends On**: None
- **Description**:
  - 在 `release.sh` 脚本开头（`set -euo pipefail` 之后，主流程开始之前）添加命令存在性检查块
  - 检查命令: `git`、`sed`、`grep`、`awk`
  - 缺失任一命令时打印清晰的错误消息并以非 0 码退出
  - 使用现有 `log_error` 函数保持输出风格一致
- **Acceptance Criteria Addressed**: FR-3, AC-3
- **Test Requirements**:
  - `programmatic` TR-3.1: `bash -n scripts/release.sh` 语法检查通过
  - `programmatic` TR-3.2: 以 `command -v git >/dev/null 2>&1` 风格检查，与 `verify-release.sh` 中现有检查一致
  - `human-judgment` TR-3.3: 错误消息包含中文说明"请安装后重试"等提示
  - `human-judgment` TR-3.4: 检查代码位置在脚本开头（版本解析之前），不会因变量未定义而提前失败
- **Notes**: `flutter` 命令只在 CI/本地实际构建时需要，本地仅执行 dry-run 不需要 flutter，故不强制检查；但 dry-run 文档中应注明 flutter 在正式发布时才需要

---

## [x] Task 4: CI keystore 文件权限设置

- **Priority**: P0
- **Depends On**: None
- **Description**:
  - 在 `.github/workflows/android-release.yml` 的签名文件还原 step 中（第 163-176 行），在 `base64 -d` 之后、`ls -lh` 之前添加 `chmod 600`
  - 添加权限验证日志（`stat` 或 `ls -l` 输出权限）
- **Acceptance Criteria Addressed**: FR-4, AC-4
- **Test Requirements**:
  - `programmatic` TR-4.1: YAML 语法有效（`yamllint` 或 `python -c "import yaml; yaml.safe_load(...)"`）
  - `human-judgment` TR-4.2: `chmod 600` 命令在 `base64 -d` 写入文件之后、`ls -lh` 之前，顺序正确
  - `human-judgment` TR-4.3: step 内使用 `${{ secrets.ANDROID_KEYSTORE }}` 的处理方式保持不变
- **Notes**: 仅修改 shell 命令行，不改变 workflow 结构

---

## [x] Task 5: 修复 rollback-release.sh 错误消息

- **Priority**: P1
- **Depends On**: None
- **Description**:
  - 修改 `scripts/rollback-release.sh` 第 149 行的矛盾消息
  - 从"已存在或不存在，跳过"改为"远程 tag origin/$CURRENT_TAG 不存在，跳过"
- **Acceptance Criteria Addressed**: FR-5, AC-5
- **Test Requirements**:
  - `programmatic` TR-5.1: `bash -n scripts/rollback-release.sh` 语法检查通过
  - `human-judgment` TR-5.2: 消息语义与 `if git ls-remote ... | grep -q ...` 的 else 分支逻辑匹配（tag 不存在时进入此分支）
  - `human-judgment` TR-5.3: 消息文本与 `log_warn` 函数风格一致
- **Notes**: 本次最小修改，不重构整个回滚流程

---

## [x] Task 6: 验证测试 - 综合回归

- **Priority**: P0
- **Depends On**: Task 1, Task 2, Task 3, Task 4, Task 5
- **Description**:
  - `bash -n` 对所有修改的脚本进行语法检查
  - 在干净工作树中执行 `./scripts/release.sh --dry-run patch` 预览
  - 执行 `./scripts/verify-release.sh` 验证当前版本号一致性
  - 检查工作树是否被脚本修改（仅 dry-run 应不修改任何文件）
  - 对 `android-release.yml` 进行 YAML 语法验证
- **Acceptance Criteria Addressed**: NFR-1, NFR-3
- **Test Requirements**:
  - `programmatic` TR-6.1: `bash -n scripts/release.sh scripts/verify-release.sh scripts/rollback-release.sh` 全部返回 exit 0
  - `programmatic` TR-6.2: `./scripts/release.sh --dry-run patch` 正常输出并退出 0
  - `programmatic` TR-6.3: `./scripts/verify-release.sh` 输出通过（ERRORS=0）
  - `programmatic` TR-6.4: dry-run 执行后 `git status` 显示无工作树变更
  - `human-judgment` TR-6.5: dry-run 输出中显示新版本号、将修改的文件列表等有用信息
- **Notes**: Task 6 是唯一的综合验证任务，必须在所有 Task 1-5 完成后执行

---

## 任务依赖关系图

```
Task 1 (sed 跨平台) ─┐
Task 2 (精确文件提交) ─┤
Task 3 (命令检查)     ─┤  ──→ Task 6 (综合验证)
Task 4 (keystore 权限) ─┤
Task 5 (错误消息修复) ─┘
```

Task 1-5 为并行任务（相互独立），Task 6 必须等待 1-5 全部完成。

## 实施顺序建议（考虑文件局部性）

1. **首先修改 `scripts/release.sh`**（Task 1 + Task 2 + Task 3，同一文件，可一次性完成）
2. **然后修改 `.github/workflows/android-release.yml`**（Task 4）
3. **然后修改 `scripts/rollback-release.sh`**（Task 5）
4. **最后运行验证**（Task 6）

总计修改文件: 3 个脚本 + 1 个 workflow = 4 个文件
