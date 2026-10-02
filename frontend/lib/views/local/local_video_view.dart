// 本地视频列表页：网格/列表切换 + 搜索 + 排序 + 多选删除 + 权限引导
// 对应 PRD《本地模式》§4.3 / §6
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'local_detail_view.dart';
import 'person_detail_view.dart';

import '../../models/local_video_item.dart';
import '../../models/file_source.dart';
import '../../providers/local_video_provider.dart';
import '../../providers/file_sources_provider.dart';
import '../../services/local_video_service.dart';
import '../../services/scrape_service.dart';
import '../../services/tmdb_service.dart';
import 'local_player_page.dart';
import 'local_directory_browser_view.dart';
import 'tmdb_search_page.dart';

class LocalVideoView extends ConsumerStatefulWidget {
  const LocalVideoView({super.key});

  @override
  ConsumerState<LocalVideoView> createState() => _LocalVideoViewState();
}

class _LocalVideoViewState extends ConsumerState<LocalVideoView> {
  final _searchCtrl = TextEditingController();
  String? _browsingFolder; // 正在浏览的文件夹名（null = 全部）
  String? _selectedSourceId; // 选中的文件源 ID（null = 全部）

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(localVideoProvider);
    final notifier = ref.read(localVideoProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

    // 权限引导
    if (!state.permission.hasAccess) {
      return _PermissionGuide(
        permission: state.permission,
        onRequest: () => notifier.requestPermissionAndScan(),
      );
    }

    final sources = ref.watch(fileSourcesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('我的媒体库',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border),
            tooltip: '收藏',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LocalFavoritesPage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: '搜索',
            onPressed: () => _showSearchSheet(context, state, notifier),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              switch (v) {
                case 'rescan':
                  notifier.refresh();
                case 'scrape':
                  notifier.scrapeMissing();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('开始刮削未识别视频…')),
                  );
                case 'sources':
                  context.push('/file-sources');
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'rescan', child: Text('重新扫描')),
              PopupMenuItem(value: 'scrape', child: Text('刮削未识别')),
              PopupMenuItem(value: 'sources', child: Text('管理文件源')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: notifier.refresh,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            // 刮削进度条
            if (state.scraping)
              LinearProgressIndicator(
                value: state.scrapeTotal > 0
                    ? state.scrapeDone / state.scrapeTotal
                    : null,
                minHeight: 2,
              ),

            // ── 播放记录（继续观看）──
            if (state.recentItems.isNotEmpty) ...[
              const _SectionTitle('播放记录'),
              SizedBox(
                height: 200,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: state.recentItems.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, i) =>
                      _buildResumeCard(state.recentItems[i], state),
                ),
              ),
            ],

            // ── 资源库（文件源横滑卡片）──
            if (sources.isNotEmpty) ...[
              const SizedBox(height: 8),
              const _SectionTitle('资源库', actionLabel: '查看所有'),
              SizedBox(
                height: 110,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: sources.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, i) =>
                      _buildSourceCard(sources[i], state),
                ),
              ),
            ],

            // ── 每个文件源分区：海报横滑 ──
            for (final src in sources)
              _buildSourceSection(src, state),

            // 空状态
            if (state.items.isEmpty && !state.loading)
              _EmptyState(
                onRefresh: notifier.refresh,
                hasPermission: state.permission.hasAccess,
              ),

            // 底部统计行
            if (state.items.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  _buildStatsLine(state),
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 单个文件源分区：标题 + 海报横滑
  Widget _buildSourceSection(FileSource src, LocalVideoState state) {
    final notifier = ref.read(localVideoProvider.notifier);
    final srcItems =
        state.items.where((e) => e.sourceId == src.id).toList();
    if (srcItems.isEmpty) return const SizedBox.shrink();

    // TV 类型源：每部剧一张海报卡，点击进入剧集列表
    final isTv = src.config['mediaType'] == 'tv';
    if (isTv) {
      final groups = <String, List<LocalVideoItem>>{};
      for (final it in srcItems) {
        final folder = ScrapeService.extractSeriesName(it.relativePath) ??
            (it.relativePath?.split('/').where((s) => s.isNotEmpty).last ?? '未分组');
        groups.putIfAbsent(folder, () => []).add(it);
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            '📁 ${src.name}',
            actionLabel: '查看所有',
            onAction: () => _openSourceFullList(src.id, src.name, state),
          ),
          SizedBox(
            height: 200,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: groups.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                final entry = groups.entries.elementAt(i);
                final first = entry.value.first;
                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _FolderEpisodePage(
                        folderName: entry.key,
                        items: entry.value,
                      ),
                    ),
                  ),
                  child: SizedBox(
                    width: 110,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _buildSeriesPoster(first, state),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(entry.key,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        Text('${entry.value.length}集',
                            style: TextStyle(fontSize: 10, color: Colors.grey[500])),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          '📁 ${src.name}',
          actionLabel: '查看所有',
          onAction: () => _openSourceFullList(src.id, src.name, state),
        ),
        SizedBox(
          height: 180,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: srcItems.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) =>
                _buildPosterCard(srcItems[i], state, notifier),
          ),
        ),
      ],
    );
  }

  /// 播放记录大卡片：backdrop + ▶ + 进度条 + 剩余时间
  Widget _buildResumeCard(LocalVideoItem item, LocalVideoState state) {
    final scraped = state.scrapedMap[item.pathHash];
    return GestureDetector(
      onTap: () => _playVideo(item),
      child: SizedBox(
        width: 260,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 260,
                height: 150,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // backdrop 或缩略图
                    scraped?.backdropPath != null
                        ? CachedNetworkImage(
                            imageUrl: TmdbService.backdropUrl(scraped!.backdropPath!),
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                _thumbPlaceholder(item),
                          )
                        : _thumbPlaceholder(item),
                    // 中间播放按钮
                    const Center(
                      child: Icon(Icons.play_circle_fill,
                          size: 48, color: Colors.white70),
                    ),
                    // 底部渐变 + 进度条
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            height: 3,
                            color: Colors.white24,
                            child: FutureBuilder<int?>(
                                                  future: LocalVideoService().readResumeMs(item.pathHash),
                              builder: (_, snap) {
                                final ms = snap.data ?? 0;
                                final total = item.duration.inMilliseconds;
                                final frac = total > 0
                                    ? (ms / total).clamp(0.0, 1.0)
                                    : 0.0;
                                return FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: frac,
                                  child: Container(color: const Color(0xFFFF6B6B)),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(scraped?.title ?? item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            FutureBuilder<int?>(
              future: LocalVideoService().readResumeMs(item.pathHash),
              builder: (_, snap) {
                final played = snap.data ?? 0;
                final remaining = item.duration.inMilliseconds - played;
                if (remaining <= 0) return const SizedBox.shrink();
                final h = remaining ~/ 3600000;
                final m = (remaining % 3600000) ~/ 60000;
                return Text('剩余时间: ${h > 0 ? '${h}h ' : ''}${m.toString().padLeft(2, '0')}m',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumbPlaceholder(LocalVideoItem item) {
    return Container(
      color: Colors.grey[800],
      child: const Icon(Icons.movie, size: 40, color: Colors.white30),
    );
  }

  /// 资源库卡片：拼贴封面 + 库名
  Widget _buildSourceCard(FileSource src, LocalVideoState state) {
    final srcItems =
        state.items.where((e) => e.sourceId == src.id).toList();
    // 取前3张海报拼贴
    final posters = <String?>[];
    for (final e in srcItems.take(3)) {
      posters.add(state.scrapedMap[e.pathHash]?.posterPath);
    }
    return GestureDetector(
      onTap: () => _openSourceFullList(src.id, src.name, state),
      child: Container(
        width: 130,
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(10),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 拼贴
            if (posters.isNotEmpty)
              Row(
                children: [
                  for (final p in posters)
                    Expanded(
                      child: p != null
                          ? CachedNetworkImage(
                              imageUrl: TmdbService.posterUrl(p, size: 'w185'),
                              fit: BoxFit.cover,
                            )
                          : Container(color: Colors.grey[700]),
                    ),
                ],
              ),
            // 底部渐变 + 名称
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                ),
              ),
            ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Text(
                src.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 剧集海报：取第一部集的刮削海报
  Widget _buildSeriesPoster(LocalVideoItem first, LocalVideoState state) {
    final s = state.scrapedMap[first.pathHash];
    if (s?.posterPath != null) {
      return CachedNetworkImage(
        imageUrl: TmdbService.posterUrl(s!.posterPath!),
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => _posterPlaceholder(),
      );
    }
    return _posterPlaceholder();
  }

  Widget _posterPlaceholder() => Container(
        color: Colors.grey[800],
        child: const Icon(Icons.tv, color: Colors.white24, size: 32),
      );

  /// 分区海报卡片
  Widget _buildPosterCard(LocalVideoItem item, LocalVideoState state,
      LocalVideoNotifier notifier) {
    final scraped = state.scrapedMap[item.pathHash];
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LocalDetailPage(
              item: item,
              onPlay: () => _playVideo(item),
            ),
          ),
        );
      },
      onLongPress: () => _showLongPressMenu(item),
      child: SizedBox(
        width: 100,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 100,
                height: 145,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    scraped?.posterPath != null
                        ? CachedNetworkImage(
                            imageUrl: TmdbService.posterUrl(scraped!.posterPath!),
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => _thumbPlaceholder(item),
                          )
                        : _thumbPlaceholder(item),
                    // 刮削成功角标
                    if (scraped != null)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.check, size: 12, color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(scraped?.title ?? item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            if (scraped?.year != null)
              Text('${scraped!.year}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }

  /// 打开某个文件源的完整列表页
  void _openSourceFullList(
      String sourceId, String sourceName, LocalVideoState state) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _SourceFullListPage(
          sourceId: sourceId,
          sourceName: sourceName,
        ),
      ),
    );
  }

  /// 本地收藏列表弹窗
  void _showLocalFavorites(BuildContext context, LocalVideoState state) {
    final favs =
        state.items.where((e) => state.favoriteHashes.contains(e.pathHash)).toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('我的收藏', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            Expanded(
              child: favs.isEmpty
                  ? const Center(child: Text('暂无收藏'))
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: favs.length,
                      itemBuilder: (_, i) {
                        final it = favs[i];
                        final s = state.scrapedMap[it.pathHash];
                        return ListTile(
                          leading: SizedBox(
                            width: 40,
                            height: 60,
                            child: s?.posterPath != null
                                ? CachedNetworkImage(imageUrl: TmdbService.posterUrl(s!.posterPath!), fit: BoxFit.cover)
                                : const Icon(Icons.movie),
                          ),
                          title: Text(s?.title ?? it.name, maxLines: 1),
                          onTap: () {
                            Navigator.pop(context);
                            _playVideo(it);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// 搜索底部弹窗
  void _showSearchSheet(
      BuildContext context, LocalVideoState state, LocalVideoNotifier notifier) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '搜索本地视频…',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: notifier.setKeyword,
              ),
            ),
            SizedBox(
              height: 300,
              child: state.filtered.isEmpty
                  ? const Center(child: Text('无结果'))
                  : ListView.builder(
                      itemCount: state.filtered.length,
                      itemBuilder: (_, i) {
                        final it = state.filtered[i];
                        return ListTile(
                          title: Text(it.name, maxLines: 1),
                          onTap: () {
                            Navigator.pop(context);
                            _playVideo(it);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// 类型筛选 Chip（P1 #6）
  Widget _buildTypeChip(String? value, String label) {
    final selected = ref.read(localVideoProvider).typeFilter == value;
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: (_) => ref.read(localVideoProvider.notifier).setTypeFilter(value),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  /// 文件源（媒体库）筛选 chip
  Widget _buildSourceChip(String? sourceId, String label) {
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: _selectedSourceId == sourceId,
      onSelected: (_) => setState(() => _selectedSourceId = sourceId),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  /// 统计行（P1 #5）：基于当前过滤后的列表
  String _buildStatsLineFor(List<LocalVideoItem> items, LocalVideoState state) {
    int movies = 0, tvs = 0, unscraped = 0;
    int totalBytes = 0;
    for (final it in items) {
      totalBytes += it.sizeBytes;
      final s = state.scrapedMap[it.pathHash];
      if (s == null) {
        unscraped++;
      } else if (s.type == 'tv') {
        tvs++;
      } else {
        movies++;
      }
    }
    String sizeLabel;
    if (totalBytes < 1024 * 1024) {
      sizeLabel = '${(totalBytes / 1024).toStringAsFixed(1)} MB';
    } else if (totalBytes < 1024 * 1024 * 1024) {
      sizeLabel = '${(totalBytes / 1024 / 1024).toStringAsFixed(1)} MB';
    } else {
      sizeLabel =
          '${(totalBytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
    }
    return '$movies 部电影 · $tvs 部剧集 · $unscraped 未识别 · 占用 $sizeLabel';
  }

  /// 统计行（P1 #5）
  String _buildStatsLine(LocalVideoState state) {
    int movies = 0, tvs = 0, unscraped = 0;
    int totalBytes = 0;
    for (final it in state.items) {
      totalBytes += it.sizeBytes;
      final s = state.scrapedMap[it.pathHash];
      if (s == null) {
        unscraped++;
      } else if (s.type == 'tv') {
        tvs++;
      } else {
        movies++;
      }
    }
    String sizeLabel;
    if (totalBytes < 1024 * 1024) {
      sizeLabel = '${(totalBytes / 1024).toStringAsFixed(1)} MB';
    } else if (totalBytes < 1024 * 1024 * 1024) {
      sizeLabel = '${(totalBytes / 1024 / 1024).toStringAsFixed(1)} MB';
    } else {
      sizeLabel =
          '${(totalBytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
    }
    return '$movies 部电影 · $tvs 部剧集 · $unscraped 未识别 · 占用 $sizeLabel';
  }

  /// 海报横滑区块（P1）：最近添加 / 未观看
  Widget _buildPosterRow({
    required String title,
    required List<LocalVideoItem> items,
    required LocalVideoState state,
    required void Function(LocalVideoItem) onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Text(title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ),
        SizedBox(
          height: 130,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final item = items[i];
              final scraped = state.scrapedMap[item.pathHash];
              return GestureDetector(
                onTap: () => onTap(item),
                child: SizedBox(
                  width: 88,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 88,
                          height: 118,
                          child: _VideoThumbnail(
                            assetId: item.assetId,
                            width: 88,
                            height: 118,
                            scraped: scraped,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(item.name,
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
      ],
    );
  }

  /// 最近观看横滑区块（P2）
  Widget _buildRecentRow(List<LocalVideoItem> recent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Text('继续观看',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ),
        SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: recent.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final item = recent[i];
              final scraped = ref.read(localVideoProvider).scrapedMap[item.pathHash];
              return GestureDetector(
                onTap: () => _playVideo(item),
                child: Container(
                  width: 130,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Row(
                    children: [
                      // 左侧缩略图
                      SizedBox(
                        width: 80,
                        child: _VideoThumbnail(
                          assetId: item.assetId,
                          width: 80,
                          height: 72,
                          scraped: scraped,
                        ),
                      ),
                      // 右侧信息
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(item.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500)),
                              const SizedBox(height: 4),
                              // 续播进度条（P2）
                              _ResumeProgress(
                                pathHash: item.pathHash,
                                totalMs: item.duration.inMilliseconds,
                              ),
                            ],
                          ),
                        ),
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

  /// 文件夹网格视图（VidHub 风格）：显示所有文件夹，点击进入
  Widget _buildFolderGrid(LocalVideoState state) {
    final grouped = state.grouped;
    if (grouped.isEmpty) return const SizedBox.shrink();
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: grouped.length,
      itemBuilder: (_, i) {
        final entry = grouped.entries.elementAt(i);
        final firstItem = entry.value.first;
        final scraped = state.scrapedMap[firstItem.pathHash];
        return GestureDetector(
          onTap: () => setState(() => _browsingFolder = entry.key),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 背景缩略图
                _VideoThumbnail(
                  assetId: firstItem.assetId,
                  width: double.infinity,
                  height: double.infinity,
                  scraped: scraped,
                ),
                // 底部渐变遮罩 + 文件夹名
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black87],
                    ),
                  ),
                ),
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 8,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(entry.key,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                      Text('${entry.value.length} 个视频',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 10)),
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

  /// 文件夹内视频视图：带返回按钮
  Widget _buildFolderView(
      LocalVideoState state, LocalVideoNotifier notifier, String folder) {
    final items = state.grouped[folder] ?? [];
    return Column(
      children: [
        // 文件夹标题栏 + 返回
        Container(
          padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _browsingFolder = null),
              ),
              Expanded(
                child: Text(folder,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ),
              Text('${items.length} 个',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.72,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: items.length,
            itemBuilder: (_, i) => _GridCard(
              item: items[i],
              selected: state.selected.contains(items[i].id),
              selecting: state.selecting,
              isFavorite: state.favoriteHashes.contains(items[i].pathHash),
              scraped: state.scrapedMap[items[i].pathHash],
              onTap: () {
                if (state.selecting) {
                  notifier.toggleSelected(items[i].id);
                } else {
                  _playVideo(items[i]);
                }
              },
              onLongPress: () => _showLongPressMenu(items[i]),
              onFavoriteToggle: () =>
                  notifier.toggleFavorite(items[i].pathHash),
            ),
          ),
        ),
      ],
    );
  }

  String _sortLabel(LocalVideoSort s) {
    switch (s) {
      case LocalVideoSort.modifiedDesc:
        return '最近修改';
      case LocalVideoSort.nameAsc:
        return '名称 A→Z';
      case LocalVideoSort.durationDesc:
        return '时长最长';
      case LocalVideoSort.sizeDesc:
        return '文件最大';
      case LocalVideoSort.ratingDesc:
        return '评分最高';
    }
  }

  /// 剧集聚合：同剧名的多集合并为一个卡片
  List<LocalVideoItem> _groupTvEpisodes(
      List<LocalVideoItem> items, LocalVideoState state) {
    final seen = <String>{};
    final out = <LocalVideoItem>[];
    for (final it in items) {
      final s = state.scrapedMap[it.pathHash];
      if (s != null && s.type == 'tv') {
        final key = 'tv:${s.title}';
        if (seen.contains(key)) continue;
        seen.add(key);
      }
      out.add(it);
    }
    return out;
  }

  Widget _buildGrid(
    List<LocalVideoItem> items,
    LocalVideoState state,
    LocalVideoNotifier notifier,
  ) {
    final grouped = _groupTvEpisodes(items, state);
    return RefreshIndicator(
      onRefresh: notifier.refresh,
      child: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.62,
        ),
        itemCount: grouped.length,
        itemBuilder: (_, i) {
          final it = grouped[i];
          // 计算该剧集的总集数
          final s = state.scrapedMap[it.pathHash];
          int epCount = 1;
          if (s != null && s.type == 'tv') {
            epCount = items
                .where((e) =>
                    state.scrapedMap[e.pathHash]?.type == 'tv' &&
                    state.scrapedMap[e.pathHash]?.title == s.title)
                .length;
          }
          return _GridCard(
            item: it,
            selected: state.selected.contains(it.id),
            selecting: state.selecting,
            isFavorite: state.favoriteHashes.contains(it.pathHash),
            scraped: state.scrapedMap[it.pathHash],
            episodeCount: epCount > 1 ? epCount : null,
            onTap: () {
              if (state.selecting) {
                notifier.toggleSelected(it.id);
              } else {
                // 对齐在线媒体库：点卡片进详情页，详情页里再点播放
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LocalDetailPage(
                      item: it,
                      onPlay: () => _playVideo(it),
                    ),
                  ),
                );
              }
            },
            onLongPress: () {
              if (state.selecting) {
                notifier.enterSelecting();
              } else {
                _showLongPressMenu(it);
              }
            },
            onFavoriteToggle: () => notifier.toggleFavorite(it.pathHash),
          );
        },
      ),
    );
  }

  Widget _buildList(
    List<LocalVideoItem> items,
    LocalVideoState state,
    LocalVideoNotifier notifier,
  ) {
    return RefreshIndicator(
      onRefresh: notifier.refresh,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) => _ListTileItem(
          item: items[i],
          selected: state.selected.contains(items[i].id),
          selecting: state.selecting,
          scraped: state.scrapedMap[items[i].pathHash],
          onTap: () {
            if (state.selecting) {
              notifier.toggleSelected(items[i].id);
            } else {
              _playVideo(items[i]);
            }
          },
          onLongPress: () {
            if (!state.selecting) _showLongPressMenu(items[i]);
          },
        ),
      ),
    );
  }

  /// 长按菜单：手动匹配 TMDB（P1）
  Future<void> _showLongPressMenu(LocalVideoItem item) async {
    final scraped = ref.read(localVideoProvider).scrapedMap[item.pathHash];
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('详情'),
              onTap: () => Navigator.pop(context, 'detail'),
            ),
            ListTile(
              leading: const Icon(Icons.search),
              title: const Text('手动匹配 TMDB 元数据'),
              subtitle: Text(item.name, maxLines: 1),
              onTap: () => Navigator.pop(context, 'scrape'),
            ),
            if (scraped != null)
              ListTile(
                leading: const Icon(Icons.auto_fix_high, color: Colors.green),
                title: const Text('按刮削信息重命名'),
                subtitle: Text('→ ${scraped.title}${scraped.year != null ? " (${scraped.year})" : ""}', maxLines: 1),
                enabled: item.isAppDirFile,
                onTap: () => Navigator.pop(context, 'autoRename'),
              ),
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: const Text('手动重命名'),
              subtitle: Text(item.name, maxLines: 1),
              enabled: item.isAppDirFile,
              onTap: () => Navigator.pop(context, 'rename'),
            ),
            ListTile(
              leading: const Icon(Icons.check_box),
              title: const Text('多选模式'),
              onTap: () => Navigator.pop(context, 'select'),
            ),
          ],
        ),
      ),
    );
    if (action == 'detail') {
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LocalDetailPage(
            item: item,
            onPlay: () => _playVideo(item),
          ),
        ),
      );
    } else if (action == 'autoRename' && scraped != null) {
      if (!mounted) return;
      try {
        await LocalVideoService().renameByScraped(item, scraped);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('重命名成功')));
          ref.read(localVideoProvider.notifier).refresh();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('重命名失败: $e')));
        }
      }
    } else if (action == 'rename') {
      if (!mounted) return;
      final ctrl = TextEditingController(text: item.name);
      final newName = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('重命名'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(hintText: '输入新文件名（不含扩展名）'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
            TextButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('确定')),
          ],
        ),
      );
      if (newName != null && newName.isNotEmpty && mounted) {
        try {
          await LocalVideoService().renameFile(item, newName);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('重命名成功')));
            ref.read(localVideoProvider.notifier).refresh();
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('重命名失败: $e')));
          }
        }
      }
    } else if (action == 'scrape') {
      if (!mounted) return;
      final done = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => TmdbSearchPage(
            initialQuery: item.name,
            pathHash: item.pathHash,
            filename: item.name,
          ),
        ),
      );
      if (done == true && mounted) {
        // 重新加载缓存
        ref.read(localVideoProvider.notifier).refresh();
      }
    } else if (action == 'select') {
      ref.read(localVideoProvider.notifier).enterSelecting();
    }
  }

  void _playVideo(LocalVideoItem item) {
    final list = ref.read(localVideoProvider).filtered;
    final idx = list.indexWhere((e) => e.id == item.id);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LocalPlayerPage(
          items: list,
          initialIndex: idx < 0 ? 0 : idx,
        ),
      ),
    );
  }
}

