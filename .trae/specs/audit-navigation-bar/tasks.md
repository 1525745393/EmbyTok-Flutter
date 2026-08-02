# 底部导航栏审查与修复 - 任务清单

## [x] Task 1: 消除路由索引 magic number

- **Priority**: high
- **Depends On**: None
- **Description**:
  修改 `/workspace/frontend/lib/views/home_scaffold.dart` L282（行号可能因修改前移），将：
  ```dart
  index: currentIndex == 4 ? 0 : 1,
  ```
  改为：
  ```dart
  index: currentIndex == PageIndices.search ? 0 : 1,
  ```

  同时检查文件中是否还有其他 magic number 引用 PageIndices（如 `currentIndex != 0`、`currentIndex != PageIndices.search` 等），全部替换为 `PageIndices.xxx` 常量。已知 L185-186 有 `currentIndex != 0 && currentIndex != PageIndices.search && currentIndex != PageIndices.history`，其中 `0` 应改为 `PageIndices.feed`。

- **Acceptance Criteria Addressed**: Requirement: 路由索引使用常量
- **Test Requirements**:
  - `programmatic` TR-1.1: 全文件 grep `== 4\b` 或 `!= 4\b` 无匹配（针对 PageIndices 范围内的数字）
  - `programmatic` TR-1.2: `flutter analyze` 无新增警告

## [x] Task 2: 迁移废弃的 PopScope API

- **Priority**: medium
- **Depends On**: None
- **Description**:
  修改 `/workspace/frontend/lib/views/home_scaffold.dart` 的 `PopScope` 组件（约 L173-229），将：
  ```dart
  return PopScope(
    canPop: false,
    onPopInvoked: (bool didPop) async {
      if (didPop) return;
      // ... 退出确认逻辑
    },
    child: Scaffold(...),
  );
  ```
  改为：
  ```dart
  return PopScope(
    canPop: false,
    onPopInvokedWithResult: (bool didPop, dynamic result) async {
      if (didPop) return;
      // ... 退出确认逻辑（保持不变）
    },
    child: Scaffold(...),
  );
  ```

  仅修改回调名称和签名，**不改变内部逻辑**（包括覆盖层返回、非 Feed Tab 回到 Feed、Feed Tab 退出确认对话框三段逻辑）。

- **Acceptance Criteria Addressed**: Requirement: PopScope 使用现代 API
- **Test Requirements**:
  - `programmatic` TR-2.1: `flutter analyze lib/views/home_scaffold.dart` 无 `onPopInvoked` deprecation 警告
  - `programmatic` TR-2.2: 退出确认对话框行为不变（需测试验证）

## [x] Task 3: Tab 切换增加触觉反馈

- **Priority**: low
- **Depends On**: None
- **Description**:
  修改 `/workspace/frontend/lib/views/home_scaffold.dart` 的 `NavigationBar.onDestinationSelected` 回调（约 L326-328），将：
  ```dart
  onDestinationSelected: (index) {
    ref.read(pageNavigationNotifierProvider).goToPage(index);
  },
  ```
  改为：
  ```dart
  onDestinationSelected: (index) {
    // 轻量触觉反馈，确认 Tab 切换操作（fire-and-forget，不阻塞 UI）
    HapticFeedback.selectionClick();
    ref.read(pageNavigationNotifierProvider).goToPage(index);
  },
  ```

  同时在文件顶部 import 区添加（如尚未导入）：
  ```dart
  import 'package:flutter/services.dart';
  ```
  注意：检查文件是否已导入 `flutter/services.dart`（L21 已有 `import 'package:flutter/services.dart';` 用于 `SystemNavigator`），若已存在则无需重复。

- **Acceptance Criteria Addressed**: Requirement: Tab 切换触觉反馈
- **Test Requirements**:
  - `programmatic` TR-3.1: `HapticFeedback.selectionClick()` 在 `goToPage` 之前调用
  - `programmatic` TR-3.2: 触觉反馈调用不阻塞页面切换（无 await）

## [x] Task 4: 修复 `_load` 异步初始化竞态

