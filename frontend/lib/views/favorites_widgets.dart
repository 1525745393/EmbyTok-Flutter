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
class _SelectableCard extends StatelessWidget {
  const _SelectableCard({
    required this.selectMode,
    required this.selected,
    required this.onTap,
    required this.child,
  });
  final bool selectMode;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!selectMode) return child;
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Stack(
        children: [
          AnimatedOpacity(
            opacity: selected ? _kCardSelectedOpacity : 1,
            duration:
                const Duration(milliseconds: _kCardSelectedAnimationDuration),
            child: child,
          ),
          Positioned(
            top: _kCardBadgeOffset,
            left: _kCardBadgeOffset,
            child: AnimatedContainer(
              duration:
                  const Duration(milliseconds: _kCardBadgeAnimationDuration),
              curve: Curves.easeOutCubic,
              width: _kCardBadgeSize,
              height: _kCardBadgeSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_kCardBadgeRadius),
                border: Border.all(
                  color: selected
                      ? scheme.primary
                      : Colors.white.withValues(alpha: 0.85),
                  width: _kCardBadgeBorderWidth,
                ),
                color: selected
                    ? scheme.primary
                    : Colors.black.withValues(alpha: 0.35),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: scheme.primary.withValues(alpha: 0.35),
                          blurRadius: _kCardBadgeShadowBlurRadius,
                        ),
                      ]
                    : null,
              ),
              child: selected
                  ? Icon(Icons.check,
                      size: _kCardBadgeCheckIconSize, color: scheme.onPrimary)
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// 影片海报卡（点击跳转播放/详情，长按菜单）
class _MoviePosterCard extends ConsumerWidget {
  const _MoviePosterCard({
    required this.item,
    required this.allItems,
  });
  final MediaItem item;
  final List<MediaItem> allItems;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final authState = ref.watch(authProvider);
    final imageUrl = item.thumbnailUrlWithAuth(
      authState.embyServerUrl,
      authState.token,
      maxWidth: _kMoviePosterMaxWidth,
    );
    final headers = item.authHeaders(authState.token);

    return InkWell(
      borderRadius: BorderRadius.circular(_kMoviePosterRadius),
      onTap: () {
        ref
            .read(playbackListProvider.notifier)
            .setPlaybackList(allItems, item.id);
        context.push('/play/${item.id}', extra: item);
      },
      onLongPress: () => _showMenu(context, ref),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_kMoviePosterRadius),
                color: scheme.surfaceContainerHighest,
                border: Border.all(
                    color: scheme.outlineVariant
                        .withValues(alpha: _kMoviePosterBorderAlpha)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_kMoviePosterRadius),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imageUrl != null && imageUrl.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: imageUrl,
                        cacheManager: AppImageCacheManager.thumbnail,
                        fit: BoxFit.cover,
                        httpHeaders: headers.isNotEmpty ? headers : null,
                        memCacheWidth: 400,
                        placeholder: (_, __) => Container(
                          color: scheme.surfaceContainerHighest,
                          child: Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: scheme.primary,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Center(
                          child: Icon(Icons.movie_outlined,
                              color: scheme.onSurfaceVariant, size: 30),
                        ),
                      )
                    else
                      Center(
                        child: Icon(Icons.movie_outlined,
                            color: scheme.onSurfaceVariant, size: 30),
                      ),
                    // 评分角标
                    if ((item.displayRating ?? 0) > 0)
                      Positioned(
                        top: _kHeartBadgeOffset,
                        right: _kHeartBadgeOffset,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(_kRatingBadgeRadius),
                            color: Colors.black
                                .withValues(alpha: _kRatingBadgeBgAlpha),
                          ),
                          child: Text(
                            '★ ${item.displayRating!.toStringAsFixed(1)}',
                            style: TextStyle(
                              color: Colors.amber.shade300,
                              fontSize: _kRatingBadgeFontSize,
                              fontWeight: FontWeight.w700,
                              letterSpacing: _kRatingBadgeLetterSpacing,
                            ),
                          ),
                        ),
                      ),
                    // 心形角标
                    Positioned(
                      bottom: _kHeartBadgeOffset,
                      right: _kHeartBadgeOffset,
                      child: Icon(
                        Icons.favorite,
                        color: scheme.primary,
                        size: _kHeartBadgeSize,
                        shadows: [
                          Shadow(
                            color: scheme.onSurface
                                .withValues(alpha: _kHeartBadgeShadowAlpha),
                            blurRadius: _kHeartBadgeShadowBlurRadius,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: _kMovieTitleSubtitleSpacing),
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: _kMovieTitleFontSize,
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
              height: _kMovieTitleLineHeight,
            ),
          ),
          const SizedBox(height: _kMovieSubtitleBottomSpacing),
          Text(
            _subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: _kMovieSubtitleFontSize,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String get _subtitle {
    final parts = <String>[];
    final y = item.productionYear ?? item.year;
    if (y != null) parts.add('$y');
    if (parts.isEmpty) return item.type;
    return parts.join(' · ');
  }

  void _showMenu(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(_kMenuTopRadius)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    _kMenuPadding, 16, _kMenuPadding, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: _kMenuTitleFontSize,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.favorite_border, color: scheme.error),
                title: Text(_kMenuItemRemoveFavorite,
                    style: TextStyle(color: scheme.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  final notifier = ref.read(favoritesProvider.notifier);
                  notifier.toggleFavorite(item);
                  final messenger = ScaffoldMessenger.of(context);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                          '$_kSnackBarRemovedPrefix${item.title}$_kSnackBarRemovedSuffix'),
                      action: SnackBarAction(
                        label: _kSnackBarUndo,
                        onPressed: () =>
                            _undoUnfavorite(messenger, notifier, item),
                      ),
                      duration: const Duration(seconds: _kSnackBarDuration),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.play_arrow, color: scheme.primary),
                title: const Text(_kMenuItemPlay),
                onTap: () {
                  Navigator.pop(ctx);
                  ref
                      .read(playbackListProvider.notifier)
                      .setPlaybackList(allItems, item.id);
                  context.push('/play/${item.id}', extra: item);
                },
              ),
              ListTile(
                leading:
                    Icon(Icons.info_outline, color: scheme.onSurfaceVariant),
                title: const Text(_kMenuItemViewDetails),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/item/${item.id}', extra: item);
                },
              ),
              const SizedBox(height: _kMenuBottomSpacing),
            ],
          ),
        );
      },
    );
  }
}

