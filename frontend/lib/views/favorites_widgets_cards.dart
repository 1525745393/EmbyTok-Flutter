// 从 favorites_widgets.dart 拆分（part 文件，无行为变化）

part of 'favorites_view.dart';

class _BoxSetTile extends ConsumerWidget {
  const _BoxSetTile({required this.item});
  final MediaItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final authState = ref.watch(authProvider);
    final imageUrl = item.thumbnailUrlWithAuth(
      authState.embyServerUrl,
      authState.token,
      maxWidth: 180,
    );
    final headers = item.authHeaders(authState.token);
    final year = item.productionYear ?? item.year;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => context.push('/boxset/${item.id}', extra: item),
      onLongPress: () => _showMenu(context, ref),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: scheme.surface.withValues(alpha: 0.7),
          border:
              Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            // 缩略方块
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: scheme.tertiary.withValues(alpha: 0.15),
              ),
              clipBehavior: Clip.antiAlias,
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      cacheManager: AppImageCacheManager.thumbnail,
                      fit: BoxFit.cover,
                      httpHeaders: headers.isNotEmpty ? headers : null,
                      errorWidget: (_, __, ___) => Center(
                        child: Icon(Icons.featured_play_list,
                            color: scheme.tertiary, size: 24),
                      ),
                    )
                  : Center(
                      child: Icon(Icons.featured_play_list,
                          color: scheme.tertiary, size: 24),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (year != null) '$year',
                      item.type,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 10.5, color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: scheme.outlineVariant.withValues(alpha: 0.25),
                        ),
                        child: Text(
                          '未看 2',
                          style: TextStyle(
                            fontSize: 10,
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      if ((item.displayRating ?? 0) > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: Colors.amber.withValues(alpha: 0.15),
                          ),
                          child: Text(
                            '★ ${item.displayRating!.toStringAsFixed(1)}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.amber.shade300,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant, size: 18),
          ],
        ),
      ),
    );
  }

  void _showMenu(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  item.title,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.favorite_border, color: scheme.error),
                title: Text('取消收藏', style: TextStyle(color: scheme.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  final notifier = ref.read(favoritesProvider.notifier);
                  notifier.toggleFavorite(item);
                  final messenger = ScaffoldMessenger.of(context);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('已取消收藏「${item.title}」'),
                      action: SnackBarAction(
                        label: '撤销',
                        onPressed: () =>
                            _undoUnfavorite(messenger, notifier, item),
                      ),
                      duration: const Duration(seconds: 5),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              ListTile(
                leading:
                    Icon(Icons.info_outline, color: scheme.onSurfaceVariant),
                title: const Text('查看详情'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/boxset/${item.id}', extra: item);
                },
              ),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
  }
}

/// 人物头像 + 名称
class _PersonTile extends ConsumerWidget {
  const _PersonTile({required this.item});
  final MediaItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final authState = ref.watch(authProvider);
    final imageUrl = item.thumbnailUrlWithAuth(
      authState.embyServerUrl,
      authState.token,
      maxWidth: 160,
    );
    final headers = item.authHeaders(authState.token);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => context.push('/person/${item.id}', extra: item),
      onLongPress: () => _showMenu(context, ref),
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.error.withValues(alpha: 0.12),
                border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.35)),
              ),
              clipBehavior: Clip.antiAlias,
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      cacheManager: AppImageCacheManager.thumbnail,
                      fit: BoxFit.cover,
                      httpHeaders: headers.isNotEmpty ? headers : null,
                      errorWidget: (_, __, ___) => Center(
                        child: Text(
                          item.title.isNotEmpty
                              ? item.title[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: scheme.error.withValues(alpha: 0.65),
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Icon(Icons.person,
                          color: scheme.error.withValues(alpha: 0.65),
                          size: 22),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.5,
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  void _showMenu(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(item.title,
                    style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.favorite_border, color: scheme.error),
                title: Text('取消收藏', style: TextStyle(color: scheme.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  final notifier = ref.read(favoritesProvider.notifier);
                  notifier.toggleFavorite(item);
                  final messenger = ScaffoldMessenger.of(context);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('已取消收藏「${item.title}」'),
                      action: SnackBarAction(
                        label: '撤销',
                        onPressed: () =>
                            _undoUnfavorite(messenger, notifier, item),
                      ),
                      duration: const Duration(seconds: 5),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              ListTile(
                leading:
                    Icon(Icons.info_outline, color: scheme.onSurfaceVariant),
                title: const Text('查看详情'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/person/${item.id}', extra: item);
                },
              ),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
  }
}

/// 影片/人物：更多卡片
