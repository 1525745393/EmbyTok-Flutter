# 底部小面积信息条 - 标题与评分显示 - The Implementation Plan

## [ ] Task 1: 在底部信息条的标题行右侧添加评分显示
- **Priority**: P0
- **Depends On**: None
- **Description**:
  - 修改 `_buildBottomGradient()` 方法中标题部分的 widget 结构（约 [video_page_item.dart:849-858](file:///workspace/frontend/lib/widgets/video_page_item.dart#L849-L858)）
  - 将当前单一 `Text` widget 改为 `Row` widget，左侧为标题 `Text`，右侧为评分 `Text`（如有）
  - 标题 `Text` 需使用 `Expanded` 包装以确保长标题自动截断，评分区域保持固定宽度
  - 评分从 `widget.item.displayRating` 获取，当为 `null` 或 `<= 0` 时不渲染评分 widget
  - 评分格式：`★ ${rating.toStringAsFixed(1)}`，与详情面板 `_InfoChip` 中的「评分」卡片保持一致
  - 评分颜色采用 `primaryPink`（品牌色高亮，与详情面板 `_InfoChip` 视觉一致），字体大小 `14`，字重 `FontWeight.w700`
  - 标题与评分之间使用 `SizedBox(width: 12)` 保持合理间距
- **Acceptance Criteria Addressed**: AC-1, AC-2, AC-3, AC-4, AC-6
- **Test Requirements**:
  - `programmatic` TR-1.1: 代码中存在对 `widget.item.displayRating` 的 null 检查和 `> 0` 检查
  - `programmatic` TR-1.2: 评分 widget 仅在评分有效时被条件渲染（通过 `if` 条件包装）
  - `programmatic` TR-1.3: 标题 `Text` 使用 `Expanded` 包装，评分 `Text` 不使用 `Expanded`
  - `programmatic` TR-1.4: 评分格式字符串与详情面板 `_InfoChip` 中「评分」卡片使用相同的 `'★ ${rating.toStringAsFixed(1)}'`
  - `human-judgement` TR-1.5: 在有评分的视频上，标题和评分在同一行显示，标题左侧，评分右侧，间距合理，视觉协调
  - `human-judgement` TR-1.6: 在长标题（> 40 字符）的视频上，标题文本被 `ellipsis` 截断，评分完整显示在右侧无重叠
  - `human-judgement` TR-1.7: 在无评分的视频上，仅显示标题，不出现任何评分相关元素，视觉效果与修改前一致
- **Notes**: 关键实现结构参考：
  ```dart
  Row(
    crossAxisAlignment: CrossAxisAlignment.baseline,
    textBaseline: TextBaseline.alphabetic,
    children: [
      Expanded(
        child: Text(
          _titleText(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      const SizedBox(width: 12),
      if (widget.item.displayRating != null && widget.item.displayRating! > 0)
        Text(
          '★ ${widget.item.displayRating!.toStringAsFixed(1)}',
          style: const TextStyle(color: primaryPink, fontSize: 14, fontWeight: FontWeight.w700),
        ),
    ],
  )
  ```
  使用 `CrossAxisAlignment.baseline` + `TextBaseline.alphabetic` 确保标题和评分的文字基线对齐（避免评分因字号较小而上浮或下沉）。
