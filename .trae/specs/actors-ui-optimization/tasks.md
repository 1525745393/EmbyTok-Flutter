# 演员界面优化 - 任务列表

## [x] Task 1: 添加 Tab 分类显示功能
- **Priority**: P0
- **Depends On**: None
- **Description**: 
  - 在演员列表页面添加"全部"、"已关注"、"未关注"三个 Tab
  - 使用 `TabBar` 和 `TabBarView` 实现
  - 在"已关注" Tab 上显示关注数量
- **Acceptance Criteria Addressed**: AC-1, AC-2, AC-6
- **Test Requirements**:
  - `programmatic` TR-1.1: Tab 切换正确显示对应分类的演员
  - `programmatic` TR-1.2: "已关注" Tab 显示正确的关注数量
- **Notes**: 

## [x] Task 2: 添加搜索功能
- **Priority**: P1
- **Depends On**: None
- **Description**: 
  - 在 AppBar 添加搜索框
  - 支持按演员名称实时搜索
  - 添加防抖处理（300ms）
  - 无结果时显示空状态提示
- **Acceptance Criteria Addressed**: AC-3
- **Test Requirements**:
  - `programmatic` TR-2.1: 搜索框输入后显示匹配的演员
  - `programmatic` TR-2.2: 无结果时显示"未找到相关演员"
  - `human-judgement` TR-2.3: 搜索响应速度流畅
- **Notes**: 需要添加防抖避免频繁搜索

## [x] Task 3: 添加分页加载功能
- **Priority**: P0
- **Depends On**: None
- **Description**: 
  - 修改 `getPeople` 调用支持分页参数
  - 添加 `startIndex` 参数用于分页
  - 添加下拉刷新功能
  - 添加上拉加载更多功能
  - 添加加载状态指示器
- **Acceptance Criteria Addressed**: AC-4
- **Test Requirements**:
  - `programmatic` TR-3.1: 下拉刷新重新加载列表
  - `programmatic` TR-3.2: 上拉加载更多追加演员
  - `programmatic` TR-3.3: 加载完成不再触发加载
- **Notes**: 已完成实现
  - `EmbytokService.getPeople` 已添加 `startIndex` 参数，返回 `PaginatedResponse<Person>`
  - 演员列表页面添加分页状态和滚动监听
  - 使用 `RefreshIndicator` 实现下拉刷新
  - 使用 `ScrollController` 检测滚动实现上拉加载更多
  - 添加加载更多指示器和"已加载全部"提示

## [x] Task 4: 添加类型筛选功能
- **Priority**: P1
- **Depends On**: None
- **Description**: 
  - 添加类型筛选器（全部/演员/导演/编剧）
  - 支持多选筛选
  - 筛选条件影响 API 调用
- **Acceptance Criteria Addressed**: AC-5
- **Test Requirements**:
  - `programmatic` TR-4.1: 选择不同类型显示对应演员
  - `programmatic` TR-4.2: 筛选条件正确传递到 API
- **Notes**: 已完成实现

## [x] Task 5: 优化演员卡片显示效果
- **Priority**: P2
- **Depends On**: None
- **Description**: 
  - 头像改为圆形裁剪
  - 增大关注按钮点击区域
  - 优化卡片间距和布局
- **Acceptance Criteria Addressed**: 
- **Test Requirements**:
  - `human-judgement` TR-5.1: 头像显示为圆形
  - `human-judgement` TR-5.2: 点击区域易于点击
  - `human-judgement` TR-5.3: 整体布局美观
- **Notes**: 

## [x] Task 6: 优化空状态和错误处理
- **Priority**: P1
- **Depends On**: None
- **Description**: 
  - 未关注演员时显示引导提示
  - 搜索无结果时显示友好提示
  - 优化加载状态动画
- **Acceptance Criteria Addressed**: 
- **Test Requirements**:
  - `human-judgement` TR-6.1: 空状态提示清晰友好
  - `human-judgement` TR-6.2: 加载动画流畅
- **Notes**: 

# Task Dependencies
- Task 1, 2, 3, 4, 5, 6 可以并行开发，无相互依赖
