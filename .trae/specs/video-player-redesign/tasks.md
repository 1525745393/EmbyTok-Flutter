# Tasks

- [x] Task 1: 重构 VideoPageItem 布局
  - [x] 1.1: 参考 EmbyTok VideoCard，重新设计 Stack 布局结构
  - [x] 1.2: 优化底部渐变信息面板样式（标题/年份/时长/类型标签）
  - [x] 1.3: 实现信息面板展开/收起动画（点击简介区域展开）
  - [x] 1.4: 实现播放时信息面板自动隐藏（3秒无操作淡出）

- [x] Task 2: 优化右侧操作按钮
  - [x] 2.1: 重新设计按钮布局（参考 EmbyTok VideoControls）
  - [x] 2.2: 实现收藏按钮动画（心形填充/描边切换）
  - [x] 2.3: 实现静音按钮样式（边框颜色 + 旋转动画）
  - [x] 2.4: 新增自动播放模式切换按钮（Infinity 图标）
  - [x] 2.5: 新增信息展开按钮（Info 图标）

- [x] Task 3: 增强 GestureOverlay 手势层
  - [x] 3.1: 实现快进/快退视觉反馈（FastForward/Rewind 图标 + 秒数显示）
  - [x] 3.2: 优化双击心形动画效果（参考 EmbyTok HeartAnimation）
  - [x] 3.3: 实现向下滑动切换下一个视频的手势
  - [x] 3.4: 优化长按倍速提示样式（参考 EmbyTok 的 Double Speed 徽章）

- [x] Task 4: 实现自动播放模式
  - [x] 4.1: 在 VideoPlaybackController 中添加 isAutoPlay 状态
  - [x] 4.2: 实现视频播放完毕自动切换逻辑
  - [x] 4.3: 持久化自动播放设置到本地存储

- [x] Task 5: 实现观看历史记录
  - [x] 5.1: 创建 WatchHistoryProvider 管理观看历史
  - [x] 5.2: 实现观看进度记录（每 10 秒更新一次）
  - [x] 5.3: 实现从上次位置继续播放功能
  - [x] 5.4: 持久化观看历史到本地存储

- [x] Task 6: 实现字幕支持（可选）
  - [x] 6.1: 在 EmbytokService 中添加获取字幕轨道的方法
  - [x] 6.2: 创建 SubtitleWidget 显示字幕
  - [x] 6.3: 实现字幕选择 UI

# Task Dependencies
- [Task 2] 依赖 [Task 1]（右侧按钮需要新的布局结构）
- [Task 3] 可以与 [Task 1] 并行
- [Task 4] 依赖 [Task 2.4]（自动播放按钮需要先实现）
- [Task 5] 可以独立进行
- [Task 6] 可以独立进行（可选功能）
