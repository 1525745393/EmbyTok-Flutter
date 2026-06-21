// 收藏管理页面：三栏（影片 / 合集 / 人物）横向滚动布局

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/error_state_card.dart';
import 'boxset_detail_view.dart';
import 'person_detail_view.dart';
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
    if (state.error != null &&
        state.movies.isEmpty &&
        state.boxSets.isEmpty &&
        state.people.isEmpty) {
      return ErrorStateCard(
        title: state.error!,
        actionLabel: '重试',
        onAction: () {
          ref.read(favoritesProvider.notifier).loadFavorites();
        },
      );
    }

    // 空状态
    if (state.movies.isEmpty && state.boxSets.isEmpty && state.people.isEmpty) {
      return EmptyStateCard.noFavorites();
    }

    // 三栏布局
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _SectionHeader(
            title: '收藏影片',
            count: state.movies.length,
          ),
        ),
        SliverToBoxAdapter(child: _buildHorizontalCardList(items: state.movies, itemType: _CardType.movie)),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
        SliverToBoxAdapter(
          child: _SectionHeader(
            title: '收藏合集',
            count: state.boxSets.length,
          ),
        ),
        SliverToBoxAdapter(child: _buildHorizontalCardList(items: state.boxSets, itemType: _CardType.boxSet)),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
        SliverToBoxAdapter(
          child: _SectionHeader(
            title: '收藏人物',
            count: state.people.length,
          ),
        ),
        SliverToBoxAdapter(child: _buildHorizontalCardList(items: state.people, itemType: _CardType.person)),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  Widget _buildHorizontalCardList({
    required List<MediaItem> items,
    required _CardType itemType,
  }) {
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
  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
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

  const _FavoriteCard({
    super.key,
    required this.item,
    required this.itemType,
    required this.width,
    required this.height,
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
      onTap: () => _navigateTo(context),
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

  void _navigateTo(BuildContext context) {
    switch (itemType) {
      case _CardType.movie:
        context.push('/play/${item.id}', extra: item);
        break;
      case _CardType.boxSet:
        context.go('/boxset/${item.id}', extra: item);
        break;
      case _CardType.person:
        context.go('/person/${item.id}', extra: item);
        break;
    }
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
