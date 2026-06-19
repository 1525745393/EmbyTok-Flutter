# 纯净模式按钮区可拖动 - Implementation Plan

## [ ] Task 1: 将按钮区改为可拖拽容器
- **Priority**: P0
- **Depends On**: None
- **Description**: 
  - 将 `_buildCleanModeRightActions()` 中的 `Positioned` 从固定 `right: 0` 改为动态 `left/top` 偏移
  - 新增一个内部 `_DraggableCleanActions` 组件（StatefulWidget），包装按钮区并处理拖拽逻辑
  - 使用 `GestureDetector` / `Listener` 监听指针事件，区分点击与拖拽
  - 维护 `Offset _position` 作为按钮区的当前偏移（相对于视频区域左上角）
  - 初始位置：右侧垂直居中（由 isAutoPlay 切换为 true 时重置）
- **Implementation Details**:
  - 使用 `_DraggableCleanActions` 的 `State` 存储：
    - `Offset _offset = Offset.zero`（从初始位置的增量偏移）
    - `Offset _startOffset = Offset.zero`（拖拽开始时的手指位置）
    - `Offset _startPosition = Offset.zero`（拖拽开始时的按钮位置）
    - `bool _isDragging = false`（是否正在拖拽）
    - `Offset _dragDelta = Offset.zero`（拖拽过程中的累计位移，用于判断是否真正在拖动）
  - 初始位置使用 `Alignment.centerRight` 或通过计算得出
  - 改用 `Positioned.fromRect` 或 `Positioned(left/top)` 动态定位
- **Acceptance Criteria Addressed**: AC-1, AC-7
- **Test Requirements**:
  - `human-judgement` TR-1.1: 按钮区可以跟随手指移动
  - `human-judgement` TR-1.2: 初始位置在右侧垂直居中
  - `human-judgement` TR-1.3: 非纯净模式下行为不变
- **Notes**: 组件内部通过 `StatefulWidget` 的 `setState` 管理位置状态，不需要新增 Provider

## [ ] Task 2: 点击与拖拽手势区分
- **Priority**: P0
- **Depends On**: Task 1
- **Description**: 
  - 使用 `Listener` 的 `onPointerDown`、`onPointerMove`、`onPointerUp` 精确追踪指针事件
  - 定义阈值：位移 > 10px 或时长 > 300ms 视为拖拽
  - 拖拽过程中（`_isDragging = true`），忽略内部按钮的点击事件
  - 拖拽开始时设置 `_startOffset` 和 `_startPosition`
  - 拖拽移动时：`_offset = _startPosition + (currentPointer - _startOffset)`
  - 拖拽结束时，如果位移和时长都小于阈值，设置 `_isDragging = false`，让内部按钮接收点击
- **Acceptance Criteria Addressed**: AC-4, AC-5
- **Test Requirements**:
  - `human-judgement` TR-2.1: 轻触按钮正常触发点击（连播切换 / 倍速面板）
  - `human-judgement` TR-2.2: 按下并移动 > 10px 触发拖拽，不触发按钮点击
  - `human-judgement` TR-2.3: 快速点击不触发拖拽
- **Notes**: 使用 `IgnorePointer(ignoring: _isDragging, child: buttons)` 屏蔽内部按钮在拖拽期间的点击

## [ ] Task 3: 拖拽视觉反馈
- **Priority**: P1
- **Depends On**: Task 1
- **Description**: 
  - 拖拽时将按钮区放大 1.1x 并增加阴影
  - 使用 `Transform.scale()` + `AnimatedContainer` 实现平滑过渡
  - 拖拽结束后恢复原有大小和阴影
- **Acceptance Criteria Addressed**: AC-2
- **Test Requirements**:
  - `human-judgement` TR-3.1: 拖拽过程中按钮区明显放大
  - `human-judgement` TR-3.2: 松手后恢复原始大小
- **Notes**: 动画时长 150ms

## [ ] Task 4: 边界限制
- **Priority**: P1
- **Depends On**: Task 1
- **Description**: 
  - 使用 `LayoutBuilder` 获取视频播放区域的尺寸
  - 拖拽过程中计算按钮区的边界位置
  - `_offset.dx`（水平偏移）的范围：`0 <= dx <= containerWidth - buttonWidth`
  - `_offset.dy`（垂直偏移）的范围：`0 <= dy <= containerHeight - buttonHeight`
  - 超出边界时 `clamp` 到边界内
- **Acceptance Criteria Addressed**: AC-6
- **Test Requirements**:
  - `human-judgement` TR-4.1: 按钮区不会拖出视频区域
  - `human-judgement` TR-4.2: 可以拖动到视频区域的任意角落
- **Notes**: 按钮区宽度约 96px，高度约 140px（两个 48px 按钮 + 20px 间距）

## [ ] Task 5: 状态切换与代码审查
- **Priority**: P1
- **Depends On**: Task 1, Task 2, Task 3, Task 4
- **Description**: 
  - `isAutoPlay` 切换为 true 时，按钮位置重置为默认（右侧垂直居中）
  - 审查所有修改，确保最小化改动，不影响其他功能
  - 确认语法正确，无类型错误
- **Acceptance Criteria Addressed**: AC-3, AC-7
- **Test Requirements**:
  - `human-judgement` TR-5.1: 切换 isAutoPlay 为 true 后，按钮从默认位置开始
  - `human-judgement` TR-5.2: 代码审查通过，无明显问题
- **Notes**: 由于 `_DraggableCleanActions` 是 StatefulWidget，当 key 变化或父重建时 State 会重置，因此位置重置会自动发生

## Task Dependencies
- Task 2, Task 3, Task 4 依赖 Task 1 的容器框架完成
- Task 5 依赖前 4 个任务全部完成
