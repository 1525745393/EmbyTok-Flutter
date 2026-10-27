import 'dart:io';
import 'package:flutter/material.dart';

import '../../models/local_video_item.dart';
import 'local_play_page.dart';

/// 取路径最后一段作为文件名（替代 path 包）
String _basename(String path) {
  final i = path.lastIndexOf('/');
  return i < 0 ? path : path.substring(i + 1);
}

/// 取文件名（不含扩展名）
String _basenameWithoutExt(String path) {
  final name = _basename(path);
  final i = name.lastIndexOf('.');
  return i < 0 ? name : name.substring(0, i);
}

/// 取目录名
String _dirname(String path) {
  final i = path.lastIndexOf('/');
  return i <= 0 ? '/' : path.substring(0, i);
}

/// 取扩展名（含点，小写）
String _extOf(String path) {
  final i = path.lastIndexOf('.');
  return i < 0 ? '' : path.substring(i).toLowerCase();
}

/// 手机本地目录浏览页（P0）
///
/// 从根目录 `/storage/emulated/0/` 开始，像文件管理器一样层层进入文件夹，
/// 看到视频文件即可点击播放。对应 VidHub 的"文件"标签页。
class LocalDirectoryBrowserView extends StatefulWidget {
  const LocalDirectoryBrowserView({
    super.key,
    this.initialPath,
    this.pickMode = false,
  });
  final String? initialPath;
  // pickMode=true 时不播放视频，点文件夹会返回路径（用于文件源选择目录）
  final bool pickMode;

  @override
  State<LocalDirectoryBrowserView> createState() =>
      _LocalDirectoryBrowserViewState();
}

class _LocalDirectoryBrowserViewState extends State<LocalDirectoryBrowserView> {
  // Android 外部存储根目录
  static const String _rootPath = '/storage/emulated/0';
  // 视频扩展名
  static const _videoExts = {
    '.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv', '.ts', '.m2ts',
    '.webm', '.m4v', '.mpg', '.mpeg', '.3gp', '.rmvb', '.rm', '.asf',
  };

  String _currentPath = _rootPath;
  List<_DirEntry> _entries = [];
  bool _loading = true;
  String? _error;
  // batch51-F1：列表加载请求序号守卫，快速切换路径时丢弃过期响应
  int _listSeq = 0;

  @override
  void initState() {
    super.initState();
    _currentPath = widget.initialPath ?? _rootPath;
    _listDir();
  }

