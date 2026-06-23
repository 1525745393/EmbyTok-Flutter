# 网格视图按钮遮挡修复 Spec

## Why
媒体库网格视图中，TvFocusable 的边框在获得焦点时会覆盖卡片内容，影响用户体验。

## What Changes
- 调整 TvFocusable 的 borderWidth 和 padding，避免边框覆盖内容
- 确保焦点边框不影响卡片内容的显示

## Impact
- Affected specs: poster_grid_optimization
- Affected code: `lib/widgets/tv_focusable.dart`、`lib/widgets/poster_grid_view.dart`

## ADDED Requirements

### Requirement: 焦点边框不遮挡内容
系统 SHALL 确保 TvFocusable 的焦点边框不会覆盖子组件内容。

#### Scenario: 焦点状态
- **WHEN** 卡片获得焦点时
- **THEN** 边框不影响内容显示，内容完整可见

### Requirement: 响应式列数保持
系统 SHALL 保持网格视图的响应式列数功能（手机3列/平板4-6列）。

#### Scenario: 不同屏幕尺寸
- **WHEN** 在不同尺寸设备上显示网格
- **THEN** 列数自动适应屏幕宽度
