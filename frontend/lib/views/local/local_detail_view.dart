import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/local_video_provider.dart';
import '../../models/local_video_item.dart';
import '../../services/local_video_service.dart';
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
    final totalMs = item.duration.inMilliseconds;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // 顶部 backdrop：标题+播放按钮叠在底部渐变上（对齐在线 Emby 详情）
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: scheme.surface,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  scraped?.backdropPath != null
                      ? CachedNetworkImage(
                          imageUrl: TmdbService.backdropUrl(scraped!.backdropPath!),
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(color: scheme.surfaceContainerHighest),
                        )
                      : Container(color: scheme.surfaceContainerHighest),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.85)],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          scraped?.title ?? item.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${scraped?.year ?? ''} · ${item.durationLabel}${scraped?.rating != null ? ' · ★${scraped!.rating!.toStringAsFixed(1)}' : ''}',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        // 操作行
                        Row(
                          children: [
                            FutureBuilder<int?>(
                              future: LocalVideoService().readResumeMs(item.pathHash),
                              builder: (_, snap) {
                                final ms = snap.data;
                                final progress = totalMs > 0 && ms != null ? (ms / totalMs).clamp(0.0, 1.0) : 0.0;
                                return ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black87,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  ),
                                  icon: const Icon(Icons.play_arrow, size: 18),
                                  label: Text(
                                    progress > 0.02 ? '继续观看 ${(progress * 100).round()}%' : '立即播放',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    onPlay?.call();
                                  },
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () => ref.read(localVideoProvider.notifier).toggleFavorite(item.pathHash),
                              icon: Icon(isFav ? Icons.favorite : Icons.favorite_border,
                                  color: isFav ? Colors.pink : Colors.white),
                              tooltip: isFav ? '取消收藏' : '收藏',
                            ),
                            IconButton(
                              onPressed: () => Share.shareXFiles([XFile(item.path)], subject: item.name),
                              icon: const Icon(Icons.share, color: Colors.white),
                              tooltip: '分享',
                            ),
                            IconButton(
                              onPressed: () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text('删除视频'),
                                    content: Text('确定删除 ${item.name} 吗？此操作不可恢复。'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                                        child: const Text('删除'),
                                      ),
                                    ],
                                  ),
                                );
                                if (ok == true) {
                                  await ref.read(localVideoProvider.notifier).deleteByIds({item.id});
                                  if (context.mounted) Navigator.pop(context);
                                }
                              },
                              icon: const Icon(Icons.delete_outline, color: Colors.white),
                              tooltip: '删除',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Primary 海报 + Thumb 缩略图并排（对齐在线）
                  if (scraped?.posterPath != null)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: TmdbService.posterUrl(scraped!.posterPath!),
                            width: 90,
                            height: 135,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              width: 90,
                              height: 135,
                              color: scheme.surfaceContainerHighest,
                              child: const Icon(Icons.movie),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: scraped?.backdropPath != null
                                ? CachedNetworkImage(
                                    imageUrl: TmdbService.backdropUrl(scraped!.backdropPath!),
                                    height: 135,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => Container(
                                      height: 135,
                                      color: scheme.surfaceContainerHighest,
                                    ),
                                  )
                                : Container(
                                    height: 135,
                                    color: scheme.surfaceContainerHighest,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  // 类型标签 + 年份 + 评分 + 时长
                  if (scraped != null && scraped.genres.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ...scraped.genres.map((g) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(g, style: const TextStyle(fontSize: 11)),
                            )),
                        if (scraped.year != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('${scraped.year}', style: const TextStyle(fontSize: 11)),
                          ),
                        if (scraped.rating != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.star, size: 12, color: Colors.amber),
                              const SizedBox(width: 2),
                              Text(scraped.rating!.toStringAsFixed(1), style: const TextStyle(fontSize: 11)),
                            ]),
                          ),
                      ],
                    ),
                  const SizedBox(height: 16),
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
