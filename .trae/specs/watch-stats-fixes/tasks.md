# 观看统计 Bug 修复 - 实施计划

## [x] Task 1: 修复 dispose 中 ref.read() 违反 Riverpod 规范
- **Priority**: high
- **Depends On**: None
- **Description**:
  - 将 `_recordWatchStats()` 调用从 `dispose()` 移到 `deactivate()` 中
  - 确保 dispose() 中没有任何 ref.read() 调用
  - 添加 `_statsRecorded` 标记防止 deactivate 被多次调用时重复记录
- **Acceptance Criteria Addressed**: AC-1
- **Test Requirements**:
  - `programmatic` TR-1.1: dispose() 方法中不包含任何 ref.read() 调用
  - `programmatic` TR-1.2: _recordWatchStats() 在 deactivate() 中被调用
  - `programmatic` TR-1.3: 有 _statsRecorded 或类似标记确保 deactivate 多次调用不重复记录
- **Notes**: 注意 activate() 中需要重置标记，确保 widget 重新插入树后下次 deactivate 能正常记录

## [x] Task 2: 修复非当前页也记录统计
- **Priority**: high
- **Depends On**: None
- **Description**:
  - 在 `_recordWatchStats()` 方法开头增加 `widget.isCurrentPage` 检查
  - 非当前页直接返回，不记录统计
- **Acceptance Criteria Addressed**: AC-2
- **Test Requirements**:
  - `programmatic` TR-2.1: _recordWatchStats() 方法中存在 isCurrentPage 检查
  - `programmatic` TR-2.2: isCurrentPage=false 时不调用 recordWatch
- **Notes**: 这是最影响数据准确性的修复，优先级最高

## [x] Task 3: 修复用户切换后内存 state 未重置
- **Priority**: high
- **Depends On**: None
- **Description**:
  - 在 `WatchStatsNotifier` 中监听 `authProvider` 变化
  - 当用户 ID 变化时（登出、切换用户），重置内存 state 并加载新用户数据
  - 保持现有 SharedPreferences 按 userId 分键的存储机制不变
- **Acceptance Criteria Addressed**: AC-3, AC-4, AC-5
- **Test Requirements**:
  - `programmatic` TR-3.1: 用户登出后 watchStatsProvider state 变为空
  - `programmatic` TR-3.2: 新用户登录后加载对应用户的记录
  - `programmatic` TR-3.3: 同一用户重新登录能正确加载记录
  - `programmatic` TR-3.4: 使用 ref.listen 或类似机制监听 auth 变化
- **Notes**:
  - 使用 `ref.listen` 监听 authProvider 变化，避免在构造函数中监听导致的循环引用
  - 注意不要在 initState 之前访问 ref.read(authProvider)
  - 保持现有 _init() 逻辑兼容

## [x] Task 4: 代码审查和一致性验证
- **Priority**: medium
- **Depends On**: Task 1, Task 2, Task 3
- **Description**:
  - 检查所有修改符合项目代码规范
  - 验证三处修改之间没有冲突或副作用
  - 确保没有引入新的 Bug
- **Acceptance Criteria Addressed**: AC-6
- **Test Requirements**:
  - `human-judgement` TR-4.1: 代码符合项目命名规范和代码风格
  - `human-judgement` TR-4.2: 修改逻辑清晰，注释准确
  - `human-judgement` TR-4.3: 没有引入新的潜在问题
