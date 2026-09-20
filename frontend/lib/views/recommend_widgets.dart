// 从 recommend_view.dart 拆分（part 文件，无行为变化）

part of 'recommend_view.dart';

// ==================== 私有卡片组件 ====================

class _RecommendTagInfo {
  const _RecommendTagInfo({
    required this.label,
    required this.sourceKey,
    required this.count,
  });
  final String label;
  final String? sourceKey; // null = 全部
  final int count;
}

/// 推荐卡片：竖屏海报 + 标题
class _RecommendCard extends ConsumerWidget {
  const _RecommendCard({
    required this.item,
    required this.onTap,
  });
  final MediaItem item;
  final VoidCallback onTap;

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
  const _LoadMoreIndicator({required this.isLoading, required this.hasMore});
  final bool isLoading;
  final bool hasMore;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (isLoading) {
      // 该组件是网格最后一格（9:16 竖长），内容顶部对齐与相邻海报齐平，
      // 避免垂直居中后上下大片留白显得悬空
      return Container(
        alignment: Alignment.topCenter,
        padding: const EdgeInsets.only(top: 20),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '加载更多...',
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    if (!hasMore) {
      // 没有更多数据：分割线 + 文案，顶部对齐，不绘制卡片底色
      return Padding(
        padding: const EdgeInsets.only(top: 12, left: 4, right: 4),
        child: Row(
          children: [
            Expanded(
              child: Divider(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.2),
                endIndent: 12,
              ),
            ),
            Text(
              '已经到底啦',
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
              ),
            ),
            Expanded(
              child: Divider(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.2),
                indent: 12,
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
