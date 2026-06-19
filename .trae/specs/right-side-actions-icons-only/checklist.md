# 右侧操作区图标化显示（保留演员名字） - 验证检查清单

## 代码审查检查项

- [ ] Checkpoint 1: `_PressableActionButton.build` 方法中仅渲染 `Icon` 组件，不包含 `Text` 组件
- [ ] Checkpoint 2: `_buildSpeedControlButton` 方法中圆形按钮仅显示 `Icons.speed` 图标，无数字文字
- [ ] Checkpoint 3: `_buildPlayModeButton` 方法中圆形按钮仅通过图标+颜色区分三种模式，无文字
- [ ] Checkpoint 4: `_buildSubtitleButton` 方法中圆形按钮仅显示 `Icons.subtitles` 图标，无文字
- [ ] Checkpoint 5: `_buildDiscMuteButton` 方法中唱片按钮仅显示封面或图标，无文字
- [ ] Checkpoint 6: `_buildAutoPlayButton` 方法中圆形按钮仅显示 `Icons.all_inclusive` 图标，无文字
- [ ] Checkpoint 7: `_buildActionButton`（点赞/全屏/下一集调用）仅渲染图标，不渲染文字标签
- [ ] Checkpoint 8: `_buildPosterAvatar` 方法中演员名字 `Text` 组件保留，不被删除
- [ ] Checkpoint 9: `_buildSpeedBadge`（顶部倍速徽章）保持不变，不属于需要修改的按钮

## 功能验证检查项

- [ ] Checkpoint 10: 点击"点赞"按钮能正常切换收藏状态（图标颜色变化）
- [ ] Checkpoint 11: 点击"信息"按钮能正常弹出信息面板
- [ ] Checkpoint 12: 点击"删除"按钮能正常弹出确认对话框
- [ ] Checkpoint 13: 点击"倍速"按钮能正常弹出倍速控制面板
- [ ] Checkpoint 14: 点击"播放模式"按钮能正常循环切换 Direct/Transcode/Fallback
- [ ] Checkpoint 15: 点击"字幕"按钮能正常弹出字幕选择（如有字幕）
- [ ] Checkpoint 16: 点击"唱片静音"按钮能正常切换静音状态
- [ ] Checkpoint 17: 点击"全屏"按钮能正常切换全屏模式
- [ ] Checkpoint 18: 点击"下一集"按钮（如有）能正常播放下一集
- [ ] Checkpoint 19: 点击"连播"按钮能正常切换连播模式并显示 SnackBar 提示
- [ ] Checkpoint 20: 点击演员头像能正常跳转到演员详情页
- [ ] Checkpoint 21: 点击演员头像上的"+"收藏按钮能正常切换收藏状态

## 视觉检查检查项

- [ ] Checkpoint 22: 手机竖屏下所有按钮布局紧凑，无重叠
- [ ] Checkpoint 23: 平板/桌面横屏下响应式缩放正常
- [ ] Checkpoint 24: 图标颜色和尺寸与设计一致（白色主色、点赞/删除=红色）
- [ ] Checkpoint 25: 倍速 >1.0 时倍速按钮橙色高亮正常显示
- [ ] Checkpoint 26: 连播开启时连播按钮绿色高亮正常显示
- [ ] Checkpoint 27: 演员名字显示位置正确（头像下方居中）
- [ ] Checkpoint 28: 演员名字字体大小适中，不影响整体布局

## 代码质量检查项

- [ ] Checkpoint 29: 所有修改仅涉及 `video_page_item.dart` 文件（如需要修改）
- [ ] Checkpoint 30: 未修改任何 API 调用、业务逻辑、状态管理代码
- [ ] Checkpoint 31: 代码无编译错误、无警告提示
- [ ] Checkpoint 32: `flutter analyze` 无新增 warning/error
