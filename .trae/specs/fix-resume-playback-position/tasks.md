# Tasks

## 任务 1：VideoPlayerWidget 新增续播参数和 seek 逻辑
- [x] 1.1 修改 `VideoPlayerWidget` 构造函数，新增 `startFromResumePosition` 参数（默认 false）
- [x] 1.2 在 `_initVideo()` 中，调用 `onControllerReady` 之后、`play()` 之前，插入 seek 逻辑：
  - 检查 `startFromResumePosition` 和 `item.userData?.playbackPositionTicks`
  - 计算目标毫秒数 `posMs = (posTicks / 10000.0).round()`
  - 执行 `await _controller!.seekTo(Duration(milliseconds: posMs))`
  - seek 失败时记录日志（不静默吞掉）
- [x] 1.3 同时处理 Path 1（预加载控制器）和 Path 2（动态创建）两个分支

## 任务 2：video_page_item 移除 seek 逻辑，传递新参数
- [x] 2.1 移除 `onControllerReady` 回调中的 seek 代码块（L508-L520）
- [x] 2.2 给 `VideoPlayerWidget` 传递 `startFromResumePosition: widget.startFromResumePosition`

## 任务 3：验证
- [x] 3.1 运行 flutter analyze 确保无 error
- [x] 3.2 代码审查确认 seek 在 play 之前执行
- [x] 3.3 确认 seek 失败时有日志输出