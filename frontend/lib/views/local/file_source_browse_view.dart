import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/file_source.dart';
import '../../models/local_video_item.dart';
import '../../providers/file_sources_provider.dart';
import '../../providers/local_video_provider.dart';
import '../../services/local_dir_scanner.dart';
import '../../services/local_video_service.dart';
import '../../services/scrape_service.dart';
import '../../services/scrape_media_store.dart';
import '../../services/smb_scanner.dart';
import '../../services/tmdb_service.dart';
import '../../services/webdav_scanner.dart';
import 'local_play_page.dart';

/// 源内浏览页（P1 第三批 + P0 增强）
///
/// 根据源类型选择扫描器：WebDAV 走 PROPFIND，SMB 走连通性测试+文件列表。
class FileSourceBrowseView extends ConsumerStatefulWidget {
  const FileSourceBrowseView({super.key, required this.source});
  final FileSource source;

  @override
  ConsumerState<FileSourceBrowseView> createState() => _FileSourceBrowseViewState();
}

class _FileSourceBrowseViewState extends ConsumerState<FileSourceBrowseView> {
  /// 匹配集号：S01E01 / S01.E01 / Season 1 Episode 1 / Episode 01 / E01 / EP01 / 第1集（默认季1）
  static final _epRegex = RegExp(
    r'(?:[Ss](\d{1,2})[._ -]?[Ee](\d{1,2}))|(?:[Ss]eason\s*(\d{1,2})\s*[Ee]pisode\s*(\d{1,2}))|(?:[Ee][Pp]?\s*(\d{1,2}))|(?:第\s*(\d{1,2})\s*集)',
    caseSensitive: false,
  );

  /// 从文件名提取季集号，返回 (season, episode) 或 null
  static (int, int)? _parseSeasonEpisode(String name) {
    final m = _epRegex.firstMatch(name);
    if (m == null) return null;
    // SxxExx: group(1)=season, group(2)=episode
    // Season X Episode Y: group(3)=season, group(4)=episode
    // E01/EP01: group(5)=episode, season 默认 1
    // 第Y集: group(6)=episode, season 默认 1
    final s = m.group(1) ?? m.group(3);
    final e = m.group(2) ?? m.group(4) ?? m.group(5) ?? m.group(6);
    if (e == null) return null;
    return (s != null ? int.parse(s) : 1, int.parse(e));
  }