/// 权限引导页
class _PermissionGuide extends StatelessWidget {
  final PermissionState permission;
  final VoidCallback onRequest;
  const _PermissionGuide({required this.permission, required this.onRequest});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final denied = permission == PermissionState.denied;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_off, size: 64, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              denied ? '需要存储权限才能读取本地视频' : '首次使用请授权访问媒体库',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              denied
                  ? '已被拒绝，请在系统设置中开启「媒体/存储」权限后重试'
                  : '授权后将扫描手机中的视频文件',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: denied
                  ? LocalVideoService.openSetting
                  : onRequest,
              child: Text(denied ? '去设置开启' : '授权并扫描'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onRefresh;
  final bool hasPermission;
  const _EmptyState({required this.onRefresh, required this.hasPermission});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.video_library_outlined, size: 64, color: Colors.grey),
        const SizedBox(height: 16),
        const Center(child: Text('没有找到本地视频')),
        const SizedBox(height: 8),
        const Center(
          child: Text(
            '请先在设置中添加文件源并扫描',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('重新扫描'),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
            onPressed: () => context.push('/file-sources'),
            icon: const Icon(Icons.folder_open, size: 18),
            label: const Text('管理文件源'),
          ),
        ),
      ],
    );
  }
}

/// 网格卡片：缩略图 + 时长角标 + 分辨率角标
class _GridCard extends StatefulWidget {
  final LocalVideoItem item;
  final bool selected;
  final bool selecting;
  final bool isFavorite;
  final ScrapedMedia? scraped; // 刮削结果（P0）
  final int? episodeCount; // 剧集总集数（聚合显示）
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onFavoriteToggle;
  const _GridCard({
    required this.item,
    required this.selected,
    required this.selecting,
    required this.isFavorite,
    this.scraped,
    this.episodeCount,
    required this.onTap,
    required this.onLongPress,
    required this.onFavoriteToggle,
  });

