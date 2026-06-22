# EmbyTok × Emby 服务器 API 对接规范 —— 产品需求文档（Spec）

## 1. 背景与现状

EmbyTok 是一个竖屏视频浏览客户端，核心通过 Emby 官方 REST API 与
Emby 服务器对接。本项目同时存在两套路径：

- **前端直连路径**（主路径）：Flutter 前端的 `embbytok_service.dart`
  直接调用 Emby 原生 API（`/Users/AuthenticateByName`、`/Items`、
  `/Videos/{id}/stream` 等）。
- **后端代理路径**（兼容路径）：Python FastAPI `backend/clients/
  emby_client.py` 作为反向代理，用于早期 demo / 搜索兼容场景。

本 Spec 以 **前端直连路径** 为基准，明确 Emby API 对接的完整规范、
与参考实现 [EmbyX](https://github.com/juneix/EmbyX) 的对齐点，
以及当前实现中尚未拉通的能力缺口（"TODO"）。

---

## 2. 术语与核心模型

- **AccessToken**：Emby 登录接口返回的会话令牌，作为后续请求的
  鉴权凭证（query 参数 `api_key` 或 header `X-Emby-Token`）。
- **UserId**：Emby 登录用户在该服务器上的唯一 ID，用于"用户视角"
  的媒体库、收藏、用户数据（UserData）等端点。
- **MediaSources**：媒体项的可用播放源数组（容器 / 编码 /
  MediaSourceId / 直链路径等），是播放降级链与编码判定的基础。
- **UserData**：用户对媒体项的私有数据（`PlaybackPositionTicks` /
  `Played` / `IsFavorite` / `PlayCount`），用于续播与收藏状态。
- **播放降级链（Fallback Chain）**：按优先级依次尝试
  `Direct Play → Direct Stream → HLS 转码` 的播放 URL 序列。
- **DisplayPreferences**：Emby 提供的 key-value 存储端点，用于
  跨设备同步任意用户配置（EmbyX 用它实现跨设备续播书签）。

---

## 3. 能力矩阵（功能要求 FR）

| # | 能力 | 说明 | 状态 |
|---|------|------|------|
| FR-1 | 用户名密码登录 | `POST /Users/AuthenticateByName` 获取 AccessToken 与 UserId | ✅ 已实现 |
| FR-2 | 用户视角媒体库 | `GET /Users/{userId}/Views`（管理员兼容 `/Library/VirtualFolders`） | ✅ 已实现 |
| FR-3 | 媒体库视频分页 | `GET /Items` 带 `ParentId`、`Recursive=true`、分页参数 | ✅ 已实现 |
| FR-4 | 媒体项详情 | `GET /Items/{itemId}` 带完整 Fields（含 MediaSources） | ✅ 已实现 |
| FR-5 | 直接播放（Direct Play） | `GET /Videos/{itemId}/stream?Static=true` | ✅ 已实现 |
| FR-6 | 直接串流（Direct Stream） | `GET /Videos/{itemId}/stream.mp4`，Remux 不重编码 | ✅ 服务层已实现 |
| FR-7 | HLS 转码 | `GET /Videos/{itemId}/master.m3u8`，带转码参数 | ✅ 服务层已实现 |
| FR-8 | 自动降级链 | Direct Play 失败时自动切到 Direct Stream / HLS | ⚠️ TODO：widget 层 error 监听未完整打通 |
| FR-9 | 播放能力上报 | `POST /Sessions/Capabilities/Full` | ⚠️ TODO：widget 层未调用 |
| FR-10 | 播放开始上报 | `POST /Sessions/Playing` | ⚠️ TODO：widget 层未调用 |
| FR-11 | 播放进度上报 | `POST /Sessions/Playing/Progress`，周期 + 字段完整 | ⚠️ TODO：widget 层未调用 |
| FR-12 | 播放停止上报 | `POST /Sessions/Playing/Stopped` | ⚠️ TODO：widget 层未调用 |
| FR-13 | 收藏切换 | `POST/DELETE /UserFavoriteItems/{itemId}`（或带 userId 变体） | ✅ 已实现（乐观更新） |
| FR-14 | 收藏列表 | `GET /Items?Filters=IsFavorite` | ✅ 已实现 |
| FR-15 | 标记已看 / 未看 | `POST/DELETE /UserPlayedItems/{itemId}` | ✅ 已实现 |
| FR-16 | 剧集季/集 | `GET /Shows/{id}/Seasons`、`/Episodes` | ✅ 已实现 |
| FR-17 | 搜索 | `GET /Items?SearchTerm=...` + `GET /Search/Hints` | ✅ 已实现 |
| FR-18 | 相似影片 | `GET /Items/{itemId}/Similar` | ✅ 已实现 |
| FR-19 | 人员与人员作品 | `GET /Persons` + `GET /Items?PersonIds=...` | ✅ 已实现 |
| FR-20 | 类型/工作室筛选 | `GET /Genres` / `GET /Studios` + 对应筛选 | ✅ 已实现 |
| FR-21 | 最近添加 / 继续观看 | `GET /Items/Latest` / `GET /Items/Resume` | ✅ 已实现 |
| FR-22 | 跨设备续播云同步 | `POST/GET /DisplayPreferences/EmbyTok-Resume?userId=...` | ⚠️ TODO：服务层方法已实现，widget 层未触发 |
| FR-23 | 图片 URL 构造 | `/Items/{id}/Images/{type}?MaxWidth=&Tag=&Format=jpg` | ✅ 已实现 |

---

## 4. 关键端点详细规范

### 4.1 认证

```
POST /emby/Users/AuthenticateByName
Headers:
  Content-Type: application/json
  X-Emby-Authorization: MediaBrowser Client="EmbyTok",
                        Device="{deviceName}",
                        DeviceId="{deviceId}",
                        Version="{appVersion}"
Body: { "Username": "...", "Pw": "..." }
```

- 响应：`{ User: { Id, Name, ... }, AccessToken: "..." }`
- 本地持久化：`embyServerUrl`、`apiKey(token)`、`userId` 三者必存。
- 后续请求统一通过 `ApiClient._defaultParams()` 挂 token。

### 4.2 媒体库（用户视角优先）

```
GET /emby/Users/{userId}/Views?api_key={token}
→ 返回 Items 数组，每个 Item: { Id, Name, CollectionType }
```

- 当 `userId` 不可用时（如管理员 token / 未登录场景），回退到
  `/Library/VirtualFolders`（admin 视角）。
- `CollectionType` 取值：`movies` / `tvshows` / `music` /
  `homevideos` / `books` / `mixed`。

### 4.3 视频列表（必须带 `MediaSources` / `Path`）

```
GET /emby/Items?api_key={token}
  &ParentId={libraryId}
  &Recursive=true
  &IncludeItemTypes=Movie,Episode,Video,MusicVideo
  &Fields=Overview,Genres,People,CommunityRating,RunTimeTicks,
          ProductionYear,ImageTags,UserData,MediaSources,Path
  &SortBy=DateCreated,SortName
  &SortOrder=Descending
  &Limit=20&StartIndex=0
```

- **必须**请求 `MediaSources` 字段，否则降级链无法判断编码。
- `Path` 用于识别 `.strm` 文件和远程 HTTP 源。

### 4.4 播放降级链

在 `MediaItem` 模型中提供三级 URL 构造方法，并在 widget 层
`_VideoPlayerWidgetState._initVideo` 中按序重试：

| Level | 方法 | URL | 适用场景 |
|-------|------|-----|----------|
| 0 | `computePlaybackUrl()` | `/Videos/{id}/stream?Static=true` | h264+mp4 / 原生兼容场景 |
| 1 | `computeDirectStreamUrl()` | `/Videos/{id}/stream.mp4` + `AllowVideoStreamCopy=true` | hevc / 容器不兼容但编码可直传 |
| 2 | `computeHlsUrl()` | `/Videos/{id}/master.m3u8` + 转码参数 | 硬编码转码兜底 |

> widget 层已实现 `_fallbackLevel` 递归重试，但 **当前仅在初始化失败
> (try-catch) 时触发**，**运行时 error 事件不触发降级**（参见 §6）。

### 4.5 播放状态上报（EmbyX 的完整四连）

```
POST /emby/Sessions/Capabilities/Full
Body: { "PlayableMediaTypes": ["Video"],
        "SupportsMediaControl": true,
        "SupportsPersistentConnections": false }
→ 登录后 / 首次播放前调用一次，用于服务器识别客户端能力

POST /emby/Sessions/Playing
Body: { "ItemId": "...", "PositionTicks": 0,
        "IsPaused": false, "IsMuted": false,
        "PlayMethod": "DirectPlay"|"Transcode",
        "EventName": "TimeUpdate", "CanSeek": true,
        "QueueableMediaTypes": ["Video"],
        "MediaSourceId": "...", "PlaySessionId": "..." }

POST /emby/Sessions/Playing/Progress  (周期 ~5s / 暂停时)
Body: 同上，字段一致

POST /emby/Sessions/Playing/Stopped   (切换/退出时)
Body: { "ItemId": "...",
        "PositionTicks": current,
        "MediaSourceId": "...",
        "PlaySessionId": "..." }
```

- `PositionTicks = (seconds) * 10_000_000`
- `PlayMethod` 需要与当前实际播放等级（DirectPlay / Transcode）
  保持一致，否则 Emby 服务端统计错误。
- `PlaySessionId` 建议为 UUID，每次播放会话唯一。

### 4.6 收藏

```
POST   /emby/UserFavoriteItems/{itemId}?api_key={token}
DELETE /emby/UserFavoriteItems/{itemId}?api_key={token}
```

- EmbyX 使用带 userId 变体 `/Users/{userId}/FavoriteItems/{id}`，
  两者等价。当前实现使用不带 userId 的短路径，行为一致。
- UI 应采用乐观更新（先改本地 UserData，远端失败再回滚）。

### 4.7 跨设备续播云同步（参考 EmbyX DisplayPreferences）

```
POST /emby/DisplayPreferences/EmbyTok-Resume?userId={userId}
Body: { "Id": "EmbyTok-Resume",
        "CustomPrefs": {
          "lastId": "{itemId}",
          "libId": "{libraryId}",
          "libType": "...",
          "date": "{unixMs}",
          "deviceName": "..."
        } }

GET /emby/DisplayPreferences/EmbyTok-Resume?userId={userId}
→ 返回 { CustomPrefs: { ... } }
```

- 触发点：**切换视频前**保存旧视频的续播信息；
  **进入首页 / 切换到某个媒体库时**拉取一次，以恢复其它设备的
  最近续播。
- 服务层已实现 `saveCloudSync` / `checkCloudSync`，但 widget 层
  尚未触发调用。

---

## 5. 非功能要求（NFR）

- **NFR-1 失败不崩溃**：任何 Emby API 失败（HTTP 非 2xx、
  网络不可达、响应 schema 变化）都不能让应用崩溃，必须降级为
  "显示占位图 + 可重试"。
- **NFR-2 并发去重**：同一用户对同一 item 的收藏 / 上报请求应
  合并或排队，避免产生重复请求。（当前 `favorites_provider.dart`
  已通过 `_pendingToggles` 实现去重。）
- **NFR-3 字段向后兼容**：`MediaItem.fromJson` 必须同时接受
  PascalCase（Emby 原生）与 snake_case（后端代理 / 缓存产物）。
- **NFR-4 认证头不泄漏**：日志中不得打印完整 token，仅允许打印
  hash / 前 4 位占位。`authHeaders()` 返回的 map 仅用于
  video_player 的 HTTP 头。
- **NFR-5 播放上报节流**：`reportPlaybackPosition` 每 5 秒最多
  一次，或播放进度累计变化 ≥ 1% 才上报，避免对 Emby 服务器造成
  压力。

---

## 6. 验收标准（Given/When/Then）

### AC-1：登录流程
- **Given** 用户已输入正确的 server url、username、password
- **When** 点击登录
- **Then** 应用本地持久化 `embyServerUrl`、`apiKey(token)`、`userId`，
  并成功拉取到媒体库列表
- **Verification**：`programmatic`（单元测试可模拟）

### AC-2：播放降级链（初始化路径）
- **Given** Direct Play URL 返回 415 / 初始化超时
- **When** `video_player` 初始化抛错
- **Then** 自动尝试 Direct Stream；若仍失败，再降级到 HLS；
  全部失败后显示占位图而非白屏
- **Verification**：`programmatic`（通过 mock 不同 URL 的失败返回）

### AC-3：播放降级链（运行时路径 —— 当前缺口）
- **Given** 视频正在播放（已初始化成功），中途发生播放 error 事件
- **When** `controller.value.hasError == true`
- **Then** widget 层尝试切到下一级降级 URL，重新初始化播放
- **Verification**：`human-judgment`（真实环境中触发网络中断并观察）

### AC-4：完整上报链
- **Given** 视频已开始播放
- **When** 播放开始 / 每 5 秒 / 暂停 / 停止时
- **Then** 分别调用 `reportCapabilities → reportPlaybackStart →
  reportPlaybackPosition（周期）→ reportPlaybackStopped`
- **Verification**：`programmatic`（断言网络请求计数与 payload 字段）

### AC-5：跨设备续播
- **Given** 设备 A 上播放到第 10 分钟后退出
- **When** 设备 B 打开同一媒体库
- **Then** 设备 B 首页显示"从 A 设备续播"提示，并在用户点击时
  跳转到第 10 分钟继续播放
- **Verification**：`human-judgment`

### AC-6：收藏乐观更新 + 失败回滚
- **Given** 用户对某条视频双击点赞，随后模拟网络失败
- **When** 远端 `POST /UserFavoriteItems` 返回 5xx
- **Then** UI 先切为已收藏，再在失败时回滚为未收藏并 toast 提示
- **Verification**：`programmatic`（mock 失败响应并断言 state）

### AC-7：字段向后兼容
- **Given** 响应同时包含 `RunTimeTicks` 和 `runtime_ticks`
- **When** `MediaItem.fromJson` 解析
- **Then** 两者都能正确解析到 `runtimeTicks` 字段，且不抛异常
- **Verification**：`programmatic`（单元测试 fixture）

---

## 7. 后端代理路径（次路径）规范

`backend/clients/emby_client.py` 保持与前端一致的端点语义：

- `authenticate(username, password)` → 登录并保存 `token` / `user_id`
- `get_libraries()` → `/Library/VirtualFolders`（保持 admin 视角，
  后端不维护 user 会话）
- `get_items(parent_id, limit, offset)` → `/Items`，**必须**带
  `MediaSources`、`Path` Fields
- `toggle_favorite(item_id, is_favorite)` → `/UserItems/{uid}/...`
- `save_playback_progress(item_id, position_ticks)` → `/Sessions/Playing/Progress`
- `get_subtitles(item_id)` → 保持现状

> 注意：后端路径不是主路径，仅在前端选择"走后端代理"模式时使用。
> 主路径下前端直接连 Emby，后端仅作为备选 / 搜索缓存。

---

## 8. 参考实现对比摘要（EmbyX vs EmbyTok）

| 维度 | EmbyX | EmbyTok | 对齐状态 |
|------|--------|---------|----------|
| 登录 | `/Users/AuthenticateByName` | 同左 | ✅ |
| 媒体库 | `/Users/{uid}/Views` | 同左 + fallback | ✅ |
| 视频列表 Fields | 含 `MediaSources,Path` | 同左 | ✅ |
| Direct Play | `/Videos/{id}/stream?Static=true` | 同左 | ✅ |
| Direct Stream | `/Videos/{id}/stream.mp4` | 同左 | ✅ |
| HLS 转码 | `/Videos/{id}/master.m3u8` | 同左 | ✅ |
| 降级链触发 | 初始化 + 运行时 error | 仅初始化 | ⚠️ 需补齐 |
| 上报链 | Capabilities + Playing + Progress + Stopped | 仅方法实现，未调用 | ⚠️ 需补齐 |
| 收藏端点 | `/Users/{uid}/FavoriteItems/{id}` | `/UserFavoriteItems/{id}` | ⚠️ 可统一 |
| 续播云同步 | DisplayPreferences | 方法已实现未触发 | ⚠️ 需补齐 |
| 乐观更新 | 是 | 是 | ✅ |

---

## 9. 未决事项 / 风险

1. **收藏端点路径统一**：带 userId 与不带 userId 两种路径 Emby 都接受，
   但建议统一为带 userId 变体以便与多用户场景一致。
2. **HLS 播放在 Flutter 端的支持**：`video_player` 官方插件对
   `master.m3u8` 的支持在 Android/iOS 上表现不一，需真机验证。
   若表现不稳，可考虑 `better_player` / `fvp` 等替代。
3. **`PlaySessionId` 生成策略**：当前未显式生成会话 ID，应在
   播放会话开始时生成并在整个播放周期内复用。
4. **云同步冲突策略**：两设备同时播放同一 item 时以 `date` 时间戳
   最新者为准，冲突时按最新覆盖旧值。

