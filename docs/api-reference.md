# EmbyTok - 后端 API 参考

> 本文件目标：为开发者提供后端 FastAPI 服务的完整 API 参考，包括每个接口的请求和响应格式、错误码及使用示例。

**相关源码**：
- [backend/routers/auth.py](../backend/routers/auth.py) — 认证路由
- [backend/routers/libraries.py](../backend/routers/libraries.py) — 媒体库路由
- [backend/routers/items.py](../backend/routers/items.py) — 媒体项 / 播放 / 进度路由
- [backend/routers/search.py](../backend/routers/search.py) — 搜索路由
- [backend/routers/favorites.py](../backend/routers/favorites.py) — 收藏路由
- [backend/routers/subtitles.py](../backend/routers/subtitles.py) — 字幕路由
- [backend/models/base_models.py](../backend/models/base_models.py) — Pydantic 数据模型
- [backend/clients/emby_client.py](../backend/clients/emby_client.py) — Emby HTTP 客户端

---

## 一、通用约定

### 1.1 Base URL

假设后端服务运行在 `http://192.168.1.6:8000`，所有 API 路径相对该地址。

### 1.2 认证方式

除了 `/`、`/health` 和 `/api/auth/login` 外，**所有需要鉴权的接口**必须在请求中携带 Emby 服务器地址和 Token。

有两种方式传递认证信息：

**方式 A（推荐，Flutter 应用使用）**：通过 HTTP Header

```
X-Emby-Server-Url: http://192.168.1.6:8010
X-Emby-Token: abcdef123456...
X-Emby-User-Id: user123
```

**方式 B（调试用）**：通过查询参数

```
?emby_server_url=http://192.168.1.6:8010&emby_token=abcdef...&user_id=user123
```

### 1.3 响应格式

成功响应返回 HTTP 200，Body 为 JSON 对象或数组。

错误响应统一格式：

```json
{
  "error": true,
  "status_code": 401,
  "message": "用户名或密码无效"
}
```

常见错误码：

| HTTP 状态码 | 含义 | 典型场景 |
|------------|------|---------|
| 400 | 错误请求 | 参数缺失 / 无效 |
| 401 | 未授权 | Token 无效 / 过期 |
| 404 | 资源不存在 | 请求的媒体项 ID 不存在 |
| 502 | 网关错误 | 无法连接到 Emby 服务器 |
| 500 | 服务器内部错误 | 非预期的异常 |

### 1.4 在线 Swagger 文档

后端服务启动后，可直接访问 Swagger UI：

```
http://192.168.1.6:8000/docs
```

或 OpenAPI JSON：

```
http://192.168.1.6:8000/openapi.json
```

---

## 二、根路由（健康检查）

### 2.1 GET /

获取后端服务的基本信息。

**请求**：无参数

**响应 (200 OK)**：

```json
{
  "message": "EmbyTok API - Use /docs for Swagger UI",
  "version": "1.0.0"
}
```

---

### 2.2 GET /health

健康检查端点。

**请求**：无参数

**响应 (200 OK)**：

```json
{
  "status": "ok",
  "version": "1.0.0",
  "service": "embbytok-backend"
}
```

---

## 三、认证 API

### 3.1 POST /api/auth/login

使用用户名和密码登录 Emby 服务器，返回访问令牌和用户信息。

**请求体**：

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `emby_url` | string | ✅ | Emby 服务器地址，如 `http://192.168.1.6:8010` |
| `username` | string | ✅ | Emby 用户名 |
| `password` | string | ✅ | Emby 登录密码 |

```json
{
  "emby_url": "http://192.168.1.6:8010",
  "username": "FK",
  "password": "your-password-here"
}
```

**响应 (200 OK)**：

| 字段 | 类型 | 说明 |
|------|------|------|
| `access_token` | string | Emby 访问令牌，后续请求需携带 |
| `user_id` | string | 用户唯一 ID |
| `username` | string | 用户名 |
| `server_id` | string 或 null | Emby 服务器 ID |

```json
{
  "access_token": "abcdef1234567890abcdef",
  "user_id": "0001-user-uuid",
  "username": "FK",
  "server_id": "server-uuid-1234"
}
```

**错误响应**：

- `400` — `emby_url` 为空
- `401` — 用户名或密码无效
- `502` — 无法连接到 Emby 服务器

**源码参考**：[backend/routers/auth.py](../backend/routers/auth.py)

---

## 四、媒体库 API

### 4.1 GET /api/libraries

获取当前用户可见的所有虚拟媒体库。

