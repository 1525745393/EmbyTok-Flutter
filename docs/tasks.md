# EmbyTok Flutter v1.1.0 - 实施计划（Tasks）

## 总体实施策略

本项目共包含 **P0 任务必须完成后 P1 任务在 P2 任务可选

---

## Task 1: 修复网络层：完善 Emby 标准请求头注入

- **Priority**: P0
- **Depends On**: None
- **Description**:
  - 重构 `ApiClient`，确保每个请求都包含完整的 `X-Emby-Authorization` 和 `X-Emby-Token` 头
  - 添加 `X-Emby-Client`, `X-Emby-Device-Id`, `X-Emby-Device-Name`, `X-Emby-Client-Version` 等标准头
  - `Content-Type` 正确设置为 `application/json`
  - 确保 `Accept: application/json
- **实现细节**:
  - 在请求拦截器中统一注入所有必需头
  - 生成稳定的 `DeviceId`（UUID 生成一次后持久化）
  - 生成 `X-Emby-Authorization: Emby UserId="...", Client="EmbyTok", Device="Mobile", DeviceId="...", Version="1.0.0"
- **Acceptance Criteria**: AC-1, AC-8
- **Test Requirements**:
  - programmatic TR-1.1: 每个请求都包含 `X-Emby-Authorization 头
  - programmatic TR-1.2: 每个已登录后的请求都包含 `X-Emby-Token` 头
  - programmatic TR-1.3: `Content-Type` 始终为 `application/json`
- **Notes**: Emby 文档要求这些头是强制性的，尤其在认证请求时必须携带否则服务器才能返回401返回 401
- **文件:
  - `frontend/lib/services/api_client.dart`
  - `frontend/lib/services/embbytok_service.dart`

---

## Task 2: 修复登录流程 /Users/AuthenticateByName 正确协议实现

- **Priority**: P0
- **Depends On**: Task 1
- **Description**:
  - 实现标准的登录请求构造正确构造 POST `/Users/AuthenticateByName
  - 正确解析 JSON Body: `{"Username": "...", "Pw": "..."}`
  - 解析返回的 `{"User": { "Id": "...", "AccessToken, ... }`
  - 保存 AccessToken 到本地存储
  - 保存 UserId 到本地存储
- **实现细节**:
  - 支持 application/json 格式发送
  - 成功后保存到 shared_preferences
  - Key: `emby_server_url, `user_id`, `access_token`, `server_id`, `server_name`
- **Acceptance Criteria**: AC-1
- **Test Requirements**:
  - programmatic TR-2.1: 登录成功后保存正确保存 AccessToken + user 等信息
  - programmatic TR-2.2: 登录失败后错误消息对错误信息对用户名
- **文件**:
  - `frontend/lib/services/embbytok_service.dart`
  - `frontend/lib/providers/auth_provider.dart`
  - `frontend/lib/views/login_view.dart`

---

## Task 3: 服务器地址验证与自动补全

- **Priority**: P0
- **Depends On**: None
- **Description**:
  - 用户输入服务器地址后自动补全
  - 输入 `192.168.1.100` → 自动补全为 `http://192.168.1.100:8096`
  - 输入 `192.168.1.100:8096` → 自动补全为 `http://192.168.1.100:8096`
  - 输入 `https://emby.example.com` → 保持原样
- **实现细节**:
  - 在提交前先测试 `GET /System/Info/Public` 来验证服务器可达性
  - 如果服务器返回 200 则继续
- **Acceptance Criteria**: AC-9
- **Test Requirements**:
  - programmatic TR-3.1: 测试多种输入格式自动补全正确
  - programmatic TR-3.2: 对无效地址显示错误信息
- **文件**:
  - `frontend/lib/views/login_view.dart`
  - `frontend/lib/services/api_client.dart`

---

## Task 4: 媒体库列表获取 GET /Library/VirtualFolders

- **Priority**: P0
- **Depends On**: Task 2
- **Description**:
  - 获取用户可访问的所有媒体库
  - 自动选中第一个非空库
  - 顶部横向滚动条切换
- **实现细节**:
  - 过滤空库（ItemCount == 0 的库不显示
  - 显示库名 + 类型标签
  - 选中高亮当前选中库
- **Acceptance Criteria**: AC-2
- **Test Requirements**:
  - programmatic TR-4.1: 成功获取媒体库列表
  - human-judgment TR-4.2: UI 显示正确的库列表，选中第一个
- **文件**:
  - `frontend/lib/services/embbytok_service.dart`
  - `frontend/lib/providers/library_provider.dart`
  - `frontend/lib/views/feed_view.dart`

---

## Task 5: 媒体列表获取 GET /Items 正确参数

