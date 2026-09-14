// 下载管理页（PRD #19）
//
// 两个 Tab：
// - 下载中：进行/等待/失败任务，进度条、取消、重试
// - 已下载：本地歌曲列表，点击离线播放、批量删除
// 顶部存储空间条。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/audio_models.dart';
import '../providers/download_provider.dart';
import '../providers/synology_playback_provider.dart';
import '../services/synology_download_service.dart';

class DownloadsView extends ConsumerStatefulWidget {
  const DownloadsView({super.key});

  @override
  ConsumerState<DownloadsView> createState() => _DownloadsViewState();
}

class _DownloadsViewState extends ConsumerState<DownloadsView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // 已下载批量选择
  final Set<String> _selected = {};
  bool _batchMode = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(downloadProvider);
    final activeCount = state.tasks
        .where((t) =>
            t.status == DownloadStatus.downloading ||
            t.status == DownloadStatus.waiting ||
            t.status == DownloadStatus.paused ||
            t.status == DownloadStatus.failed)
        .length;
    final downloadedCount = state.downloaded.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(_batchMode ? '已选 ${_selected.length} 项' : '下载管理'),
        leading: _batchMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  _batchMode = false;
                  _selected.clear();
                }),
              )
            : null,
        actions: [
          if (_batchMode)
            TextButton(
              onPressed: () {
                final all = state.downloaded.keys.toSet();
                if (_selected.length == all.length) {
                  setState(() => _selected.clear());
                } else {
                  setState(() => _selected.addAll(all));
                }
              },
              child: const Text('全选', style: TextStyle(color: Colors.white)),
            ),
          if (_batchMode)
            TextButton(
              onPressed: () async {
                for (final id in _selected) {
                  await ref.read(downloadProvider.notifier).deleteDownloaded(id);
                }
                if (mounted) {
                  setState(() {
                    _batchMode = false;
                    _selected.clear();
                  });
                }
              },
              child: const Text('删除', style: TextStyle(color: Colors.red)),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: '下载中 ($activeCount)'),
            Tab(text: '已下载 ($downloadedCount)'),
          ],
        ),
      ),
      body: Column(
        children: [
          _StorageBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _DownloadingTab(),
                _DownloadedTab(
                  batchMode: _batchMode,
                  selected: _selected,
                  onTapItem: (songId) {
                    setState(() {
                      if (_selected.contains(songId)) {
                        _selected.remove(songId);
                        if (_selected.isEmpty) _batchMode = false;
                      } else {
                        _selected.add(songId);
                      }
                    });
                  },
                  onLongPress: (songId) {
                    setState(() {
                      _batchMode = true;
                      _selected.add(songId);
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _fmtSize(num bytes) {
  if (bytes <= 0) return '0 MB';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
  return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
}

/// 存储空间条
class _StorageBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final used = ref.watch(downloadProvider).downloaded.values.fold<int>(
          0,
          (sum, s) => sum + s.fileSize,
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('已下载占用',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text(_fmtSize(used),
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: used <= 0 ? 0 : (used / (1024 * 1024 * 100)).clamp(0.0, 1.0),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}

class _DownloadingTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(downloadProvider);
    final tasks = state.tasks
        .where((t) =>
            t.status == DownloadStatus.downloading ||
            t.status == DownloadStatus.waiting ||
            t.status == DownloadStatus.paused ||
            t.status == DownloadStatus.failed)
        .toList();

    if (tasks.isEmpty) {
      return const Center(child: Text('暂无下载任务'));
    }

    return ListView.separated(
      itemCount: tasks.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final t = tasks[i];
        final pct = (t.progress * 100).toStringAsFixed(0);
        return ListTile(
          leading: const Icon(Icons.music_note, size: 40),
          title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: t.status == DownloadStatus.downloading ? t.progress : null,
              ),
              const SizedBox(height: 2),
              Text(
                t.status == DownloadStatus.failed
                    ? '失败：${t.errorMessage ?? "重试"}'
                    : t.status == DownloadStatus.paused
                        ? '已暂停 · $pct%'
                        : t.status == DownloadStatus.waiting
                            ? '等待中 · $pct%'
                            : '$pct% · ${_fmtSize(t.downloadedBytes)}/${_fmtSize(t.totalBytes)}',
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
          trailing: t.status == DownloadStatus.failed
              ? IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.orange),
                  onPressed: () =>
                      ref.read(downloadProvider.notifier).retry(t.songId),
                )
              : IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.grey),
                  onPressed: () =>
                      ref.read(downloadProvider.notifier).cancel(t.songId),
                ),
        );
      },
    );
  }
}

class _DownloadedTab extends ConsumerWidget {
  const _DownloadedTab({
    required this.batchMode,
    required this.selected,
    required this.onTapItem,
    required this.onLongPress,
  });

  final bool batchMode;
  final Set<String> selected;
  final void Function(String songId) onTapItem;
  final void Function(String songId) onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(downloadProvider);
    final songs = state.downloaded.values.toList()
      ..sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt));

    if (songs.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.download_done, size: 56, color: Colors.grey),
            SizedBox(height: 12),
            Text('还没有下载歌曲'),
            SizedBox(height: 4),
            Text('在播放页下载喜欢的歌曲离线听',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: songs.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final s = songs[i];
        final isSelected = selected.contains(s.songId);
        return ListTile(
          leading: batchMode
              ? Icon(
                  isSelected
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey,
                )
              : const Icon(Icons.music_note, size: 40),
          title: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            '${s.artist} · ${_fmtSize(s.fileSize)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
          trailing: batchMode
              ? null
              : IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.grey),
                  onPressed: () => ref
                      .read(downloadProvider.notifier)
                      .deleteDownloaded(s.songId),
                ),
          onLongPress: () => onLongPress(s.songId),
          onTap: () {
            if (batchMode) {
              onTapItem(s.songId);
            } else {
              final song = AudioSong(
                id: s.songId,
                title: s.title,
                tag: AudioSongTag(artist: s.artist),
              );
              ref.read(synologyPlaybackProvider.notifier).playQueue([song], 0);
            }
          },
        );
      },
    );
  }
}
