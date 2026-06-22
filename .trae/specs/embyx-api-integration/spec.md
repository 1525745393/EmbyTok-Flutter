# EmbyX Emby 对接方法分析与借鉴 Spec

## Why
EmbyTok 当前的 Emby API 对接存在几个关键缺失：仅支持直接播放（Direct Play）不支持转码降级、未上报播放能力（Capabilities）、未实现续播云同步、收藏 API 端点与 EmbyX 不同。分析 EmbyX 的对接方法可以补齐这些短板。

## What Changes
- 借鉴 EmbyX 的**多级播放降级链**（Direct Play → Direct Stream → HLS 转码）
- 借鉴 EmbyX 的**完整播放上报**（Capabilities + Playing + Progress + Stopped）
- 借鉴 EmbyX 的**续播云同步**（DisplayPreferences 方案）
- 借鉴 EmbyX 的**收藏 API 端点**（`/Users/{userId}/FavoriteItems/{id}`）
- 借鉴 EmbyX 的**媒体库列表获取**（`/Users/{userId}/Views` 替代 `/Library/VirtualFolders`）
- 借鉴 EmbyX 的**视频列表 Fields 参数**（增加 `MediaSources` 字段）

## Impact
- Affected code: `frontend/lib/services/embbytok_service.dart`、`frontend/lib/models/media_item.dart`、`frontend/lib/widgets/video_player_widget.dart`、`backend/clients/emby_client.py`

## EmbyX Emby API 对接方法详解

### 1. 认证方式

EmbyX 使用用户名密码登录获取 Token，与 EmbyTok 相同：

```
POST /emby/Users/AuthenticateByName
Headers:
  Content-Type: application/json
  X-Emby-Authorization: Emby Client="EmbyX", Device="{deviceName}", DeviceId="{deviceId}", Version="{appVersion}"
Body: { "Username": "user", "Pw": "pwd" }
```

**差异**：EmbyX 的 `X-Emby-Authorization` 头在登录后追加 `, Token="{token}"`，EmbyTok 使用单独的 `X-Emby-Token` 头。两种方式都被 Emby 支持。

### 2. 媒体库列表

EmbyX 使用 `/Users/{userId}/Views` 获取用户可见的媒体库视图：

```
GET /emby/Users/{userId}/Views?api_key={token}
Headers:
  X-Emby-Authorization: Emby Client="EmbyX", ..., Token="{token}"
```

**差异**：EmbyTok 使用 `/Library/VirtualFolders`（管理员视角），EmbyX 使用 `/Users/{userId}/Views`（用户视角，更准确）。

EmbyX 还获取播放列表：`GET /emby/Users/{userId}/Items?Recursive=true&IncludeItemTypes=Playlist&api_key={token}`

### 3. 视频列表

EmbyX 使用 `/Users/{userId}/Items` 获取视频列表：

```
GET /emby/Users/{userId}/Items?api_key={token}&Recursive=true
  &IncludeItemTypes=Movie,Episode,Video,MusicVideo
  &Limit=150&StartIndex={offset}
  &Fields=Overview,Path,RunTimeTicks,MediaSources
  &SortBy=DateCreated&SortOrder=Descending
  &ParentId={libraryId}  (可选)
  &Filters=IsFavorite    (收藏模式)
  &SortBy=Random         (随机模式)
```

**关键差异**：
- EmbyX 使用 `/Users/{userId}/Items`（带 userId），EmbyTok 使用 `/Items`（不带 userId）
- EmbyX 的 Fields 包含 `Path` 和 `MediaSources`，EmbyTok 缺少这两个字段
- `MediaSources` 字段是播放降级链的关键依赖（获取编码、容器、MediaSourceId）

### 4. 视频播放 URL 构造（三级降级链）

EmbyX 实现了智能播放降级链，这是最核心的借鉴点：

**Level 1: Direct Play（直接播放）**
```
GET /emby/Videos/{itemId}/stream?Static=true&api_key={token}
  &MediaSourceId={msId}&DeviceId={deviceId}&PlaySessionId={playSessionId}
```

**Level 2: Direct Stream（直接串流，Remux 不重编码）**
```
GET /emby/Videos/{itemId}/stream.mp4?api_key={token}
  &DeviceId={deviceId}
  &VideoCodec=h264,hevc,hevc,av1
  &AudioCodec=aac,mp3,ac3
  &AllowVideoStreamCopy=true
  &AllowAudioStreamCopy=true
```

**Level 3: HLS 转码**
```
GET /emby/Videos/{itemId}/master.m3u8?api_key={token}
  &MediaSourceId={msId}&DeviceId={deviceId}&PlaySessionId={playSessionId}
  &VideoCodec=h264&AudioCodec=aac,mp3,ac3
  &VideoBitrate=20000000&AudioBitrate=320000
  &TranscodingMaxAudioChannels=2
  &SegmentContainer=ts&MinSegments=1&BreakOnNonKeyFrames=True
  &AllowVideoStreamCopy=true&AllowAudioStreamCopy=true
```

