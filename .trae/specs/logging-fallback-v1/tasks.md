# 日志完善与错误降级策略 - 任务清单

> 在关键 API 调用处添加结构化日志，并实现视频流失败时的降级策略。

---

## [x] Task 1: 创建日志工具类
**Priority**: P0
**Depends On**: None

**Description**:
创建统一的日志工具类，支持不同日志级别和结构化数据。

**SubTasks**:
- [ ] 创建 `frontend/lib/utils/logger.dart`
- [ ] 实现日志级别控制（Debug/Info/Warn/Error）
- [ ] 支持结构化数据附加
- [ ] 添加时间戳和调用位置信息

---

## [x] Task 2: 在认证流程添加日志
**Priority**: P0
**Depends On**: Task 1

**Description**:
在登录、登出、Token 刷新等认证流程添加结构化日志。

**SubTasks**:
- [ ] 修改 `auth_provider.dart`，在 login 方法添加日志
- [ ] 在 logout 方法添加日志
- [ ] 在 _loadFromStorage 方法添加日志
- [ ] 捕获并记录认证错误

---

## [x] Task 3: 在媒体库和视频列表添加日志
**Priority**: P0
**Depends On**: Task 1

**Description**:
在媒体库加载和视频列表请求添加日志。

**SubTasks**:
- [ ] 修改 `library_provider.dart`，添加媒体库加载日志
- [ ] 修改 `video_list_provider.dart`，添加视频列表请求日志
- [ ] 记录分页加载状态

---

## [x] Task 4: 在视频播放器添加日志和降级策略
**Priority**: P0
**Depends On**: Task 1

**Description**:
在视频播放器添加日志，并实现降级策略。

**SubTasks**:
- [ ] 修改 `video_player_widget.dart`，添加播放状态日志
- [ ] 实现降级逻辑：后端代理失败 → Emby 原生 API
- [ ] 添加 `fallbackUrl` 参数支持
- [ ] 记录降级触发原因和结果

---

## [x] Task 5: 在搜索和收藏功能添加日志
**Priority**: P1
**Depends On**: Task 1

**Description**:
在搜索和收藏功能添加日志。

**SubTasks**:
- [ ] 修改 `search_provider.dart`，添加搜索请求日志
- [ ] 修改 `favorites_provider.dart`，添加收藏操作日志
- [ ] 记录防抖和分页状态

---

## [x] Task 6: 在 EmbytokService 添加日志
**Priority**: P0
**Depends On**: Task 1

**Description**:
在 API 服务层添加请求/响应日志。

**SubTasks**:
- [ ] 修改 `embbytok_service.dart`，添加 HTTP 请求日志
- [ ] 记录请求 URL、方法、耗时
- [ ] 记录响应状态码和数据大小
- [ ] 捕获并记录网络错误

---

## [ ] Task 7: 添加日志配置选项
**Priority**: P2
**Depends On**: Task 1-6

**Description**:
在设置页面添加日志级别配置选项。

**SubTasks**:
- [ ] 在 `settings_view.dart` 添加日志级别开关
- [ ] Debug 模式启用详细日志
- [ ] Release 模式仅记录 Error 和 Warn

---

## [x] Task 8: 测试和验证
**Priority**: P0
**Depends On**: Task 1-6

**Description**:
测试日志功能和降级策略。

**SubTasks**:
- [ ] 验证日志输出格式正确
- [ ] 验证降级策略正常工作
- [ ] 验证错误捕获和记录
- [ ] 验证 Debug/Release 日志级别差异

---

# Task Dependencies

```
Task 1 (日志工具类)
  ├─→ Task 2 (认证日志)
  ├─→ Task 3 (媒体库日志)
  ├─→ Task 4 (视频播放日志+降级)
  ├─→ Task 5 (搜索收藏日志)
  └─→ Task 6 (Service 日志)
        └─→ Task 7 (日志配置)
              └─→ Task 8 (测试验证)
```

**可并行执行**：Task 2、Task 3、Task 4、Task 5、Task 6 可在 Task 1 完成后并行执行。
