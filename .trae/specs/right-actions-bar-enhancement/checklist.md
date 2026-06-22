# 右侧操作栏对齐 EmbyTok React 版 - Verification Checklist

## Task 1: 播放模式切换按钮
- [ ] 代码中存在 `_buildPlayModeButton()` 方法
- [ ] 点击循环切换 DirectPlay → Transcode → Fallback
- [ ] 按钮显示当前模式文本（Direct / Transcode / Fbk）
- [ ] 非 Direct 模式时按钮高亮（靛蓝色背景）
- [ ] 状态通过 `playbackLevelProvider` 管理

## Task 2: 字幕控制按钮
- [ ] 代码中存在 `_buildSubtitleButton()` 方法
- [ ] 点击弹出字幕选择菜单
- [ ] 有字幕时按钮正常显示
- [ ] 选中字幕后按钮高亮
- [ ] 状态通过 `selectedSubtitleProvider` 管理

## Task 3: 信息按钮
- [ ] 代码中存在 `_buildInfoButton()` 方法
- [ ] 点击切换底部信息面板显示/隐藏
- [ ] 展开时按钮高亮
- [ ] 状态与底部信息区同步

## Task 4: 唱片式静音按钮
- [ ] 静音按钮为圆形唱片样式
- [ ] 播放时带有缓慢旋转动画
- [ ] 静音时边框/图标变为红色
- [ ] 点击切换静音状态

## Task 5: 海报/头像展示区
- [ ] 按钮列表顶部有圆形海报展示区
- [ ] 使用视频封面图像
- [ ] 大小约 48-56px
- [ ] （可选）点击播放/暂停视频

## Task 6: 按钮顺序与布局
- [ ] 按钮顺序（自上而下）：海报 → 点赞 → 信息 → 删除 → 倍速 → 播放模式 → 字幕 → 唱片静音 → 全屏 → 下一集 → 连播开关
- [ ] 按钮之间有合适间距
- [ ] 按钮布局与 React 版风格一致
- [ ] 连播开关在底部或独立位置

## Task 7: 状态同步与验证
- [ ] 播放模式按钮状态与 VideoControls 一致
- [ ] 字幕按钮状态与 VideoControls 一致
- [ ] 信息按钮状态与底部信息面板同步
- [ ] 静音按钮状态与 `isMutedProvider` 同步
- [ ] 非纯净模式显示完整按钮列表
- [ ] 纯净模式只显示简化按钮
- [ ] 代码编译无错误