  @override
  State<_GridCard> createState() => _GridCardState();
}

class _GridCardState extends State<_GridCard> {
  Uint8List? _thumb;

  @override
  void initState() {
    super.initState();
    _loadThumb();
  }

  Future<void> _loadThumb() async {
    if (widget.item.assetId == null) return;
    try {
      final asset = AssetEntity(
        id: widget.item.assetId!,
        typeInt: 1, // video
        width: widget.item.width,
        height: widget.item.height,
        duration: widget.item.duration.inSeconds,
      );
      final data = await asset.thumbnailDataWithSize(
        const ThumbnailSize.square(200),
      );
      if (mounted && data != null) setState(() => _thumb = data);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = widget.scraped?.title ?? widget.item.name;
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: widget.scraped?.posterPath != null
                ? CachedNetworkImage(
                    imageUrl: TmdbService.posterUrl(widget.scraped!.posterPath!),
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: scheme.surfaceContainerHighest,
                      child: const Center(
                          child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))),
                    ),
                    errorWidget: (_, __, ___) => _thumb != null
                        ? Image.memory(_thumb!, fit: BoxFit.cover)
                        : Container(
                            color: scheme.surfaceContainerHighest,
                            child: const Icon(Icons.movie, size: 32),
                          ),
                  )
                : _thumb != null
                    ? Image.memory(_thumb!, fit: BoxFit.cover)
                    : Container(
                        color: scheme.surfaceContainerHighest,
                        child: const Icon(Icons.movie, size: 32),
                      ),
          ),
          // 评分角标右上（刮削 P0）
          if (widget.scraped?.rating != null)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  widget.scraped!.rating!.toStringAsFixed(1),
                  style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          // 剧集角标：聚合时显示"N 集"，单集显示 S01E01
          if (widget.scraped?.type == 'tv' && widget.episodeCount != null)
            Positioned(
              top: 24,
              right: 4,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${widget.episodeCount} 集',
                  style: const TextStyle(color: Colors.white, fontSize: 9),
                ),
              ),
            )
          else if (widget.scraped?.type == 'tv' &&
              widget.scraped?.season != null &&
              widget.scraped?.episode != null)
            Positioned(
              top: 24,
              right: 4,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'S${widget.scraped!.season}E${widget.scraped!.episode}',
                  style: const TextStyle(color: Colors.white, fontSize: 9),
                ),
              ),
            ),
          // 时长角标右下
          Positioned(
            right: 4,
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                widget.item.durationLabel,
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ),
          // 分辨率角标左下
          if (widget.item.width > 0)
            Positioned(
              left: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  widget.item.resolutionLabel,
                  style: const TextStyle(color: Colors.white70, fontSize: 9),
                ),
              ),
            ),
          // 多选勾选 / 收藏心形（P3）
          if (widget.selecting)
            Positioned(
              top: 4,
              right: 4,
              child: Icon(
                widget.selected
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: widget.selected ? scheme.primary : Colors.white,
                size: 22,
              ),
            )
          else
            Positioned(
              bottom: 18,
              left: 4,
              child: GestureDetector(
                onTap: widget.onFavoriteToggle,
                child: Icon(
                  widget.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: widget.isFavorite ? Colors.pink : Colors.white,
                  size: 18,
                ),
              ),
            ),
        ],
      ),
          ),
          // 标题（对齐在线媒体库：海报下方显示名称）
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 2, right: 2),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

