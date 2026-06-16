# EmbyTok 响应式设计 - 验证清单

## 设计与视觉检查

- [ ] Checkpoint 1: 顶部工具栏呈现半透明黑色渐变（自顶向下，从约 67% 不透明度渐变为 0%）
- [ ] Checkpoint 2: 顶部工具栏底部边缘无硬边框线（之前的 `dividerColor` 分隔线已移除）
- [ ] Checkpoint 3: 底部导航栏呈现半透明黑色渐变（自底向上，从约 67% 不透明度渐变为 0%）
- [ ] Checkpoint 4: 底部导航栏顶部边缘无硬边框线
- [ ] Checkpoint 5: 顶部和底部的渐变使用相同的透明度参数（0xAA000000 → 0x00000000）
- [ ] Checkpoint 6: 工具栏图标和文字在视频背景上保持清晰可读（对比度评估）

## 布局与结构检查

- [ ] Checkpoint 7: 视频内容从屏幕顶部边缘延伸到底部边缘（全屏展示）
- [ ] Checkpoint 8: 状态栏图标"浮在"视频画面上方，状态栏下方无黑色填充
- [ ] Checkpoint 9: 底部手势条（如果设备有）"浮在"视频画面上
- [ ] Checkpoint 10: 顶部工具栏使用 `Positioned(top: 0)` 绝对定位叠加在 Stack 中
- [ ] Checkpoint 11: 底部导航栏不再是 Scaffold 的 `bottomNavigationBar` 属性，而是通过 `Stack` + `Positioned(bottom: 0)` 叠加
- [ ] Checkpoint 12: 视频内容区使用 `Positioned.fill` 或等效方式占据整个屏幕

## 内容避让检查（操作按钮 & 标题）

- [ ] Checkpoint 13: 工具栏展开时，右侧操作按钮（静音/点赞/收藏/评论/分享）的"静音"按钮不会被顶部 toolbar 遮挡
- [ ] Checkpoint 14: 工具栏展开时，底部的标题和简介文字不会被底部导航栏遮挡
- [ ] Checkpoint 15: 工具栏隐藏时，右侧操作按钮上移到接近顶部的位置（仅保留安全 padding）
- [ ] Checkpoint 16: 工具栏隐藏时，底部标题下移到接近底部的位置（仅保留安全 padding）
- [ ] Checkpoint 17: 操作按钮和标题的 padding 与 toolbarVisibilityProvider 响应式联动

## 安全区域适配检查

- [ ] Checkpoint 18: 带有刘海/动态岛的设备：工具栏内容（按钮、图标、文字）避开刘海区域
- [ ] Checkpoint 19: 带有底部手势条的设备：底部导航栏内容避开手势条区域
- [ ] Checkpoint 20: 视频内容延伸到屏幕边缘，但系统 UI（状态栏、导航栏图标）覆盖在视频上

## 动画与交互检查

- [ ] Checkpoint 21: 向上滑动切换视频 → 顶部工具栏和底部导航栏平滑折叠（高度从 ~112px 降到 0，200ms 动画）
- [ ] Checkpoint 22: 向下滑动或点击画面空白区域 → 工具栏展开（200ms 动画）
- [ ] Checkpoint 23: 点击画面后 3 秒内无进一步交互 → 工具栏自动折叠
- [ ] Checkpoint 24: 手势无延迟、漏触或干扰
- [ ] Checkpoint 25: 操作按钮（静音/点赞/收藏/评论/分享）仍然可点击，点击区域正确

## 模式兼容检查

- [ ] Checkpoint 26: 切换到网格视图（`ViewMode.grid`）时，布局保持正常，视频卡片正确显示
- [ ] Checkpoint 27: 网格视图的顶部工具栏也使用半透明渐变效果（或保持原有风格，根据 spec 决策）
- [ ] Checkpoint 28: 横屏全屏模式下布局无异常（工具栏正常隐藏）
- [ ] Checkpoint 29: 切换到搜索、收藏、历史、设置页面时，布局不受影响（非视频流页面保持原有风格）

## 代码质量检查

- [ ] Checkpoint 30: `flutter analyze lib` 无静态分析错误或警告
- [ ] Checkpoint 31: 无未使用的 import
- [ ] Checkpoint 32: 颜色、透明度参数集中在 `colors.dart` 和 `constants.dart`，无硬编码
- [ ] Checkpoint 33: 所有修改的文件保持清晰的中文注释，解释关键逻辑
- [ ] Checkpoint 34: 修改不超过 200 行代码（预期）

## 性能检查

- [ ] Checkpoint 35: 视频切换动画保持流畅（55-60fps），无明显卡顿
- [ ] Checkpoint 36: 工具栏展开/折叠动画保持流畅（200ms，动画帧无丢帧）
- [ ] Checkpoint 37: `AnimatedContainer` + `LinearGradient` 不会导致持续的过度重绘

## 兼容性检查

- [ ] Checkpoint 38: 在 Android 12+（带动态主题色和手势导航）设备上正常显示
- [ ] Checkpoint 39: 在旧版本 Android（6.0-9.0）设备上正常显示（无可用 SystemUiMode.edgeToEdge 的降级方案）
- [ ] Checkpoint 40: 在小屏手机（如 Pixel 4/5，屏幕宽高 ≤ 1080x2340）上无布局溢出
- [ ] Checkpoint 41: 在大屏手机（如 Pixel 8 Pro/三星 S24 Ultra）上布局正常
