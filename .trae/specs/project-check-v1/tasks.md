# 项目全面检查 - 任务清单

> 对 EmbyTok-Flutter 项目进行全面检查，验证实现状态。

---

## [ ] Task 1: 文件结构完整性检查
**Priority**: P0
**Depends On**: None

**Description**:
检查前端和后端的目录结构是否完整，必需文件是否存在。

**SubTasks**:
- [ ] 检查 `frontend/lib/` 目录结构（models/, views/, widgets/, services/, providers/, utils/）
- [ ] 检查 `backend/` 目录结构（main.py, routers/, models/, clients/, core/）
- [ ] 检查 `pubspec.yaml` 和 `requirements.txt` 是否存在
- [ ] 检查配置文件（flutter pubspec.yaml, backend requirements.txt）

---

## [ ] Task 2: 前端核心功能代码检查
**Priority**: P0
**Depends On**: Task 1

**Description**:
检查 Flutter 前端核心功能的代码实现。

**SubTasks**:
- [ ] 检查 login_view.dart - 登录页面实现
- [ ] 检查 feed_view.dart - 视频流页面实现
- [ ] 检查 video_player_widget.dart - 视频播放器实现（含动态 URL 支持）
- [ ] 检查 gesture_overlay.dart - 手势交互实现
- [ ] 检查 favorites_view.dart - 收藏页面实现
- [ ] 检查 search_view.dart - 搜索页面实现
- [ ] 检查 history_view.dart - 历史记录页面实现
- [ ] 检查 settings_view.dart - 设置页面实现

---

## [ ] Task 3: Provider 和状态管理检查
**Priority**: P0
**Depends On**: Task 1

**Description**:
检查 Riverpod Provider 的实现和状态管理。

**SubTasks**:
- [ ] 检查 auth_provider.dart - 认证状态管理
- [ ] 检查 library_provider.dart - 媒体库状态管理
- [ ] 检查 video_list_provider.dart - 视频列表状态管理
- [ ] 检查 favorites_provider.dart - 收藏状态管理
- [ ] 检查 search_provider.dart - 搜索状态管理
- [ ] 检查 watch_history_provider.dart - 历史记录状态管理
- [ ] 检查 theme_provider.dart - 主题状态管理

---

## [ ] Task 4: 后端 API 检查
**Priority**: P0
**Depends On**: Task 1

**Description**:
检查 FastAPI 后端的路由和数据模型。

**SubTasks**:
- [ ] 检查 main.py - 应用入口和路由挂载
- [ ] 检查 routers/auth.py - 认证路由
- [ ] 检查 routers/libraries.py - 媒体库路由
- [ ] 检查 routers/items.py - 媒体项路由
- [ ] 检查 routers/search.py - 搜索路由
- [ ] 检查 routers/favorites.py - 收藏路由
- [ ] 检查 models/ - Pydantic 模型
- [ ] 检查 clients/emby_client.py - Emby 客户端

---

## [ ] Task 5: 视频播放和认证增强检查
**Priority**: P0
**Depends On**: Task 2, Task 3

**Description**:
检查最近添加的视频播放和 UI 修复功能。

**SubTasks**:
- [ ] 检查 MediaItem.computePlaybackUrl() 方法
- [ ] 检查 MediaItem.authHeaders() 方法
- [ ] 检查 VideoPlayerWidget 的 embyServerUrl/token 参数
- [ ] 检查 VideoPageItem 的认证信息传递
- [ ] 检查 search_view/favorites_view/history_view 的认证图片加载

---

## [ ] Task 6: 代码质量分析
**Priority**: P1
**Depends On**: Task 2, Task 3, Task 4

**Description**:
分析代码质量和潜在问题。

**SubTasks**:
- [ ] 检查是否有硬编码的敏感信息
- [ ] 检查是否有 TODO/FIXME 注释
- [ ] 检查是否有未处理的异常
- [ ] 检查代码复杂度（大文件/长方法）
- [ ] 检查依赖使用是否正确

---

## [ ] Task 7: 文档完整性检查
**Priority**: P1
**Depends On**: Task 1

**Description**:
检查项目文档是否完整。

**SubTasks**:
- [ ] 检查 frontend/README.md
- [ ] 检查 backend/README.md
- [ ] 检查根目录 README.md
- [ ] 检查 CHANGELOG.md

---

## [x] Task 8: 生成检查报告
**Priority**: P1
**Depends By**: Task 1-7
**Status**: ✅ Completed

**Description**:
汇总所有检查结果，生成报告。

**SubTasks**:
- [x] 汇总文件结构检查结果
- [x] 汇总功能实现检查结果
- [x] 汇总代码质量问题
- [x] 列出待修复问题
- [x] 给出发布建议
