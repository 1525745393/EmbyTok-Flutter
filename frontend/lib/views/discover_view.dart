// 发现页（PRD：视频库首页顶栏「发现」）
//
// 按用户设置的 Emby 合集（BoxSet）与类型（Genres）展示发现内容。
// - 顶部：AppBar + 「编辑发现」按钮（跳设置选择）
// - 主体：网格展示已选类型与合集下的影片（合并去重）
// - 未配置任何来源：引导空态，点击去设置
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
import '../widgets/last_watched_badge.dart';
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

  /// 已定位过的列表签名（防止浏览中 rebuild 反复拉回）
  String? _lastScrolledSignature;

  /// 已定位过的视频 id
  String? _lastScrolledId;

  /// 网格滚动控制器（用于定位到上次观看的视频）
  final ScrollController _gridController = ScrollController();

  @override
  void dispose() {
    _gridController.dispose();
    super.dispose();
  }

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
            label: const Text('编辑发现'),
          ),
        ],
      ),
      body: _buildBody(context, ref, state),
    );
  }

  void _scheduleLoadLastWatched(List<MediaItem> items) {
    if (items.isEmpty) return;
    final signature = items.first.id;
    Future.microtask(() async {
      final id = await PlaybackPositionMemory.lastWatchedItemId(
        source: 'discover',
        listSignature: signature,
      );
      if (!mounted) return;
      final isNewSignature = signature != _lastScrolledSignature;
      if (isNewSignature || id != _lastWatchedId) {
        setState(() => _lastWatchedId = id);
      }
      // 仅列表签名变化（首次进入/切换数据源/刷新）或上次观看视频变化
      // （从播放页返回）时滚动定位，避免浏览中任何 rebuild 反复把用户
      // 拉回旧位置打断浏览。
      if (id != null && (isNewSignature || id != _lastScrolledId)) {
        _lastScrolledSignature = signature;
        _lastScrolledId = id;
        _scrollToLastWatched(items, id);
      }
    });
  }

  /// 网格滚动定位：把上次观看的视频滚动到视口内（优先估算偏移粗定位，
  /// 目标卡片构建后 ensureVisible 精确居中），便于用户一眼看到角标。
  void _scrollToLastWatched(List<MediaItem> items, String id) {
    final index = items.indexWhere((i) => i.id == id);
    if (index < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_gridController.hasClients) return;
      final position = _gridController.position;
      final viewportWidth = position.viewportDimension;
      // 与 GridView 配置保持一致：padding 12、间距 12、maxCrossAxisExtent 160、比例 2/3
      const padding = 12.0;
      const spacing = 12.0;
      const maxExtent = 160.0;
      const aspectRatio = 2 / 3;
      final contentWidth = viewportWidth - padding * 2;
      final cols = ((contentWidth + spacing) / (maxExtent + spacing)).ceil();
      final cellWidth = (contentWidth - spacing * (cols - 1)) / cols;
      final cellHeight = cellWidth / aspectRatio;
      final row = index ~/ cols;
      final target = row * (cellHeight + spacing);

      final viewport = position.viewportDimension;
      final current = position.pixels;
      final needsScroll =
          target < current || target > current + viewport - cellHeight;
      if (needsScroll) {
        final maxExtentOffset = position.maxScrollExtent;
        _gridController.animateTo(
          target.clamp(0.0, maxExtentOffset),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
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
    if (!state.hasSelection) {
      return EmptyStateCard(
        icon: Icons.explore_outlined,
        title: '还没有选择发现来源',
        subtitle: '在设置中选择 Emby 合集或类型后，这里会展示对应的影片。',
        actionLabel: '去设置',
        onAction: () => context.push('/settings'),
      );
    }
    if (state.items.isEmpty) {
      return const EmptyStateCard(
        icon: Icons.movie_outlined,
        title: '所选来源下暂无内容',
        subtitle: '试试更换合集/类型，或检查服务器媒体库。',
      );
    }

    // 网格 + 顶部「上次看到」续播横幅
    final lastWatchedItem = _lastWatchedItemOf(state.items);
    return Column(
      children: [
        if (lastWatchedItem != null)
          ResumePlayBanner(
            title: lastWatchedItem.title,
            onTap: () => _playFrom(context, ref, lastWatchedItem, state.items),
          ),
        Expanded(
          child: GridView.builder(
            controller: _gridController,
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
        ref.read(playbackListProvider.notifier).setPlaybackList(items, item.id);
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
                // 「上次看到」角标（醒目样式 + 服务端进度百分比）
                if (isLastWatched)
                  Positioned(
                    left: 6,
                    top: 6,
                    child: LastWatchedBadge(
                      progressPercent: item.progressPercent > 0
                          ? (item.progressPercent * 100).round()
                          : null,
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
