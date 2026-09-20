// 歌单列表页（PRD #21）
//
// 展示本地歌单，支持新建/重命名/删除/进入详情。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/playlists_provider.dart';

class PlaylistsView extends ConsumerWidget {
  const PlaylistsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的歌单'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '新建歌单',
            onPressed: () => _showCreateDialog(context, ref),
          ),
        ],
      ),
      body: SafeArea(
        child: playlists.isEmpty
            ? const Center(
                child: Text('还没有歌单，点右上角 + 新建',
                    style: TextStyle(color: Colors.grey)))
            : ListView.separated(
                itemCount: playlists.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final pl = playlists[i];
                  return ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.queue_music),
                    ),
                    title: Text(pl.name),
                    subtitle: Text('${pl.songs.length} 首'),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'rename') {
                          _showRenameDialog(context, ref, pl);
                        } else if (v == 'delete') {
                          _confirmDelete(context, ref, pl);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'rename', child: Text('重命名')),
                        PopupMenuItem(value: 'delete', child: Text('删除')),
                      ],
                    ),
                    onTap: () =>
                        context.push('/playlists/detail', extra: pl.id),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
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
      await ref.read(playlistsProvider.notifier).create(ctl.text);
    }
  }

  Future<void> _showRenameDialog(
      BuildContext context, WidgetRef ref, LocalPlaylist pl) async {
    final ctl = TextEditingController(text: pl.name);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('重命名歌单'),
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
              child: const Text('保存')),
        ],
      ),
    );
    if (ok == true && ctl.text.trim().isNotEmpty) {
      await ref.read(playlistsProvider.notifier).rename(pl.id, ctl.text);
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, LocalPlaylist pl) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除歌单'),
        content: Text('删除「${pl.name}」？歌单内歌曲不会从NAS删除。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('删除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(playlistsProvider.notifier).remove(pl.id);
    }
  }
}
