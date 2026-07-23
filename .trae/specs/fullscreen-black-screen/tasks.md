# 全屏视频播放黑屏问题修复 - 实施计划

## [ ] Task 1: 修复 isControllerUsableForFullscreen 缺少尺寸检查
- **Priority**: high
- **Depends On**: None
- **Description**:
  - 在 `isControllerUsableForFullscreen` 方法中增加 `!v.size.isEmpty` 检查
  - 确保只有视频尺寸有效时才允许进入全屏
- **Acceptance Criteria Addressed**: AC-1
- **Test Requirements**:
  - `programmatic` TR-1.1: isControllerUsableForFullscreen 方法中包含 `!v.size.isEmpty` 检查
  - `programmatic` TR-1.2: 当 controller 已初始化但尺寸为空时，返回 false

## [ ] Task 2: 修复全屏页 isControllerReady 判断过于严格
- **Priority**: high
- **Depends On**: None
- **Description**:
  - 修改全屏页 `isControllerReady` 判断逻辑，不再要求尺寸非空
  - 引入 `hasValidSize` 变量单独判断尺寸有效性
  - VideoPlayer 组件在尺寸为空时使用占位尺寸（如 1x1）
- **Acceptance Criteria Addressed**: AC-2, AC-4
- **Test Requirements**:
  - `programmatic` TR-2.1: isControllerReady 判断不包含尺寸检查
  - `programmatic` TR-2.2: VideoPlayer 组件在尺寸为空时仍被构建
  - `programmatic` TR-2.3: 尺寸更新后 setState 触发重建

## [ ] Task 3: 修复全屏页加载指示器显示逻辑
- **Priority**: medium
- **Depends On**: Task 2
- **Description**:
  - 修改加载指示器显示条件：仅在 controller 未初始化或有错误时显示
  - 当 controller 已初始化但尺寸为空时，显示 VideoPlayer（使用占位尺寸）而非加载指示器
- **Acceptance Criteria Addressed**: AC-3
- **Test Requirements**:
  - `human-judgment` TR-3.1: controller 已初始化且无错误时不显示加载指示器
  - `human-judgment` TR-3.2: 视频画面能正常显示，无黑屏

## [ ] Task 4: 代码审查和验证
- **Priority**: medium
- **Depends On**: Task 1, Task 2, Task 3
- **Description**:
  - 验证修改后的代码逻辑正确性
  - 检查是否引入新的 Bug
  - 确保修复与现有代码兼容
- **Acceptance Criteria Addressed**: AC-1, AC-2, AC-3, AC-4
- **Test Requirements**:
  - `human-judgment` TR-4.1: 代码符合项目命名规范和代码风格
  - `human-judgment` TR-4.2: 修改逻辑清晰，注释准确
