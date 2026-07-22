# 全屏黑屏 Bug 修复 - 验证清单

- [x] Checkpoint 1: `isControllerReady` 判断包含 `!v.size.isEmpty` 条件（fullscreen_video_page.dart:722）
- [x] Checkpoint 2: `_buildVideoSurface` 不再在 `videoSize.isEmpty` 时返回 `SizedBox.shrink()`
- [x] Checkpoint 3: `_buildVideoSurface` 在尺寸为空时使用 1x1 占位尺寸
- [x] Checkpoint 4: 当 `isInitialized=true` 但 `size=Size.zero` 时显示加载指示器而非黑屏
- [x] Checkpoint 5: 尺寸恢复后视频正常显示，无异常行为
- [x] Checkpoint 6: 代码风格与现有代码一致
- [x] Checkpoint 7: 与 `VideoPlayerWidget` 的处理逻辑保持一致
