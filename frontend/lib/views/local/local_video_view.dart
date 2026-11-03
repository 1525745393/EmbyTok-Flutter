// 本地视频列表页：网格/列表切换 + 搜索 + 排序 + 多选删除 + 权限引导
// 对应 PRD《本地模式》§4.3 / §6
import 'package:flutter/material.dart';
import '../../utils/logger.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'local_detail_view.dart';
import 'person_detail_view.dart';
import '../../widgets/local/local_images.dart';

import '../../models/local_video_item.dart';
import '../../providers/app_preferences_providers.dart';
import '../../models/file_source.dart';
import '../../providers/local_video_provider.dart';
import '../../providers/file_sources_provider.dart';
import '../../services/local_video_service.dart';
import '../../services/scrape_service.dart';
import '../../services/tmdb_service.dart';
import 'local_play_page.dart';
import 'tmdb_search_page.dart';
import '../../utils/constants.dart';

part 'local_video_part2.dart';
part 'local_video_part1.dart';

class LocalVideoView extends ConsumerStatefulWidget {
  const LocalVideoView({super.key});

  @override
  ConsumerState<LocalVideoView> createState() => _LocalVideoViewState();
}

class _LocalVideoViewState extends ConsumerState<LocalVideoView> {
  final _searchCtrl = TextEditingController();
  String? _browsingFolder; // 正在浏览的文件夹名（null = 全部）
  String? _selectedSourceId; // 选中的文件源 ID（null = 全部）
  /// 多选批量操作进行中：批量重刮/批量重命名期间禁用底部栏按钮，
  /// 防止循环 await 期间重复点击并发执行（批次A-F3/F5）
  bool _batchBusy = false;

  /// 续播位置读取缓存：同一 pathHash 只触发一次异步读，滚动重建不重复读盘、进度条不闪回
  final Map<String, Future<int?>> _resumeFutureCache = {};

  Future<int?> _resumeFuture(String pathHash) => _resumeFutureCache.putIfAbsent(
      pathHash, () => LocalVideoService().readResumeMs(pathHash));

