import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/file_source.dart';
import '../../models/local_video_item.dart';
import '../../providers/file_sources_provider.dart';
import '../../services/local_dir_scanner.dart';
import '../../services/local_video_service.dart';
import '../../services/scrape_service.dart';
import '../../services/smb_scanner.dart';
import '../../services/tmdb_service.dart';
import '../../services/webdav_scanner.dart';
import 'local_player_page.dart';

/// 源内浏览页（P1 第三批 + P0 增强）
///
/// 根据源类型选择扫描器：WebDAV 走 PROPFIND，SMB 走连通性测试+文件列表。
class FileSourceBrowseView extends ConsumerStatefulWidget {
  final FileSource source;
  const FileSourceBrowseView({super.key, required this.source});

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
          items = [];
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
    } catch (e) {
      if (mounted) {
        ref
            .read(fileSourcesProvider.notifier)
            .updateScanStatus(widget.source.id, FileSourceStatus.failed);
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  /// 对当前列表中未刮削的视频调用 TMDB 刮削
  Future<void> _scrapeAll() async {
    if (_items.isEmpty || _scraping) return;
    setState(() {
      _scraping = true;
      _scrapedCount = 0;
    });
    for (final item in _items) {
      try {
        final pathHash = item.pathHash;
        // parentDir 传完整父目录路径，extractSeriesName 自动跳过 Season 文件夹
        await ScrapeService.scrapeFile(
          pathHash,
          item.name,
          parentDir: item.relativePath,
          mediaTypeHint: widget.source.config['mediaType'],
        );
      } catch (_) {}
      if (!mounted) return;
      setState(() => _scrapedCount++);
    }
    if (mounted) {
      final cache = await ScrapeService.loadCache();
      setState(() {
        _scraped = cache;
        _scraping = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('刮削完成：共 $_scrapedCount 个视频')),
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

  Set<String> _expandedFolders = {};

  Widget _buildBody() {
    final isTv = widget.source.config['mediaType'] == 'tv';
    // TV 类型按文件夹分组
    if (isTv) {
      // 同时记录文件夹完整路径，用于重命名
      final groups = <String, List<LocalVideoItem>>{};
      final groupDir = <String, String>{};
      for (final it in _items) {
        final parent = it.relativePath ?? '';
        final folder = parent.isEmpty
            ? '未分组'
            : parent.split('/').where((s) => s.isNotEmpty).last;
        groups.putIfAbsent(folder, () => []).add(it);
        groupDir[folder] = parent;
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
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.drive_file_rename_outline, size: 18),
                      tooltip: '重命名文件夹',
                      onPressed: () => _renameFolder(entry.key, groupDir[entry.key] ?? ''),
                    ),
                    const Icon(Icons.keyboard_arrow_down),
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
    try {
      final newPath = dirPath.substring(0, dirPath.lastIndexOf('/')) + '/$newName';
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
        MaterialPageRoute(
          builder: (_) => LocalPlayerPage(items: _items, initialIndex: index),
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