- **Priority**: P0
- **Depends On**: Task 4
- **Description**:
  - 获取正确的 SortBy 改为 `PremiereDate,ProductionYear,SortName（电影）或 `DateCreated`（剧集
  - Recursive=true
  - IncludeItemTypes=Movie,Episode,Video,MusicVideo
  - Fields=Overview,Genres,CommunityRating,ProductionYear,RuntimeTicks,UserData
  - 支持分页（StartIndex, Limit
  - 滑动到底部自动加载下一页
- **实现细节**:
  - 每次返回 TotalRecordCount 记录总数判断
  - 当 StartIndex + Limit >= TotalRecordCount 停止加载
- **Acceptance Criteria**: AC-3
- **Test Requirements**:
  - programmatic TR-5.1: 分页加载正确，每
  - programmatic TR-5.2: 滑动到底部正确加载下一页
  - human-judgment TR-5.3: 加载流畅
- **文件**:
  - `frontend/lib/services/embbytok_service.dart`
  - `frontend/lib/providers/video_list_provider.dart`
  - `frontend/lib/views/feed_view.dart`

---

## Task 6: 媒体项模型重构：生成正确的缩略图和播放地址

- **Priority**: P0
- **Depends On**: Task 5
- **Description**:
  - 从 /Items 响应解析 MediaItem 正确的 Id、名称、时长、等字段
  - **thumbnailUrl = `{server_url}/Items/{id}/Images/Primary?MaxWidth=800&Format=jpg
  - **playbackUrl = `{server_url}/Videos/{id}/stream?api_key={token} （在请求头 X-Emby-Token 头
- **实现细节**:
  - **User.IsFavorite 解析 UserData.IsFavorite
  - **RuntimeTicks 转秒（/ 10000000
  - 确保地址都使用 `DateTime.FromBinary(... `MediaItem 字段
- **Acceptance Criteria**: AC-3, AC-4
- **Test Requirements**:
  - programmatic TR-6.1: MediaItem 正确构造
  - human-judgment TR-6.2: 缩略图正确显示
  - programmatic TR-6.3: 播放地址正确
- **文件**:
  - `frontend/lib/models/media_item.dart`
  - `frontend/lib/services/embbytok_service.dart`

---

## Task 7: 视频播放集成

- **Priority**: P0
- **Depends On**: Task 6
- **Description**:
  - 使用 video_player 播放 `/Videos/<id>/stream 地址
  - 通过 X-Emby-Token 请求头中 token
  - 视频自动播放当前页视频流
- **实现细节**:
  - VideoPlayerController.networkUrl()
  - 在 URL 格式 `{server}/Videos/{id}/stream?api_key={token} 或使用 X-Emby-Token 请求头
  - 自动在 video_player 设置 httpHeaders
- **Acceptance Criteria**: AC-4
- **Test Requirements**:
  - programmatic TR-7.1: 视频播放地址正确
  - human-judgment TR-7.2: 视频流畅播放
- **文件**:
  - `frontend/lib/widgets/video_player_widget.dart`（或 video_player_widget.dart

---

## Task 8: 搜索功能修复

- **Priority**: P1
- **Depends On**: Task 5
- **Description**:
  - `GET /Items?SearchTerm=<query>&Recursive=true
  - 300ms 防抖
  - 搜索结果列表显示
  - 搜索历史本地存储
- **实现细节**:
  - 搜索历史最多保存到 shared_preferences
  - 点击搜索历史项直接搜索
- **Acceptance Criteria**: AC-5
- **Test Requirements**:
  - programmatic TR-8.1: 搜索返回正确
  - programmatic TR-8.2: 搜索历史保存
- **文件**:
  - `frontend/lib/services/embbytok_service.dart`
  - `frontend/lib/providers/search_provider.dart`
  - `frontend/lib/views/search_view.dart`

---

## Task 9: 收藏功能修复

- **Priority**: P1
- **Depends On**: Task 6
- **Description**:
  - 收藏按钮在视频页面点击 heart_animation 组件
  - 调用 `POST /Users/<user_id>/FavoriteItems/<item_id>
  - 取消调用 `DELETE /Users/<user_id>/FavoriteItems/<item_id>
- **实现细节**:
  - 乐观更新 UI 态
  - 失败回滚
- **Acceptance Criteria**: AC-6
- **Test Requirements**:
  - programmatic TR-9.1: 收藏/取消收藏
  - programmatic TR-9.2: 收藏列表正确获取
- **文件**:
  - `frontend/lib/services/embbytok_service.dart`
  - `frontend/lib/providers/favorites_provider.dart`
  - `frontend/lib/views/favorites_view.dart`
  - `frontend/lib/widgets/gesture_overlay.dart`

---

## Task 10: 完善错误信息优化

- **Priority**: P0
- **Depends On**: Task 1
- **Description**:
  - 错误信息分类：网络 / 认证 / 权限 / 服务器错误 / 超时
  - 为每种情况提供中文友好提示信息
  - 401 Token 过期自动跳回登录页
- **实现细节**:
  - Dio 错误在 _humanReadableError 映射中文消息
  - SnackBar 显示
- **Acceptance Criteria**: AC-7, AC-8
- **Test Requirements**:
  - programmatic TR-10.1: 401 自动跳转
  - human-judgment TR-10.2: 错误消息清晰
- **文件**:
  - `frontend/lib/services/api_client.dart`

---

## Task 11: 播放进度同步

- **Priority**: P1
- **Depends On**: Task 7
- **Description**:
  - 播放期间定期（30s `POST /Users/<user_id>/PlayingItems/<item_id>/Progress
  - 播放完成 POST /Users/<user_id>/PlayingItems/<item_id>/Stopped
  - 本地观看历史 shared_preferences 存
- **实现细节**:
  - 在视频播放期间进度保存进度条
- **Acceptance Criteria**: AC-5
- **文件**:
  - `frontend/lib/services/embbytok_service.dart`
  - `frontend/lib/providers/watch_history_provider.dart`

---

## Task 12: 多服务器管理

- **Priority**: P2
- **Depends On**: Task 2
- **Description**:
  - 添加、切换、删除服务器切换服务器
  - 每个服务器独立保存
- **实现细节**:
  - 设置页服务器列表
  - 选择一个服务器快速切换
- **Acceptance Criteria**: AC-6
- **文件**:
  - `frontend/lib/providers/auth_provider.dart`
  - `frontend/lib/views/settings_view.dart`

---

## 实施顺序

```
Phase 1: Tasks 1, 2, 3（基础认证、
Phase 2: Tasks 4, 5, 6（媒体列表
Phase 3: Tasks 7（视频播放
Phase 4: Tasks 8, 9, 10, 11（搜索、收藏、错误、播放进度

