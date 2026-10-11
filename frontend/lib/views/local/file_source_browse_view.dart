import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  List<LocalVideoItem> _items = [];
  Map<String, ScrapedMedia> _scraped = {};
  bool _loading = true;
  String? _error;
  bool _scraping = false;
  int _scrapedCount = 0;

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
            success++;
          } else {
            await ScrapeMediaStore.recordHistory(
              videoPath: item.path, status: 'failed', error: '未找到匹配结果', sessionId: sessionId);
            await ScrapeMediaStore.moveToFailed(item.path);
          }
          } catch (e) {
            debugPrint('刮削失败 ${item.name}: $e');
            await ScrapeMediaStore.recordHistory(
              videoPath: item.path, status: 'failed', error: e.toString(), sessionId: sessionId);
            await ScrapeMediaStore.moveToFailed(item.path);
          }
      }));
      i += concurrency;
      if (!mounted) return;
      setState(() => _scrapedCount = i > _items.length ? _items.length : i);
    }
    if (mounted) {
      final cache = await ScrapeService.loadCache();
      if (!mounted) return;
      setState(() {
        _scraped = cache;
        _scraping = false;
      });
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
          IconButton(onPressed: _scan, icon: const Icon(Icons.refresh)),
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
        ],
      ),
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
    final hasTvPattern = _items.any((it) =>
        RegExp(r'[Ss]\d{1,2}[._ -]?[Ee]\d{1,2}').hasMatch(it.name));
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
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final entry in groups.entries)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
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
                  ],
                ),
                children: entry.value.map((it) {
                  final realIndex = _items.indexOf(it);
                  return _buildItemTile(it, realIndex < 0 ? 0 : realIndex);
                }).toList(),
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
    }
  }

  /// 刮削某部剧的所有集（TMDB 只搜一次）
  Future<void> _scrapeGroup(String seriesName, List<LocalVideoItem> eps) async {
    setState(() {
      _scraping = true;
      _scrapedCount = 0;
    });
    // 第一步：按剧名搜一次 TMDB
    ScrapedMedia? base;
    try {
      base = await ScrapeService.scrapeTvSeries(seriesName);
    } catch (e) { debugPrint('剧集刮削失败 $seriesName: $e'); }
    if (base == null) {
      if (mounted) {
        setState(() => _scraping = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('未在 TMDB 找到该剧')));
      }
      return;
    }
    // 第二步：给每集叠加季集号 + 拉取单集详情（标题/简介/剧照），并存缓存
    int done = 0;
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
        // 写每集视频旁 .nfo/-poster.jpg
        await ScrapeMediaStore.save(item, media);
      } catch (e) { debugPrint('单集元数据保存失败 ${item.name}: $e'); }
      if (!mounted) return;
      setState(() => _scrapedCount = ++done);
    }
    final cache = await ScrapeService.loadCache();
    if (!mounted) return;
    setState(() {
      _scraped = cache;
      _scraping = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('刮削完成：$done 集共享《${base.title}》元数据')));
    }
  }

  /// 一键重命名某部剧的所有集为 "剧名 S01E01.ext"
  Future<void> _renameAllEpisodes(String seriesName, List<LocalVideoItem> eps) async {
    int ok = 0;
    int fail = 0;
    for (final item in eps) {
      try {
        final s = _scraped[item.pathHash];
        if (s != null) {
          await LocalVideoService().renameByScraped(item, s);
        } else {
          // 没有刮削数据，从文件名提取 SxxExx
          final m = RegExp(r'[Ss](\d{1,2})[._ -]?[Ee](\d{1,2})').firstMatch(item.name);
          if (m != null) {
            final se = 'S${m.group(1)!.padLeft(2, '0')}E${m.group(2)!.padLeft(2, '0')}';
            final safe = seriesName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '').trim();
            await LocalVideoService().renameFile(item, '$safe $se');
          }
        }
        ok++;
      } catch (_) {
        fail++;
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('重命名完成：成功 $ok，失败 $fail')));
      _scan();
    }
  }

  /// 整理文件结构：把扁平集数移动到 Season X 子文件夹
  /// 如 西游记/S01E01.mp4 → 西游记/Season 1/S01E01.mp4
  Future<void> _organizeStructure(String seriesName, List<LocalVideoItem> eps) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('整理文件结构'),
        content: Text('将按 SxxEyy 把集数移动到对应 "Season X" 子文件夹。\n\n例：$seriesName/S01E01.mp4 → $seriesName/Season 1/S01E01.mp4\n\n是否继续？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('开始整理')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    int ok = 0, fail = 0;
    for (final item in eps) {
      try {
        final m = RegExp(r'[Ss](\d{1,2})[._ -]?[Ee](\d{1,2})').firstMatch(item.name);
        if (m == null) continue;
        final season = int.tryParse(m.group(1)!) ?? 1;
        final parent = item.path.substring(0, item.path.lastIndexOf('/'));
        // 已在 Season X 子文件夹里就跳过，避免重复嵌套
        if (RegExp(r'[\/\\][Ss]eason\s*\d+$', caseSensitive: false).hasMatch(parent)) continue;
        final seasonDir = Directory('$parent/Season $season');
        if (!await seasonDir.exists()) await seasonDir.create(recursive: true);
        // item.name 不含扩展名，需从原 path 拼回
        final dot = item.path.lastIndexOf('.');
        final ext = dot > 0 ? item.path.substring(dot) : '';
        final newPath = '$parent/Season $season/${item.name}$ext';
        if (!await File(newPath).exists()) {
          await File(item.path).rename(newPath);
          ok++;
        }
      } catch (_) {
        fail++;
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('整理完成：移动 $ok 个文件，失败 $fail')));
      _scan();
    }
  }

  Future<void> _renameFolder(String oldName, String dirPath) async {
    final ctrl = TextEditingController(text: oldName);
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('重命名剧集文件夹'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: '输入新文件夹名'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('确定')),
        ],
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
      await Directory(dirPath).rename(newPath);
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

  Widget _buildItemTile(LocalVideoItem item, int index) {
    final s = _scraped[item.pathHash];
    return ListTile(
      leading: SizedBox(
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
      title: Text(s?.title ?? item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(s?.year != null ? '${s!.year} · ${item.sizeLabel}' : item.sizeLabel),
      trailing: const Icon(Icons.play_arrow, size: 20),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<Widget>(builder: (_) => LocalPlayPage(items: _items, initialIndex: index),
        ),
      ),
      onLongPress: () => _showLongPressMenu(item),
    );
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
              leading: const Icon(Icons.drive_file_rename_outline),
              title: const Text('手动重命名'),
              subtitle: Text(item.name, maxLines: 1),
              enabled: item.assetId == null,
              onTap: () => Navigator.pop(context, 'rename'),
            ),
          ],
        ),
      ),
    );
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
      final newName = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('重命名'),
          content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(hintText: '新文件名')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
            TextButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('确定')),
          ],
        ),
      );
      if (newName != null && newName.isNotEmpty) {
        try {
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
