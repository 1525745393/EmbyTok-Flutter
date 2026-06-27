# 修复网格→视频流跳转竞争条件 - 实施计划

## [x] Task 1: 修复 _handleGridToFeedTransition 阻止 SharedPreferences 恢复覆盖
- **Priority**: high
- **Depends On**: None
- **Description**: 
  - 在 `_handleGridToFeedTransition` 中，当 `gridSelectedItemIdProvider` 非空时，设置 `_hasRestoredScrollPosition = true`
  - 阻止 `_buildVideoPageView` 中的 SharedPreferences 恢复逻辑与跳转竞争
- **Acceptance Criteria Addressed**: 网格→视频流跳转不被覆盖
- **Test Requirements**:
  - `human-judgement` TR-1.1: 点击网格视频后，视频流正确跳转到该视频
  - `human-judgement` TR-1.2: 正常进入视频流时仍从 SharedPreferences 恢复位置
- **Notes**: 这是一个小修复，只需在 `_handleGridToFeedTransition` 开头加一行

## [x] Task 2: 在 _buildVideoPageView 中增加网格选中判断
- **Priority**: high
- **Depends On**: Task 1
- **Description**: 
  - 在 `_buildVideoPageView` 的 SharedPreferences 恢复逻辑前，检查 `gridSelectedItemIdProvider` 是否为空
  - 如果非空，跳过 SharedPreferences 恢复（双重保险）
- **Acceptance Criteria Addressed**: 网格→视频流跳转不被覆盖
- **Test Requirements**:
  - `human-judgement` TR-2.1: 网格点击跳转后不再被 SharedPreferences 恢复覆盖
- **Notes**: 与 Task 1 互为补充，确保万无一失