  List<LocalVideoItem> _items = [];
  Map<String, ScrapedMedia> _scraped = {};
  bool _loading = true;
  String? _error;
  bool _scraping = false;
  int _scrapedCount = 0;
  // 多选模式
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      late final List<LocalVideoItem> items;
      switch (widget.source.type) {
        case FileSourceType.webdav:
          final scanner = WebdavScanner();
          items = await scanner.scan(widget.source);
          break;
        case FileSourceType.smb:
          // SMB：先测连通性，再尝试列文件（当前骨架返回空列表）
          final cfg = widget.source.config;
          final err = await SmbScanner.testConnection(
            host: cfg['host'] ?? '',
            port: int.tryParse(cfg['port'] ?? '') ?? 445,
            username: cfg['username'],
            password: cfg['password'],
            share: cfg['share'],
          );
          if (err != null) {
            throw Exception(err);
          }
          items = await SmbScanner.scan(
            sourceId: widget.source.id,
            host: cfg['host'] ?? '',
            port: int.tryParse(cfg['port'] ?? '') ?? 445,
            username: cfg['username'],
            password: cfg['password'],
            share: cfg['share'],
            path: cfg['path'],
          );
          break;
        case FileSourceType.local:
          // 手机相册：从已扫描的本地视频中筛选 sourceId 匹配的
          items = ref.read(localVideoProvider).items
              .where((e) => e.sourceId == widget.source.id)
              .toList();
          break;
        case FileSourceType.localDir:
          // 支持多文件夹挂载
          final paths = <String>[];
          final rawPaths = widget.source.config['paths'];
          if (rawPaths != null && rawPaths.isNotEmpty) {
            paths.addAll(rawPaths.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty));
          }
          final oldPath = widget.source.config['path'] ?? '';
          if (oldPath.isNotEmpty && !paths.contains(oldPath)) paths.add(oldPath);
          if (paths.isEmpty) throw Exception('未配置文件夹路径');
          items = await LocalDirScanner().scan(paths);
          break;
      }
      if (mounted) {
        // 更新扫描状态到 provider
        ref.read(fileSourcesProvider.notifier).updateScanStatus(
              widget.source.id,
              items.isEmpty ? FileSourceStatus.failed : FileSourceStatus.connected,
              videoCount: items.length,
            );
        final cache = await ScrapeService.loadCache();
        setState(() {
          _items = items;
          _scraped = cache;
          _loading = false;
        });
      }
    } catch (e, st) {
      if (mounted) {
        ref
            .read(fileSourcesProvider.notifier)
            .updateScanStatus(widget.source.id, FileSourceStatus.failed);
        setState(() {
          _error = '$e\n$st';
          _loading = false;
        });
      }
    }
  }

  /// 检查设置开关，开启时才移动失败文件
  Future<void> _moveToFailedIfEnabled(String path) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('move_failed_enabled') ?? false) {
      await ScrapeMediaStore.moveToFailed(path);
    }
  }

  /// 对当前列表中未刮削的视频调用 TMDB 刮削
  Future<void> _scrapeAll() async {
    if (_items.isEmpty || _scraping) return;

    // 检查"所有文件访问"权限——写 .nfo/海报到视频旁需要
    final hasPerm = await LocalVideoService.hasManageExternalStorage();
    if (!hasPerm && mounted) {
      final grant = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('需要文件写入权限'),
          content: const Text(
            '刮削后需要在视频同目录写入 .nfo 元数据和海报图片。\n\n'
            '请在接下来的系统设置中开启「允许管理所有文件」'
            '（或叫「所有文件访问」），否则元数据只能存到 App 内部，'
            '无法在视频文件夹中看到 .nfo 和海报。',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('去开启')),
          ],
        ),
      );
      if (grant == true) {
        await LocalVideoService.requestManageExternalStorage();
      }
    }

    setState(() {
      _scraping = true;
      _scrapedCount = 0;
    });
    ScrapeMediaStore.isScraping.value = true;
    // 并发限流 4，串行避免 TMDB 限速
    const concurrency = 4;
    final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    var i = 0;
    var success = 0;
    while (i < _items.length) {
      final batch = _items.skip(i).take(concurrency).toList();
      await Future.wait(batch.map((item) async {
        try {
          final pathHash = item.pathHash;
          final m = await ScrapeService.scrapeFile(
            pathHash,
            item.name,
            parentDir: item.relativePath,
            mediaTypeHint: widget.source.config['mediaType'],
          );
          if (m != null) {
            await ScrapeService.saveCache(pathHash, m);
            await ScrapeMediaStore.save(item, m, sessionId: sessionId);
            // 增量更新主页，不用等全部刮完
            ref.read(localVideoProvider.notifier).addScrapedEntry(pathHash, m);
            success++;
          } else {
            await ScrapeMediaStore.recordHistory(
              videoPath: item.path, status: 'failed', error: '未找到匹配结果', sessionId: sessionId);
            await _moveToFailedIfEnabled(item.path);
          }
          } catch (e) {
            debugPrint('刮削失败 ${item.name}: $e');
            await ScrapeMediaStore.recordHistory(
              videoPath: item.path, status: 'failed', error: e.toString(), sessionId: sessionId);
            await _moveToFailedIfEnabled(item.path);
          }
      }));
      i += concurrency;
      if (!mounted) {
        ScrapeMediaStore.isScraping.value = false;
        return;
      }
      setState(() => _scrapedCount = i > _items.length ? _items.length : i);
    }
    ScrapeMediaStore.isScraping.value = false;
    if (mounted) {
      final cache = await ScrapeService.loadCache();
      if (!mounted) return;
      setState(() {
        _scraped = cache;
        _scraping = false;
      });
      // 刷新全局 provider，让媒体库主页实时显示新刮削的元数据
      ref.read(localVideoProvider.notifier).refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('刮削完成：成功 $success / 共 ${_items.length} 个视频')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.source.name),
        actions: [
          IconButton(onPressed: _showHelp, icon: const Icon(Icons.help_outline), tooltip: '使用帮助'),
          IconButton(onPressed: _scan, icon: const Icon(Icons.refresh)),
          IconButton(onPressed: _showRenameHistory, icon: const Icon(Icons.history), tooltip: '重命名历史'),
          IconButton(
            onPressed: _scraping ? null : _scrapeAll,
            icon: _scraping
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome),
            tooltip: '刮削此文件夹',
          ),
          // 电影模式批量操作菜单
          if (widget.source.config['mediaType'] != 'tv')
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: _onMovieBatchAction,
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'renameAllMovies', child: Row(children: [Icon(Icons.auto_fix_high, size: 18, color: Colors.green), SizedBox(width: 8), Text('按刮削重命名')])),
                PopupMenuItem(value: 'renameByFolder', child: Row(children: [Icon(Icons.folder, size: 18), SizedBox(width: 8), Text('按文件夹名重命名')])),
                PopupMenuItem(value: 'organizeMovies', child: Row(children: [Icon(Icons.folder_special, size: 18), SizedBox(width: 8), Text('整理文件结构')])),
                PopupMenuItem(value: 'undoRename', child: Row(children: [Icon(Icons.undo, size: 18, color: Colors.orange), SizedBox(width: 8), Text('撤销上次重命名')])),
                PopupMenuItem(value: 'renameHistory', child: Row(children: [Icon(Icons.history, size: 18), SizedBox(width: 8), Text('重命名历史')])),
              ],
            ),
        ],
      ),
      bottomNavigationBar: _buildSelectionBar(),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        Text('扫描失败', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                        const SizedBox(height: 16),
                        FilledButton(onPressed: _scan, child: const Text('重试')),
                      ],
                    ),
                  ),
                )
              : _items.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.source.type == FileSourceType.smb
                                  ? Icons.check_circle_outline
                                  : Icons.video_library_outlined,
                              size: 48,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              widget.source.type == FileSourceType.smb
                                  ? 'SMB 连接成功，文件列表开发中'
                                  : '未找到视频文件',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _buildBody(),
    );
  }

  final Set<String> _expandedFolders = {};

  Widget _buildBody() {
    // mediaType=tv 或文件名含 SxxExx 模式时按文件夹分组
    final hasTvPattern = _items.any((it) => _parseSeasonEpisode(it.name) != null);
    final isTv = widget.source.config['mediaType'] == 'tv' || hasTvPattern;
    // TV 类型按文件夹分组
    if (isTv) {
      // 按剧名分组（自动跳过 Season 子目录）
      final groups = <String, List<LocalVideoItem>>{};
      final groupDir = <String, String>{};
      for (final it in _items) {
        final folder = ScrapeService.extractSeriesName(it.relativePath) ??
            (it.relativePath?.split('/').where((s) => s.isNotEmpty).last ?? '未分组');
        groups.putIfAbsent(folder, () => []).add(it);
        // 剧根目录：去掉 Season 子目录后缀，避免重命名改错目录
        final rel = it.relativePath ?? '';
        final m = RegExp(r'[\/\\][Ss]eason\s*\d+[\/\\]?.*$', caseSensitive: false).firstMatch(rel);
        final rootPath = m != null ? rel.substring(0, m.start) : rel;
        groupDir.putIfAbsent(folder, () => rootPath);
      }
      // 建立 pathHash → 列表索引映射，避免每集 O(n) indexOf
      final indexByHash = {
        for (var i = 0; i < _items.length; i++) _items[i].pathHash: i,
      };
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final entry in groups.entries)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onLongPress: () => _showGroupMenu(entry.key, groupDir[entry.key] ?? '', entry.value),
                child: ExpansionTile(
                initiallyExpanded: _expandedFolders.contains(entry.key),
                onExpansionChanged: (v) {
                  setState(() {
                    if (v) {
                      _expandedFolders.add(entry.key);
                    } else {
                      _expandedFolders.remove(entry.key);
                    }
                  });
                },
                leading: const Icon(Icons.folder, color: Colors.amber),
                title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${entry.value.length}集'),
                trailing: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz, size: 20),
                  onSelected: (v) => _onGroupAction(v, entry.key, groupDir[entry.key] ?? '', entry.value),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'scrape', child: Row(children: [Icon(Icons.search, size: 18), SizedBox(width: 8), Text('刮削本剧')])),
                    const PopupMenuItem(value: 'renameAll', child: Row(children: [Icon(Icons.auto_fix_high, size: 18, color: Colors.green), SizedBox(width: 8), Text('一键重命名集数')])),
                    const PopupMenuItem(value: 'organize', child: Row(children: [Icon(Icons.folder_special, size: 18), SizedBox(width: 8), Text('整理文件结构')])),
                    const PopupMenuItem(value: 'renameFolder', child: Row(children: [Icon(Icons.drive_file_rename_outline, size: 18), SizedBox(width: 8), Text('重命名文件夹')])),
                    const PopupMenuItem(value: 'renameFolderScraped', child: Row(children: [Icon(Icons.auto_fix_high, size: 18, color: Colors.green), SizedBox(width: 8), Text('按刮削信息重命名文件夹')])),
                    const PopupMenuItem(value: 'undoRename', child: Row(children: [Icon(Icons.undo, size: 18, color: Colors.orange), SizedBox(width: 8), Text('撤销上次重命名')])),
                    const PopupMenuItem(value: 'renameHistory', child: Row(children: [Icon(Icons.history, size: 18), SizedBox(width: 8), Text('重命名历史')])),
                  ],
                ),
                children: entry.value.map((it) {
                  return _buildItemTile(it, indexByHash[it.pathHash] ?? 0);
                }).toList(),
              ),
              ),
            ),
        ],
      );
    }
    return ListView.separated(
      itemCount: _items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) => _buildItemTile(_items[i], i),
    );
  }

  void _showGroupMenu(String seriesName, String dirPath, List<LocalVideoItem> eps) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.search, color: Colors.green),
              title: const Text('刮削本剧'),
              onTap: () => Navigator.pop(context, 'scrape'),
            ),
            ListTile(
              leading: const Icon(Icons.auto_fix_high, color: Colors.green),
              title: const Text('一键重命名集数'),
              onTap: () => Navigator.pop(context, 'renameAll'),
            ),
            ListTile(
              leading: const Icon(Icons.folder_special),
              title: const Text('整理文件结构'),
              onTap: () => Navigator.pop(context, 'organize'),
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: const Text('重命名文件夹'),
              onTap: () => Navigator.pop(context, 'renameFolder'),
            ),
            ListTile(
              leading: const Icon(Icons.auto_fix_high, color: Colors.green),
              title: const Text('按刮削信息重命名文件夹'),
              onTap: () => Navigator.pop(context, 'renameFolderScraped'),
            ),
            ListTile(
              leading: const Icon(Icons.undo, color: Colors.orange),
              title: const Text('撤销上次重命名'),
              onTap: () => Navigator.pop(context, 'undoRename'),
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('重命名历史'),
              onTap: () => Navigator.pop(context, 'renameHistory'),
            ),
          ],
        ),
      ),
    );
    if (action != null) _onGroupAction(action, seriesName, dirPath, eps);
  }

  Future<void> _onGroupAction(String action, String seriesName, String dirPath, List<LocalVideoItem> eps) async {
    switch (action) {
      case 'scrape':
        await _scrapeGroup(seriesName, eps);
        break;
      case 'renameAll':
        await _renameAllEpisodes(seriesName, eps);
        break;
      case 'organize':
        await _organizeStructure(seriesName, eps);
        break;
      case 'renameFolder':
        await _renameFolder(seriesName, dirPath);
        break;
      case 'renameFolderScraped':
        await _renameFolderByScraped(seriesName, dirPath, eps);
        break;
      case 'undoRename':
        await _undoLastRename();
        break;
      case 'renameHistory':
        await _showRenameHistory();
        break;
    }
  }

  /// 刮削某部剧的所有集（TMDB 只搜一次）
  Future<void> _scrapeGroup(String seriesName, List<LocalVideoItem> eps) async {
    setState(() {
      _scraping = true;
      _scrapedCount = 0;
    });
    final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    ScrapeMediaStore.isScraping.value = true;
    // 第一步：按剧名搜一次 TMDB（去掉括号年份避免搜索偏差）
    ScrapedMedia? base;
    try {
      final searchName = seriesName.replaceAll(RegExp(r'\s*\(\d{4}\)\s*'), '').trim();
      base = await ScrapeService.scrapeTvSeries(searchName);
    } catch (e) {
      debugPrint('剧集刮削失败 $seriesName: $e');
    }
    if (base == null) {
      ScrapeMediaStore.isScraping.value = false;
      // 记录整剧失败
      if (eps.isNotEmpty) {
        await ScrapeMediaStore.recordHistory(
          videoPath: eps.first.path,
          status: 'failed',
          matchedTitle: seriesName,
          error: '未在 TMDB 找到该剧',
          sessionId: sessionId,
        );
      }
      if (mounted) {
        setState(() => _scraping = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('未在 TMDB 找到该剧')));
      }
      return;
    }
    // 第二步：给每集叠加季集号 + 拉取单集详情（标题/简介/剧照），并存缓存
    int done = 0, epFail = 0;
    for (final item in eps) {
      try {
        final ep = ScrapeService.extractEpisode(item.name);
        ScrapedMedia media;
        if (ep != null) {
          media = ScrapeService.applyEpisodeInfo(base, ep.season, ep.episode);
          // 拉取单集详情（标题/简介/剧照），与 scrapeFile 自动刮削保持一致
          try {
            final epDetail = await TmdbService.getTvEpisodeDetails(
                base.tmdbId, ep.season, ep.episode);
            if (epDetail.isNotEmpty) {
              media = ScrapedMedia(
                tmdbId: media.tmdbId,
                type: 'tv',
                title: media.title,
                year: media.year,
                posterPath: media.posterPath,
                backdropPath: media.backdropPath,
                overview: epDetail['overview'] as String? ?? media.overview,
                rating: media.rating,
                genres: media.genres,
                cast: media.cast,
                directors: media.directors,
                studios: media.studios,
                imdbId: media.imdbId,
                stillPath: epDetail['still_path'] as String?,
                episodeTitle: epDetail['name'] as String?,
                season: media.season,
                episode: media.episode,
                tvId: media.tvId,
                scrapedAt: media.scrapedAt,
              );
            }
          } catch (_) {}
        } else {
          media = base;
        }
        await ScrapeService.saveCache(item.pathHash, media);
        // 写每集视频旁 .nfo/-poster.jpg（单集不单独写历史，整剧末尾统一记录）
        await ScrapeMediaStore.save(item, media, logHistory: false);
        // 增量更新主页
        ref.read(localVideoProvider.notifier).addScrapedEntry(item.pathHash, media);
      } catch (e) {
        debugPrint('单集元数据保存失败 ${item.name}: $e');
        epFail++;
      }
      if (!mounted) {
        ScrapeMediaStore.isScraping.value = false;
        return;
      }
      setState(() => _scrapedCount = ++done);
    }
    // 整剧刮削成功后写一条汇总记录
    await ScrapeMediaStore.recordHistory(
      videoPath: eps.first.path,
      status: 'success',
      matchedTitle: base.title,
      matchedYear: base.year,
      error: epFail > 0 ? '$epFail 集保存失败' : null,
      sessionId: sessionId,
    );
    ScrapeMediaStore.isScraping.value = false;
    final cache = await ScrapeService.loadCache();
    if (!mounted) return;
    setState(() {
      _scraped = cache;
      _scraping = false;
    });
    ref.read(localVideoProvider.notifier).refresh();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('刮削完成：$done 集共享《${base.title}》元数据')));
    }
  }

  /// 一键重命名某部剧的所有集为 "剧名 S01E01.ext"
  Future<void> _renameAllEpisodes(String seriesName, List<LocalVideoItem> eps) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(children: [CircularProgressIndicator(), SizedBox(width: 16), Text('正在重命名...')]),
      ),
    );
    int ok = 0;
    int fail = 0;
    int skip = 0;
    for (final item in eps) {
      try {
        final s = _scraped[item.pathHash];
        if (s != null) {
          await LocalVideoService().renameByScraped(item, s);
          ok++;
        } else {
          // 没有刮削数据，从文件名提取季集号
          final se = _parseSeasonEpisode(item.name);
          if (se != null) {
            final seStr = 'S${se.$1.toString().padLeft(2, '0')}E${se.$2.toString().padLeft(2, '0')}';
            final safe = seriesName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '').trim();
            await LocalVideoService().renameFile(item, '$safe $seStr');
            ok++;
          } else {
            skip++;
          }
        }
      } catch (_) {
        fail++;
      }
    }
    if (mounted) {
      Navigator.pop(context); // 关闭加载框
      final msg = StringBuffer('重命名完成：成功 $ok');
      if (skip > 0) msg.write('，跳过 $skip');
      if (fail > 0) msg.write('，失败 $fail');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg.toString())));
      _scan();
    }
  }

  /// 整理文件结构：把扁平集数移动到 Season X 子文件夹
  /// 如 西游记/S01E01.mp4 → 西游记/Season 1/西游记 - S01E01.mp4
  Future<void> _organizeStructure(String seriesName, List<LocalVideoItem> eps) async {
    // 标准化文件夹名：[2022] → (2022)
    var safeSeries = seriesName.replaceAll(RegExp(r'\[(\d{4})\]'), r'($1)');
    safeSeries = safeSeries.replaceAll(RegExp(r'[\\/:*?"<>|]'), '').trim();
    // 先统计将要移动的文件数
    var willMove = 0;
    var noEpInfo = 0;
    for (final item in eps) {
      final ep = _parseSeasonEpisode(item.name);
      if (ep == null) { noEpInfo++; continue; }
      var parent = item.path.substring(0, item.path.lastIndexOf('/'));
      final seasonMatch = RegExp(r'[\/\\][Ss]eason\s*(\d+)$', caseSensitive: false).firstMatch(parent);
      if (seasonMatch != null) continue;
      willMove++;
    }
    if (willMove == 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(noEpInfo > 0 ? '所有集数已整理或无法识别集号（$noEpInfo 个跳过）' : '所有集数已在 Season 目录中，无需整理'),
        ));
      }
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('整理文件结构'),
        content: Text('将整理 $willMove 个集数为标准格式：\n$safeSeries/Season X/$safeSeries - S01E01.ext\n\n${noEpInfo > 0 ? '$noEpInfo 个文件无法识别集号，将跳过。\n\n' : ''}是否继续？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('开始整理')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(children: [CircularProgressIndicator(), SizedBox(width: 16), Text('正在整理...')]),
      ),
    );
    int ok = 0, fail = 0, dup = 0, skip = 0;
    for (final item in eps) {
      try {
        final ep = _parseSeasonEpisode(item.name);
        if (ep == null) { skip++; continue; }
        final season = ep.$1;
        var parent = item.path.substring(0, item.path.lastIndexOf('/'));
        // 先判断是否已在 Season X 子文件夹里
        final seasonMatch = RegExp(r'[\/\\][Ss]eason\s*(\d+)$', caseSensitive: false).firstMatch(parent);
        if (seasonMatch != null) {
          // 已在 Season 目录里，跳过
          continue;
        }
        // 如果父目录名和标准化剧名不一致（如 [2022] vs (2022)），重命名父目录
        final parentName = parent.substring(parent.lastIndexOf('/') + 1);
        if (parentName != safeSeries) {
          final newParent = parent.substring(0, parent.lastIndexOf('/') + 1) + safeSeries;
          if (!await Directory(newParent).exists()) {
            await Directory(parent).rename(newParent);
          }
          parent = newParent;
        }
        final seasonDir = Directory('$parent/Season $season');
        if (!await seasonDir.exists()) await seasonDir.create(recursive: true);
        // item.name 不含扩展名，需从原 path 拼回
        final dot = item.path.lastIndexOf('.');
        final ext = dot > 0 ? item.path.substring(dot) : '';
        // TMDB 标准格式：剧名 - S01E01.ext
        final seStr = 'S${season.toString().padLeft(2, '0')}E${ep.$2.toString().padLeft(2, '0')}';
        final newPath = '$parent/Season $season/$safeSeries - $seStr$ext';
        if (await File(newPath).exists()) {
          dup++;
          continue;
        }
        await File(item.path).rename(newPath);
        await LocalVideoService().recordRename(item.path, newPath);
        await LocalVideoService().migrateCachePath(item.path, newPath);
        // 双轨落盘：同步重命名旁置文件并清理沙箱旧元数据
        try {
          await ScrapeMediaStore.rename(item.path, newPath);
          // 同步移动 .actors/ 目录
          final oldActorsDir = Directory('${item.path.substring(0, dot)}/.actors');
          if (await oldActorsDir.exists()) {
            final newActorsDir = Directory('${newPath.substring(0, newPath.lastIndexOf('.'))}/.actors');
            if (!await newActorsDir.parent.exists()) await newActorsDir.parent.create(recursive: true);
            await oldActorsDir.rename(newActorsDir.path);
          }
        } catch (_) {}
        ok++;
      } catch (_) {
        fail++;
      }
    }
    if (mounted) {
      Navigator.pop(context); // 关闭加载框
      final msg = StringBuffer('整理完成：移动 $ok 个文件');
      if (dup > 0) msg.write('，$dup 个重复已跳过');
      if (skip > 0) msg.write('，$skip 个无法识别');
      if (fail > 0) msg.write('，失败 $fail');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg.toString())));
      _scan();
    }
  }

  Future<void> _renameFolder(String oldName, String dirPath) async {
    final ctrl = TextEditingController(text: oldName);
    String preview = oldName;
    final parentPath = dirPath.isNotEmpty && dirPath.lastIndexOf('/') > 0
        ? dirPath.substring(0, dirPath.lastIndexOf('/'))
        : '';
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (_, setDialog) => AlertDialog(
          title: const Text('重命名剧集文件夹'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: ctrl,
                autofocus: true,
                onChanged: (v) => setDialog(() => preview = v.trim()),
                decoration: const InputDecoration(hintText: '输入新文件夹名'),
              ),
              const SizedBox(height: 12),
              Text(
                '$parentPath/$preview',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
            TextButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('确定')),
          ],
        ),
      ),
    );
    if (newName == null || newName.isEmpty || newName == oldName) return;
    if (dirPath.isEmpty || dirPath.lastIndexOf('/') < 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('无法定位文件夹路径')));
      }
      return;
    }
    try {
      final newPath = '${dirPath.substring(0, dirPath.lastIndexOf('/'))}/$newName';
      if (await Directory(newPath).exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('文件夹 "$newName" 已存在')));
        }
        return;
      }
      await Directory(dirPath).rename(newPath);
      await LocalVideoService().recordRename(dirPath, newPath);
      await LocalVideoService().migrateFolderCache(dirPath, newPath);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('文件夹重命名成功')));
        _scan();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('重命名失败: $e')));
      }
    }
  }

  /// 按刮削信息重命名剧名文件夹为 "剧名 (年份)"
  Future<void> _renameFolderByScraped(String seriesName, String dirPath, List<LocalVideoItem> eps) async {
    // 从任一集的刮削数据取剧名和年份
    ScrapedMedia? s;
    for (final ep in eps) {
      final candidate = _scraped[ep.pathHash];
      if (candidate != null) { s = candidate; break; }
    }
    if (s == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('无刮削数据，请先刮削本剧')));
      }
      return;
    }
    final safeTitle = s.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '').trim();
    final newName = s.year != null ? '$safeTitle (${s.year})' : safeTitle;
    if (newName == seriesName) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('文件夹名已正确，无需重命名')));
      }
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('按刮削信息重命名文件夹'),
        content: Text('$seriesName\n→\n$newName\n\n是否继续？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('确定')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    if (dirPath.isEmpty || dirPath.lastIndexOf('/') < 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('无法定位文件夹路径')));
      }
      return;
    }
    try {
      final newPath = '${dirPath.substring(0, dirPath.lastIndexOf('/'))}/$newName';
      if (await Directory(newPath).exists()) throw Exception('目标文件夹已存在');
      await Directory(dirPath).rename(newPath);
      await LocalVideoService().recordRename(dirPath, newPath);
      await LocalVideoService().migrateFolderCache(dirPath, newPath);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('文件夹已重命名为: $newName')));
        _scan();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('重命名失败: $e')));
      }
    }
  }

  /// 撤销最近一次重命名
  Future<void> _undoLastRename() async {
    try {
      final newPath = await LocalVideoService().undoLastRename();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已撤销: ${newPath.split('/').last}')));
        _scan();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
      }
    }
  }

  /// 使用帮助
  void _showHelp() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(children: [Icon(Icons.help_outline), SizedBox(width: 8), Text('使用帮助')]),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              _HelpItem('刮削', '从 TMDB 拉取海报、简介、演员等元数据，写入 .nfo 文件。'),
              _HelpItem('按刮削重命名', '用 TMDB 的标准片名+年份重命名文件。需先刮削。'),
              _HelpItem('按文件夹名重命名', '直接用父文件夹名重命名文件，无需刮削。'),
              _HelpItem('整理文件结构（电影）', '把电影移入独立文件夹，自动从文件名提取片名和年份。'),
              _HelpItem('整理文件结构（电视剧）', '把集数移入 Season X 子文件夹，并改名为标准格式。'),
              _HelpItem('一键重命名集数', '把所有集数改为"剧名 S01E01"格式。'),
              _HelpItem('重命名文件夹', '修改剧集所在文件夹名称。'),
              _HelpItem('重新刮削', '长按某个文件，单独重新拉取 TMDB 元数据。'),
              _HelpItem('橙色感叹号', '元数据不完整（缺海报或简介），可重新刮削补全。'),
              _HelpItem('重命名历史', '查看历史重命名记录，支持撤销。'),
              _HelpItem('多选', '长按文件进入多选模式，可批量重命名或删除。'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('知道了')),
        ],
      ),
    );
  }

  /// 查看重命名历史
  Future<void> _showRenameHistory() async {
    final history = await LocalVideoService().getRenameHistory();
    if (!mounted) return;
    if (history.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('暂无重命名记录')));
      return;
    }
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('重命名历史'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: history.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final e = history[i];
              final oldName = e.key.split('/').last;
              final newName = e.value.split('/').last;
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('$oldName → $newName', maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: TextButton(
                  onPressed: () async {
                    Navigator.pop(_);
                    try {
                      await LocalVideoService().undoRenameEntry(e.key, e.value);
                      // 从历史中移除该条目
                      final sp = await SharedPreferences.getInstance();
                      final list = sp.getStringList('rename_history') ?? [];
                      list.removeAt(i);
                      await sp.setStringList('rename_history', list);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已撤销: $newName')));
                        _scan();
                      }
                    } catch (ex) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('撤销失败: ${ex.toString().replaceFirst('Exception: ', '')}')));
                      }
                    }
                  },
                  child: const Text('撤销'),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final sp = await SharedPreferences.getInstance();
              await sp.setStringList('rename_history', []);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('历史已清空')));
              }
            },
            child: const Text('清空', style: TextStyle(color: Colors.red)),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭')),
        ],
      ),
    );
  }

  /// 电影模式批量操作分发
  void _onMovieBatchAction(String action) async {
    switch (action) {
      case 'renameAllMovies':
        await _renameAllMovies();
        break;
      case 'renameByFolder':
        await _renameMoviesByFolder();
        break;
      case 'organizeMovies':
        await _organizeMovies();
        break;
      case 'undoRename':
        await _undoLastRename();
        break;
      case 'renameHistory':
        await _showRenameHistory();
        break;
    }
  }

  /// 按刮削信息重命名电影为 "片名 (年份)"
  Future<void> _renameAllMovies() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(children: [CircularProgressIndicator(), SizedBox(width: 16), Text('正在重命名...')]),
      ),
    );
    int ok = 0, fail = 0, skip = 0;
    for (final item in _items) {
      try {
        final s = _scraped[item.pathHash];
        if (s != null) {
          await LocalVideoService().renameByScraped(item, s);
          ok++;
        } else {
          skip++;
        }
      } catch (_) {
        fail++;
      }
    }
    if (mounted) {
      Navigator.pop(context);
      final msg = StringBuffer('重命名完成：成功 $ok');
      if (skip > 0) msg.write('，$skip 个未刮削');
      if (fail > 0) msg.write('，失败 $fail');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg.toString())));
      _scan();
    }
  }

  /// 按父文件夹名重命名电影文件（无需刮削）
  /// 例：哪吒 (2019)/random.mp4 → 哪吒 (2019)/哪吒 (2019).mp4
  Future<void> _renameMoviesByFolder() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(children: [CircularProgressIndicator(), SizedBox(width: 16), Text('正在重命名...')]),
      ),
    );
    int ok = 0, fail = 0, skip = 0;
    for (final item in _items) {
      try {
        final parent = item.path.substring(0, item.path.lastIndexOf('/'));
        final folderName = parent.substring(parent.lastIndexOf('/') + 1);
        final dot = item.name.lastIndexOf('.');
        final nameWithoutExt = dot > 0 ? item.name.substring(0, dot) : item.name;
        if (folderName.isNotEmpty && folderName != nameWithoutExt) {
          await LocalVideoService().renameFile(item, folderName);
          ok++;
        } else {
          skip++;
        }
      } catch (_) {
        fail++;
      }
    }
    if (mounted) {
      Navigator.pop(context);
      final msg = StringBuffer('按文件夹名重命名：成功 $ok');
      if (skip > 0) msg.write('，跳过 $skip');
      if (fail > 0) msg.write('，失败 $fail');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg.toString())));
      _scan();
    }
  }

  /// 从文件名提取片名和年份（无刮削数据时使用）
  /// 例：[bdys.me]王牌替身.2023.HD1080P → (王牌替身, 2023)
  /// 例：长空之王.Born.to.Fly.2023.4K → (长空之王, 2023)
  static (String, int?)? _parseTitleYear(String filename) {
    var name = filename;
    // 去掉扩展名
    final dot = name.lastIndexOf('.');
    if (dot > 0) name = name.substring(0, dot);
    // 去掉 [网站名] 前缀
    name = name.replaceFirst(RegExp(r'^\[[^\]]*\]'), '').trim();
    // 找年份（19xx-20xx）
    final yearMatch = RegExp(r'(19\d{2}|20\d{2})').firstMatch(name);
    int? year;
    String titlePart;
    if (yearMatch != null) {
      year = int.tryParse(yearMatch.group(0)!);
      titlePart = name.substring(0, yearMatch.start);
    } else {
      titlePart = name;
    }
    // 清理：去掉末尾的点、空格、分隔符
    titlePart = titlePart.replaceAll(RegExp(r'[.\s\-_]+$'), '').trim();
    // 如果片名包含中文，优先取中文部分（中英双语片名只留中文）
    final chineseMatch = RegExp(r'[\u4e00-\u9fff][\u4e00-\u9fff0-9]*').firstMatch(titlePart);
    if (chineseMatch != null) {
      titlePart = chineseMatch.group(0)!;
    }
    if (titlePart.isEmpty) return null;
    return (titlePart, year);
  }

  /// 整理电影文件结构：每部电影移入独立文件夹
  /// 例：电影/哪吒.mp4 → 电影/哪吒 (2019)/哪吒 (2019).mp4
  Future<void> _organizeMovies() async {
    // 统计需要移动的电影数（有刮削用刮削，无刮削从文件名提取）
    final needMove = <LocalVideoItem>[];
    for (final item in _items) {
      final s = _scraped[item.pathHash];
      String title;
      int? year;
      if (s != null) {
        title = s.title;
        year = s.year;
      } else {
        final parsed = _parseTitleYear(item.name);
        if (parsed == null) continue;
        title = parsed.$1;
        year = parsed.$2;
      }
      final folderName = year != null ? '$title ($year)' : title;
      final parent = item.path.substring(0, item.path.lastIndexOf('/'));
      if (!parent.endsWith('/$folderName') && parent != folderName) {
        needMove.add(item);
      }
    }

    if (needMove.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无需整理：所有电影已在独立文件夹中')),
        );
      }
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('整理电影文件结构'),
        content: Text('将把 $needMove 部电影移入独立文件夹：\n\n例：电影/哪吒.mp4 → 电影/哪吒 (2019)/哪吒 (2019).mp4\n\n是否继续？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('开始整理')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(children: [CircularProgressIndicator(), SizedBox(width: 16), Text('正在整理...')]),
      ),
    );
    int ok = 0, fail = 0, dup = 0;
    for (final item in needMove) {
      try {
        final s = _scraped[item.pathHash];
        String title;
        int? year;
        if (s != null) {
          title = s.title;
          year = s.year;
        } else {
          final parsed = _parseTitleYear(item.name)!;
          title = parsed.$1;
          year = parsed.$2;
        }
        final safeTitle = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '').trim();
        final folderName = year != null ? '$safeTitle ($year)' : safeTitle;
        final parent = item.path.substring(0, item.path.lastIndexOf('/'));
        final dot = item.path.lastIndexOf('.');
        final ext = dot > 0 ? item.path.substring(dot) : '';
        final movieDir = Directory('$parent/$folderName');
        if (!await movieDir.exists()) await movieDir.create(recursive: true);
        final newPath = '$parent/$folderName/$folderName$ext';
        if (await File(newPath).exists()) {
          dup++;
          continue;
        }
        await File(item.path).rename(newPath);
        await LocalVideoService().recordRename(item.path, newPath);
        await LocalVideoService().migrateCachePath(item.path, newPath);
        // 双轨落盘：同步重命名旁置文件并清理沙箱旧元数据
        try {
          await ScrapeMediaStore.rename(item.path, newPath);
          // 同步移动 .actors/ 目录
          final oldActorsDir = Directory('${item.path.substring(0, dot)}/.actors');
          if (await oldActorsDir.exists()) {
            final newActorsDir = Directory('${newPath.substring(0, newPath.lastIndexOf('.'))}/.actors');
            if (!await newActorsDir.parent.exists()) await newActorsDir.parent.create(recursive: true);
            await oldActorsDir.rename(newActorsDir.path);
          }
        } catch (_) {}
        ok++;
      } catch (_) {
        fail++;
      }
    }
    // 清理整理后空的旧文件夹（仅当目录为空时）
    try {
      final cleanedDirs = <String>{};
      for (final item in needMove) {
        final parent = item.path.substring(0, item.path.lastIndexOf('/'));
        if (parent.isEmpty || cleanedDirs.contains(parent)) continue;
        final dir = Directory(parent);
        if (await dir.exists() && (await dir.list().isEmpty)) {
          await dir.delete();
          cleanedDirs.add(parent);
        }
      }
    } catch (_) {}
    if (mounted) {
      Navigator.pop(context); // 关闭加载框
      final msg = StringBuffer('整理完成：移动 $ok 个文件');
      if (dup > 0) msg.write('，$dup 个重复已跳过');
      if (fail > 0) msg.write('，失败 $fail');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg.toString())),
      );
      _scan();
    }
  }

  String _itemTitle(ScrapedMedia? s, LocalVideoItem item) {
    if (s == null) return item.name;
    // 电视剧单集：显示集号和单集标题，不再只显示剧名
    if (s.type == 'tv' && s.season != null && s.episode != null) {
      final se = 'S${s.season!.toString().padLeft(2, '0')}E${s.episode!.toString().padLeft(2, '0')}';
      if (s.episodeTitle != null && s.episodeTitle!.isNotEmpty) {
        return '$se · ${s.episodeTitle}';
      }
      return se;
    }
    return s.title;
  }

  String _itemSubtitle(ScrapedMedia? s, LocalVideoItem item) {
    final parts = <String>[];
    if (s != null) {
      // 电视剧单集：副标题显示剧名
      if (s.type == 'tv' && s.season != null) parts.add(s.title);
      if (s.year != null) parts.add('${s.year}');
    }
    parts.add(item.sizeLabel);
    return parts.join(' · ');
  }

  Widget _buildItemTile(LocalVideoItem item, int index) {
    final s = _scraped[item.pathHash];
    final selecting = _selected.isNotEmpty;
    final isSelected = _selected.contains(item.pathHash);
    return ListTile(
      leading: selecting
          ? Icon(isSelected ? Icons.check_circle : Icons.circle_outlined,
              color: isSelected ? Colors.pink : Colors.grey, size: 28)
          : SizedBox(
              width: 48,
              height: 68,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: s?.posterPath != null
                    ? CachedNetworkImage(imageUrl: TmdbService.posterUrl(s!.posterPath!), fit: BoxFit.cover)
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(color: Colors.grey[800], child: const Icon(Icons.movie, size: 20)),
                          if (s != null)
                            Positioned(
                              top: 2,
                              right: 2,
                              child: Container(
                                padding: const EdgeInsets.all(1),
                                decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(6)),
                                child: const Icon(Icons.check, size: 10, color: Colors.white),
                              ),
                            ),
                        ],
                      ),
              ),
            ),
      title: s == null
          ? Row(children: [
              Expanded(child: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 6),
              Text('未刮削', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
            ])
          : Row(children: [
              Expanded(child: Text(_itemTitle(s, item), maxLines: 1, overflow: TextOverflow.ellipsis)),
              // 元数据不完整标记：缺海报或简介
              if (s.posterPath == null || s.overview == null || s.overview!.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(Icons.error_outline, size: 14, color: Colors.orange),
                ),
            ]),
      subtitle: Text(_itemSubtitle(s, item), maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: selecting ? null : const Icon(Icons.play_arrow, size: 20),
      selected: isSelected,
      selectedTileColor: Colors.pink.withValues(alpha: 0.1),
      onTap: () {
        if (selecting) {
          setState(() {
            if (isSelected) {
              _selected.remove(item.pathHash);
            } else {
              _selected.add(item.pathHash);
            }
          });
        } else {
          Navigator.push(
            context,
            MaterialPageRoute<Widget>(builder: (_) => LocalPlayPage(items: _items, initialIndex: index)),
          );
        }
      },
      onLongPress: () {
        if (selecting) return;
        _showLongPressMenu(item);
      },
    );
  }

  /// 多选模式下的底部操作栏
  Widget? _buildSelectionBar() {
    if (_selected.isEmpty) return null;
    return BottomAppBar(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          TextButton.icon(
            icon: const Icon(Icons.close, color: Colors.grey),
            label: const Text('取消'),
            onPressed: () => setState(() => _selected.clear()),
          ),
          TextButton(
            child: Text(_selected.length == _items.length ? '取消全选' : '全选'),
            onPressed: () => setState(() {
              if (_selected.length == _items.length) {
                _selected.clear();
              } else {
                _selected.addAll(_items.map((i) => i.pathHash));
              }
            }),
          ),
          Text('已选 ${_selected.length}'),
          TextButton.icon(
            icon: const Icon(Icons.auto_fix_high, color: Colors.green),
            label: const Text('按刮削重命名'),
            onPressed: () => _batchRename(),
          ),
          TextButton.icon(
            icon: const Icon(Icons.delete, color: Colors.red),
            label: const Text('删除'),
            onPressed: () => _batchDelete(),
          ),
        ],
      ),
    );
  }

  Future<void> _batchRename() async {
    int ok = 0, fail = 0, skip = 0;
    for (final item in _items.where((i) => _selected.contains(i.pathHash))) {
      try {
        final s = _scraped[item.pathHash];
        if (s != null) {
          await LocalVideoService().renameByScraped(item, s);
          ok++;
        } else {
          skip++;
        }
      } catch (_) {
        fail++;
      }
    }
    setState(() => _selected.clear());
    if (mounted) {
      final msg = StringBuffer('批量重命名：成功 $ok');
      if (skip > 0) msg.write('，$skip 个未刮削');
      if (fail > 0) msg.write('，失败 $fail');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg.toString())));
      _scan();
    }
  }

  Future<void> _batchDelete() async {
    final selectedItems = _items.where((i) => _selected.contains(i.pathHash)).toList();
    final count = selectedItems.length;
    final preview = selectedItems.take(3).map((i) => i.name).join('\n');
    final more = count > 3 ? '\n... 等 $count 个文件' : '';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('批量删除'),
        content: Text('确定删除以下 $count 个文件？\n\n$preview$more\n\n此操作不可撤销。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除')),
        ],
      ),
    );
    if (confirm != true) return;
    int ok = 0, fail = 0;
    for (final item in _items.where((i) => _selected.contains(i.pathHash))) {
      try {
        await LocalVideoService().delete(item);
        ok++;
      } catch (_) {
        fail++;
      }
    }
    setState(() => _selected.clear());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('批量删除：成功 $ok，失败 $fail')));
      _scan();
    }
  }

  void _showLongPressMenu(LocalVideoItem item) async {
    final s = _scraped[item.pathHash];
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (s != null)
              ListTile(
                leading: const Icon(Icons.auto_fix_high, color: Colors.green),
                title: const Text('按刮削信息重命名'),
                subtitle: Text('→ ${s.title}${s.year != null ? " (${s.year})" : ""}', maxLines: 1),
                enabled: item.assetId == null,
                onTap: () => Navigator.pop(context, 'autoRename'),
              ),
            ListTile(
              leading: const Icon(Icons.refresh, color: Colors.blue),
              title: const Text('重新刮削'),
              subtitle: Text(s != null ? '已有元数据，重新拉取TMDB' : '从未刮削过，拉取TMDB元数据', maxLines: 1),
              onTap: () => Navigator.pop(context, 'rescrape'),
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: const Text('手动重命名'),
              subtitle: Text(item.name, maxLines: 1),
              enabled: item.assetId == null,
              onTap: () => Navigator.pop(context, 'rename'),
            ),
            ListTile(
              leading: const Icon(Icons.check_box_outlined),
              title: const Text('多选'),
              onTap: () => Navigator.pop(context, 'select'),
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('删除'),
              enabled: item.assetId == null,
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (action == 'select') {
      setState(() => _selected.add(item.pathHash));
      return;
    }
    if (action == 'delete') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('删除文件'),
          content: Text('确定删除 "${item.name}"？\n此操作不可撤销。'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除')),
          ],
        ),
      );
      if (confirm == true) {
        try {
          await LocalVideoService().delete(item);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已删除: ${item.name}')));
            _scan();
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('删除失败: $e')));
          }
        }
      }
      return;
    }
    if (action == 'rescrape') {
      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const AlertDialog(
            content: Row(children: [CircularProgressIndicator(), SizedBox(width: 16), Text('正在刮削...')]),
          ),
        );
        final m = await ScrapeService.scrapeFile(
          item.pathHash, item.name,
          parentDir: item.relativePath,
          mediaTypeHint: widget.source.config['mediaType'],
        );
        if (!mounted) return;
        Navigator.pop(context);
        if (m != null) {
          await ScrapeService.saveCache(item.pathHash, m);
          await ScrapeMediaStore.save(item, m);
          ref.read(localVideoProvider.notifier).addScrapedEntry(item.pathHash, m);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('刮削成功：${m.title}')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('未在 TMDB 找到匹配')));
        }
        setState(() {});
      } catch (e) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('刮削失败: $e')));
        }
      }
      return;
    }
    if (action == 'autoRename' && s != null) {
      try {
        await LocalVideoService().renameByScraped(item, s);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('重命名成功')));
          _scan();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('重命名失败: $e')));
        }
      }
    } else if (action == 'rename') {
      if (!mounted) return;
      final ctrl = TextEditingController(text: item.name);
      final ext = item.path.contains('.') ? item.path.substring(item.path.lastIndexOf('.')) : '';
      final newName = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('重命名'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(hintText: '新文件名（不含扩展名）')),
              const SizedBox(height: 12),
              ValueListenableBuilder(
                valueListenable: ctrl,
                builder: (_, __, ___) => Text(
                  '预览: ${ctrl.text.trim()}$ext',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
            TextButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('确定')),
          ],
        ),
      );
      if (newName != null && newName.isNotEmpty) {
        try {
          final parent = item.path.substring(0, item.path.lastIndexOf('/'));
          final target = '$parent/$newName$ext';
          if (await File(target).exists() && target != item.path) {
            if (!mounted) return;
            final overwrite = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('文件已存在'),
                content: Text('$newName$ext 已存在，是否覆盖？'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
                  TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('覆盖')),
                ],
              ),
            );
            if (overwrite != true) return;
          }
          await LocalVideoService().renameFile(item, newName);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('重命名成功')));
            _scan();
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('重命名失败: $e')));
          }
        }
      }
    }
  }
}

