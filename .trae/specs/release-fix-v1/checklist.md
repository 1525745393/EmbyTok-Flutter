# 发布流程问题修复 - 验证清单

> 每个检查点对应 tasks.md 中的测试要求（TR）。修复完成后将 `[ ]` 替换为 `[x]`。

---

## Task 1: sed 跨平台兼容修复

- [ ] **CL-1.1**: `scripts/release.sh` 中所有原有的 6 处 `sed -i` 已被替换为调用辅助函数或兼容的语法
- [ ] **CL-1.2**: 新添加的辅助函数（如 `sed_inplace`）根据 `uname -s` 正确区分 Linux/Darwin
- [ ] **CL-1.3**: 在 Linux 下 `sed_inplace "s/old/new/" filename` 能正确更新文件内容
- [ ] **CL-1.4**: 在 macOS 模拟下不会产生 `.bak` 或其他临时文件
- [ ] **CL-1.5**: `bash -n scripts/release.sh` 通过语法检查
- [ ] **CL-1.6**: 辅助函数有中文注释说明为什么需要 OS 检测

---

## Task 2: 精确文件提交修复

- [ ] **CL-2.1**: `scripts/release.sh` 中不再存在 `git add -A` 调用
- [ ] **CL-2.2**: 替换后的 `git add` 命令有显式文件列表，包含 5 个文件
- [ ] **CL-2.3**: 文件列表与实际会被 `sed` 修改的文件完全一致
- [ ] **CL-2.4**: 添加前有日志输出告知将添加的文件，便于审查
- [ ] **CL-2.5**: `bash -n scripts/release.sh` 通过语法检查

---

## Task 3: 命令存在性检查修复

- [ ] **CL-3.1**: `scripts/release.sh` 中新增了命令存在性检查（检查 `git`、`sed`、`grep`、`awk`）
- [ ] **CL-3.2**: 检查位置在 `set -euo pipefail` 之后、主流程开始之前
- [ ] **CL-3.3**: 使用 `command -v cmd >/dev/null 2>&1` 语法（与 verify-release.sh 保持一致）
- [ ] **CL-3.4**: 缺失命令时输出中文错误消息并以非 0 码退出
- [ ] **CL-3.5**: `bash -n scripts/release.sh` 通过语法检查

---

## Task 4: CI keystore 权限修复

- [ ] **CL-4.1**: `.github/workflows/android-release.yml` 中签名文件创建后的 `chmod 600` 命令在 `base64 -d` 之后、`ls -lh` 之前
- [ ] **CL-4.2**: 添加了权限验证日志（如 `stat` 或 `ls -l`）
- [ ] **CL-4.3**: YAML 语法有效（可通过 yamllint 或手动验证）
- [ ] **CL-4.4**: 不改变 `${{ secrets.ANDROID_KEYSTORE }}` 的处理方式
- [ ] **CL-4.5**: step 结构完整无缩进错误

---

## Task 5: rollback 错误消息修复

- [ ] **CL-5.1**: `scripts/rollback-release.sh` 中已不存在"已存在或不存在"的矛盾文本
- [ ] **CL-5.2**: 新消息清晰表达"远程 tag ... 不存在，跳过"
- [ ] **CL-5.3**: `bash -n scripts/rollback-release.sh` 通过语法检查
- [ ] **CL-5.4**: 消息与 `if` 判断的 else 分支语义匹配

---

## Task 6: 综合验证

- [ ] **CL-6.1**: `bash -n scripts/release.sh scripts/verify-release.sh scripts/rollback-release.sh` 全部 exit 0
- [ ] **CL-6.2**: `./scripts/release.sh --dry-run patch` 正常执行并 exit 0，输出包含新版本号和将修改的文件列表
- [ ] **CL-6.3**: `./scripts/verify-release.sh` 输出 ERRORS=0（在当前版本号状态）
- [ ] **CL-6.4**: dry-run 执行后 `git status` 显示无工作树变更（脚本未修改任何文件）
- [ ] **CL-6.5**: dry-run 输出格式清晰、颜色正常，与修复前的 dry-run 输出格式风格一致
- [ ] **CL-6.6**: `.github/workflows/android-release.yml` 的 YAML 结构完整无语法错误（缩进一致）
- [ ] **CL-6.7**: 没有引入新的外部依赖或新的命令调用超出 Constraints 范围

---

## 提交前最终检查

- [ ] **CL-F1**: 所有修改的 4 个文件（release.sh, rollback-release.sh, android-release.yml）都符合现有代码风格（4 空格缩进、颜色日志、中文注释）
- [ ] **CL-F2**: 没有在修复过程中意外修改 Makefile 或 verify-release.sh 中未计划的部分
- [ ] **CL-F3**: 修复后与 CI workflow 中签名步骤的行数不改变 job 名称或顺序
- [ ] **CL-F4**: 没有引入未在 Non-Goals 之外的功能（如未添加 `_common.sh`）
- [ ] **CL-F5**: 所有修改可在 Linux 下通过 `bash -n` 语法检查
- [ ] **CL-F6**: 所有修改在 macOS 下通过 dry-run 验证（如无 macOS 环境则通过代码审查确认）

---

## 验证结果汇总

| 任务 | 通过检查点 | 状态 |
|------|-----------|------|
| Task 1 (sed) | __ / 6 | __ |
| Task 2 (git add) | __ / 5 | __ |
| Task 3 (命令检查) | __ / 5 | __ |
| Task 4 (keystore) | __ / 5 | __ |
| Task 5 (错误消息) | __ / 4 | __ |
| Task 6 (综合) | __ / 7 | __ |
| **总计** | **__ / 32** | **__** |
