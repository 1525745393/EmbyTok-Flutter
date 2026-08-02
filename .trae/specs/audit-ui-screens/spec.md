# UI 界面全量审查与修复 - 规范

## Why

EmbyTok 的 UI 表面由 17 个视图文件（`frontend/lib/views/`）与 24 个 widget 文件（`frontend/lib/widgets/`，含 `video/` 子目录）构成，承载视频流、收藏、演员、推荐、详情、搜索、历史、登录、设置、全屏播放等全部用户可见交互。

本轮全量审查（覆盖已完成的 `audit-actors-view` / `audit-navigation-bar` / `audit-settings-view` / `fix-homepage-audit` 范围之外的视图与组件）发现：5 个**严重**功能缺陷（强制解包崩溃风险、Slider 无防抖高频 seek、撤销状态不一致、build 中副作用、空状态无引导）、若干**中等**问题（`withOpacity` 废弃 API、长列表嵌套、magic number、死代码）、以及若干**低**级别代码质量问题。这些问题影响稳定性、性能与可维护性，需在不破坏现有功能语义的前提下统一修复。

## What Changes

### 严重问题修复（5 项，必须）

- **消除 `person_detail_view.dart` 强制解包崩溃风险**：`_loadData` / `_loadMore` 中 `auth.embyServerUrl!` / `auth.token!` 在 token 过期或未登录时触发空指针崩溃，改为 null 检查 + 会话过期友好提示
- **修复 `fullscreen_video_page.dart` Slider 拖动高频 seek**：L1157-1165 `onChanged` 中直接 `controller.seekTo` 导致拖动过程每帧都发 seek 请求，改为 `onChangeStart` 记录起始 + `onChanged` 仅更新预览时间 + `onChangeEnd` 执行最终 seek
- **修复 `favorites_view.dart` 撤销操作状态不一致**：L729-747 / L1245-1259 撤销仅再次 `toggleFavorite`，未处理服务端失败导致 UI 与服务器状态不一致，撤销失败时回滚 UI 状态并提示
- **修复 `recommend_view.dart` build 中副作用**：L145 在 `_buildBody` 中调用 `_maybeShowError` 触发 `addPostFrameCallback`，每次 rebuild 重复注册副作用，改为 `ref.listen` 监听 error 字段变化
- **修复 `video_grid_view.dart` 空状态无主动引导**：L86-97 空状态仅文字提示，未配置媒体库时无按钮直接打开 `LibrarySelector`，新增"选择媒体库"按钮引导

### 中等问题修复

- **迁移 `withOpacity` 废弃 API**：Flutter 3.27+ 标记 `Color.withOpacity` 为废弃，迁移至 `Color.withValues(alpha: ...)`（涉及视图层与组件层多处）
- **长列表嵌套优化**：`favorites_view.dart`、`history_view.dart`、`search_view.dart` 等长列表使用 `Column` + `SingleChildScrollView` 嵌套导致全量构建，评估改为 `ListView.builder` 懒加载
- **提取 magic number**：`fullscreen_video_page.dart` 中手势阈值、200px 触底加载阈值等提取为 `constants.dart` 常量
- **清理死代码**：审查中发现的未调用方法、不可达分支

### 低级别问题修复

- 注释与代码语义同步（如 `person_detail_view.dart` 中 fallback 行为注释）
- 代码风格统一（命名、缩进）

## Impact

- **Affected specs**:
  - `audit-actors-view`（演员模块已审查，本次不重复）
  - `audit-navigation-bar`（导航栏已审查，本次不重复）
  - `audit-settings-view`（设置页已审查，本次不重复）
  - `fix-homepage-audit`（首页 Feed 已审查，本次不重复）
  - `notch-safe-area-adaptation`（刘海适配不变）