/// 合集 ListTile
class _BoxSetTile extends ConsumerWidget {
  const _BoxSetTile({required this.item});
  final MediaItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final authState = ref.watch(authProvider);
    final imageUrl = item.thumbnailUrlWithAuth(
      authState.embyServerUrl,
      authState.token,
      maxWidth: 180,
    );
    final headers = item.authHeaders(authState.token);
    final year = item.productionYear ?? item.year;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => context.push('/boxset/${item.id}', extra: item),
      onLongPress: () => _showMenu(context, ref),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: scheme.surface.withValues(alpha: 0.7),
          border:
              Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            // 缩略方块
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: scheme.tertiary.withValues(alpha: 0.15),
              ),
              clipBehavior: Clip.antiAlias,
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      cacheManager: AppImageCacheManager.thumbnail,
                      fit: BoxFit.cover,
                      httpHeaders: headers.isNotEmpty ? headers : null,
                      errorWidget: (_, __, ___) => Center(
                        child: Icon(Icons.featured_play_list,
                            color: scheme.tertiary, size: 24),
                      ),
                    )
                  : Center(
                      child: Icon(Icons.featured_play_list,
                          color: scheme.tertiary, size: 24),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (year != null) '$year',
                      item.type,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 10.5, color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: scheme.outlineVariant.withValues(alpha: 0.25),
                        ),
                        child: Text(
                          '未看 2',
                          style: TextStyle(
                            fontSize: 10,
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      if ((item.displayRating ?? 0) > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: Colors.amber.withValues(alpha: 0.15),
                          ),
                          child: Text(
                            '★ ${item.displayRating!.toStringAsFixed(1)}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.amber.shade300,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant, size: 18),
          ],
        ),
      ),
    );
  }

  void _showMenu(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  item.title,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.favorite_border, color: scheme.error),
                title: Text('取消收藏', style: TextStyle(color: scheme.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  final notifier = ref.read(favoritesProvider.notifier);
                  notifier.toggleFavorite(item);
                  final messenger = ScaffoldMessenger.of(context);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('已取消收藏「${item.title}」'),
                      action: SnackBarAction(
                        label: '撤销',
                        onPressed: () =>
                            _undoUnfavorite(messenger, notifier, item),
                      ),
                      duration: const Duration(seconds: 5),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              ListTile(
                leading:
                    Icon(Icons.info_outline, color: scheme.onSurfaceVariant),
                title: const Text('查看详情'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/boxset/${item.id}', extra: item);
                },
              ),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
  }
}