  Future<void> _listDir() async {
    if (!mounted) return;
    final seq = ++_listSeq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dir = Directory(_currentPath);
      if (!await dir.exists()) {
        if (!mounted || seq != _listSeq) return;
        setState(() {
          _error = '目录不存在: $_currentPath';
          _loading = false;
        });
        return;
      }
      final List<_DirEntry> dirs = [];
      final List<_DirEntry> videos = [];
      // 先收集条目，再分批并发 stat：大目录（千级）不串行阻塞，
      // 单项 stat 失败（无权限/损坏条目）跳过，不拖垮整个列表
      final pending = <(FileSystemEntity, String)>[];
      await for (final entity in dir.list(followLinks: false)) {
        final name = _basename(entity.path);
        if (name.startsWith('.')) continue; // 隐藏目录
        pending.add((entity, name));
      }
      const batchSize = 16; // 对齐项目既有并发批次
      for (var i = 0; i < pending.length; i += batchSize) {
        final batch = pending.skip(i).take(batchSize).toList();
        await Future.wait(batch.map((e) async {
          final (entity, name) = e;
          try {
            final stat = await entity.stat();
            if (stat.type == FileSystemEntityType.directory) {
              dirs.add(_DirEntry(
                name: name,
                path: entity.path,
                isDir: true,
                modifiedAt: stat.modified,
              ));
            } else if (stat.type == FileSystemEntityType.file) {
              if (_videoExts.contains(_extOf(name))) {
                videos.add(_DirEntry(
                  name: name,
                  path: entity.path,
                  isDir: false,
                  sizeBytes: stat.size,
                  modifiedAt: stat.modified,
                ));
              }
            }
          } catch (_) {
            // 单项 stat 失败：跳过该项，不影响其余条目
          }
        }));
      }
      dirs.sort((a, b) => a.name.compareTo(b.name));
      videos.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
      // batch51-F1：过期响应丢弃，避免旧目录内容覆盖当前路径
      if (!mounted || seq != _listSeq) return;
      setState(() {
        _entries = [...dirs, ...videos];
        _loading = false;
      });
    } catch (e) {
      if (!mounted || seq != _listSeq) return;
      setState(() {
        _error = '无法访问目录: $e';
        _loading = false;
      });
    }
  }

  void _openDir(String path) {
    setState(() => _currentPath = path);
    _listDir();
  }

  void _playVideo(_DirEntry entry) {
    // id 必须与 LocalDirScanner 一致（'localdir:<path>'）：同一文件在目录浏览
    // 与媒体库列表播放共用续播/收藏/刮削缓存键，进度与收藏互通
    final item = LocalVideoItem(
      id: 'localdir:${entry.path}',
      name: _basenameWithoutExt(entry.name),
      path: entry.path,
      sizeBytes: entry.sizeBytes ?? 0,
      duration: Duration.zero,
      width: 0,
      height: 0,
      mimeType: 'video/*',
      modifiedAt: entry.modifiedAt,
      isAppDirFile: false, // 共享存储真实路径，与扫描构造一致
      relativePath: _dirname(entry.path),
    );
    Navigator.push(
      context,
      MaterialPageRoute<Widget>(builder: (_) => LocalPlayPage(items: [item]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 面包屑路径段
    final segments = _currentPath.replaceFirst(_rootPath, '').split('/')
      ..removeWhere((s) => s.isEmpty);
    return Scaffold(
      appBar: AppBar(
        title: const Text('浏览文件夹'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(32),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _Crumb(
                    label: '内部存储',
                    onTap: () => _openDir(_rootPath),
                    isCurrent: segments.isEmpty,
                  ),
                  for (var i = 0; i < segments.length; i++) ...[
                    const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                    _Crumb(
                      label: segments[i],
                      onTap: () {
                        final sub = segments.sublist(0, i + 1).join('/');
                        _openDir('$_rootPath/$sub');
                      },
                      isCurrent: i == segments.length - 1,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      body: _buildBody(),
      floatingActionButton: widget.pickMode
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.pop(context, _currentPath),
              icon: const Icon(Icons.check),
              label: const Text('选择此文件夹'),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.folder_off, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _listDir,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    if (_entries.isEmpty) {
      return const Center(
        child: Text('此文件夹为空', style: TextStyle(color: Colors.grey)),
      );
    }
    return ListView.separated(
      itemCount: _entries.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final e = _entries[i];
        return ListTile(
          leading: Icon(
            e.isDir ? Icons.folder : Icons.play_circle_outline,
            color: e.isDir ? Colors.amber : Theme.of(context).colorScheme.primary,
          ),
          title: Text(e.name, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: e.isDir
              ? Text('修改于 ${_fmtDate(e.modifiedAt)}')
              : Text(
                  '${_fmtSize(e.sizeBytes ?? 0)} · ${_fmtDate(e.modifiedAt)}',
                  style: const TextStyle(fontSize: 12),
                ),
          onTap: widget.pickMode
              ? (e.isDir ? () => _openDir(e.path) : null) // 选择目录模式：视频文件不可点（不进播放页）
              : () => e.isDir ? _openDir(e.path) : _playVideo(e),
        );
      },
    );
  }

  static String _fmtDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  static String _fmtSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }
}

class _DirEntry {
  const _DirEntry({
    required this.name,
    required this.path,
    required this.isDir,
    this.sizeBytes,
    required this.modifiedAt,
  });
  final String name;
  final String path;
  final bool isDir;
  final int? sizeBytes;
  final DateTime modifiedAt;
}

class _Crumb extends StatelessWidget {
  const _Crumb({
    required this.label,
    required this.onTap,
    required this.isCurrent,
  });
  final String label;
  final VoidCallback onTap;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          color: isCurrent ? Theme.of(context).colorScheme.primary : Colors.grey,
          fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }
}
