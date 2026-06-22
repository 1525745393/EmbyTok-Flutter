# 底部导航栏搜索和历史按钮移至顶部操作区

## Why
当前底部导航栏有5个标签（首页、搜索、收藏、历史、设置），占用空间较大。将搜索和历史功能移至顶部操作区可以简化底部导航，提升用户体验，同时保持功能可访问性。

## What Changes
- 从底部导航栏移除"搜索"和"历史"两个标签页
- 底部导航栏简化为3个标签：首页、收藏、设置
- 在 Feed 页面顶部操作区添加搜索和历史图标按钮
- 顶部操作区的搜索和历史按钮只显示图标，不显示文字

## Impact
- Affected specs: 无
- Affected code: 
  - `/workspace/frontend/lib/views/home_scaffold.dart` - 修改底部导航栏配置
  - `/workspace/frontend/lib/views/feed_view.dart` - 在顶部操作区添加搜索和历史按钮

## ADDED Requirements
### Requirement: 顶部操作区搜索按钮
系统 SHALL 在 Feed 页面顶部操作区左侧提供搜索图标按钮，点击后切换到搜索页面。

#### Scenario: 点击顶部搜索按钮
- **WHEN** 用户点击顶部操作区的搜索图标
- **THEN** 应用切换到搜索页面

### Requirement: 顶部操作区历史按钮
系统 SHALL 在 Feed 页面顶部操作区添加历史图标按钮，点击后切换到历史页面。

#### Scenario: 点击顶部历史按钮
- **WHEN** 用户点击顶部操作区的历史图标
- **THEN** 应用切换到历史页面

## MODIFIED Requirements
### Requirement: 底部导航栏简化
底部导航栏 SHALL 只包含3个标签页：首页、收藏、设置，移除搜索和历史标签。

#### Scenario: 底部导航栏显示
- **WHEN** 用户查看底部导航栏
- **THEN** 只显示首页、收藏、设置三个标签，每个标签包含图标和文字

### Requirement: 页面索引映射调整
由于底部导航栏从5个标签减少到3个，页面索引映射需要调整：
- 索引 0: Feed 页面（首页）
- 索引 1: 收藏页面
- 索引 2: 设置页面
- 搜索和历史页面不再通过底部导航栏直接访问，而是通过顶部操作区的按钮切换

## REMOVED Requirements
### Requirement: 底部导航栏搜索标签
**Reason**: 搜索功能移至顶部操作区，简化底部导航
**Migration**: 用户通过顶部操作区的搜索图标按钮访问搜索功能

### Requirement: 底部导航栏历史标签
**Reason**: 历史功能移至顶部操作区，简化底部导航
**Migration**: 用户通过顶部操作区的历史图标按钮访问历史功能