/// 人物头像 + 名称
class _PersonTile extends ConsumerWidget {
  const _PersonTile({required this.item});
  final MediaItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final authState = ref.watch(authProvider);
    final imageUrl = item.thumbnailUrlWithAuth(
      authState.embyServerUrl,
      authState.token,
      maxWidth: 160,
    );
    final headers = item.authHeaders(authState.token);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => context.push('/person/${item.id}', extra: item),
      onLongPress: () => _showMenu(context, ref),
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.error.withValues(alpha: 0.12),
                border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.35)),
              ),
              clipBehavior: Clip.antiAlias,
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      cacheManager: AppImageCacheManager.thumbnail,
                      fit: BoxFit.cover,
                      httpHeaders: headers.isNotEmpty ? headers : null,
                      errorWidget: (_, __, ___) => Center(
                        child: Text(
                          item.title.isNotEmpty
                              ? item.title[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: scheme.error.withValues(alpha: 0.65),
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Icon(Icons.person,
                          color: scheme.error.withValues(alpha: 0.65),
                          size: 22),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.5,
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  void _showMenu(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(item.title,
                    style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.favorite_border, color: scheme.error),
                title: Text('取消收藏', style: TextStyle(color: scheme.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  final notifier = ref.read(favoritesProvider.notifier);
                  notifier.toggleFavorite(item);
                  final messenger = ScaffoldMessenger.of(context);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('已取消收藏「${item.title}」'),
                      action: SnackBarAction(
                        label: '撤销',
                        onPressed: () =>
                            _undoUnfavorite(messenger, notifier, item),
                      ),
                      duration: const Duration(seconds: 5),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              ListTile(
                leading:
                    Icon(Icons.info_outline, color: scheme.onSurfaceVariant),
                title: const Text('查看详情'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/person/${item.id}', extra: item);
                },
              ),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
  }
}

/// 影片/人物：更多卡片
class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.remaining,
    required this.hasMore,
    required this.onTap,
  });
  final int remaining;
  final bool hasMore;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final suffix = hasMore ? '…' : '';
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: scheme.outlineVariant.withValues(alpha: 0.18),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.4),
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.grid_view_outlined,
                color: scheme.onSurfaceVariant, size: 24),
            const SizedBox(height: 6),
            Text(
              '+$remaining$suffix',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              '查看全部',
              style: TextStyle(
                fontSize: 9.5,
                color: scheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MorePersonTile extends StatelessWidget {
  const _MorePersonTile({required this.remaining, required this.onTap});
  final int remaining;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.outlineVariant.withValues(alpha: 0.2),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.4),
                  style: BorderStyle.solid,
                ),
              ),
              child: Center(
                child: Text(
                  '+$remaining',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '更多',
            style: TextStyle(
              fontSize: 10.5,
              color: scheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadMoreHint extends StatelessWidget {
  const _LoadMoreHint({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.expand_more, size: 14, color: scheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              '点击加载更多（查看全部完整列表）',
              style: TextStyle(
                fontSize: 10.5,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 搜索无结果提示卡：给出明确无结果文案 + 一键清空搜索词「返回」全量列表
///
/// 设计动机：用户输入一个不存在的词后，若直接让搜索框消失就会「无法返回」；
/// 这里同时保留搜索框（用户可点 × 清空）并增加显式「清空搜索词」按钮，
/// 提供双路径返回全量收藏内容。
class _SearchNoResultHint extends StatelessWidget {
  const _SearchNoResultHint({
    required this.query,
    required this.onClear,
  });
  final String query;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(18, 26, 18, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        border:
            Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 56, color: scheme.onSurfaceVariant),
          const SizedBox(height: 14),
          Text(
            '没有找到「$query」',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '可以换个关键词试试，或直接清空搜索词返回全部收藏',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.clear_all, size: 16),
                label: const Text('清空搜索词'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: scheme.primary,
                  side:
                      BorderSide(color: scheme.primary.withValues(alpha: 0.55)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 撤销取消收藏
// ============================================================

/// 撤销取消收藏：重新收藏，失败时提示用户
///
/// 与原实现一致：FavoritesNotifier.toggleFavorite 采用乐观更新 + 失败回滚，
/// 通过 isFavorite 判定撤销结果，避免依赖异常机制。
Future<void> _undoUnfavorite(
  ScaffoldMessengerState messenger,
  FavoritesNotifier notifier,
  MediaItem item,
) async {
  await notifier.toggleFavorite(item);
  if (!notifier.isFavorite(item.id)) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('撤销失败，请重试'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

// ============================================================
// 二级分类详情页（保持原有实现，不改动）
// FavoritesCategoryView / _GridCard
// ============================================================

class _FavoritesCategoryViewState extends ConsumerState<FavoritesCategoryView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(favoritesProvider.notifier).ensureLoaded();
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final offset = _scrollController.position.pixels;
    final maxExtent = _scrollController.position.maxScrollExtent;
    if (offset >= maxExtent - 300) {
      final state = ref.read(favoritesProvider);
      final hasMore = switch (widget.category) {
        FavoritesCategory.movie => state.hasMoreMovies,
        FavoritesCategory.boxSet => state.hasMoreBoxSets,
        FavoritesCategory.person => state.hasMorePeople,
      };
      if (hasMore && !state.isLoadingMore) {
        ref.read(favoritesProvider.notifier).loadMore(widget.category);
      }
    }
  }

  String get _title {
    return switch (widget.category) {
      FavoritesCategory.movie => '收藏影片',
      FavoritesCategory.boxSet => '收藏合集',
      FavoritesCategory.person => '收藏人物',
    };
  }

  List<MediaItem> _items(FavoritesState state) {
    return switch (widget.category) {
      FavoritesCategory.movie => state.movies,
      FavoritesCategory.boxSet => state.boxSets,
      FavoritesCategory.person => state.people,
    };
  }

  String? _error(FavoritesState state) {
    return switch (widget.category) {
      FavoritesCategory.movie => state.moviesError,
      FavoritesCategory.boxSet => state.boxSetsError,
      FavoritesCategory.person => state.peopleError,
    };
  }

  bool _hasMore(FavoritesState state) {
    return switch (widget.category) {
      FavoritesCategory.movie => state.hasMoreMovies,
      FavoritesCategory.boxSet => state.hasMoreBoxSets,
      FavoritesCategory.person => state.hasMorePeople,
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final state = ref.watch(favoritesProvider);
    final items = _items(state);
    final error = _error(state);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_title),
            const SizedBox(width: 8),
            Text(
              '${items.length}',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: state.isLoading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.onSurfaceVariant,
                    ),
                  )
                : Icon(Icons.refresh, color: scheme.onSurfaceVariant, size: 22),
            onPressed: state.isLoading
                ? null
                : () => ref.read(favoritesProvider.notifier).loadFavorites(),
            tooltip: '刷新',
          ),
        ],
      ),
      body: _buildBody(state, items, error, scheme),
    );
  }

  Widget _buildBody(
    FavoritesState state,
    List<MediaItem> items,
    String? error,
    ColorScheme scheme,
  ) {
    if (state.isLoading && items.isEmpty && error == null) {
      return Center(child: CircularProgressIndicator(color: scheme.primary));
    }

    if (error != null && items.isEmpty) {
      return ErrorStateCard(
        title: error,
        actionLabel: '重试',
        onAction: () => ref.read(favoritesProvider.notifier).loadFavorites(),
      );
    }

    if (items.isEmpty) {
      return EmptyStateCard.noFavorites();
    }

    final crossAxisCount = widget.category == FavoritesCategory.person ? 4 : 3;
    final aspectRatio =
        widget.category == FavoritesCategory.person ? 0.7 : 0.65;
    final hasMore = _hasMore(state);

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: aspectRatio,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: items.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (hasMore && index == items.length) {
          return Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.primary,
              ),
            ),
          );
        }
        final item = items[index];
        return _GridCard(
          key: Key(item.id),
          item: item,
          category: widget.category,
          allItems: items,
        );
      },
    );
  }
}

