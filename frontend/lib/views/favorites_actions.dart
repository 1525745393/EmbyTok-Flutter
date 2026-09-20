// 从 favorites_view.dart 拆分（part 文件，无行为变化）

part of 'favorites_view.dart';

// ==================== 收藏筛选 / 批量操作 / 统计 ====================

extension _FavoritesActions on _FavoritesViewState {
  List<MediaItem> _filter(List<MediaItem> items) {
    var result = items;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result =
          result.where((item) => item.title.toLowerCase().contains(q)).toList();
    }
    return _sort(result);
  }

  List<MediaItem> _sort(List<MediaItem> items) {
    if (_sortMode == FavoritesSortMode.defaultOrder) return items;
    final sorted = List<MediaItem>.from(items);
    switch (_sortMode) {
      case FavoritesSortMode.nameAsc:
        sorted.sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case FavoritesSortMode.yearDesc:
        sorted.sort((a, b) {
          final ya = a.productionYear ?? a.year ?? 0;
          final yb = b.productionYear ?? b.year ?? 0;
          return yb.compareTo(ya);
        });
        break;
      case FavoritesSortMode.ratingDesc:
        sorted.sort((a, b) {
          final ra = a.displayRating ?? 0;
          final rb = b.displayRating ?? 0;
          return rb.compareTo(ra);
        });
        break;
      case FavoritesSortMode.defaultOrder:
        // 已在方法开头处理，这里不会到达
        break;
    }
    return sorted;
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _toggleSelectAll(Iterable<String> ids) {
    final allSelected = ids.every((id) => _selectedIds.contains(id));
    setState(() {
      if (allSelected) {
        _selectedIds.removeAll(ids);
      } else {
        _selectedIds.addAll(ids);
      }
    });
  }

  void _exitSelectMode() {
    setState(() {
      _selectMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _bulkUnfavorite() async {
    if (_selectedIds.isEmpty) return;
    final notifier = ref.read(favoritesProvider.notifier);
    final state = ref.read(favoritesProvider);
    // 从三组列表中找到对应 MediaItem
    final all = [...state.movies, ...state.boxSets, ...state.people];
    final targets =
        all.where((item) => _selectedIds.contains(item.id)).toList();
    if (targets.isEmpty) {
      _exitSelectMode();
      return;
    }

    // 捕获 ScaffoldMessenger（在 async gap 之前）
    final messenger = ScaffoldMessenger.of(context);

    // 逐条执行：乐观更新 + SnackBar 合并提示
    for (final item in targets) {
      await notifier.toggleFavorite(item);
    }

    final n = targets.length;
    _exitSelectMode();

    messenger.showSnackBar(
      SnackBar(
        content: Text('已批量取消收藏 $n 项'),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: '撤销',
          onPressed: () async {
            // 逐条重新收藏（撤销）
            for (final item in targets) {
              await notifier.toggleFavorite(item);
            }
            // 简单校验：至少一条失败则提示
            final anyFailed = targets.any((e) => !notifier.isFavorite(e.id));
            if (anyFailed) {
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('部分撤销失败，请重试'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  String _recentLabel(String? err) {
    if (err != null) return _kLoadFailedLabel;
    return '$_kGroupRecentLabelPrefix$_sortLabel$_kGroupRecentLabelSuffix';
  }

  Widget _buildSearchField(ColorScheme scheme) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_kSearchBorderRadius),
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        children: [
          Icon(Icons.search,
              size: _kSearchIconSize, color: scheme.onSurfaceVariant),
          const SizedBox(width: _kSearchIconSpacing),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: _kSearchHint,
                hintStyle: TextStyle(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    vertical: _kSearchVerticalPadding),
              ),
              style: TextStyle(
                  color: scheme.onSurface, fontSize: _kSearchFontSize),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            GestureDetector(
              onTap: () {
                setState(() {
                  _searchQuery = '';
                  _searchController.clear();
                });
              },
              child: Icon(
                Icons.cancel,
                size: _kSearchIconSize,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(ColorScheme scheme, FavoritesState state) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: _kStatLabelMovies,
            count: state.movies.length,
            icon: Icons.movie_outlined,
            bgColor: scheme.primary.withValues(alpha: 0.10),
            fgColor: scheme.primary,
          ),
        ),
        const SizedBox(width: _kStatCardSpacing),
        Expanded(
          child: _StatCard(
            label: _kStatLabelBoxSets,
            count: state.boxSets.length,
            icon: Icons.featured_play_list,
            bgColor: scheme.tertiary.withValues(alpha: 0.10),
            fgColor: scheme.tertiary,
          ),
        ),
        const SizedBox(width: _kStatCardSpacing),
        Expanded(
          child: _StatCard(
            label: _kStatLabelPeople,
            count: state.people.length,
            icon: Icons.person_outline,
            bgColor: scheme.error.withValues(alpha: 0.10),
            fgColor: scheme.error,
          ),
        ),
      ],
    );
  }

  Widget _buildBulkActionBar(ColorScheme scheme) {
    final n = _selectedIds.length;
    return Positioned(
      left: _kBulkBarHorizontalMargin,
      right: _kBulkBarHorizontalMargin,
      bottom: _kBulkBarBottomMargin + MediaQuery.of(context).padding.bottom,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_kBulkBarBorderRadius),
          color: scheme.surface.withValues(alpha: 0.95),
          border:
              Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: _kBulkBarBlurRadius,
              offset: const Offset(0, _kBulkBarShadowOffset),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          left: false,
          right: false,
          child: Row(
            children: [
              Container(
                width: _kBulkCountContainerSize,
                height: _kBulkCountContainerSize,
                decoration: BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(_kBulkCountContainerRadius),
                  color: scheme.primary.withValues(alpha: 0.18),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$n',
                  style: TextStyle(
                    color: scheme.primary,
                    fontSize: _kBulkCountFontSize,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$_kBulkSelectedPrefix$n$_kBulkSelectedSuffix',
                      style: const TextStyle(
                          fontSize: _kBulkTitleFontSize,
                          fontWeight: FontWeight.w600),
                    ),
                    Text(
                      n == 0 ? _kBulkEmptyHint : _kBulkActionHint,
                      style: TextStyle(
                        fontSize: _kBulkHintFontSize,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              _IconAction(
                icon: Icons.playlist_play,
                onTap: n == 0 ? null : () {}, // TODO: 移动到合集
              ),
              const SizedBox(width: 4),
              _IconAction(
                icon: Icons.download_for_offline_outlined,
                onTap: n == 0 ? null : () {}, // TODO: 批量下载
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: n == 0 ? null : _bulkUnfavorite,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: scheme.error.withValues(alpha: 0.15),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.favorite_border,
                        color: scheme.error,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '取消收藏',
                        style: TextStyle(
                          color: scheme.error,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyListHint(ColorScheme scheme, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
