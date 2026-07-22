# 观看统计 Bug 修复 - 验证清单

- [x] dispose() 方法中不包含任何 ref.read() 调用
- [x] _recordWatchStats() 在 deactivate() 中调用而非 dispose() 中
- [x] 有防重复记录标记（如 _statsRecorded），deactivate 多次调用不重复记录
- [x] activate() 中重置了防重复记录标记
- [x] _recordWatchStats() 方法中存在 isCurrentPage 检查
- [x] isCurrentPage=false 时直接返回，不调用 recordWatch
- [x] 用户登出后 watchStatsProvider state 变为空状态
- [x] 新用户登录后 watchStatsProvider 加载对应用户的记录
- [x] 同一用户重新登录能正确加载记录
- [x] 使用 ref.listen 或类似机制监听 auth 变化
- [x] 本地存储按 userId 分键的机制保持不变
- [x] 清除统计功能仍然正常工作
- [x] 代码符合项目命名规范和代码风格
- [x] 没有引入新的 Riverpod 规范违反
- [x] 没有引入新的潜在 Bug 或副作用
