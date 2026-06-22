# 发布流程问题修复 - Product Requirement Document

## Overview
- **Summary**: 根据代码审查报告，修复 EmbyTok 发布流程脚本和 CI workflow 中发现的 5 个问题，重点是跨平台兼容性、安全性和健壮性，确保在 macOS 和 Linux 环境下发布流程稳定可靠。
- **Purpose**: 消除发布流程中的已知风险，防止在 macOS 本地执行时 sed 失败导致错误版本发布，防止 `git add -A` 意外提交敏感文件，加强 CI 构建产物的安全权限。
- **Target Users**: 项目维护者（执行发布操作的开发者）、CI/CD 系统（自动发布流程）。

## Goals

1. **修复跨平台兼容性**: 确保 `release.sh` 在 macOS (BSD sed) 和 Linux (GNU sed) 上都能正确修改文件
2. **消除发布安全风险**: 将 `git add -A` 改为精确的文件列表，避免意外提交未跟踪的敏感文件
3. **增强命令健壮性**: 在 `release.sh` 中添加命令存在性检查，提供清晰的错误消息
4. **加强 CI 安全**: 在 Android 签名构建中正确设置 keystore 文件权限
5. **改进错误消息**: 修复 `rollback-release.sh` 中矛盾的错误文本

## Non-Goals (Out of Scope)

1. **添加公共函数库 `_common.sh`**: 虽然代码审查中建议提取，但属于较大重构，本轮修复不包含
2. **增加新功能（如单元测试开关、增强 dry-run 摘要）**: 属于增强功能，本轮不做
3. **重写 CI workflow 或添加新 job**: 仅修改现有 step，不改变整体结构
4. **修复 Makefile**: Makefile 审查结论为"良好"，无修复项
5. **升级 Flutter/Android SDK 版本**: 版本升级属于独立任务
6. **其他脚本的修复**（如 build-all.sh, docker-push.sh 等非发布流程脚本）

## Background & Context

**历史背景**: 此前的发布流程变更引入了自动化脚本，但仅在 Linux CI 环境测试过，未考虑 macOS 兼容性。同时，脚本的发布流程依赖 `set -e` 进行错误处理，但缺少对关键命令存在性的预检查。

**技术栈约束**:
- **Bash**: 需同时兼容 Bash 3.2+ (macOS) 和 Bash 4+ (Linux)
- **sed**: macOS 使用 BSD sed，Linux 使用 GNU sed，`-i` 参数行为不同
- **GitHub Actions runner**: ubuntu-latest，Bash 5.x
- **本地环境**: 同时有 macOS 和 Linux 开发者

**已识别的 5 个问题（来自代码审查报告）**:
1. `sed -i` 在 macOS 上行为不同，可能导致版本号更新失败
2. `git add -A` 会提交所有未跟踪文件，有潜在安全风险
3. `release.sh` 未检查 `git`、`flutter`、`sed` 等命令是否存在
4. CI workflow 中 keystore 文件创建后未设置 `chmod 600`
5. `rollback-release.sh` 第 149 行"已存在或不存在"的错误消息语义矛盾

## Functional Requirements

### FR-1: 跨平台 sed 替换

`release.sh` 中所有 `sed -i` 调用（6 处）必须同时兼容 GNU sed 和 BSD sed。

### FR-2: 精确的文件提交

`release.sh` 发布提交时必须只添加预期会修改的文件（pubspec.yaml、build.gradle、version.dart、version.py、CHANGELOG.md），不添加任何其他未跟踪文件。

### FR-3: 命令存在性预检查

`release.sh` 在开始版本号更新前，必须检查所有关键命令（`git`、`sed`、`grep`、`awk`）是否可用，缺失时输出清晰错误消息并退出。

### FR-4: CI keystore 权限设置

`android-release.yml` 中创建 keystore 文件后必须设置权限为 `600`（仅拥有者可读写），并在日志中显示权限验证结果。

### FR-5: 回滚脚本错误消息修复

`rollback-release.sh` 中矛盾的错误消息必须修正，逻辑清晰表达"远程 tag 不存在"。

## Non-Functional Requirements

### NFR-1: 行为一致性

修复后，所有脚本在 Linux CI 环境下的行为必须与修复前一致（即修复不应引入回归）。

### NFR-2: 可维护性

修复代码应保持原有的代码风格（4 空格缩进、颜色日志函数、中文注释）。

