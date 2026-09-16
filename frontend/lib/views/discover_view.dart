// 发现页（PRD：视频库首页顶栏「发现」）
//
// 按用户设置的 Emby 标签（Genres）展示发现内容。
// - 顶部：AppBar + 「编辑标签」按钮（跳设置选择）
// - 主体：网格展示已选标签下的影片
// - 未配置标签：引导空态，点击去设置
// - 点击影片 → 进入播放页（整列表传入，可上下滑刷视频）
// - 「上次看到」标记：读取播放页位置记忆，标记上次观看的视频

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/image_cache_manager.dart';
import '../utils/playback_position_memory.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/error_state_card.dart';
import '../widgets/resume_play_banner.dart';
import '../widgets/skeleton_loading.dart';

class DiscoverView extends ConsumerStatefulWidget {
  const DiscoverView({super.key});

  @override
  ConsumerState<DiscoverView> createState() => _DiscoverViewState();
}

class _DiscoverViewState extends ConsumerState<DiscoverView> {
  /// 本列表上次观看的视频 id（位置记忆标记）
  String? _lastWatchedId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final state = ref.watch(discoverProvider);

    // 异步读取「上次看到」标记：每次 build 都重读，从播放页返回
    // （State 存活）时也能拿到最新记忆；读取结果与当前值相同则不
    // setState，不会触发重建循环
    _scheduleLoadLastWatched(state.items);

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

  void _scheduleLoadLastWatched(List<MediaItem> items) {
    if (items.isEmpty) return;
    Future.microtask(() async {
      final id = await PlaybackPositionMemory.lastWatchedItemId(
        source: 'discover',
        listSignature: items.first.id,
      );
      if (mounted && id != _lastWatchedId) {
        setState(() => _lastWatchedId = id);
      }
    });
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

    // 网格 + 顶部「上次看到」续播横幅
    final lastWatchedItem = _lastWatchedItemOf(state.items);
    return Column(
      children: [
        if (lastWatchedItem != null)
          ResumePlayBanner(
            title: lastWatchedItem.title,
            onTap: () =>
                _playFrom(context, ref, lastWatchedItem, state.items),
          ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 160,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2 / 3,
            ),
            itemCount: state.items.length,
            itemBuilder: (context, i) => _PosterCard(
              item: state.items[i],
              items: state.items,
              isLastWatched: state.items[i].id == _lastWatchedId,
            ),
          ),
        ),
      ],
    );
  }

  /// 从当前列表中找到上次观看的视频（横幅续播用）
  MediaItem? _lastWatchedItemOf(List<MediaItem> items) {
    final id = _lastWatchedId;
    if (id == null) return null;
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  /// 横幅一键续播：与海报点击同路径（整列表进入播放页）
  void _playFrom(BuildContext context, WidgetRef ref, MediaItem item,
      List<MediaItem> items) {
    ref.read(playbackListProvider.notifier).setPlaybackList(items, item.id);
    context.push('/play/${item.id}', extra: {
      'item': item,
      'items': items,
      'source': 'discover',
    });
  }
}

/// 海报卡片
class _PosterCard extends ConsumerWidget {
  const _PosterCard({
    required this.item,
    required this.items,
    this.isLastWatched = false,
  });

  final MediaItem item;
  final List<MediaItem> items; // 当前发现列表（进入播放页后支持上下刷）
  final bool isLastWatched; // 是否为上次观看到的视频

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
        // 发现页数据与视频流列表不同源（按标签拉取），
        // 不能依赖 /?initialId= 在视频流 items 中查找（会超时失败）；
        // 把整个发现列表传给播放页，进入后可像刷抖音一样上下滑动切换
        ref
            .read(playbackListProvider.notifier)
            .setPlaybackList(items, item.id);
        context.push('/play/${item.id}', extra: {
          'item': item,
          'items': items,
          'source': 'discover',
        });
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
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
                // 「上次看到」角标
                if (isLastWatched)
                  Positioned(
                    left: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: const BorderRadius.only(
                          bottomRight: Radius.circular(8),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history, size: 11, color: Colors.white),
                          SizedBox(width: 3),
                          Text(
                            '上次看到',
                            style: TextStyle(
                                color: Colors.white, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
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
