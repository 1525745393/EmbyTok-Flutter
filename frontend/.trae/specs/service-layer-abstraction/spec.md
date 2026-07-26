# 服务层抽象与依赖注入 - Product Requirement Document

## Overview
- **Summary**: 对现有 EmbytokService 进行分层重构，抽象出 MediaServerApi 接口层，将 Emby 特定的 API 调用封装为独立适配层，上层业务通过 Riverpod Provider 获取服务实例，为后续多服务端（Jellyfin、Plex）支持和单元测试奠定基础。
- **Purpose**: 解决当前 EmbytokService 直接封装 Dio、业务逻辑与 Emby API 强耦合的问题，提高代码可测试性和可扩展性，实现服务端实现的可插拔替换。
- **Target Users**: 项目开发者、测试人员

## Goals
- 抽象 MediaServerApi 接口，定义媒体服务端的标准能力契约
- 实现 Emby 适配层（EmbyServerApi），将现有 EmbytokService 中的 API 调用迁移到适配层
- 建立基于 Riverpod Provider 的服务实例管理机制，支持多环境切换和测试 Mock
- 保持现有功能完全兼容，不引入任何行为变更
- 为 Jellyfin、Plex 等其他媒体服务端适配预留扩展点

## Non-Goals (Out of Scope)
- 不实现 Jellyfin 或 Plex 的具体适配（仅预留接口）
- 不改变现有的 UI 层和业务逻辑层代码
- 不引入新的功能特性
- 不改变数据模型（MediaItem、Library 等）
- 不修改播放相关的底层逻辑（视频播放、字幕渲染等）
- 不重构 Repository 层（MediaRepository 已存在，保持现状）

## Background & Context

### 现有架构
项目当前服务层结构：
- `ApiClient`：基于 Dio 的底层 HTTP 客户端，负责请求拦截、Token 注入、错误处理
- `EmbytokService`：直接封装 Emby API，包含 40+ 个方法，承担了 API 适配和部分业务逻辑
- `MediaRepository`：已有的仓库抽象接口，定义了媒体数据访问契约
- `EmbyRepository`：MediaRepository 的 Emby 实现，薄封装 EmbytokService

### 存在的问题
1. **职责不清**：EmbytokService 同时承担了 API 适配、业务逻辑、状态管理等多个职责，单文件超过 1600 行
2. **耦合严重**：上层业务（Provider、Widget）部分直接依赖 EmbytokService，部分通过 MediaRepository，两种模式并存
3. **测试困难**：虽然已通过 Provider 管理实例，但服务层缺乏抽象接口，Mock 成本高
4. **扩展困难**：新增 Jellyfin/Plex 支持需要大量修改现有代码

### 技术约束
- 框架：Flutter + Riverpod 2.x
- 语言：Dart 3.x
- 网络库：Dio 5.x
- 现有数据模型保持不变

## Functional Requirements

### FR-1: MediaServerApi 接口抽象
- 定义 `MediaServerApi` 抽象接口，包含媒体服务端的核心能力
- 接口方法覆盖现有 EmbytokService 的所有公共 API 方法
- 每个方法接受明确的参数，返回统一的数据模型
- 认证信息（serverUrl、token、userId）通过方法参数传递，不持有内部状态

### FR-2: Emby 适配层实现
- 实现 `EmbyServerApi` 类，实现 `MediaServerApi` 接口
- 内部使用 `ApiClient` 进行 HTTP 请求
- 将现有 `EmbytokService` 中的 API 调用逻辑迁移到适配层
- 保持与现有 EmbytokService 完全一致的行为

### FR-3: EmbytokService 重构为业务门面
- `EmbytokService` 不再直接调用 Dio，而是依赖 `MediaServerApi` 接口
- `EmbytokService` 保留业务逻辑（字幕缓存、播放上报重试、云同步等）
- 通过构造函数注入 `MediaServerApi` 实例，默认使用 `EmbyServerApi`
- 保持所有现有公共方法签名不变，确保向后兼容

### FR-4: Provider 依赖注入体系
- 定义 `mediaServerApiProvider`，提供当前激活的 `MediaServerApi` 实例
- `embytokServiceProvider` 改为从 `mediaServerApiProvider` 获取适配层实例
- 支持通过 Provider override 切换不同的服务端实现
- 测试时可 easily Mock `MediaServerApi`

