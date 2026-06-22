# 播放器控制功能（TDD）- The Implementation Plan

## [ ] Task 1：代码审查与当前状态分析
- **Priority**: P0
- **Depends On**: None
- **Description**:
  - 审查以下 5 个关键文件的当前实现状态，确认哪些功能已实现但存在 bug，哪些功能完全缺失
  - `widgets/video_page_item.dart`：_togglePlay 方法、中央按钮条件渲染、_controlsVisible 切换逻辑
  - `widgets/gesture_overlay.dart`：_handleTap 单击/双击区分、_onDoubleTap 区域判定、_onLongPressStart/End 加速、_onHorizontalDrag* 预览逻辑
  - `widgets/video_controls.dart`：播放/暂停按钮、图标切换、_togglePlay 同步 isPlayingProvider
  - `widgets/video/video_control_buttons.dart`：CenterPlayButton onTap 回调是否正确
  - `widgets/video/video_progress_bars.dart`：ThinProgressBar 渲染和监听器
  - `providers/video_playback_controller.dart`：确认 Provider 定义完整性
- **Acceptance Criteria Addressed**: 为后续任务提供准确的修复定位
- **Test Requirements**:
  - `programmatic` TR-1.1：确认 `VideoPageItem._togglePlay()` 方法是否正确调用 controller.play()/pause() 并更新 isPlayingProvider
  - `programmatic` TR-1.2：确认 `GestureOverlay._handleTap()` 是否正确处理单击/双击区分（300ms 定时器逻辑）
  - `programmatic` TR-1.3：确认 `VideoControls` 中 IconButton 的 onPressed 是否指向 `_togglePlay`
  - `human-judgment` TR-1.4：人工阅读确认各文件无编译错误（未定义标识符、导入缺失等）
- **Notes**: 这一步是 TDD 的基础 - 先理解现状再修复

## [ ] Task 2：中央播放按钮交互修复
- **Priority**: P0
- **Depends On**: Task 1
- **Description**:
  - 确保 `CenterPlayButton` 组件的 `onPlay` 回调被正确传递
  - 在 `VideoPageItem` 中，中央按钮的条件渲染为：`_videoController != null && _videoController!.value.isInitialized && !isPlaying`
  - 点击后调用 `_togglePlay()`，内部执行 `controller.play()`/`pause()` + 更新 `isPlayingProvider`
  - 验证 `isPlayingProvider` 变化后中央按钮正确消失
- **Acceptance Criteria Addressed**: AC-1, AC-11
- **Test Requirements**:
  - `programmatic` TR-2.1：验证 `_togglePlay()` 中 `controller.play()`/`pause()` 被正确调用，且 `isPlayingProvider` 状态同步更新
  - `programmatic` TR-2.2：验证中央按钮在 `isPlaying = false` 时渲染，在 `isPlaying = true` 时不渲染
  - `human-judgment` TR-2.3：手动测试点击中央按钮后播放状态切换是否符合预期
- **Notes**: 如果 `_togglePlay` 已存在，检查其逻辑是否正确（null 检查、isPlayingProvider 更新）

## [ ] Task 3：控制条播放/暂停按钮修复
- **Priority**: P0
- **Depends On**: Task 1
- **Description**:
  - 确保 `VideoControls` 组件中的播放/暂停 IconButton 正确连接到 `_togglePlay`
  - 图标根据 `controller.value.isPlaying` 动态切换为 pause/play_arrow
  - 点击后更新 `isPlayingProvider` 以驱动中央按钮的条件渲染
- **Acceptance Criteria Addressed**: AC-2, AC-11
- **Test Requirements**:
  - `programmatic` TR-3.1：验证 IconButton 的 `icon` 参数正确使用 `isPlaying ? Icons.pause : Icons.play_arrow`
  - `programmatic` TR-3.2：验证 `_togglePlay()` 内部同步更新 `isPlayingProvider`
  - `human-judgment` TR-3.3：手动测试控制条按钮与中央按钮状态同步

