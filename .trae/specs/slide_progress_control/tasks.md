# EmbyTok 滑动进度控制 - 实施计划

## 实施范围
**核心改动**：`lib/widgets/gesture_overlay.dart`（在现有水平拖动逻辑中添加视觉进度条浮层）
**辅助改动**：`lib/utils/constants.dart`（添加动画时长等常量）

---

## [ ] Task 1: 补充常量定义（constants.dart）
- **Priority**: P0
- **Depends On**: None
- **Description**:
  - 在 [constants.dart](file:///workspace/frontend/lib/utils/constants.dart) 中添加：
    - `kProgressBarFadeInMs = 150`：进度条淡入时长
    - `kProgressBarFadeOutMs = 300`：进度条淡出时长
    - `kProgressBarAnimMs = 80`：进度条内部填充动画（避免过快抖动）
  - 说明：这些常量控制进度条动画的节奏，与现有 `kToolbarAnimMs = 200` 不同步（更快的响应更自然）
- **Acceptance Criteria Addressed**: AC-1, AC-4, FR-6
- **Test Requirements**:
  - `human-judgement` TR-1.1: 常量命名语义清晰，放在 constants.dart 中易于找到
- **Notes**: 这些值可以在后续优化中微调，作为参数暴露便于调参

## [ ] Task 2: 时间格式化辅助函数（gesture_overlay.dart 内私有函数）
- **Priority**: P0
- **Depends On**: None
- **Description**:
  - 在 [gesture_overlay.dart](file:///workspace/frontend/lib/widgets/gesture_overlay.dart) 顶部（现有 import 之后，或作为私有函数）添加：
    - `String _formatDuration(Duration d)`：将 `Duration` 格式化为 `HH:MM:SS`（如果超过 1 小时）或 `MM:SS`（如果小于 1 小时）
    - 逻辑：`if (d.inHours >= 1) return '${d.inHours.toString().padLeft(2, '0')}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}'; else return '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';`
  - 此函数用于进度条上的时间显示
- **Acceptance Criteria Addressed**: AC-2
- **Test Requirements**:
  - `human-judgement` TR-2.1: 函数能正确处理 0 秒、小于 1 小时、大于等于 1 小时三种情况
  - `human-judgement` TR-2.2: 输出格式前后一致（如总是两位分钟、两位秒数）
- **Notes**: 这是一个纯函数，便于测试和复用

## [ ] Task 3: 创建进度条浮层子组件 `_ProgressBarOverlay`
- **Priority**: P0
- **Depends On**: Task 1, Task 2
- **Description**:
  - 在 [gesture_overlay.dart](file:///workspace/frontend/lib/widgets/gesture_overlay.dart) 中添加私有 `StatefulWidget` `_ProgressBarOverlay`（与现有的 `_FlyingHeart` 和 `_SpeedBadge` 同级）
  - 构造函数参数：
    - `required Duration currentPosition`：拖动到的目标位置
    - `required Duration totalDuration`：视频总时长
    - `required Duration offsetFromStart`：相对于起始拖动位置的偏移量（可为负值，表示快退）
    - `required bool isVisible`：是否可见（用于控制淡入淡出）
    - `required double widthRatio`：进度条宽度（0.0-1.0，对应屏幕宽度的比例，默认 0.85）
  - UI 结构（`Stack` 内的 `Positioned` 叠加）：
    - 外层：半透明黑色圆角容器（`BoxDecoration` + `overlayBlack` 背景，`borderRadius: 16`），内部 `padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12)`
    - 顶部一行：方向图标（左滑 `Icons.fast_rewind`，右滑 `Icons.fast_forward`，颜色 `primaryPink`）+ 偏移量文本（如 `+12s` 或 `-45s`，颜色 `textPrimary`）+ 当前时间 / 总时长文本（颜色 `textSecondary`）
    - 底部一行：可视化进度条（`Stack` 内 `AnimatedContainer`）
      - 背景：`Colors.white.withOpacity(0.15)` 灰色长条
      - 填充：`primaryPink` 色条，宽度 = `currentPosition.inMilliseconds / totalDuration.inMilliseconds * parentWidth`
      - 顶部有一个小三角形或圆形指示器标记当前播放点
  - 动画：
    - 显隐使用 `AnimatedOpacity`（0 ↔ 1.0，时长由 `kProgressBarFadeInMs` / `kProgressBarFadeOutMs` 控制）
    - 填充条宽度变化使用 `AnimatedContainer`（`Duration(milliseconds: kProgressBarAnimMs)`，曲线 `Curves.easeOut`）
    - 整体宽度使用 `AnimatedContainer`（淡入时从 0.8 * 屏幕宽度扩展到 0.85，增强弹性感）
- **Acceptance Criteria Addressed**: AC-1, AC-2, AC-3, AC-4, FR-2, FR-6
- **Test Requirements**:
  - `human-judgement` TR-3.1: 进度条浮层在屏幕中上方居中显示（`top: 120`），不被顶部工具栏遮挡（当工具栏展开时可能会被遮挡一部分，但这是可接受的，因为 120px 已经足够远离）
  - `human-judgement` TR-3.2: 文本、图标色彩与现有 UI（`_SpeedBadge`）风格一致
  - `human-judgement` TR-3.3: 进度条填充宽度严格对应 currentPosition/totalDuration 比例
  - `human-judgement` TR-3.4: 动画流畅（淡入、填充伸缩、淡出均自然）
- **Notes**: 该组件需要 `Duration.zero` 作为 `totalDuration` 的安全检查——如果 totalDuration 为 0，则不显示进度条（隐藏），避免除零错误

## [ ] Task 4: 在 `_GestureOverlayState` 中追踪拖动状态并触发 UI
- **Priority**: P0
- **Depends On**: Task 3
- **Description**:
  - 在 `_GestureOverlayState` 中添加新字段：
    - `Duration? _currentTargetPosition`：当前拖动目标位置（初始为 `null`，拖动结束后设回 `null`）
    - `Duration _dragOffset = Duration.zero`：当前相对于起点的偏移量（用于显示 `+/- Xs`）
    - `Timer? _progressHideTimer`：拖动结束后的淡出延迟计时器（可选项——如果使用 AnimatedOpacity 的动画曲线配合 `isVisible = false` 即可，不需要额外 Timer）
  - 修改 `_onHorizontalDragStart`（line 94）：
    - 设置 `_currentTargetPosition = _dragStartPosition`
    - 设置 `_dragOffset = Duration.zero`
    - 添加 `HapticFeedback.selectionClick()`（已有，line 100）
    - **添加** `setState(() {})` 以触发重绘（因为状态字段改变了）——目前代码已经隐式地做了这件事，因为 `_onHorizontalDragUpdate` 中有 `setState` 来更新 `_currentTargetPosition`
  - 修改 `_onHorizontalDragUpdate`（line 104）：
    - 保留现有 seek 逻辑（line 108-116）
    - **新增** `setState(() { _currentTargetPosition = clamped; _dragOffset = clamped - _dragStartPosition; })` 来更新位置显示
    - 保留现有 5 秒边界 haptic 逻辑（line 117-122）
  - 修改 `_onHorizontalDragEnd`（line 125）：
    - **新增** `HapticFeedback.lightImpact()`（拖动结束反馈）
    - **新增** `Future.delayed(Duration(milliseconds: kProgressBarFadeOutMs ~/ 2), () { if (mounted) setState(() { _currentTargetPosition = null; }); })`——使用延迟来在淡出动画进行中保持状态，动画结束后清除
    - 保留 `_isDragging = false; _lastSeenSeconds = -1;`
  - 修改 `build` 方法（line 155）：
    - 在 `Stack` 的 `children` 中，在 `_SpeedBadge` 之后、`_FlyingHeart` 之后，**添加** `_ProgressBarOverlay`（包裹在 `Positioned(top: 120, left: 0, right: 0)` 中）
    - 传递参数：`isVisible = _currentTargetPosition != null && _isDragging`（或更简单：`isVisible = _isDragging`，因为 `_currentTargetPosition` 仅在 `_isDragging` 时有效）
    - `currentPosition = _currentTargetPosition ?? _dragStartPosition`
    - `totalDuration = widget.controller?.value.duration ?? Duration.zero`
    - `offsetFromStart = _dragOffset`
- **Acceptance Criteria Addressed**: AC-1, AC-2, AC-3, AC-4, AC-5, AC-6
- **Test Requirements**:
  - `human-judgement` TR-4.1: 水平拖动时进度条立即出现（150ms 淡入）
  - `human-judgement` TR-4.2: 拖动中时间显示实时更新，填充条实时伸缩
  - `human-judgement` TR-4.3: 松开手指 300ms 内进度条淡出
  - `human-judgement` TR-4.4: 松开后视频从新位置继续播放
  - `human-judgement` TR-4.5: 拖到 0 秒或视频末尾时，进度条显示边界值且不再变化
- **Notes**: 关键优化：`_onHorizontalDragUpdate` 中避免重复 `setState`——可以使用 `_currentTargetPosition` 的值判断是否需要 setState（例如只有当 inSeconds 变化时才 setState）。但由于 Flutter 的 diffing 机制，简单的每次 setState 开销不大，且保证响应及时性，可以先保留此简化实现。

## [ ] Task 5: 手势冲突处理与边界保护
- **Priority**: P1
- **Depends On**: Task 4
- **Description**:
  - 在 `_handleTap` 中增加检查：**如果 `_isDragging == true`，则忽略单击/双击**（虽然这在当前实现中可能已经由 Flutter 的手势竞技场处理，但显式检查是防御性编程的好习惯）
  - 在 `_onHorizontalDragUpdate` 中加强边界检查：确保 `clamped` 不会超出 `[Duration.zero, duration]` 范围（已有 line 111-115）——无需修改
  - 在 `_ProgressBarOverlay` 的 `build` 中添加空值检查：如果 `totalDuration == Duration.zero` 或 `totalDuration.inMilliseconds <= 0`，则 `return SizedBox.shrink()`（不渲染任何东西）
  - 验证：`_ProgressBarOverlay` 不应该拦截任何手势（应该包裹在 `IgnorePointer` 或 `Positioned` 中且不接收 pointer events）——默认 Widget 不接收事件，除非显式添加 `GestureDetector`
- **Acceptance Criteria Addressed**: AC-6, AC-7
- **Test Requirements**:
  - `human-judgement` TR-5.1: 在视频开头（0:00）向左滑，进度条正确显示 `⏪ 00:00` 并保持不动
  - `human-judgement` TR-5.2: 在视频末尾向右滑，进度条正确显示 `⏩ [总时长]` 并保持不动
  - `human-judgement` TR-5.3: 拖动中快速切换到单击/双击，不会误触发播放/暂停或点赞
  - `human-judgement` TR-5.4: 垂直滑动切换视频时，进度条不会出现

## [ ] Task 6: 代码审查与静态分析
- **Priority**: P1
- **Depends On**: Task 1, Task 2, Task 3, Task 4, Task 5
- **Description**:
  - 确保所有新增代码使用中文注释，解释关键逻辑
  - 确保没有硬编码的颜色值——使用 `colors.dart` 中的常量
  - 确保没有未使用的 import、变量或方法
  - 确保 `_ProgressBarOverlay` 作为私有子组件——不需要暴露给外部文件
  - 确保文件改动行数控制在合理范围（预期 +80 ~ +120 行）
- **Acceptance Criteria Addressed**: AC-10
- **Test Requirements**:
  - `human-judgement` TR-6.1: 代码结构与现有的 `_FlyingHeart`、`_SpeedBadge` 一致（命名风格、代码组织）
  - `human-judgement` TR-6.2: 所有新增的 Widget、字段、函数都有简洁中文注释说明
  - `human-judgement` TR-6.3: 不引入任何新的 package import

## [ ] Task 7: 手动集成测试（用户验收）
- **Priority**: P2
- **Depends On**: Task 6
- **Description**:
  - 在真机或模拟器上运行应用，测试以下场景：
    - 场景 A：短内容（<1 分钟）的快进/快退
    - 场景 B：中等内容（10-60 分钟）的快进/快退
    - 场景 C：长内容（>1 小时）的快进/快退——验证时间格式切换到 HH:MM:SS
    - 场景 D：多次快速的左右交替滑动（验证状态切换的稳定性）
    - 场景 E：在工具栏展开/折叠两种状态下拖动（验证不冲突）
    - 场景 F：横屏全屏模式下拖动（验证布局依然正常）
    - 场景 G：快速连续地单击/双击/水平拖动（验证手势解耦）
- **Acceptance Criteria Addressed**: AC-1 ~ AC-9
- **Test Requirements**:
  - `human-judgement` TR-7.1: 所有 7 个场景都达到预期效果，无崩溃、无视觉异常
  - `human-judgement` TR-7.2: 视频流畅播放，拖动后的画面从正确位置继续

## 实施时间线估算
| Task | 预估耗时 |
|------|---------|
| Task 1: 常量定义 | 5 分钟 |
| Task 2: 时间格式化函数 | 10 分钟 |
| Task 3: `_ProgressBarOverlay` 子组件 | 40 分钟 |
| Task 4: 状态追踪与触发 | 20 分钟 |
| Task 5: 手势冲突与边界保护 | 10 分钟 |
| Task 6: 代码审查 | 10 分钟 |
| Task 7: 手动测试 | 20 分钟 |
| **总计** | **~115 分钟** |
