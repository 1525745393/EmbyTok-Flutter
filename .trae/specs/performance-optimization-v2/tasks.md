# Tasks

- [x] Task 1: 搜索输入防抖
  - **Priority**: high
  - **Depends On**: None
  - **Description**:
    - 已有实现：_debounce + kDebounceMs(300ms)
    - 输入停止 300ms 后发起搜索
    - 涉及文件：search_view.dart
  - **Acceptance Criteria Addressed**: AC-1
  - **Status**: 已存在，无需修改

- [x] Task 2: 双向视频预加载
  - **Priority**: high
  - **Depends On**: None
  - **Description**:
    - 修改 feed_view.dart 的预加载逻辑，同时预加载上一条和下一条视频
    - 修改 _evictFarPreloads 清理策略，保留当前条目前后各 1 条
    - 涉及文件：feed_view.dart
  - **Acceptance Criteria Addressed**: AC-2
  - **Test Requirements**:
    - `human-judgement` TR-2.1: 向上滑动回到上一条视频也能秒开
    - `programmatic` TR-2.2: _evictFarPreloads 保留前后各 1 条

- [x] Task 3: 过滤列表增量计算优化（收益有限，跳过）
  - **Priority**: medium
  - **Depends On**: None
  - **Description**:
    - Riverpod Provider 自带缓存，相同引用返回相同结果
    - 中小列表（几百条）where 过滤耗时可忽略
    - 暂不优化
  - **Acceptance Criteria Addressed**: AC-3
  - **Status**: 跳过，收益有限

- [x] Task 4: EmbytokService 单例化
  - **Priority**: medium
  - **Depends On**: None
  - **Description**:
    - 将 EmbytokService 改为单例模式（factory 构造函数返回单例）
    - 22 处新建实例全部复用同一个单例
    - 保留 withClient 命名构造函数供测试使用
    - 涉及文件：embbytok_service.dart、测试文件
  - **Acceptance Criteria Addressed**: AC-4
  - **Test Requirements**:
    - `programmatic` TR-4.1: EmbytokService 只创建一个实例

# Task Dependencies
- Task 3 和 Task 4 可与 Task 1、Task 2 并行
