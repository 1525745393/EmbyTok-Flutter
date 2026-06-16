# EmbyTok 滑动进度控制 - 验证清单

## 常量与配置检查
- [ ] Checkpoint 1: `constants.dart` 中正确添加了 `kProgressBarFadeInMs`（=150）、`kProgressBarFadeOutMs`（=300）、`kProgressBarAnimMs`（=80）
- [ ] Checkpoint 2: `colors.dart` 中颜色常量正确引用（`overlayBlack`、`primaryPink`、`textPrimary`、`textSecondary`）

## 功能行为检查
- [ ] Checkpoint 3: 在视频流页面（feed 模式）按住屏幕并水平拖动→进度条浮层出现，150ms 内淡入
- [ ] Checkpoint 4: 向右滑动→进度条显示 `⏩` 图标和正偏移量（如 `+12s`），时间向前推进
- [ ] Checkpoint 5: 向左滑动→进度条显示 `⏪` 图标和负偏移量（如 `-45s`），时间向后回退
- [ ] Checkpoint 6: 拖动过程中，时间文本和进度条填充宽度实时更新，响应时间 < 100ms
- [ ] Checkpoint 7: 松开手指→进度条 300ms 内淡出，视频从新位置继续播放
- [ ] Checkpoint 8: 拖动开始时触发轻震动（`HapticFeedback.selectionClick`）
- [ ] Checkpoint 9: 拖动过程中每跨越 5 秒边界触发轻震动
- [ ] Checkpoint 10: 拖动结束时触发稍强震动（`HapticFeedback.lightImpact`）

## 边界情况检查
- [ ] Checkpoint 11: 视频刚开始（0:00）时向左滑→进度条停在 0:00，不继续后退，不崩溃
- [ ] Checkpoint 12: 视频接近末尾时向右滑→进度条停在总时长，不继续前进，不崩溃
- [ ] Checkpoint 13: 视频总时长未知（`Duration.zero`）时→进度条不显示或返回空容器，不崩溃
- [ ] Checkpoint 14: 短内容（<1 分钟）→时间显示为 `MM:SS`（如 `00:35 / 00:45`）
- [ ] Checkpoint 15: 长内容（>1 小时）→时间显示为 `HH:MM:SS`（如 `00:05:23 / 01:30:00`）

## 手势冲突检查
- [ ] Checkpoint 16: 单击视频画面→正常播放/暂停切换，不触发进度条
- [ ] Checkpoint 17: 双击视频画面→正常触发点赞心形动画，不触发进度条
- [ ] Checkpoint 18: 长按视频→正常触发倍速播放，显示 `2.0x` 徽章，不触发进度条
- [ ] Checkpoint 19: 垂直滑动（向上/向下）→正常切换上一个/下一个视频，不触发进度条
- [ ] Checkpoint 20: 快速地在"长按→水平滑动"之间交替→手势竞技场行为正常，不出现意外状态残留
- [ ] Checkpoint 21: 正在拖动进度条时突然松开+立即单击→播放状态正常（暂停/播放），无双重事件

## UI 与视觉检查
- [ ] Checkpoint 22: 进度条浮层背景为半透明黑色（`Color(0xAA000000)`），圆角 16px，位于屏幕中上方（top: 120）
- [ ] Checkpoint 23: 进度条填充色为粉色（`primaryPink`），背景条为白色半透明（`Color(0x26FFFFFF)` 或类似）
- [ ] Checkpoint 24: 文本颜色：偏移量和时间为白色（`textPrimary`），总时长为灰色（`textSecondary`）
- [ ] Checkpoint 25: 进度条的图标和文本风格与 `_SpeedBadge` 保持一致（字体大小 14-16，加粗或半加粗）
- [ ] Checkpoint 26: 淡入淡出动画平滑，无闪烁或跳跃感
- [ ] Checkpoint 27: 进度条填充宽度精确对应 `currentPosition/totalDuration`（不允许有超过 5% 的视觉偏差）

## 代码质量检查
- [ ] Checkpoint 28: `_ProgressBarOverlay` 作为私有组件放在 `gesture_overlay.dart` 中，与 `_FlyingHeart`、`_SpeedBadge` 同级
- [ ] Checkpoint 29: 所有新增代码都有简洁中文注释，解释关键逻辑
- [ ] Checkpoint 30: 没有硬编码颜色、字体大小等常量（除了进度条自身的内部布局微调常量，可以接受硬编码但建议抽取为局部 const）
- [ ] Checkpoint 31: 没有新增未使用的 import
- [ ] Checkpoint 32: `_formatDuration` 函数处理了 `Duration.zero`、负数等边界情况
- [ ] Checkpoint 33: `_currentTargetPosition`、`_dragOffset` 等字段在 `dispose` 时不需要特殊处理（非资源型字段）
- [ ] Checkpoint 34: `_progressHideTimer`（如果使用的话）在 `dispose` 中被 `cancel()`

## 性能检查
- [ ] Checkpoint 35: 快速拖动（约 500px/s）时，UI 仍保持 50+ FPS（可在 Flutter DevTools 中查看帧率）
- [ ] Checkpoint 36: `_onHorizontalDragUpdate` 中的 `setState` 不会触发整棵子树的重建——`AnimatedOpacity`/`AnimatedContainer` 做局部更新
- [ ] Checkpoint 37: 进度条淡出动画期间，底层 `VideoPlayer` 继续流畅播放，无音频卡顿

## 兼容性检查
- [ ] Checkpoint 38: 网格视图（`ViewMode.grid`）不受影响，视频卡片正常显示
- [ ] Checkpoint 39: 横屏全屏模式下，水平拖动进度条正常工作（位置调整为屏幕中央）
- [ ] Checkpoint 40: 切换页面（feed → search → favorites → history → settings）后，再回到 feed 页面，进度条功能正常
- [ ] Checkpoint 41: 不同屏幕尺寸（小屏/普通/大屏平板）下，进度条宽度自适应（使用 `MediaQuery.of(context).size.width * 0.85`）
