import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/file_source.dart';
import '../../providers/file_sources_provider.dart';
import 'file_source_browse_view.dart';
import 'file_source_edit_view.dart';
import 'local_directory_browser_view.dart';

/// 文件源列表页（P0 第二批 + P0 增强）
///
/// 参考 VidHub：本地/SMB/WebDAV 源卡片，支持启用/禁用、重扫、编辑、删除。
class FileSourcesView extends ConsumerWidget {
  const FileSourcesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sources = ref.watch(fileSourcesProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('文件源'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTypeDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('添加文件源'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: sources.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) => _buildSourceCard(context, ref, sources[i], scheme),
      ),
    );
  }

  Widget _buildSourceCard(
    BuildContext context,
    WidgetRef ref,
    FileSource s,
    ColorScheme scheme,
  ) {
    final isLocal = s.type == FileSourceType.local;
    // 禁用的源整体变暗
    final opacity = s.enabled ? 1.0 : 0.45;
    return Opacity(
      opacity: opacity,
      child: Card(
        child: Column(
          children: [
            ListTile(
              onTap: s.type == FileSourceType.local || !s.enabled
                  ? null
                  : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FileSourceBrowseView(source: s),
                        ),
                      ),
              leading: Icon(
                switch (s.type) {
                  FileSourceType.local => Icons.phone_iphone,
                  FileSourceType.localDir => Icons.folder,
                  FileSourceType.smb => Icons.lan,
                  FileSourceType.webdav => Icons.cloud_outlined,
                },
                color: scheme.primary,
                size: 28,
              ),
              title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                isLocal
                    ? '手机媒体库'
                    : (s.type == FileSourceType.localDir
                        ? s.config['path'] ?? ''
                        : s.type == FileSourceType.webdav
                            ? s.config['url'] ?? ''
                            : '${s.config['host'] ?? ''}:${s.config['port'] ?? '445'}'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              // 启用/禁用开关（本地源也允许切换，用于临时隐藏手机相册）
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    value: s.enabled,
                    onChanged: (_) =>
                        ref.read(fileSourcesProvider.notifier).toggleEnabled(s.id),
                  ),
                  // local_default（手机媒体库）不显示菜单，其他源都有
                  if (s.id != 'local_default')
                    PopupMenuButton<String>(
                      onSelected: (v) async {
                        if (v == 'edit') {
                          if (s.type == FileSourceType.localDir) {
                            // 重新选目录
                            final path = await Navigator.push<String>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LocalDirectoryBrowserView(
                                  pickMode: true,
                                  initialPath: s.config['path'] as String? ?? '',
                                ),
                              ),
                            );
                            if (path != null) {
                              ref.read(fileSourcesProvider.notifier).update(
                                    s.copyWith(config: {...s.config, 'path': path}),
                                  );
                            }
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => FileSourceEditView(existing: s),
                              ),
                            );
                          }
                        } else if (v == 'rescan') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FileSourceBrowseView(source: s),
                            ),
                          );
                        } else if (v == 'scrape') {
                          // 刮削此文件夹：打开浏览页自动触发刮削
                          if (context.mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => FileSourceBrowseView(source: s),
                              ),
                            );
                          }
                        } else if (v == 'delete') {
                          _confirmDelete(context, ref, s);
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'rescan', child: Text('重新扫描')),
                        const PopupMenuItem(value: 'scrape', child: Text('刮削此文件夹')),
                        const PopupMenuItem(value: 'edit', child: Text('编辑/换目录')),
                        const PopupMenuItem(value: 'delete', child: Text('删除')),
                      ],
                    ),
                ],
              ),
            ),
            // 底部信息行：视频数 + 上次扫描时间
            if (s.videoCount > 0 || s.lastScanAt != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Icon(Icons.movie_outlined, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text('${s.videoCount} 个视频',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    const SizedBox(width: 12),
                    if (s.lastScanAt != null) ...[
                      Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '${s.lastScanAt!.month}/${s.lastScanAt!.day} ${s.lastScanAt!.hour}:${s.lastScanAt!.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, FileSource s) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除文件源'),
        content: Text('确定删除「${s.name}」？\n该源下的影片将从媒体库移除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              ref.read(fileSourcesProvider.notifier).remove(s.id);
              Navigator.pop(context);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAddTypeDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 手机文件夹：用文件浏览器选目录
            ListTile(
              leading: const Icon(Icons.folder),
              title: const Text('手机文件夹'),
              subtitle: const Text('浏览手机本地目录并加入媒体库'),
              onTap: () async {
                Navigator.pop(context);
                final path = await Navigator.push<String>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LocalDirectoryBrowserView(pickMode: true),
                  ),
                );
                if (path == null || !context.mounted) return;
                final name = path.split('/').last;
                ref.read(fileSourcesProvider.notifier).add(FileSource(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      type: FileSourceType.localDir,
                      name: name.isEmpty ? '手机文件夹' : name,
                      config: {'path': path},
                    ));
              },
            ),
            ListTile(
              leading: const Icon(Icons.lan),
              title: const Text('SMB 共享'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const FileSourceEditView(type: FileSourceType.smb),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.cloud_outlined),
              title: const Text('WebDAV'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const FileSourceEditView(type: FileSourceType.webdav),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
