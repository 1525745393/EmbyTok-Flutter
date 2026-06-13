# Checklist - UI 功能完善

## Task 1: 搜索页面
- [x] `search_view.dart` 实现了搜索输入框
- [x] 搜索历史标签横向滚动显示
- [x] 搜索结果网格正确渲染缩略图和标题
- [x] 分页加载在滚动到底部时触发
- [x] 空搜索结果显示空状态提示
- [x] 加载状态显示 Loading 指示器

## Task 2: 收藏页面
- [x] `favorites_view.dart` 显示收藏视频网格
- [x] 收藏数量在标题栏显示
- [x] 点击取消收藏后列表即时更新
- [x] 空收藏状态显示友好提示
- [x] 缩略图正确加载

## Task 3: 历史页面
- [x] `history_view.dart` 显示观看历史列表
- [x] 历史记录按时间倒序排列
- [x] 每条记录显示封面、标题、观看时间
- [x] 清除历史按钮显示确认对话框
- [x] 确认后历史列表清空
- [x] 空历史状态显示友好提示

## Task 4: 设置页面
- [x] `settings_view.dart` 显示用户信息
- [x] 主题切换选项可用（深色/浅色/跟随系统）
- [x] 字幕设置选项可用（语言、大小）
- [x] 当前服务器信息正确显示
- [x] 退出登录按钮可点击
- [x] 退出后返回登录页面

## Task 5: HomeScaffold 集成
- [x] `_SearchPlaceholder` 已替换为 `SearchView`
- [x] `_FavoritesPlaceholder` 已替换为 `FavoritesView`
- [x] `_HistoryPlaceholder` 已替换为 `HistoryView`
- [x] `_SettingsPlaceholder` 已替换为 `SettingsView`
- [x] 底部导航切换到各页面无报错
- [x] 页面样式与整体深色主题一致