**智能判定逻辑**：
- h264 + mp4 → 直接 Direct Play（原生兼容）
- iOS + hevc + hev1 标签 → Direct Stream（Remux hev1→hvc1）
- 其他 → Direct Play，失败后降级

**STRM 直播流特殊处理**：
- 检测 `.strm` 文件或 `Path.startsWith('http')`
- FLV 流使用 mpegts.js 直连
- HLS 流使用 hls.js 直连
- 绕过 Emby 服务器中转，直接播放原始 URL

**差异**：EmbyTok 仅实现了 Level 1（Direct Play），无降级链。

### 5. 图片 URL

```
GET /emby/Items/{itemId}/Images/Primary?api_key={token}
```

**差异**：EmbyX 不传 `MaxWidth` 和 `Tag` 参数，EmbyTok 传了。EmbyTok 的方式更优（支持缓存和尺寸控制）。

### 6. 收藏 API

EmbyX 使用带 userId 的端点：
```
收藏:   POST   /emby/Users/{userId}/FavoriteItems/{itemId}?api_key={token}
取消:   DELETE /emby/Users/{userId}/FavoriteItems/{itemId}?api_key={token}
```

**差异**：EmbyTok 使用 `/UserFavoriteItems/{itemId}`（不带 userId），EmbyX 使用 `/Users/{userId}/FavoriteItems/{itemId}`（带 userId）。两种方式 Emby 都支持。

EmbyX 还实现了**乐观更新**：先修改内存和 UI，远端失败再回滚。

### 7. 播放进度上报

EmbyX 实现了完整的播放上报链：

**Step 1: 上报播放能力**
```
POST /emby/Sessions/Capabilities/Full?api_key={token}
Body: {
  "PlayableMediaTypes": ["Video"],
  "SupportsMediaControl": true,
  "SupportsPersistentConnections": false
}
```

**Step 2: 上报播放开始/进度/停止**
```
POST /emby/Sessions/Playing           (开始)
POST /emby/Sessions/Playing/Progress  (进度，每5秒)
POST /emby/Sessions/Playing/Stopped   (停止)
Body: {
  "ItemId": "{itemId}",
  "PositionTicks": {currentTime * 10000000},
  "IsPaused": {bool},
  "IsMuted": {bool},
  "VolumeLevel": {0-100},
  "PlayMethod": "DirectPlay" | "Transcode",
  "EventName": "TimeUpdate" | "Pause" | "Stopped",
  "CanSeek": true,
  "PlaySessionId": "{sessionId}",
  "QueueableMediaTypes": ["Video"],
  "MediaSourceId": "{msId}"
}
```

**差异**：
- EmbyTok 未上报 `Sessions/Capabilities/Full`
- EmbyTok 未上报 `Sessions/Playing`（开始）
- EmbyTok 的 Progress 上报缺少 `IsPaused`、`IsMuted`、`VolumeLevel`、`PlayMethod`、`EventName`、`CanSeek`、`QueueableMediaTypes` 字段
- EmbyX 的 `PositionTicks` 计算方式：`Math.floor(currentTime * 10000000)`

### 8. 续播云同步

EmbyX 使用 `DisplayPreferences` 实现跨设备续播同步：

```
POST /emby/DisplayPreferences/EmbyX-Resume-Drama?userId={userId}&api_key={token}
Body: {
  "Id": "EmbyX-Resume-Drama",
  "CustomPrefs": {
    "lastId": "{itemId}",
    "libId": "{libraryId}",
    "libType": "{libraryType}",
    "date": "{timestamp}",
    "deviceName": "{deviceName}"
  }
}
```

**差异**：EmbyTok 未实现续播云同步。

### 9. 删除视频

```
DELETE /emby/Items/{itemId}?api_key={token}
```

**差异**：EmbyTok 未实现删除功能。EmbyX 实现了权限检查（403 提示管理员权限）。

## ADDED Requirements

### Requirement: 多级播放降级链
系统 SHALL 提供三级播放降级链：Direct Play → Direct Stream → HLS 转码。当 Direct Play 失败时自动降级。

#### Scenario: Direct Play 失败降级
- **WHEN** Direct Play 播放失败（error 事件）
- **THEN** 自动切换到 Direct Stream（stream.mp4 + AllowVideoStreamCopy）
- **WHEN** Direct Stream 也失败
- **THEN** 自动切换到 HLS 转码（master.m3u8）

### Requirement: 完整播放上报
系统 SHALL 上报完整的播放状态：Capabilities + Playing + Progress + Stopped。

#### Scenario: 播放开始
- **WHEN** 视频开始播放
- **THEN** 先上报 Capabilities，再上报 Sessions/Playing

### Requirement: 续播云同步
系统 SHALL 使用 DisplayPreferences 实现跨设备续播同步。

## MODIFIED Requirements

### Requirement: 视频列表获取
视频列表 Fields 参数 SHALL 包含 `MediaSources` 和 `Path` 字段，以支持播放降级链的编码判定。