/// 续播进度条组件（P2）：异步读取播放位置，显示进度百分比
class _ResumeProgress extends StatefulWidget {
  final String pathHash;
  final int totalMs;
  const _ResumeProgress({required this.pathHash, required this.totalMs});

  @override
  State<_ResumeProgress> createState() => _ResumeProgressState();
}

class _ResumeProgressState extends State<_ResumeProgress> {
  int? _resumeMs;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ms = await LocalVideoService().readResumeMs(widget.pathHash);
    if (mounted) setState(() => _resumeMs = ms);
  }

  @override
  Widget build(BuildContext context) {
    if (_resumeMs == null || widget.totalMs <= 0) {
      return Text('${Duration(milliseconds: widget.totalMs).inMinutes}:${(Duration(milliseconds: widget.totalMs).inSeconds % 60).toString().padLeft(2, '0')}',
          style: const TextStyle(fontSize: 10, color: Colors.grey));
    }
    final frac = (_resumeMs! / widget.totalMs).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: frac,
            minHeight: 3,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation(Color(0xFFFF6B6B)),
          ),
        ),
        const SizedBox(height: 2),
        Text('${(frac * 100).toStringAsFixed(0)}%',
            style: const TextStyle(fontSize: 9, color: Colors.grey)),
      ],
    );
  }
}

