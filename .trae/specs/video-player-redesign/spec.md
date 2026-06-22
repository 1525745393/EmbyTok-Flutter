# APP 播放界面优化 Spec

## Why
当前 Flutter APP 的播放界面功能较简单，需要参考 EmbyTok Web 项目（React/TypeScript）的播放界面设计，实现更完善的 TikTok 风格视频浏览体验，包括精致的手势交互、动画效果、自动播放模式、字幕支持等功能。

## What Changes
- 重构 VideoPageItem 组件，参考 EmbyTok 的 VideoCard 布局设计
- 优化 GestureOverlay 手势层，增加快进/快退视觉反馈
- 新增自动播放模式切换功能
- 新增底部信息面板展开/收起动画
- 新增字幕选择与渲染功能
- 新增观看历史记录功能
- 优化右侧操作按钮布局与动画

## Impact
- Affected specs: 视频播放体验、用户交互
- Affected code:
  - `frontend/lib/widgets/video_page_item.dart`
  - `frontend/lib/widgets/gesture_overlay.dart`
  - `frontend/lib/widgets/video_player_widget.dart`
  - `frontend/lib/providers/video_playback_controller.dart`

## ADDED Requirements

### Requirement: TikTok 风格视频播放界面
系统应提供类似 TikTok 的竖屏视频浏览界面，包含全屏视频、手势交互、右侧操作按钮、底部信息面板。

#### Scenario: 用户浏览视频
- **WHEN** 用户进入视频流页面
- **THEN** 系统显示全屏视频，底部显示标题/简介/类型标签，右侧显示操作按钮

#### Scenario: 用户单击屏幕
- **WHEN** 用户单击视频画面
- **THEN** 系统切换播放/暂停状态，显示相应的图标动画

#### Scenario: 用户双击屏幕
- **WHEN** 用户双击视频画面
- **THEN** 系统触发点赞动画（飞行心形），并将视频加入收藏

#### Scenario: 用户长按屏幕
- **WHEN** 用户长按视频画面超过 500ms
- **THEN** 系统以 2 倍速播放视频，并在顶部显示倍速徽章

#### Scenario: 用户水平拖动
- **WHEN** 用户水平拖动视频画面
- **THEN** 系统显示快进/快退偏移量（如 +10s / -5s），松手后跳转到目标位置

### Requirement: 自动播放模式
系统应提供自动播放模式切换功能，开启时视频播放完毕自动切换到下一个视频。

#### Scenario: 用户开启自动播放
- **WHEN** 用户点击右侧的自动播放按钮（Infinity 图标）
- **THEN** 系统开启自动播放模式，按钮变为绿色高亮

#### Scenario: 视频播放完毕（自动播放开启）
- **WHEN** 当前视频播放完毕且自动播放模式已开启
- **THEN** 系统自动切换到下一个视频

#### Scenario: 视频播放完毕（自动播放关闭）
- **WHEN** 当前视频播放完毕且自动播放模式已关闭
- **THEN** 视频循环播放，不自动切换

### Requirement: 底部信息面板
系统应在视频底部显示信息面板，包含标题、年份、时长、媒体类型、简介，支持展开/收起。

#### Scenario: 用户查看视频信息
- **WHEN** 用户点击底部的简介区域
- **THEN** 信息面板展开，显示完整简介

#### Scenario: 视频播放时自动隐藏
- **WHEN** 视频正在播放且用户无操作超过 3 秒
- **THEN** 底部信息面板淡出隐藏

#### Scenario: 用户点击屏幕
- **WHEN** 用户点击屏幕（非按钮区域）
- **THEN** 底部信息面板重新显示

### Requirement: 右侧操作按钮
系统应在视频右侧显示操作按钮列，包含收藏、信息、静音、自动播放等功能。

#### Scenario: 用户点击收藏按钮
- **WHEN** 用户点击右侧的收藏按钮（Heart 图标）
- **THEN** 系统切换收藏状态，图标填充/描边变化

#### Scenario: 用户点击静音按钮
- **WHEN** 用户点击右侧的静音按钮
- **THEN** 系统切换静音状态，按钮边框颜色变化（红色=静音）

#### Scenario: 静音按钮旋转动画
- **WHEN** 视频正在播放
- **THEN** 静音按钮显示旋转动画（播放状态指示）

### Requirement: 字幕支持
系统应支持选择和显示字幕轨道（如 Emby 服务器提供）。

#### Scenario: 用户选择字幕
- **WHEN** 用户点击字幕按钮
- **THEN** 系统显示可用字幕列表，用户选择后字幕覆盖在视频上

#### Scenario: 无可用字幕
- **WHEN** 当前视频无可用字幕轨道
- **THEN** 字幕按钮显示为禁用状态

### Requirement: 观看历史记录
系统应记录用户的观看进度，下次打开同一视频时从上次位置继续播放。

#### Scenario: 用户观看视频
- **WHEN** 用户观看视频超过 30 秒
- **THEN** 系统记录观看进度到本地存储

#### Scenario: 用户重新打开视频
- **WHEN** 用户打开之前观看过的视频
- **THEN** 系统从上次观看位置继续播放

## MODIFIED Requirements

### Requirement: 手势交互层
现有的 GestureOverlay 组件需要增强，增加快进/快退的视觉反馈。

**修改内容**：
- 增加快进/快退偏移量显示（如 EmbyTok 的 FastForward/Rewind 图标 + 秒数）
- 优化心形动画效果（参考 EmbyTok 的 HeartAnimation）
- 增加向下滑动切换下一个视频的手势

## REMOVED Requirements

### Requirement: 无
本次优化为增量改进，不删除现有功能。
