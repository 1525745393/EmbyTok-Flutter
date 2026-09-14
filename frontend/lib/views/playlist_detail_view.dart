// 歌单详情页（PRD #21）
//
// 展示歌单内歌曲，支持播放全部、删歌、清空。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/audio_models.dart';
import '../providers/playlists_provider.dart';
import '../providers/synology_playback_provider.dart';

class PlaylistDetailView extends ConsumerWidget {
  const PlaylistDetailView({required this.playlistId, super.key});
  final String playlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(playlistsProvider);
    final pl = list.where((p) => p.id == playlistId).firstOrNull;
    if (pl == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('歌单')),
        body: const Center(child: Text('歌单不存在或已删除')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(pl.name),
        actions: [
          if (pl.songs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: '清空歌单',
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('清空歌单'),
                    content: const Text('确定清空歌单内全部歌曲？'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('取消')),
                      TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('清空')),
                    ],
                  ),
                );
                if (ok == true) {
                  await ref
                      .read(playlistsProvider.notifier)
                      .clearSongs(pl.id);
                }
              },
            ),
        ],
      ),
      floatingActionButton: pl.songs.isEmpty
          ? null
          : FloatingActionButton.extended(
              icon: const Icon(Icons.play_arrow),
              label: Text('播放全部 (${pl.songs.length})'),
              onPressed: () => ref
                  .read(synologyPlaybackProvider.notifier)
                  .playQueue(pl.songs, 0),
            ),
      body: pl.songs.isEmpty
          ? const Center(
              child: Text('歌单为空，去歌曲列表把歌曲加入歌单',
                  style: TextStyle(color: Colors.grey)))
          : ListView.separated(
              itemCount: pl.songs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final AudioSong s = pl.songs[i];
                return ListTile(
                  title: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(s.artistDisplay,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    tooltip: '移出歌单',
                    onPressed: () => ref
                        .read(playlistsProvider.notifier)
                        .removeSong(pl.id, s.id),
                  ),
                  onTap: () => ref
                      .read(synologyPlaybackProvider.notifier)
                      .playQueue(pl.songs, i),
                );
              },
            ),
    );
  }
}
