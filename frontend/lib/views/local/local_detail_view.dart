import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/local_video_provider.dart';
import '../../models/local_video_item.dart';
import '../../services/local_video_service.dart';
import '../../services/tmdb_service.dart';
import '../../services/scrape_service.dart';
import 'person_detail_view.dart';

/// 本地视频详情页（P1 #7）
class LocalDetailPage extends ConsumerStatefulWidget {
  final LocalVideoItem item;
  final VoidCallback? onPlay; // 播放回调（列表页注入）
  const LocalDetailPage({super.key, required this.item, this.onPlay});

  @override
  ConsumerState<LocalDetailPage> createState() => _LocalDetailPageState();
}

class _LocalDetailPageState extends ConsumerState<LocalDetailPage> {
  /// 缓存继续观看进度 future，避免 ref.watch 触发 rebuild 时重新请求
  late final Future<int?> _resumeFuture =
      LocalVideoService().readResumeMs(widget.item.pathHash);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final scraped = ref.watch(localVideoProvider).scrapedMap[widget.item.pathHash];
    final isFav = ref.watch(localVideoProvider).favoriteHashes.contains(widget.item.pathHash);
    final totalMs = widget.item.duration.inMilliseconds;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // 顶部 backdrop：标题+播放按钮叠在底部渐变上（对齐在线 Emby 详情）
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: scheme.surface,
            actions: [
              // 重新刮削（解决旧缓存无演员头像问题）
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                tooltip: '重新刮削元数据',
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  messenger.showSnackBar(const SnackBar(content: Text('正在重新刮削…')));
                  final result = await ScrapeService.scrapeFile(
                    widget.item.pathHash,
                    widget.item.name,
                  );
                  if (result != null) {
                    // 写入磁盘缓存，避免重启后演员头像/元数据丢失
                    await ScrapeService.saveCache(widget.item.pathHash, result);
                    final cached = Map<String, ScrapedMedia>.from(ref.read(localVideoProvider).scrapedMap);
                    cached[widget.item.pathHash] = result;
                    ref.read(localVideoProvider.notifier).state =
                        ref.read(localVideoProvider).copyWith(scrapedMap: cached);
                    messenger.showSnackBar(const SnackBar(content: Text('刮削完成')));
                  }
                },
              ),
            ],
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
                          scraped?.title ?? widget.item.name,
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
                          '${scraped?.year ?? ''} · ${widget.item.durationLabel}${scraped?.rating != null ? ' · ★${scraped!.rating!.toStringAsFixed(1)}' : ''}',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        // 操作行
                        Row(
                          children: [
                            FutureBuilder<int?>(
                              future: _resumeFuture,
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
                                    widget.onPlay?.call();
                                  },
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () => ref.read(localVideoProvider.notifier).toggleFavorite(widget.item.pathHash),
                              icon: Icon(isFav ? Icons.favorite : Icons.favorite_border,
                                  color: isFav ? Colors.pink : Colors.white),
                              tooltip: isFav ? '取消收藏' : '收藏',
                            ),
                            IconButton(
                              onPressed: () => Share.shareXFiles([XFile(widget.item.path)], subject: widget.item.name),
                              icon: const Icon(Icons.share, color: Colors.white),
                              tooltip: '分享',
                            ),
                            IconButton(
                              onPressed: () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text('删除视频'),
                                    content: Text('确定删除 ${widget.item.name} 吗？此操作不可恢复。'),
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
                                  await ref.read(localVideoProvider.notifier).deleteByIds({widget.item.id});
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
                        // 海报（点击放大）
                        GestureDetector(
                          onTap: () => _openImageViewer(context, TmdbService.posterUrl(scraped!.posterPath!)),
                          child: ClipRRect(
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
                        ),
                        const SizedBox(width: 12),
                        // 缩略图（点击放大）
                        Expanded(
                          child: GestureDetector(
                            onTap: scraped?.backdropPath != null
                                ? () => _openImageViewer(context, TmdbService.backdropUrl(scraped!.backdropPath!))
                                : null,
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
                  // 简介（可展开/收起）
                  if (scraped?.overview != null && scraped!.overview!.isNotEmpty) ...[
                    _ExpandableOverview(text: scraped.overview!),
                    const SizedBox(height: 20),
                  ],
                  // 演员（横滑头像列表，对齐在线）
                  if (scraped != null && scraped.cast.isNotEmpty) ...[
                    const Text('演员', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 110,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: scraped.cast.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, i) {
                          final c = scraped.cast[i];
                          final profile = c['profilePath'];
                          final personId = int.tryParse(c['id'] ?? '');
                          return GestureDetector(
                            onTap: () {
                              if (personId != null && personId > 0) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PersonDetailPage(
                                      personId: personId,
                                      name: c['name'] ?? '',
                                      profilePath: profile,
                                    ),
                                  ),
                                );
                              } else if (profile != null && profile.isNotEmpty) {
                                _openImageViewer(context, TmdbService.personUrl(profile));
                              }
                            },
                            child: Column(
                              children: [
                                ClipOval(
                                  child: SizedBox(
                                    width: 64,
                                    height: 64,
                                    child: profile != null && profile.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: TmdbService.personUrl(profile),
                                            fit: BoxFit.cover,
                                            placeholder: (_, __) => Container(
                                              color: scheme.surfaceContainerHighest,
                                            ),
                                            errorWidget: (_, __, ___) => Container(
                                              color: scheme.surfaceContainerHighest,
                                              child: const Icon(Icons.person, size: 32),
                                            ),
                                          )
                                        : Container(
                                            color: scheme.surfaceContainerHighest,
                                            child: const Icon(Icons.person, size: 32),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                SizedBox(
                                  width: 72,
                                  child: Text(
                                    c['name'] ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                                if (c['character'] != null && c['character']!.isNotEmpty)
                                  Text(
                                    c['character']!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 9, color: Colors.white54),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  // 相关推荐
                  if (scraped.tmdbId > 0) ...[
                    const SizedBox(height: 20),
                    const Text('相关推荐', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 180,
                      child: FutureBuilder<List<Map<String, dynamic>>>(
                        future: scraped.type == 'tv'
                            ? TmdbService.getTvRecommendations(scraped.tvId ?? scraped.tmdbId)
                            : TmdbService.getRecommendations(scraped.tmdbId),
                        builder: (_, snap) {
                          if (!snap.hasData || snap.data!.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          final recs = snap.data!.take(10).toList();
                          return ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: recs.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 10),
                            itemBuilder: (_, i) {
                              final r = recs[i];
                              final poster = r['poster_path'] as String?;
                              return SizedBox(
                                width: 110,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: poster != null
                                          ? CachedNetworkImage(
                                              imageUrl: TmdbService.posterUrl(poster),
                                              height: 140, width: 110, fit: BoxFit.cover,
                                            )
                                          : Container(height: 140, width: 110, color: Colors.grey[800]),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      r['title'] ?? r['name'] ?? '',
                                      maxLines: 1, overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                  // 外部链接（TMDB）
                  if (scraped.tmdbId > 0) ...[
                    const SizedBox(height: 20),
                    const Text('外部链接', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.link, size: 16),
                          label: const Text('TheMovieDb'),
                          onPressed: () => _openTmdbUrl(scraped.tmdbId, scraped.type),
                        ),
                        if (scraped.imdbId != null && scraped.imdbId!.isNotEmpty)
                          ActionChip(
                            avatar: const Icon(Icons.movie, size: 16),
                            label: const Text('IMDb'),
                            onPressed: () async {
                              await launchUrl(
                                Uri.parse('https://www.imdb.com/title/${scraped.imdbId}'),
                                mode: LaunchMode.externalApplication,
                              );
                            },
                          ),
                      ],
                    ),
                  ],
                  // 加入时间
                  if (scraped.scrapedAt > 0) ...[
                    const SizedBox(height: 16),
                    Text(
                      '加入时间: ${DateTime.fromMillisecondsSinceEpoch(scraped.scrapedAt).toString().substring(0, 16)}',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                  // TMDB 评论
                  if (scraped.tmdbId > 0) ...[
                    const SizedBox(height: 20),
                    const Text('评论', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: scraped.type == 'tv'
                          ? TmdbService.getTvReviews(scraped.tvId ?? scraped.tmdbId)
                          : TmdbService.getMovieReviews(scraped.tmdbId),
                      builder: (_, snap) {
                        if (!snap.hasData || snap.data!.isEmpty) {
                          return const Text('暂无评论', style: TextStyle(color: Colors.white38, fontSize: 12));
                        }
                        return Column(
                          children: snap.data!.take(3).map((r) {
                            final author = r['author'] ?? '';
                            final content = r['content'] ?? '';
                            final rating = r['author_details']?['rating'];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white10,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.person, size: 14, color: Colors.white54),
                                      const SizedBox(width: 4),
                                      Text(author, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                      if (rating != null) ...[
                                        const SizedBox(width: 8),
                                        Text('★$rating', style: const TextStyle(fontSize: 11, color: Colors.amber)),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(content, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                  // 媒体信息
                  const SizedBox(height: 16),
                  const Text('媒体信息', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  if (scraped.directors.isNotEmpty)
                    _infoRow('导演', scraped.directors.join(' / ')),
                  if (scraped.studios.isNotEmpty)
                    _infoRow('出品', scraped.studios.join(' / ')),
                  _infoRow('分辨率', widget.item.resolutionLabel),
                  _infoRow('时长', widget.item.durationLabel),
                  _infoRow('大小', widget.item.sizeLabel),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 信息行
  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 12))),
        ],
      ),
    );
  }

  /// 打开 TMDB 网页
  void _openTmdbUrl(int tmdbId, String type) async {
    final url = type == 'tv'
        ? 'https://www.themoviedb.org/tv/$tmdbId'
        : 'https://www.themoviedb.org/movie/$tmdbId';
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  /// 全屏查看图片（点击海报/缩略图放大）
  void _openImageViewer(BuildContext context, String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.transparent, iconTheme: const IconThemeData(color: Colors.white)),
          body: Center(
            child: InteractiveViewer(
              child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }
}

/// 可展开/收起的简介（对齐在线详情）
class _ExpandableOverview extends StatefulWidget {
  final String text;
  const _ExpandableOverview({required this.text});

  @override
  State<_ExpandableOverview> createState() => _ExpandableOverviewState();
}

class _ExpandableOverviewState extends State<_ExpandableOverview> {
  bool _expanded = false;
  static const _maxLines = 4;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.5);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('简介', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(
          widget.text,
          style: style,
          maxLines: _expanded ? null : _maxLines,
          overflow: _expanded ? null : TextOverflow.ellipsis,
        ),
        if (widget.text.length > 120)
          TextButton(
            onPressed: () => setState(() => _expanded = !_expanded),
            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
            child: Text(_expanded ? '收起' : '展开', style: const TextStyle(fontSize: 13)),
          ),
      ],
    );
  }
}
