# EmbyX 服务器对接方式规范

## Why

当前 EmbyTok 项目需要优化与 Emby/Jellyfin 服务器的对接方式，参考 EmbyX 项目的成功实现。EmbyX 是一个成熟的 TikTok 风格 Emby/Jellyfin 播放器，其服务器对接方式经过验证稳定可靠。

## What Changes

- 采用 EmbyX 的标准 API 对接方式
- 统一媒体库获取、媒体列表、视频播放、图片获取等接口
- 添加会话能力上报，提升 Direct Play 兼容性
- 简化视频流 URL 构建逻辑

## Impact

- Affected specs: 媒体服务层、认证模块、视频播放模块
- Affected code:
  - `frontend/lib/services/embbytok_service.dart`
  - `frontend/lib/services/api_client.dart`
  - `frontend/lib/providers/auth_provider.dart`

---

## EmbyX API 对接方式

### 1. 认证流程

**端点**：`POST /emby/Users/AuthenticateByName`

**请求体**：
```json
{
  "Username": "用户名",
  "Pw": "密码"
}
```

**响应**：
```json
{
  "User": {
    "Id": "用户ID",
    "Name": "用户名"
  },
  "AccessToken": "令牌",
  "SessionInfo": {
    "UserId": "用户ID"
  }
}
```

**关键点**：
- 密码字段名为 `Pw`（非 `Password`）
- 返回的 `AccessToken` 作为后续所有请求的 `api_key`
- 用户信息在 `User` 字段中，用户 ID 在 `SessionInfo.UserId`

### 2. 媒体库列表

**端点**：`GET /emby/Users/{userId}/Views`

**参数**：无（使用 `api_key` 认证）

**响应结构**：
```json
{
  "Items": [
    {
      "Id": "媒体库ID",
      "Name": "媒体库名称",
      "CollectionType": "movies|tvshows|musicvideos..."
    }
  ]
}
```

**关键点**：
- 返回用户可访问的所有媒体库
- `CollectionType` 区分类型：`movies`、`tvshows`、`musicvideos`、`homevideos`、`playlists`

### 3. 媒体列表获取

**端点**：`GET /emby/Users/{userId}/Items`

**参数**：
| 参数 | 值 | 说明 |
|------|-----|------|
| `api_key` | 令牌 | 认证 |
| `Recursive` | `true` | 递归获取所有子项 |
| `IncludeItemTypes` | `Movie,Episode,Video,MusicVideo` | 包含类型 |
| `Limit` | 数字 | 每页数量 |
| `StartIndex` | 数字 | 偏移量 |
| `Fields` | `Overview,Path,RunTimeTicks,MediaSources` | 返回字段 |
| `ParentId` | ID | 限定父级（可选） |
| `Filters` | `IsFavorite` | 仅收藏（可选） |
| `SortBy` | `DateCreated,SortName` | 排序（可选） |
| `SortOrder` | `Descending` | 降序（可选） |

### 4. 视频流播放

**直接流（推荐）**：
```
GET /emby/Videos/{itemId}/stream.mp4?api_key={token}&DeviceId={deviceId}&VideoCodec=h264,hevc,av1&AudioCodec=aac,mp3,ac3&AllowVideoStreamCopy=true&AllowAudioStreamCopy=true
```

**HLS 流（备选）**：
```
GET /emby/Videos/{itemId}/master.m3u8?api_key={token}&DeviceId={deviceId}&...
```

**参数说明**：
| 参数 | 说明 |
|------|------|
| `VideoCodec` | 支持的编码：`h264`, `hevc`, `av1` |
| `AudioCodec` | 支持的音频：`aac`, `mp3`, `ac3` |
| `AllowVideoStreamCopy` | `true` 允许直接复制（节省转码） |
| `AllowAudioStreamCopy` | `true` 允许音频直接复制 |
| `DeviceId` | 设备标识，用于 Emby 识别设备 |

### 5. 图片获取

**海报图**：
```
GET /emby/Items/{itemId}/Images/Primary?api_key={token}
```

**背景图**：
```
GET /emby/Items/{itemId}/Images/Backdrop?api_key={token}
```

**缩略图**：
```
GET /emby/Items/{itemId}/Images/Thumb?api_key={token}
```

### 6. 收藏管理

