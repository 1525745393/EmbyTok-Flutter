// 数据备份与恢复页（PRD #29）
//
// - 收藏导出 JSON / 导入 JSON
// - 歌单导出 M3U / 导入 M3U（智能匹配 NAS 音乐库）

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/audio_models.dart';
import '../providers/synology_music_provider.dart';
import '../services/data_backup_service.dart';

class DataBackupView extends ConsumerWidget {
  const DataBackupView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final svc = DataBackupService.instance;
    final music = ref.watch(synologyMusicProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('备份与恢复')),
      body: SafeArea(
        child: ListView(
          children: [
            const _SectionTitle('收藏歌曲'),
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: const Text('导出收藏'),
              subtitle: Text('将 ${music.pins.length} 首收藏导出为 JSON 备份'),
              onTap: () async {
                final json = await svc.exportFavoritesJson(music.pins);
                await svc.shareTextFile('embytok_favorites.json', json);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已生成收藏备份文件')),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.download_for_offline),
              title: const Text('导入收藏'),
              subtitle: const Text('从 JSON 备份文件恢复收藏'),
              onTap: () => _importFavorites(context, ref, svc),
            ),
            const Divider(),
            const _SectionTitle('歌单（M3U）'),
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: const Text('导出歌单'),
              subtitle: Text('选择一个歌单导出为 M3U（共 ${music.playlists.length} 个）'),
              onTap: music.playlists.isEmpty
                  ? null
                  : () => _exportPlaylist(context, ref, svc),
            ),
            ListTile(
              leading: const Icon(Icons.download_for_offline),
              title: const Text('导入歌单'),
              subtitle: const Text('选择 .m3u / .m3u8 文件导入'),
              onTap: () => _importPlaylist(context, ref, svc),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportPlaylist(
      BuildContext context, WidgetRef ref, DataBackupService svc) async {
    final music = ref.read(synologyMusicProvider);
    AudioPlaylist? picked = await showModalBottomSheet<AudioPlaylist>(
      context: context,
      builder: (_) => ListView(
        children: music.playlists
            .map((p) => ListTile(
                  title: Text(p.name),
                  onTap: () => Navigator.pop(context, p),
                ))
            .toList(),
      ),
    );
    if (picked == null) return;
    try {
      final songs = await ref
          .read(synologyMusicProvider.notifier)
          .loadPlaylistSongs(picked.id);
      final m3u = svc.buildM3U(picked.name, songs);
      final safeName = picked.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      await svc.shareTextFile('$safeName.m3u', m3u);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已导出 ${songs.length} 首到 M3U')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('导出失败：$e')));
      }
    }
  }

  Future<void> _importFavorites(
      BuildContext context, WidgetRef ref, DataBackupService svc) async {
    final content = await svc.pickTextFile(['json']);
    if (content == null) return;
    final items = svc.parseFavoritesJson(content);
    if (items.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('文件格式错误或无收藏')));
      }
      return;
    }
    if (context.mounted) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('导入结果'),
          content: Text('解析到 ${items.length} 首收藏记录。\n\n'
              'songId: ${items.map((e) => e['title']).join('、')}\n\n'
              '提示：恢复需服务端 API 配合，当前先完成解析与预览。'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('关闭')),
          ],
        ),
      );
    }
  }

  Future<void> _importPlaylist(
      BuildContext context, WidgetRef ref, DataBackupService svc) async {
    final content = await svc.pickTextFile(['m3u', 'm3u8']);
    if (content == null) return;
    final entries = svc.parseM3U(content);
    if (entries.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('文件中没有歌曲')));
      }
      return;
    }
    final library = ref.read(synologyMusicProvider).songs;
    final matched = svc.matchSongs(entries, library);
    final ok = matched.where((e) => e != null).length;
    final unmatched = <String>[];
    for (var i = 0; i < entries.length; i++) {
      if (matched[i] == null) unmatched.add(entries[i].title);
    }
    if (context.mounted) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('导入匹配结果'),
          content: SingleChildScrollView(
            child: Text(
              '共 ${entries.length} 首\n成功匹配 $ok 首\n未匹配 ${unmatched.length} 首'
              '${unmatched.isNotEmpty ? '\n\n未匹配：\n${unmatched.take(20).join('\n')}' : ''}',
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('关闭')),
          ],
        ),
      );
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child:
          Text(text, style: const TextStyle(fontSize: 13, color: Colors.grey)),
    );
  }
}
