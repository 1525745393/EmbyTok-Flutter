# 日志完善与错误降级策略 - 验收清单

> 本清单用于逐项验证日志系统和降级策略的实现状态。

---

## 日志工具类

- [x] `frontend/lib/utils/logger.dart` 文件存在
- [x] `AppLogger.info()` 方法实现正确
- [x] `AppLogger.debug()` 方法实现正确
- [x] `AppLogger.warn()` 方法实现正确
- [x] `AppLogger.error()` 方法实现正确
- [x] 日志包含时间戳信息
- [x] 日志支持结构化数据附加

---

## 认证流程日志

- [x] `auth_provider.dart` 导入 `AppLogger`
- [x] 登录开始时记录 INFO 日志
- [x] 登录成功时记录 INFO 日志（包含 userId）
- [x] 登录失败时记录 ERROR 日志（包含错误信息）
- [x] 登出时记录 INFO 日志
- [x] Token 恢复时记录 DEBUG 日志

---

## 媒体库和视频列表日志

- [x] `library_provider.dart` 导入 `AppLogger`
- [x] 媒体库加载开始/完成时记录日志
- [x] `video_list_provider.dart` 导入 `AppLogger`
- [x] 视频列表请求开始/完成时记录日志
- [x] 分页加载状态记录日志

---

## 视频播放器日志和降级策略

### 日志
- [x] `video_player_widget.dart` 导入 `AppLogger`
- [x] 播放器初始化时记录日志
- [x] 播放 URL 构造时记录日志
- [x] 播放状态变化时记录日志
- [x] 播放错误时记录 ERROR 日志

### 降级策略
- [x] `VideoPlayerWidget` 支持 `fallbackUrl` 参数
- [x] 主 URL 播放失败时自动尝试 fallbackUrl
- [x] 降级触发时记录 WARN 日志（包含原因）
- [x] 降级成功时记录 INFO 日志
- [x] 降级失败时显示友好错误提示
- [ ] 错误提示包含"重试"按钮（待 UI 实现）

---

## 搜索和收藏日志

- [x] `search_provider.dart` 导入 `AppLogger`
- [x] 搜索请求开始/完成时记录日志
- [x] 搜索防抖状态记录日志
- [x] `favorites_provider.dart` 导入 `AppLogger`
- [x] 收藏/取消收藏操作记录日志

---

## EmbytokService 日志

- [x] `embbytok_service.dart` 导入 `AppLogger`
- [x] HTTP 请求发送时记录日志（URL、方法）
- [x] HTTP 响应接收时记录日志（状态码、耗时）
- [x] 网络错误时记录 ERROR 日志
- [x] 超时时记录 WARN 日志

---

## 日志配置选项

- [ ] `settings_view.dart` 包含日志级别配置（Task 7 待实施）
- [x] Debug 模式启用详细日志（DEBUG 及以上）
- [x] Release 模式仅记录 WARN 及以上
- [ ] 日志级别持久化到本地存储（Task 7 待实施）

---

## 功能验证

### 日志输出验证
- [x] 日志格式正确：`[LEVEL] message {data}`
- [x] 日志包含时间戳
- [x] 结构化数据正确序列化

### 降级策略验证
- [x] 后端代理超时时触发降级
- [x] 后端返回 5xx 时触发降级
- [x] 网络错误时触发降级
- [x] 降级后视频正常播放
- [x] 降级失败时显示错误提示

### 错误处理验证
- [x] 所有 API 错误被捕获并记录
- [x] 用户看到友好的错误提示
- [ ] 重试功能正常工作（待 UI 实现）

---

## 代码质量

- [x] 无硬编码的敏感信息（Token、密码等）
- [x] 日志不泄露用户隐私（自动过滤敏感键名）
- [x] Release 模式下敏感日志被过滤
- [x] 代码符合 Flutter 最佳实践
