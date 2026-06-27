# EmbyX 功能对齐验证 - 实施计划（验证任务列表）

## [x] Task 1: 验证媒体库选择器功能对齐
- **Priority**: high
- **Depends On**: None
- **Description**: 
  - 检查 LibrarySelector 组件是否与 EmbyX 行为一致
  - 验证：2列网格布局、收藏夹入口、单选模式、点击即切换并关闭
- **Acceptance Criteria Addressed**: AC-1
- **Test Requirements**:
  - `human-judgement` TR-1.1: 媒体库选择器为居中弹窗 Dialog
  - `human-judgement` TR-1.2: 2列网格布局，包含收藏夹入口和媒体库列表
  - `human-judgement` TR-1.3: 单选模式，点击即切换并关闭弹窗
  - `programmatic` TR-1.4: 点击媒体库后 selectedLibraryIdsProvider 正确更新

## [x] Task 2: 验证网格→视频流跳转功能对齐
- **Priority**: high
- **Depends On**: None
- **Description**: 
  - 检查 _handleGridToFeedTransition 方法实现
  - 验证：统一通过 viewModeProvider 监听器处理，无独立监听器
  - 验证：跳转后 currentIndex 正确，gridSelectedItemIdProvider 被清理
- **Acceptance Criteria Addressed**: AC-2, AC-5
- **Test Requirements**:
  - `programmatic` TR-2.1: 点击网格视频后，视图切换到 feed 模式
  - `programmatic` TR-2.2: 跳转后 currentIndex 等于点击视频的索引
  - `programmatic` TR-2.3: 跳转后 gridSelectedItemIdProvider 被清理为 null
  - `programmatic` TR-2.4: initState 中没有独立的 gridSelectedItemIdProvider 监听器
  - `human-judgement` TR-2.5: 只有 viewModeProvider 监听器一处处理跳转

## [x] Task 3: 验证视频流→网格滚动功能对齐
- **Priority**: high
- **Depends On**: None
- **Description**: 
  - 检查 _tryScrollToCurrentVideo 方法实现
  - 验证：垂直居中滚动，与 EmbyX 公式一致
  - 验证：3列布局计算正确，animateTo 平滑滚动
- **Acceptance Criteria Addressed**: AC-3
- **Test Requirements**:
  - `programmatic` TR-3.1: 从 feed 切到 grid 时，_handleFeedToGridTransition 被调用
  - `programmatic` TR-3.2: 滚动使用垂直居中公式：elTop - (areaHeight / 2) + (elHeight / 2)
  - `programmatic` TR-3.3: 使用 animateTo 平滑滚动（300ms，Curves.easeOut）
  - `programmatic` TR-3.4: 滚动偏移使用 clamp 限制在有效范围内
  - `human-judgement` TR-3.5: 当前视频在可视区域内垂直居中显示

## [x] Task 4: 验证「神之一手」裁剪功能对齐
- **Priority**: high
- **Depends On**: None
- **Description**: 
  - 检查 video_list_provider.dart 中的裁剪逻辑
  - 验证：根据 currentIndex 计算页码，裁剪到当前页（150条）
- **Acceptance Criteria Addressed**: AC-4
- **Test Requirements**:
  - `programmatic` TR-4.1: 从 feed 切到 grid 时，执行裁剪逻辑
  - `programmatic` TR-4.2: pageIndex = currentIndex ~/ 150
  - `programmatic` TR-4.3: gridStartIndex = pageIndex * 150
  - `programmatic` TR-4.4: gridItems 为当前页的 150 条数据

## [x] Task 5: 验证滚动位置持久化逻辑对齐
- **Priority**: high
- **Depends On**: None
- **Description**: 
  - 检查网格滚动位置的保存和恢复逻辑
  - 验证：只保存不恢复，不从 SharedPreferences 恢复滚动位置
- **Acceptance Criteria Addressed**: AC-6
- **Test Requirements**:
  - `programmatic` TR-5.1: _buildGridPageView 中没有恢复滚动位置的逻辑
  - `programmatic` TR-5.2: 没有 _hasRestoredGridScrollPosition 变量
  - `programmatic` TR-5.3: _saveGridScrollOffset 和 _onGridScrollChanged 保留（保存逻辑）
  - `human-judgement` TR-5.4: 滚动失败时降级调用 _restoreGridScrollOffset

## Task Dependencies
- 所有任务相互独立，可并行验证
