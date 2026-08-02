# 底部导航栏审查与修复 - 规范

## Why

`frontend/lib/views/home_scaffold.dart`（461 行）是应用主骨架，承载底部导航栏、4 个 Tab 切换、覆盖层页面（搜索/历史）、App 生命周期播放控制、系统返回键拦截等核心能力。配合 `frontend/lib/providers/page_navigation_provider.dart`（109 行）和 `frontend/lib/utils/fullscreen_navigator.dart`（92 行）构成完整导航系统。

代码审查发现若干确认问题：路由索引硬编码 magic number、PopScope 使用已废弃 API、Tab 切换缺乏触觉反馈、`_load` 异步初始化竞态、核心逻辑测试覆盖缺失。本次审查目的是在不改变现有功能语义的前提下，修复这些问题，提升代码可读性、API 现代化程度与可测试性。

## What Changes

- **消除路由索引 magic number**：`home_scaffold.dart` L282 `currentIndex == 4 ? 0 : 1` 改用 `PageIndices.search` 常量
- **迁移废弃的 PopScope API**：`onPopInvoked` → `onPopInvokedWithResult`（Flutter 3.22+ 标记废弃）
- **Tab 切换增加触觉反馈**：`onDestinationSelected` 添加 `HapticFeedback.selectionClick()`
- **修复 `_load` 异步初始化竞态**：增加 `isLoaded` 标记，避免用户在恢复的 Tab 加载完成前看到 Feed 闪烁
- **统一覆盖层持久化策略**：`goToSearch()`/`goToHistory()` 不持久化是合理的（覆盖层不应恢复），但需在代码注释中明确说明此设计决策
- **补充测试**：为 `home_scaffold.dart` 的 Tab 切换、覆盖层显隐、退出确认、生命周期播放控制等核心逻辑补充测试

## Impact

- **Affected specs**: `notch-safe-area-adaptation`（刘海适配不变）、`audit-settings-view`（设置页不变）
- **Affected code**:
  - `frontend/lib/views/home_scaffold.dart`（主要修改文件）
  - `frontend/lib/providers/page_navigation_provider.dart`（增加 `isLoaded` 状态）
  - `frontend/test/views/home_scaffold_test.dart`（新建测试文件）
- **Affected tests**: 新增 home_scaffold_test.dart 覆盖核心导航逻辑

## ADDED Requirements

### Requirement: 路由索引使用常量

代码中所有页面索引引用必须使用 `PageIndices` 类中定义的常量（`feed`/`favorites`/`actors`/`settings`/`search`/`history`），不得使用 magic number（如 `4`、`1`）。

#### Scenario: 覆盖层索引映射使用常量

- **WHEN** 在 `home_scaffold.dart` 中根据 `currentIndex` 判断覆盖层显示哪个页面
- **THEN** 使用 `currentIndex == PageIndices.search ? 0 : 1` 而非 `currentIndex == 4 ? 0 : 1`

### Requirement: PopScope 使用现代 API

`PopScope` 必须使用 `onPopInvokedWithResult` 而非已废弃的 `onPopInvoked`，以适配 Flutter 3.22+ 的 API 变更。

#### Scenario: PopScope 回调签名

- **WHEN** 编译 `home_scaffold.dart`
- **THEN** 不出现 `onPopInvoked` 的 deprecation 警告
- **AND** 使用 `onPopInvokedWithResult: (bool didPop, dynamic result) async { ... }` 签名

### Requirement: Tab 切换触觉反馈

用户点击底部导航栏切换 Tab 时，应触发轻量触觉反馈，提升操作确认感。

#### Scenario: 点击导航项触发触觉反馈

- **WHEN** 用户点击底部导航栏的某个 NavigationDestination
- **THEN** 调用 `HapticFeedback.selectionClick()` 后再切换页面
- **AND** 触觉反馈不阻塞页面切换（fire-and-forget）

### Requirement: 导航状态初始化一致性

`PageNavigationNotifier` 异步加载上次保存的 Tab 索引时，应明确标记加载状态，避免应用启动时短暂显示 Feed 后跳转到恢复的 Tab 造成视觉闪烁。

#### Scenario: 启动时恢复上次 Tab

- **WHEN** 应用启动且 SharedPreferences 中有保存的 `kStorageKeyLastPageIndex`
- **THEN** 在 `_load` 完成前，`state` 保持初始默认值（Feed）
- **AND** `_load` 完成后 `state` 更新为保存的索引
- **AND** 提供 `isLoaded` getter 供调用方判断加载状态（可选）

## MODIFIED Requirements

### Requirement: 覆盖层持久化策略文档化

`PageNavigationNotifier` 的 `goToSearch()` 和 `goToHistory()` 不调用 `_saveIndex`，这是有意设计（覆盖层是临时操作，不应在下次启动时恢复）。当前代码无注释说明此决策，需补充注释明确意图。

## REMOVED Requirements

无移除项。

## Constraints

- **不改变现有功能语义**：Tab 切换、覆盖层显隐、退出确认、生命周期播放控制的行为不变
- **不引入新依赖**：仅在现有 `flutter_riverpod`、`shared_preferences`、`flutter/services.dart`（HapticFeedback）范围内修改
- **保持向后兼容**：用户已保存的 `kStorageKeyLastPageIndex` 数据不受影响
- **小步重构**：每个修复独立，每步保持代码可工作

## Assumptions

- 项目 Flutter 版本 ≥ 3.22（`onPopInvoked` 已废弃）
- `HapticFeedback.selectionClick()` 在所有目标平台（Android/iOS）可用且无副作用
- 用户在应用启动时短暂看到 Feed 闪烁是可接受的（`_load` 通常 <50ms 完成）

## Open Questions

- [ ] `isLoaded` 状态是否真的需要暴露？如果 `_load` 完成时间极短（<50ms），用户可能感知不到闪烁。是否仅添加注释说明而不增加 `isLoaded` 字段？
- [ ] 触觉反馈是否应作为可配置项（如 `appPreferences.hapticFeedbackEnabled`）？还是硬编码为始终启用？
