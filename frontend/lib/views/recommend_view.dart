// 推荐页面：独立路由 /recommend
//
// 背景（PR #57）：
// 推荐从 FeedType 中移除，改为独立路由 + 独立数据源。
// - 数据源：recommendProvider（StateNotifier）
// - 不与 video_list_provider / feed / grid 共享任何状态
// - 视频流中点"推荐"图标 → context.push('/recommend')
// - 推荐页点视频 → 进入视频流播放（context.go('/?initialId=...')）
//
// 特点：
// - 3 列网格布局（参考 PosterGridView）
// - 推荐内容是"个性化推荐 + 多库评分推荐"混合，一次性加载不分页
// - 包含独立 Scaffold + AppBar + 返回按钮

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/image_cache_manager.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/error_state_card.dart';
import '../widgets/library_selector.dart';

/// 推荐页面
class RecommendView extends ConsumerStatefulWidget {
  const RecommendView({super.key});

  @override
  ConsumerState<RecommendView> createState() => _RecommendViewState();
}

class _RecommendViewState extends ConsumerState<RecommendView> {
  // PR #79：滚动监听 - 滚到底部自动 loadMore
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    // PR #66：首次未配置推荐媒体库 → 强制弹 LibrarySelector 让用户选一次
    // 监听 libraryListProvider 加载完成（不打断首帧）
    ref.listen<AsyncValue<List<Library>>>(libraryListProvider, (prev, next) {
      next.whenData((_) {
        // 等到下一帧再弹，避免 build 期间触发 setState
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final configured = ref.read(recommendLibraryConfiguredProvider);
          if (configured) return;
          // 媒体库列表已加载但用户没配置过 → 弹 LibrarySelector
          LibrarySelector.show(context, scope: LibraryScope.recommend);
        });
      });
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  // PR #79：分页 - 距底 200px 时触发 loadMore
  // 避免用户看到空白再加载，提升体验
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    // 距底 < 200px 时触发
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      final state = ref.read(recommendProvider);
      if (state.hasMore && !state.isLoadingMore && !state.isLoading) {
        ref.read(recommendProvider.notifier).loadMore();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final state = ref.watch(recommendProvider);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        elevation: 0,
        title: Row(
          children: [
            Icon(Icons.auto_awesome, color: scheme.primary, size: 22),
            const SizedBox(width: 8),
            const Text('推荐'),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // 返回上一页（独立路由，直接 pop）
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        actions: [
          // 刷新按钮
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: state.isLoading
                ? null
                : () => ref.read(recommendProvider.notifier).refresh(),
          ),
        ],
      ),
      body: _buildBody(context, state, scheme),
    );
  }

  // 错误监听：弹出 SnackBar
  void _maybeShowError(String? error) {
    if (error == null || error.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 3),
        ),
      );
      ref.read(recommendProvider.notifier).clearError();
    });
  }

  Widget _buildBody(
    BuildContext context,
    RecommendState state,
    ColorScheme scheme,
  ) {
    // 错误监听
    _maybeShowError(state.error);

    // PR #79：冷启动 Banner（仅当 isColdStart=true 时显示）
    // 提示用户"先观看几个视频，推荐会更准"
    final showColdStartBanner = state.isColdStart && state.taggedItems.isNotEmpty;

    // 首次加载
    if (state.isLoading && state.taggedItems.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    // 错误（无数据 + 错误信息）
    final errorMsg = state.error;
    if (state.taggedItems.isEmpty && errorMsg != null) {
      return ErrorStateCard(
        title: '加载推荐失败',
        subtitle: errorMsg,
        actionLabel: '重试',
        onAction: () => ref.read(recommendProvider.notifier).refresh(),
      );
    }

    // 空数据
    if (state.taggedItems.isEmpty) {
      return const EmptyStateCard(
        icon: Icons.auto_awesome,
        title: '暂无推荐',
        subtitle: '试试刷新或检查媒体库设置',
      );
    }

    // 性能优化：displayItems 和 tagCounts 由 Provider 预计算
    // 避免在 build 中同步执行 where + map + length（O(n) × 7 次）
    final displayItems = state.displayItems;
    final mediaItems =
        displayItems.map((r) => r.item).toList(growable: false);
    final hasMoreSlot = state.hasMore;

    // 网格：3 列（PR #79：顶部加冷启动 Banner + PR #80：标签栏 + 滚到底自动 loadMore）
    return Column(
      children: [
        if (showColdStartBanner) _buildColdStartBanner(scheme),
        // PR #80：标签分类栏（横向可滚动 + 选中高亮）
        _buildTagBar(state, scheme),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.read(recommendProvider.notifier).refresh(),
            child: GridView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 9 / 16, // 竖屏海报
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: displayItems.length + (hasMoreSlot ? 1 : 0),
              itemBuilder: (context, index) {
                // PR #79：最后一项 = 加载更多指示器
                if (index >= displayItems.length) {
                  return _LoadMoreIndicator(
                    isLoading: state.isLoadingMore,
                    hasMore: state.hasMore,
                  );
                }
                // PR #80：displayItems 是 RecommendItem 列表，渲染时取 .item
                final recommendItem = displayItems[index];
                return _RecommendCard(
                  item: recommendItem.item,
                  // PR #83：传 source 标签用于完播率统计门控
                  onTap: () => _playItem(
                    context,
                    recommendItem.item,
                    mediaItems,
                    recommendItem.source,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // PR #80：横向标签分类栏
  // - 显示 6 个标签：全部 / 追剧 / 续看 / 为你推荐 / 相似 / 高分
  // - 选中时高亮（scheme.primary 背景）
  // - 横向可滚动（不溢出）
  // - 点击切换 → state.selectedTag 变化 → view 自动 rebuild
  Widget _buildTagBar(RecommendState state, ColorScheme scheme) {
    // 性能优化：用预计算的 tagCounts 替代 where.length
    // O(1) Map 查找替代 O(n) 全量遍历
    int countFor(RecommendSource? s) {
      if (s == null) return state.taggedItems.length;
      return state.tagCounts[s.key] ?? 0;
    }

    final tags = <_RecommendTagInfo>[
      _RecommendTagInfo(label: '全部', sourceKey: null, count: countFor(null)),
      _RecommendTagInfo(
          label: RecommendSource.nextUp.label,
          sourceKey: RecommendSource.nextUp.key,
          count: countFor(RecommendSource.nextUp)),
      _RecommendTagInfo(
          label: RecommendSource.resume.label,
          sourceKey: RecommendSource.resume.key,
          count: countFor(RecommendSource.resume)),
      _RecommendTagInfo(
          label: RecommendSource.suggestions.label,
          sourceKey: RecommendSource.suggestions.key,
          count: countFor(RecommendSource.suggestions)),
      _RecommendTagInfo(
          label: RecommendSource.similar.label,
          sourceKey: RecommendSource.similar.key,
          count: countFor(RecommendSource.similar)),
      _RecommendTagInfo(
          label: RecommendSource.recommendations.label,
          sourceKey: RecommendSource.recommendations.key,
          count: countFor(RecommendSource.recommendations)),
    ];

    return Container(
      height: 44,
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: tags.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final tag = tags[i];
          final isSelected = state.selectedTag == tag.sourceKey;
          return ChoiceChip(
            label: Text('${tag.label} (${tag.count})'),
            selected: isSelected,
            onSelected: (_) {
              ref.read(recommendProvider.notifier).selectTag(tag.sourceKey);
            },
            selectedColor: scheme.primary,
            backgroundColor: scheme.surfaceContainerHighest,
            labelStyle: TextStyle(
              color: isSelected ? scheme.onPrimary : scheme.onSurface,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
            side: BorderSide(
              color: isSelected
                  ? scheme.primary
                  : scheme.outlineVariant.withOpacity(0.3),
              width: 1,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4),
          );
        },
      ),
    );
  }

  // PR #79：冷启动 Banner
  // - 提示用户"先观看几个视频，推荐会更准"
  // - 显示在推荐页顶部，仅 isColdStart=true 时出现
  Widget _buildColdStartBanner(ColorScheme scheme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.primary.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.tips_and_updates_outlined,
              color: scheme.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '先观看几个视频，推荐会更准',
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 跳转到独立播放页（/play/:itemId）
  //
  // PR #63 修复：之前 context.go('/?initialId=item.id') 跳到首页视频流，
  // 但推荐页是独立数据源（Emby Suggestions + 多库评分推荐），推荐 video
  // 不在 video_list.items 中 → FeedView._waitForInitialItemToLoad 找不到
  // → loadMore 100 次（约 5 秒）超时 → 用户看到的不是推荐 video
  //
  // 现在改用 /play/:itemId 独立播放页（[PlaybackShell]），用推荐页的 items
  // 作为滑动列表，用户在播放页可以左右滑动看其他推荐 video。
  //
  // PR #83：传 source 标签（nextUp/resume/...）用于完播率统计门控
  void _playItem(
    BuildContext context,
    MediaItem item,
    List<MediaItem> items,
    RecommendSource? source,
  ) {
    context.push(
      '/play/${item.id}',
      extra: <String, dynamic>{
        'item': item,
        'items': items,
        'source': source?.key, // PR #83：完播率 source 标签
      },
    );
  }
}

/// PR #80：标签分类 - 单个标签的信息（label + sourceKey + count）
class _RecommendTagInfo {
  final String label;
  final String? sourceKey; // null = 全部
  final int count;
  const _RecommendTagInfo({
    required this.label,
    required this.sourceKey,
    required this.count,
  });
}

/// 推荐卡片：竖屏海报 + 标题
class _RecommendCard extends ConsumerWidget {
  final MediaItem item;
  final VoidCallback onTap;

  const _RecommendCard({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final auth = ref.watch(authProvider);
    final imageUrl = item.primaryUrl(
      embyServerUrl: auth.embyServerUrl,
      apiKey: auth.token,
      maxWidth: 500,
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      cacheManager: AppImageCacheManager.thumbnail,
                      memCacheWidth: 300,
                      placeholder: (context, url) => Container(
                        color: scheme.surfaceContainerHighest,
                        child: const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: scheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.movie_outlined,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : Container(
                      color: scheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.movie_outlined,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

/// PR #79：分页加载指示器
/// - 加载中：显示 CircularProgressIndicator
/// - 加载完但 hasMore=false：显示「没有更多了」
class _LoadMoreIndicator extends StatelessWidget {
  final bool isLoading;
  final bool hasMore;
  const _LoadMoreIndicator({required this.isLoading, required this.hasMore});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (isLoading) {
      return Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (!hasMore) {
      // 没有更多数据
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            '没有更多了',
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
