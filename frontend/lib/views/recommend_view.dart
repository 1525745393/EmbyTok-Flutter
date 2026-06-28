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
  @override
  void initState() {
    super.initState();
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

    // 首次加载
    if (state.isLoading && state.items.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    // 错误（无数据 + 错误信息）
    if (state.items.isEmpty && state.error != null) {
      return ErrorStateCard(
        title: '加载推荐失败',
        subtitle: state.error!,
        actionLabel: '重试',
        onAction: () => ref.read(recommendProvider.notifier).refresh(),
      );
    }

    // 空数据
    if (state.items.isEmpty) {
      return const EmptyStateCard(
        icon: Icons.auto_awesome,
        title: '暂无推荐',
        subtitle: '试试刷新或检查媒体库设置',
      );
    }

    // 网格：3 列
    return RefreshIndicator(
      onRefresh: () => ref.read(recommendProvider.notifier).refresh(),
      child: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 9 / 16, // 竖屏海报
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemCount: state.items.length,
        itemBuilder: (context, index) {
          final item = state.items[index];
          return _RecommendCard(
            item: item,
            onTap: () => _playItem(context, item, state.items),
          );
        },
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
  void _playItem(
    BuildContext context,
    MediaItem item,
    List<MediaItem> items,
  ) {
    context.push(
      '/play/${item.id}',
      extra: <String, dynamic>{
        'item': item,
        'items': items,
      },
    );
  }
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