/// 公共视频缩略图组件（带内存缓存）
class _VideoThumbnail extends StatefulWidget {
  final String? assetId;
  final double width;
  final double height;
  final ScrapedMedia? scraped; // 刮削海报优先

  const _VideoThumbnail({
    required this.assetId,
    required this.width,
    required this.height,
    this.scraped,
  });

  /// 静态内存缓存：assetId → thumb bytes
  static final Map<String, Uint8List> _cache = {};

  @override
  State<_VideoThumbnail> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<_VideoThumbnail> {
  Uint8List? _thumb;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // 刮削有海报优先
    if (widget.scraped?.posterPath != null) return;
    final aid = widget.assetId;
    if (aid == null) return;
    final cached = _VideoThumbnail._cache[aid];
    if (cached != null) {
      if (mounted) setState(() => _thumb = cached);
      return;
    }
    try {
      final entity = AssetEntity(
        id: aid,
        typeInt: 1,
        width: 0,
        height: 0,
        duration: 0,
      );
      final data = await entity.thumbnailDataWithSize(
        const ThumbnailSize.square(200),
      );
      if (data != null) {
        _VideoThumbnail._cache[aid] = data;
        if (mounted) setState(() => _thumb = data);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: widget.scraped?.posterPath != null
            ? CachedNetworkImage(
                imageUrl: TmdbService.posterUrl(widget.scraped!.posterPath!),
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _fallback(scheme),
              )
            : (_thumb != null
                ? Image.memory(_thumb!, fit: BoxFit.cover)
                : _fallback(scheme)),
      ),
    );
  }

  Widget _fallback(ColorScheme scheme) => Container(
        color: scheme.surfaceContainerHighest,
        child: const Icon(Icons.movie, size: 20),
      );
}

class _ListTileItem extends StatelessWidget {
  final LocalVideoItem item;
  final bool selected;
  final bool selecting;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  const _ListTileItem({
    required this.item,
    required this.selected,
    required this.selecting,
    required this.onTap,
    required this.onLongPress,
    this.scraped,
  });

  final ScrapedMedia? scraped;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      leading: _VideoThumbnail(
        assetId: item.assetId,
        width: 64,
        height: 40,
        scraped: scraped,
      ),
      title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${item.durationLabel} · ${item.sizeLabel}'
        '${item.relativePath != null ? ' · ${item.relativePath}' : ''}',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: selecting
          ? Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey,
            )
          : const Icon(Icons.chevron_right),
    );
  }
}

/// 分区标题行
class _SectionTitle extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  const _SectionTitle(this.title, {this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel!,
                  style: const TextStyle(fontSize: 13, color: Colors.grey)),
            ),
        ],
      ),
    );
  }
}

/// 单个文件源完整列表页（点"查看所有"进入）：对齐 Emby 资源库页
class _SourceFullListPage extends ConsumerStatefulWidget {
  final String sourceId;
  final String sourceName;
  const _SourceFullListPage({required this.sourceId, required this.sourceName});

  @override
  ConsumerState<_SourceFullListPage> createState() => _SourceFullListPageState();
}

class _SourceFullListPageState extends ConsumerState<_SourceFullListPage> {
  int _tab = 0; // 电影/播放记录/分类/合集/文件夹
  bool _gridMode = true; // true=3列海报, false=2列backdrop
  String _sortBy = 'name';
  String? _genreFilter; // 分类 Tab 当前选中类型

  static const _sortOptions = {
    'name': '按名称',
    'time': '按时间',
    'rating': '按评分',
    'added': '加入时间',
    'year': '年份',
    'criticRating': '影评人评分',
    'playDate': '播放日期',
    'duration': '播放时长',
    'lastAdded': '最后一集添加日期',
    'resolution': '分辨率',
    'size': '大小',
    'bitrate': '比特率',
    'random': '随机',
  };