## [ ] Task 4：双击快进/快退修复
- **Priority**: P0
- **Depends On**: Task 1
- **Description**:
  - 确保 `GestureOverlay` 的 `_handleTap()` 正确使用 300ms 定时器区分单击/双击
  - `_onDoubleTap()` 中的 `_lastTapPosition` 正确记录 `onTapDown` 坐标
  - 区域判定逻辑（relativeX < 0.33 快退 / > 0.67 快进）正确执行
  - `_seekBySeconds()` 正确调用 `controller.seekTo()` + `HapticFeedback.lightImpact()`
  - 视觉反馈的条件渲染（`_showSeekFeedback` 状态）正确显示和隐藏
- **Acceptance Criteria Addressed**: AC-3, AC-4
- **Test Requirements**:
  - `programmatic` TR-4.1：验证 `_handleTap` 的 Timer 逻辑 - 300ms 内的第二次点击应取消定时器并触发 `_onDoubleTap`
  - `programmatic` TR-4.2：验证 `_seekBySeconds(-10)` 和 `_seekBySeconds(10)` 分别被正确调用
  - `programmatic` TR-4.3：验证 seek 后 `HapticFeedback.lightImpact()` 被调用
  - `human-judgment` TR-4.4：手动测试双击不同区域的反馈效果

## [ ] Task 5：长按加速播放修复
- **Priority**: P0
- **Depends On**: Task 1
- **Description**:
  - `_onLongPressStart()`：设置 `_isLongPressing = true`，调用 `setPlaybackSpeed(kLongPressPlaybackRate)`，更新 `playbackRateProvider` 为 2.0
  - `_onLongPressEnd()`：恢复 `_isLongPressing = false`，调用 `setPlaybackSpeed(originalRate)`（从 Provider 读取长按前的速度）
  - **关键改进**：当前实现中 `_onLongPressStart` 会将 `playbackRateProvider` 设置为 2.0，`_onLongPressEnd` 再从 Provider 读取恢复值——这意味着恢复值也是 2.0！需要在长按开始前**先保存原始速度**
- **Acceptance Criteria Addressed**: AC-5, AC-6
- **Test Requirements**:
  - `programmatic` TR-5.1：验证在 `_onLongPressStart` 中正确调用 `setPlaybackSpeed(kLongPressPlaybackRate)`
  - `programmatic` TR-5.2：**关键 bug 修复验证**：在 `_onLongPressStart` 之前先将 `controller.value.playbackSpeed` 保存到临时变量，`_onLongPressEnd` 用此变量恢复
  - `programmatic` TR-5.3：验证 `_SpeedBadge` 在 `_isLongPressing = true` 时条件渲染
  - `human-judgment` TR-5.4：手动测试长按加速 → 松手恢复，确认速度正确回到 1.0x（或长按前的倍速）

## [ ] Task 6：水平拖动进度预览修复
- **Priority**: P1
- **Depends On**: Task 1
- **Description**:
  - `_onHorizontalDragStart()`：记录 `_dragStartX` 和 `_dragStartPosition`，设置 `_isDragging = true`
  - `_onHorizontalDragUpdate()`：只更新 `_previewPosition` 变量 + setState 触发 `_SeekPreviewBar` 重绘，**不调用 seekTo**
  - `_onHorizontalDragEnd()`：单次调用 `controller.seekTo(_previewPosition)` + `HapticFeedback.lightImpact()`
  - 松手后 800ms 隐藏 `_SeekPreviewBar`
- **Acceptance Criteria Addressed**: AC-7, AC-8
- **Test Requirements**:
  - `programmatic` TR-6.1：验证拖动过程中 `controller.seekTo` **未被调用**（可通过日志或断点验证）
  - `programmatic` TR-6.2：验证松手时 `controller.seekTo` 被**精确调用一次**，参数为 `_previewPosition`
  - `programmatic` TR-6.3：验证 `_SeekPreviewBar` 在拖动中可见，松手 800ms 后消失
  - `human-judgment` TR-6.4：手动测试长距离拖动的平滑性和准确性

## [ ] Task 7：单击切换控制条修复
- **Priority**: P1
- **Depends On**: Task 1
- **Description**:
  - `GestureOverlay` 的 `_onSingleTap()` 调用 `widget.onSingleTap?.call()`
  - `VideoPageItem` 中将 `_toggleControls` 作为 `onSingleTap` 传入
  - `_toggleControls()` 切换 `_controlsVisible` 状态，控制 `VideoControls` 的可见性
  - 控制条显示后 3 秒自动隐藏（`_controlsAutoHideSeconds`）
