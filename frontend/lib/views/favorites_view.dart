// 收藏管理页面：三栏（影片 / 合集 / 人物）横向滚动布局

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/formatters.dart';
import 'boxset_detail_view.dart';
import 'person_detail_view.dart';
import 'video_page_item.dart';

class FavoritesView extends ConsumerStatefulWidget {
  const FavoritesView({super.key});

  @override
  ConsumerState<FavoritesView> createState() => _FavoritesViewState();
}

class _FavoritesViewState extends ConsumerState<FavoritesView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(favoritesProvider.notifier).loadFavorites();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(favoritesProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            const Icon(Icons.favorite, color: Color(0xFFE91E63), size: 24),
            const SizedBox(width: 8),
            const Text('我的收藏'),
            const SizedBox(width: 12),
            Text(
              '${state.movies.length + state.boxSets.length + state.people.length}',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white70, size: 22),
              onPressed: () =>
                  ref.read(favoritesProvider.notifier).loadFavorites(),
              tooltip: '刷新',
            ),
          ],
        ),
      ),
      body: _buildBody(state),
    );
  }

  Widget _buildBody(FavoritesState state) {
    // 加载中
    if (state.isLoading &&
        state.movies.isEmpty &&
        state.boxSets.isEmpty &&
        state.people.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFE91E63)),
      );
    }

    // 错误
    if (state.error != null &&
        state.movies.isEmpty &&
        state.boxSets.isEmpty &&
        state.people.isEmpty) {
      return _buildError(state.error!);
    }

    // 空状态
    if (state.movies.isEmpty && state.boxSets.isEmpty && state.people.isEmpty) {
      return const _EmptyState();
    }

    // 三栏布局
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 收藏影片
          _SectionHeader(
            title: '收藏影片',
            count: state.movies.length,
          ),
          _buildHorizontalCardList(
            items: state.movies,
            itemType: _CardType.movie,
          ),
          const SizedBox(height: 24),

          // 收藏合集
          _SectionHeader(
            title: '收藏合集',
            count: state.boxSets.length,
          ),
          _buildHorizontalCardList(
            items: state.boxSets,
            itemType: _CardType.boxSet,
          ),
          const SizedBox(height: 24),

          // 收藏人物
          _SectionHeader(
            title: '收藏人物',
            count: state.people.length,
          ),
          _buildHorizontalCardList(
            items: state.people,
            itemType: _CardType.person,
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalCardList({
    required List<MediaItem> items,
    required _CardType itemType,
  }) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Text(
          '暂无收藏',
          style: TextStyle(color: Colors.white54, fontSize: 14),
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

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE91E63),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('重试'),
              onPressed: () {
                ref.read(favoritesProvider.notifier).loadFavorites();
              },
            ),
          ],
        ),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '($count)',
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.favorite_border, size: 80, color: Colors.white30),
          SizedBox(height: 16),
          Text(
            '还没有收藏',
            style: TextStyle(color: Colors.white70, fontSize: 18),
          ),
          SizedBox(height: 8),
          Text(
            '双击视频即可收藏 💖',
            style: TextStyle(color: Colors.white54, fontSize: 14),
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
    required this.item,
    required this.itemType,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                color: Colors.grey[800],
                border: Border.all(color: Colors.white12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        headers: headers.isNotEmpty ? headers : null,
                        errorBuilder: (_, __, ___) => _PlaceholderIcon(
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
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _subtitleText,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
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
        Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => _FavoritePlayPage(item: item),
          ),
        );
        break;
      case _CardType.boxSet:
        Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => BoxsetDetailView(item: item),
          ),
        );
        break;
      case _CardType.person:
        Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => PersonDetailView(person: item),
          ),
        );
        break;
    }
  }
}

class _PlaceholderIcon extends StatelessWidget {
  final _CardType itemType;
  const _PlaceholderIcon({required this.itemType});

  @override
  Widget build(BuildContext context) {
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
    return Icon(icon, color: Colors.white30, size: 48);
  }
}

class _FavoritePlayPage extends StatelessWidget {
  final MediaItem item;
  const _FavoritePlayPage({required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(item.title, style: const TextStyle(fontSize: 16)),
      ),
      body: VideoPageItem(item: item),
    );
  }
}
