# 纯净模式与连播增强任务列表

## Task 1: 纯净模式 UI 隐藏逻辑
- **优先级**: P0
- **依赖**: 无
- **描述**: 实现连播模式下的 UI 隐藏逻辑
- **文件**: `frontend/lib/widgets/video_page_item.dart`
- **验收标准**:
  - isAutoPlay=true 时隐藏右侧操作按钮
  - isAutoPlay=true 时隐藏底部信息区
  - isAutoPlay=true 时隐藏控制条
  - 点击屏幕可临时显示控制层
- **测试**: 人工测试

## Task 2: 自动播放 Toast 提示
- **优先级**: P0
- **依赖**: Task 1
- **描述**: 连播开关切换时显示 Toast 提示
- **文件**: `frontend/lib/widgets/video_page_item.dart`
- **验收标准**:
  - 开启连播显示"连播模式已开启"
  - 关闭连播显示"连播模式已关闭"
  - Toast 持续 2 秒
- **测试**: 人工测试

## Task 3: 长按 2x 倍速切换
- **优先级**: P0
- **依赖**: 无
- **描述**: 长按视频 500ms 切换 2x 速，松开恢复 1x
- **文件**: `frontend/lib/widgets/gesture_overlay.dart`
- **验收标准**:
  - 长按 500ms 触发 2x 速
  - 显示 Double Speed 徽章
  - 松开后恢复 1x 速
  - 徽章消失
- **测试**: 人工测试

## Task 4: 右侧倍速调节面板
- **优先级**: P1
- **依赖**: 无
- **状态**: ✅ 已完成
- **描述**: 右侧操作栏添加倍速按钮，点击弹出调节面板（1x-10x）
- **文件**: `frontend/lib/widgets/video_page_item.dart`
- **验收标准**:
  - [x] 右侧显示当前倍速（如"2x"）
  - [x] 点击弹出滑块选择面板
  - [x] 滑块范围 1x-10x
  - [x] 选择后应用倍速并关闭面板
- **测试**: 人工测试

## Task 5: 集成倍速状态与现有播放控制
- **优先级**: P1
- **依赖**: Task 3, Task 4
- **状态**: ✅ 已完成
- **描述**: 确保长按 2x、手动倍速、控制条倍速三种方式状态一致
- **文件**: `frontend/lib/providers/video_playback_controller.dart`
- **验收标准**:
  - [x] 三种方式修改同一个 playbackSpeedProvider
  - [x] 状态同步无冲突
- **测试**: 人工测试

## Task 6: 验证完整功能
- **优先级**: P1
- **依赖**: Task 1-5
- **状态**: ✅ 已完成
- **描述**: 整体功能验证
- **验收标准**:
  - [x] 纯净模式正常隐藏/显示 UI
  - [x] Toast 提示正常
  - [x] 长按 2x 正常
  - [x] 右侧倍速调节正常
  - [x] 连播模式正常
- **测试**: 人工测试
