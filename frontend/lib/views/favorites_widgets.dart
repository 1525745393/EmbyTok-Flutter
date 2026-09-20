// 从 favorites_view.dart 拆分（part 文件，无行为变化）

// 从 favorites_view.dart 拆分（part 文件，无行为变化）

part of 'favorites_view.dart';

// ==================== 收藏页辅助组件 ====================

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.count,
    required this.icon,
    required this.bgColor,
    required this.fgColor,
  });
  final String label;
  final int count;
  final IconData icon;
  final Color bgColor;
  final Color fgColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border:
            Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: bgColor,
            ),
            child: Icon(icon, color: fgColor, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// 可折叠分组：标题 + 状态/数量 + chevron + 内容
class _GroupSection extends StatelessWidget {
  const _GroupSection({
    super.key,
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.count,
    required this.recentLabel,
    required this.error,
    required this.onRetry,
    required this.isOpen,
    required this.onToggleOpen,
    required this.onViewAll,
    required this.child,
  });
  final String title;
  final IconData icon;
  final Color accentColor;
  final int count;
  final String recentLabel;
  final String? error;
  final VoidCallback? onRetry;
  final bool isOpen;
  final VoidCallback onToggleOpen;
  final VoidCallback? onViewAll;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行（可点击折叠）
          Material(
            color: Colors.transparent,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: InkWell(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              onTap: onToggleOpen,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: accentColor.withValues(alpha: 0.15),
                      ),
                      child: Icon(icon, color: accentColor, size: 17),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: scheme.onSurface,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 1.5),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  color: scheme.outlineVariant
                                      .withValues(alpha: 0.3),
                                ),
                                child: Text(
                                  '$count',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 1),
                          Text(
                            recentLabel,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: error != null
                                  ? scheme.error
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (onViewAll != null && count > 0)
                      TextButton(
                        onPressed: onViewAll,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '全部',
                              style: TextStyle(
                                  color: scheme.primary, fontSize: 12),
                            ),
                            const SizedBox(width: 1),
                            Icon(Icons.chevron_right,
                                color: scheme.primary, size: 16),
                          ],
                        ),
                      ),
                    const SizedBox(width: 2),
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: scheme.surface.withValues(alpha: 0.7),
                      ),
                      child: AnimatedRotation(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                        turns: isOpen ? 0.25 : 0,
                        child: Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),
          ),
          // 分组错误提示
          if (error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: scheme.error, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      error!,
                      style: TextStyle(color: scheme.error, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (onRetry != null)
                    TextButton(
                      onPressed: onRetry,
                      child: const Text('重试', style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
            ),
          // 分组内容（AnimatedCrossFade 平滑折叠）
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 280),
            firstCurve: Curves.easeOutCubic,
            secondCurve: Curves.easeOutCubic,
            sizeCurve: Curves.easeOutCubic,
            crossFadeState:
                isOpen ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

/// 图标按钮：批量操作栏用
class _IconAction extends StatelessWidget {
  const _IconAction({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final disabled = onTap == null;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: scheme.onSurface.withValues(alpha: disabled ? 0.03 : 0.06),
          ),
          child: Icon(
            icon,
            size: 17,
            color: disabled
                ? scheme.onSurfaceVariant.withValues(alpha: 0.35)
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// 分组内容：影片网格 / 合集列表 / 人物网格
// ============================================================

/// 影片 3 列网格（可预览最多 6 张 + 加载更多 + 全选）
class _MovieGrid extends StatelessWidget {
  const _MovieGrid({
    required this.items,
    required this.allItems,
    required this.selectMode,
    required this.selectedIds,
    required this.onToggle,
    required this.onToggleAll,
    required this.allSelected,
    required this.hasMore,
    required this.onLoadMore,
  });
  final List<MediaItem> items;
  final List<MediaItem> allItems;
  final bool selectMode;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggle;
  final VoidCallback onToggleAll;
  final bool allSelected;
  final bool hasMore;
  final VoidCallback onLoadMore;

  // 预览数量：分组内只显示前 6 张（更多请进"全部"页面）
  static const int _previewMax = _kMovieGridPreviewCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final preview = items.take(_previewMax).toList();
    final showMoreTile = items.length > _previewMax || hasMore;

    return Column(
      children: [
        // 全选提示条
        if (selectMode && items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 4, 2, 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: onToggleAll,
                  child: Container(
                    width: _kSelectCheckboxSize,
                    height: _kSelectCheckboxSize,
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(_kSelectCheckboxRadius),
                      border: Border.all(
                        color: allSelected
                            ? scheme.primary
                            : scheme.outlineVariant,
                        width: _kSelectCheckboxBorderWidth,
                      ),
                      color: allSelected ? scheme.primary : Colors.transparent,
                    ),
                    child: allSelected
                        ? Icon(Icons.check,
                            size: _kSelectCheckIconSize,
                            color: scheme.onPrimary)
                        : null,
                  ),
                ),
                const SizedBox(width: _kSelectHintSpacing),
                Text(
                  allSelected ? '取消全选本组影片' : '全选本组影片',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: _kSelectHintFontSize,
                  ),
                ),
              ],
            ),
          ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _kMovieGridCrossAxisCount,
            childAspectRatio: _kMovieGridChildAspectRatio,
            crossAxisSpacing: _kGridCrossAxisSpacing,
            mainAxisSpacing: _kGridMainAxisSpacing,
          ),
          itemCount: preview.length + (showMoreTile ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == preview.length) {
              return _MoreTile(
                remaining: (items.length - _previewMax).clamp(0, 1 << 31),
                hasMore: hasMore,
                onTap: () => context.push('/favorites/category/movie'),
              );
            }
            final item = preview[index];
            return _SelectableCard(
              selectMode: selectMode,
              selected: selectedIds.contains(item.id),
              onTap: () => onToggle(item.id),
              child: _MoviePosterCard(
                item: item,
                allItems: allItems,
              ),
            );
          },
        ),
        if (hasMore)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _LoadMoreHint(onTap: onLoadMore),
          ),
      ],
    );
  }
}

