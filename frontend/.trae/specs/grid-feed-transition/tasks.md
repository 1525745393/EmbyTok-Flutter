# 网格与视频流切换功能 - 实施计划

## [x] Task 1: 移除 feed→grid 冲突逻辑（删除 SharedPreferences 恢复滚动位置）
- **Priority**: high
- **Depends On**: None
- **Description**: 
  - 删除 `_buildGridPageView` 中从 SharedPreferences 恢复网格滚动位置的逻辑
  - 删除 `_hasRestoredGridScrollPosition` 变量及其相关代码
  - 保留 `_saveGridScrollOffset` 和 `_onGridScrollChanged` 保存逻辑（只存不恢复）
  - 保留 `_restoreGridScrollOffset` 方法（供将来可能使用，但不再从 build 中调用）
- **Acceptance Criteria Addressed**: AC-2, AC-3, AC-4
- **Test Requirements**:
  - `programmatic` TR-1.1: 从 feed 切换到 grid 时，`_handleFeedToGridTransition` 是唯一触发滚动的入口
  - `programmatic` TR-1.2: `_buildGridPageView` 中不再包含 `_hasRestoredGridScrollPosition` 相关逻辑
  - `human-judgement` TR-1.3: 代码审查确认无残留的首次进入恢复滚动逻辑

## [x] Task 2: 清理 grid→feed 冗余监听器
- **Priority**: medium
- **Depends On**: None
- **Description**:
  - 移除 `initState` 中对 `gridSelectedItemIdProvider` 的独立监听器
  - 保留 `viewModeProvider` 监听器中的 `_handleGridToFeedTransition`（它已经处理了 gridSelectedItemId 的读取和跳转）
  - 原因：两个监听器功能重复，且独立监听器在 viewMode 未切换时可能触发无效调用
- **Acceptance Criteria Addressed**: AC-1, FR-3
- **Test Requirements**:
  - `programmatic` TR-2.1: 点击网格视频后，只通过 `_handleGridToFeedTransition` 完成跳转
  - `programmatic` TR-2.2: `gridSelectedItemIdProvider` 不再有独立的 ref.listen
  - `human-judgement` TR-2.3: 代码审查确认跳转逻辑只有一处入口

## [x] Task 3: 验证 grid→feed 跳转功能正确性
- **Priority**: high
- **Depends On**: Task 2
- **Description**:
  - 验证点击网格视频后，`gridSelectedItemIdProvider` 被正确设置
  - 验证视图切换到 feed 模式
  - 验证 `_handleGridToFeedTransition` 正确计算目标索引并跳转
  - 验证跳转后 `currentIndexProvider` 与 `_currentIndex` 同步更新
  - 验证跳转后 `gridSelectedItemIdProvider` 被清理为 null
- **Acceptance Criteria Addressed**: AC-1
- **Test Requirements**:
  - `programmatic` TR-3.1: 选中 ID 在 items 中存在时，跳转到正确索引
  - `programmatic` TR-3.2: 选中 ID 在 items 中不存在时，保持当前位置
  - `programmatic` TR-3.3: 跳转后 gridSelectedItemIdProvider 被清理
  - `programmatic` TR-3.4: currentIndexProvider 与实际页面同步

## [x] Task 4: 验证 feed→grid 滚动功能正确性
- **Priority**: high
- **Depends On**: Task 1
- **Description**:
  - 验证从 feed 切换到 grid 时，`_handleFeedToGridTransition` 正确调度
  - 验证 `_tryScrollToCurrentVideo` 计算的滚动位置正确
  - 验证 indexInGrid = currentIndex - gridStartIndex 计算正确
  - 验证行高和目标偏移计算与 GridView 配置一致
  - 验证滚动失败时的降级行为（虽然删除了恢复逻辑，但失败时应静默处理）
- **Acceptance Criteria Addressed**: AC-2, AC-3
- **Test Requirements**:
  - `programmatic` TR-4.1: currentIndex 在当前页范围内时，indexInGrid 计算正确
  - `programmatic` TR-4.2: 3列布局下行号计算正确（index ~/ 3）
  - `programmatic` TR-4.3: 滚动偏移量使用 clamp 限制在有效范围内
  - `programmatic` TR-4.4: currentIndex 不在当前页时，返回 false 不滚动
  - `human-judgement` TR-4.5: 代码审查确认只有一处滚动触发源

## [x] Task 5: 代码审查与清理
- **Priority**: medium
- **Depends On**: Task 1, Task 2
- **Description**:
  - 审查整个 feed_view.dart 文件，确保没有残留的冲突逻辑
  - 检查是否有其他未使用的变量或方法可以清理
  - 确保代码风格一致，注释清晰
- **Acceptance Criteria Addressed**: NFR-3
- **Test Requirements**:
  - `human-judgement` TR-5.1: 代码审查确认无冗余逻辑
  - `human-judgement` TR-5.2: 变量命名清晰，职责单一
  - `programmatic` TR-5.3: 无编译错误
