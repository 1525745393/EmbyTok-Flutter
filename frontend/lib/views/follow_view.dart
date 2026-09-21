// 关注页（PRD：追剧标签移至首页改名「关注」）
//
// 独立页面展示「收藏演员的最新作品」（推荐系统 nextUp 数据源），
// 不复用推荐页标签栏/横幅，入口为首页顶栏「关注」按钮。
//
// 数据源：recommendProvider（构造时自动全量加载），此处按
// RecommendSource.nextUp.key 过滤展示，与推荐页 selectTag 逻辑共用同一份数据。
// 「上次看到」标记：读取播放页位置记忆，标记上次观看的视频。

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/image_cache_manager.dart';
import '../utils/playback_position_memory.dart';
import '../widgets/error_state_card.dart';
import '../widgets/last_watched_badge.dart';
import '../widgets/resume_play_banner.dart';
import '../widgets/skeleton_loading.dart';

class FollowView extends ConsumerStatefulWidget {
  const FollowView({super.key});

  @override
  ConsumerState<FollowView> createState() => _FollowViewState();
}

class _FollowViewState extends ConsumerState<FollowView> {
  /// 本列表上次观看的视频 id（位置记忆标记）
  String? _lastWatchedId;

  /// 关注流分组过滤：null=全部 / actorWork=演员新作 / seriesUpdate=剧集更新
  NextUpKind? _kindFilter;

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
    final state = ref.watch(recommendProvider);

    // 仅取追剧源（关注内容：收藏演员新作品 + 剧集更新）
    final allNextUpItems = state.taggedItems
        .where((r) => r.source.key == RecommendSource.nextUp.key)
        .toList(growable: false);
    final actorItems = allNextUpItems
        .where((r) => r.nextUpKind == NextUpKind.actorWork)
        .toList(growable: false);
    final seriesItems = allNextUpItems
        .where((r) => r.nextUpKind == NextUpKind.seriesUpdate)
        .toList(growable: false);
    final nextUpItems = switch (_kindFilter) {
      NextUpKind.actorWork => actorItems,
      NextUpKind.seriesUpdate => seriesItems,
      null => allNextUpItems,
    };