/// 单部剧的剧集列表页
class _SeriesEpisodePage extends StatelessWidget {
  const _SeriesEpisodePage({required this.seriesName, required this.episodes, required this.onMenu});
  final String seriesName;
  final List<LocalVideoItem> episodes;
  final void Function(String action) onMenu;

  @override
  Widget build(BuildContext context) {
    final sorted = [...episodes]..sort((a, b) => a.name.compareTo(b.name));
    return Scaffold(
      appBar: AppBar(
        title: Text(seriesName),
        actions: [
          PopupMenuButton<String>(
            onSelected: onMenu,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'scrape', child: Row(children: [Icon(Icons.search, size: 18), SizedBox(width: 8), Text('刮削本剧')])),
              PopupMenuItem(value: 'renameAll', child: Row(children: [Icon(Icons.auto_fix_high, size: 18, color: Colors.green), SizedBox(width: 8), Text('一键重命名集数')])),
              PopupMenuItem(value: 'organize', child: Row(children: [Icon(Icons.folder_special, size: 18), SizedBox(width: 8), Text('整理文件结构')])),
              PopupMenuItem(value: 'renameFolder', child: Row(children: [Icon(Icons.drive_file_rename_outline, size: 18), SizedBox(width: 8), Text('重命名文件夹')])),
            ],
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: sorted.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final it = sorted[i];
          return ListTile(
            leading: Text('${i + 1}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            title: Text(it.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: const Icon(Icons.play_arrow),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<Widget>(builder: (_) => LocalPlayPage(items: sorted, initialIndex: i),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HelpItem extends StatelessWidget {
  final String title;
  final String desc;
  const _HelpItem(this.title, this.desc);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 2),
          Text(desc, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        ],
      ),
    );
  }
}
