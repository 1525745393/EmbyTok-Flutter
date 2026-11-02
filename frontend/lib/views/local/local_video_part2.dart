part of 'local_video_view.dart';

/// 本地收藏页：按电影/电视剧/集分区横滑
class LocalFavoritesPage extends ConsumerWidget {
  const LocalFavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(localVideoProvider);
    final favs = state.items
        .where((e) => state.favoriteHashes.contains(e.pathHash))
        .toList();

    // 按刮削类型分区
    final movies = <LocalVideoItem>[];
    final tvs = <LocalVideoItem>[];
    final episodes = <LocalVideoItem>[];
    for (final it in favs) {
      final s = state.scrapedMap[it.pathHash];
      if (s?.type == 'tv') {
        // 电视剧：按 tvId 去重，只放代表海报
        tvs.add(it);
      } else if (s?.type == 'movie') {
        movies.add(it);
      } else {
        episodes.add(it);
      }
    }

    // 电视剧按 tvId 去重，每个系列只显示一张海报，角标显示集数
    final tvGroups = <String, List<LocalVideoItem>>{};
    for (final it in tvs) {
      final s = state.scrapedMap[it.pathHash];
      final key = s?.tvId != null ? 'tv_${s!.tvId}' : it.name;
      tvGroups.putIfAbsent(key, () => []).add(it);
    }
    final tvReps = tvGroups.values.map((g) => g.first).toList();

    // 演员收藏：从所有刮削结果里找已收藏演员的姓名和头像
    final actorInfo = <String, Map<String, String>>{};
    for (final s in state.scrapedMap.values) {
      for (final c in s.cast) {
        final id = c['id'];
        if (id != null &&
            id.isNotEmpty &&
            state.favoriteActorIds.contains(id)) {
          actorInfo.putIfAbsent(id, () => c);
        }
      }
    }
    final favActors = state.favoriteActorIds
        .where((id) => actorInfo.containsKey(id))
        .map((id) => actorInfo[id]!)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('收藏')),
      body: favs.isEmpty && favActors.isEmpty
          ? const Center(child: Text('暂无收藏'))
          : ListView(
              children: [
                if (movies.isNotEmpty)
                  _FavSection(title: '电影', items: movies, state: state),
                if (tvReps.isNotEmpty)
                  _FavSection(
                      title: '电视剧',
                      items: tvReps,
                      state: state,
                      isTv: true,
                      tvGroups: tvGroups),
                if (episodes.isNotEmpty)
                  _FavSection(
                      title: '集',
                      items: episodes,
                      state: state,
                      useBackdrop: true),
                if (favActors.isNotEmpty) _FavActorsSection(actors: favActors),
              ],
            ),
    );
  }
}

class _FavSection extends StatelessWidget {
  const _FavSection({
    required this.title,
    required this.items,
    required this.state,
    this.isTv = false,
    this.useBackdrop = false,
    this.tvGroups,
  });
  final String title;
  final List<LocalVideoItem> items;
  final LocalVideoState state;
  final bool isTv;
  final bool useBackdrop;
  final Map<String, List<LocalVideoItem>>? tvGroups;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              Text('查看所有',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            ],
          ),
        ),
        SizedBox(
          height: useBackdrop ? 180 : 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final it = items[i];
              final s = state.scrapedMap[it.pathHash];
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<Widget>(
                    builder: (_) => LocalDetailPage(
                        item: it,
                        onPlay: () {
                          // LocalDetailPage 内部已先 pop 自己，这里直接 push 播放器
                          Navigator.push(
                            context,
                            MaterialPageRoute<Widget>(
                              builder: (_) =>
                                  LocalPlayPage(items: [it], initialIndex: 0),
                            ),
                          );
                        }),
                  ),
                ),
                child: Container(
                  width: useBackdrop ? 280 : 120,
                  margin: const EdgeInsets.only(right: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: useBackdrop ? 280 : 120,
                              height: useBackdrop ? 150 : 160,
                              child: s?.posterPath != null
                                  ? CachedNetworkImage(
                                      imageUrl:
                                          TmdbService.posterUrl(s!.posterPath!),
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      color: Colors.grey[800],
                                      child: const Icon(Icons.movie,
                                          size: 32, color: Colors.white54),
                                    ),
                            ),
                          ),
                          if (isTv && tvGroups != null)
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Builder(builder: (_) {
                                final s2 = state.scrapedMap[it.pathHash];
                                final key = s2?.tvId != null
                                    ? 'tv_${s2!.tvId}'
                                    : it.name;
                                final count = tvGroups?[key]?.length ?? 1;
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$count',
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 11),
                                  ),
                                );
                              }),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        s?.title ?? it.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      if (s?.year != null)
                        Text('${s!.year}',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[500])),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 收藏演员分区：圆形头像横滑