**请求**：
- 需要认证 Header（见 1.2 节）

**响应 (200 OK)**：

```json
[
  {
    "id": "library-id-1",
    "name": "电影",
    "type": "Movies",
    "item_count": 128,
    "cover_image_url": "http://192.168.1.6:8010/..."
  },
  {
    "id": "library-id-2",
    "name": "电视剧",
    "type": "Series",
    "item_count": 256,
    "cover_image_url": "http://192.168.1.6:8010/..."
  }
]
```

**字段说明**：

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | string | 媒体库唯一 ID |
| `name` | string | 媒体库名称 |
| `type` | string | 媒体库类型（Movies / Series / Music 等） |
| `item_count` | number 或 null | 媒体项数量 |
| `cover_image_url` | string 或 null | 封面图 URL |

---

### 4.2 GET /api/libraries/{library_id}/items

按分页返回指定媒体库下的媒体项。

**路径参数**：

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `library_id` | string | ✅ | 媒体库 ID |

**查询参数**：

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `limit` | int | 20 | 每页条数 |
| `offset` | int | 0 | 起始偏移量 |
| `sort` | string | "SortName" | 排序字段 |

**响应 (200 OK)**：

```json
{
  "items": [
    {
      "id": "media-id-1",
      "title": "肖申克的救赎",
      "type": "Movie",
      "duration_seconds": 8520,
      "thumbnail_url": "http://192.168.1.6:8010/...",
      "overview": "一个银行家被冤枉谋杀妻子...",
      "year": 1994,
      "rating": 9.3,
      "genres": ["剧情", "犯罪"],
      "playback_url": null
    }
  ],
  "total": 128,
  "offset": 0,
  "limit": 20
}
```

**源码参考**：[backend/routers/libraries.py](../backend/routers/libraries.py)

---

## 五、媒体项 API

### 5.1 GET /api/items/{item_id}

获取单个媒体项的完整信息。

**路径参数**：

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `item_id` | string | ✅ | 媒体项 ID |

**响应 (200 OK)**：

```json
{
  "id": "media-id-1",
  "title": "肖申克的救赎",
  "type": "Movie",
  "duration_seconds": 8520,
  "thumbnail_url": "http://192.168.1.6:8010/...",
  "overview": "一个银行家被冤枉谋杀妻子...",
  "year": 1994,
  "rating": 9.3,
  "genres": ["剧情", "犯罪"],
  "playback_url": null
}
```

**错误响应**：

- `404` — 未找到指定的媒体项

---

### 5.2 GET /api/items/{item_id}/playback

获取指定媒体项的直链播放地址。

**响应 (200 OK)**：

```json
{
  "item_id": "media-id-1",
  "playback_url": "http://192.168.1.6:8010/Items/media-id-1/Download?api_key=xxx",
  "format": "direct",
  "protocol": "http"
}
```

**字段说明**：

| 字段 | 类型 | 说明 |
|------|------|------|
| `item_id` | string | 媒体项 ID |
| `playback_url` | string | 可直接播放的视频文件 URL（直链下载） |
| `format` | string | 播放格式（`direct` / `transcode`） |
| `protocol` | string | 传输协议（`http` / `hls`） |

---

### 5.3 POST /api/items/{item_id}/progress

上报/保存当前播放进度。

**请求体**：

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `position_seconds` | number | ✅ | 当前播放时间（秒），不能为负 |

```json
{
  "position_seconds": 1234.5
}
```

**响应 (200 OK)**：

```json
{
  "ok": true
}
```

---

### 5.4 GET /api/items/{item_id}/progress

获取上次保存的播放进度。

**响应 (200 OK)**：

```json
{
  "position_seconds": 1234.5
}
```

如果从未上报过进度，返回 `{"position_seconds": 0.0}`。

---

### 5.5 GET /api/items/{item_id}/subtitles

获取指定媒体项的所有可用字幕轨道。

**响应 (200 OK)**：

```json
[
  {
    "id": "subtrack-1",
    "name": "简体中文",
    "language": "chi",
    "format": "srt",
    "url": "http://192.168.1.6:8010/..."
  },
  {
    "id": "subtrack-2",
    "name": "English",
    "language": "eng",
    "format": "srt",
    "url": "http://192.168.1.6:8010/..."
  }
]
```

**字段说明**：

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | string | 字幕轨道 ID |
| `name` | string | 字幕显示名称 |
| `language` | string | 语言代码（ISO 639-2 三位，如 `chi` / `eng`） |
| `format` | string | 字幕文件格式（`srt` / `vtt` / `ass` 等） |
| `url` | string 或 null | 字幕文件下载地址 |

