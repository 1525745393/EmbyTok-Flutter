// 本地视频列表页：网格/列表切换 + 搜索 + 排序 + 多选删除 + 权限引导
// 对应 PRD《本地模式》§4.3 / §6
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'local_detail_view.dart';

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
            onPressed: () => _showLocalFavorites(context, state),
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
                child: scraped?.posterPath != null
                    ? CachedNetworkImage(
                        imageUrl: TmdbService.posterUrl(scraped!.posterPath!),
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _thumbPlaceholder(item),
                      )
                    : _thumbPlaceholder(item),
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

/// 单个文件源完整列表页（点"查看所有"进入）
class _SourceFullListPage extends ConsumerWidget {
  final String sourceId;
  final String sourceName;
  const _SourceFullListPage({required this.sourceId, required this.sourceName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(localVideoProvider);
    final items = state.items.where((e) => e.sourceId == sourceId).toList();
    return Scaffold(
      appBar: AppBar(title: Text(sourceName)),
      body: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.62,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final item = items[i];
          final scraped = state.scrapedMap[item.pathHash];
          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LocalDetailPage(item: item, onPlay: () {}),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: scraped?.posterPath != null
                        ? CachedNetworkImage(
                            imageUrl: TmdbService.posterUrl(scraped!.posterPath!),
                            fit: BoxFit.cover,
                          )
                        : Container(
                            color: Colors.grey[800],
                            child: const Icon(Icons.movie, color: Colors.white30),
                          ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(scraped?.title ?? item.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11)),
              ],
            ),
          );
        },
      ),
    );
  }
}
