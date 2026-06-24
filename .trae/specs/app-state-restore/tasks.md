# 应用状态恢复 - The Implementation Plan (Decomposed and Prioritized Task List)

## [ ] Task 1: 在 constants.dart 中添加页面索引存储键常量
- **Priority**: high
- **Depends On**: None
- **Description**: 
  - 添加 `kStorageKeyLastPageIndex` 常量
  - 命名风格与现有常量保持一致
- **Acceptance Criteria Addressed**: AC-4
- **Test Requirements**:
  - `programmatic` TR-1.1: constants.dart 中定义了新的存储键常量

## [ ] Task 2: 修改 pageNavigationProvider 添加持久化支持
- **Priority**: high
- **Depends On**: Task 1
- **Description**: 
  - 在 PageNavigationNotifier 构造函数中调用 _load() 从 SharedPreferences 加载上次页面索引
  - 添加 _load() 异步方法，加载时忽略覆盖层页面，只恢复主页面
  - 修改 goToPage() 方法，切换主页面时保存索引
  - 覆盖层页面（goToSearch/goToHistory）切换时不保存
- **Acceptance Criteria Addressed**: AC-1, AC-2
- **Test Requirements**:
  - `programmatic` TR-2.1: 应用启动时从存储加载上次的页面索引
  - `programmatic` TR-2.2: 切换主页面时自动保存到存储
  - `programmatic` TR-2.3: 覆盖层页面（搜索/历史）切换时不保存
  - `programmatic` TR-2.4: 如果上次是覆盖层页面，恢复到底层主页面

## [ ] Task 3: 验证现有持久化设置正常工作
- **Priority**: medium
- **Depends On**: None
- **Description**: 
  - 验证 feedType（浏览模式）持久化正常
  - 验证 viewMode（视图模式）持久化正常
  - 验证 orientationMode（方向过滤）持久化正常
  - 验证 themeMode（主题）持久化正常
- **Acceptance Criteria Addressed**: AC-4
- **Test Requirements**:
  - `human-judgement` TR-3.1: 浏览模式设置在重启后保持
  - `human-judgement` TR-3.2: 视图模式设置在重启后保持
  - `human-judgement` TR-3.3: 方向过滤设置在重启后保持
