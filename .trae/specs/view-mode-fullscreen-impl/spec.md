# 视图切换、方向过滤与全屏模式实现计划

## Why
当前 Flutter APP 已完成核心视频播放功能，但缺少以下关键交互：
- 视频流/网格视图切换（用户需要快速浏览内容）
- 方向过滤（只看竖屏/横屏视频）
- 全屏播放模式
- 视频方向自适应显示

## What Changes

### 新增功能
1. **网格视图（VideoGridView）** - 缩略图网格浏览，支持点击跳转
2. **视图切换按钮** - 顶部工具栏一键切换视频流/网格
3. **方向过滤** - 菜单中选择竖屏/横屏/全部
4. **全屏模式** - 进入/退出横屏全屏播放
5. **视频方向自适应** - 横屏视频在竖屏设备上带背景显示

### 修改功能
- `feed_view.dart` - 添加顶部工具栏
- `standard_root_view.dart` - 添加视图切换逻辑
- `video_page_item.dart` - 支持全屏入口
- `video_player_widget.dart` - 支持视频方向自适应

## Impact

### 受影响的功能
- FR-3: 视频流/网格视图切换
- FR-7: 方向过滤
- FR-13: 全屏切换
- FR-16: 视频方向自适应显示

### 受影响的代码
- `frontend/lib/views/feed_view.dart` - 重构顶部工具栏
- `frontend/lib/views/video_grid_view.dart` - 新建
- `frontend/lib/widgets/video_grid_card.dart` - 新建
- `frontend/lib/widgets/top_tool_bar.dart` - 新建
- `frontend/lib/providers/app_preferences_providers.dart` - 补充实现

## ADDED Requirements

### Requirement: 视图切换
系统 SHALL 提供视频流视图和网格视图的一键切换功能

#### Scenario: 切换到网格视图
- **WHEN** 用户点击顶部工具栏的网格图标
- **THEN** 界面切换为缩略图网格显示

#### Scenario: 切换到视频流视图
- **WHEN** 用户点击顶部工具栏的手机图标
- **THEN** 界面切换为竖向滑动视频流

### Requirement: 方向过滤
系统 SHALL 提供按视频方向过滤的功能

#### Scenario: 过滤竖屏视频
- **WHEN** 用户选择"只看竖屏"
- **THEN** 列表中仅显示 Height >= Width * 0.8 的视频

### Requirement: 全屏模式
系统 SHALL 提供进入/退出全屏播放的功能

#### Scenario: 进入全屏
- **WHEN** 用户点击全屏按钮
- **THEN** 屏幕旋转为横屏，系统 UI 隐藏

#### Scenario: 退出全屏
- **WHEN** 用户在横屏模式下点击退出按钮或旋转回竖屏
- **THEN** 恢复竖屏显示，系统 UI 恢复

### Requirement: 视频方向自适应
系统 SHALL 根据视频内容和屏幕方向自动调整显示方式

#### Scenario: 横屏视频在竖屏设备
- **WHEN** 用户播放横屏视频
- **THEN** 视频以 BoxFit.contain 显示，背景叠加模糊海报

#### Scenario: 竖屏视频在竖屏设备
- **WHEN** 用户播放竖屏视频
- **THEN** 视频以 BoxFit.cover 全屏填充

## MODIFIED Requirements

### Requirement: 顶部工具栏
顶部工具栏应包含以下元素：
- 左侧：返回按钮（菜单入口）
- 中间：当前浏览模式标签（最新/随机/收藏）
- 右侧：视图切换、全屏、静音按钮
