# Tasks - UI 功能完善

## 前置准备
- [ ] Task 0: 检查现有视图文件，确认是否已有部分实现
  - 检查 `search_view.dart`、`favorites_view.dart`、`history_view.dart`、`settings_view.dart` 是否存在
  - 如果文件已存在且有部分实现，则阅读并复用；如果只有占位代码，则完全重写

---

## 页面实现

### Task 1: 实现搜索页面 (SearchView)
- **Priority**: P1
- **Depends On**: Task 0
- **Description**:
  创建 `search_view.dart`，实现：
  - 顶部搜索输入框（带搜索图标、清除按钮）
  - 搜索历史列表（横向滚动标签，点击快速搜索）
  - 搜索结果网格（缩略图 + 标题 + 时长）
  - 分页加载（滚动到底部自动加载更多）
  - 空状态和加载状态 UI
- **Acceptance Criteria Addressed**: 搜索页面需求
- **Test Requirements**:
  - `human-judgement` TR-1.1: 搜索框可输入并触发搜索
  - `human-judgement` TR-1.2: 搜索结果正确显示分页数据

### Task 2: 实现收藏页面 (FavoritesView)
- **Priority**: P1
- **Depends On**: Task 0
- **Description**:
  完善 `favorites_view.dart`，实现：
  - 顶部标题栏（显示收藏数量）
  - 视频网格布局（两列，缩略图 + 标题）
  - 爱心动画效果
  - 取消收藏交互
  - 空状态提示
- **Acceptance Criteria Addressed**: 收藏页面需求
- **Test Requirements**:
  - `human-judgement` TR-2.1: 收藏列表正确展示
  - `human-judgement` TR-2.2: 取消收藏后列表更新

### Task 3: 实现历史页面 (HistoryView)
- **Priority**: P1
- **Depends On**: Task 0
- **Description**:
  完善 `history_view.dart`，实现：
  - 顶部标题栏 + 清除历史按钮
  - 历史记录列表（缩略图 + 标题 + 观看时间）
  - 确认清除对话框
  - 空状态提示
- **Acceptance Criteria Addressed**: 历史页面需求
- **Test Requirements**:
  - `human-judgement` TR-3.1: 历史记录按时间倒序显示
  - `human-judgement` TR-3.2: 清除历史功能正常

### Task 4: 实现设置页面 (SettingsView)
- **Priority**: P1
- **Depends On**: Task 0
- **Description**:
  完善 `settings_view.dart`，实现：
  - 用户信息展示（用户名、头像）
  - 主题切换（跟随系统 / 深色 / 浅色）
  - 字幕设置（语言选择、大小调节）
  - 服务器信息（显示当前连接的后端和 Emby 地址）
  - 退出登录按钮
- **Acceptance Criteria Addressed**: 设置页面需求
- **Test Requirements**:
  - `human-judgement` TR-4.1: 主题切换立即生效
  - `human-judgement` TR-4.2: 退出登录返回登录页

### Task 5: 替换 HomeScaffold 占位组件
- **Priority**: P1
- **Depends On**: Task 1, Task 2, Task 3, Task 4
- **Description**:
  修改 `home_scaffold.dart`，将 4 个占位组件替换为真实页面：
  - `_SearchPlaceholder` → `SearchView`（需 import）
  - `_FavoritesPlaceholder` → `FavoritesView`
  - `_HistoryPlaceholder` → `HistoryView`
  - `_SettingsPlaceholder` → `SettingsView`
- **Acceptance Criteria Addressed**: HomeScaffold 替换需求
- **Test Requirements**:
  - `human-judgement` TR-5.1: 底部导航切换到各页面正常显示

---

## Task Dependencies
- Task 1, 2, 3, 4 可并行开发（相互独立）
- Task 5 依赖 Task 1, 2, 3, 4 完成后执行
