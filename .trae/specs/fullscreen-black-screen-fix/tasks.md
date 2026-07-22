# 全屏黑屏 Bug 修复 - 实施计划

## [x] Task 1: 修改 isControllerReady 判断逻辑
- **Priority**: high
- **Depends On**: None
- **Description**: 
  - 在 `fullscreen_video_page.dart` 第 722 行，将 `isControllerReady = v.isInitialized && !v.hasError` 修改为 `isControllerReady = v.isInitialized && !v.hasError && !v.size.isEmpty`
  - 增加尺寸检查，确保尺寸为空时不认为控制器就绪
- **Acceptance Criteria Addressed**: AC-1
- **Test Requirements**:
  - `programmatic` TR-1.1: 当 `isInitialized=true` 且 `size=Size.zero` 时，`isControllerReady` 应为 `false`
  - `programmatic` TR-1.2: 当 `isInitialized=true` 且 `size` 有效时，`isControllerReady` 应为 `true`

## [x] Task 2: 修改 _buildVideoSurface 使用占位尺寸
- **Priority**: high
- **Depends On**: Task 1
- **Description**: 
  - 修改 `fullscreen_video_page.dart` 的 `_buildVideoSurface` 方法
  - 移除 `if (videoSize.isEmpty) return const SizedBox.shrink();`
  - 使用 `hasValidSize ? videoSize.width : 1` 和 `hasValidSize ? videoSize.height : 1` 作为 `SizedBox` 尺寸
- **Acceptance Criteria Addressed**: AC-2
- **Test Requirements**:
  - `programmatic` TR-2.1: 当 `size=Size.zero` 时，`_buildVideoSurface` 返回包含 1x1 `SizedBox` 的组件（而非空组件）
  - `programmatic` TR-2.2: 当 `size` 有效时，使用实际尺寸渲染

## [x] Task 3: 验证修复效果
- **Priority**: high
- **Depends On**: Task 2
- **Description**: 
  - 验证进入全屏时不再出现纯黑屏
  - 验证尺寸恢复后视频正常显示
  - 验证加载指示器在尺寸为空时正确显示
- **Acceptance Criteria Addressed**: AC-3
- **Test Requirements**:
  - `human-judgment` TR-3.1: 进入全屏时，尺寸为空阶段显示加载指示器，而非黑屏
  - `human-judgment` TR-3.2: 尺寸恢复后视频正常播放，无异常闪烁

## Quality Checklist
- [x] Every acceptance criterion is addressed by at least one task
- [x] Every task has at least one test requirement
- [x] Dependencies form a valid DAG (no cycles)
- [x] Task granularity is consistent
- [x] Programmatic vs human-judgment verification is preserved correctly