class _FavActorsSection extends StatelessWidget {
  const _FavActorsSection({required this.actors});
  final List<Map<String, String>> actors;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('演员',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: actors.length,
            itemBuilder: (_, i) {
              final a = actors[i];
              final id = int.tryParse(a['id'] ?? '');
              return GestureDetector(
                onTap: id == null
                    ? null
                    : () => Navigator.push(
                          context,
                          MaterialPageRoute<Widget>(
                            builder: (_) => PersonDetailPage(
                              personId: id,
                              name: a['name'] ?? '',
                              profilePath: a['profilePath'],
                            ),
                          ),
                        ),
                child: Container(
                  width: 80,
                  margin: const EdgeInsets.only(right: 12),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundImage: a['profilePath'] != null &&
                                a['profilePath']!.isNotEmpty
                            ? CachedNetworkImageProvider(
                                TmdbService.personUrl(a['profilePath']!))
                            : null,
                        child: a['profilePath'] == null ||
                                a['profilePath']!.isEmpty
                            ? const Icon(Icons.person, size: 32)
                            : null,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        a['name'] ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 按季/集数字序排序（多季正确序：S01E9 在 S01E10 前）；解析不到季集号的文件排最后
List<LocalVideoItem> _sortBySeasonEpisode(List<LocalVideoItem> items) {
  final list = [...items];
  list.sort((a, b) {
    final ea = ScrapeService.extractEpisode(a.name);
    final eb = ScrapeService.extractEpisode(b.name);
    // 解析不到季集号时用大数排最后
    final ka = (ea?.season ?? 9999, ea?.episode ?? 9999);
    final kb = (eb?.season ?? 9999, eb?.episode ?? 9999);
    final c = ka.$1.compareTo(kb.$1);
    if (c != 0) return c;
    final d = ka.$2.compareTo(kb.$2);
    if (d != 0) return d;
    return a.name.compareTo(b.name);
  });
  return list;
}

/// 剧集文件夹内页：显示某部剧的所有集
class _FolderEpisodePage extends ConsumerStatefulWidget {
  const _FolderEpisodePage({required this.folderName, required this.items});
  final String folderName;
  final List<LocalVideoItem> items;

  @override
  ConsumerState<_FolderEpisodePage> createState() => _FolderEpisodePageState();
}

class _FolderEpisodePageState extends ConsumerState<_FolderEpisodePage> {
  bool _overviewExpanded = false;

  /// 每集详情缓存：'season-episode' -> {name, overview, stillPath}（key 含季号避免多季冲突）
  final Map<String, Map<String, dynamic>> _epInfo = {};
  bool _loadedEpInfo = false;

  @override
  void initState() {
    super.initState();
    _loadEpisodeInfo();
  }

  /// 并发分批拉取每集 TMDB 详情（每批完成后增量更新 UI）
  Future<void> _loadEpisodeInfo() async {
    final state = ref.read(localVideoProvider);
    final sorted = _sortBySeasonEpisode(widget.items);
    if (sorted.isEmpty) return;
    final meta = state.scrapedMap[sorted.first.pathHash];
    final tvId = meta?.tvId;
    if (tvId == null || tvId <= 0) return;
    const batchSize = 5; // 限制并发，避免打满 TMDB 速率限制
    for (var i = 0; i < sorted.length; i += batchSize) {
      final batch = sorted.skip(i).take(batchSize).toList();
      await Future.wait(batch.map((it) async {
        final ep = ScrapeService.extractEpisode(it.name);
        if (ep == null) return;
        final details =
            await TmdbService.getTvEpisodeDetails(tvId, ep.season, ep.episode);
        if (details.isNotEmpty) {
          _epInfo['${ep.season}-${ep.episode}'] = {
            'name': details['name'] ?? '',
            'overview': details['overview'] ?? '',
            'stillPath': details['still_path'],
            'airDate': details['air_date'] ?? '',
            'runtime': details['runtime'],
          };
        }
      }));
      if (mounted) setState(() => _loadedEpInfo = true);
    }
  }

  /// 从文件名提取干净的集标题，去掉 SxxEyy、扩展名
  String _episodeTitle(String filename) {
    var n = filename;
    final dot = n.lastIndexOf('.');
    if (dot > 0) n = n.substring(0, dot);
    n = n.replaceFirst(RegExp(r'^[Ss]\d{1,2}[._ -]?[Ee]\d{1,2}[._ -]*'), '');
    n = n.replaceFirst(RegExp(r'^第?\d{1,3}[集話][._ -]*'), '');
    return n.trim().isEmpty ? filename : n.trim();
  }

  Widget _stillFallback(ScrapedMedia? meta) {
    if (meta?.backdropPath != null) {
      return CachedNetworkImage(
          imageUrl: TmdbService.backdropUrl(meta!.backdropPath!),
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => Container(color: Colors.grey[800]));
    }
    return Container(color: Colors.grey[800]);
  }

  /// 分享单集：系统媒体库 item 的 path 为空，经 AssetEntity.fromId 取真实路径（与详情页分享一致）
  Future<void> _shareItem(LocalVideoItem item) async {
    var path = item.path;
    if (path.isEmpty && item.assetId != null) {
      try {
        final entity = await AssetEntity.fromId(item.assetId!);
        final file = await entity?.file;
        if (file != null) path = file.path;
      } catch (_) {}
    }
    if (path.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('该文件暂不支持分享')));
      }
      return;
    }
    await SharePlus.instance
        .share(ShareParams(files: [XFile(path)], subject: item.name));
  }

  void _openImageViewer(String url) {
    Navigator.push(
      context,
      MaterialPageRoute<Widget>(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
              backgroundColor: Colors.transparent,
              iconTheme: const IconThemeData(color: Colors.white)),
          body: Center(
              child: InteractiveViewer(
                  child:
                      CachedNetworkImage(imageUrl: url, fit: BoxFit.contain))),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(localVideoProvider);
    // 按季/集数字序排序（多季正确序，且与 _loadEpisodeInfo 的遍历顺序一致）
    final sorted = _sortBySeasonEpisode(widget.items);
    if (sorted.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.folderName)),
        body: const Center(child: Text('没有视频')),
      );
    }
    // 按季统计：单季显示"第 X 季"，多季显示"N 季"
    final seasonCounts = <int, int>{};
    for (final it in sorted) {
      final s = ScrapeService.extractEpisode(it.name)?.season ?? 1;
      seasonCounts[s] = (seasonCounts[s] ?? 0) + 1;
    }
    final seasonLabel = seasonCounts.length > 1
        ? '${seasonCounts.length} 季 · ${sorted.length} 集'
        : '第 ${seasonCounts.keys.first} 季 · ${sorted.length} 集';
    final first = sorted.first;
    final meta = state.scrapedMap[first.pathHash];
    final cast = meta?.cast ?? [];
    // 整剧收藏：所有集都收藏才算收藏
    final allFaved =
        sorted.every((e) => state.favoriteHashes.contains(e.pathHash));

    return Scaffold(
      body: ListView(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 24),
        children: [
          _buildBackdrop(context, ref, sorted, meta, allFaved),
          _buildPosterBackdropRow(context, meta),
          _buildGenreRatingTags(meta),
          _buildOverview(meta),
          _buildSeasonHeader(context, seasonLabel, sorted, meta),
          _buildEpisodeGrid(context, sorted, meta),
          ..._buildCastRow(context, cast),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// 顶部 backdrop 大图 + 返回/重新刮削 + 操作行（整剧收藏、分享、删除）
  Widget _buildBackdrop(
    BuildContext context,
    WidgetRef ref,
    List<LocalVideoItem> sorted,
    ScrapedMedia? meta,
    bool allFaved,
  ) {
    final state = ref.watch(localVideoProvider);
    final first = sorted.first;
    return Stack(
      children: [
        SizedBox(
          height: 280,
          width: double.infinity,
          child: meta?.backdropPath != null
              ? CachedNetworkImage(
                  imageUrl: TmdbService.backdropUrl(meta!.backdropPath!),
                  fit: BoxFit.cover)
              : Container(color: Colors.grey[900]),
        ),
        Container(
          height: 280,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.85)
              ],
            ),
          ),
        ),
        Positioned(
          top: (ref.watch(notchAvoidanceProvider)
                  ? MediaQuery.of(context).padding.top
                  : 0) +
              4,
          left: 0,
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        // 顶部右侧：重新刮削
        Positioned(
          top: (ref.watch(notchAvoidanceProvider)
                  ? MediaQuery.of(context).padding.top
                  : 0) +
              4,
          right: 0,
          child: IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: '重新刮削',
            onPressed: () async {
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('正在重新刮削…')));
              final result =
                  await ScrapeService.scrapeTvSeries(widget.folderName);
              if (result != null) {
                // 整剧所有集共享系列元数据；scrapeTvSeries 结果不含季集号，
                // 逐集按文件名解析保留 SxxExx，避免覆盖缓存后角标/缺集检测失效
                final cached = Map<String, ScrapedMedia>.from(
                    ref.read(localVideoProvider).scrapedMap);
                for (final it in sorted) {
                  final ep = ScrapeService.extractEpisode(it.name);
                  final media = ep != null
                      ? ScrapeService.applyEpisodeInfo(
                          result, ep.season, ep.episode)
                      : result;
                  cached[it.pathHash] = media;
                  // 整剧重刮必须逐集落盘：仅 updateScrapedMap 只改内存，重启后
                  // loadCache 从 SP 读回旧数据导致结果丢失（与详情页重刮 saveCache
                  // 持久化路径一致，batch 25 F1；saveCache 保留旧 scrapedAt）
                  await ScrapeService.saveCache(it.pathHash, media);
                }
                ref.read(localVideoProvider.notifier).updateScrapedMap(cached);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('刮削完成')));
              }
            },
          ),
        ),
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(meta?.title ?? widget.folderName,
                  maxLines: 2,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black54)])),
              const SizedBox(height: 4),
              Text(
                [
                  if (meta?.year != null) '${meta!.year}',
                  if (meta?.rating != null)
                    '★ ${meta!.rating!.toStringAsFixed(1)}',
                  '${sorted.length} 集',
                ].join('  ·  '),
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              // 操作行：播放 + 收藏 + 分享 + 删除
              Row(
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('播放',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<Widget>(
                            builder: (_) =>
                                LocalPlayPage(items: sorted, initialIndex: 0))),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      // 整剧收藏/取消：切换所有集
                      for (final it in sorted) {
                        if (allFaved) {
                          ref
                              .read(localVideoProvider.notifier)
                              .toggleFavorite(it.pathHash);
                        } else if (!state.favoriteHashes
                            .contains(it.pathHash)) {
                          ref
                              .read(localVideoProvider.notifier)
                              .toggleFavorite(it.pathHash);
                        }
                      }
                    },
                    icon: Icon(
                        allFaved ? Icons.favorite : Icons.favorite_border,
                        color: allFaved ? Colors.pink : Colors.white),
                  ),
                  IconButton(
                    onPressed: () => _shareItem(first),
                    icon: const Icon(Icons.share, color: Colors.white),
                  ),
                  IconButton(
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('删除整剧'),
                          content: Text(
                              '确定删除 ${widget.folderName} 共 ${sorted.length} 集吗？此操作不可恢复。'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('取消')),
                            TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: TextButton.styleFrom(
                                    foregroundColor: Colors.red),
                                child: const Text('删除')),
                          ],
                        ),
                      );
                      if (ok == true) {
                        await ref
                            .read(localVideoProvider.notifier)
                            .deleteByIds(sorted.map((e) => e.id).toSet());
                        if (!context.mounted) return;
                        Navigator.pop(context);
                      }
                    },
                    icon: const Icon(Icons.delete_outline, color: Colors.white),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 海报 + backdrop 并排（点击看大图）
  Widget _buildPosterBackdropRow(BuildContext context, ScrapedMedia? meta) {
    if (meta?.posterPath == null) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () =>
                    _openImageViewer(TmdbService.posterUrl(meta.posterPath!)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: TmdbService.posterUrl(meta!.posterPath!),
                    width: 90,
                    height: 135,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: meta.backdropPath != null
                      ? () => _openImageViewer(
                          TmdbService.backdropUrl(meta.backdropPath!))
                      : null,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: meta.backdropPath != null
                        ? CachedNetworkImage(
                            imageUrl:
                                TmdbService.backdropUrl(meta.backdropPath!),
                            height: 135,
                            fit: BoxFit.cover)
                        : Container(height: 135, color: Colors.grey[800]),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  /// 类型标签 + 评分
  Widget _buildGenreRatingTags(ScrapedMedia? meta) {
    if (meta?.genres == null || meta!.genres.isEmpty)
      return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ...meta.genres.map((g) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(4)),
                    child: Text(g, style: const TextStyle(fontSize: 11)),
                  )),
              if (meta.rating != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.star, size: 12, color: Colors.amber),
                    const SizedBox(width: 2),
                    Text(meta.rating!.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 11)),
                  ]),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  /// 简介（可展开）
  Widget _buildOverview(ScrapedMedia? meta) {
    if (meta?.overview == null || meta!.overview!.isEmpty)
      return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('简介',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(meta.overview!,
                  maxLines: _overviewExpanded ? null : 4,
                  overflow: _overviewExpanded ? null : TextOverflow.ellipsis,
                  style: TextStyle(
                      color: Colors.grey[300], fontSize: 13, height: 1.5)),
              if (meta.overview!.length > 120)
                TextButton(
                  onPressed: () =>
                      setState(() => _overviewExpanded = !_overviewExpanded),
                  style: TextButton.styleFrom(
                      padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
                  child: Text(_overviewExpanded ? '收起' : '展开',
                      style: const TextStyle(fontSize: 13)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  /// 季标题 + 查看全部
  Widget _buildSeasonHeader(
    BuildContext context,
    String seasonLabel,
    List<LocalVideoItem> sorted,
    ScrapedMedia? meta,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(seasonLabel,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<Widget>(
                    builder: (_) => _AllEpisodesPage(
                      items: sorted,
                      meta: meta,
                      epInfo: _epInfo,
                      episodeTitle: _episodeTitle,
                    ),
                  ),
                ),
                child: const Text('查看全部'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  /// 剧集网格（2列，缩略图 + 集号 + 简介）
  Widget _buildEpisodeGrid(
    BuildContext context,
    List<LocalVideoItem> sorted,
    ScrapedMedia? meta,
  ) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: sorted.length,
      itemBuilder: (_, i) {
        final it = sorted[i];
        final ep = ScrapeService.extractEpisode(it.name);
        final info = ep != null ? _epInfo['${ep.season}-${ep.episode}'] : null;
        final stillPath = info?['stillPath'] as String?;
        final epName = (info?['name'] as String?)?.isNotEmpty == true
            ? info!['name'] as String
            : _episodeTitle(it.name);
        final airDate = info?['airDate'] as String?;
        final runtime = info?['runtime'] as int?;
        final overview = info?['overview'] as String?;
        final epNum = ep?.episode ?? i + 1;
        return InkWell(
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute<Widget>(
                  builder: (_) =>
                      LocalPlayPage(items: sorted, initialIndex: i))),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: BoxDecoration(
                color: Colors.grey[850],
                borderRadius: BorderRadius.circular(10)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      stillPath != null && stillPath.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: TmdbService.stillUrl(stillPath),
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => _stillFallback(meta))
                          : _stillFallback(meta),
                      // 底部渐变
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black54]),
                        ),
                      ),
                      // 集号角标
                      Positioned(
                        left: 8,
                        bottom: 6,
                        child: Text('$epNum',
                            style: const TextStyle(
                                color: Colors.orange,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                shadows: [
                                  Shadow(blurRadius: 3, color: Colors.black)
                                ])),
                      ),
                      // 播放按钮
                      Positioned(
                        right: 6,
                        bottom: 4,
                        child: Icon(Icons.play_circle_fill,
                            color: Colors.white.withValues(alpha: 0.9),
                            size: 22),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(epName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                      if (airDate != null || runtime != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                              [
                                if (airDate != null && airDate.isNotEmpty)
                                  airDate,
                                if (runtime != null) '${runtime}m'
                              ].join('  ·  '),
                              style: TextStyle(
                                  fontSize: 10, color: Colors.grey[500])),
                        ),
                      if (overview != null && overview.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(overview,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[400],
                                  height: 1.3)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 演职人员横向列表
  List<Widget> _buildCastRow(BuildContext context, List<dynamic> cast) {
    if (cast.isEmpty) return const [];
    return [
      const SizedBox(height: 24),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Text('演职人员',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      const SizedBox(height: 12),
      SizedBox(
        height: 110,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: cast.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, i) {
            final c = cast[i];
            final profile = c['profilePath'];
            final personId = int.tryParse(c['id'] ?? '');
            return GestureDetector(
              onTap: () {
                if (personId != null && personId > 0) {
                  Navigator.push(
                      context,
                      MaterialPageRoute<Widget>(
                          builder: (_) => PersonDetailPage(
                              personId: personId,
                              name: c['name'] ?? '',
                              profilePath: profile)));
                } else if (profile != null && profile.isNotEmpty) {
                  _openImageViewer(TmdbService.personUrl(profile));
                }
              },
              child: SizedBox(
                width: 70,
                child: Column(
                  children: [
                    ClipOval(
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: profile != null
                            ? CachedNetworkImage(
                                imageUrl: TmdbService.personUrl(profile),
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Container(
                                    color: Colors.grey[800],
                                    child: const Icon(Icons.person,
                                        color: Colors.white24)))
                            : Container(
                                color: Colors.grey[800],
                                child: const Icon(Icons.person,
                                    color: Colors.white24)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(c['name'] ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ];
  }
}

/// 全部剧集页：完整列表展示所有集
class _AllEpisodesPage extends StatelessWidget {
  const _AllEpisodesPage(
      {required this.items,
      required this.meta,
      required this.epInfo,
      required this.episodeTitle});
  final List<LocalVideoItem> items;
  final ScrapedMedia? meta;
  final Map<String, Map<String, dynamic>> epInfo;
  final String Function(String) episodeTitle;

  @override
  Widget build(BuildContext context) {
    // 与剧集页保持一致：按季/集数字序排序
    final sorted = _sortBySeasonEpisode(items);
    return Scaffold(
      appBar: AppBar(title: Text('全部剧集 · ${sorted.length} 集')),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: sorted.length,
        itemBuilder: (_, i) {
          final it = sorted[i];
          final ep = ScrapeService.extractEpisode(it.name);
          final info = ep != null ? epInfo['${ep.season}-${ep.episode}'] : null;
          final stillPath = info?['stillPath'] as String?;
          final epName = (info?['name'] as String?)?.isNotEmpty == true
              ? info!['name'] as String
              : episodeTitle(it.name);
          final airDate = info?['airDate'] as String?;
          final runtime = info?['runtime'] as int?;
          final overview = info?['overview'] as String?;
          return ListTile(
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute<Widget>(
                    builder: (_) =>
                        LocalPlayPage(items: sorted, initialIndex: i))),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 100,
                height: 60,
                child: stillPath != null && stillPath.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: TmdbService.stillUrl(stillPath),
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            Container(color: Colors.grey[800]))
                    : meta?.backdropPath != null
                        ? CachedNetworkImage(
                            imageUrl:
                                TmdbService.backdropUrl(meta!.backdropPath!),
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                Container(color: Colors.grey[800]))
                        : Container(color: Colors.grey[800]),
              ),
            ),
            title: Text('${ep?.episode ?? i + 1}. $epName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (airDate != null || runtime != null)
                  Text(
                      [
                        if (airDate != null && airDate.isNotEmpty) airDate,
                        if (runtime != null) '${runtime}m'
                      ].join('  ·  '),
                      style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                if (overview != null && overview.isNotEmpty)
                  Text(overview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[400], height: 1.3)),
              ],
            ),
            trailing: const Icon(Icons.play_arrow, size: 20),
          );
        },
      ),
    );
  }
}