**源码参考**：[backend/routers/items.py](../backend/routers/items.py)、[backend/routers/subtitles.py](../backend/routers/subtitles.py)

---

## 六、搜索 API

### 6.1 GET /api/search

通过查询字符串简单搜索媒体项。

**查询参数**：

| 参数 | 类型 | 默认值 | 必填 | 说明 |
|------|------|--------|------|------|
| `q` | string | — | ✅ | 搜索关键字 |
| `limit` | int | 20 | 否 | 每页条数 |
| `offset` | int | 0 | 否 | 起始偏移 |

**示例**：

```
GET /api/search?q=肖申克&limit=10
```

**响应 (200 OK)**：

分页格式同 4.2 节：

```json
{
  "items": [
    {
      "id": "media-id-1",
      "title": "肖申克的救赎",
      "type": "Movie",
      "duration_seconds": 8520,
      "thumbnail_url": "http://192.168.1.6:8010/...",
      "overview": "一个银行家被冤枉谋杀妻子...",
      "year": 1994,
      "rating": 9.3,
      "genres": ["剧情", "犯罪"]
    }
  ],
  "total": 3,
  "offset": 0,
  "limit": 10
}
```

---

### 6.2 POST /api/search

通过请求体搜索，支持更复杂的参数。

**请求体**：

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `query` | string | ✅ | 搜索关键字 |
| `limit` | int | 否 | 每页条数（默认 20） |
| `offset` | int | 否 | 起始偏移（默认 0） |
| `types` | string[] 或 null | 否 | 媒体类型过滤 |

```json
{
  "query": "肖申克",
  "limit": 10,
  "offset": 0,
  "types": ["Movie", "Episode"]
}
```

**响应**：格式同 6.1

**源码参考**：[backend/routers/search.py](../backend/routers/search.py)

---

## 七、收藏 API

### 7.1 GET /api/favorites

获取当前用户的所有收藏媒体项。

**请求**：需要认证 Header

**响应 (200 OK)**：

```json
[
  {
    "id": "media-id-1",
    "title": "肖申克的救赎",
    "type": "Movie",
    "duration_seconds": 8520,
    "thumbnail_url": "http://192.168.1.6:8010/...",
    "overview": "一个银行家被冤枉谋杀妻子...",
    "year": 1994,
    "rating": 9.3,
    "genres": ["剧情", "犯罪"]
  }
]
```

---

### 7.2 POST /api/favorites/{item_id}

将指定媒体项添加到当前用户的收藏列表。

**响应 (200 OK)**：

```json
{
  "ok": true
}
```

---

### 7.3 DELETE /api/favorites/{item_id}

将指定媒体项从当前用户的收藏列表中移除。

**响应 (200 OK)**：

```json
{
  "ok": true
}
```

**源码参考**：[backend/routers/favorites.py](../backend/routers/favorites.py)

---

## 八、数据模型速查

以下是所有 API 中使用的核心 Pydantic 模型的字段摘要。完整定义见 [backend/models/base_models.py](../backend/models/base_models.py)。

### AuthRequest

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `emby_url` | string | ✅ | Emby 服务器地址 |
| `username` | string | ✅ | 用户名 |
| `password` | string | ✅ | 密码 |

### AuthResponse

| 字段 | 类型 | 说明 |
|------|------|------|
| `access_token` | string | Emby 访问令牌 |
| `user_id` | string | 用户 ID |
| `username` | string | 用户名 |
| `server_id` | string 或 null | 服务器 ID |

### Library

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | string | 媒体库 ID |
| `name` | string | 媒体库名称 |
| `type` | string | 类型（Movies / Series / Music 等） |
| `item_count` | int 或 null | 媒体项数量 |
| `cover_image_url` | string 或 null | 封面图 URL |

### MediaItem

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | string | 媒体项 ID |
| `title` | string | 标题 |
| `type` | string | 类型（Movie / Episode / Video 等） |
| `duration_seconds` | number 或 null | 时长（秒） |
| `thumbnail_url` | string 或 null | 缩略图 URL |
| `overview` | string 或 null | 简介 |
| `year` | int 或 null | 年份 |
| `rating` | number 或 null | 评分 |
| `genres` | string[] 或 null | 类型标签 |
| `playback_url` | string 或 null | 播放 URL |

### PlaybackInfo

| 字段 | 类型 | 说明 |
|------|------|------|
| `item_id` | string | 媒体项 ID |
| `playback_url` | string | 播放地址 |
| `format` | string | 播放格式（direct / transcode） |
| `protocol` | string | 传输协议（http / hls） |