- **Priority**: medium
- **Depends On**: None
- **Description**:
  修改 `/workspace/frontend/lib/providers/page_navigation_provider.dart` 的 `PageNavigationNotifier`：

  方案 A（最小改动）：仅添加注释说明此设计决策，不增加 `isLoaded` 字段。
  在 `_load` 方法上方添加注释：
  ```dart
  // 异步加载上次保存的 Tab 索引。
  //
  // 设计说明：_load 是异步的，应用启动时 state 初始为 Feed (index=0)，
  // _load 完成后（通常 <50ms）更新为保存的索引。
  // 此期间用户可能短暂看到 Feed 后跳转到恢复的 Tab，这是已知行为。
  // 覆盖层页面（search/history）不在此恢复，因为它们是临时操作不应持久化。
  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final index = prefs.getInt(kStorageKeyLastPageIndex);
      if (index != null && index >= PageIndices.feed && index <= PageIndices.settings) {
        state = PageNavigationState(currentIndex: index, isOverlayPage: false);
      }
    } catch (_) {}
  }
  ```

  方案 B（增加 isLoaded 字段，可选）：如果用户希望消除闪烁，增加 `isLoaded` 状态。但这会增加复杂度，不推荐。

  **本次采用方案 A**（仅注释，不改逻辑），符合"不过度工程"原则。

- **Acceptance Criteria Addressed**: Requirement: 导航状态初始化一致性
- **Test Requirements**:
  - `programmatic` TR-4.1: `_load` 方法上方有注释说明异步初始化行为
  - `programmatic` TR-4.2: `_load` 方法逻辑不变（仅添加注释）

## [x] Task 5: 统一覆盖层持久化策略文档化

- **Priority**: low
- **Depends On**: None
- **Description**:
  修改 `/workspace/frontend/lib/providers/page_navigation_provider.dart` 的 `goToSearch()` 和 `goToHistory()` 方法，添加注释说明为何不持久化：

  ```dart
  // 切换到搜索页面（覆盖层）
  //
  // 注意：不调用 _saveIndex，因为覆盖层是临时操作，不应在下次启动时恢复。
  // 用户下次启动应回到上次的主 Tab（Feed/Favorites/Actors/Settings）。
  void goToSearch() {
    state = const PageNavigationState(
      currentIndex: PageIndices.search,
      isOverlayPage: true,
    );
  }

  // 切换到历史页面（覆盖层）
  //
  // 注意：同 goToSearch，不持久化覆盖层索引。
  void goToHistory() {
    state = const PageNavigationState(
      currentIndex: PageIndices.history,
      isOverlayPage: true,
    );
  }
  ```

- **Acceptance Criteria Addressed**: Requirement: 覆盖层持久化策略文档化
- **Test Requirements**:
  - `programmatic` TR-5.1: `goToSearch()` 和 `goToHistory()` 方法上方有注释说明不持久化的原因

## [x] Task 6: 补充测试用例

- **Priority**: medium
- **Depends On**: Task 1, Task 2
- **Description**:
  在 `/workspace/frontend/test/views/` 下创建 `home_scaffold_test.dart`，覆盖以下场景：

  - **Tab 切换测试**：
    - 点击"收藏"Tab，`pageNavigationProvider` 的 `currentIndex` 更新为 1
    - 点击"演员"Tab，`currentIndex` 更新为 2
    - 点击"设置"Tab，`currentIndex` 更新为 3
    - 点击"首页"Tab，`currentIndex` 更新为 0

  - **覆盖层显隐测试**：
    - 调用 `goToSearch()`，`isOverlayPage` 为 true，底部导航栏不显示
    - 调用 `goToHistory()`，`isOverlayPage` 为 true
    - 调用 `backToFeed()`，`isOverlayPage` 为 false，底部导航栏显示

  - **PopScope 退出确认测试**（如已在 `back_navigation_test.dart` 覆盖则跳过）：
    - 在 Feed Tab 按返回键，弹出退出确认对话框
    - 在非 Feed Tab 按返回键，回到 Feed Tab（不弹退出确认）

  - **生命周期播放控制测试**：
    - 验证 `applyFeedVisibilityChange` 纯函数：Feed 隐藏时暂停，Feed 可见时恢复（仅当 userWantsToPlay=true）
    - 验证 `applyLifecyclePlaybackChange` 纯函数：切后台暂停，回前台恢复（仅当 Feed 可见 + userWantsToPlay=true）

  注意：测试中 mock `SharedPreferences`、`currentVideoControllerProvider`、`isPlayingProvider`，避免依赖真实服务。

- **Test Requirements**:
  - `programmatic` TR-6.1: 所有新增测试通过
  - `programmatic` TR-6.2: `flutter test test/views/home_scaffold_test.dart` 退出码 0

# Task Dependencies

- Task 6 依赖 Task 1, Task 2（测试基于修复后的代码）
- Task 1, 2, 3, 4, 5 之间无依赖，可并行执行
