// 从 favorites_widgets_cards.dart 拆分（part 文件，无行为变化）

part of 'favorites_view.dart';

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
