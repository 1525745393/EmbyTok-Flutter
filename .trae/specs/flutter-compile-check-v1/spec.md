# Flutter 编译错误预防机制 Spec

## Why
当前 EmbyTok Flutter 项目每次发布新版本时都会出现编译错误（如 `FutureProviderRef` 类型错误、`httpHeaders` 参数不存在等），导致反复修复、重新发布。这是因为代码变更后没有在本地或 CI 中进行完整的静态分析和构建验证。

## What Changes
- 在 CI workflow 中增加 `flutter analyze` 静态分析步骤
- 在发布前强制执行 `flutter analyze` 和 `flutter build` 验证
- 创建本地预检查脚本 `scripts/flutter-check.sh`，在 `git push` 前自动运行
- 修复已知的编译错误根源（如 `FutureProviderRef` vs `WidgetRef` 类型混淆）

## Impact
- **Affected specs**: 发布流程 (release-fix-v1)
- **Affected code**:
  - `.github/workflows/ci.yml` - 添加 analyze 步骤
  - `.github/workflows/android-release.yml` - 添加 analyze 前置检查
  - `scripts/flutter-check.sh` - 新增本地检查脚本

## ADDED Requirements

### Requirement: Flutter 静态分析强制执行
在每次代码变更合并到 main 分支前，必须通过 `flutter analyze` 无错误验证。

#### Scenario: CI 中静态分析
- **WHEN**: PR 被合并或 push 到 main 时
- **THEN**: CI 自动运行 `flutter analyze`，若存在任何 error 则构建失败

#### Scenario: 发布前本地检查
- **WHEN**: 开发者执行 `git push` 前
- **THEN**: 钩子脚本自动运行 `flutter analyze`，如有错误则拒绝推送

### Requirement: 发布前构建验证
在发布新版本前，必须通过完整的 debug 和 release 构建验证。

#### Scenario: 发布前构建
- **WHEN**: 执行 `scripts/release.sh` 时
- **THEN**: 脚本先运行 `flutter analyze` 和 `flutter build --debug`，确认成功后才继续版本号更新

## MODIFIED Requirements

### Requirement: CI 工作流 - flutter analyze
**原内容**: CI 仅运行测试，不包含静态分析
**修改为**: CI 必须包含 `flutter analyze` 步骤，且不允许任何 error 存在（warning 可以）

### Requirement: 发布脚本 - 前置验证
**原内容**: 发布脚本直接更新版本号并提交
**修改为**: 发布脚本先执行 `flutter analyze` 和 `flutter build` 验证，失败时拒绝发布

## REMOVED Requirements

### Requirement: 无验证直接发布
**Reason**: 频繁的编译错误表明当前无验证机制不足以保证代码质量
**Migration**: 通过自动化验证替代人工检查

## 根因分析

根据最近的编译错误，常见问题包括：

| 错误类型 | 原因 | 预防措施 |
|---------|------|---------|
| `FutureProviderRef` 不能赋值给 `WidgetRef` | FutureProvider 内部使用 Ref，非 WidgetRef | 明确类型区分 |
| `httpHeaders` 参数不存在 | Flutter 旧版本 API，新版本改用 `headers` | 使用 `flutter analyze` 检测 |
| `Map<dynamic, dynamic>` 类型不匹配 | 缺少类型转换 | 添加显式类型转换 |
| toggleFavorite 参数错误 | API 签名变更后调用方未更新 | 保持 API 文档同步 |

## 实现方案

### 方案 A: 最小改动（推荐）
1. 修改 `ci.yml`，添加 `flutter analyze` job
2. 修改 `release.sh`，在版本更新前添加 `flutter analyze` 检查
3. 添加 `.git/hooks/pre-push` 脚本（可选）

### 方案 B: 完整方案
在方案 A 基础上，添加：
1. `scripts/flutter-check.sh` 本地检查脚本
2. Dart 严格模式 (`analysis_options.yaml` 严格规则)
3. 每日夜间 CI 构建测试

## Open Questions
- [ ] 是否需要升级 `flutter_lints` 到最新版本？
- [ ] 是否需要启用 Dart 严格模式（strict mode）？
- [ ] `flutter analyze` 的 warning 级别是否也需要阻止发布？
