# 发布流程代码审查 - 任务分解与实施计划

## [ ] Task 1: 代码风格一致性审查

- **Priority**: P0
- **Depends On**: None
- **Description**: 
  - 逐行审查 5 个变更文件的命名、缩进、注释和代码组织风格
  - 确认所有变量和函数命名有意义、一致
  - 确认脚本头部注释完整（shebang、功能描述、使用示例）
  - 确认函数遵循单一职责原则
  - 确认中文注释简洁清晰，解释"为什么"而非"做什么"
- **Files to Review**:
  - `scripts/release.sh` — 289 行，发布脚本
  - `scripts/verify-release.sh` — 274 行，验证脚本
  - `scripts/rollback-release.sh` — 163 行，回滚脚本
  - `.github/workflows/android-release.yml` — 443 行，CI 工作流
  - `Makefile` — 15+ 行，构建目标
- **Acceptance Criteria Addressed**: FR-1, AC-1
- **Test Requirements**:
  - `programmatic` TR-1.1: 确认所有 3 个 .sh 脚本都有 `#!/bin/bash` 作为首行
  - `programmatic` TR-1.2: 确认所有脚本都设置了 `set -euo pipefail` 或等效的安全模式
  - `programmatic` TR-1.3: 确认没有单字母变量名（如 `$a`、`$b`、`$x`），除了公认的循环变量
  - `programmatic` TR-1.4: 检查缩进是否统一（搜索混 tab 和空格的行）
  - `programmatic` TR-1.5: 确认脚本都有使用说明（Usage/示例）注释
  - `human-judgment` TR-1.6: 评估每个脚本的函数是否遵循单一职责原则（每个函数是否只做一件事）
  - `human-judgment` TR-1.7: 评估注释是否解释"为什么"而非"做什么"
  - `human-judgment` TR-1.8: 评估代码组织是否合理（相关逻辑是否放在一起）
- **Notes**: 重点关注三个 Bash 脚本中的命名一致性和函数抽象是否合理

---

## [ ] Task 2: 错误处理完整性审查

- **Priority**: P0
- **Depends On**: None
- **Description**: 
  - 检查所有可能失败的操作是否有错误处理
  - 验证 `set -euo pipefail` 的设置和行为
  - 检查空值/空字符串处理
  - 验证文件测试运算符使用正确
  - 检查脚本退出码是否有意义
- **Acceptance Criteria Addressed**: FR-2, AC-2
- **Test Requirements**:
  - `programmatic` TR-2.1: 检查 `release.sh` 中 `git tag` 命令失败时的处理（tag 已存在的情况）
  - `programmatic` TR-2.2: 检查 `release.sh` 中 `git push` 失败时的处理
  - `programmatic` TR-2.3: 检查 `verify-release.sh` 中文件不存在时的处理（第 100-105 行 check_file_exists）
  - `programmatic` TR-2.4: 检查 `rollback-release.sh` 中 tag 不存在时的处理
  - `programmatic` TR-2.5: 检查 CI workflow 中每个 step 的失败处理（`if: failure()` 是否存在）
  - `programmatic` TR-2.6: 验证 `set -o pipefail` 是否能正确捕获管道失败
  - `human-judgment` TR-2.7: 评估错误信息是否用户友好（告诉用户怎么修复）
  - `human-judgment` TR-2.8: 检查失败场景是否保留了足够诊断信息
  - `programmatic` TR-2.9: 检查对 `$CURRENT_CODE`、`$NEW_VERSION` 等变量的空值处理
- **Notes**: `set -e` 与 `if cmd; then` 模式的相互作用需要特别注意 — `if` 中的命令失败不会触发 errexit

---

## [ ] Task 3: 安全性检查

- **Priority**: P0
- **Depends On**: None
- **Description**: 
  - 审查签名密钥和密码的处理方式
  - 检查日志输出中是否有敏感信息泄露
  - 验证文件权限设置
  - 检查命令存在性检查
  - 检查输入验证和命令注入风险
- **Acceptance Criteria Addressed**: FR-3, AC-3
- **Test Requirements**:
  - `programmatic` TR-3.1: grep 搜索所有脚本中是否有硬编码密码/密钥字符串（搜索 "password"、"secret"、"pwd" 等）
  - `programmatic` TR-3.2: 检查 CI workflow 中是否正确使用 `${{ secrets.XXX }}` 而非硬编码
  - `programmatic` TR-3.3: 检查 `release.sh` 中 `printf` 写入 key.properties 是否在日志中输出密码内容（注意：第 170-172 行的 printf 应该不会输出密码）
  - `human-judgment` TR-3.4: 评估 keystore 文件的权限设置（创建后是否应设置 `chmod 600`）
  - `programmatic` TR-3.5: 检查是否有 `command -v` 或 `which` 检查命令存在性
  - `human-judgment` TR-3.6: 评估用户输入的验证（交互式命令是否有格式校验）
  - `human-judgment` TR-3.7: 检查变量在 shell 命令中的使用是否安全（是否可能导致命令注入）
  - `programmatic` TR-3.8: 检查 CI workflow 中是否有 `echo "$SECRET_VAR"` 之类的敏感信息输出
- **Notes**: 特别关注 `android-release.yml` 第 163-176 行的签名配置还原逻辑 — 该逻辑正确地不在日志中输出密码内容

---

## [ ] Task 4: 性能影响评估

- **Priority**: P1
- **Depends On**: None
- **Description**: 
  - 审查 CI 缓存策略的有效性
  - 检查是否有重复计算或重复命令
  - 评估并行 vs 串行的工作流设计
  - 检查资源使用效率
