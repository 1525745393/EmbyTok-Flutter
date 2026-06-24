import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/image_cache_manager.dart';
import 'tv_focusable.dart';
import 'video_page_item.dart';

/// 海报墙视图：网格布局展示视频缩略图
class PosterGridView extends ConsumerStatefulWidget {
  final ScrollController? scrollController;

  const PosterGridView({super.key, this.scrollController});

  @override
  ConsumerState<PosterGridView> createState() => _PosterGridViewState();
}

class _PosterGridViewState extends ConsumerState<PosterGridView> {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final videoState = ref.watch(videoListProvider);
    final filteredItems = ref.watch(gridFilteredVideoListProvider);

    if (videoState.items.isEmpty && videoState.isLoading) {
      return Center(child: CircularProgressIndicator(color: scheme.primary));
    }
    if (filteredItems.isEmpty) {
      return Center(
        child: Text('暂无视频', style: TextStyle(color: scheme.onSurface.withOpacity(0.7), fontSize: 16)),
      );
    }

    return GridView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.65,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: filteredItems.length + (videoState.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        // 分页加载触发（基于原始列表，因为过滤是客户端行为）
        if (videoState.hasMore && index >= videoState.items.length - 3 && !videoState.isLoading) {
          ref.read(videoListProvider.notifier).loadMore();
        }
        // 末尾加载指示器
        if (index >= filteredItems.length) {
          return Center(child: CircularProgressIndicator(color: scheme.primary));
        }
        final item = filteredItems[index];
        return _PosterCard(key: Key(item.id), item: item);
      },
    );
  }
}

/// 单个海报卡片
class _PosterCard extends ConsumerWidget {
  final MediaItem item;
  const _PosterCard({super.key, required this.item});

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
                cacheManager: AppImageCacheManager.thumbnail,
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
            // 底部渐变 + 标题
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      scheme.surface.withOpacity(0.75),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: scheme.onSurface, fontSize: 12, fontWeight: FontWeight.w600),
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
