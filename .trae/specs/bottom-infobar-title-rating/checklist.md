# 底部小面积信息条 - 标题与评分显示 - Verification Checklist

## 功能正确性

- [ ] Checkpoint 1: 在有有效评分的视频上，底部信息条标题行右侧显示 `★ X.X` 格式的评分
- [ ] Checkpoint 2: 在无评分（`displayRating == null`）的视频上，底部信息条标题行仅显示标题，不出现评分元素
- [ ] Checkpoint 3: 在评分为 0 或负值（异常数据）的视频上，评分自动隐藏
- [ ] Checkpoint 4: 评分数字保留 1 位小数（如 `8.0`、`7.5`）

## 布局与视觉

- [ ] Checkpoint 5: 评分显示在标题行右侧，与标题在同一行（不独占新行）
- [ ] Checkpoint 6: 标题与评分之间有合理间距（约 12px）
- [ ] Checkpoint 7: 长标题（> 40 字符中文）时自动截断为省略号，评分完整显示在右侧无重叠、无被压缩
- [ ] Checkpoint 8: 标题和评分文字基线对齐（baseline 对齐），不因字号差异出现视觉错位
- [ ] Checkpoint 9: 评分文字颜色为 `primaryPink`（品牌色），字体大小约 14，字重加粗
- [ ] Checkpoint 10: 类型标签位置不变（仍在标题上方左侧）
- [ ] Checkpoint 11: 简介位置不变（仍在标题下方）
- [ ] Checkpoint 12: 整体布局高度与修改前保持一致（不产生额外行高）

## 与详情面板一致性

- [ ] Checkpoint 13: 底部信息条的评分格式（`★ X.X`）与详情面板「评分」`_InfoChip` 卡片的格式完全一致
- [ ] Checkpoint 14: 底部信息条与详情面板显示的评分数值相同（来自同一数据源 `displayRating`）

## 代码质量

- [ ] Checkpoint 15: 标题 `Text` widget 使用 `Expanded` 包装以确保正确的 flex 布局行为
- [ ] Checkpoint 16: 评分 widget 使用 `if` 条件语句包装（条件为 `displayRating != null && > 0`）
- [ ] Checkpoint 17: 无语法错误，`flutter analyze` 不产生 `error` 级别的问题
- [ ] Checkpoint 18: 不使用 Flutter 3.19+ 专属 API（如 `Color.withValues()`），保持对 SDK `>=3.0.0` 的兼容
- [ ] Checkpoint 19: 代码风格与周边一致（使用 const 构造函数、颜色常量 `textPrimary`/`primaryPink`）

## 边界场景

- [ ] Checkpoint 20: 标题为单行时，评分显示在同一行右侧
- [ ] Checkpoint 21: 标题为两行（达到 `maxLines: 2`）时，评分显示在右侧，不影响标题两行布局
- [ ] Checkpoint 22: 横屏全屏模式下，底部信息条已被隐藏（由 `_isFullscreen` 控制），不产生额外影响
- [ ] Checkpoint 23: 在 `_isInfoExpanded` 为 true/false 两种状态下，评分显示行为一致