### SubtitleTrack

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | string | 字幕轨道 ID |
| `name` | string | 字幕名称 |
| `language` | string | 语言代码 |
| `format` | string | 格式（srt / vtt / ass 等） |
| `url` | string 或 null | 字幕下载地址 |

### PaginatedResponse\<T\>

| 字段 | 类型 | 说明 |
|------|------|------|
| `items` | T[] | 当前页数据项列表 |
| `total` | int | 总条数 |
| `offset` | int | 起始偏移 |
| `limit` | int | 每页条数 |

---

## 九、用 curl 快速测试

以下是一组完整的测试命令，方便你在命令行验证 API：

```bash
# 1. 健康检查
curl http://192.168.1.6:8000/health

# 2. 登录（获取 Token）
curl -X POST http://192.168.1.6:8000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"emby_url":"http://192.168.1.6:8010","username":"FK","password":"你的密码"}'

# 假设登录返回的 access_token 是 abcdef...

# 3. 获取媒体库列表（通过 Header 传递认证信息）
curl "http://192.168.1.6:8000/api/libraries" \
  -H "X-Emby-Server-Url: http://192.168.1.6:8010" \
  -H "X-Emby-Token: abcdef..." \
  -H "X-Emby-User-Id: user-id-from-login"

# 4. 获取某个媒体库的视频列表
curl "http://192.168.1.6:8000/api/libraries/{library_id}/items?limit=5" \
  -H "X-Emby-Server-Url: http://192.168.1.6:8010" \
  -H "X-Emby-Token: abcdef..." \
  -H "X-Emby-User-Id: user-id-from-login"

# 5. 搜索
curl "http://192.168.1.6:8000/api/search?q=肖申克" \
  -H "X-Emby-Server-Url: http://192.168.1.6:8010" \
  -H "X-Emby-Token: abcdef..." \
  -H "X-Emby-User-Id: user-id-from-login"

# 6. 获取播放地址
curl "http://192.168.1.6:8000/api/items/{item_id}/playback" \
  -H "X-Emby-Server-Url: http://192.168.1.6:8010" \
  -H "X-Emby-Token: abcdef..." \
  -H "X-Emby-User-Id: user-id-from-login"

# 7. 保存播放进度
curl -X POST "http://192.168.1.6:8000/api/items/{item_id}/progress" \
  -H "X-Emby-Server-Url: http://192.168.1.6:8010" \
  -H "X-Emby-Token: abcdef..." \
  -H "X-Emby-User-Id: user-id-from-login" \
  -H "Content-Type: application/json" \
  -d '{"position_seconds": 1234.5}'

# 8. 获取收藏
curl "http://192.168.1.6:8000/api/favorites" \
  -H "X-Emby-Server-Url: http://192.168.1.6:8010" \
  -H "X-Emby-Token: abcdef..." \
  -H "X-Emby-User-Id: user-id-from-login"

# 9. 添加收藏
curl -X POST "http://192.168.1.6:8000/api/favorites/{item_id}" \
  -H "X-Emby-Server-Url: http://192.168.1.6:8010" \
  -H "X-Emby-Token: abcdef..." \
  -H "X-Emby-User-Id: user-id-from-login"

# 10. 取消收藏
curl -X DELETE "http://192.168.1.6:8000/api/favorites/{item_id}" \
  -H "X-Emby-Server-Url: http://192.168.1.6:8010" \
  -H "X-Emby-Token: abcdef..." \
  -H "X-Emby-User-Id: user-id-from-login"
```

---

## 十、架构设计说明

为什么需要一个中间层（FastAPI）而不是让 Flutter 直接请求 Emby？

| 考量 | 说明 |
|------|------|
| **统一 API** | Emby 的 REST API 较为复杂，中间层将其封装为简洁的 JSON API，符合现代前端习惯 |
| **Token 管理** | 集中管理 Emby Access Token 的传递方式（支持 Header 和 Query 参数两种形式） |
| **错误统一** | 所有后端错误统一格式化为 `{error, status_code, message}`，方便前端处理 |
| **数据适配** | 把 Emby 的 `AccessToken` / `User.Id` 等原始字段映射为统一的 `AuthResponse` |
| **未来扩展** | 未来支持 Plex 时，只需在后端新增一个 Plex 客户端，前端 API 保持不变 |

---

*文档版本：v1.0 | 最后更新：2026-06-12 | 对应项目版本：EmbyTok-Flutter v1.0.x*