  List<LocalVideoItem> _applySort(List<LocalVideoItem> items, LocalVideoState state) {
    final list = [...items];
    double gR(String h) => state.scrapedMap[h]?.rating ?? 0;
    int gY(String h) => state.scrapedMap[h]?.year ?? 0;
    switch (_sortBy) {
      case 'name':
        list.sort((a, b) => (state.scrapedMap[a.pathHash]?.title ?? a.name)
            .compareTo(state.scrapedMap[b.pathHash]?.title ?? b.name));
      case 'time':
      case 'playDate':
        list.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
      case 'added':
      case 'lastAdded':
        list.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
      case 'year':
        list.sort((a, b) => gY(b.pathHash).compareTo(gY(a.pathHash)));
      case 'rating':
      case 'criticRating':
        list.sort((a, b) => gR(b.pathHash).compareTo(gR(a.pathHash)));
      case 'duration':
        list.sort((a, b) => b.duration.inSeconds.compareTo(a.duration.inSeconds));
      case 'size':
        list.sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));
      case 'resolution':
        // 无分辨率字段，按文件大小近似
        list.sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));
      case 'bitrate':
        // 比特率 = 大小/时长
        int bps(LocalVideoItem e) =>
            e.duration.inSeconds > 0 ? e.sizeBytes ~/ e.duration.inSeconds : 0;
        list.sort((a, b) => bps(b).compareTo(bps(a)));
      case 'random':
        list.shuffle();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(localVideoProvider);
    final allItems =
        state.items.where((e) => e.sourceId == widget.sourceId).toList();

    // 查找当前源的媒体类型
    final sources = ref.watch(fileSourcesProvider);
    final src = sources.where((s) => s.id == widget.sourceId).cast<FileSource?>().firstWhere((_) => true, orElse: () => null);
    final isTv = src?.config['mediaType'] == 'tv';

    // TV 源按剧名分组
    List<LocalVideoItem> items;
    switch (_tab) {
      case 1: // 播放记录
        final played = state.recentHashes.toSet();
        items = allItems.where((e) => played.contains(e.pathHash)).toList();
        break;
      default:
        items = allItems;
    }
    items = _applySort(items, state);

    // TV 源默认 Tab（0）按剧名分组显示海报网格
    if (isTv && _tab == 0) {
      final groups = <String, List<LocalVideoItem>>{};
      for (final it in items) {
        final folder = ScrapeService.extractSeriesName(it.relativePath) ??
            (it.relativePath?.split('/').where((s) => s.isNotEmpty).last ?? '未分组');
        groups.putIfAbsent(folder, () => []).add(it);
      }
      return Scaffold(
        appBar: _buildAppBar(allItems.length),
        body: Column(
          children: [
            _buildTabBar(isTv),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.55,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 16,
                ),
                itemCount: groups.length,
                itemBuilder: (_, i) {
                  final entry = groups.entries.elementAt(i);
                  final eps = entry.value;
                  final s = state.scrapedMap[eps.first.pathHash];
                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _FolderEpisodePage(folderName: entry.key, items: eps),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: s?.posterPath != null
                                    ? CachedNetworkImage(imageUrl: TmdbService.posterUrl(s!.posterPath!), fit: BoxFit.cover)
                                    : Container(color: Colors.grey[800], child: const Icon(Icons.tv, size: 32, color: Colors.white24)),
                              ),
                              Positioned(
                                top: 6, right: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.pinkAccent, borderRadius: BorderRadius.circular(10)),
                                  child: Text('${eps.length}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(s?.title ?? entry.key, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(s?.year != null ? '${s!.year}-现在' : '${eps.length} 集',
                            style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: _buildAppBar(allItems.length),
      body: Column(
        children: [
          _buildTabBar(isTv),
          Expanded(child: _buildTabBody(items, state)),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(int count) {
    return AppBar(
      titleSpacing: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.sourceName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          Text('当前项目数: $count', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(_gridMode ? Icons.grid_view : Icons.view_agenda_outlined),
          tooltip: _gridMode ? '切换列表' : '切换网格',
          onPressed: () => setState(() => _gridMode = !_gridMode),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.sort),
          tooltip: '排序',
          onSelected: (v) => setState(() => _sortBy = v),
          itemBuilder: (_) => _sortOptions.entries
              .map((e) => PopupMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildTabBar(bool isTv) {
    final labels = isTv ? ['电视剧', '播放记录', '分类', '合集', '文件夹'] : ['电影', '播放记录', '分类', '合集', '文件夹'];
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (var i = 0; i < labels.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: GestureDetector(
                onTap: () => setState(() => _tab = i),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      labels[i],
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: _tab == i ? FontWeight.w700 : FontWeight.normal,
                        color: _tab == i ? Theme.of(context).colorScheme.primary : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 2,
                      width: 24,
                      color: _tab == i ? Theme.of(context).colorScheme.primary : Colors.transparent,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 按当前 Tab 渲染内容
  Widget _buildTabBody(List<LocalVideoItem> items, LocalVideoState state) {
    switch (_tab) {
      case 2: // 分类：顶部类型 chips + 网格
        final genres = <String>{};
        for (final it in items) {
          final s = state.scrapedMap[it.pathHash];
          if (s != null) genres.addAll(s.genres);
        }
        final filtered = _genreFilter == null
            ? items
            : items.where((it) {
                final s = state.scrapedMap[it.pathHash];
                return s?.genres.contains(_genreFilter) ?? false;
              }).toList();
        return Column(
          children: [
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  ChoiceChip(
                    label: const Text('全部'),
                    selected: _genreFilter == null,
                    onSelected: (_) => setState(() => _genreFilter = null),
                  ),
                  const SizedBox(width: 8),
                  ...genres.map((g) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(g),
                          selected: _genreFilter == g,
                          onSelected: (_) => setState(() => _genreFilter = g),
                        ),
                      )),
                ],
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('暂无内容'))
                  : _gridMode
                      ? _buildGrid(filtered, state)
                      : _buildBackdropList(filtered, state),
            ),
          ],
        );
      case 3: // 合集：按 tvId / 标题分组
        final groups = <String, List<LocalVideoItem>>{};
        for (final it in items) {
          final s = state.scrapedMap[it.pathHash];
          final key = s?.tvId != null ? 'tv_${s!.tvId}' : (s?.title ?? it.name);
          groups.putIfAbsent(key, () => []).add(it);
        }
        return ListView(
          padding: const EdgeInsets.all(12),
          children: groups.entries.map((e) {
            final first = e.value.first;
            final s = state.scrapedMap[first.pathHash];
            return ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  width: 48,
                  height: 72,
                  child: s?.posterPath != null
                      ? CachedNetworkImage(
                          imageUrl: TmdbService.posterUrl(s!.posterPath!), fit: BoxFit.cover)
                      : Container(color: Colors.grey[800], child: const Icon(Icons.movie, size: 20)),
                ),
              ),
              title: Text(s?.title ?? first.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('${e.value.length} 个项目'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _GroupListPage(title: s?.title ?? first.name, items: e.value, state: state),
                ),
              ),
            );
          }).toList(),
        );
      case 4: // 文件夹：按相对路径目录分组
        final folders = <String, List<LocalVideoItem>>{};
        for (final it in items) {
          final dir = (it.relativePath != null && it.relativePath!.contains('/'))
              ? it.relativePath!.substring(0, it.relativePath!.lastIndexOf('/'))
              : '根目录';
          folders.putIfAbsent(dir, () => []).add(it);
        }
        return ListView(
          padding: const EdgeInsets.all(12),
          children: folders.entries.map((e) {
            return ListTile(
              leading: const Icon(Icons.folder, color: Colors.amber),
              title: Text(e.key, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('${e.value.length} 个视频'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _GroupListPage(title: e.key, items: e.value, state: state),
                ),
              ),
            );
          }).toList(),
        );
      default: // 0 电影 / 1 播放记录
        return items.isEmpty
            ? const Center(child: Text('暂无内容'))
            : _gridMode
                ? _buildGrid(items, state)
                : _buildBackdropList(items, state);
    }
  }

  /// 3列竖版海报网格
  Widget _buildGrid(List<LocalVideoItem> items, LocalVideoState state) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.58,
        crossAxisSpacing: 10,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _GridPosterCard(
        item: items[i],
        state: state,
        onPlay: () => _openPlayer(items, i),
      ),
    );
  }

  /// 2列横版 backdrop 卡片
  Widget _buildBackdropList(List<LocalVideoItem> items, LocalVideoState state) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.4,
        crossAxisSpacing: 10,
        mainAxisSpacing: 16,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _BackdropCard(
        item: items[i],
        state: state,
        onPlay: () => _openPlayer(items, i),
      ),
    );
  }

  void _openPlayer(List<LocalVideoItem> items, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LocalPlayerPage(
          items: items,
          initialIndex: index,
        ),
      ),
    );
  }
}

