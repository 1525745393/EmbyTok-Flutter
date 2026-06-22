# EmbyX vs EmbyTok 功能差距：点赞和媒体库显示 Spec

## Why

用户反馈 EmbyTok-Flutter 相比 EmbyX 存在两个关键功能缺失：
1. **点赞功能不可用** - EmbyX 的点赞/收藏功能正常工作，EmbyTok-Flutter 无法使用
2. **媒体库显示不完整** - EmbyX 能显示全部媒体库，EmbyTok-Flutter 媒体库显示不全

## What Changes

- **点赞功能**：修复收藏 API 调用逻辑，使用正确的 Emby API 端点
- **媒体库显示**：修复媒体库列表获取，确保显示用户所有可访问的媒体库
- **API 路径统一**：确保所有用户相关 API 调用使用用户视角路径 `/Users/{userId}/...`

## Impact

- Affected specs: 收藏功能、媒体库浏览
- Affected code:
  - `frontend/lib/services/embbytok_service.dart` - 收藏 API 和媒体库 API
  - `frontend/lib/providers/favorites_provider.dart` - 收藏状态管理
  - `frontend/lib/providers/library_provider.dart` - 媒体库列表管理

---

## 背景分析

### EmbyX vs EmbyTok API 差异

| 功能 | EmbyX | EmbyTok-Flutter |
|------|--------|------------------|
| 媒体库列表 | `/Users/{userId}/Views` | `/Library/VirtualFolders` |
| 收藏添加 | `POST /Users/{userId}/FavoriteItems/{itemId}` | `POST /UserFavoriteItems/{itemId}` |
| 收藏取消 | `DELETE /Users/{userId}/FavoriteItems/{itemId}` | `DELETE /UserFavoriteItems/{itemId}` |
| 视频列表 | `/Users/{userId}/Items` | `/Items` |

### 核心问题

1. **媒体库显示不完整**：
   - EmbyTok 使用 `/Library/VirtualFolders`（管理员视角），可能返回用户无权访问的库
   - EmbyX 使用 `/Users/{userId}/Views`（用户视角），只返回用户可访问的库
   - 需要修改 `getLibraries()` 方法使用用户视角路径

2. **点赞功能失效**：
   - EmbyTok 使用 `/UserFavoriteItems/{itemId}`（不带 userId）
   - EmbyX 使用 `/Users/{userId}/FavoriteItems/{itemId}`（带 userId）
   - Emby 服务器对两种方式都支持，但带 userId 更符合多用户场景
   - 需要修改 `markAsPlayed()`/`markAsUnplayed()` 或新增专门的收藏方法

---

## ADDED Requirements

### Requirement: 媒体库完整显示

系统 SHALL 使用用户视角 API 获取媒体库列表，确保显示用户有权限访问的全部媒体库。

#### Scenario: 获取用户可访问的媒体库
- **WHEN** 用户登录后打开媒体库选择界面
- **THEN** 显示该用户有权限访问的所有媒体库（电影、剧集、音乐等）
- **AND** 不显示用户无权访问的库

#### Scenario: 媒体库切换
- **WHEN** 用户在媒体库选择器中选择某个库
- **THEN** 该库的视频列表只包含该用户有权限访问的内容

### Requirement: 点赞/收藏功能

系统 SHALL 提供完整的点赞/收藏功能，允许用户收藏和取消收藏媒体内容。

#### Scenario: 点赞视频
- **WHEN** 用户点击点赞按钮或双击视频
- **THEN** 调用 Emby 收藏 API 将该项目添加到用户收藏
- **AND** UI 立即更新为已点赞状态（乐观更新）

#### Scenario: 取消点赞
- **WHEN** 用户再次点击已点赞的项目
- **THEN** 调用 Emby 取消收藏 API
- **AND** UI 立即更新为未点赞状态

---

## MODIFIED Requirements

### Requirement: getLibraries 方法

`embbytok_service.dart` 中的 `getLibraries` 方法 SHALL 使用 `/Users/{userId}/Views` 端点获取媒体库列表。

#### Scenario: 获取媒体库列表
- **WHEN** 调用 `getLibraries(userId: 'xxx')`
- **THEN** 发送请求到 `/Users/{userId}/Views`
- **AND** 返回该用户可访问的媒体库列表

### Requirement: 收藏 API 方法

`embbytok_service.dart` 中的收藏相关方法 SHALL 使用 `/Users/{userId}/FavoriteItems/{itemId}` 端点。

#### Scenario: 添加收藏
- **WHEN** 调用 `markAsPlayed(itemId)` 或新增 `addToFavorites(itemId)`
- **THEN** 发送 `POST /Users/{userId}/FavoriteItems/{itemId}`

#### Scenario: 取消收藏
- **WHEN** 调用 `markAsUnplayed(itemId)` 或新增 `removeFromFavorites(itemId)`
- **THEN** 发送 `DELETE /Users/{userId}/FavoriteItems/{itemId}`

---

## REMOVED Requirements

### Requirement: 旧版收藏 API

**Reason**: `/UserFavoriteItems/{itemId}` 不带 userId，在多用户场景下可能导致数据混乱
**Migration**: 替换为 `/Users/{userId}/FavoriteItems/{itemId}`

### Requirement: 旧版媒体库 API

**Reason**: `/Library/VirtualFolders` 返回管理员视角的库列表，可能包含用户无权访问的库
**Migration**: 替换为 `/Users/{userId}/Views`

---

## 约束

- 不破坏现有的视频播放、续播、NextUp 等功能
- 保持与现有代码风格一致
- 不引入新的第三方依赖
- 确保 flutter analyze 无 error

## 验收标准

### AC-1: 媒体库完整显示
- **Given** 用户已登录
- **When** 打开媒体库选择器
- **Then** 显示用户有权限访问的全部媒体库

### AC-2: 点赞功能正常
- **Given** 用户已登录
- **When** 点击点赞按钮
- **Then** 视频被添加到 Emby 收藏
- **And** 点赞状态正确显示

### AC-3: 取消点赞正常
- **Given** 用户已登录且视频已被点赞
- **When** 再次点击点赞按钮
- **Then** 视频从 Emby 收藏中移除
- **And** 点赞状态正确更新

### AC-4: 多用户数据隔离
- **Given** 两个不同用户 A 和 B
- **When** 用户 A 点赞某视频
- **Then** 用户 B 的收藏中不包含该视频
