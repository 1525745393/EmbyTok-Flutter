# 连播模式按钮位置调整 - 实施任务计划

## [ ] Task 1: 修改 _buildCleanModeRightActions 的布局 - 从 Positioned.fill 改为右下角定位
- **Priority**: P0
- **Depends On**: None
- **Description**: 
  - 重写 `_buildCleanModeRightActions()` 方法，将 `Positioned.fill` + `LayoutBuilder` 改为 `Positioned(right: X, bottom: Y)`，定位到视频容器的右下角
  - 按钮容器宽度改为紧凑尺寸（`responsiveSize(56)` 左右），高度自适应
  - 使用 `AnimatedOpacity` 或 `AnimatedPositioned` 实现出现/消失动画（200-300ms）
  - 半透明背景：`Color(0x66000000)` 黑色半透明，圆角
  - 保留 `_DraggableCleanActions` 组件作为按钮容器，但修改其传入的位置参数
- **Acceptance Criteria Addressed**: AC-1, AC-2, AC-4, AC-6, AC-10
- **Test Requirements**:
  - `programmatic` TR-1.1: 检查 `_buildCleanModeRightActions` 不再使用 `Positioned.fill`
  - `programmatic` TR-1.2: 检查 `_buildCleanModeRightActions` 返回的 Widget 使用 `Positioned(right: , bottom:)` 参数
  - `human-judgement` TR-1.3: 视觉检查 - 按钮显示在屏幕/容器右下角，不遮挡视频主体内容
  - `human-judgement` TR-1.4: 视觉检查 - 按钮容器具有半透明黑色背景和圆角
- **Notes**: 底部边距需要考虑底部导航栏高度 (`kBottomNavHeight`) 和系统手势条 (`MediaQuery.of(context).padding.bottom`)，额外留 16px 边距。

## [ ] Task 2: 修改 _DraggableCleanActions 初始位置 - 从右侧中间改为右下角
- **Priority**: P0
- **Depends On**: Task 1
- **Description**: 
  - 修改 `_DraggableCleanActionsState.initState()` 中的 `_offset` 初始值
  - 当前初始值：`Offset(width - buttonWidth, height/2 - 70)` （右侧中间）
  - 新初始值：`Offset(containerSize.width - buttonWidth - 16, containerSize.height - _kHeightApprox - bottomPadding - 16)` （右下角，留 16px 边距）
  - `bottomPadding` 应包含：底部导航栏高度 + 系统手势条高度
  - 保持拖动范围限制 `clamp(0.0, containerSize.width - buttonWidth)` 不变
  - 按钮高度估算 `_kHeightApprox = 140` 根据实际内容自动调整
- **Acceptance Criteria Addressed**: AC-1, AC-3, AC-8, AC-10
- **Test Requirements**:
  - `programmatic` TR-2.1: 检查 `_DraggableCleanActionsState.initState()` 中 `_offset` 的 `dy` 不再是 `height/2`，而是 `height - estimatedHeight - padding`
  - `human-judgement` TR-2.2: 视觉检查 - 连播模式开启后按钮初始位置在右下角，距离底部有合理边距
  - `human-judgement` TR-2.3: 视觉检查 - 在有底部手势条的设备上，按钮不与手势条重叠
  - `human-judgement` TR-2.4: 交互检查 - 拖动按钮后可以停留在任意位置，不会超出屏幕边界

## [ ] Task 3: 添加动画过渡效果
- **Priority**: P1
- **Depends On**: Task 1, Task 2
- **Description**: 
  - 在 `_buildCleanModeRightActions` 或 `_DraggableCleanActions` 中添加 `AnimatedOpacity`（200-300ms）实现出现/消失动画
  - 可选：在按钮位置变化或拖动时使用 `AnimatedContainer` 实现平滑过渡
  - 保留当前已有的拖动缩放效果（`_kScaleFactor = 1.1`）
- **Acceptance Criteria Addressed**: AC-4, AC-9, NFR-1
- **Test Requirements**:
  - `human-judgement` TR-3.1: 视觉检查 - 切换连播模式时，按钮有渐显/渐隐效果（不是突然出现/消失）
  - `human-judgement` TR-3.2: 交互检查 - 拖动按钮时有轻微放大效果，点击按钮时有按下反馈
  - `programmatic` TR-3.3: 代码审查 - 确认动画时长在 200-300ms 范围内

## [ ] Task 4: 响应式尺寸适配与代码整理
- **Priority**: P1
- **Depends On**: Task 3
- **Description**: 
  - 确保按钮尺寸使用 `responsiveSize()` 方法适配不同屏幕尺寸
  - 圆形按钮直径：`responsiveSize(40)` 或 `responsiveSize(48)`
  - 按钮间间距：`responsiveSize(16)`
  - 移除冗余代码：如果 `_DraggableCleanActions` 的 `containerSize` 参数在新的布局中不再必要，可简化
  - 确保 `kBottomNavHeight` 常量使用正确
- **Acceptance Criteria Addressed**: AC-7, AC-10, NFR-3
- **Test Requirements**:
  - `human-judgement` TR-4.1: 视觉检查 - 在手机屏幕上按钮尺寸合适，不显得过大
  - `human-judgement` TR-4.2: 视觉检查 - 在平板/桌面窗口上按钮尺寸不过小，保持可点击
  - `programmatic` TR-4.3: 代码审查 - 确认使用 `responsiveSize()` 而非硬编码数字

## [ ] Task 5: 验证所有功能 - 手动测试和代码审查
- **Priority**: P0
- **Depends On**: Task 1, Task 2, Task 3, Task 4
- **Description**: 
  - 启动应用，进入视频播放页面
  - 测试开启连播模式 → 检查按钮位置是否正确 → 关闭连播模式 → 检查按钮是否消失
  - 测试按钮拖动功能 → 检查按钮是否跟随手指移动 → 检查拖动范围限制
  - 测试横屏全屏模式 → 检查连播按钮是否正确隐藏
  - 测试倍速按钮 → 确保功能正常
  - 测试按钮视觉样式 → 确认半透明背景和圆角
  - 检查 git diff 范围，确保变更最小化
- **Acceptance Criteria Addressed**: AC-1, AC-2, AC-3, AC-4, AC-5, AC-6, AC-7, AC-8, AC-9, AC-10
- **Test Requirements**:
  - `human-judgement` TR-5.1: 端到端测试 - 连播模式按钮功能完整
  - `programmatic` TR-5.2: 代码审查 - diff 仅限于 `_buildCleanModeRightActions` 和 `_DraggableCleanActions` 相关代码
