# Emby 服务器适配度全面检查 Spec

## Why
项目已进行多次 Emby API 相关修复，需要重新全面检查当前代码与 Emby 原生 API 的适配情况，识别剩余问题和改进空间。

## What Changes
- 全面审查 `EmbytokService` 所有 API 调用
- 检查 `ApiClient` 认证头构造
- 检查 `VideoPlayerWidget` 播放 URL 构造
- 检查 `VideoPageItem` 播放进度上报
- 检查模型解析与 Emby 响应字段匹配
- 生成适配度评分报告

## Impact
- Affected specs: emby-api-compatibility（已完成修复，需验证）
- Affected code: 
  - `lib/services/embbytok_service.dart`
  - `lib/services/api_client.dart`
  - `lib/widgets/video_player_widget.dart`
  - `lib/widgets/video_page_item.dart`
  - `lib/models/*.dart`

## ADDED Requirements

### Requirement: 全面适配度检查
系统 SHALL 对以下模块进行 Emby API 适配度检查：

#### Scenario: API 端点检查
- **WHEN** 检查 `EmbytokService` 的所有方法
- **THEN** 验证每个 API 端点路径、请求参数、响应解析是否符合 Emby 原生 API 规范

#### Scenario: 认证机制检查
- **WHEN** 检查 `ApiClient` 的认证头构造
- **THEN** 验证 `X-Emby-Authorization` 和 `X-Emby-Token` 是否正确

#### Scenario: 播放功能检查
- **WHEN** 检查播放 URL 构造和进度上报
- **THEN** 验证 DirectPlay/DirectStream/Transcode URL 和 PositionTicks 精度

#### Scenario: 模型解析检查
- **WHEN** 检查 `MediaItem`/`UserData`/`MediaSource` 模型
- **THEN** 验证字段名映射（PascalCase vs snake_case）和类型转换

#### Scenario: 生成评分报告
- **WHEN** 完成所有检查
- **THEN** 输出适配度评分（0-10）和问题清单