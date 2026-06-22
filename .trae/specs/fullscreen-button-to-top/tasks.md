# 全屏按钮移动到顶部操作区 - 实施任务计划

## [ ] Task 1: 新建 _buildTopActions() - 顶部操作区组件
- **Priority**: P0
- **Depends On**: None
- **Description**:
  - 在 `video_page_item.dart` 中新增 `_buildTopActions()` 方法
  - 返回一个 `Positioned` Widget，定位在视频容器右上角
  - 位置：`top: topPadding + 8, right: 16`
  - 视觉样式：半透明黑色背景卡片（`Color(0x66000000)`），圆角 16px
  - 包含一个圆形按钮，图标为 `Icons.fullscreen`（竖屏）或 `Icons.fullscreen_exit`（横屏）
  - 使用 `responsiveSize()` 计算按钮尺寸
  - 添加 `AnimatedOpacity` 动画（200ms 渐入渐出）
  - 点击触发 `_toggleFullscreen()`
- **Acceptance Criteria Addressed**: AC-1, AC-2, AC-3, AC-7, AC-8, AC-9
- **Test Requirements**:
  - `human-judgement` TR-1.1: 视觉检查 - 按钮显示在视频容器右上角
  - `human-judgement` TR-1.2: 视觉检查 - 按钮有半透明黑色背景和圆角
  - `human-judgement` TR-1.3: 交互检查 - 点击按钮可切换全屏
  - `human-judgement` TR-1.4: 交互检查 - 横屏时图标变为 fullscreen_exit
  - `programmatic` TR-1.5: 代码审查 - 使用 responsiveSize() 计算尺寸
- **Notes**: 参考 `_buildCleanModeRightActions()` 中的卡片样式以保持视觉一致性。

## [ ] Task 2: 删除右侧操作区的全屏按钮
- **Priority**: P0
- **Depends On**: Task 1
- **Description**:
  - 在 `_buildRightActions()` 方法中，删除原来的"10. 全屏按钮"代码块
  - 即删除 L1037-L1043 附近的 `_buildActionButton(fullscreen/exit)` 调用
  - 保持其他按钮（1-9、11）不变，间距不变
- **Acceptance Criteria Addressed**: AC-4, AC-10
- **Test Requirements**:
  - `human-judgement` TR-2.1: 视觉检查 - 右侧操作区不再显示全屏按钮
  - `human-judgement` TR-2.2: 视觉检查 - 其他按钮顺序和位置保持不变
  - `programmatic` TR-2.3: 代码审查 - `_buildRightActions()` 中不包含 `Icons.fullscreen` 相关调用

## [ ] Task 3: 删除或替换 _buildExitFullscreenButton() - 横屏模式统一
- **Priority**: P0
- **Depends On**: Task 1, Task 2
- **Description**:
  - 删除 `_buildExitFullscreenButton()` 方法（L736-L746 附近）
  - 或保留方法但不再调用（取决于代码审查的简洁性）
  - 在 build 方法中，将 `if (_isFullscreen) _buildExitFullscreenButton()` 改为直接渲染 `_buildTopActions()`
  - 实际上：`_buildTopActions()` 应在所有模式下都渲染（横屏+竖屏+连播模式）
  - 在 build 方法中调整：将 `_buildTopActions()` 改为无条件渲染，替代原来的条件判断
- **Acceptance Criteria Addressed**: AC-3, AC-5, AC-6
- **Test Requirements**:
  - `human-judgement` TR-3.1: 视觉检查 - 横屏模式下右上角显示退出全屏按钮
  - `human-judgement` TR-3.2: 交互检查 - 横屏时点击按钮可回到竖屏
  - `programmatic` TR-3.3: 代码审查 - `_buildExitFullscreenButton` 不再被任何地方调用
  - `human-judgement` TR-3.4: 视觉检查 - 连播模式下右上角显示全屏按钮

## [ ] Task 4: 更新 build 方法渲染逻辑
- **Priority**: P0
- **Depends On**: Task 1, Task 2, Task 3
- **Description**:
  - 在 build 方法的 Stack children 中添加 `_buildTopActions()` 的渲染调用
  - `_buildTopActions()` 应在所有模式下都渲染（不依赖 `!_isFullscreen`）
  - 确保 `_buildTopActions()` 的渲染顺序：在底部信息条和右侧操作区之前或之后都可以，因为位置不重叠
  - 可能需要调整 Stack 中的 z-order，使顶部操作区不被其他组件遮挡
- **Acceptance Criteria Addressed**: AC-1, AC-6, AC-10
- **Test Requirements**:
  - `human-judgement` TR-4.1: 视觉检查 - 竖屏非连播模式下顶部操作区正常显示
  - `human-judgement` TR-4.2: 视觉检查 - 横屏模式下顶部操作区正常显示
  - `human-judgement` TR-4.3: 视觉检查 - 连播模式下顶部操作区正常显示，不被其他组件遮挡
  - `programmatic` TR-4.4: 代码审查 - build 方法中正确调用 `_buildTopActions()`

## [ ] Task 5: 验证所有功能 - 手动测试和代码审查
- **Priority**: P0
- **Depends On**: Task 1, Task 2, Task 3, Task 4
- **Description**:
  - 在真实设备或模拟器上测试竖屏模式的全屏切换
  - 测试横屏模式的退出全屏
  - 测试连播模式下的全屏切换
  - 测试右侧操作区按钮数量减少后的视觉效果
  - 检查顶部操作区与连播模式浮层按钮的视觉风格一致性
  - Git diff 审查：确保变更范围最小化
- **Acceptance Criteria Addressed**: AC-1 through AC-10
- **Test Requirements**:
  - `human-judgement` TR-5.1: 端到端测试 - 全屏功能在所有模式下正常工作
  - `human-judgement` TR-5.2: 视觉检查 - 顶部操作区与右下角浮层视觉风格一致
  - `human-judgement` TR-5.3: 视觉检查 - 右侧操作区减少一个按钮后，其他按钮布局正常
  - `programmatic` TR-5.4: 代码审查 - diff 仅包含：新增 `_buildTopActions()`、删除右侧全屏按钮、build 方法调整、删除 `_buildExitFullscreenButton()` 调用
