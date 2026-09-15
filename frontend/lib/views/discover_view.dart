// 发现页（PRD：视频库首页顶栏「发现」）
//
// 按用户设置的 Emby 标签（Genres）展示发现内容。
// - 顶部：AppBar + 「编辑标签」按钮（跳设置选择）
// - 主体：网格展示已选标签下的影片
// - 未配置标签：引导空态，点击去设置
// - 点击影片 → context.go('/?initialId=...') 进入视频流

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/image_cache_manager.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/error_state_card.dart';
import '../widgets/skeleton_loading.dart';

class DiscoverView extends ConsumerWidget {
  const DiscoverView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final state = ref.watch(discoverProvider);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('发现'),
        backgroundColor: scheme.surface,
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.tune, size: 18),
            label: const Text('编辑标签'),
          ),
        ],
      ),
      body: _buildBody(context, ref, state),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, DiscoverState state) {
    if (state.isLoading && state.items.isEmpty) {
      return const SkeletonGrid();
    }
    if (state.error != null && state.items.isEmpty) {
      return ErrorStateCard(
        title: state.error!,
        actionLabel: '重试',
        onAction: () => ref.read(discoverProvider.notifier).load(),
      );
    }
    if (state.selectedGenreIds.isEmpty) {
      return EmptyStateCard(
        icon: Icons.explore_outlined,
        title: '还没有选择发现标签',
        subtitle: '在设置中选择感兴趣的标签后，这里会展示对应的影片。',
        actionLabel: '去设置',
        onAction: () => context.push('/settings'),
      );
    }
    if (state.items.isEmpty) {
      return const EmptyStateCard(
        icon: Icons.movie_outlined,
        title: '所选标签下暂无内容',
        subtitle: '试试换一批标签，或检查服务器媒体库。',
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2 / 3,
      ),
      itemCount: state.items.length,
      itemBuilder: (context, i) => _PosterCard(item: state.items[i]),
    );
  }
}

/// 海报卡片
class _PosterCard extends ConsumerWidget {
  const _PosterCard({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final auth = ref.read(authProvider);
    final imageUrl = item.primaryUrl(
      embyServerUrl: auth.embyServerUrl,
      apiKey: auth.token,
    );
    return GestureDetector(
      onTap: () => context.go('/?initialId=${item.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      cacheManager: AppImageCacheManager.thumbnail,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: scheme.surfaceContainerHighest,
                        child: const Center(
                          child: Icon(Icons.movie_outlined, size: 32),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: scheme.surfaceContainerHighest,
                        child: Center(
                          child: Icon(Icons.broken_image_outlined,
                              size: 32, color: scheme.outline),
                        ),
                      ),
                    )
                  : Container(
                      color: scheme.surfaceContainerHighest,
                      child: Center(
                        child: Icon(Icons.movie_outlined,
                            size: 32, color: scheme.outline),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
