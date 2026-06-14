# 发布流程代码审查 - 验证清单

> 本清单用于验证 EmbyTok 发布流程代码审查的完整性。每个检查点对应 tasks.md 中的测试要求（TR）。审查完成后应将 `[ ]` 替换为 `[x]` 并附上简短备注。

---

## 1. 代码风格一致性（对应 Task 1）

- [ ] **CL-1.1**: 所有 3 个 .sh 脚本的首行都是 `#!/bin/bash`
  - 检查文件: `scripts/release.sh`, `scripts/verify-release.sh`, `scripts/rollback-release.sh`
  - 备注: ___

- [ ] **CL-1.2**: 所有脚本都设置了 `set -euo pipefail` 或等效的安全模式
  - 备注: ___

- [ ] **CL-1.3**: 没有使用无意义的单字母变量名（如 `$a`, `$b`），除了公认的循环变量
  - 备注: ___

- [ ] **CL-1.4**: 脚本缩进风格统一（2 空格或 4 空格，没有混用 tab 和空格）
  - 备注: ___

- [ ] **CL-1.5**: 每个脚本都有完整的使用说明（Usage/示例）注释
  - 备注: ___

- [ ] **CL-1.6**: 函数遵循单一职责原则（每个函数只做一件事，功能清晰）
  - 备注: ___

- [ ] **CL-1.7**: 注释解释"为什么"而非"做什么"，中文注释简洁清晰
  - 备注: ___

- [ ] **CL-1.8**: 代码组织合理，相关逻辑放在一起（参数解析、主要流程、辅助函数分区明确）
  - 备注: ___

---

## 2. 错误处理完整性（对应 Task 2）

- [ ] **CL-2.1**: `release.sh` 中 `git tag` 命令在 tag 已存在时是否有适当的错误提示
  - 位置: `scripts/release.sh` 第 271 行
  - 备注: ___

- [ ] **CL-2.2**: `release.sh` 中 `git push` 失败时是否有错误提示
  - 位置: `scripts/release.sh` 第 272-273 行
  - 备注: ___

- [ ] **CL-2.3**: `verify-release.sh` 中 `check_file_exists` 函数正确处理文件不存在情况
  - 位置: `scripts/verify-release.sh` 第 57-64 行
  - 备注: ___

- [ ] **CL-2.4**: `rollback-release.sh` 中 tag 不存在时的处理
  - 位置: `scripts/rollback-release.sh` 第 106-110 行
  - 备注: ___

- [ ] **CL-2.5**: CI workflow 中有 `if: failure()` 步骤保留诊断信息
  - 位置: `.github/workflows/android-release.yml` 第 343-352 行
  - 备注: ___

- [ ] **CL-2.6**: `set -o pipefail` 能正确捕获管道命令的失败
  - 备注: ___

- [ ] **CL-2.7**: 错误信息用户友好（告诉用户怎么修复），而非简单的"出错了"
  - 备注: ___

- [ ] **CL-2.8**: 失败时保留足够的诊断信息（退出码、上下文、日志）
  - 备注: ___

- [ ] **CL-2.9**: 关键变量（如 `$CURRENT_CODE`, `$NEW_VERSION`）有空值检查
  - 备注: ___

---

## 3. 安全性检查（对应 Task 3）

- [ ] **CL-3.1**: 脚本中没有硬编码的密码/密钥字符串
  - 搜索关键词: "password", "secret", "pwd", "key"
  - 备注: ___

- [ ] **CL-3.2**: CI workflow 中正确使用 `${{ secrets.XXX }}` 而非硬编码
  - 位置: `.github/workflows/android-release.yml` 第 107-111 行
  - 备注: ___

- [ ] **CL-3.3**: 签名配置还原过程不会在日志中泄露密码内容
  - 位置: `.github/workflows/android-release.yml` 第 163-176 行
  - 备注: ___

- [ ] **CL-3.4**: keystore 文件创建后是否设置了合适的权限（如 `chmod 600`）
  - 备注: ___

- [ ] **CL-3.5**: 脚本中有命令存在性检查（`command -v` 或 `which`）
  - 备注: ___

- [ ] **CL-3.6**: 用户输入有基本的格式校验（交互式命令）
  - 备注: ___

- [ ] **CL-3.7**: 变量在 shell 命令中的使用是安全的（没有明显的命令注入风险）
  - 备注: ___

- [ ] **CL-3.8**: CI workflow 中没有 `echo "$SECRET_VAR"` 之类的敏感信息输出
  - 备注: ___

---

## 4. 性能影响评估（对应 Task 4）

- [ ] **CL-4.1**: Gradle 缓存 key 基于文件 hash，restore-keys 合理
  - 位置: `.github/workflows/android-release.yml` 第 142-150 行
  - 备注: ___

- [ ] **CL-4.2**: Flutter cache 配置了合理的 cache-key（基于 pubspec.lock 或版本）
  - 位置: `.github/workflows/android-release.yml` 第 131-139 行
  - 备注: ___

- [ ] **CL-4.3**: Android SDK 缓存路径和 key 合理
  - 位置: `.github/workflows/android-release.yml` 第 153-160 行
  - 备注: ___

- [ ] **CL-4.4**: 3 个 job 的串行依赖设计是否合理（是否可以部分并行）
  - Job 依赖: pre-release-check → build-android → create-release
  - 备注: ___

- [ ] **CL-4.5**: 没有不必要的重复 grep/find 命令（检查脚本中的命令重复度）
  - 备注: ___