  @override
  void dispose() {
    _searchCtrl.dispose();
    _resumeFutureCache.clear();
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Theme.of(context).brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
        statusBarBrightness: Theme.of(context).brightness == Brightness.dark
            ? Brightness.dark
            : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        bottomNavigationBar: state.selecting && state.selected.isNotEmpty
            ? BottomAppBar(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.refresh, color: Colors.blue),
                      label: const Text('重刮'),
                      onPressed: _batchBusy
                          ? null
                          : () => _batchRescrape(state, notifier),
                    ),
                    TextButton.icon(
                      icon:
                          const Icon(Icons.auto_fix_high, color: Colors.green),
                      label: const Text('批量重命名'),
                      onPressed: _batchBusy
                          ? null
                          : () => _batchRename(state, notifier),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      label: const Text('取消'),
                      onPressed: () => notifier.exitSelecting(),
                    ),
                  ],
                ),
              )
            : null,
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
                MaterialPageRoute<Widget>(
                    builder: (_) => const LocalFavoritesPage()),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: '搜索',
              onPressed: () => _showSearchSheet(context, state, notifier),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (v) async {
                // 每个 case 必须 break，否则 fallthrough 会连带执行后续动作（batch 30 F2）
                switch (v) {
                  case 'rescan':
                    notifier.refresh();
                    break;
                  case 'scrape':
                    notifier.scrapeMissing();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('开始刮削未识别视频…')),
                    );
                    break;
                  case 'sources':
                    context.push('/file-sources');
                    break;
                  case 'undoRename':
                    try {
                      final path = await LocalVideoService().undoLastRename();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('已撤销重命名: ${path.split('/').last}')),
                      );
                      notifier.refresh();
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('撤销失败: $e')),
                      );
                    }
                    break;
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'rescan', child: Text('重新扫描')),
                PopupMenuItem(value: 'scrape', child: Text('刮削未识别')),
                PopupMenuItem(value: 'sources', child: Text('管理文件源')),
                PopupMenuItem(value: 'undoRename', child: Text('撤销最近重命名')),
              ],
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: notifier.refresh,
          child: ListView(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + kSpacingXl,),
            children: [
              // 刮削进度条
              if (state.scraping)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: kSpacingLg, vertical: kSpacingXs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(
                        value: state.scrapeTotal > 0
                            ? state.scrapeDone / state.scrapeTotal
                            : null,
                        minHeight: 2,
                      ),
                      const SizedBox(height: 2),
                      Text('刮削中 ${state.scrapeDone}/${state.scrapeTotal}',
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey[600])),
                    ],
                  ),
                )
              else if (state.scrapeTotal > 0 && !state.scraping)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: kSpacingLg, vertical: kSpacingXs),
                  child: Row(
                    children: [
                      Text(
                        '刮削完成：成功 ${state.scrapeOk} · 失败 ${state.scrapeFail}',
                        style: TextStyle(
                            fontSize: 11,
                            color: state.scrapeFail > 0
                                ? Colors.orange
                                : Colors.green),
                      ),
                      if (state.scrapeFail > 0) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => notifier.retryFailed(),
                          child: const Text('重试失败',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.blue,
                                  decoration: TextDecoration.underline)),
                        ),
                      ],
                    ],
                  ),
                ),

              // ── 播放记录（继续观看）──
              if (state.recentItems.isNotEmpty) ...[
                const _SectionTitle('播放记录'),
                SizedBox(
                  height: 200,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: kSpacingLg),
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
                    padding: const EdgeInsets.symmetric(horizontal: kSpacingLg),
                    itemCount: sources.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, i) => _buildSourceCard(sources[i], state),
                  ),
                ),
              ],

              // ── 每个文件源分区：海报横滑 ──
              for (final src in sources) _buildSourceSection(src, state),

              // 空状态
              if (state.items.isEmpty && !state.loading)
                _EmptyState(
                  onRefresh: notifier.refresh,
                  hasPermission: state.permission.hasAccess,
                ),

              // 底部统计行
              if (state.items.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(kSpacingLg, kSpacingLg, kSpacingLg, kSpacingSm),
                  child: Text(
                    _buildStatsLine(state),
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 单个文件源分区：标题 + 海报横滑
  Widget _buildSourceSection(FileSource src, LocalVideoState state) {
    final notifier = ref.read(localVideoProvider.notifier);
    final srcItems = state.items.where((e) => e.sourceId == src.id).toList();
    if (srcItems.isEmpty) return const SizedBox.shrink();

    // TV 类型源：每部剧一张海报卡，点击进入剧集列表
    final isTv = src.config['mediaType'] == 'tv';
    if (isTv) {
      final groups = <String, List<LocalVideoItem>>{};
      for (final it in srcItems) {
        final folder = ScrapeService.extractSeriesName(it.relativePath) ??
            (it.relativePath?.split('/').where((s) => s.isNotEmpty).last ??
                '未分组');
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
              padding: const EdgeInsets.symmetric(horizontal: kSpacingLg),
              itemCount: groups.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                final entry = groups.entries.elementAt(i);
                final first = entry.value.first;
                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<Widget>(
                      builder: (_) => _FolderEpisodePage(
                        folderName: entry.key,
                        items: entry.value,
                      ),
                    ),
                  ),
                  onLongPress: () => _showLongPressMenu(first),
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
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                        Text('${entry.value.length}集',
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
            padding: const EdgeInsets.symmetric(horizontal: kSpacingLg),
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
                    // backdrop 或缩略图（本地旁置 backdrop 文件优先，无则 CDN 回退，与详情页一致 batch 25 F2）
                    scraped?.backdropPath != null
                        ? LocalBackdropImage(
                            item: item, backdropPath: scraped!.backdropPath)
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
                              future: _resumeFuture(item.pathHash),
                              builder: (_, snap) {
                                final ms = snap.data ?? 0;
                                final total = item.duration.inMilliseconds;
                                final frac = total > 0
                                    ? (ms / total).clamp(0.0, 1.0)
                                    : 0.0;
                                return FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: frac,
                                  child:
                                      Container(color: const Color(0xFFFF6B6B)),
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
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            FutureBuilder<int?>(
              future: _resumeFuture(item.pathHash),
              builder: (_, snap) {
                final played = snap.data ?? 0;
                final remaining = item.duration.inMilliseconds - played;
                if (remaining <= 0) return const SizedBox.shrink();
                final h = remaining ~/ 3600000;
                final m = (remaining % 3600000) ~/ 60000;
                return Text(
                    '剩余时间: ${h > 0 ? '${h}h ' : ''}${m.toString().padLeft(2, '0')}m',
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
    final srcItems = state.items.where((e) => e.sourceId == src.id).toList();
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
      return LocalPosterImage(
          item: first,
          posterPath: s!.posterPath,
          placeholder: _posterPlaceholder());
    }
    return _posterPlaceholder();
  }

  Widget _posterPlaceholder() => Container(
        color: Colors.grey[800],
        child: const Icon(Icons.tv, color: Colors.white24, size: 32),
      );

  /// 分区海报卡片
  Widget _buildPosterCard(
      LocalVideoItem item, LocalVideoState state, LocalVideoNotifier notifier) {
    final scraped = state.scrapedMap[item.pathHash];
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute<Widget>(
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
                        ? LocalPosterImage(
                            item: item,
                            posterPath: scraped!.posterPath,
                            placeholder: _thumbPlaceholder(item))
                        : _thumbPlaceholder(item),
                    // 刮削状态角标：完整=绿勾，不完整=黄感叹号，未刮削不显示（P3）
                    if (scraped != null &&
                        ScrapeService.statusOf(scraped) ==
                            ScrapeStatus.complete)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.check,
                              size: 12, color: Colors.white),
                        ),
                      ),
                    if (scraped != null &&
                        ScrapeService.statusOf(scraped) ==
                            ScrapeStatus.incomplete)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.warning_amber,
                              size: 12, color: Colors.black87),
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
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
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
      MaterialPageRoute<Widget>(
        builder: (_) => _SourceFullListPage(
          sourceId: sourceId,
          sourceName: sourceName,
        ),
      ),
    );
  }

  /// 本地收藏列表弹窗
  void _showLocalFavorites(BuildContext context, LocalVideoState state) {
    final favs = state.items
        .where((e) => state.favoriteHashes.contains(e.pathHash))
        .toList();
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
              padding: EdgeInsets.all(kSpacingLg),
              child: Text('我的收藏',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
                                ? LocalPosterImage(
                                    item: it, posterPath: s!.posterPath)
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
  void _showSearchSheet(BuildContext context, LocalVideoState state,
      LocalVideoNotifier notifier) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      // 弹窗必须订阅 provider 实时刷新：若用打开时捕获的 state 快照，
      // 输入关键词后结果列表停留在旧内容（批次A-F1）
      builder: (_) => Consumer(
        builder: (context, ref, _) {
          final liveState = ref.watch(localVideoProvider);
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(kSpacingMd),
                  child: TextField(
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: '搜索本地视频…',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) =>
                        ref.read(localVideoProvider.notifier).setKeyword(v),
                  ),
                ),
                SizedBox(
                  height: 300,
                  child: liveState.filtered.isEmpty
                      ? const Center(child: Text('无结果'))
                      : ListView.builder(
                          itemCount: liveState.filtered.length,
                          itemBuilder: (_, i) {
                            final it = liveState.filtered[i];
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
          );
        },
      ),
    ).whenComplete(() {
      // 关闭弹窗后清空关键词：输入框本身无 controller，下次打开输入框为空；
      // 但 provider 里残留的旧 keyword 会让结果列表仍按旧词过滤，
      // 出现"空输入框却展示上一次搜索结果"的状态不一致。
      notifier.setKeyword('');
    });
  }

  /// 类型筛选 Chip（P1 #6）
  Widget _buildTypeChip(String? value, String label) {
    final selected = ref.read(localVideoProvider).typeFilter == value;
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: (_) =>
          ref.read(localVideoProvider.notifier).setTypeFilter(value),
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
      sizeLabel = '${(totalBytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
    }
    return '$movies 部电影 · $tvs 部剧集 · $unscraped 未识别 · 占用 $sizeLabel';
  }

  /// 统计行（P1 #5）
  String _buildStatsLine(LocalVideoState state) {
    int movies = 0, tvs = 0, unscraped = 0, incomplete = 0;
    int totalBytes = 0;
    for (final it in state.items) {
      totalBytes += it.sizeBytes;
      final s = state.scrapedMap[it.pathHash];
      if (s == null) {
        unscraped++;
      } else {
        // 完整/不完整都计入对应类型；不完整单独计数便于用户补全
        if (ScrapeService.statusOf(s) == ScrapeStatus.incomplete) incomplete++;
        if (s.type == 'tv') {
          tvs++;
        } else {
          movies++;
        }
      }
    }
    String sizeLabel;
    if (totalBytes < 1024 * 1024) {
      // <1MB 时以 KB 展示（totalBytes/1024 得 KB 值，标签须为 KB）
      sizeLabel = '${(totalBytes / 1024).toStringAsFixed(1)} KB';
    } else if (totalBytes < 1024 * 1024 * 1024) {
      sizeLabel = '${(totalBytes / 1024 / 1024).toStringAsFixed(1)} MB';
    } else {
      sizeLabel = '${(totalBytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
    }
    return '$movies 部电影 · $tvs 部剧集 · $unscraped 未识别 · $incomplete 不完整 · 占用 $sizeLabel';
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
          padding: const EdgeInsets.fromLTRB(kSpacingMd, kSpacingSm, kSpacingMd, kSpacingXs),
          child: Text(title,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ),
        SizedBox(
          height: 130,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: kSpacingMd),
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
                          style: const TextStyle(fontSize: 12)),
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
          padding: EdgeInsets.fromLTRB(kSpacingMd, kSpacingSm, kSpacingMd, kSpacingXs),
          child: Text('继续观看',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ),
        SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: kSpacingMd),
            itemCount: recent.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final item = recent[i];
              final scraped =
                  ref.read(localVideoProvider).scrapedMap[item.pathHash];
              return GestureDetector(
                onTap: () => _playVideo(item),
                child: Container(
                  width: 130,
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
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
      padding: const EdgeInsets.all(kSpacingSm),
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
                              color: Colors.white70, fontSize: 12)),
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
          padding: const EdgeInsets.fromLTRB(kSpacingXs, kSpacingXs, kSpacingMd, kSpacingXs),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _browsingFolder = null),
                tooltip: '返回',
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
            padding: const EdgeInsets.symmetric(horizontal: kSpacingSm),
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
        padding: const EdgeInsets.all(kSpacingSm),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.62,
        ),
        itemCount: grouped.length,
        itemBuilder: (_, i) {
          final it = grouped[i];
          // 计算该剧集的总集数 + 缺集
          final s = state.scrapedMap[it.pathHash];
          int epCount = 1;
          String? missingLabel;
          if (s != null && s.type == 'tv') {
            final eps = items
                .where((e) =>
                    state.scrapedMap[e.pathHash]?.type == 'tv' &&
                    state.scrapedMap[e.pathHash]?.title == s.title)
                .map((e) => state.scrapedMap[e.pathHash]!.episode ?? 0)
                .where((e) => e > 0)
                .toSet()
                .toList()
              ..sort();
            epCount = eps.length;
            // P2#8 缺集检测：1..max 中缺失的
            if (eps.isNotEmpty) {
              final maxEp = eps.last;
              final have = eps.toSet();
              final missing = List.generate(maxEp, (i) => i + 1)
                  .where((n) => !have.contains(n))
                  .toList();
              if (missing.isNotEmpty) {
                final shown = missing.take(3).join('、E');
                missingLabel = missing.length > 3
                    ? '缺 E$shown 等${missing.length}集'
                    : '缺 E$shown';
              }
            }
          }
          return _GridCard(
            item: it,
            selected: state.selected.contains(it.id),
            selecting: state.selecting,
            isFavorite: state.favoriteHashes.contains(it.pathHash),
            scraped: state.scrapedMap[it.pathHash],
            episodeCount: epCount > 1 ? epCount : null,
            missingLabel: missingLabel,
            onTap: () {
              if (state.selecting) {
                notifier.toggleSelected(it.id);
              } else {
                // 对齐在线媒体库：点卡片进详情页，详情页里再点播放
                Navigator.push(
                  context,
                  MaterialPageRoute<Widget>(
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
        padding: const EdgeInsets.symmetric(horizontal: kSpacingSm, vertical: kSpacingXs),
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

  /// P2#9 批量重新刮削
  Future<void> _batchRescrape(
      LocalVideoState state, LocalVideoNotifier notifier) async {
    if (_batchBusy) return;
    final ids = state.selected.toList();
    final items = state.items.where((e) => ids.contains(e.id)).toList();
    if (items.isEmpty) return;
    setState(() => _batchBusy = true);
    try {
      // 清空刮削缓存（而非写入空占位），避免刮削失败后残留空数据导致标题空白且不再自动刮削
      for (final it in items) {
        await ScrapeService.removeCacheEntry(it.pathHash);
      }
      notifier.exitSelecting();
      // 先刷新让 scrapedMap 移除这些条目，scrapeMissing 按 containsKey 判断才会重新刮
      await notifier.refresh();
      notifier.scrapeMissing();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已请求重新刮削 ${items.length} 个文件')),
        );
      }
    } finally {
      if (mounted) setState(() => _batchBusy = false);
    }
  }

  /// P2#9 批量按刮削重命名
  Future<void> _batchRename(
      LocalVideoState state, LocalVideoNotifier notifier) async {
    if (_batchBusy) return;
    final ids = state.selected.toList();
    final items = state.items.where((e) => ids.contains(e.id)).toList();
    if (items.isEmpty) return;
    setState(() => _batchBusy = true);
    int ok = 0, fail = 0;
    try {
      for (final it in items) {
        final s = state.scrapedMap[it.pathHash];
        if (s == null || s.title.isEmpty) {
          fail++;
          continue;
        }
        try {
          await LocalVideoService().renameByScraped(it, s);
          ok++;
        } catch (_) {
          fail++;
        }
      }
      notifier.exitSelecting();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('批量重命名完成：成功 $ok，失败 $fail')),
        );
        notifier.refresh();
      }
    } finally {
      if (mounted) setState(() => _batchBusy = false);
    }
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
                subtitle: Text(
                    '→ ${scraped.title}${scraped.year != null ? " (${scraped.year})" : ""}',
                    maxLines: 1),
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
        MaterialPageRoute<Widget>(
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
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('重命名成功')));
          ref.read(localVideoProvider.notifier).refresh();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('重命名失败: $e')));
        }
      }
    } else if (action == 'rename') {
      if (!mounted) return;
      // 预填去掉扩展名：renameFile 会按服务层自动补全扩展名，直接确定产生 xx.mp4.mp4 双扩展名（batch 30 F4）
      final baseName = item.name.contains('.')
          ? item.name.substring(0, item.name.lastIndexOf('.'))
          : item.name;
      final ctrl = TextEditingController(text: baseName);
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
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消')),
            TextButton(
                onPressed: () => Navigator.pop(context, ctrl.text.trim()),
                child: const Text('确定')),
          ],
        ),
      );
      ctrl.dispose(); // 弹窗已关闭，释放控制器避免泄漏
      if (newName != null && newName.isNotEmpty && mounted) {
        try {
          await LocalVideoService().renameFile(item, newName);
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('重命名成功')));
            ref.read(localVideoProvider.notifier).refresh();
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('重命名失败: $e')));
          }
        }
      }
    } else if (action == 'scrape') {
      if (!mounted) return;
      final done = await Navigator.push<bool>(
        context,
        MaterialPageRoute<bool>(
          builder: (_) => TmdbSearchPage(
            initialQuery: item.name,
            pathHash: item.pathHash,
            filename: item.name,
            videoItem: item,
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
    // 用完整列表定位：filtered 受搜索/类型筛选影响，筛选激活时播放记录/收藏卡片点播会
    // 定位不到而错播 filtered[0]，filtered 为空时还会以空列表进入播放页（batch 30 F3）
    final all = ref.read(localVideoProvider).items;
    final idx = all.indexWhere((e) => e.id == item.id);
    final list = idx >= 0 ? all : [item];
    Navigator.of(context)
        .push(
          MaterialPageRoute<Widget>(
            builder: (_) => LocalPlayPage(
              items: list,
              initialIndex: idx < 0 ? 0 : idx,
            ),
          ),
        )
        // 播放返回后清除续播进度缓存，下次重建重新读盘，进度条/剩余时间不显示旧值
        .then((_) => _resumeFutureCache.clear());
  }
}

/// 权限引导页
class _PermissionGuide extends StatelessWidget {
  const _PermissionGuide({required this.permission, required this.onRequest});
  final PermissionState permission;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final denied = permission == PermissionState.denied;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(kSpacingXxl),
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
              denied ? '已被拒绝，请在系统设置中开启「媒体/存储」权限后重试' : '授权后将扫描手机中的视频文件',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: denied ? LocalVideoService.openSetting : onRequest,
              child: Text(denied ? '去设置开启' : '授权并扫描'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onRefresh, required this.hasPermission});
  final VoidCallback onRefresh;
  final bool hasPermission;

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
  const _GridCard({
    required this.item,
    required this.selected,
    required this.selecting,
    required this.isFavorite,
    this.scraped,
    this.episodeCount,
    this.missingLabel,
    required this.onTap,
    required this.onLongPress,
    required this.onFavoriteToggle,
  });
  final LocalVideoItem item;
  final bool selected;
  final bool selecting;
  final bool isFavorite;
  final ScrapedMedia? scraped; // 刮削结果（P0）
  final int? episodeCount; // 剧集总集数（聚合显示）
  final String? missingLabel; // P2#8 缺集提示
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onFavoriteToggle;

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
    } catch (e) { AppLogger.warn('缩略图加载失败', data: {'error': e.toString()}); }
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
                      ? LocalPosterImage(
                          item: widget.item,
                          posterPath: widget.scraped!.posterPath)
                      : _thumb != null
                          ? Image.memory(_thumb!, fit: BoxFit.cover)
                          : Container(
                              color: scheme.surfaceContainerHighest,
                              child: const Icon(Icons.movie, size: 32),
                            ),
                ),
                // P2#2 lowConfidence 角标
                if (widget.scraped?.lowConfidence == true)
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                          color: Colors.orange, shape: BoxShape.circle),
                      child: const Icon(Icons.help_outline,
                          color: Colors.white, size: 12),
                    ),
                  ),
                // 评分角标右上（刮削 P0）
                if (widget.scraped?.rating != null)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        widget.scraped!.rating!.toStringAsFixed(1),
                        style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                // 剧集角标：聚合时显示"N 集"，单集显示 S01E01
                if (widget.scraped?.type == 'tv' && widget.episodeCount != null)
                  Positioned(
                    top: 24,
                    right: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${widget.episodeCount} 集',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11),
                          ),
                        ),
                        if (widget.missingLabel != null) ...[
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade700,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              widget.missingLabel!,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 8),
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                else if (widget.scraped?.type == 'tv' &&
                    widget.scraped?.season != null &&
                    widget.scraped?.episode != null)
                  Positioned(
                    top: 24,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'S${widget.scraped!.season}E${widget.scraped!.episode}',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ),
                // 时长角标右下
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      widget.item.durationLabel,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
                // 分辨率角标左下
                if (widget.item.width > 0)
                  Positioned(
                    left: 4,
                    bottom: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        widget.item.resolutionLabel,
                        style:
                            const TextStyle(color: Colors.white70, fontSize: 11),
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
                        widget.isFavorite
                            ? Icons.favorite
                            : Icons.favorite_border,
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
  const _ResumeProgress({required this.pathHash, required this.totalMs});
  final String pathHash;
  final int totalMs;

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
      return Text(
          '${Duration(milliseconds: widget.totalMs).inMinutes}:${(Duration(milliseconds: widget.totalMs).inSeconds % 60).toString().padLeft(2, '0')}',
          style: const TextStyle(fontSize: 12, color: Colors.grey));
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
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

/// 公共视频缩略图组件（带内存缓存）
class _VideoThumbnail extends StatefulWidget {
  // 刮削海报优先

  const _VideoThumbnail({
    required this.assetId,
    required this.width,
    required this.height,
    this.scraped,
  });
  final String? assetId;
  final double width;
  final double height;
  final ScrapedMedia? scraped;

  /// 静态内存缓存：assetId → thumb bytes
  /// batch53-F3：加 FIFO 容量上限，大媒体库滚动时不再无限驻留内存
  static final Map<String, Uint8List> _cache = {};
  static const int _maxCacheEntries = 200;

  static void _cachePut(String key, Uint8List bytes) {
    if (_cache.length >= _maxCacheEntries) {
      _cache.remove(_cache.keys.first); // 淘汰最旧
    }
    _cache[key] = bytes;
  }

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
        _VideoThumbnail._cachePut(aid, data);
        if (mounted) setState(() => _thumb = data);
      }
    } catch (e) { AppLogger.warn('缩略图加载失败', data: {'error': e.toString()}); }
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
  const _ListTileItem({
    required this.item,
    required this.selected,
    required this.selecting,
    required this.onTap,
    required this.onLongPress,
    this.scraped,
  });
  final LocalVideoItem item;
  final bool selected;
  final bool selecting;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

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
  const _SectionTitle(this.title, {this.actionLabel, this.onAction});
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kSpacingLg, kSpacingLg, kSpacingSm, kSpacingSm),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
