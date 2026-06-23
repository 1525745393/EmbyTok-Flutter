import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import 'tv_focusable.dart';
import 'video_page_item.dart';

/// 海报墙视图：网格布局展示视频缩略图
class PosterGridView extends ConsumerStatefulWidget {
  final List<MediaItem> items;
  final bool hasMore;
  final bool isLoading;
  final VoidCallback onLoadMore;

  const PosterGridView({
    super.key,
    required this.items,
    required this.hasMore,
    required this.isLoading,
    required this.onLoadMore,
  });

  @override
  ConsumerState<PosterGridView> createState() => _PosterGridViewState();
}

class _PosterGridViewState extends ConsumerState<PosterGridView> {
  // 根据屏幕宽度计算网格列数
  int _getCrossAxisCount(double width) {
    if (width < 600) return 3;
    if (width < 900) return 4;
    if (width < 1200) return 5;
    return 6;
  }

  // 显示长按操作菜单
  void _showActionMenu(BuildContext context, MediaItem item) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: const Text('播放'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    body: VideoPageItem(item: item),
                  ),
                ));
              },
            ),
            ListTile(
              leading: Icon(item.isFavorite == true ? Icons.favorite : Icons.favorite_border),
              title: Text(item.isFavorite == true ? '取消收藏' : '收藏'),
              onTap: () {
                // TODO: 实现收藏功能
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('详情'),
              onTap: () {
                Navigator.pop(context);
                // TODO: 实现详情页
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (widget.items.isEmpty && widget.isLoading) {
      return Center(child: CircularProgressIndicator(color: scheme.primary));
    }
    if (widget.items.isEmpty) {
      return Center(
        child: Text('暂无视频', style: TextStyle(color: scheme.onSurface.withOpacity(0.7), fontSize: 16)),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = _getCrossAxisCount(constraints.maxWidth);
        return GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.65,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: widget.items.length + (widget.hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            // 分页加载触发
            if (widget.hasMore && index >= widget.items.length - 3 && !widget.isLoading) {
              widget.onLoadMore();
            }
            // 末尾加载指示器
            if (index >= widget.items.length) {
              return Center(child: CircularProgressIndicator(color: scheme.primary));
            }
            final item = widget.items[index];
            return _PosterCard(
              key: Key(item.id),
              item: item,
              onLongPress: () => _showActionMenu(context, item),
            );
          },
        );
      },
    );
  }
}

/// 单个海报卡片
class _PosterCard extends ConsumerStatefulWidget {
  final MediaItem item;
  final VoidCallback? onLongPress;

  const _PosterCard({super.key, required this.item, this.onLongPress});

  @override
  ConsumerState<_PosterCard> createState() => _PosterCardState();
}

class _PosterCardState extends ConsumerState<_PosterCard> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  // 类型标签映射
  static String _getTypeLabel(String? type) {
    switch (type?.toLowerCase()) {
      case 'movie':
      case 'video':
        return '电影';
      case 'episode':
        return '剧集';
      case 'series':
        return '系列';
      case 'musicalbum':
        return '音乐';
      case 'musicvideo':
        return '音乐视频';
      case 'trailer':
        return '预告片';
      case 'boxset':
        return '合集';
      default:
        return type ?? '视频';
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final authState = ref.watch(authProvider);
    final thumbnailUrl = widget.item.thumbnailUrlWithAuth(authState.embyServerUrl, authState.token);

    return GestureDetector(
      onLongPress: widget.onLongPress,
      child: TvFocusable(
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              backgroundColor: Theme.of(context).colorScheme.surface,
              body: VideoPageItem(item: widget.item),
            ),
          ));
        },
        borderRadius: 8,
        borderWidth: 2,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (thumbnailUrl != null && thumbnailUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: thumbnailUrl,
                  fit: BoxFit.cover,
                  httpHeaders: widget.item.authHeaders(authState.token),
                  memCacheWidth: 400,
                  placeholder: (_, __) => _ShimmerPlaceholder(scheme: scheme, animation: _shimmerAnimation),
                  errorWidget: (_, __, ___) => Container(
                    color: scheme.surface.withOpacity(0.3),
                    child: Icon(Icons.broken_image, color: scheme.onSurface.withOpacity(0.4)),
                  ),
                )
              else
                Container(
                  color: scheme.surface.withOpacity(0.3),
                  child: Icon(Icons.movie, color: scheme.onSurface.withOpacity(0.4)),
                ),
              // 底部渐变 + 标题 + 类型/标签
              Positioned(
                left: 0, right: 0, bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(6, 20, 6, 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        scheme.surface.withOpacity(0.85),
                        scheme.surface.withOpacity(0.6),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 类型标签
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: scheme.primary.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _getTypeLabel(widget.item.type),
                          style: TextStyle(
                            color: scheme.onPrimary,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      // 标题
                      Text(
                        widget.item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      // 标签（genres）
                      if (widget.item.displayGenres.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.item.displayGenres.take(3).join(' / '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // 继续观看进度条：当有播放位置时在底部显示细粉色条
              if (widget.item.hasProgress)
                Positioned(
                  left: 0, right: 0, bottom: 0,
                  child: LinearProgressIndicator(
                    value: widget.item.progressPercent,
                    minHeight: 3,
                    backgroundColor: scheme.onSurface.withOpacity(0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 骨架屏占位符组件：渐变 shimmer 效果
class _ShimmerPlaceholder extends StatelessWidget {
  final ColorScheme scheme;
  final Animation<double> animation;

  const _ShimmerPlaceholder({required this.scheme, required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                scheme.surface.withOpacity(0.3),
                scheme.surface.withOpacity(0.5),
                scheme.surface.withOpacity(0.3),
              ],
              stops: [
                (animation.value - 1).clamp(0.0, 1.0),
                animation.value.clamp(0.0, 1.0),
                (animation.value + 1).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}
