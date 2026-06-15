# Tasks - 视图切换、方向过滤与全屏模式

## 任务列表

### [x] Task 1: 创建网格视图组件 VideoGridView
- **Depends On**: None
- **Description**: 新建网格视图组件，支持缩略图网格浏览
  - 创建 `frontend/lib/views/video_grid_view.dart`
  - 创建 `frontend/lib/widgets/video_grid_card.dart`
  - 实现 2 列（竖屏）/ 4 列（横屏）网格布局
  - 每个卡片显示：封面图、标题、时长、进度条（若有）
  - 点击视频卡片跳转到视频流对应位置
- **Acceptance Criteria**: 
  - 网格视图正确渲染
  - 点击卡片能跳转到视频流

### [x] Task 2: 创建顶部工具栏 TopToolBar
- **Depends On**: None
- **Description**: 新建顶部工具栏组件
  - 创建 `frontend/lib/widgets/top_tool_bar.dart`
  - 左侧：返回按钮或菜单按钮
  - 中间：当前模式标签（最新/随机/收藏）
  - 右侧：视图切换（全屏/网格图标）、全屏按钮、静音按钮
- **Acceptance Criteria**:
  - 工具栏显示正确
  - 按钮可点击并触发状态变化

### [x] Task 3: 实现视图切换逻辑
- **Depends On**: Task 1, Task 2
- **Description**: 在 feed_view.dart 中集成视图切换
  - 修改 `frontend/lib/views/feed_view.dart`
  - 根据 viewModeProvider 切换视频流/网格视图
  - 点击网格图标切换到 grid 模式
  - 点击手机图标切换到 feed 模式
- **Acceptance Criteria**:
  - 视图切换正常工作
  - 状态持久化

### [x] Task 4: 实现方向过滤 UI
- **Depends On**: Task 2
- **Description**: 在菜单中添加方向过滤选项
  - 修改 `frontend/lib/widgets/top_tool_bar.dart` 或新建菜单面板
  - 添加方向过滤选项：竖屏/横屏/全部
  - 使用 orientationModeProvider 管理状态
- **Acceptance Criteria**:
  - 方向过滤选项显示
  - 切换后列表正确过滤

### [x] Task 5: 实现全屏模式
- **Depends On**: Task 2
- **Description**: 实现全屏/退出全屏功能
  - 添加全屏按钮到顶部工具栏
  - 使用 SystemChrome 控制屏幕方向和系统 UI
  - 在 video_page_item.dart 中添加全屏入口
- **Acceptance Criteria**:
  - 点击全屏按钮进入横屏全屏
  - 点击退出按钮恢复竖屏

### [x] Task 6: 实现视频方向自适应
- **Depends On**: Task 5
- **Description**: 根据视频内容方向调整显示方式
  - 修改 video_player_widget.dart
  - 判断 isContentLandscape 和 isScreenLandscape
  - 横屏视频在竖屏设备上使用 BoxFit.contain + 模糊背景
  - 竖屏视频使用 BoxFit.cover
- **Acceptance Criteria**:
  - 横屏视频正确显示
  - 竖屏视频正确显示

### [x] Task 7: 验证与测试
- **Depends On**: Task 1-6
- **Description**: 验证所有功能正常工作
  - 运行 flutter analyze 检查编译错误
  - 测试视图切换
  - 测试方向过滤
  - 测试全屏模式
- **Acceptance Criteria**:
  - flutter analyze 无错误
  - 所有功能可正常使用

---

## Task Dependencies

```
Task 1 ─┬─> Task 3 ─> Task 7
         │
Task 2 ─┴─> Task 4 ─> Task 7
         │
         └────> Task 5 ─> Task 6 ─> Task 7
```

Task 1 和 Task 2 可并行开发