- **Acceptance Criteria Addressed**: AC-9
- **Test Requirements**:
  - `programmatic` TR-7.1：验证 `onSingleTap` 参数正确传递，`GestureOverlay` 中 `_onSingleTap()` 正确调用回调
  - `programmatic` TR-7.2：验证 `_controlsVisible` 状态切换后，`VideoControls` 组件的 `AnimatedOpacity` 正确响应
  - `programmatic` TR-7.3：验证 3 秒自动隐藏 Timer 逻辑
  - `human-judgment` TR-7.4：手动测试单击画面 → 控制条显示 → 3 秒后消失

## [ ] Task 8：底部细线进度条修复
- **Priority**: P1
- **Depends On**: Task 1
- **Description**:
  - `ThinProgressBar` 组件正确监听 `controller.addListener(_onChanged)`
  - 计算 progress = `position.inMilliseconds / duration.inMilliseconds`
  - 渲染为 2px 高度的 Container，使用 `scheme.primary` 填充
  - 在 `VideoPageItem` 中正确条件渲染：`_videoController != null && _videoController!.value.isInitialized`
- **Acceptance Criteria Addressed**: AC-10
- **Test Requirements**:
  - `programmatic` TR-8.1：验证 `ThinProgressBar` 在 VideoPageItem 的 Stack 中被正确渲染（非被其他组件遮挡）
  - `programmatic` TR-8.2：验证 `controller.addListener` 在 initState 注册，dispose 时移除
  - `programmatic` TR-8.3：验证 progress 计算逻辑（0.0 - 1.0）正确
  - `human-judgment` TR-8.4：手动测试播放时进度条实时更新

## [ ] Task 9：空安全和初始化检查强化
- **Priority**: P1
- **Depends On**: Task 2-8 并行
- **Description**:
  - 确保所有手势处理方法在 `_controllerReady = false` 时安全 return
  - 确保 `_videoController` 为 null 时所有控制组件不渲染
  - 确保 dispose 时所有 Timer、Listener 被正确取消
- **Acceptance Criteria Addressed**: AC-12
- **Test Requirements**:
  - `programmatic` TR-9.1：代码审查所有交互方法的 null 检查
  - `programmatic` TR-9.2：验证 dispose 方法中所有资源清理（Timer.cancel、controller.removeListener）
  - `human-judgment` TR-9.3：在视频加载前快速点击各区域，确认无崩溃或错误日志

## [ ] Task 10：播放状态管理一致性审查
- **Priority**: P2
- **Depends On**: Task 2-9
- **Description**:
  - 审查 `isPlayingProvider` 在 `VideoPageItem`、`VideoControls`、`GestureOverlay` 三处的读写一致性
  - 审查 `playbackRateProvider` 在长按加速、倍速按钮、控制条中三处的读写一致性
  - 确保写入 `isPlayingProvider` 的唯一入口是 `_togglePlay()` 和 `VideoControls._onControllerChanged`
  - 清理不必要的重复状态更新
- **Acceptance Criteria Addressed**: AC-11（补充验证）
- **Test Requirements**:
  - `programmatic` TR-10.1：全代码搜索 `isPlayingProvider.notifier.state` 的所有写入点，确认逻辑一致
  - `programmatic` TR-10.2：全代码搜索 `playbackRateProvider.notifier.state` 的所有写入点，确认逻辑一致
  - `human-judgment` TR-10.3：代码可读性审查

## [ ] Task 11：主题颜色一致性检查
- **Priority**: P2
- **Depends On**: Task 2-9
- **Description**:
  - 确保所有新修改的组件使用 `Theme.of(context).colorScheme` 的语义化颜色
  - 搜索所有控制相关代码，确认无硬编码颜色值（如 `Colors.white`、`Colors.black`、十六进制值等）
  - 验证颜色在亮/暗主题切换下的可读性
- **Acceptance Criteria Addressed**: NFR-5
- **Test Requirements**:
  - `programmatic` TR-11.1：全代码搜索 `Colors.` 关键字，确认在播放控制相关组件中无直接使用
  - `human-judgment` TR-11.2：手动切换亮/暗主题，验证播放控制 UI 颜色协调性
