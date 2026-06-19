# 视频详情弹窗增强 + 底部进度条 - 验证检查清单

## 视频详情弹窗检查项

- [ ] Checkpoint 1: 点击「ℹ 信息」按钮后，BottomSheet 从底部弹出
- [ ] Checkpoint 2: 弹窗标题区域显示视频标题（含年份，如 "电影名 (2023)）
- [ ] Checkpoint 3: 副标题区域显示类型标签（粉色背景）、年份、剧集信息（如有）
- [ ] Checkpoint 4: 基本信息行显示时长（如 "1h 30m"）
- [ ] Checkpoint 5: 基本信息行显示评分（如 "★ 8.5"），无评分时隐藏
- [ ] Checkpoint 6: 基本信息行显示类型（如 "剧情 / 动作"）
- [ ] Checkpoint 7: 基本信息行显示制作公司/工作室（如有）
- [ ] Checkpoint 8: 简介区域显示完整简介（多行，支持滚动）
- [ ] Checkpoint 9: 演员区域显示主要演员姓名（前 5 人）
- [ ] Checkpoint 10: 导演区域显示导演姓名（如有）
- [ ] Checkpoint 11: 缺失某些元信息时，对应区域优雅隐藏或显示「暂无数据」
- [ ] Checkpoint 12: 剧集类型视频显示剧集名和季/集信息
- [ ] Checkpoint 13: 弹窗支持拖动调整高度（最小 30%，最大 90%）
- [ ] Checkpoint 14: 下滑或点击空白区域可关闭弹窗
- [ ] Checkpoint 15: 弹窗背景色为半透明黑色（`Color(0xE6000000)`）
- [ ] Checkpoint 16: 文字颜色使用 `textPrimary`/`textSecondary`/`primaryPink`，与现有 UI 一致
- [ ] Checkpoint 17: 弹窗顶部显示小把手指示器（提示可下滑关闭）
- [ ] Checkpoint 18: 弹窗内所有内容可通过 ListView 正常滚动

## 底部信息条播放进度检查项

- [ ] Checkpoint 19: 底部渐变信息条存在并显示类型标签
- [ ] Checkpoint 20: 标题行显示视频标题（maxLines=2）
- [ ] Checkpoint 21: 标题行右侧显示评分（★ X.X 格式，如无评分则不显示）
- [ ] Checkpoint 22: 简介文本存在时显示单行简介（如有）
- [ ] Checkpoint 23: 在简介下方新增播放进度条（LinearProgressIndicator 或等效组件）
- [ ] Checkpoint 24: 进度条已播放部分使用 `primaryPink` 颜色
- [ ] Checkpoint 25: 进度条未播放部分使用深灰色
- [ ] Checkpoint 26: 进度条右侧显示时间文本（格式：`当前时间 / 总时间`）
- [ ] Checkpoint 27: 进度条高度合理（约 3-4dp）
- [ ] Checkpoint 28: 进度条圆角为 2dp 或轻微圆角
- [ ] Checkpoint 29: 时间文本字体为 11-12 号字，`textSecondary` 颜色，右侧对齐
- [ ] Checkpoint 30: 视频播放过程中，进度条随播放持续增长（每 500ms 内可见变化）
- [ ] Checkpoint 31: 视频暂停时，进度条停止增长（位置不变）
- [ ] Checkpoint 32: 视频结束时，进度条达到 100%（如总时长）
- [ ] Checkpoint 33: 无有效时长时（_videoController 为 null 或 duration 为 zero），进度条不显示
- [ ] Checkpoint 34: 短时长视频（< 1 小时）时间格式为 `mm:ss / mm:ss`
- [ ] Checkpoint 35: 长时长视频（>= 1 小时）时间格式为 `mm:ss / h:mm:ss` 或 `m:ss / h:mm:ss`
- [ ] Checkpoint 36: 进度条不被其他 UI 元素遮挡（如右侧操作按钮、底部导航）
- [ ] Checkpoint 37: 长标题视频（超过一行）时，进度条仍正常显示在底部
- [ ] Checkpoint 38: 连播模式下，进度条随新视频自动重置为 0%

## 功能测试检查项

- [ ] Checkpoint 39: 连播开关（infinity/all_inclusive）按钮点击后正常切换连播状态
- [ ] Checkpoint 40: 倍速按钮正常工作，可调节播放速度
- [ ] Checkpoint 41: 播放模式按钮正常工作，可切换 Direct/Transcode/Fallback
- [ ] Checkpoint 42: 字幕按钮正常工作，可选择字幕
- [ ] Checkpoint 43: 唱片静音按钮正常工作，可切换静音状态
- [ ] Checkpoint 44: 全屏按钮正常工作，可切换全屏
- [ ] Checkpoint 45: 点赞按钮正常工作，可切换收藏状态
- [ ] Checkpoint 46: 删除按钮正常工作，可删除视频
- [ ] Checkpoint 47: 下一集按钮（如有）正常工作，可切换到下一集
- [ ] Checkpoint 48: 点击演员头像跳转到演员详情页（如有演员信息）

## 代码质量检查项

- [ ] Checkpoint 49: 代码无新增编译错误
- [ ] Checkpoint 50: `flutter analyze` 输出无新增 error 级别问题
- [ ] Checkpoint 51: `_formatDuration` 方法逻辑正确，无边界情况处理
- [ ] Checkpoint 52: `_videoController` 的空安全处理完善（null 检查）
- [ ] Checkpoint 53: `duration` 为 zero 时不导致除零错误
- [ ] Checkpoint 54: 进度条 listener 在 `dispose` 时正确移除，无内存泄漏
- [ ] Checkpoint 55: 代码风格与现有代码一致（使用 const 构造函数、颜色常量等）
- [ ] Checkpoint 56: 缩进规范（2 空格或 4 空格，与项目一致）
- [ ] Checkpoint 57: 代码注释清晰，特别是新增的方法和复杂逻辑

## 多端兼容性检查项

- [ ] Checkpoint 58: Android 设备上 UI 布局正常
- [ ] Checkpoint 59: iOS 设备上 UI 布局正常（如有 iOS 设备）
- [ ] Checkpoint 60: 平板/桌面端响应式布局正常（如有此平台）
- [ ] Checkpoint 61: 竖屏模式下布局不重叠
- [ ] Checkpoint 62: 不同屏幕宽度下进度条不溢出或挤压

## 性能检查项

- [ ] Checkpoint 63: 播放过程中 UI 响应流畅，无明显卡顿
- [ ] Checkpoint 64: 频繁暂停/播放操作后，内存使用无持续增长
- [ ] Checkpoint 65: 快速滑动多个视频后，应用无明显内存泄漏

## 边缘情况处理检查项

- [ ] Checkpoint 66: 无元信息的视频（仅标题，无其他信息）仍可正常播放和显示
- [ ] Checkpoint 67: 极短时长视频（< 30 秒）进度条显示正常
- [ ] Checkpoint 68: 极长时长视频（> 2 小时）进度条显示正常
- [ ] Checkpoint 69: 正在下载/未完全加载的视频，进度条显示 0% 或不显示
- [ ] Checkpoint 70: 多次打开关闭信息弹窗后，UI 仍正常响应
- [ ] Checkpoint 71: 在播放过程中，进度条随播放位置正确增长