### NFR-3: 可验证性

修复后必须可通过以下方式验证：
1. `bash -n script.sh` 语法检查通过
2. `./scripts/release.sh --dry-run patch` 在干净仓库中正常输出
3. `./scripts/verify-release.sh` 报告无错误

### NFR-4: 无新依赖

修复过程**不得**引入任何新的外部依赖或第三方工具。

## Constraints

- **技术限制**: 必须使用 Bash 标准内置功能，不得引入 `python`、`perl`（除非特别简单）、`jq` 等非预装工具
- **向后兼容**: 修复不得改变 CI workflow 的 YAML 结构，不得改变 tag 命名约定 `vMAJOR.MINOR.PATCH`
- **最小修改原则**: 只改确认为问题的代码，不重构无问题的部分
- **安全约束**: 敏感操作（文件权限、文件删除）需有明确日志输出

## Assumptions

1. macOS 开发者的 `/bin/bash` 版本 ≥ 3.2（macOS 默认自带）
2. CI 环境使用 actions/checkout@v4，工作目录正确
3. `grep -E`、`awk`、`sort` 等命令在所有目标环境中存在且行为一致
4. `chmod` 命令在所有类 Unix 环境下使用相同的数字权限语法
5. 修复后无需立即打 tag 发布——维护者可自行决定是否发新版本测试

## Acceptance Criteria

### AC-1: sed 跨平台兼容修复
- **Given**: 在 macOS 或 Linux 上执行 `./scripts/release.sh patch`
- **When**: 脚本到达版本号更新步骤（修改 pubspec.yaml / build.gradle / version.dart / version.py）
- **Then**: 所有文件被正确更新，不产生 `.bak` 或其他临时文件，脚本不报错
- **Verification**: `programmatic` — 在本地用两种 sed 实现测试，或通过 `uname` 判断执行路径
- **Notes**: 推荐使用 `perl -pi -e` 替代 `sed -i`，或通过 OS 检测选择正确的 sed 语法

### AC-2: 精确文件提交
- **Given**: 项目根目录存在未跟踪的临时文件（例如 `test.log`、`local.properties`）
- **When**: 执行 `./scripts/release.sh patch`
- **Then**: 发布提交 (`git commit`) 只包含预期会被修改的 5 个文件，临时文件**不会**被添加
- **Verification**: `programmatic` — 通过在测试环境中创建临时文件并验证 `git diff --cached --name-only` 输出的文件列表

### AC-3: 命令存在性检查
- **Given**: 一个没有安装 `flutter` 的环境（但其他命令正常）
- **When**: 执行 `./scripts/release.sh patch`
- **Then**: 脚本应在执行到需要 `flutter` 的步骤前**不**因该命令缺失而崩溃；如果在 `--dry-run` 模式下，应当完整预览而不崩溃
- **Verification**: `programmatic` — 在受限环境中运行 dry-run，观察是否正常输出

### AC-4: keystore 文件权限
- **Given**: CI workflow 执行签名文件还原步骤
- **When**: base64 解码完成后
- **Then**: keystore 文件权限设置为 `600`，日志中显示权限验证成功
- **Verification**: `programmatic` — 在 GitHub Actions 日志中检查 `ls -lh` 输出

### AC-5: rollback 错误消息修复
- **Given**: 远程不存在某个 tag（例如从未推送的本地 tag）
- **When**: 执行 `./scripts/rollback-release.sh`
- **Then**: 错误消息清晰说明"远程 tag 不存在，跳过"，没有矛盾语义
- **Verification**: `human-judgment` + `programmatic` — 阅读错误消息文本，执行脚本验证输出

## Open Questions

- [x] **问题 1**: 是否本轮也要创建 `scripts/_common.sh` 公共函数库？
  - **决议**: 本轮不做，属于长期优化，后续版本独立处理
- [x] **问题 2**: 是否要在 `release.sh` 中添加 `git tag` 已存在的预检查？
  - **决议**: 本轮修复的 FR-3 已经包含命令检查，tag 已存在的场景因 `set -e` 会失败并退出，已足够安全；增强消息属于建议类改进，本轮不做
- [x] **问题 3**: `scripts/_common.sh` 中的颜色输出在非 TTY 环境（如 CI）可能产生 ANSI 乱码？
  - **决议**: 本轮不处理；属于可接受的小问题，后续可添加 `[ -t 1 ]` 判断
