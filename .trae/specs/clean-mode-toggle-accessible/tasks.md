# 纯净模式下保留连播开关与倍速控制 - Implementation Plan

## [x] Task 1: 新增纯净模式专用右侧按钮区 ✅ 已完成
- **Priority**: P0
- **Depends On**: None
- **Description**: 
  - 在 `video_page_item.dart` 中新增一个 Widget 方法 `_buildCleanModeRightActions()`，仅包含连播开关和倍速按钮
  - 该按钮区在 `isAutoPlay=true` 且非全屏时显示
  - 位置与原有右侧操作栏相同（右侧垂直排列）
  - 复用现有的 `_buildAutoPlayButton()` 和 `_buildSpeedControlButton()` 方法
- **Acceptance Criteria Addressed**: AC-1, AC-2
- **Test Requirements**:
  - `human-judgement` TR-1.1: 纯净模式下屏幕右侧应清晰可见连播开关（绿色 Infinity 图标）
  - `human-judgement` TR-1.2: 纯净模式下屏幕右侧应清晰可见倍速按钮（显示当前倍速值）
  - `human-judgement` TR-1.3: 两个按钮应在原有位置垂直排列（从顶部开始）
  - `human-judgement` TR-1.4: 按钮样式与非纯净模式完全一致（圆形、半透明背景、白色图标）
- **Notes**: 按钮布局应参考 `_buildRightActions()` 中的布局结构，垂直间距约 20px

## [x] Task 2: 原有右侧按钮区条件不变 ✅ 已完成
- **Priority**: P0
- **Depends On**: Task 1
- **Description**: 
  - 保持 `_buildRightActions()` 的隐藏条件不变：`isAutoPlay=true` 时完全隐藏
  - 仅在 `isAutoPlay=false` 时显示完整的右侧操作栏
- **Acceptance Criteria Addressed**: AC-3, AC-5
- **Test Requirements**:
  - `human-judgement` TR-2.1: 纯净模式下不应看到全屏、静音、点赞、删除、评论、分享、上下集按钮
  - `human-judgement` TR-2.2: 关闭连播后，完整的右侧操作栏应恢复显示
  - `human-judgement` TR-2.3: 底部信息区在纯净模式下仍然隐藏
- **Notes**: 确保两种状态互斥：要么显示完整按钮区（非纯净模式），要么显示简化按钮区（纯净模式），不同时显示

## [x] Task 3: 功能一致性验证 ✅ 已完成
- **Priority**: P1
- **Depends On**: Task 1, Task 2
- **Description**: 
  - 验证纯净模式下连播开关和倍速按钮的点击行为与非纯净模式完全相同
  - 连播开关点击后正确切换 isAutoPlayProvider 状态并显示 Toast
  - 倍速按钮点击后正确弹出倍速选择面板
  - 关闭连播后 UI 正确切换回非纯净模式
- **Acceptance Criteria Addressed**: AC-4, AC-5
- **Test Requirements**:
  - `human-judgement` TR-3.1: 纯净模式下点击连播开关，状态切换并显示 Toast
  - `human-judgement` TR-3.2: 关闭连播后，完整 UI 立即恢复显示
  - `human-judgement` TR-3.3: 纯净模式下点击倍速按钮，弹出倍速选择面板
  - `human-judgement` TR-3.4: 非纯净模式下所有行为与修改前一致
- **Notes**: 不修改 `_buildAutoPlayButton()` 和 `_buildSpeedControlButton()` 的内部逻辑，仅改变显示位置和条件
