# 修复顶/底部操作区返回逻辑问题 - 任务列表

## [x] Task 1: 修改 SearchView 增加 useScaffold 参数和覆盖层模式支持
- **Priority**: P0
- **Depends On**: None
- **Description**:
  - 在 SearchView 构造函数中增加 `useScaffold` 参数（bool，默认 true）
  - 当 `useScaffold=false` 时：
    - 不渲染 Scaffold，改为 `Container` + `SafeArea`
    - 增加简化的顶部栏：包含搜索图标、"搜索"标题、返回图标按钮
    - 点击返回按钮调用 `ref.read(pageNavigationNotifierProvider).backToFeed()`
  - 当 `useScaffold=true` 时：保持现有行为（Scaffold + AppBar）
- **Test Requirements**:
  - 检查 SearchView 两种模式都能正常渲染
  - 确认覆盖层模式下没有 Scaffold 嵌套问题
  - 确认返回按钮调用正确的 provider 方法

## [x] Task 2: 修改 HistoryView 增加 useScaffold 参数和覆盖层模式支持
- **Priority**: P0
- **Depends On**: Task 1（可并行，结构相同）
- **Description**:
  - 在 HistoryView 构造函数中增加 `useScaffold` 参数（bool，默认 true）
  - 当 `useScaffold=false` 时：
    - 不渲染 Scaffold，改为 `Container` + `SafeArea`
    - 增加简化的顶部栏：包含历史图标、"观看历史"标题、返回图标按钮
    - 点击返回按钮调用 `ref.read(pageNavigationNotifierProvider).backToFeed()`
  - 当 `useScaffold=true` 时：保持现有行为
- **Test Requirements**:
  - 同 Task 1，针对 HistoryView
  - 确认未登录状态下的 UI 正确（ErrorStateCard 不依赖 Scaffold）

## [x] Task 3: 更新 HomeScaffold 使用覆盖层模式
- **Priority**: P0
- **Depends On**: Task 1, Task 2
- **Description**:
  - 在 HomeScaffold 覆盖层的 IndexedStack 中，将 SearchView 和 HistoryView 改为带 `useScaffold: false` 参数
  - 确保覆盖层页面的背景色与 scheme.surface 一致
  - 确认 PopScope 逻辑不受影响（保持现有逻辑不变）
- **Test Requirements**:
  - 检查 home_scaffold.dart 中 SearchView/HistoryView 的使用方式
  - 确认 Stack 结构中覆盖层正确显示和隐藏

## [x] Task 4: 验证 flutter analyze 和代码正确性
- **Priority**: P1
- **Depends On**: Task 1-3
- **Description**:
  - 运行 flutter analyze --no-pub lib，检查无 error
  - 检查没有 lint warning（如未使用的 import、未使用的参数等）
  - 检查所有修改文件的中文注释完整清晰
- **Test Requirements**:
  - `flutter analyze --no-pub lib` 无 error
  - 手动代码审查确认无结构性问题