/// 竖版海报卡片
class _GridPosterCard extends StatelessWidget {
  final LocalVideoItem item;
  final LocalVideoState state;
  final VoidCallback? onPlay;
  const _GridPosterCard({required this.item, required this.state, this.onPlay});

  @override
  Widget build(BuildContext context) {
    final s = state.scrapedMap[item.pathHash];
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LocalDetailPage(item: item, onPlay: onPlay),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: s?.posterPath != null
                  ? CachedNetworkImage(
                      imageUrl: TmdbService.posterUrl(s!.posterPath!),
                      fit: BoxFit.cover,
                      width: double.infinity,
                    )
                  : Container(
                      color: Colors.grey[800],
                      child: const Icon(Icons.movie, color: Colors.white30),
                    ),
            ),
          ),
          const SizedBox(height: 6),
          Text(s?.title ?? item.name,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          if (s?.year != null)
            Text('${s!.year}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        ],
      ),
    );
  }
}

/// 横版 backdrop 卡片
class _BackdropCard extends StatelessWidget {
  final LocalVideoItem item;
  final LocalVideoState state;
  final VoidCallback? onPlay;
  const _BackdropCard({required this.item, required this.state, this.onPlay});

  @override
  Widget build(BuildContext context) {
    final s = state.scrapedMap[item.pathHash];
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LocalDetailPage(item: item, onPlay: onPlay),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: s?.backdropPath != null
                  ? CachedNetworkImage(
                      imageUrl: TmdbService.backdropUrl(s!.backdropPath!),
                      fit: BoxFit.cover,
                      width: double.infinity,
                    )
                  : Container(
                      color: Colors.grey[800],
                      child: const Icon(Icons.movie, size: 40, color: Colors.white30),
                    ),
            ),
          ),
          const SizedBox(height: 6),
          Text(s?.title ?? item.name,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

/// 合集/文件夹分组下的视频列表页
class _GroupListPage extends StatelessWidget {
  final String title;
  final List<LocalVideoItem> items;
  final LocalVideoState state;
  const _GroupListPage({required this.title, required this.items, required this.state});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title),
            Text('${items.length} 个项目', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.58,
          crossAxisSpacing: 10,
          mainAxisSpacing: 12,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) => _GridPosterCard(
          item: items[i],
          state: state,
          onPlay: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LocalPlayerPage(items: items, initialIndex: i),
            ),
          ),
        ),
      ),
    );
  }
}

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
        if (id != null && id.isNotEmpty && state.favoriteActorIds.contains(id)) {
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
                  _FavSection(title: '电视剧', items: tvReps, state: state, isTv: true, tvGroups: tvGroups),
                if (episodes.isNotEmpty)
                  _FavSection(title: '集', items: episodes, state: state, useBackdrop: true),
                if (favActors.isNotEmpty)
                  _FavActorsSection(actors: favActors),
              ],
            ),
    );
  }
}

