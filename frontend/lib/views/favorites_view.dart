// 收藏管理页面：三栏（影片 / 合集 / 人物）横向滚动布局

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/image_cache_manager.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/error_state_card.dart';
import '../widgets/video_page_item.dart';

class FavoritesView extends ConsumerStatefulWidget {
  const FavoritesView({super.key});

  @override
  ConsumerState<FavoritesView> createState() => _FavoritesViewState();
}

class _FavoritesViewState extends ConsumerState<FavoritesView>
    with AutomaticKeepAliveClientMixin<FavoritesView> {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(favoritesProvider.notifier).loadFavorites();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final scheme = Theme.of(context).colorScheme;
    final state = ref.watch(favoritesProvider);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        title: Row(
          children: [
            Icon(Icons.favorite, color: scheme.primary, size: 24),
            const SizedBox(width: 8),
            const Text('我的收藏'),
            const SizedBox(width: 12),
            Text(
              '${state.movies.length + state.boxSets.length + state.people.length}',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
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
      ),
      body: _buildBody(state, scheme),
    );
  }

  Widget _buildBody(FavoritesState state, ColorScheme scheme) {
    // 加载中
    if (state.isLoading &&
        state.movies.isEmpty &&
        state.boxSets.isEmpty &&
        state.people.isEmpty) {
      return Center(
        child: CircularProgressIndicator(color: scheme.primary),
      );
    }

    // 错误
    final errorMsg = state.error;
    if (errorMsg != null &&
        state.movies.isEmpty &&
        state.boxSets.isEmpty &&
        state.people.isEmpty) {
      return ErrorStateCard(
        title: errorMsg,
        actionLabel: '重试',
        onAction: () {
          ref.read(favoritesProvider.notifier).loadFavorites();
        },
      );
    }

    // 空状态（三栏全空且无错误）
    if (state.movies.isEmpty &&
        state.boxSets.isEmpty &&
        state.people.isEmpty &&
        state.moviesError == null &&
        state.boxSetsError == null &&
        state.peopleError == null &&
        state.error == null) {
      return EmptyStateCard.noFavorites();
    }

    // 三栏布局
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _SectionHeader(
            title: '收藏影片',
            count: state.movies.length,
            onViewAll: state.movies.isNotEmpty
                ? () => context.push('/favorites/category/movie')
                : null,
          ),
        ),
        SliverToBoxAdapter(
          child: _buildHorizontalCardList(
            items: state.movies,
            itemType: _CardType.movie,
            error: state.moviesError,
            onRetry: () => ref.read(favoritesProvider.notifier).loadFavorites(),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
        SliverToBoxAdapter(
          child: _SectionHeader(
            title: '收藏合集',
            count: state.boxSets.length,
            onViewAll: state.boxSets.isNotEmpty
                ? () => context.push('/favorites/category/boxset')
                : null,
          ),
        ),
        SliverToBoxAdapter(
          child: _buildHorizontalCardList(
            items: state.boxSets,
            itemType: _CardType.boxSet,
            error: state.boxSetsError,
            onRetry: () => ref.read(favoritesProvider.notifier).loadFavorites(),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
        SliverToBoxAdapter(
          child: _SectionHeader(
            title: '收藏人物',
            count: state.people.length,
            onViewAll: state.people.isNotEmpty
                ? () => context.push('/favorites/category/person')
                : null,
          ),
        ),
        SliverToBoxAdapter(
          child: _buildHorizontalCardList(
            items: state.people,
            itemType: _CardType.person,
            error: state.peopleError,
            onRetry: () => ref.read(favoritesProvider.notifier).loadFavorites(),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  Widget _buildHorizontalCardList({
    required List<MediaItem> items,
    required _CardType itemType,
    String? error,
    VoidCallback? onRetry,
  }) {
    // 该栏加载失败：显示错误提示 + 重试按钮
    if (error != null && items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(Icons.error_outline,
                color: Theme.of(context).colorScheme.error, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                error,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                child: const Text('重试'),
              ),
          ],
        ),
      );
    }

    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Text(
          '暂无收藏',
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14),
        ),
      );
    }

    final double cardWidth = itemType == _CardType.person ? 100 : 120;
    final double cardHeight = itemType == _CardType.person ? 140 : 180;

    return SizedBox(
      height: cardHeight + 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return Padding(
            padding: EdgeInsets.only(
              right: index < items.length - 1 ? 12 : 0,
            ),
            child: _FavoriteCard(
              key: Key(item.id),
              item: item,
              itemType: itemType,
              width: cardWidth,
              height: cardHeight,
              allItems: items,
            ),
          );
        },
      ),
    );
  }
}

