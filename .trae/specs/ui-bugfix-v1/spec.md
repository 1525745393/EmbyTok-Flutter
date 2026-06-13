# EmbyTok Flutter - 修复 API 认证与首页加载

## Why
用户测试后反馈：首页媒体库切换栏完全不显示，收藏页报错 "Access token is invalid or expired"，首页显示 "暂无视频"。核心原因：(1) 后端用查询参数 `ApiKey` 传递 token，某些 Emby 版本不接受，应改为请求头方式；(2) 首页在媒体库加载时不显示任何 UI，用户不知道正在加载；(3) 错误信息未友好化。

## What Changes
- 后端 `EmbyClient`：在请求头 `X-Emby-Token` 中传递 token（同时保留查询参数兼容）
- 前端 `feed_view.dart`：改进媒体库切换栏的加载状态显示，自动选择第一个媒体库
- 前端 `favorites_view.dart` / `search_view.dart` / `history_view.dart`：友好处理错误信息

## Impact
- Affected code: `backend/clients/emby_client.py`, `frontend/lib/views/feed_view.dart`
- Backward compatible: 是，仅改进认证方式和 UI 显示

## ADDED Requirements

### Requirement: 后端 Token 通过请求头传递
后端 EmbyClient 在请求时应在 header `X-Emby-Token` 中传递 token，同时保留查询参数的兼容方式。

#### Scenario: 认证请求
- **WHEN** 后端使用 `EmbyClient` 调用 Emby API（如 `/Items`、`/Library/VirtualFolders`）
- **THEN** 请求头中应包含 `X-Emby-Token: <token>`，同时查询参数中也包含 `ApiKey=<token>`

### Requirement: 首页媒体库切换栏加载状态改进
用户进入首页时，应能看到媒体库加载状态，加载成功后自动选择第一个媒体库并开始加载视频。

#### Scenario: 首次进入首页
- **WHEN** 用户登录后进入首页
- **THEN** 顶部显示媒体库加载指示器
- **AND** 媒体库加载成功后自动选择第一个媒体库
- **AND** 自动触发视频列表加载

#### Scenario: 媒体库加载失败
- **WHEN** 获取媒体库列表失败
- **THEN** 顶部显示错误提示和重试按钮

### Requirement: 错误信息友好化
当 API 返回错误时，应显示用户友好的中文提示而非原始英文错误。

#### Scenario: 收藏页 API 失败
- **WHEN** 收藏页 API 返回 401 或其他错误
- **THEN** 显示"加载失败，请重试"等中文提示，而不是 "Access token is invalid or expired"

## MODIFIED Requirements

### Requirement: 后端 EmbyClient 认证方式
`EmbyClient._default_params()` 继续设置查询参数 `ApiKey`，同时**新增请求头 `X-Emby-Token` 的注入**。

### Requirement: 首页 FeedView 初始化逻辑
`feed_view.dart` 中 `libraryListProvider` 返回空/错误时，`_buildLibraryChips` 不再返回 `SizedBox.shrink()`，而是显示相应状态 UI。
