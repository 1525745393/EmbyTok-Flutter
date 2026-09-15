// 关注页（PRD：追剧标签移至首页改名「关注」）
//
// 独立页面展示「收藏演员的最新作品」（推荐系统 nextUp 数据源），
// 不复用推荐页标签栏/横幅，入口为首页顶栏「关注」按钮。
//
// 数据源：recommendProvider（构造时自动全量加载），此处按
// RecommendSource.nextUp.key 过滤展示，与推荐页 selectTag 逻辑共用同一份数据。

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

class FollowView extends ConsumerWidget {
  const FollowView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final state = ref.watch(recommendProvider);

    // 仅取追剧源（收藏演员的新作品）
    final nextUpItems = state.taggedItems
        .where((r) => r.source.key == RecommendSource.nextUp.key)
        .toList(growable: false);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('关注'),
        backgroundColor: scheme.surface,
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(recommendProvider.notifier).refresh(),
        child: _buildBody(context, ref, state, nextUpItems, scheme),
      ),
    );
  }

  Widget _buildBody(
      BuildContext context, WidgetRef ref, RecommendState state,
      List<RecommendItem> items, ColorScheme scheme) {
    // 全局加载中且暂无数据 → 骨架屏
    if (state.isLoading && state.taggedItems.isEmpty) {
      return const SkeletonGrid();
    }

    // 全局错误（未登录 / 未选择媒体库）
    final error = state.error;
    if (state.taggedItems.isEmpty && error != null) {
      return ErrorStateCard(
        title: error,
        actionLabel: '重试',
        onAction: () => ref.read(recommendProvider.notifier).refresh(),
      );
    }

    // 数据已加载但追剧源为空 → 引导关注演员
    if (items.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: constraints.maxHeight,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_search_outlined,
                      size: 48, color: scheme.onSurfaceVariant),
                  const SizedBox(height: 12),
                  Text(
                    '还没有关注任何演员',
                    style: TextStyle(
                        color: scheme.onSurfaceVariant, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      '在演员详情页点「关注」后，这里会展示他们的最新作品',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: scheme.onSurfaceVariant, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () =>
                        ref.read(recommendProvider.notifier).refresh(),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('刷新'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // 网格展示追剧内容
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2 / 3,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) => _FollowPosterCard(
        item: items[i].item,
        // 整列表进入播放页，支持抖音式上下滑刷视频
        items: items.map((r) => r.item).toList(growable: false),
      ),
    );
  }
}

/// 关注页海报卡片
class _FollowPosterCard extends ConsumerWidget {
  const _FollowPosterCard({required this.item, required this.items});

  final MediaItem item;
  final List<MediaItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final auth = ref.read(authProvider);
    final imageUrl = item.primaryUrl(
      embyServerUrl: auth.embyServerUrl,
      apiKey: auth.token,
    );
    return GestureDetector(
      onTap: () {
        // 追剧数据来自推荐系统（收藏演员新作品），与视频流 items 不同源，
        // 不依赖 /?initialId= 查找；整列表进入播放页，支持上下滑刷视频
        ref.read(playbackListProvider.notifier).setPlaybackList(items, item.id);
        context.push('/play/${item.id}', extra: {
          'item': item,
          'items': items,
          'source': 'follow',
        });
      },
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