class _FavSection extends StatelessWidget {
  final String title;
  final List<LocalVideoItem> items;
  final LocalVideoState state;
  final bool isTv;
  final bool useBackdrop;
  final Map<String, List<LocalVideoItem>>? tvGroups;
  const _FavSection({
    required this.title,
    required this.items,
    required this.state,
    this.isTv = false,
    this.useBackdrop = false,
    this.tvGroups,
  });

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
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              Text('查看所有', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
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
                  MaterialPageRoute(
                    builder: (_) => LocalDetailPage(item: it, onPlay: () {
                      // LocalDetailPage 内部已先 pop 自己，这里直接 push 播放器
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LocalPlayerPage(items: [it], initialIndex: 0),
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
                                      imageUrl: TmdbService.posterUrl(s!.posterPath!),
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      color: Colors.grey[800],
                                      child: const Icon(Icons.movie, size: 32, color: Colors.white54),
                                    ),
                            ),
                          ),
                          if (isTv && tvGroups != null)
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Builder(builder: (_) {
                                final s2 = state.scrapedMap[it.pathHash];
                                final key = s2?.tvId != null ? 'tv_${s2!.tvId}' : it.name;
                                final count = tvGroups?[key]?.length ?? 1;
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$count',
                                    style: const TextStyle(color: Colors.white, fontSize: 11),
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
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      if (s?.year != null)
                        Text('${s!.year}', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
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
  final List<Map<String, String>> actors;
  const _FavActorsSection({required this.actors});

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
              Text('演员', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
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
                        MaterialPageRoute(
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
                        backgroundImage: a['profilePath'] != null && a['profilePath']!.isNotEmpty
                            ? CachedNetworkImageProvider(
                                TmdbService.personUrl(a['profilePath']!))
                            : null,
                        child: a['profilePath'] == null || a['profilePath']!.isEmpty
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

/// 剧集文件夹内页：显示某部剧的所有集
class _FolderEpisodePage extends ConsumerStatefulWidget {
  final String folderName;
  final List<LocalVideoItem> items;
  const _FolderEpisodePage({required this.folderName, required this.items});

  @override
  ConsumerState<_FolderEpisodePage> createState() => _FolderEpisodePageState();
}

class _FolderEpisodePageState extends ConsumerState<_FolderEpisodePage> {
  bool _overviewExpanded = false;

  /// 从文件名提取干净的集标题，去掉 SxxEyy、扩展名
  String _episodeTitle(String filename) {
    var n = filename;
    final dot = n.lastIndexOf('.');
    if (dot > 0) n = n.substring(0, dot);
    n = n.replaceFirst(RegExp(r'^[Ss]\d{1,2}[._ -]?[Ee]\d{1,2}[._ -]*'), '');
    n = n.replaceFirst(RegExp(r'^第?\d{1,3}[集話][._ -]*'), '');
    return n.trim().isEmpty ? filename : n.trim();
  }

  void _openImageViewer(String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.transparent, iconTheme: const IconThemeData(color: Colors.white)),
          body: Center(child: InteractiveViewer(child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain))),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(localVideoProvider);
    final sorted = [...widget.items]..sort((a, b) => a.name.compareTo(b.name));
    if (sorted.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.folderName)),
        body: const Center(child: Text('没有视频')),
      );
    }
    final first = sorted.first;
    final meta = state.scrapedMap[first.pathHash];
    final cast = meta?.cast ?? [];
    // 整剧收藏：所有集都收藏才算收藏
    final allFaved = sorted.every((e) => state.favoriteHashes.contains(e.pathHash));

    return Scaffold(
      body: ListView(
        children: [
          // 顶部 backdrop 大图
          Stack(
            children: [
              SizedBox(
                height: 280,
                width: double.infinity,
                child: meta?.backdropPath != null
                    ? CachedNetworkImage(imageUrl: TmdbService.backdropUrl(meta!.backdropPath!), fit: BoxFit.cover)
                    : Container(color: Colors.grey[900]),
              ),
              Container(
                height: 280,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.85)],
                  ),
                ),
              ),
              Positioned(
                top: MediaQuery.of(context).padding.top,
                left: 0,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              // 顶部右侧：重新刮削
              Positioned(
                top: MediaQuery.of(context).padding.top,
                right: 0,
                child: IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  tooltip: '重新刮削',
                  onPressed: () async {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('正在重新刮削…')));
                    final result = await ScrapeService.scrapeTvSeries(widget.folderName);
                    if (result != null) {
                      // 整剧所有集共享系列元数据
                      final cached = Map<String, ScrapedMedia>.from(ref.read(localVideoProvider).scrapedMap);
                      for (final it in sorted) {
                        cached[it.pathHash] = result;
                      }
                      ref.read(localVideoProvider.notifier).state =
                          ref.read(localVideoProvider).copyWith(scrapedMap: cached);
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('刮削完成')));
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
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, shadows: [Shadow(blurRadius: 4, color: Colors.black54)])),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (meta?.year != null) '${meta!.year}',
                        if (meta?.rating != null) '★ ${meta!.rating!.toStringAsFixed(1)}',
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
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          icon: const Icon(Icons.play_arrow, size: 18),
                          label: const Text('播放', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LocalPlayerPage(items: sorted, initialIndex: 0))),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () {
                            // 整剧收藏/取消：切换所有集
                            for (final it in sorted) {
                              if (allFaved) {
                                ref.read(localVideoProvider.notifier).toggleFavorite(it.pathHash);
                              } else if (!state.favoriteHashes.contains(it.pathHash)) {
                                ref.read(localVideoProvider.notifier).toggleFavorite(it.pathHash);
                              }
                            }
                          },
                          icon: Icon(allFaved ? Icons.favorite : Icons.favorite_border, color: allFaved ? Colors.pink : Colors.white),
                        ),
                        IconButton(
                          onPressed: () => Share.shareXFiles([XFile(first.path)], subject: first.name),
                          icon: const Icon(Icons.share, color: Colors.white),
                        ),
                        IconButton(
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('删除整剧'),
                                content: Text('确定删除 ${widget.folderName} 共 ${sorted.length} 集吗？此操作不可恢复。'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
                                  TextButton(onPressed: () => Navigator.pop(context, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('删除')),
                                ],
                              ),
                            );
                            if (ok == true) {
                              await ref.read(localVideoProvider.notifier).deleteByIds(sorted.map((e) => e.id).toSet());
                              if (mounted) Navigator.pop(context);
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
          ),
          // 海报 + backdrop 并排
          if (meta?.posterPath != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => _openImageViewer(TmdbService.posterUrl(meta!.posterPath!)),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: TmdbService.posterUrl(meta!.posterPath!),
                        width: 90, height: 135, fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: meta!.backdropPath != null ? () => _openImageViewer(TmdbService.backdropUrl(meta!.backdropPath!)) : null,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: meta!.backdropPath != null
                            ? CachedNetworkImage(imageUrl: TmdbService.backdropUrl(meta!.backdropPath!), height: 135, fit: BoxFit.cover)
                            : Container(height: 135, color: Colors.grey[800]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          // 类型标签 + 评分
          if (meta?.genres != null && meta!.genres!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ...meta.genres!.map((g) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(4)),
                        child: Text(g, style: const TextStyle(fontSize: 11)),
                      )),
                  if (meta.rating != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.star, size: 12, color: Colors.amber),
                        const SizedBox(width: 2),
                        Text(meta.rating!.toStringAsFixed(1), style: const TextStyle(fontSize: 11)),
                      ]),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          // 简介（可展开）
          if (meta?.overview != null && meta!.overview!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('简介', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(meta.overview!,
                      maxLines: _overviewExpanded ? null : 4,
                      overflow: _overviewExpanded ? null : TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey[300], fontSize: 13, height: 1.5)),
                  if (meta.overview!.length > 120)
                    TextButton(
                      onPressed: () => setState(() => _overviewExpanded = !_overviewExpanded),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
                      child: Text(_overviewExpanded ? '收起' : '展开', style: const TextStyle(fontSize: 13)),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          // 季标题
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('第 1 季', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 12),
          // 剧集网格（2列）
          GridView.builder(
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
              return InkWell(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LocalPlayerPage(items: sorted, initialIndex: i))),
                child: Container(
                  decoration: BoxDecoration(color: Colors.grey[850], borderRadius: BorderRadius.circular(10)),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: meta?.backdropPath != null
                            ? CachedNetworkImage(imageUrl: TmdbService.backdropUrl(meta!.backdropPath!), fit: BoxFit.cover, errorWidget: (_, __, ___) => Container(color: Colors.grey[800]))
                            : Container(color: Colors.grey[800]),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text('${i + 1}. ${_episodeTitle(it.name)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          // 演员
          if (cast.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('演职人员', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                        Navigator.push(context, MaterialPageRoute(builder: (_) => PersonDetailPage(personId: personId, name: c['name'] ?? '', profilePath: profile)));
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
                              width: 56, height: 56,
                              child: profile != null
                                  ? CachedNetworkImage(imageUrl: TmdbService.personUrl(profile), fit: BoxFit.cover, errorWidget: (_, __, ___) => Container(color: Colors.grey[800], child: const Icon(Icons.person, color: Colors.white24)))
                                  : Container(color: Colors.grey[800], child: const Icon(Icons.person, color: Colors.white24)),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(c['name'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
