# 演员界面与功能审查 - 规范

## Why

`frontend/lib/views/actors_view.dart`（815 行）、`frontend/lib/views/person_detail_view.dart`（573 行）和 `frontend/lib/providers/actors_provider.dart`（313 行）构成演员模块，承载演员列表展示、搜索、类型筛选、关注/取消关注、演员详情、作品列表分页加载等核心功能。

代码审查发现若干确认问题：硬编码颜色违反 lint 规范、滚动位置保存但从未恢复（死代码）、详情页错误处理逻辑 bug（作品列表成功但详情失败时显示错误而非作品）、`'null'` 字符串作为 null 占位符的 hack、TabController length magic number、空状态分支死代码等。本次审查目的是在不改变现有功能语义的前提下，修复这些问题，提升代码规范性与健壮性。

## What Changes

- **消除硬编码颜色**：`actors_view.dart` L788-794 的 `Colors.orange/green/blue`（类型标签颜色）迁移至主题或常量定义
- **修复滚动位置恢复**：`_restoreScrollOffset()` 已实现但从未被调用，需在数据加载完成后调用
- **修复详情页错误处理 bug**：`person_detail_view.dart` 中作品列表加载成功但详情加载失败时，UI 错误显示错误而非已加载的作品列表
- **消除 `'null'` 字符串 hack**：`actors_view.dart` L65 用 `savedType == 'null'` 判断 null，改用 `prefs.containsKey` 判断
- **提取 TabController length 常量**：L34 的 `length: 3` 提取为命名常量
- **清理空状态死代码**：`_buildEmptyState` 的 `isFavoriteEmpty` 分支（L513-568）永远不会被触发，需在"已关注"Tab 空列表时正确调用
- **补充测试**：为 actors_provider 和 person_detail_view 的核心逻辑补充测试

## Impact

- **Affected specs**: `actors-list-page`（演员列表页不变）、`actors-ui-optimization`（UI 优化不变）、`fix-actors-full-list`（全量加载不变）、`actor-avatar-button`（头像按钮不变）
- **Affected code**:
  - `frontend/lib/views/actors_view.dart`（主要修改文件）
  - `frontend/lib/views/person_detail_view.dart`（错误处理修复）
  - `frontend/test/providers/actors_provider_test.dart`（新建测试文件）
  - `frontend/test/views/person_detail_view_test.dart`（新建测试文件）
- **Affected tests**: 新增 actors_provider_test.dart 和 person_detail_view_test.dart 覆盖核心逻辑

## ADDED Requirements

### Requirement: 演员模块无硬编码颜色

`actors_view.dart` 中类型标签的颜色（Actor=蓝色, Director=橙色, Writer=绿色）不得使用 `Colors.xxx` 硬编码，应迁移至 `lib/theme/` 下的常量定义或使用 `ColorScheme` 语义化颜色。

#### Scenario: 类型标签颜色使用常量

- **WHEN** 编译 `actors_view.dart`
- **THEN** 不出现 `Colors.orange`、`Colors.green`、`Colors.blue` 等硬编码颜色
- **AND** `dart run tool/lints/hardcoded_color_lint.dart --path lib/views/actors_view.dart` 退出码 0

### Requirement: 滚动位置恢复功能可用

`actors_view.dart` 的 `_restoreScrollOffset()` 方法已实现（保存滚动位置到 SharedPreferences），但从未被调用，导致用户离开演员页再返回时滚动位置丢失。

#### Scenario: 数据加载完成后恢复滚动位置

- **WHEN** 用户进入演员页面且 `loadActors` 完成首次加载
- **THEN** 调用 `_restoreScrollOffset()` 恢复上次保存的滚动位置
- **AND** 恢复的滚动位置不超过 `maxScrollExtent`（已 clamp 处理）

### Requirement: 详情页错误处理不影响已加载作品

`person_detail_view.dart` 中，作品列表（`getPersonItems`）和详情（`getPersonDetail`）并发加载。当作品列表加载成功但详情加载失败时，UI 不应显示错误状态，而应正常展示作品列表。

#### Scenario: 作品成功但详情失败时显示作品列表

- **WHEN** `getPersonItems` 成功返回作品列表
- **AND** `getPersonDetail` 抛出异常
- **THEN** UI 正常显示作品列表（`_works` 非空）
- **AND** `_error` 保持为 null（不显示错误状态）
- **AND** 详情区域 fallback 到原始 `widget.person` 数据

### Requirement: 消除 'null' 字符串占位符 hack

`actors_view.dart` 中 `_saveSelectedType` 用 `'null'` 字符串作为 null 的占位符，`_restoreState` 用 `savedType == 'null'` 判断。这是反模式，应使用 `prefs.containsKey` 判断键是否存在。

#### Scenario: 类型筛选为"全部"时正确保存和恢复

- **WHEN** 用户选择"全部"类型（type=null）
- **THEN** `_saveSelectedType(null)` 不写入 SharedPreferences，或写入空字符串
- **AND** `_restoreState` 通过 `prefs.containsKey` 判断是否有保存的类型
- **AND** 恢复时 `setSelectedType(null)` 正确设置"全部"类型

### Requirement: TabController length 使用常量

`actors_view.dart` 中 `TabController(length: 3, vsync: this)` 的 `3` 是 magic number，应提取为命名常量。

#### Scenario: TabController length 引用常量

- **WHEN** 创建 TabController
- **THEN** 使用 `_actorTabsCount` 常量而非 magic number `3`

### Requirement: "已关注"Tab 空状态正确显示

`actors_view.dart` 的 `_buildEmptyState` 有 `isFavoriteEmpty` 分支（提示"暂无关注的演员"），但 `_buildActorGrid` 调用时传入 `isFavoriteEmpty: false`，导致该分支永远不会被触发。需在"已关注"Tab 的空列表时正确传入 `isFavoriteEmpty: true`。

#### Scenario: 已关注 Tab 无关注演员时显示引导提示

- **WHEN** 用户切换到"已关注"Tab
- **AND** 关注列表为空
- **THEN** 显示"暂无关注的演员"提示和"快去关注你喜欢的演员吧"引导文案
- **AND** 显示"点击演员卡片上的爱心图标即可关注"操作引导

## MODIFIED Requirements

无修改项。

## REMOVED Requirements

无移除项。

## Constraints

- **不改变现有功能语义**：演员列表加载、搜索、筛选、关注、详情查看、作品分页加载的行为不变
- **不引入新依赖**：仅在现有依赖范围内修改
- **保持向后兼容**：用户已保存的 SharedPreferences 数据不受影响（'null' 字符串 hack 的修复需考虑旧数据兼容）
- **小步重构**：每个修复独立，每步保持代码可工作

## Assumptions

- 硬编码颜色迁移至 `lib/theme/` 下的常量定义是项目认可的做法（参考 `donate_colors.dart` 模式）
- `'null'` 字符串 hack 的修复不需要数据迁移（旧数据 'null' 字符串在恢复时仍可被 `containsKey` 检测到并正确处理）
- TabController length 常量提取为私有静态常量即可，无需公开 API

## Open Questions

- [ ] 类型标签颜色是迁移至 `lib/theme/` 下的常量定义（参考 `donate_colors.dart`），还是改用 `ColorScheme` 语义化颜色？后者更符合 Material 3 规范，但 Director/Writer/Actor 是业务语义而非 Material 语义。
- [ ] `'null'` 字符串 hack 修复后，旧版本保存的 'null' 字符串数据如何处理？是否需要兼容读取？