**添加收藏**：
```
POST /emby/Users/{userId}/FavoriteItems/{itemId}
```

**取消收藏**：
```
DELETE /emby/Users/{userId}/FavoriteItems/{itemId}
```

### 7. 播放进度上报

**播放进度**：
```
POST /emby/Sessions/Playing/Progress
Content-Type: application/json

{
  "ItemId": "视频ID",
  "PositionTicks": 123456789,  // 100ns 为单位
  "MediaSourceId": "媒体源ID",   // 可选
  "PlaySessionId": "会话ID"     // 可选
}
```

**播放停止**：
```
POST /emby/Sessions/Playing/Stopped
```

### 8. 会话能力上报

**端点**：`POST /emby/Sessions/Capabilities/Full`

**作用**：告知 Emby 服务器客户端支持的解码能力，提升 Direct Play 兼容性

**请求体**：
```json
{
  "PlayableMediaTypes": ["Video", "Audio"],
  "SupportedCommands": ["Play", "Pause", "Seek", "SetVolume"],
  "SupportsMediaControl": true,
  "DeviceProfile": {
    "Name": "EmbyX",
    "Id": "设备ID"
  }
}
```

---

## 当前 EmbyTok 实现对比

### ✅ 已对齐的功能

| 功能 | EmbyTok | EmbyX |
|------|---------|-------|
| 认证 | `/Users/AuthenticateByName` | ✅ 相同 |
| Token | `AccessToken` 作为 `api_key` | ✅ 相同 |
| 收藏管理 | `POST/DELETE /UserFavoriteItems/{id}` | ✅ 相同 |
| 播放进度 | `/Sessions/Playing/Progress` | ✅ 相同 |
| 图片获取 | `/Items/{id}/Images/Primary` | ✅ 相同 |

### ⚠️ 需要改进的功能

| 功能 | EmbyTok 当前实现 | EmbyX 实现 | 改进点 |
|------|-----------------|------------|--------|
| 媒体库列表 | `/Library/VirtualFolders` | `/Users/{userId}/Views` | 使用用户视角的 Views |
| 视频流参数 | 缺少 `VideoCodec`, `AudioCodec` | 完整参数列表 | 添加编解码器参数 |
| 会话能力 | ❌ 未实现 | `/Sessions/Capabilities/Full` | 添加能力上报 |

---

## 改进要求

### MODIFIED Requirements

### Requirement: 媒体库列表获取

**当前实现**：
```dart
GET /Library/VirtualFolders
```

**应修改为**：
```dart
GET /Users/{userId}/Views
```

**原因**：`/Users/{userId}/Views` 返回的是用户实际可访问的媒体库列表，包含用户创建的智能列表和播放列表

### Requirement: 视频流 URL 构建

**应支持完整的 Direct Play 参数**：
```dart
String buildStreamUrl(String itemId) {
  final params = {
    'api_key': token,
    'DeviceId': deviceId,
    'VideoCodec': 'h264,hevc,av1',
    'AudioCodec': 'aac,mp3,ac3',
    'AllowVideoStreamCopy': 'true',
    'AllowAudioStreamCopy': 'true',
  };
  return '$serverUrl/emby/Videos/$itemId/stream.mp4?${Uri(queryParameters: params).query}';
}
```

### Requirement: 会话能力上报

**新增功能**：在首次播放前上报客户端能力

```dart
Future<void> reportCapabilities() async {
  await _apiClient.post('/Sessions/Capabilities/Full', data: {
    'PlayableMediaTypes': ['Video', 'Audio'],
    'SupportedCommands': ['Play', 'Pause', 'Seek', 'SetVolume'],
    'SupportsMediaControl': true,
  });
}
```

---

## 文件变更清单

| 文件 | 变更类型 | 说明 |
|------|---------|------|
| `frontend/lib/services/embbytok_service.dart` | MODIFY | 更新 `getLibraries` 使用 Views API，添加 `reportCapabilities` |
| `frontend/lib/services/api_client.dart` | MODIFY | 支持 `DeviceId` 配置 |
| `frontend/lib/models/library.dart` | MODIFY | 支持 `CollectionType` 字段 |
| `frontend/lib/providers/video_playback_controller.dart` | ADD | 添加视频流 URL 构建逻辑 |
