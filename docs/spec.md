# EmbyTok Flutter v1.1.0 - 产品需求文档（PRD）

## 一、概述

### 1.1 目标

修复 Flutter 竖屏视频浏览客户端，直接连接 Emby 媒体服务器，提供类似 TikTok 的沉浸式滑动观看体验。当前核心功能已完成，但无法成功连接 Emby 服务器，需要修复认证流程、媒体列表获取、视频播放等核心功能修复优化。

### 1.2 问题概述

当前应用的主要用户：

1. 无法成功与 Emby 服务器握手
2. 缺少必要的请求头导致服务端拒绝服务
3. 错误信息不明朗，难以诊断
4. 媒体列表获取逻辑不完善
5. 视频播放地址构建错误

### 1.3 核心体验（来自参考应用的关键要点

来自 [**Yamby**（第三方 Emby 客户端，Android）**
- Material Design 3 界面
- Emby SDK 调用 /Users/AuthenticateByName 进行登录
- Emby API 获取图片地址：/emby/Users/AuthenticateByName

[**Cinetry**](https://github.com/gstory0404/Cinetry)（开源跨平台）
- 支持 Emby / Jellyfin / CMS / IPTV
- 登录流程：先获取公共用户列表 → 用户选择用户后输入密码 → 调用 /Users/AuthenticateByName

[**Jellyfin AndroidTV**](https://github.com/jellyfin/jellyfin-androidtv)（开源
- 认证使用 QuickConnect 与密码登录
- 使用 Form URL 登录协议通过 /Users/AuthenticateByName

[**EmbyTok**](https://github.com/1525745393)（参考设计图（参考设计图
- Flutter 3.0，Riverpod 2.0，Dio 5.0）
- 支持多服务器管理
- 完整文档/Emby 服务器切换

### 1.4 应用架构设计参考

来自 Emby REST API 官方规范（来自 dev.emby.media）：

```
认证流程：

步骤 1：POST /Users/AuthenticateByName
  Content-Type: application/json 或 application/x-www-form-urlencoded
  Body: { "Username": "...", "Pw": "..." }
  请求头必须：X-Emby-Authorization: Emby UserId="(guid)", Client="ClientName", Device="DeviceName", DeviceId="device_id", Version="1.0.0"

步骤 2：返回 { "User": { "Id": "...", "Name": "...", ... }, "AccessToken": "...", "ServerId": "..."}

步骤 3：后续请求头：X-Emby-Token: <AccessToken>

媒体库列表：GET /Library/VirtualFolders

媒体列表：GET /Items?ParentId=<library_id>&SortBy=SortName&SortOrder=Ascending&Recursive=true&IncludeItemTypes=Movie&Fields=Overview,Genres,CommunityRating,ProductionYear,RuntimeTicks,UserData&StartIndex=0&Limit=20

搜索：GET /Items?SearchTerm=<query>&Recursive=true&IncludeItemTypes=Movie,Episode,Video,MusicVideo,Series

收藏：GET /Items?Filters=IsFavorite&Recursive=true

视频播放：/Videos/<item_id>/stream?api_key=<token> 或 /Items/<item_id>/Videos?MediaSourceId=<media_source_id>

缩略图：/Items/<item_id>/Images/Primary?MaxWidth=400&Format=webp

播放记录：POST /Users/<user_id>/PlayingItems/<item_id>

```

---

## 二、目标

- **G1**: 应用能够成功连接任意版本（≥4.7+ 的 Emby 服务器
- **G2**: 用户可以快速浏览竖屏视频列表，且加载流畅，加载中的滑动体验
- **G3**: 提供清晰、可操作的错误信息
- **G4**: 支持多服务器管理（本地存储）
- **G5**: 支持基本的播放记录同步（观看进度同步到服务器
- **G6**: G6：兼容 Jellyfin（与 Emby API 大部分兼容）

---

## 三、非目标（Out of Scope）

- **NS1**: 不实现 Emby Connect 远程登录（仅限本地 LAN 连接
- **NS2**: 不实现转码与硬解高级设置（遵循设备能力检测）
- **NS3**: 不实现高级设置界面
- **NS4**: 不实现字幕渲染和字幕选轨显示（保留在后续版本）
- **NS5**: 不实现 DLNA/Chromecast 投屏功能
- **NS6**: 不实现离线缓存下载

---

## 四、功能需求

### FR-1: 登录认证流程

#### 4.1 用户输入服务器地址 + 用户名 + 密码 → 点击登录 → 调用 /Users/AuthenticateByName

**流程详情：

1. 用户输入服务器地址 (http://host:port 或 https://host:port/emby)
2. 应用首先验证服务器可达性
3. 调用 /Users/AuthenticateByName 获取用户列表，构建请求头必须包含：
   - `X-Emby-Authorization: Emby UserId="(guid)", Client="EmbyTok", Device="Mobile", DeviceId="<uuid>", Version="1.0.0"
   - `X-Emby-Client: EmbyTok`
   - `X-Emby-Client-Version: 1.0.0`
   - `X-Emby-Device-Name: <设备名>`
   - `X-Emby-Device-Id: <UUID>`
   - `Content-Type: application/json` 或 `application/x-www-form-urlencoded`
4. 保存 AccessToken、UserId、ServerId、服务器地址到本地存储
5. 跳转首页

**重要：

- `X-Emby-Authorization` 头在认证请求中的 `X-Emby-Token 头在认证请求中需要发送，Emby 服务器对认证请求时需在认证请求需要先访问 /emby 路径前缀支持，认证，注意服务器地址可能有 /emby 路径前缀

#### 4.2 自动检测服务器地址校验

- 提交前，应用先调用 `GET /System/Info/Public` 或 `GET /Users/Public` 验证服务器可达，用于：

- 确认地址格式正确
- 确认服务器是 Emby 服务器
- 获取服务器基本信息（版本、名称等）
- 检查协议正确

### FR-2: 媒体库列表获取

- **获取用户可访问的所有媒体库

**实现要求：

**

#### 4.2 加载**

- 自动选中第一个媒体库（非空）默认选中

**实现要求：

- **`GET /Library/VirtualFolders` 获取媒体库列表
- 每个库显示库名（Name），可选显示类型（CollectionType）
- 空库不显示，不显示媒体库加载中状态，空状态显示

**显示项：

- id: 库 ID (Id)
- name: 库名 (Name)
- type: 电影/剧集/音乐等 (CollectionType: movies/tvshows/music/...)

### FR-3: 媒体列表获取

- **根据选中媒体库，获取视频条目列表

**API 调用：

- `GET /Items?ParentId=<library_id>&Recursive=true&IncludeItemTypes=Movie,Episode,Video,MusicVideo&Fields=Overview,Genres,CommunityRating,ProductionYear,RuntimeTicks,UserData&SortBy=PremiereDate,ProductionYear,SortName&SortOrder=Descending&StartIndex=0&Limit=20

**支持分页加载**

- 每页 20 条记录
- 滑动到底部自动加载下一页
- 当达到总数时停止加载

**媒体项**：

- id (Id)
- title (Name)
- type (Type)
- overview (Overview)
- duration (RuntimeTicks → 秒)
- rating (CommunityRating)
- year (ProductionYear)
- genres (Genres → 列表)
- isFavorite (UserData.IsFavorite)
- imageUrl: /Items/<id>/Images/Primary?MaxWidth=800&Format=jpg
- playbackUrl: /Videos/<id>/stream?Static=true&api_key=<token> （静态播放地址或 /Videos/<id>/stream.mp4?Static=true&MediaSourceId=<media_source_id>

**Emby 标准做法：

- **SortBy 推荐使用 PremiereDate,ProductionYear,SortName（Emby 官方文档推荐）
- 电影：SortBy=ProductionYear（最新电影在前）
- 剧集：SortBy=DateCreated（最近添加在前）

### FR-4: 视频播放

**播放地址选择正确的播放地址

- 视频播放器：`/Videos/<item_id>/stream?Static=true&MediaSourceId=<media_source_id>&api_key=<token>

或使用 `/Videos/<item_id>/stream?Static=true` + 在请求头中携带 `X-Emby-Token: <token>`

**播放进度同步：

- 播放期间定期（每 30 秒调用 `POST /Users/<user_id>/PlayingItems/<item_id>/Progress`
- 播放完成调用 `POST /Users/<user_id>/PlayingItems/<item_id>/Stopped`

**视频播放器：

- 使用 video_player 插件播放 MP4 流

### FR-5: 搜索功能

**搜索流程：

- `GET /Items?SearchTerm=<关键词&Recursive=true&IncludeItemTypes=Movie,Episode,Video,MusicVideo,Series&Fields=Overview,Genres,CommunityRating,ProductionYear,RuntimeTicks,UserData&StartIndex=0&Limit=20

**搜索历史：

- 本地存储最近 10 条搜索记录
- 清空搜索历史

### FR-6: 收藏管理

**添加收藏：`POST /Users/<user_id>/FavoriteItems/<item_id>

**移除收藏：

`DELETE /Users/<user_id>/FavoriteItems/<item_id>

**获取收藏列表：

`GET /Items?Filters=IsFavorite&Recursive=true&IncludeItemTypes=Movie,Episode,Video,MusicVideo&Fields=Overview,Genres,CommunityRating,ProductionYear,RuntimeTicks,UserData&SortBy=DateCreated&SortOrder=Descending&StartIndex=0&Limit=100

**收藏更新：

- 乐观更新：点击收藏按钮即时变更态，后台异步同步到服务器
- 失败时回滚本地状态并显示错误提示

### FR-7: 观看历史

**记录：

- 本地存储最近观看的条目（id、标题、缩略图、观看进度、观看时间）
- 与服务器同步：调用 `POST /Users/<user_id>/PlayingItems/<item_id>/Progress`

### FR-8: 多服务器管理

**支持多服务器配置：

- 添加多个服务器
- 快速切换服务器
- 每个服务器独立的用户凭证独立保存

---

## 五、非功能需求

### NFR-1: 性能

- **视频首屏加载时间 < 2 秒（在正常网络条件下
- **滑动流畅度：60 FPS 帧率
- **媒体库切换响应 < 500ms

### NFR-2: 稳定性

- **崩溃率 < 0.5%（每天活跃用户
- **请求失败时显示清晰错误信息
- **Token 过期自动重定向到登录页

### NFR-3: 安全

- **Token 安全存储（shared_preferences 加密或加密存储
- **不存储明文密码（Token 是 Token，不存储密码
- **HTTPS 优先（用户输入时支持 https 前缀

### NFR-4: API 兼容性

- **兼容 Emby Server 4.7+
- **兼容 Jellyfin 10.8+（核心 API 相同）

### NFR-5: 错误信息

- **所有错误消息应包含：
  - 错误类型（网络/认证/权限/服务器错误）
  - 错误详情（服务器返回原始错误
  - 建议操作（检查服务器地址/检查网络/检查权限等

---

## 六、架构设计

### 6.1 技术选型

- **Flutter 3.10+**
- **Dart 3.0+**
- **状态管理：Riverpod 2.x
- **网络：Dio 5.x**
- **视频播放：video_player 2.x
- **本地存储：shared_preferences
- **图片缓存：cached_network_image 或 Image.network（带缓存机制

### 6.2 数据流架构

```
┌────────────────────────────────────────────────────┐
│                     UI 层 (Views)                            │
│  LoginView / FeedView / SearchView / FavoritesView │
│  HistoryView / SettingsView / HomeScaffold          │
└──────────────────────┬──────────────────────────────────────┘
                   │ Riverpod (Providers
┌──────────────────▼────────────────────────────┐
│           状态管理层 (Providers)              │
│  authProvider / libraryProvider /       │
│  videoListProvider / searchProvider /    │
│  favoritesProvider / watchHistoryProvider   │
└──────────────────────┬─────────────────────┘
                     │
┌────────────────────▼──────────────────────┐
│           服务层 (Services)                │
│  EmbytokService                        │
│  ├── login(embyUrl, username, password)    │
│  ├── getLibraries()                  │
│  ├── getItems(libraryId, page)      │
│  ├── search(query, page)            │
│  ├── getFavorites(page)               │
│  ├── toggleFavorite(itemId, bool) │
│  └── reportPlayback(itemId, progress)│
└──────────────────────┬──────────────────────┘
                     │
┌────────────────────▼──────────────────────┐
│          网络层 (ApiClient)                │
│  ├── 统一配置 Dio 配置                   │
│  ├── 注入 X-Emby-* 请求头               │
│  ├── 统一错误处理                      │
│  └── 超时 / 重试机制                    │
└─────────────────────────────────────────┘
                     │
         ┌──────────────▼────────────┐
         │   Emby / Jellyfin    │
         │   媒体服务器            │
         └────────────────────┘
```

### 6.3 状态模型

**AuthState：
```dart
class AuthState {
  final bool isAuthenticated;
  final User? user;
  final String? serverUrl;
  final String? accessToken;
  final String? serverId;
  final String? serverName;
  final String? serverVersion;
  final bool isLoading;
  final String? error;
}
```

**User：
```dart
class User {
  final String id;
  final String name;
  final String accessToken;
  final String? serverId;
}
```

**Library：
```dart
class Library {
  final String id;
  final String name;
  final String type;  // movies, tvshows, music, mixed ...
}
```

**MediaItem：
```dart
class MediaItem {
  final String id;
  final String title;
  final String type;
  final int? durationSeconds;
  final String thumbnailUrl;
  final String playbackUrl;
  final String? overview;
  final int? year;
  final double? rating;
  final List<String>? genres;
  final bool isFavorite;
}
```

---

## 七、约束条件

### 7.1 技术约束

- **Flutter SDK >= 3.10.0
- **Dart >= 3.0.0
- **最小 Android API 21+（Android 5.0+
- **iOS 12.0+

### 7.2 业务约束

- **不存储密码明文
- **不发送用户密码不存储

### 7.3 依赖

- **flutter_riverpod: ^2.5.0
- **go_router: ^13.0.0
- **dio: ^5.4.0
- **shared_preferences: ^2.2.0
- **video_player: ^2.8.0
- **cached_network_image: ^3.3.0
- **intl: ^0.19.0
- **uuid: ^4.0.0（生成 DeviceId

---

## 八、验收标准

### AC-1: 登录认证

- **Given** 用户输入有效的 Emby 服务器地址、用户名和密码
- **When** 点击登录按钮
- **Then**
  1. 应用调用 `/Users/AuthenticateByName
  2. 返回 200 → 成功保存 AccessToken 和 User 信息
  3. 跳转到首页
  4. 后续请求头中都携带 `X-Emby-Token`
- **Verification**: programmatic（实际请求拦截器检查请求头包含正确字段

### AC-2: 媒体库列表

- **Given** 用户已登录
- **When** 进入首页
- **Then**
  1. 调用 `/Library/VirtualFolders`
  2. 显示媒体库列表
  3. 默认选中第一个非空库
  4. 空库不显示
- **Verification**: programmatic + human-judgment

### AC-3: 视频列表加载

- **Given** 用户选中了一个媒体库
- **When** 首页加载
- **Then**
  1. 调用 `/Items?ParentId=<library_id>&Recursive=true&...&StartIndex=0&Limit=20`
  2. 返回 20 条视频
  3. 滑动到底部自动加载下一页
  4. 达到总数时停止加载
- **Verification**: programmatic + human-judgment

### AC-4: 视频播放

- **Given** 用户在首页上滑动到一个视频
- **When** 视频在页面可见
- **Then**
  1. 自动开始播放
  2. 视频地址正确 `/Videos/<id>/stream
  3. 播放请求头包含 `X-Emby-Token`
- **Verification**: programmatic + human-judgment

### AC-5: 搜索功能

- **Given** 用户在搜索框输入关键词
- **When** 点击搜索
- **Then**
  1. 调用 `/Items?SearchTerm=<keyword>&...`
  2. 显示搜索结果列表
  3. 保存搜索历史
- **Verification**: programmatic

### AC-6: 收藏功能

- **Given** 用户点击视频页面的心形按钮
- **When** 点击收藏按钮
- **Then**
  1. 调用 `POST /Users/<user_id>/FavoriteItems/<item_id>`
  2. 本地状态立即更新（乐观更新）
  3. 失败时回滚并显示错误
- **Verification**: programmatic

### AC-7: 错误提示

- **Given** 发生网络错误
- **When** 请求失败
- **Then** 显示清晰的错误类型（网络/认证/权限等 + human-judgment

### AC-8: Token 过期自动重定向

- **Given** 服务器返回 401
- **When** 用户浏览已登录状态下请求
- **Then** 自动重定向到登录页
- **Verification**: programmatic

### AC-9: 服务器地址自动补全

- **Given** 用户输入 `192.168.1.100
- **When** 提交
- **Then** 自动补全为 `http://192.168.1.100:8096

---

## 九、开放问题（Open Questions）

- **OQ-1**: 是否需要支持 Jellyfin 的特殊处理？（Jellyfin 的 API 大部分相同，但有细微差异）
  - 决定：兼容两者，检测服务器类型后适配
- **OQ-2**: 是否需要保存用户密码用于快速登录？
  - 决定：不保存密码，仅保存 AccessToken

---

## 十、风险与缓解措施

### 10.1 主要风险

| 风险 | 影响 | 概率 | 缓解措施 |
|------|------|------|----------|
| 不同 Emby 版本差异 | 高 | 中 | 测试多个版本（4.7 / 4.8 / 最新；降级兼容测试 |
| 网络超时设置合理（30 秒） | 中 | 中 | 实现超时配置 + 友好超时提示 |
| 服务器认证失败 401 原因多样（用户密码错误、服务器版本、Token 过期 | 高 | 高 | 完善错误分类 + 清晰错误信息 + 重定向到登录 |
| 视频播放器在低端设备性能 | 中 | 中 | 优化视频预加载 + 自动播放策略；优化图片缓存 |

## 十一、版本计划

| 阶段 | 时间 | 主要内容 |
|------|------|---------||
| v1.1.0 | 当前 | 修复认证、媒体列表、播放、搜索、收藏 |
| v1.2.0 | 后续 | 多服务器、播放进度、字幕、Jellyfin 兼容 |
