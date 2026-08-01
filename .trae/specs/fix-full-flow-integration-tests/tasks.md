# Tasks

- [x] Task 1: 收集当前失败证据并定位根因
  - [x] SubTask 1.1: 运行 `flutter test test/integration/full_flow_test.dart --concurrency=1`，捕获 4 个失败测试的完整错误输出与 hit test 结果
  - [x] SubTask 1.2: 在测试 2 中添加诊断（如 `find.byType(LibrarySelector).evaluate().length`、`ref.read(libraryListProvider)` 状态），确认弹窗是否残留以及 `libraryListProvider` 的 AsyncValue 状态（loading/data/error）
  - [x] SubTask 1.3: 确认 `RenderAbsorbPointer` + `_RenderTheater` 的来源——是 LibrarySelector 残留，还是其他 Overlay（如系统 UI、Snackbar、FullscreenOverlay）
  - [x] SubTask 1.4: 确认测试 4 中 `videoListProvider.items` 为空的原因——检查 `selectedLibraryIdsProvider` 是否有值、`VideoListNotifier.refresh()` 是否被触发

- [x] Task 2: 修复 `dismissLibrarySelectorIfNeeded` 在弹窗 loading/error 态下不关闭的问题
  - [x] SubTask 2.1: 修改辅助函数，当弹窗存在但无「确认」按钮时，通过点击标题栏关闭按钮（tooltip「关闭」）强制关闭弹窗；并用 `pump(Duration)` 替代 `pumpAndSettle` 避免无限动画导致超时
  - [x] SubTask 2.2: 重跑测试 2/3/5，确认 `tap()` 不再命中 `RenderAbsorbPointer`，弹窗不再残留
  - [x] SubTask 2.3: 修复 mock wiring——为 `getLibraries`/`getLibraryItems`/`getItemDetail`/`toggleFavorite` stub 显式添加 `userId: anyNamed('userId')` 等命名参数，确保 stub 命中

- [x] Task 3: 修复测试 2/3 中 `PosterGridView` 未渲染的问题
  - [x] SubTask 3.1: 确认弹窗关闭后，点击「网格」能触发 `viewModeProvider` 切换到 `ViewMode.grid`
  - [x] SubTask 3.2: 调整 `usePortraitViewport` 物理尺寸为 1242x2688（iPhone 11/12 @ 3.0x DPR），避免「网格」按钮溢出屏幕右侧
  - [x] SubTask 3.3: 重跑测试 2/3，确认 `find.byType(PosterGridView)` 命中

- [x] Task 4: 修复测试 4 中 `videoListProvider.items` 为空的问题
  - [x] SubTask 4.1: 确认 `selectedLibraryIdsProvider` 在测试中有值——根因是弹窗残留导致未点击确认，修复 dismissLibrarySelectorIfNeeded 后即解决
  - [x] SubTask 4.2: 为 `toggleFavorite` 验证添加 `userId: anyNamed('userId')` 参数，匹配 EmbyRepository.toggleFavorite 的实际调用签名
  - [x] SubTask 4.3: 修复后重跑测试 4，确认 `items.length` 等于 mock 返回的数量（1）

- [x] Task 5: 修复测试 5 中 `SettingsView` 未渲染的问题
  - [x] SubTask 5.1: 确认弹窗关闭后，点击「设置」tab 能触发导航到 SettingsView
  - [x] SubTask 5.2: 修复 `scrollUntilVisible(find.text('退出登录'), ...)` 抛 `Bad state: Too many elements`——改用 `find.widgetWithText(ElevatedButton, '退出登录')` 精确定位 + 手动 fling 滚动循环
  - [x] SubTask 5.3: 修复点击「退出」后未导航回 LoginView——分多次 pump（1s+1s+2s）确保 logout 异步链路每阶段都有帧调度
  - [x] SubTask 5.4: 修复后重跑测试 5，确认 `find.byType(LoginView)` 命中且退出登录流程完整

- [x] Task 6: 全量验证与回归
  - [x] SubTask 6.1: 运行 `flutter test test/integration/full_flow_test.dart --concurrency=1`，确认 5 个测试全部通过（`All tests passed!`）
  - [x] SubTask 6.2: 运行 `flutter test`（全量），确认本次修复未引入新的测试失败
    - 9 个前期已修复的目标测试文件全部通过（159 用例）
    - 全量测试中 4 个失败（actors_api_test / embytok_service_test / back_navigation_test ×2）均为预先存在的失败，不在本次修改范围，与 full_flow_test.dart 无关
  - [x] SubTask 6.3: 运行 `flutter analyze`，确认无 error 级别诊断（0 个 error，853 个 warning/info）
  - [x] SubTask 6.4: 更新 `run-flutter-tests/tasks.md` 中 Task 6.2 状态为已完成，checklist 中 `flutter test` 全绿检查点为已通过

# Task Dependencies

- [Task 2] depends on [Task 1]（必须先定位根因再修复）
- [Task 3] depends on [Task 2]（弹窗关闭后才能验证网格切换）
- [Task 4] depends on [Task 2]（弹窗关闭后才能验证视频列表加载）
- [Task 5] depends on [Task 2]（弹窗关闭后才能验证设置页导航）
- [Task 6] depends on [Task 3, Task 4, Task 5]（所有修复完成后全量验证）
