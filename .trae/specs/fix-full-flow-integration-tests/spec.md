# 修复完整流程集成测试 Spec

## Why

`test/integration/full_flow_test.dart` 中 5 个端到端集成测试目前 4 个失败（测试 1 已通过）。这些测试覆盖核心用户流：登录 → 首页 → 网格 → 详情 → 收藏 → 退出登录。`run-flutter-tests` spec 在 Task 6.2 中明确指出集成测试的失败属于 lib/ 实现层问题（`ref.listen` 误用），需要单独的 spec 处理。前期已修复 `ref.listen` → `ref.listenManual`、`ref.invalidate` 延迟到 `addPostFrameCallback`、`ListTile` 背景色等实现层问题，使测试 1 通过。剩余 4 个测试的失败根因需要进一步定位并修复，使集成测试达到全绿，建立端到端回归保护基线。

## What Changes

- 定位测试 2/3/5 中 `tap()` 命中 `RenderAbsorbPointer` + `_RenderTheater`（Overlay/Dialog 仍吸收指针事件）的根因
- 定位测试 2/3 中 `PosterGridView` 未渲染的根因（viewMode 未切换或网格视图构建被阻断）
- 定位测试 4 中 `videoListProvider.items.length == 0` 的根因（媒体库未选中导致不加载，或 mock 未到达 notifier）
- 定位测试 5 中 `SettingsView` 未渲染的根因（底部导航 tab 切换被阻断）
- 修复根因：实现层 bug 优先修 lib/，测试 wiring 问题修 test/ 或 mocks/
- 重跑 `flutter test test/integration/full_flow_test.dart` 确认全绿

## Impact

- Affected specs:
  - `run-flutter-tests`：关闭 Task 6.2 遗留的集成测试失败，使 checklist 中 `flutter test` 全绿检查点可达成
  - `complete-test-coverage`：集成测试作为端到端回归基线
- Affected code:
  - `frontend/test/integration/full_flow_test.dart`（测试 wiring / 辅助函数）
  - `frontend/lib/` 下实现代码（若根因是实现 bug，如 LibrarySelector 状态、VideoListNotifier 加载逻辑）
  - `frontend/test/mocks/` 下的 mock 文件（若 mock 配置不完整）
  - 已知前期已修改：`feed_view_model.dart`、`feed_view.dart`、`library_selector.dart`、`settings_view.dart`

## ADDED Requirements

### Requirement: 集成测试辅助函数正确关闭弹窗
`dismissLibrarySelectorIfNeeded` SHALL 在 LibrarySelector 处于 loading/error 状态（无「确认」按钮）时也能正确关闭弹窗，避免弹窗残留吸收后续 tap 事件。

#### Scenario: 弹窗处于加载态时关闭
- **WHEN** LibrarySelector 已弹出但 `libraryListProvider` 仍在 loading（显示 CircularProgressIndicator，无「确认」按钮）
- **THEN** 辅助函数通过 Navigator.pop 或等待加载完成后点击「确认」关闭弹窗，确保后续 `tap()` 不被 Overlay 吸收

#### Scenario: 弹窗处于错误态时关闭
- **WHEN** LibrarySelector 已弹出但 `libraryListProvider` 处于 error 状态（显示「重试」按钮，无「确认」按钮）
- **THEN** 辅助函数关闭弹窗，测试可继续或选择让测试失败并报告根因

### Requirement: 集成测试网格切换可达
登录后未配置媒体库的场景下，测试 SHALL 能通过有效的交互方式触发 `viewModeProvider` 切换到 `ViewMode.grid`，使 `PosterGridView` 渲染并可断言。

#### Scenario: 切换到网格视图成功
- **WHEN** 测试在 FeedView 中尝试切换到网格视图
- **THEN** `PosterGridView` 出现在 widget 树中（`find.byType(PosterGridView)` 命中）

### Requirement: 集成测试视频列表加载可达
登录并配置媒体库后，`videoListProvider` SHALL 加载到 mock 提供的视频数据，使测试可断言 items 非空。

#### Scenario: 视频列表加载成功
- **WHEN** 测试 mock `getLibraryItems` 返回 5 个 MediaItem
- **THEN** `container.read(videoListProvider).items.length` 等于 5（或经过过滤后的预期数量）

### Requirement: 集成测试设置页可达
登录后，测试 SHALL 能通过有效的交互方式导航到 SettingsView，使 `find.byType(SettingsView)` 命中。

#### Scenario: 切换到设置页成功
- **WHEN** 测试在 HomeScaffold 中点击「设置」tab
- **THEN** `SettingsView` 出现在 widget 树中

## MODIFIED Requirements

### Requirement: 完整流程集成测试全绿
**现有实现**：5 个测试中 1 个通过、4 个失败（测试 2/3/4/5）。
**修改后**：5 个测试全部通过，`flutter test test/integration/full_flow_test.dart` 输出 `All tests passed!`。

## REMOVED Requirements
无

## Assumptions

- 前期已修复的 `ref.listen` → `ref.listenManual` 等实现层问题已生效，测试 1 通过即为证据。
- 测试 2/3/5 的 `tap()` 命中 `RenderAbsorbPointer` + `_RenderTheater` 表明存在 Overlay（很可能就是 LibrarySelector）残留吸收指针事件。
- `dismissLibrarySelectorIfNeeded` 当前实现在弹窗无「确认」按钮时静默返回，是残留弹窗的主要嫌疑。
- `embytokServiceProvider` override 会通过 `mediaRepositoryProvider` → `cachedMediaRepositoryProvider` 链传递到 `libraryListProvider`，mock 应能到达（测试 1 登录成功为间接证据）。
- 修复遵循小步重构：每定位并修复一个根因后重跑测试确认，不批量修改。

## Constraints

- 不得修改 `pubspec.yaml` 中的依赖版本。
- 不得删除或 skip 任何测试用例——必须真实修复使测试通过。
- 不得修改 CI 工作流文件。
- 实现层修复必须添加简明中文注释说明修改原因。
- 测试 wiring 修改必须保留测试原有的业务意图（登录→首页→网格→详情→收藏→退出登录）。
- 修复遵循 systematic-debugging：先定位根因再修复，禁止"猜测式"批量改动。
- 不执行 git commit/push/stash，只做代码编辑。
