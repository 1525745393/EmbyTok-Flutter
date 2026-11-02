// 海报卡片共享组件（批次Q1：discover/follow 两页同构海报卡收敛为单一组件）
//
// 行为与两页原始实现完全一致：
// - 点击整列表进入播放页（数据与视频流列表不同源，不支持 /?initialId= 查找）
// - Material+InkWell 水波纹（discover 原为裸 GestureDetector，一并消除交互残留）
// - nextUpKind 非空时渲染右上来源角标（演员新作 / 剧集更新）
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/image_cache_manager.dart';
import 'last_watched_badge.dart';

/// 海报卡片：封面 + 「上次看到」角标 + 可选来源角标 + 标题
class PosterCard extends ConsumerWidget {
  const PosterCard({
    super.key,
    required this.item,
    required this.items,
    required this.source,
    this.nextUpKind,
    this.isLastWatched = false,
  });

  final MediaItem item;
  final List<MediaItem> items; // 进入播放页后支持上下滑刷
  final String source; // 播放页数据源标识（'discover' / 'follow'）
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          // 数据与视频流列表不同源（按标签/推荐拉取），不能依赖 /?initialId=
          // 在视频流 items 中查找（会超时失败）；把整列表传给播放页，
          // 进入后可像刷抖音一样上下滑动切换
          ref
              .read(playbackListProvider.notifier)
              .setPlaybackList(items, item.id);
          context.push('/play/${item.id}', extra: {
            'item': item,
            'items': items,
            'source': source,
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
                              nextUpKind == NextUpKind.seriesUpdate
                                  ? '剧集'
                                  : '演员',
                              style: TextStyle(
                                fontSize: 11,
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
      ),
    );
  }
}