- **Affected code**:
  - `frontend/lib/views/person_detail_view.dart`（严重：null 安全）
  - `frontend/lib/views/fullscreen_video_page.dart`（严重：Slider 防抖；中等：magic number）
  - `frontend/lib/views/favorites_view.dart`（严重：撤销一致性；中等：长列表）
  - `frontend/lib/views/recommend_view.dart`（严重：build 副作用）
  - `frontend/lib/views/video_grid_view.dart`（严重：空状态引导）
  - `frontend/lib/views/history_view.dart`、`search_view.dart`（中等：长列表）
  - `frontend/lib/widgets/video_player_widget.dart`（中等：build 中修改状态、字幕状态管理）
  - `frontend/lib/utils/constants.dart`（新增常量定义）
  - 相关测试文件（补充覆盖）
- **Affected tests**: 新增/补充 `person_detail_view_test.dart`、`fullscreen_video_page_test.dart`、`favorites_view_test.dart`、`recommend_view_test.dart`、`video_grid_view_test.dart` 中严重问题的回归测试

## ADDED Requirements

### Requirement: 演员详情页 null 安全

`person_detail_view.dart` 中所有读取 `auth.embyServerUrl` / `auth.token` 的位置不得使用 `!` 强制解包，必须显式处理 null 场景（会话过期、未登录）。

#### Scenario: Token 过期时友好提示而非崩溃

- **WHEN** 用户在演员详情页加载作品列表时 `auth.token` 为 null（会话过期）
- **THEN** 不抛出空指针异常
- **AND** UI 显示"登录已过期，请重新登录"错误提示
- **AND** 不阻塞已加载的详情区域（fallback 到 `widget.person`）

#### Scenario: 分页加载时 token 失效

- **WHEN** `_loadMore` 执行时 `auth.embyServerUrl` 或 `auth.token` 为 null
- **THEN** 不调用 `getPersonItems`，停止分页
- **AND** UI 提示"登录已过期"

### Requirement: 全屏播放器进度条防抖

`fullscreen_video_page.dart` 的进度条 `Slider` 必须在拖动结束时才执行 `seekTo`，拖动过程中仅更新预览时间显示。

#### Scenario: 拖动进度条不触发连续 seek

- **WHEN** 用户拖动进度条 Slider
- **THEN** `onChanged` 仅更新本地预览时间文本，不调用 `controller.seekTo`
- **AND** `onChangeEnd` 时才调用一次 `controller.seekTo(target)`
- **AND** 单次拖动只触发一次 seek 请求

### Requirement: 收藏撤销操作状态一致

`favorites_view.dart` 中"取消收藏"的撤销操作必须保证 UI 状态与服务器状态最终一致，撤销失败时回滚 UI。

#### Scenario: 撤销操作失败时回滚 UI

- **WHEN** 用户点击"撤销"重新收藏
- **AND** `toggleFavorite` 服务端调用失败
- **THEN** UI 回滚到"未收藏"状态（与服务器一致）
- **AND** SnackBar 提示"撤销失败，请重试"
- **AND** 不出现 UI 显示已收藏但服务器未收藏的不一致

### Requirement: 推荐页错误提示不在 build 中触发副作用

`recommend_view.dart` 的错误提示必须通过 `ref.listen` 监听 `recommendProvider` 的 error 字段变化触发，不得在 build 方法或被 build 调用的辅助方法中调用 `addPostFrameCallback`。

#### Scenario: rebuild 不重复注册 postFrameCallback

- **WHEN** `RecommendView` 因任何原因 rebuild（如父组件 setState、主题切换）
- **AND** `state.error` 为空或已展示
- **THEN** 不调用 `addPostFrameCallback`
- **AND** 不重复弹出 SnackBar

### Requirement: 视频网格空状态主动引导

`video_grid_view.dart` 的空状态必须提供可操作的引导按钮，而非仅文字提示。

#### Scenario: 未配置媒体库时显示选择按钮

- **WHEN** `videoState.items.isEmpty`（未选择媒体库或媒体库为空）
- **THEN** 空状态显示"暂无视频"文字 + "选择媒体库"按钮
- **AND** 点击按钮打开 `LibrarySelector`
- **AND** 用户选择媒体库后自动加载视频列表

