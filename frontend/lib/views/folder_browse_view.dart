// 文件夹浏览页面（PRD：快捷入口 → 文件夹）
//
// 按目录结构浏览 NAS 音乐文件，支持递归进入子文件夹，点击歌曲播放。
// SYNO.AudioStation.Folder API 返回 folders + songs 混合列表。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/audio_models.dart';
import '../providers/synology_auth_provider.dart';
import '../providers/synology_playback_provider.dart';
import '../services/synology_audio_api.dart';

class FolderBrowseView extends ConsumerStatefulWidget {
  /// 初始文件夹路径，null 表示根目录
  final String? initialPath;

  const FolderBrowseView({super.key, this.initialPath});

  @override
  ConsumerState<FolderBrowseView> createState() => _FolderBrowseViewState();
}

class _FolderBrowseViewState extends ConsumerState<FolderBrowseView> {
  /// 当前文件夹路径栈（用于返回上一级）
  final List<String> _pathStack = [];
  List<AudioFolderItem> _items = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialPath != null && widget.initialPath!.isNotEmpty) {
      _pathStack.add(widget.initialPath!);
    }
    _loadFolder();
  }

  String get _currentPath =>
      _pathStack.isEmpty ? '' : _pathStack.last;

  String get _displayPath =>
      _pathStack.isEmpty ? '根目录' : _pathStack.last.split('/').last;

  Future<void> _loadFolder() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final api = ref.read(synologyAuthProvider.notifier).api;
      final items = await api.getFolders(folderPath: _currentPath.isEmpty ? null : _currentPath);
      if (!mounted) return;
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _openFolder(AudioFolderItem item) {
    _pathStack.add(item.path);
    _loadFolder();
  }

  void _goBack() {
    if (_pathStack.isNotEmpty) {
      _pathStack.removeLast();
      _loadFolder();
    } else {
      context.go('/');
    }
  }

  void _playSong(AudioSong song) {
    // 播放当前文件夹中的所有歌曲，从选中的歌曲开始
    final songs = _items
        .where((i) => i.type == AudioFolderItemType.song && i.song != null)
        .map((i) => i.song!)
        .toList();
    final index = songs.indexWhere((s) => s.id == song.id);
    if (songs.isNotEmpty) {
      ref
          .read(synologyPlaybackProvider.notifier)
          .playQueue(songs, index >= 0 ? index : 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_displayPath),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBack,
        ),
        actions: [
          // 播放当前文件夹全部歌曲
          if (_items.any((i) => i.type == AudioFolderItemType.song))
            IconButton(
              icon: const Icon(Icons.play_circle_outline),
              tooltip: '播放全部',
              onPressed: () {
                final songs = _items
                    .where((i) =>
                        i.type == AudioFolderItemType.song && i.song != null)
                    .map((i) => i.song!)
                    .toList();
                if (songs.isNotEmpty) {
                  ref
                      .read(synologyPlaybackProvider.notifier)
                      .playQueue(songs, 0);
                }
              },
            ),
        ],
      ),
      body: _buildBody(scheme),
    );
  }

  Widget _buildBody(ColorScheme scheme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: scheme.error),
            const SizedBox(height: 12),
            Text('加载失败：$_error',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadFolder,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open, size: 48, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('此文件夹为空',
                style: TextStyle(color: scheme.onSurfaceVariant)),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        if (item.type == AudioFolderItemType.folder) {
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: scheme.primaryContainer,
              child: Icon(Icons.folder,
                  color: scheme.onPrimaryContainer, size: 22),
            ),
            title: Text(item.name,
                maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openFolder(item),
          );
        } else {
          final song = item.song!;
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: scheme.secondaryContainer,
              child: Icon(Icons.music_note,
                  color: scheme.onSecondaryContainer, size: 20),
            ),
            title: Text(song.title,
                maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              song.artistDisplay,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: song.durationText.isNotEmpty
                ? Text(song.durationText,
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant))
                : null,
            onTap: () => _playSong(song),
          );
        }
      },
    );
  }
}
