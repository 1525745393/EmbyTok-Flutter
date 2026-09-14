// 「添加到歌单」Bottom Sheet
//
// 列出现有歌单，点选即加入；可新建歌单并加入。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/audio_models.dart';
import '../../providers/playlists_provider.dart';

Future<void> showAddToPlaylistSheet(
    BuildContext context, WidgetRef ref, AudioSong song) async {
  await showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _AddSheet(song: song),
  );
}

class _AddSheet extends ConsumerWidget {
  const _AddSheet({required this.song});
  final AudioSong song;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistsProvider);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('添加到歌单',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('新建歌单'),
            onTap: () async {
              final ctl = TextEditingController();
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('新建歌单'),
                  content: TextField(
                    controller: ctl,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: '歌单名称'),
                  ),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('取消')),
                    TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('创建')),
                  ],
                ),
              );
              if (ok == true && ctl.text.trim().isNotEmpty) {
                final pl = await ref
                    .read(playlistsProvider.notifier)
                    .create(ctl.text);
                await ref
                    .read(playlistsProvider.notifier)
                    .addSong(pl.id, song);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('已加入「${pl.name}」')));
                }
              }
            },
          ),
          const Divider(),
          if (playlists.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('还没有歌单，先新建一个',
                  style: TextStyle(color: Colors.grey)),
            ),
          ...playlists.map((pl) {
            final already = pl.songs.any((s) => s.id == song.id);
            return ListTile(
              leading: const Icon(Icons.queue_music),
              title: Text(pl.name),
              subtitle: Text(already ? '已在歌单中' : '${pl.songs.length} 首'),
              trailing: already
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: already
                  ? null
                  : () async {
                      await ref
                          .read(playlistsProvider.notifier)
                          .addSong(pl.id, song);
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('已加入「${pl.name}」')));
                      }
                    },
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
