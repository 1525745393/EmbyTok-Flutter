# 底部小面积信息条 - 标题与评分显示 - Product Requirement Document

## Overview
- **Summary**: 在视频页面底部的小面积信息条中，除当前已有的视频标题外，新增显示评分字段（★ + 数字），使播放时可直观获取视频的关键信息。
- **Purpose**: 用户在滑动浏览视频时，标题与评分是最核心的决策要素。当前仅显示标题与简介，评分需要点击信息按钮才能查看，操作成本较高。在底部信息条直接呈现评分可显著降低信息获取成本。
- **Target Users**: 所有使用 EmbyTok 浏览竖屏视频的用户，包括新用户和重度用户。

## Goals
- 在底部信息条的标题行右侧以紧凑方式显示评分（★ + 数字，保留 1 位小数）
- 保持现有底部信息条的视觉层次与布局风格，不引入破坏性改动
- 评分数据为空或无效时自动隐藏评分显示，不产生空占位
- 与视频详情面板中「评分」信息卡片的格式保持一致

## Non-Goals (Out of Scope)
- 不改变底部信息条的渐变色、高度或整体布局结构
- 不增加评分点击交互（不做跳转详情或其他操作）
- 不修改简介、类型标签等其他信息条元素
- 不修改右侧操作区的信息按钮功能
- 不引入新的评分数据源（仅使用 MediaItem 已有的 communityRating/rating 字段）

## Background & Context
1. **现有底部信息条**（见 [video_page_item.dart](file:///workspace/frontend/lib/widgets/video_page_item.dart#L799-L874) 的 `_buildBottomGradient()`）:
   - 结构: 类型标签 → 标题（maxLines=2）→ 简介（maxLines=1）
   - 标题通过私有方法 `_titleText()` 返回，格式为 `标题 (年份)` 或仅 `标题`
   - 整体位于底部带黑→透明渐变的背景之上
   - 受 `_isInfoExpanded` 和 `isAutoPlay` 控制显示/隐藏

2. **评分数据源**（见 [media_item.dart](file:///workspace/frontend/lib/models/media_item.dart#L287-L288)）:
   - `MediaItem.communityRating`（double?, 1-10 范围）
   - `MediaItem.rating`（兼容字段，与 communityRating 同义）
   - 便捷属性 `displayRating` → `communityRating ?? rating`

3. **参考格式**（见 [video_page_item.dart](file:///workspace/frontend/lib/widgets/video_page_item.dart#L1360-L1363) 的详情面板 `_InfoChip`）:
   - 评分显示格式为 `★ 8.5`（保留 1 位小数）

## Functional Requirements
- **FR-1**: 底部信息条的标题区域应显示评分信息
- **FR-2**: 评分显示格式为 `★ X.X`（保留 1 位小数），与详情面板 `_InfoChip` 中「评分」卡片保持一致
- **FR-3**: 评分显示在标题行右侧，与标题在同一行，不独占新行
- **FR-4**: 当评分数据为空（`null`）或 <= 0 时，自动隐藏评分显示，仅保留标题
- **FR-5**: 评分文字颜色与标题保持一致（白色 `textPrimary`），字体大小略小于标题但仍清晰可读
- **FR-6**: 评分数字使用与 `_InfoChip` 一致的视觉风格（可选：评分数字采用品牌色 `primaryPink` 强调）

## Non-Functional Requirements
- **NFR-1 (性能)**: 评分字段获取和格式化不产生任何额外异步操作或性能开销（纯本地数据读取）
- **NFR-2 (兼容性)**: 不改变现有方法签名与对外接口，不影响其他模块对 `MediaItem` 的使用
- **NFR-3 (代码风格)**: 遵循现有代码风格（使用 const 构造函数、`primaryPink`/`textPrimary` 颜色常量等）
- **NFR-4 (健壮性)**: 评分字段为 null 时不导致运行时异常或布局错误

## Constraints
- **技术约束**: Flutter 3.10+ / Dart 3.0+（由 `pubspec.yaml` 的 SDK 约束确定）
- **UI 框架约束**: 使用现有颜色常量（`textPrimary`、`primaryPink`）和 `Text` widget，不引入新依赖
- **空间约束**: 标题已有 `maxLines: 2`，增加评分后标题区域总高度不应显著增加；当标题过长时标题文本自动截断，评分保持在右侧固定位置

## Assumptions
- 评分数据通过 Emby/Plex API 正常返回，范围 1-10，部分视频可能无评分数据
- 底部信息条在竖屏浏览时为主要信息展示区域，横屏模式下已被隐藏（不受影响）
- `widget.item.displayRating` 返回的评分值在 null 检查后可安全调用

## Acceptance Criteria

### AC-1: 评分在底部信息条正确显示
- **Given**: 视频具有有效的评分（`displayRating != null && > 0`）
- **When**: 用户在竖屏模式下查看视频页面
- **Then**: 底部信息条的标题行右侧显示 `★ X.X`（保留 1 位小数），例如 `★ 8.5`
- **Verification**: `human-judgment`
- **Notes**: 需在真机或模拟器上验证显示效果

### AC-2: 评分空值时自动隐藏
- **Given**: 视频无评分数据（`displayRating == null` 或 `<= 0`）
- **When**: 用户查看视频页面
- **Then**: 底部信息条的标题行仅显示标题文本，不出现评分相关内容，视觉效果与修改前一致
- **Verification**: `programmatic`
- **Notes**: 可通过代码审查确认有明确的 null 检查逻辑

### AC-3: 评分格式与详情面板保持一致
- **Given**: 视频同时显示底部信息条和详情面板
- **When**: 点击信息按钮打开详情面板后
- **Then**: 详情面板中「评分」卡片的数字格式与底部信息条评分显示完全一致（相同的 ★ 符号、小数位数）
- **Verification**: `human-judgment`
- **Notes**: 确认格式字符串 `★ ${rating.toStringAsFixed(1)}` 在两处使用

### AC-4: 长标题与评分共存时布局正确
- **Given**: 视频标题较长（接近或超过一行）
- **When**: 同时显示标题和评分
- **Then**: 标题文本自动截断（`TextOverflow.ellipsis`），评分保持在右侧固定位置不被压缩或换行；标题区域总高度不超过两行高度
- **Verification**: `human-judgment`
- **Notes**: 测试用例应包含超长篇标题（> 40 个字符的中文标题）

### AC-5: 不引入编译错误
- **Given**: 修改提交到 GitHub
- **When**: CI 执行 `flutter analyze` 代码分析
- **Then**: 不产生任何 `error` 级别的问题，CI 构建成功
- **Verification**: `programmatic`
- **Notes**: 确保不使用 Dart 3.3+ 专属 API（如 `Color.withValues()`）

### AC-6: 不影响其他信息条元素
- **Given**: 底部信息条包含类型标签、标题、评分、简介
- **When**: 视频页面渲染
- **Then**: 类型标签位置不变（顶部左侧）、简介位置不变（底部），视觉层次与修改前保持一致
- **Verification**: `human-judgment`

## Open Questions
- [ ] **Q1**: 评分数字是否需要用品牌色（`primaryPink`）高亮显示，还是与标题使用相同的白色？（参考详情面板 `_InfoChip` 中「评分」使用高亮效果）
- [ ] **Q2**: 是否需要在评分数字前增加一个小间距（如 `SizedBox(width: 12)`）使其与标题文本保持合理距离？
