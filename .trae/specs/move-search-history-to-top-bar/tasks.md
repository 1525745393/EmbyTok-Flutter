# Tasks

## 任务 1：修改底部导航栏配置
- [x] 1.1 修改 `/workspace/frontend/lib/views/home_scaffold.dart`
  - [x] 移除搜索和历史两个 BottomNavigationBarItem
  - [x] 保留首页、收藏、设置三个标签
  - [x] 调整页面索引常量（_indexSearch 和 _indexHistory 不再需要）
  - [x] 更新 IndexedStack 的 children 配置，只保留 3 个页面

## 任务 2：在顶部操作区添加搜索和历史按钮
- [x] 2.1 修改 `/workspace/frontend/lib/views/feed_view.dart` 的 `_buildTopBar` 方法
  - [x] 在顶部操作区左侧添加搜索图标按钮
  - [x] 在顶部操作区左侧添加历史图标按钮
  - [x] 按钮只显示图标，不显示文字（使用 IconButton）
  - [x] 点击搜索按钮切换到搜索页面
  - [x] 点击历史按钮切换到历史页面

## 任务 3：处理页面切换逻辑
- [x] 3.1 需要调整 HomeScaffold 和 FeedView 之间的页面切换通信
  - [x] 方案 A：使用 Provider 共享当前页面索引状态
  - [x] 方案 B：通过回调函数传递页面切换事件
  - [x] 确保从顶部按钮点击后能正确切换到对应页面

## 任务 4：测试验证
- [x] 4.1 验证底部导航栏只显示 3 个标签
- [x] 4.2 验证顶部操作区显示搜索和历史图标按钮
- [x] 4.3 验证点击顶部搜索按钮能切换到搜索页面
- [x] 4.4 验证点击顶部历史按钮能切换到历史页面
- [x] 4.5 验证从搜索/历史页面返回能回到 Feed 页面
