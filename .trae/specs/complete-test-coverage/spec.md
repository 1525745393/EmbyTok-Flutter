# 完善测试覆盖 Spec

## Why
当前项目只有一个基础的 widget_test.dart 冒烟测试，缺少对核心业务逻辑（Services、Providers、Models）的单元测试覆盖。这导致：
1. 重构时无法快速验证行为不变性
2. 新功能开发缺少回归保护
3. 错误处理逻辑未经验证

## What Changes
- 添加测试依赖：mockito、build_runner、dio 的 mock adapter
- 为 `ApiClient` 和 `EmbytokService` 编写单元测试（使用 mock HTTP 响应）
- 为核心 Providers（`AuthNotifier`、`VideoListNotifier`、`FavoritesNotifier`）编写状态机测试
- 为数据模型（`User`、`MediaItem`、`Library`）编写序列化/反序列化测试
- 添加测试工具类和 mock 生成配置

## Impact
- Affected specs: embbytok-flutter-v1（补充测试需求）
- Affected code: 
  - `frontend/pubspec.yaml`（添加 dev_dependencies）
  - `frontend/test/`（新增测试文件）
  - `frontend/lib/`（可能需要微调以支持测试注入）

## ADDED Requirements

### Requirement: 测试基础设施
系统应提供完整的测试基础设施，支持 mock HTTP 响应、状态管理测试和模型序列化测试。

#### Scenario: 测试依赖安装成功
- **WHEN** 执行 `flutter pub get`
- **THEN** mockito、build_runner、flutter_test 依赖正确安装

#### Scenario: Mock 文件生成成功
- **WHEN** 执行 `flutter pub run build_runner build`
- **THEN** 生成 `.mocks.dart` 文件，包含必要的 mock 类

### Requirement: Service 层单元测试
`EmbytokService` 的所有公开方法应有对应的单元测试，覆盖成功、失败、异常场景。

#### Scenario: 登录成功测试
- **WHEN** mock 后端返回有效 token
- **THEN** `login()` 方法返回 `User` 对象，token 被正确设置

#### Scenario: 登录失败测试
- **WHEN** mock 后端返回 401 错误
- **THEN** `login()` 方法抛出明确的错误信息

#### Scenario: 搜索结果解析测试
- **WHEN** mock 返回分页搜索结果
- **THEN** `search()` 方法正确解析 `PaginatedResponse<MediaItem>`

### Requirement: Provider 层状态机测试
核心 Provider 的状态流转应有完整的单元测试。

#### Scenario: AuthNotifier 登录状态流转
- **WHEN** 用户登录成功
- **THEN** `isAuthenticated` 变为 `true`，`user` 不为空，`error` 为 null

#### Scenario: AuthNotifier 登录失败状态流转
- **WHEN** 登录失败
- **THEN** `isAuthenticated` 保持 `false`，`error` 包含错误信息

#### Scenario: VideoListNotifier 分页加载
- **WHEN** 触发加载更多
- **THEN** 新数据追加到列表，`hasMore` 状态正确更新

### Requirement: Model 层序列化测试
所有数据模型应有 `fromJson` / `toJson` 测试，确保与后端 API 契约一致。

#### Scenario: User 模型序列化
- **WHEN** 解析登录响应 JSON
- **THEN** `User.fromJson()` 正确提取 `id`、`name`、`accessToken`

#### Scenario: MediaItem 模型序列化
- **WHEN** 解析媒体项 JSON
- **THEN** `MediaItem.fromJson()` 正确处理可选字段（如 `thumbnailUrl`、`rating`）

## MODIFIED Requirements
无（这是新增测试需求，不修改现有功能）

## REMOVED Requirements
无
