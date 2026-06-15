# 项目全面检查 - 验收清单

> 本清单用于逐项验证 EmbyTok-Flutter 项目的实现状态。

---

## 文件结构检查

### 前端目录结构
- [ ] `frontend/lib/models/` 目录存在且包含必需模型
- [ ] `frontend/lib/views/` 目录存在且包含所有视图
- [ ] `frontend/lib/widgets/` 目录存在且包含所有组件
- [ ] `frontend/lib/services/` 目录存在且包含 API 客户端
- [ ] `frontend/lib/providers/` 目录存在且包含所有 Provider
- [ ] `frontend/lib/utils/` 目录存在且包含工具函数
- [ ] `frontend/pubspec.yaml` 存在且配置正确

### 后端目录结构
- [ ] `backend/main.py` 存在
- [ ] `backend/routers/` 目录存在且包含所有路由
- [ ] `backend/models/` 目录存在且包含所有模型
- [ ] `backend/clients/` 目录存在且包含 Emby 客户端
- [ ] `backend/core/` 目录存在且包含配置和错误处理
- [ ] `backend/requirements.txt` 存在且配置正确
- [ ] `backend/Dockerfile` 存在

---

## 前端核心功能检查

### 登录功能 (AC-1)
- [ ] `login_view.dart` 包含后端代理地址输入
- [ ] `login_view.dart` 包含 Emby 服务器地址输入
- [ ] `login_view.dart` 包含用户名和密码输入
- [ ] `login_view.dart` 包含 API Key 输入（可选）
- [ ] `login_view.dart` 包含登录按钮
- [ ] `auth_provider.dart` 实现登录逻辑
- [ ] `auth_provider.dart` 实现 token 持久化
- [ ] `auth_provider.dart` 实现登出逻辑

### 视频流页面 (AC-3)
- [ ] `feed_view.dart` 使用 PageView 实现竖屏滑动
- [ ] `feed_view.dart` 支持全屏视频展示
- [ ] `feed_view.dart` 支持自动播放
- [ ] `feed_view.dart` 支持分页加载

### 视频播放器 (AC-4)
- [ ] `video_player_widget.dart` 存在且实现播放功能
- [ ] `video_player_widget.dart` 支持动态构造播放 URL
- [ ] `video_player_widget.dart` 支持认证头传递
- [ ] `video_controls.dart` 存在且实现播放控制
- [ ] `video_controls.dart` 支持播放/暂停
- [ ] `video_controls.dart` 支持进度条
- [ ] `video_controls.dart` 支持倍速选择

### 手势交互 (AC-5)
- [ ] `gesture_overlay.dart` 存在且实现手势检测
- [ ] 支持单击播放/暂停
- [ ] 支持双击收藏
- [ ] 支持长按倍速
- [ ] 支持水平滑动快进/快退
- [ ] `heart_animation.dart` 存在且实现点赞动画

### 收藏功能 (AC-7)
- [ ] `favorites_view.dart` 存在且实现收藏列表
- [ ] `favorites_provider.dart` 实现收藏状态管理
- [ ] 支持收藏/取消收藏
- [ ] 支持删除收藏

### 搜索功能 (AC-8)
- [ ] `search_view.dart` 存在且实现搜索页面
- [ ] `search_provider.dart` 实现搜索状态管理
- [ ] `search_history_provider.dart` 实现搜索历史
- [ ] 支持结果分页

### 历史记录 (AC-10)
- [ ] `history_view.dart` 存在且实现历史页面
- [ ] `watch_history_provider.dart` 实现历史状态管理
- [ ] 支持显示观看进度
- [ ] 支持清空历史

### 设置页面 (AC-17)
- [ ] `settings_view.dart` 存在且实现设置页面
- [ ] `theme_provider.dart` 实现主题管理
- [ ] 支持主题切换
- [ ] 支持退出登录

---

## Provider 状态管理检查

- [ ] `auth_provider.dart` 正确导出
- [ ] `library_provider.dart` 正确导出
- [ ] `video_list_provider.dart` 正确导出
- [ ] `favorites_provider.dart` 正确导出
- [ ] `search_provider.dart` 正确导出
- [ ] `watch_history_provider.dart` 正确导出
- [ ] `theme_provider.dart` 正确导出
- [ ] `providers.dart` 统一导出所有 Provider

---

## 后端 API 检查

### 健康检查 (AC-11)
- [ ] `/health` 端点存在
- [ ] 返回正确的版本信息

### 认证 API (AC-12)
- [ ] `POST /api/auth/login` 路由存在
- [ ] 返回正确的认证响应

### 媒体库 API (AC-13)
- [ ] `GET /api/libraries` 路由存在
- [ ] `GET /api/libraries/{id}/items` 路由存在
- [ ] 支持分页参数

### 搜索 API (AC-14)
- [ ] `POST /api/search` 路由存在
- [ ] 返回正确的搜索结果

### Docker 配置 (AC-15)
- [ ] `Dockerfile` 存在且正确
- [ ] `docker-compose.yml` 存在且正确

---

## 代码质量检查

### 视频播放认证增强
- [ ] `MediaItem.computePlaybackUrl()` 方法存在
- [ ] `MediaItem.authHeaders()` 方法存在
- [ ] `VideoPlayerWidget` 支持 embyServerUrl 参数
- [ ] `VideoPlayerWidget` 支持 token 参数
- [ ] 图片加载包含认证头

### 代码质量
- [ ] 无硬编码敏感信息
- [ ] 无未处理的异常
- [ ] 代码结构清晰

---

## 文档检查

- [ ] `frontend/README.md` 存在且完整
- [ ] `backend/README.md` 存在且完整
- [ ] `CHANGELOG.md` 存在且包含版本记录

---

## 待修复问题汇总

> 此部分在检查完成后填写

### 高优先级
- [ ] ⚠️ backend/core/version.py 中 embytokVersion 拼写错误（应为 embbytokVersion）

### 中优先级
- [ ] 建议统一 API Service 层命名（embbytok_service.dart vs embbytok_service.dart）

### 低优先级
- [ ] 建议为更多组件添加中文注释
