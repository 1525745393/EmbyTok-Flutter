# 运行测试套件并修复至全绿 Spec

## Why
Flutter SDK 刚完成本地安装（3.44.8），此前所有测试修复（类型安全解析、AppError 断言、缓存逻辑、手势交互等）均为静态代码审查，从未实际执行 `flutter test`。`fix-embbytok-service-tests` 的 Task 5.2/5.3 也因"无 Flutter SDK"而遗留。现在需要运行完整测试套件，收集真实失败结果，分类修复，最终建立"测试全绿"基线，使后续每次提交都能在本地快速验证。

## What Changes
- 在 `/workspace/frontend` 下执行 `flutter test --concurrency=1`，收集全部失败用例与编译错误
- 按失败根因分类：编译错误 / mock 路径或字段不匹配 / 断言值不匹配 / 实现层 bug / 测试本身逻辑错误
- 逐类修复，每修一类后重跑对应测试确认通过
- 最终全量运行 `flutter test` 达到 `All tests passed!`
- 运行 `flutter analyze` 确保修复未引入新问题
- 关闭 `fix-embbytok-service-tests` 遗留的 SubTask 5.2/5.3

## Impact
- Affected specs:
  - `fix-embbytok-service-tests`：关闭遗留的 SubTask 5.2（运行 service 测试）、5.3（运行 analyze）
  - `install-flutter-sdk`：补全 checklist 中检查点 18（flutter test 能启动并出现明确通过/失败统计）
  - `complete-test-coverage`：验证已标记完成的 Task 1-10 测试是否真的通过
- Affected code:
  - `frontend/test/` 下全部 52 个测试文件（可能需要修正 mock 配置、断言值、API 签名匹配）
  - `frontend/lib/` 下实现代码（若测试失败根因是实现 bug 而非测试问题）
  - `frontend/test/mocks/` 下的 mock 服务定义

## ADDED Requirements

### Requirement: 测试套件全量可运行
系统 SHALL 在 `/workspace/frontend` 目录下执行 `flutter test --concurrency=1` 时，所有测试文件均可编译并执行，不出现 SDK/工具链配置类环境错误。

#### Scenario: 全量测试可启动
- **WHEN** 开发者在 `/workspace/frontend` 执行 `flutter test`
- **THEN** 命令进入测试执行阶段，输出包含通过/失败统计文本，而非环境级报错

### Requirement: 测试套件全绿
系统 SHALL 在修复完成后，`flutter test` 输出 `All tests passed!`，退出码为 0。

#### Scenario: 所有测试通过
- **WHEN** 所有修复完成后执行 `flutter test`
- **THEN** 输出包含 `All tests passed!`，退出码 0

### Requirement: 静态分析无错误
系统 SHALL 在修复完成后，`flutter analyze` 退出码为 0 或仅含 info 级别提示，不含 error 级别诊断。

#### Scenario: analyze 无错误
- **WHEN** 执行 `flutter analyze`
- **THEN** 输出不包含 `error •` 级别诊断行

## MODIFIED Requirements

### Requirement: fix-embbytok-service-tests 遗留任务关闭
`fix-embbytok-service-tests` 的 SubTask 5.2（运行 service 测试）和 5.3（运行 analyze）在此 spec 完成后标记为已完成。

## REMOVED Requirements
无

## Assumptions
- Flutter SDK 已安装且 `flutter test` 命令可正常启动（install-flutter-sdk spec Task 5 已验证）。
- 测试失败根因以"测试代码与实现不匹配"为主，而非"实现本身有功能 bug"——若发现实现 bug 需单独评估修复范围。
- 修复过程中不改变测试覆盖的业务意图，仅修正测试代码使其与当前实现一致。
- 不新增测试用例（新增覆盖属于 `complete-test-coverage` 的范畴），本 spec 只修复现有测试使其通过。

## Constraints
- 不得修改 `pubspec.yaml` 中的生产依赖版本（仅可调整 dev_dependencies 如有兼容性问题）。
- 不得删除或 skip 测试用例来"达到全绿"——必须真实修复。
- 不得修改 CI 工作流文件。
- 修复遵循小步重构：每修一类失败后重跑该类测试确认。