- **Acceptance Criteria Addressed**: FR-4, AC-4
- **Test Requirements**:
  - `programmatic` TR-4.1: 检查 Gradle 缓存 key（第 144-150 行）是否基于文件 hash，restore-keys 是否合理
  - `programmatic` TR-4.2: 检查 Flutter cache（第 132-139 行）是否配置了合理的 cache-key
  - `programmatic` TR-4.3: 检查 Android SDK 缓存（第 153-160 行）路径和 key 是否合理
  - `human-judgment` TR-4.4: 评估 3 个 job 的串行依赖设计（pre-release-check → build-android → create-release）是否有优化空间
  - `human-judgment` TR-4.5: 检查是否有不必要的重复 grep/find 命令（如重复执行相同的 grep）
  - `programmatic` TR-4.6: 检查 `release.sh` 中 `sed` 执行的次数和是否可以合并
  - `human-judgment` TR-4.7: 评估构建产物的大小对上传/下载的影响（APK、AAB 是否需要压缩）
  - `human-judgment` TR-4.8: 检查 Gradle daemon 是否正确配置和预热（第 179-188 行）
- **Notes**: CI 缓存是性能优化的关键 — 首次构建可能较慢，但后续构建应显著提速。需要验证缓存 key 是否能在文件未变更时正确命中

---

## [ ] Task 5: 可维护性分析

- **Priority**: P1
- **Depends On**: None
- **Description**: 
  - 审查代码结构、注释和文档
  - 检查魔法数字和硬编码字符串
  - 评估变量作用域和常量使用
  - 检查脚本之间的代码重复
- **Acceptance Criteria Addressed**: FR-5, AC-5
- **Test Requirements**:
  - `programmatic` TR-5.1: 搜索三个脚本中重复出现的函数/代码块（log_info、log_success、颜色定义等）
  - `programmatic` TR-5.2: 搜索是否有 "TODO" 或 "FIXME" 标记
  - `programmatic` TR-5.3: 检查是否使用 `local` 关键字标记函数内变量
  - `programmatic` TR-5.4: 检查是否有 `readonly` 或常量标记
  - `programmatic` TR-5.5: 搜索脚本中的魔法数字（如 `100`、`256`、`21` 等无注释的数字）
  - `programmatic` TR-5.6: 检查硬编码路径和文件名（如 `frontend/pubspec.yaml`、`embbytok-keystore.jks`）是否应该提取为变量
  - `human-judgment` TR-5.7: 评估每个脚本的整体结构是否清晰（标题/分节是否清楚）
  - `human-judgment` TR-5.8: 评估 Makefile 目标的文档完整性
  - `human-judgment` TR-5.9: 评估 CI workflow 中每个 step 的 name 是否清晰描述其功能
- **Notes**: 3 个脚本中都有约 25-30 行的颜色定义和日志函数重复，这是提取公共模块的明显候选

---

## [ ] Task 6: 测试覆盖和边界条件审查

- **Priority**: P0
- **Depends On**: None
- **Description**: 
  - 审查 dry-run 模式的有效性
  - 检查 CI 中的发布前验证
  - 评估边界条件处理
  - 检查失败回滚机制
- **Acceptance Criteria Addressed**: FR-6, AC-6
- **Test Requirements**:
  - `programmatic` TR-6.1: 验证 `release.sh` dry-run 模式（第 162-176 行）是否覆盖了所有变更操作
  - `programmatic` TR-6.2: 验证 `rollback-release.sh` dry-run 模式（第 69-72、116-122 行）的完整性
  - `programmatic` TR-6.3: 验证 `verify-release.sh` 在 CI 中是否执行（第 67-73 行）
  - `human-judgment` TR-6.4: 评估边界条件：空版本号、脏 Git 工作树、网络失败、tag 已存在
  - `human-judgment` TR-6.5: 评估发布后失败的回滚策略（当前方案：手动删除 GitHub Release + 本地 git tag 操作）
  - `human-judgment` TR-6.6: 检查 `release.sh` 是否检查了 `flutter` 和 `git` 命令是否存在
  - `programmatic` TR-6.7: 检查 `verify-release.sh` 中 `--with-tests` 和 `--with-analyze` 选项（第 219-249 行）是否合理
  - `human-judgment` TR-6.8: 评估交互式确认（y/N）是否安全，默认为 No
  - `programmatic` TR-6.9: 验证 `make verify-release` 在干净工作树中应成功
- **Notes**: dry-run 模式是脚本测试的核心手段 — 它应该准确预览所有变更操作，不含任何遗漏

---

## [ ] Task 7: 生成审查报告和修复建议

- **Priority**: P0
- **Depends On**: Task 1, Task 2, Task 3, Task 4, Task 5, Task 6
- **Description**: 
  - 汇总所有任务中发现的问题
  - 按严重性分类（严重问题/建议/通过项）
  - 生成最终审查报告
  - 给出总体评价
- **Acceptance Criteria Addressed**: 所有 FR 和 AC 的汇总输出
- **Test Requirements**:
  - `human-judgment` TR-7.1: 审查报告格式是否清晰（✅通过 / ⚠️建议 / ❌问题）
  - `human-judgment` TR-7.2: 每个问题是否有具体的代码位置和修复建议
  - `human-judgment` TR-7.3: 总体评价（优秀/良好/需改进/不通过）是否合理
- **Notes**: 审查报告应使用中文撰写，面向项目维护者

---

## 任务优先级和依赖关系图

```
P0 任务（必须完成）:
├── Task 1: 代码风格一致性审查
├── Task 2: 错误处理完整性审查  
├── Task 3: 安全性检查
├── Task 6: 测试覆盖和边界条件审查
└── Task 7: 生成审查报告（依赖 Task 1-6）

P1 任务（重要但不阻塞）:
├── Task 4: 性能影响评估
└── Task 5: 可维护性分析
```

所有 P0 任务可以并行执行，Task 7 等待所有任务完成后执行。
