# 日志完善与错误降级策略 - Spec

## Overview
- **Summary**: 在关键 API 调用处添加结构化日志，并实现视频流失败时的降级策略（自动切换到 Emby 原生 API）。
- **Purpose**: 提升应用的可调试性和稳定性，确保视频播放体验的连续性。
- **Target**: EmbyTok-Flutter v1.2.8+

## Why
当前应用存在以下问题：
1. **日志不足**：关键 API 调用缺乏结构化日志，难以定位问题
2. **无降级策略**：视频流失败时直接报错，用户体验中断

## What Changes

### 1. 结构化日志系统
- 引入 `logger` 包进行结构化日志记录
- 在关键 API 调用处添加日志：
  - 登录/认证流程
  - 媒体库加载
  - 视频流请求
  - 收藏/搜索操作
  - 错误和异常捕获

### 2. 视频流降级策略
- **主路径**：通过后端代理请求视频流
- **降级路径**：失败时自动切换到 Emby 原生 API
- **降级条件**：
  - 后端代理超时（>10s）
  - 后端返回 5xx 错误
  - 网络连接失败
  - 视频流加载失败

## Impact
- **Affected specs**: embbytok-flutter-v1, fix-video-ui-v1
- **Affected code**:
  - `frontend/lib/services/embbytok_service.dart` — 添加日志和降级逻辑
  - `frontend/lib/widgets/video_player_widget.dart` — 添加降级播放逻辑
  - `frontend/lib/providers/auth_provider.dart` — 添加认证日志
  - `frontend/lib/utils/logger.dart` — 新增日志工具类

## ADDED Requirements

### Requirement: 结构化日志系统
系统 SHALL 在关键 API 调用处记录结构化日志。

#### Scenario: 登录流程日志
- **WHEN** 用户执行登录操作
- **THEN** 系统记录以下日志：
  - `[INFO] Login started: {serverUrl, username}`
  - `[DEBUG] Auth request sent: {requestId, timestamp}`
  - `[INFO] Login success: {userId, tokenLength}`
  - `[ERROR] Login failed: {error, stackTrace}`

#### Scenario: 视频流请求日志
- **WHEN** 请求视频流
- **THEN** 系统记录以下日志：
  - `[INFO] Video stream request: {itemId, serverUrl}`
  - `[DEBUG] Stream URL constructed: {playbackUrl}`
  - `[WARN] Stream fallback triggered: {reason, fallbackUrl}`
  - `[ERROR] Stream failed: {error, itemId}`

### Requirement: 视频流降级策略
系统 SHALL 在视频流失败时自动切换到 Emby 原生 API。

#### Scenario: 后端代理失败降级
- **WHEN** 后端代理请求视频流失败（超时/5xx/网络错误）
- **THEN** 系统自动切换到 Emby 原生 API
- **AND** 记录降级原因和降级 URL

#### Scenario: 降级成功
- **WHEN** 降级到 Emby 原生 API
- **THEN** 视频正常播放
- **AND** 用户无感知切换

#### Scenario: 降级失败
- **WHEN** 降级到 Emby 原生 API 仍然失败
- **THEN** 显示友好的错误提示
- **AND** 提供"重试"按钮

## MODIFIED Requirements

### Requirement: VideoPlayerWidget
`VideoPlayerWidget` SHALL 支持降级播放策略。

**修改内容**：
- 新增 `fallbackUrl` 参数
- 新增 `onFallback` 回调
- 播放失败时自动尝试降级 URL

### Requirement: EmbytokService
`EmbytokService` SHALL 记录所有 API 调用日志。

**修改内容**：
- 所有公开方法添加日志记录
- 错误捕获时记录完整堆栈

## Technical Design

### 日志工具类
```dart
// frontend/lib/utils/logger.dart
class AppLogger {
  static void info(String message, {Map<String, dynamic>? data});
  static void debug(String message, {Map<String, dynamic>? data});
  static void warn(String message, {Map<String, dynamic>? data});
  static void error(String message, Object error, StackTrace? stackTrace);
}
```

### 降级策略流程
```
1. 尝试后端代理 URL
   ↓ (失败)
2. 记录失败原因
   ↓
3. 切换到 Emby 原生 URL
   ↓ (成功)
4. 播放视频 + 记录降级日志
   ↓ (失败)
5. 显示错误提示 + 提供重试按钮
```

## Open Questions
- [ ] 日志级别是否需要可配置（Debug/Release 不同级别）？
- [ ] 降级策略是否需要统计成功率？