### FR-5: 服务类型枚举与配置
- 定义 `ServerType` 枚举（emby、jellyfin、plex）
- 提供根据 serverUrl 自动检测服务类型的能力（可选，本期仅预留）
- 用户可手动选择服务端类型（UI 层面不在本期范围内）

## Non-Functional Requirements

### NFR-1: 向后兼容
- 所有现有公共 API 的签名和行为保持不变
- 现有单元测试无需修改即可通过
- 上层调用代码（Provider、Widget）无需修改

### NFR-2: 可测试性
- MediaServerApi 接口可被 Mock
- 每个适配层可独立单元测试
- EmbytokService 可通过注入 Mock 的 MediaServerApi 进行测试

### NFR-3: 可扩展性
- 新增服务端类型只需实现 MediaServerApi 接口
- 无需修改 EmbytokService 和上层业务代码
- 遵循开闭原则（对扩展开放，对修改关闭）

### NFR-4: 性能
- 抽象层引入的性能开销可忽略（<1%）
- 不增加额外的网络请求
- 内存占用无显著增加

### NFR-5: 代码质量
- 每个文件不超过 500 行
- 接口文档完整（每个方法有中文注释）
- 遵循项目现有代码规范

## Constraints
- **技术**: 必须使用 Dart 3.x、Riverpod 2.x、Dio 5.x
- **业务**: 功能完全保持现状，不引入新功能，不修改现有行为
- **时间**: 重构应在可验证的小步骤中完成，每步均可独立提交
- **依赖**: 不引入新的第三方依赖库

## Assumptions
- 现有 EmbytokService 的所有方法行为都是正确的，重构仅做结构调整
- MediaRepository 层将在后续迭代中统一使用 MediaServerApi，本期保持现状
- Jellyfin 和 Plex 的 API 结构与 Emby 有足够的相似性，接口抽象可行
- 现有单元测试覆盖了主要业务逻辑，可作为重构的安全网

## Acceptance Criteria

### AC-1: MediaServerApi 接口完整性
- **Given**: 现有 EmbytokService 的公共方法列表
- **When**: 对比 MediaServerApi 接口定义
- **Then**: 所有公共方法在接口中都有对应的声明，参数和返回类型一致
- **Verification**: `programmatic`
- **Notes**: 可通过静态分析或代码审查验证

### AC-2: Emby 适配层行为一致性
- **Given**: 相同的输入参数
- **When**: 分别调用重构前的 EmbytokService 和重构后的 EmbyServerApi
- **Then**: 返回结果完全一致，网络请求的 URL、参数、Header 完全相同
- **Verification**: `programmatic`
- **Notes**: 通过单元测试验证，Mock Dio 层对比请求细节

### AC-3: EmbytokService 向后兼容
- **Given**: 现有所有调用 EmbytokService 的代码
- **When**: 运行现有单元测试
- **Then**: 所有测试全部通过，无需修改测试代码
- **Verification**: `programmatic`
- **Notes**: 包括 auth、favorites、search 等相关测试

### AC-4: Provider 可替换性
- **Given**: 一个 Mock 的 MediaServerApi 实现
- **When**: 通过 ProviderScope.overrides 替换 mediaServerApiProvider
- **Then**: EmbytokService 使用 Mock 实例而非默认的 EmbyServerApi
- **Verification**: `programmatic`
- **Notes**: 通过单元测试验证

### AC-5: 代码结构合理性
- **Given**: 重构后的代码库
- **When**: 审查服务层目录结构和文件大小
- **Then**: 接口、适配层、业务服务分层清晰，单个文件不超过 500 行
- **Verification**: `human-judgment`
- **Notes**: 代码审查检查

### AC-6: 无性能退化
- **Given**: 相同的网络请求场景
- **When**: 对比重构前后的响应时间和内存占用
- **Then**: 性能差异在 5% 以内，无内存泄漏
- **Verification**: `human-judgment`
- **Notes**: 人工代码审查确认无明显性能问题

## Open Questions
- [ ] MediaServerApi 接口是否需要包含播放上报相关方法（reportCapabilities、reportPlaybackStart 等）？这些更偏向业务逻辑而非纯 API 调用。
- [ ] 字幕解析逻辑（parseSubtitle）应该放在哪一层？目前在 EmbytokService 中，它是纯函数，与具体服务端无关。
- [ ] 云同步（saveCloudSync/checkCloudSync）是 Emby 特有的功能，是否需要纳入 MediaServerApi？
- [ ] deleteItem、postRaw、deleteRaw 这些通用方法是否需要纳入接口？还是仅作为 Emby 实现的特有方法？