enum _CardType { movie, boxSet, person }

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final VoidCallback? onViewAll;
  const _SectionHeader({
    required this.title,
    required this.count,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '($count)',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
          ),
          const Spacer(),
          if (onViewAll != null && count > 0)
            TextButton(
              onPressed: onViewAll,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('全部', style: TextStyle(color: scheme.primary, fontSize: 13)),
                  const SizedBox(width: 2),
                  Icon(Icons.chevron_right, color: scheme.primary, size: 18),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _FavoriteCard extends ConsumerWidget {
  final MediaItem item;
  final _CardType itemType;
  final double width;
  final double height;
  final List<MediaItem> allItems; // 完整列表

  const _FavoriteCard({
    super.key,
    required this.item,
    required this.itemType,
    required this.width,
    required this.height,
    required this.allItems,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final authState = ref.watch(authProvider);
    final imageUrl = item.thumbnailUrlWithAuth(
      authState.embyServerUrl,
      authState.token,
      maxWidth: width.toInt(),
    );
    final headers = item.authHeaders(authState.token);

    return InkWell(
      onTap: () => _navigateTo(context, ref),
      onLongPress: () => _showLongPressMenu(context, ref),
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: scheme.surface.withOpacity(0.25),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        cacheManager: AppImageCacheManager.thumbnail,
                        fit: BoxFit.cover,
                        httpHeaders: headers.isNotEmpty ? headers : null,
                        memCacheWidth: 400,
                        placeholder: (_, __) => Container(
                          color: scheme.surface.withOpacity(0.25),
                          child: Center(
                            child: CircularProgressIndicator(color: scheme.primary, strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (_, __, ___) => _PlaceholderIcon(
                          itemType: itemType,
                        ),
                      )
                    : _PlaceholderIcon(itemType: itemType),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: scheme.onSurface, fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _subtitleText,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  String get _subtitleText {
    if (itemType == _CardType.person) {
      return '演员';
    }
    final year = item.productionYear ?? item.year;
    if (year != null) {
      return year.toString();
    }
    return item.type;
  }

  void _navigateTo(BuildContext context, WidgetRef ref) {
    switch (itemType) {
      case _CardType.movie:
        // 设置播放列表后再跳转
        ref.read(playbackListProvider.notifier).setPlaybackList(allItems, item.id);
        context.push('/play/${item.id}', extra: item);
        break;
      case _CardType.boxSet:
        context.push('/boxset/${item.id}', extra: item);
        break;
      case _CardType.person:
        context.push('/person/${item.id}', extra: item);
        break;
    }
  }

  // 长按弹出操作菜单
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
              // 标题行
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
              // 取消收藏
              ListTile(
                leading: Icon(Icons.favorite_border, color: scheme.error),
                title: Text(
                  '取消收藏',
                  style: TextStyle(color: scheme.error),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  // 先执行取消收藏（乐观更新）
                  ref.read(favoritesProvider.notifier).toggleFavorite(item);
                  // 弹出 SnackBar 提供撤销
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('已取消收藏「${item.title}」'),
                      action: SnackBarAction(
                        label: '撤销',
                        onPressed: () {
                          // 重新收藏
                          ref.read(favoritesProvider.notifier).toggleFavorite(item);
                        },
                      ),
                      duration: const Duration(seconds: 5),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              // 播放（仅影片）
              if (itemType == _CardType.movie)
                ListTile(
                  leading: Icon(Icons.play_arrow, color: scheme.primary),
                  title: Text('播放', style: TextStyle(color: scheme.onSurface)),
                  onTap: () {
                    Navigator.pop(ctx);
                    ref.read(playbackListProvider.notifier).setPlaybackList(allItems, item.id);
                    context.push('/play/${item.id}', extra: item);
                  },
                ),
              // 查看详情
              ListTile(
                leading: Icon(Icons.info_outline, color: scheme.onSurfaceVariant),
                title: Text('查看详情', style: TextStyle(color: scheme.onSurface)),
                onTap: () {
                  Navigator.pop(ctx);
                  switch (itemType) {
                    case _CardType.movie:
                      context.push('/item/${item.id}', extra: item);
                      break;
                    case _CardType.boxSet:
                      context.push('/boxset/${item.id}', extra: item);
                      break;
                    case _CardType.person:
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

class _PlaceholderIcon extends StatelessWidget {
  final _CardType itemType;
  const _PlaceholderIcon({required this.itemType});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    IconData icon;
    switch (itemType) {
      case _CardType.person:
        icon = Icons.person;
        break;
      case _CardType.boxSet:
        icon = Icons.featured_play_list;
        break;
      case _CardType.movie:
        icon = Icons.movie_outlined;
        break;
    }
    return Icon(icon, color: scheme.onSurfaceVariant, size: 48);
  }
}

class _FavoritePlayPage extends StatelessWidget {
  final MediaItem item;
  const _FavoritePlayPage({required this.item});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        title: Text(item.title, style: const TextStyle(fontSize: 16)),
      ),
      body: VideoPageItem(item: item),
    );
  }
}

/// 收藏分类详情页：展示某一类收藏的全屏网格
///
/// 通过 [category] 区分影片 / 合集 / 人物
enum FavoritesCategory { movie, boxSet, person }

class FavoritesCategoryView extends ConsumerStatefulWidget {
  final FavoritesCategory category;
  const FavoritesCategoryView({super.key, required this.category});

  @override
  ConsumerState<FavoritesCategoryView> createState() =>
      _FavoritesCategoryViewState();
}

class _FavoritesCategoryViewState
    extends ConsumerState<FavoritesCategoryView> {
  String get _title {
    switch (widget.category) {
      case FavoritesCategory.movie:
        return '收藏影片';
      case FavoritesCategory.boxSet:
        return '收藏合集';
      case FavoritesCategory.person:
        return '收藏人物';
    }
  }

  List<MediaItem> _items(FavoritesState state) {
    switch (widget.category) {
      case FavoritesCategory.movie:
        return state.movies;
      case FavoritesCategory.boxSet:
        return state.boxSets;
      case FavoritesCategory.person:
        return state.people;
    }
  }

  String? _error(FavoritesState state) {
    switch (widget.category) {
      case FavoritesCategory.movie:
        return state.moviesError;
      case FavoritesCategory.boxSet:
        return state.boxSetsError;
      case FavoritesCategory.person:
        return state.peopleError;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(favoritesProvider.notifier).ensureLoaded();
    });
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

    // 人物用宽一些的网格，影片/合集用海报网格
    final crossAxisCount = widget.category == FavoritesCategory.person ? 4 : 3;
    final aspectRatio = widget.category == FavoritesCategory.person ? 0.7 : 0.65;

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: aspectRatio,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
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

/// 网格卡片：收藏分类详情页的单张卡片
class _GridCard extends ConsumerWidget {
  final MediaItem item;
  final FavoritesCategory category;
  final List<MediaItem> allItems;

  const _GridCard({
    super.key,
    required this.item,
    required this.category,
    required this.allItems,
  });

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
                border: Border.all(color: scheme.outlineVariant.withOpacity(0.5)),
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
                        errorWidget: (_, __, ___) => _gridPlaceholder(category, scheme),
                      )
                    else
                      _gridPlaceholder(category, scheme),
                    // 心形角标
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Icon(
                        Icons.favorite,
                        color: scheme.primary,
                        size: 16,
                        shadows: [
                          Shadow(
                            color: scheme.onSurface.withOpacity(0.3),
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
    IconData icon;
    switch (cat) {
      case FavoritesCategory.person:
        icon = Icons.person;
        break;
      case FavoritesCategory.boxSet:
        icon = Icons.featured_play_list;
        break;
      case FavoritesCategory.movie:
        icon = Icons.movie_outlined;
        break;
    }
    return Center(
      child: Icon(icon, color: scheme.onSurfaceVariant, size: 36),
    );
  }

  String _subtitle(MediaItem item) {
    if (category == FavoritesCategory.person) return '演员';
    final year = item.productionYear ?? item.year;
    if (year != null) return year.toString();
    return item.type;
  }

  void _navigateTo(BuildContext context, WidgetRef ref) {
    switch (category) {
      case FavoritesCategory.movie:
        ref.read(playbackListProvider.notifier).setPlaybackList(allItems, item.id);
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
                  ref.read(favoritesProvider.notifier).toggleFavorite(item);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('已取消收藏「${item.title}」'),
                      action: SnackBarAction(
                        label: '撤销',
                        onPressed: () {
                          ref.read(favoritesProvider.notifier).toggleFavorite(item);
                        },
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
                  title: Text('播放', style: TextStyle(color: scheme.onSurface)),
                  onTap: () {
                    Navigator.pop(ctx);
                    ref.read(playbackListProvider.notifier).setPlaybackList(allItems, item.id);
                    context.push('/play/${item.id}', extra: item);
                  },
                ),
              ListTile(
                leading: Icon(Icons.info_outline, color: scheme.onSurfaceVariant),
                title: Text('查看详情', style: TextStyle(color: scheme.onSurface)),
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