class _GridCard extends ConsumerWidget {
  const _GridCard({
    super.key,
    required this.item,
    required this.category,
    required this.allItems,
  });
  final MediaItem item;
  final FavoritesCategory category;
  final List<MediaItem> allItems;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final authState = ref.watch(authProvider);
    final imageUrl = item.thumbnailUrlWithAuth(
      authState.embyServerUrl,
      authState.token,
      maxWidth: 300,
    );
    final headers = item.authHeaders(authState.token);

    return InkWell(
      onTap: () => _navigateTo(context, ref),
      onLongPress: () => _showLongPressMenu(context, ref),
      borderRadius: BorderRadius.circular(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: scheme.surfaceContainerHighest,
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imageUrl != null && imageUrl.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: imageUrl,
                        cacheManager: AppImageCacheManager.thumbnail,
                        fit: BoxFit.cover,
                        httpHeaders: headers.isNotEmpty ? headers : null,
                        memCacheWidth: 600,
                        placeholder: (_, __) => Container(
                          color: scheme.surfaceContainerHighest,
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: scheme.primary,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        ),
                        errorWidget: (_, __, ___) =>
                            _gridPlaceholder(category, scheme),
                      )
                    else
                      _gridPlaceholder(category, scheme),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Icon(
                        Icons.favorite,
                        color: scheme.primary,
                        size: 16,
                        shadows: [
                          Shadow(
                            color: scheme.onSurface.withValues(alpha: 0.3),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _subtitle(item),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _gridPlaceholder(FavoritesCategory cat, ColorScheme scheme) {
    final icon = switch (cat) {
      FavoritesCategory.person => Icons.person,
      FavoritesCategory.boxSet => Icons.featured_play_list,
      FavoritesCategory.movie => Icons.movie_outlined,
    };
    return Center(child: Icon(icon, color: scheme.onSurfaceVariant, size: 36));
  }

  String _subtitle(MediaItem item) {
    if (category == FavoritesCategory.person) return '演员';
    final parts = <String>[];
    final year = item.productionYear ?? item.year;
    if (year != null) parts.add(year.toString());
    final rating = item.displayRating;
    if (rating != null && rating > 0) {
      parts.add('★ ${rating.toStringAsFixed(1)}');
    }
    if (parts.isEmpty) return item.type;
    return parts.join(' · ');
  }

  void _navigateTo(BuildContext context, WidgetRef ref) {
    switch (category) {
      case FavoritesCategory.movie:
        ref
            .read(playbackListProvider.notifier)
            .setPlaybackList(allItems, item.id);
        context.push('/play/${item.id}', extra: item);
        break;
      case FavoritesCategory.boxSet:
        context.push('/boxset/${item.id}', extra: item);
        break;
      case FavoritesCategory.person:
        context.push('/person/${item.id}', extra: item);
        break;
    }
  }

  void _showLongPressMenu(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.favorite_border, color: scheme.error),
                title: Text('取消收藏', style: TextStyle(color: scheme.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  final notifier = ref.read(favoritesProvider.notifier);
                  notifier.toggleFavorite(item);
                  final messenger = ScaffoldMessenger.of(context);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('已取消收藏「${item.title}」'),
                      action: SnackBarAction(
                        label: '撤销',
                        onPressed: () =>
                            _undoUnfavorite(messenger, notifier, item),
                      ),
                      duration: const Duration(seconds: 5),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              if (category == FavoritesCategory.movie)
                ListTile(
                  leading: Icon(Icons.play_arrow, color: scheme.primary),
                  title: const Text('播放'),
                  onTap: () {
                    Navigator.pop(ctx);
                    ref
                        .read(playbackListProvider.notifier)
                        .setPlaybackList(allItems, item.id);
                    context.push('/play/${item.id}', extra: item);
                  },
                ),
              ListTile(
                leading:
                    Icon(Icons.info_outline, color: scheme.onSurfaceVariant),
                title: const Text('查看详情'),
                onTap: () {
                  Navigator.pop(ctx);
                  switch (category) {
                    case FavoritesCategory.movie:
                      context.push('/item/${item.id}', extra: item);
                      break;
                    case FavoritesCategory.boxSet:
                      context.push('/boxset/${item.id}', extra: item);
                      break;
                    case FavoritesCategory.person:
                      context.push('/person/${item.id}', extra: item);
                      break;
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
