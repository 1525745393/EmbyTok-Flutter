# 设置页面审查与修复 - 规范

## Why

`frontend/lib/views/settings_view.dart`（3527 行）是应用中功能最密集的页面之一，承载 25+ 个设置项、12 个对话框、APK 在线更新、日志导出、许可证页等能力。近期多次增量开发（PR #66/#78/#79/#81/#85/#88/#89）累积了若干交互反馈缺陷、性能隐患与代码规范问题。本次审查目的是在不破坏现有功能的前提下，修复确认存在的问题，提升交互反馈一致性、IO 效率与代码可维护性。

## What Changes

- **修复 3 个 RadioListTile 对话框选中无视觉反馈**：`_showRecommendHalfLifeDaysDialog`、`_showAntiFatigueDaysDialog`、`_showUserRatingMinDialog` 选中后立即 pop，未更新 `current` 局部变量
- **优化 2 个 Slider 对话框的频繁写入**：`_showRecommendRatingDialog`、`_showRecommendRuntimeDialog` 拖动时每次 `onChanged` 都写入 provider，改为拖动结束时写入（`onChangeEnd`）
- **消除硬编码颜色违规**：`_showDonateDialog`、`_showAboutDialog` 中的 `Color(0xFF07C160)`、`Color(0xFF1677FF)`、`Colors.red`、`Colors.white` 等迁移至主题或白名单
- **完善 `_formatSize` 单位**：增加 GB 单位支持
- **修正误导性文案**：`_buildGestureControlTile` subtitle 从"配置滑动和双击手势"改为"查看手势说明"
- **优化重置设置流程**：`_showResetSettingsDialog` 去除"请重启应用"误导提示（应用内无重启功能），改为说明设置已立即生效
- **重构 `_RecommendAdvancedTile` 分隔线逻辑**：替换 `..removeLast()` 为更清晰的实现
- **保留国际化缺失问题**：本次不在范围内（涉及全项目改造，单独 spec 处理）

## Impact

- **Affected specs**: `settings-persistence`（持久化机制不变）、`notch-safe-area-adaptation`（刘海适配不变）
- **Affected code**:
  - `frontend/lib/views/settings_view.dart`（主要修改文件）
  - `frontend/lib/theme/app_theme.dart`（如需扩展主题色定义）
  - `frontend/tool/lints/hardcoded_color_allowlist.json`（如需添加品牌色白名单）
- **Affected tests**: 现有设置页相关测试需补充选中反馈、Slider 写入时机、缓存大小格式化等用例

## ADDED Requirements

### Requirement: 对话框选中即时反馈

设置页中所有使用 `RadioListTile` 的选择对话框，在用户点击选项后、关闭对话框前，应立即在 UI 上反映选中状态（高亮当前选项），而非立即关闭对话框无视觉反馈。

#### Scenario: 单选对话框选中反馈

- **WHEN** 用户在"记忆半衰期"、"不重推天数"、"最低用户评分"对话框中点击某选项
- **THEN** 该选项立即显示为选中状态（RadioListTile 高亮 + check 图标），对话框保持打开
- **AND** 用户可继续切换选项或点击"完成"关闭

### Requirement: Slider 拖动写入时机优化

设置页中所有使用 `Slider` 的对话框（评分阈值、最短时长），应在拖动结束时（`onChangeEnd`）写入持久化 provider，而非拖动过程中（`onChanged`）每次写入，避免频繁磁盘 IO。

#### Scenario: Slider 拖动过程不写入

- **WHEN** 用户拖动评分阈值 Slider
- **THEN** 拖动过程中 UI 实时更新显示值（通过 `setDialogState`）
- **AND** 仅在松手（`onChangeEnd`）时调用 `provider.setRating(v)` 写入持久化

### Requirement: 颜色规范合规

设置页所有颜色使用应符合项目 `hardcoded_color_lint` 规则，品牌色（微信绿、支付宝蓝）应加入白名单或迁移至主题。

#### Scenario: 硬编码颜色检测通过

- **WHEN** 运行 `dart run tool/lints/hardcoded_color_lint.dart --path lib/views/settings_view.dart`
- **THEN** 退出码为 0，无违规报告

### Requirement: 缓存大小格式化支持 GB

`_formatSize` 方法应正确显示 B / KB / MB / GB 四档单位。

#### Scenario: 大缓存显示 GB

- **WHEN** `cacheSize` 超过 1GB
- **THEN** subtitle 显示形如 "1.2 GB"

### Requirement: 文案与实际功能一致

设置项 subtitle 应准确描述点击后的实际行为，不得误导用户。

#### Scenario: 手势控制文案修正

- **WHEN** 用户查看"手势控制"设置项
- **THEN** subtitle 显示"查看手势说明"（而非"配置滑动和双击手势"）

### Requirement: 重置设置流程准确

重置设置对话框不应提示用户"请重启应用"，因为应用内无重启功能，且设置实际上在 provider 重新读取后立即生效。

#### Scenario: 重置后无重启提示

- **WHEN** 用户点击"重置设置"并确认
- **THEN** SnackBar 提示"设置已重置并立即生效"
- **AND** 不出现"请重启应用"字样

## MODIFIED Requirements

### Requirement: `_RecommendAdvancedTile` 分隔线实现

将 `..removeLast()` 的分隔线处理替换为更清晰的实现，提升可读性与可维护性，行为保持不变（高级选项展开时各项之间有分隔线，最后一项无分隔线）。

## REMOVED Requirements

无移除项。

## Open Questions

- [ ] 微信绿 `#07C160`、支付宝蓝 `#1677FF` 是否应作为品牌色加入 `hardcoded_color_allowlist.json`？还是应抽象为 `DonateColors` 主题扩展？（需用户决策）
- [ ] Slider 拖动写入时机优化后，是否需要在拖动过程中预览显示值（如 Rating 拖动时实时显示 "≥ 7.5"）？当前实现已通过 `setDialogState` 实现预览，需确认保留。

## Constraints

- **不改变现有功能语义**：所有设置项的存储键、默认值、行为不变
- **不引入新依赖**：仅在现有 `flutter_riverpod`、`shared_preferences` 范围内修改
- **保持向后兼容**：用户已存储的设置数据不受影响
- **小步重构**：每个修复独立提交，每步保持代码可工作

## Assumptions

- `AppPreferencesService` 的写入操作是同步阻塞的磁盘 IO（SharedPreferences 在 Android 上是同步的）
- 用户在设置页停留时间足够短，Slider 拖动优化不会显著影响用户感知延迟
- 现有 `hardcoded_color_lint` 工具的检测逻辑（正则匹配）不变
