import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/local_video_provider.dart';
import '../../models/local_video_item.dart';
import '../../services/tmdb_service.dart';

/// 本地视频详情页（P1 #7）
class LocalDetailPage extends ConsumerWidget {
  final LocalVideoItem item;
  final VoidCallback? onPlay; // 播放回调（列表页注入）
  const LocalDetailPage({super.key, required this.item, this.onPlay});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final scraped = ref.watch(localVideoProvider).scrapedMap[item.pathHash];
    final isFav = ref.watch(localVideoProvider).favoriteHashes.contains(item.pathHash);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // 顶部 backdrop + 关闭按钮
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: scheme.surface,
            flexibleSpace: FlexibleSpaceBar(
              background: scraped?.backdropPath != null
                  ? CachedNetworkImage(
                      imageUrl: TmdbService.backdropUrl(scraped!.backdropPath!),
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(color: scheme.surfaceContainerHighest),
                    )
                  : Container(color: scheme.surfaceContainerHighest),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 海报 + 基本信息
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 海报
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 90,
                          height: 135,
                          child: scraped?.posterPath != null
                              ? CachedNetworkImage(
                                  imageUrl: TmdbService.posterUrl(scraped!.posterPath!),
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) =>
                                      Container(color: scheme.surfaceContainerHighest, child: const Icon(Icons.movie)),
                                )
                              : Container(color: scheme.surfaceContainerHighest, child: const Icon(Icons.movie)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 标题/年份/评分/时长
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              scraped?.title ?? item.name,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${scraped?.year ?? ''} · ${item.durationLabel}',
                              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 6),
                            if (scraped?.rating != null)
                              Row(
                                children: [
                                  const Icon(Icons.star, color: Colors.amber, size: 18),
                                  const SizedBox(width: 4),
                                  Text(
                                    scraped!.rating!.toStringAsFixed(1),
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 8),
                            // 类型标签
                            if (scraped != null && scraped.genres.isNotEmpty)
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: scraped.genres
                                    .map((g) => Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: scheme.surfaceContainerHighest,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(g, style: const TextStyle(fontSize: 11)),
                                        ))
                                    .toList(),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // 播放 + 收藏按钮
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            onPlay?.call();
                          },
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('播放'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: () => ref.read(localVideoProvider.notifier).toggleFavorite(item.pathHash),
                        icon: Icon(
                          isFav ? Icons.favorite : Icons.favorite_border,
                          color: isFav ? Colors.pink : null,
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // 简介
                  if (scraped?.overview != null && scraped!.overview!.isNotEmpty) ...[
                    const Text('简介', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(
                      scraped.overview!,
                      style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.5),
                    ),
                    const SizedBox(height: 20),
                  ],
                  // 演员
                  if (scraped != null && scraped.cast.isNotEmpty) ...[
                    const Text('演员', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    ...scraped.cast.map((c) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            '${c['name']} · ${c['role'] ?? ''}',
                            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                          ),
                        )),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
