# EmbyTok 演员列表页面 - 实现计划

## [x] Task 1: 创建演员列表页面组件
- **Priority**: P0
- **Depends On**: None
- **Description**: 
  - 创建 `actors_view.dart` 文件
  - 实现演员列表展示，包含头像、姓名、关注状态
  - 支持关注/取消关注功能
  - 支持点击演员跳转到详情页
- **Acceptance Criteria Addressed**: AC-3, AC-4, AC-5
- **Test Requirements**:
  - `human-judgement` TR-1.1: 页面显示演员列表，每个演员显示头像和姓名
  - `human-judgement` TR-1.2: 已关注演员显示已关注标记，未关注显示关注按钮
  - `programmatic` TR-1.3: 点击关注按钮后状态正确切换

## [x] Task 2: 更新底部导航栏添加演员按钮
- **Priority**: P0
- **Depends On**: Task 1
- **Description**: 
  - 更新 `home_scaffold.dart` 添加演员导航项
  - 调整页面索引配置（收藏=1，演员=2，设置=3）
- **Acceptance Criteria Addressed**: AC-1, AC-2
- **Test Requirements**:
  - `human-judgement` TR-2.1: 底部导航栏显示演员按钮（位于收藏和设置之间）
  - `programmatic` TR-2.2: 点击演员按钮跳转到演员列表页面

## [x] Task 3: 更新路由配置和页面导航Provider
- **Priority**: P0
- **Depends On**: Task 1
- **Description**: 
  - 更新 `app.dart` 添加演员页面路由
  - 更新 `page_navigation_provider.dart` 添加演员页面索引
- **Acceptance Criteria Addressed**: AC-2
- **Test Requirements**:
  - `programmatic` TR-3.1: 路由 `/actors` 正确映射到演员列表页面
  - `programmatic` TR-3.2: 页面导航状态正确处理演员页面

## [ ] Task 4: 集成测试与验证
- **Priority**: P1
- **Depends On**: Task 1, Task 2, Task 3
- **Description**: 
  - 运行现有测试确保没有回归
  - 验证演员页面功能正常工作
- **Acceptance Criteria Addressed**: AC-1, AC-2, AC-3, AC-4, AC-5
- **Test Requirements**:
  - `programmatic` TR-4.1: 所有现有测试通过
  - `human-judgement` TR-4.2: 端到端验证所有功能正常