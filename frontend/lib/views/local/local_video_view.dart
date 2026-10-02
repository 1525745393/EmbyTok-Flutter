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

    var items = state.filtered;
    // 按选中的文件源过滤
    if (_selectedSourceId != null) {
      items = items.where((e) => e.sourceId == _selectedSourceId).toList();
    }
    final sources = ref.watch(fileSourcesProvider);

    // 横滑区块也按选中文件源过滤
    var recentItems = state.recentItems;
    var recentlyAdded = state.recentlyAdded;
    var unwatchedItems = state.unwatchedItems;
    if (_selectedSourceId != null) {
      bool match(LocalVideoItem e) => e.sourceId == _selectedSourceId;
      recentItems = recentItems.where(match).toList();
      recentlyAdded = recentlyAdded.where(match).toList();
      unwatchedItems = unwatchedItems.where(match).toList();
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // 顶部搜索 + 排序 + 视图切换
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: '搜索本地视频…',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    ),
                    onChanged: notifier.setKeyword,
                  ),
                ),
                const SizedBox(width: 8),
                // 浏览本地文件夹（P0：文件管理器式目录浏览）
                IconButton(
                  icon: const Icon(Icons.folder, size: 22),
                  tooltip: '浏览文件夹',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LocalDirectoryBrowserView(),
                      ),
                    );
                  },
                ),
                // 排序菜单
                PopupMenuButton<LocalVideoSort>(
                  icon: const Icon(Icons.sort, size: 20),
                  tooltip: '排序',
                  onSelected: notifier.setSort,
                  itemBuilder: (_) => [
                    for (final s in LocalVideoSort.values)
                      PopupMenuItem(value: s, child: Text(_sortLabel(s))),
                  ],
                ),
                // 三点菜单（P1 #8）：视图/分组/重扫/刮削/全选
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (v) {
                    switch (v) {
                      case 'grid':
                        notifier.setViewMode(LocalVideoViewMode.grid);
                      case 'list':
                        notifier.setViewMode(LocalVideoViewMode.list);
                      case 'folder':
                        notifier.toggleGroupByFolder();
                      case 'rescan':
                        notifier.refresh();
                      case 'scrape':
                        notifier.scrapeMissing();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('开始刮削未识别视频…')),
                        );
                      case 'selectall':
                        notifier.enterSelecting();
                        notifier.selectAll();
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                        value: 'grid', child: Text('网格视图')),
                    const PopupMenuItem(value: 'list', child: Text('列表视图')),
                    PopupMenuItem(
                        value: 'folder',
                        child: Text(state.groupByFolder ? '退出文件夹分组' : '按文件夹分组')),
                    const PopupMenuDivider(),
                    const PopupMenuItem(value: 'rescan', child: Text('重新扫描')),
                    const PopupMenuItem(value: 'scrape', child: Text('刮削未识别')),
                    const PopupMenuItem(value: 'selectall', child: Text('全选')),
                  ],
                ),
              ],
            ),
          ),
          // 刮削进度条（P1 #4）
          if (state.scraping)
            LinearProgressIndicator(
              value: state.scrapeTotal > 0
                  ? state.scrapeDone / state.scrapeTotal
                  : null,
              minHeight: 2,
            ),
          // 文件源（媒体库）筛选 Chip 行
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _buildSourceChip(null, '全部'),
                for (final s in sources) ...[
                  const SizedBox(width: 6),
                  _buildSourceChip(s.id, s.name),
                ],
              ],
            ),
          ),
          // 类型筛选 Chip 行（P1 #6）
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _buildTypeChip(null, '全部'),
                const SizedBox(width: 6),
                _buildTypeChip('movie', '电影'),
                const SizedBox(width: 6),
                _buildTypeChip('tv', '剧集'),
                const SizedBox(width: 6),
                _buildTypeChip('none', '未识别'),
              ],
            ),
          ),
          // 多选模式顶栏
          if (state.selecting)
            Container(
              color: scheme.primaryContainer,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  TextButton(
                    onPressed: notifier.exitSelecting,
                    child: const Text('取消'),
                  ),
                  const Spacer(),
                  Text('已选 ${state.selected.length} 项',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  // 批量收藏（P2 #12）：只收藏未收藏项
                  TextButton(
                    onPressed: () async {
                      final selectedItems = state.items
                          .where((e) => state.selected.contains(e.id))
                          .toList();
                      var added = 0;
                      for (final it in selectedItems) {
                        // 已收藏则跳过，未收藏才收藏
                        if (!state.favoriteHashes.contains(it.pathHash)) {
                          await notifier.toggleFavorite(it.pathHash);
                          added++;
                        }
                      }
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('已收藏 $added 个视频')),
                        );
                      }
                    },
                    child: const Text('收藏'),
                  ),
                  TextButton(
                    onPressed: () async {
                      // 删除确认对话框（P1：避免误删）
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('删除视频'),
                          content: Text(
                              '确定删除选中的 ${state.selected.length} 个视频吗？此操作不可恢复。'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('取消'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: TextButton.styleFrom(
                                  foregroundColor: scheme.error),
                              child: const Text('删除'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true || !mounted) return;
                      final ok = await notifier.deleteByIds(state.selected);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('已删除 $ok 个视频')),
                        );
                      }
                    },
                    child: Text('删除',
                        style: TextStyle(color: scheme.error)),
                  ),
                ],
              ),
            ),
          // 内容区
          Expanded(
            child: state.loading && items.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : items.isEmpty
                    ? _EmptyState(
                        onRefresh: notifier.refresh,
                        hasPermission: state.permission.hasAccess,
                      )
                    : Column(
                        children: [
                          // 最近观看横滑区块（P2）
                          if (recentItems.isNotEmpty)
                            _buildRecentRow(recentItems),
                          // 最近添加横滑海报墙（P1）
                          if (recentlyAdded.isNotEmpty)
                            _buildPosterRow(
                              title: '最近添加',
                              items: recentlyAdded,
                              state: state,
                              onTap: (item) => _playVideo(item),
                            ),
                          // 未观看横滑（P1）
                          if (unwatchedItems.isNotEmpty)
                            _buildPosterRow(
                              title: '未观看',
                              items: unwatchedItems,
                              state: state,
                              onTap: (item) => _playVideo(item),
                            ),
                          Expanded(
                            child: _browsingFolder != null
                                ? _buildFolderView(state, notifier, _browsingFolder!)
                                : state.groupByFolder
                                    ? _buildFolderGrid(state)
                                    : state.viewMode == LocalVideoViewMode.grid
                                        ? _buildGrid(items, state, notifier)
                                        : _buildList(items, state, notifier),
                          ),
                          // 媒体库统计行（P1 #5）
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 4, horizontal: 12),
                            child: Text(
                              _buildStatsLineFor(items, state),
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[600]),
                            ),
                          ),
                        ],
                      ),
          ),
        ],
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
