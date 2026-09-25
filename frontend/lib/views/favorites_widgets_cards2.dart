// 从 favorites_widgets.dart 拆分（part 文件，无行为变化）

part of 'favorites_view.dart';

// ==================== 选择卡片与海报卡片 ====================

class _SelectableCard extends StatelessWidget {
  const _SelectableCard({
    required this.selectMode,
    required this.selected,
    required this.onTap,
    required this.child,
  });
  final bool selectMode;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!selectMode) return child;
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Stack(
        children: [
          AnimatedOpacity(
            opacity: selected ? _kCardSelectedOpacity : 1,
            duration:
                const Duration(milliseconds: _kCardSelectedAnimationDuration),
            child: child,
          ),
          Positioned(
            top: _kCardBadgeOffset,
            left: _kCardBadgeOffset,
            child: AnimatedContainer(
              duration:
                  const Duration(milliseconds: _kCardBadgeAnimationDuration),
              curve: Curves.easeOutCubic,
              width: _kCardBadgeSize,
              height: _kCardBadgeSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_kCardBadgeRadius),
                border: Border.all(
                  color: selected
                      ? scheme.primary
                      : Colors.white.withValues(alpha: 0.85),
                  width: _kCardBadgeBorderWidth,
                ),
                color: selected
                    ? scheme.primary
                    : Colors.black.withValues(alpha: 0.35),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: scheme.primary.withValues(alpha: 0.35),
                          blurRadius: _kCardBadgeShadowBlurRadius,
                        ),
                      ]
                    : null,
              ),
              child: selected
                  ? Icon(Icons.check,
                      size: _kCardBadgeCheckIconSize, color: scheme.onPrimary)
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// 影片海报卡（点击跳转播放/详情，长按菜单）
class _MoviePosterCard extends ConsumerWidget {
  const _MoviePosterCard({
    required this.item,
    required this.allItems,
  });
  final MediaItem item;
  final List<MediaItem> allItems;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final authState = ref.watch(authProvider);
    final imageUrl = item.thumbnailUrlWithAuth(
      authState.embyServerUrl,
      authState.token,
      maxWidth: _kMoviePosterMaxWidth,
    );
    final headers = item.authHeaders(authState.token);

    return InkWell(
      borderRadius: BorderRadius.circular(_kMoviePosterRadius),
      onTap: () {
        ref
            .read(playbackListProvider.notifier)
            .setPlaybackList(allItems, item.id);
        context.push('/play/${item.id}', extra: item);
      },
      onLongPress: () => _showMenu(context, ref),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_kMoviePosterRadius),
                color: scheme.surfaceContainerHighest,
                border: Border.all(
                    color: scheme.outlineVariant
                        .withValues(alpha: _kMoviePosterBorderAlpha)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_kMoviePosterRadius),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imageUrl != null && imageUrl.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: imageUrl,
                        cacheManager: AppImageCacheManager.thumbnail,
                        fit: BoxFit.cover,
                        httpHeaders: headers.isNotEmpty ? headers : null,
                        memCacheWidth: 400,
                        placeholder: (_, __) => Container(
                          color: scheme.surfaceContainerHighest,
                          child: Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: scheme.primary,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Center(
                          child: Icon(Icons.movie_outlined,
                              color: scheme.onSurfaceVariant, size: 30),
                        ),
                      )
                    else
                      Center(
                        child: Icon(Icons.movie_outlined,
                            color: scheme.onSurfaceVariant, size: 30),
                      ),
                    // 评分角标
                    if ((item.displayRating ?? 0) > 0)
                      Positioned(
                        top: _kHeartBadgeOffset,
                        right: _kHeartBadgeOffset,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(_kRatingBadgeRadius),
                            color: Colors.black
                                .withValues(alpha: _kRatingBadgeBgAlpha),
                          ),
                          child: Text(
                            '★ ${item.displayRating!.toStringAsFixed(1)}',
                            style: TextStyle(
                              color: Colors.amber.shade300,
                              fontSize: _kRatingBadgeFontSize,
                              fontWeight: FontWeight.w700,
                              letterSpacing: _kRatingBadgeLetterSpacing,
                            ),
                          ),
                        ),
                      ),
                    // 心形角标（可点击取消收藏）
                    Positioned(
                      bottom: _kHeartBadgeOffset,
                      right: _kHeartBadgeOffset,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => ref
                            .read(favoritesProvider.notifier)
                            .toggleFavorite(item),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.favorite,
                            color: Colors.red,
                            size: _kHeartBadgeSize,
                            shadows: [
                              Shadow(
                                color: scheme.onSurface
                                    .withValues(alpha: _kHeartBadgeShadowAlpha),
                                blurRadius: _kHeartBadgeShadowBlurRadius,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: _kMovieTitleSubtitleSpacing),
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: _kMovieTitleFontSize,
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
              height: _kMovieTitleLineHeight,
            ),
          ),
          const SizedBox(height: _kMovieSubtitleBottomSpacing),
          Text(
            _subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: _kMovieSubtitleFontSize,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String get _subtitle {
    final parts = <String>[];
    final y = item.productionYear ?? item.year;
    if (y != null) parts.add('$y');
    if (parts.isEmpty) return item.type;
    return parts.join(' · ');
  }

  void _showMenu(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(_kMenuTopRadius)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    _kMenuPadding, 16, _kMenuPadding, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: _kMenuTitleFontSize,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.favorite_border, color: scheme.error),
                title: Text(_kMenuItemRemoveFavorite,
                    style: TextStyle(color: scheme.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  final notifier = ref.read(favoritesProvider.notifier);
                  notifier.toggleFavorite(item);
                  final messenger = ScaffoldMessenger.of(context);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                          '$_kSnackBarRemovedPrefix${item.title}$_kSnackBarRemovedSuffix'),
                      action: SnackBarAction(
                        label: _kSnackBarUndo,
                        onPressed: () =>
                            _undoUnfavorite(messenger, notifier, item),
                      ),
                      duration: const Duration(seconds: _kSnackBarDuration),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.play_arrow, color: scheme.primary),
                title: const Text(_kMenuItemPlay),
                onTap: () {
                  Navigator.pop(ctx);
                  ref
                      .read(playbackListProvider.notifier)
                      .setPlaybackList(allItems, item.id);
                  context.push('/play/${item.id}', extra: item);
                },
              ),
              ListTile(
                leading:
                    Icon(Icons.info_outline, color: scheme.onSurfaceVariant),
                title: const Text(_kMenuItemViewDetails),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/item/${item.id}', extra: item);
                },
              ),
              const SizedBox(height: _kMenuBottomSpacing),
            ],
          ),
        );
      },
    );
  }
}

/// 合集 ListTile