/// 合集列表：横向 ListTile 风格
class _BoxSetList extends StatelessWidget {
  const _BoxSetList({
    required this.items,
    required this.allItems,
    required this.selectMode,
    required this.selectedIds,
    required this.onToggle,
  });
  final List<MediaItem> items;
  final List<MediaItem> allItems;
  final bool selectMode;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 预览最多 3 条合集
    final preview = items.take(3).toList();
    final showMore = items.length > 3;
    return Column(
      children: [
        ...preview.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _SelectableCard(
              selectMode: selectMode,
              selected: selectedIds.contains(item.id),
              onTap: () => onToggle(item.id),
              child: _BoxSetTile(item: item),
            ),
          ),
        ),
        if (showMore)
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => context.push('/favorites/category/boxset'),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '还有 ${items.length - 3} 个合集 →',
                    style: TextStyle(
                      color: scheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// 人物 4 列头像网格
class _PersonGrid extends StatelessWidget {
  const _PersonGrid({
    required this.items,
    required this.selectMode,
    required this.selectedIds,
    required this.onToggle,
  });
  final List<MediaItem> items;
  final bool selectMode;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final preview = items.take(_kPersonGridPreviewCount).toList();
    final showMore = items.length > _kPersonGridPreviewCount;
    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _kPersonGridCrossAxisCount,
            childAspectRatio: _kPersonGridChildAspectRatio,
            crossAxisSpacing: _kPersonGridCrossAxisSpacing,
            mainAxisSpacing: _kPersonGridMainAxisSpacing,
          ),
          itemCount: preview.length + (showMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == preview.length) {
              return _MorePersonTile(
                remaining:
                    (items.length - _kPersonGridPreviewCount).clamp(0, 1 << 31),
                onTap: () => context.push('/favorites/category/person'),
              );
            }
            final item = preview[index];
            return _SelectableCard(
              selectMode: selectMode,
              selected: selectedIds.contains(item.id),
              onTap: () => onToggle(item.id),
              child: _PersonTile(item: item),
            );
          },
        ),
      ],
    );
  }
}

// ============================================================
// 原子组件：海报卡 / 合集卡 / 人物卡 / MoreTile / LoadMore
// ============================================================

/// 选择包装：左上角勾选角标（选择模式下可点击切换选中）