#### Scenario: 有数据但筛选无结果时仅文字提示

- **WHEN** `videoState.items` 非空但 `displayItems` 为空（筛选无结果）
- **THEN** 空状态仅显示"没有符合筛选条件的视频"文字
- **AND** 不显示"选择媒体库"按钮（已有数据，无需引导）

### Requirement: 废弃 API 迁移

视图层与组件层不再使用 `Color.withOpacity`，迁移至 `Color.withValues(alpha: ...)`。

#### Scenario: 编译无 withOpacity 废弃警告

- **WHEN** 编译 `frontend/lib/views/` 与 `frontend/lib/widgets/` 下所有文件
- **THEN** 不出现 `withOpacity` 的 deprecation 警告（Flutter 3.27+）

### Requirement: 长列表懒加载

涉及长列表的视图（`favorites_view.dart`、`history_view.dart`、`search_view.dart`）不得使用 `Column` + `SingleChildScrollView` 全量构建，必须使用 `ListView.builder` 按需构建。

#### Scenario: 长列表按需构建

- **WHEN** 列表数据超过 50 条
- **THEN** 仅构建可见区域 + 缓存区的 item
- **AND** 滚动流畅无卡顿

### Requirement: Magic Number 提取为常量

`fullscreen_video_page.dart` 中的手势阈值、触底加载阈值等硬编码数值提取为 `constants.dart` 中的具名常量。

#### Scenario: 硬编码数值检测

- **WHEN** 在 `fullscreen_video_page.dart` 中搜索手势相关数值（如 `0.05`、`200`、`0.1`）
- **THEN** 引用 `constants.dart` 中的常量，不作为裸数值存在

## MODIFIED Requirements

无修改项（本 spec 全部为新增审查范围，已有的 audit-* specs 不在此 spec 修改范围内）。

## REMOVED Requirements

无移除项。

## Constraints

- **不改变现有功能语义**：所有视图与组件的用户可见行为保持不变，除非是修复明确的 bug
- **不引入新依赖**：仅在现有 `flutter_riverpod`、`video_player`、`cached_network_image` 等范围内修改
- **保持向后兼容**：用户已保存的 SharedPreferences 数据、设置项不受影响
- **小步重构**：每个修复独立提交，每步保持代码可工作
- **测试保障**：严重问题修复必须补充回归测试，中等问题可选
- **不重复审查**：已在 `audit-actors-view` / `audit-navigation-bar` / `audit-settings-view` / `fix-homepage-audit` 范围内的文件不重复审查
- **不处理国际化缺失**：全项目国际化改造单独 spec 处理，不在本次范围

## Assumptions

- 项目 Flutter 版本 ≥ 3.27（`withOpacity` 已废弃，`withValues` 可用）
- `toggleFavorite` 是乐观更新，撤销失败时需要显式回滚 UI 状态
- `recommendProvider` 的 `error` 字段在 `clearError` 后会变为 null，`ref.listen` 可正确监听变化
- `LibrarySelector.show` 是已有的媒体库选择器入口，可直接复用
- 长列表懒加载改造不影响现有的滚动位置恢复逻辑（如 `actors_view.dart` 的 `_restoreScrollOffset`）

## Open Questions

- [ ] `favorites_view.dart` 撤销失败时回滚 UI 是否需要等待服务端响应？还是立即回滚 + 后台重试？（建议立即回滚，避免 UI 卡顿）
- [ ] `video_grid_view.dart` 空状态按钮的样式：是 `ElevatedButton` 还是 `OutlinedButton`？（建议 `OutlinedButton`，与项目其他空状态引导一致）
- [ ] `withOpacity` 迁移是否一次性全量迁移？还是分文件分批？（建议全量，避免遗漏）
- [ ] `fullscreen_video_page.dart` Slider 拖动过程中的预览时间显示位置：是替换底部时间文本，还是显示气泡？（建议替换底部时间文本，最小改动）
