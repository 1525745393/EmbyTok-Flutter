import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import 'tv_focusable.dart';
import 'video_page_item.dart';

/// 海报墙视图：网格布局展示视频缩略图
class PosterGridView extends ConsumerStatefulWidget {
  const PosterGridView({super.key});

  @override
  ConsumerState<PosterGridView> createState() => _PosterGridViewState();
}

class _PosterGridViewState extends ConsumerState<PosterGridView> {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final videoState = ref.watch(videoListProvider);

    if (videoState.items.isEmpty && videoState.isLoading) {
      return Center(child: CircularProgressIndicator(color: scheme.primary));
    }
    if (videoState.items.isEmpty) {
      return Center(
        child: Text('暂无视频', style: TextStyle(color: scheme.onSurface.withOpacity(0.7), fontSize: 16)),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.65,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: videoState.items.length + (videoState.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        // 分页加载触发
        if (videoState.hasMore && index >= videoState.items.length - 3 && !videoState.isLoading) {
          ref.read(videoListProvider.notifier).loadMore();
        }
        // 末尾加载指示器
        if (index >= videoState.items.length) {
          return Center(child: CircularProgressIndicator(color: scheme.primary));
        }
        final item = videoState.items[index];
        return _PosterCard(key: Key(item.id), item: item);
      },
    );
  }
}

/// 单个海报卡片
class _PosterCard extends ConsumerWidget {
  final MediaItem item;
  const _PosterCard({super.key, required this.item});

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
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final authState = ref.watch(authProvider);
    final thumbnailUrl = item.thumbnailUrlWithAuth(authState.embyServerUrl, authState.token);

    return TvFocusable(
      onTap: () {
        // 点击海报进入视频播放
        Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            body: VideoPageItem(item: item),
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
                httpHeaders: item.authHeaders(authState.token),
                memCacheWidth: 400,
                placeholder: (_, __) => Container(
                  color: scheme.surface.withOpacity(0.3),
                  child: Center(
                    child: CircularProgressIndicator(color: scheme.primary, strokeWidth: 2),
                  ),
                ),
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
                        _getTypeLabel(item.type),
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
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    // 标签（genres）
                    if (item.displayGenres.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.displayGenres.take(3).join(' / '),
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
            if (item.hasProgress)
              Positioned(
                left: 0, right: 0, bottom: 0,
                child: LinearProgressIndicator(
                  value: item.progressPercent,
                  minHeight: 3,
                  backgroundColor: scheme.onSurface.withOpacity(0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