    // 异步读取「上次看到」标记：每次 build 都重读，从播放页返回
    // （State 存活）时也能拿到最新记忆；结果相同则不 setState，
    // 不会触发重建循环
    if (nextUpItems.isNotEmpty) {
      _scheduleLoadLastWatched(nextUpItems);
    }

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('关注'),
        backgroundColor: scheme.surface,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(recommendProvider.notifier).refresh(),
          child: _buildBody(
            context,
            ref,
            state,
            nextUpItems,
            actorItems,
            seriesItems,
            scheme,
          ),
        ),
      ),
    );
  }

  void _scheduleLoadLastWatched(List<RecommendItem> items) {
    if (items.isEmpty) return;
    final signature = items.first.item.id;
    Future.microtask(() async {
      final id = await PlaybackPositionMemory.lastWatchedItemId(
        source: 'follow',
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

  /// 网格滚动定位：把上次观看的视频滚动到视口内（估算偏移粗定位），
  /// 便于用户一眼看到角标。若目标已在视口内则不打扰。
  void _scrollToLastWatched(List<RecommendItem> items, String id) {
    final index = items.indexWhere((r) => r.item.id == id);
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
        _gridController.animateTo(
          target.clamp(0.0, position.maxScrollExtent),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildBody(
      BuildContext context,
      WidgetRef ref,
      RecommendState state,
      List<RecommendItem> items,
      List<RecommendItem> actorItems,
      List<RecommendItem> seriesItems,
      ColorScheme scheme) {
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

    // 数据已加载但当前视图为空：
    // 1) 分段过滤导致当前段为空（全量仍有内容）→ 提示并提供「查看全部」恢复入口
    // 2) 全量追剧源为空 → 引导关注演员 / 收藏剧集
    if (items.isEmpty) {
      final hasFullContent = actorItems.isNotEmpty || seriesItems.isNotEmpty;
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: constraints.maxHeight,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    hasFullContent
                        ? Icons.filter_alt_off_outlined
                        : Icons.person_search_outlined,
                    size: 48,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    hasFullContent ? '当前分类暂无内容' : '关注后这里会展示最新内容',
                    style:
                        TextStyle(color: scheme.onSurfaceVariant, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      hasFullContent
                          ? '切换分类后，其他分类的内容仍可浏览'
                          : '收藏演员可看他们的最新作品；收藏剧集会跟踪未看新集',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: scheme.onSurfaceVariant, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (hasFullContent)
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _kindFilter = null),
                      icon: const Icon(Icons.apps, size: 18),
                      label: const Text('查看全部'),
                    )
                  else
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

    // 网格 + 顶部「上次看到」续播横幅 + 分组过滤栏
    final lastWatchedItem = _lastWatchedItemOf(items);
    // 整列表转一次，避免 itemBuilder 里每个 item 都重复创建完整 list
    final mediaItems = items.map((r) => r.item).toList(growable: false);
    return Column(
      children: [
        if (lastWatchedItem != null)
          ResumePlayBanner(
            title: lastWatchedItem.title,
            onTap: () => _playFrom(context, ref, lastWatchedItem, items),
          ),
        _buildFilterBar(
          context,
          actorCount: actorItems.length,
          seriesCount: seriesItems.length,
          scheme: scheme,
        ),
        Expanded(
          child: GridView.builder(
            controller: _gridController,
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
              nextUpKind: items[i].nextUpKind,
              // 整列表进入播放页，支持抖音式上下滑刷视频
              items: mediaItems,
              isLastWatched: items[i].item.id == _lastWatchedId,
            ),
          ),
        ),
      ],
    );
  }

  /// 顶部分组过滤栏（全部 / 演员新作 / 剧集更新）
  /// 仅当两类子源都有内容时才显示分段器；单选可再次点击取消回到「全部」。
  Widget _buildFilterBar(
    BuildContext context, {
    required int actorCount,
    required int seriesCount,
    required ColorScheme scheme,
  }) {
    final total = actorCount + seriesCount;
    if (actorCount == 0 || seriesCount == 0) {
      // 只有单一来源：无需分段器
      return const SizedBox.shrink();
    }
    final filters = <({NextUpKind? kind, String label, int count})>[
      (kind: null, label: '全部', count: total),
      (kind: NextUpKind.seriesUpdate, label: '剧集更新', count: seriesCount),
      (kind: NextUpKind.actorWork, label: '演员新作', count: actorCount),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          for (final f in filters)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text('${f.label} ${f.count}'),
                labelStyle: TextStyle(
                  fontSize: 12,
                  color: _kindFilter == f.kind
                      ? scheme.onSecondaryContainer
                      : scheme.onSurfaceVariant,
                ),
                selected: _kindFilter == f.kind,
                visualDensity: VisualDensity.compact,
                onSelected: (_) {
                  setState(() {
                    // 点击已选中的段 = 取消过滤回「全部」
                    _kindFilter = _kindFilter == f.kind ? null : f.kind;
                  });
                },
              ),
            ),
        ],
      ),
    );
  }

  /// 从当前追剧列表中找到上次观看的视频（横幅续播用）
  MediaItem? _lastWatchedItemOf(List<RecommendItem> items) {
    final id = _lastWatchedId;
    if (id == null) return null;
    for (final r in items) {
      if (r.item.id == id) return r.item;
    }
    return null;
  }

  /// 横幅一键续播：与海报点击同路径（整列表进入播放页）
  void _playFrom(BuildContext context, WidgetRef ref, MediaItem item,
      List<RecommendItem> items) {
    final mediaItems = items.map((r) => r.item).toList(growable: false);
    ref
        .read(playbackListProvider.notifier)
        .setPlaybackList(mediaItems, item.id);
    context.push('/play/${item.id}', extra: {
      'item': item,
      'items': mediaItems,
      'source': 'follow',
    });
  }
}

/// 关注页海报卡片
class _FollowPosterCard extends ConsumerWidget {
  const _FollowPosterCard({
    required this.item,
    required this.items,
    this.nextUpKind,
    this.isLastWatched = false,
  });

  final MediaItem item;
  final List<MediaItem> items;
  final NextUpKind? nextUpKind; // 来源标注（演员新作 / 剧集更新）
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
                // 来源标注角标（演员新作 / 剧集更新）
                if (nextUpKind != null)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            nextUpKind == NextUpKind.seriesUpdate
                                ? Icons.live_tv_outlined
                                : Icons.person_outline,
                            size: 10,
                            color: scheme.onPrimary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            nextUpKind == NextUpKind.seriesUpdate ? '剧集' : '演员',
                            style: TextStyle(
                              fontSize: 9,
                              height: 1.2,
                              color: scheme.onPrimary,
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