- [ ] **CL-4.6**: `release.sh` 中 `sed` 执行次数合理，是否可以合并
  - 备注: ___

- [ ] **CL-4.7**: 构建产物上传/下载大小评估（是否需要压缩）
  - 产物: APK, AAB, checksums.sha256
  - 备注: ___

- [ ] **CL-4.8**: Gradle daemon 预热和配置合理
  - 位置: `.github/workflows/android-release.yml` 第 179-188 行
  - 备注: ___

---

## 5. 可维护性分析（对应 Task 5）

- [ ] **CL-5.1**: 三个脚本中的颜色定义和日志函数重复（约 25-30 行），应考虑提取公共模块
  - 重复内容: `RED`, `GREEN`, `YELLOW`, `NC`, `log_info`, `log_success`, `log_warn`, `log_error`
  - 备注: ___

- [ ] **CL-5.2**: 脚本中是否有 TODO 或 FIXME 标记的未解决问题
  - 备注: ___

- [ ] **CL-5.3**: 函数内变量使用了 `local` 关键字，避免全局污染
  - 备注: ___

- [ ] **CL-5.4**: 使用了 `readonly` 或其他方式标记只读常量
  - 备注: ___

- [ ] **CL-5.5**: 魔法数字/硬编码字符串是否应该提取为变量（如 `21`, `34`, `256`）
  - 例子: minSdk=21, targetSdk=34, 256 校验和
  - 备注: ___

- [ ] **CL-5.6**: 硬编码路径和文件名应考虑提取为变量（如 `frontend/pubspec.yaml`）
  - 备注: ___

- [ ] **CL-5.7**: 每个脚本的整体结构清晰（标题/分节分隔明确）
  - 备注: ___

- [ ] **CL-5.8**: Makefile 目标都有简短描述（`##` 注释）
  - 备注: ___

- [ ] **CL-5.9**: CI workflow 中每个 step 的 name 都清晰描述了功能
  - 备注: ___

---

## 6. 测试覆盖和边界条件（对应 Task 6）

- [ ] **CL-6.1**: `release.sh` dry-run 模式覆盖了所有变更操作（不遗漏任何修改）
  - 位置: `scripts/release.sh` 第 162-176 行
  - 备注: ___

- [ ] **CL-6.2**: `rollback-release.sh` dry-run 模式完整
  - 位置: `scripts/rollback-release.sh` 第 69-72, 116-122 行
  - 备注: ___

- [ ] **CL-6.3**: CI workflow 中包含发布前验证（verify-release.sh）
  - 位置: `.github/workflows/android-release.yml` 第 67-73 行
  - 备注: ___

- [ ] **CL-6.4**: 边界条件: 空版本号、脏 Git 工作树、网络失败、tag 已存在
  - 每个条件的处理: ___

- [ ] **CL-6.5**: 发布失败的回滚策略明确（当前方案: 手动删除 GitHub Release）
  - 备注: ___

- [ ] **CL-6.6**: `release.sh` 检查了 `flutter` 和 `git` 命令是否存在
  - 备注: ___

- [ ] **CL-6.7**: `verify-release.sh` 的 `--with-tests` 和 `--with-analyze` 选项设计合理
  - 位置: `scripts/verify-release.sh` 第 219-249 行
  - 备注: ___

- [ ] **CL-6.8**: 交互式确认（y/N）安全，默认为 No
  - 位置: `scripts/rollback-release.sh` 第 131-137 行
  - 备注: ___

- [ ] **CL-6.9**: `make verify-release` 在干净工作树中应成功（已验证）
  - 备注: ___

---

## 7. 审查报告生成（对应 Task 7）

- [ ] **CL-7.1**: 审查报告格式清晰（✅通过 / ⚠️建议 / ❌问题）
  - 备注: ___

- [ ] **CL-7.2**: 每个问题都有具体的代码位置（文件名+行号）和修复建议
  - 备注: ___

- [ ] **CL-7.3**: 总体评价（优秀/良好/需改进/不通过）合理且有依据
  - 备注: ___

---

## 8. 补充检查项（Open Questions 相关）

- [ ] **CL-OQ-1**: `sed -i` 的 macOS/Linux 兼容性问题已处理或已记录为已知问题
  - sed -i "s/pattern/replacement/" file 在 macOS 上需要 -i ""
  - 备注: ___

- [ ] **CL-OQ-2**: `git add -A` 的安全性评估（是否需要更严格的文件选择）
  - 备注: ___

- [ ] **CL-OQ-3**: 是否需要提取公共函数库（如 `scripts/_common.sh`）
  - 备注: ___

- [ ] **CL-OQ-4**: debug 模式下 AAB 未构建时 create-release job 的处理
  - 备注: ___

- [ ] **CL-OQ-5**: "回滚"的定义和用户期望是否一致（是否包含代码回退）
  - 备注: ___

---

## 审查总结

| 分类 | 通过项数 | 问题数 | 建议数 |
|------|---------|-------|-------|
| 1. 代码风格一致性 | ___ / 8 | ___ | ___ |
| 2. 错误处理完整性 | ___ / 9 | ___ | ___ |
| 3. 安全性检查 | ___ / 8 | ___ | ___ |
| 4. 性能影响评估 | ___ / 8 | ___ | ___ |
| 5. 可维护性分析 | ___ / 9 | ___ | ___ |
| 6. 测试和边界条件 | ___ / 9 | ___ | ___ |
| **总计** | **___ / 51** | ___ | ___ |

### 总体评价: ___（优秀/良好/需改进/不通过）

### 审查者: ___
### 审查日期: ___
