# EmbyTok Flutter - UI 功能完善

## Why
当前 App 的搜索、收藏、历史、设置页面均为占位页面，用户无法使用这些核心功能。需要实现完整的 UI 交互。

## What Changes
- 实现搜索页面：支持关键词搜索、分页加载、搜索历史
- 实现收藏页面：展示收藏列表、支持取消收藏
- 实现历史页面：展示观看历史、支持清除历史
- 实现设置页面：主题切换、字幕设置、后端地址管理、退出登录

## Impact
- Affected specs: 原有 TikTok 风格深色主题保持一致
- Affected code:
  - `frontend/lib/views/search_view.dart` → 替换占位页
  - `frontend/lib/views/favorites_view.dart` → 替换占位页
  - `frontend/lib/views/history_view.dart` → 替换占位页
  - `frontend/lib/views/settings_view.dart` → 替换占位页
  - `frontend/lib/views/home_scaffold.dart` → 替换占位组件引用

## ADDED Requirements

### Requirement: 搜索页面
系统应提供关键词搜索功能，支持分页加载和搜索历史记录。

#### Scenario: 搜索成功
- **WHEN** 用户在搜索框输入关键词并点击搜索
- **THEN** 显示搜索结果列表，支持分页加载
- **AND** 输入框下方显示搜索历史记录

#### Scenario: 空搜索结果
- **WHEN** 用户搜索的关键词无匹配结果
- **THEN** 显示空状态提示"未找到相关视频"

### Requirement: 收藏页面
系统应展示用户的收藏列表，支持取消收藏操作。

#### Scenario: 查看收藏列表
- **WHEN** 用户进入收藏页面
- **THEN** 显示收藏的视频网格，带缩略图和标题
- **AND** 加载完成后显示收藏数量

#### Scenario: 取消收藏
- **WHEN** 用户点击已收藏视频的爱心图标
- **THEN** 从列表中移除该视频，显示取消成功提示

### Requirement: 历史页面
系统应展示用户的观看历史，支持清除历史功能。

#### Scenario: 查看历史记录
- **WHEN** 用户进入历史页面
- **THEN** 按时间倒序显示观看过的视频
- **AND** 每条记录显示标题、封面和观看时间

#### Scenario: 清除历史
- **WHEN** 用户点击清除历史按钮
- **THEN** 显示确认对话框，用户确认后清空所有历史记录

### Requirement: 设置页面
系统应提供主题切换、字幕设置、服务器配置和退出登录功能。

#### Scenario: 主题切换
- **WHEN** 用户在设置页面切换主题
- **THEN** App 立即应用新的主题颜色

#### Scenario: 退出登录
- **WHEN** 用户点击退出登录按钮
- **THEN** 清除认证状态，返回登录页面

## MODIFIED Requirements

### Requirement: HomeScaffold 占位页替换
`home_scaffold.dart` 中的占位组件应替换为真实页面组件。
- 替换 `_SearchPlaceholder` → `SearchView`
- 替换 `_FavoritesPlaceholder` → `FavoritesView`
- 替换 `_HistoryPlaceholder` → `HistoryView`
- 替换 `_SettingsPlaceholder` → `SettingsView`
