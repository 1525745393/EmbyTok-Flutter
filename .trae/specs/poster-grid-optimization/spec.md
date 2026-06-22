# 网格视图优化 Spec

## Why
当前网格视图（PosterGridView）功能单一，列数固定为3，无骨架屏、无搜索筛选等基础功能，用户体验有待提升。

## What Changes
- 响应式列数：根据屏幕宽度动态调整（手机3列、平板4-6列）
- 骨架屏/加载占位符：图片加载时显示占位符
- 长按菜单：长按卡片弹出快速操作
- 排序/筛选：添加排序和类型筛选
- 搜索功能：网格视图顶部添加搜索框

## Impact
- Affected specs: 网格视图
- Affected code: `lib/widgets/poster_grid_view.dart`

## ADDED Requirements

### Requirement: 响应式列数
系统 SHALL 根据屏幕宽度动态调整网格列数：
- width < 600dp: 3列
- 600dp <= width < 900dp: 4列
- 900dp <= width < 1200dp: 5列
- width >= 1200dp: 6列

#### Scenario: 响应式布局
- **WHEN** 用户在不同尺寸设备上打开网格视图
- **THEN** 网格列数自动适应屏幕宽度

### Requirement: 骨架屏加载占位符
系统 SHALL 在图片加载完成前显示骨架屏占位符，避免布局跳动。

#### Scenario: 加载中状态
- **WHEN** 图片正在加载
- **THEN** 显示渐变骨架屏占位符

### Requirement: 长按菜单
系统 SHALL 支持长按卡片弹出快速操作菜单（收藏、播放、详情）。

#### Scenario: 长按操作
- **WHEN** 用户长按视频卡片
- **THEN** 弹出操作菜单（收藏、播放、详情）

### Requirement: 排序功能
系统 SHALL 支持按不同方式排序视频（最近添加、评分、标题）。

#### Scenario: 排序切换
- **WHEN** 用户选择排序方式
- **THEN** 视频列表按选定方式重新排序

### Requirement: 搜索功能
系统 SHALL 在网格视图顶部显示搜索框，支持搜索视频。

#### Scenario: 搜索视频
- **WHEN** 用户在搜索框输入关键词
- **THEN** 实时过滤显示匹配的视频
