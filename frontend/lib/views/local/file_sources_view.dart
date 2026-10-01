import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/file_source.dart';
import '../../providers/file_sources_provider.dart';
import 'file_source_edit_view.dart';

/// 文件源列表页（P0 第二批）
///
/// 参考 VidHub：本地/SMB/WebDAV 源卡片，FAB 添加。
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
        onPressed: () => _showAddTypeDialog(context),
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
    return Card(
      child: ListTile(
        leading: Icon(
          switch (s.type) {
            FileSourceType.local => Icons.phone_iphone,
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
              : (s.type == FileSourceType.webdav
                  ? s.config['url'] ?? ''
                  : '${s.config['host'] ?? ''}:${s.config['port'] ?? '445'}'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: isLocal
            ? const Icon(Icons.lock, size: 16, color: Colors.grey)
            : PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FileSourceEditView(existing: s),
                      ),
                    );
                  } else if (v == 'delete') {
                    _confirmDelete(context, ref, s);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('编辑')),
                  PopupMenuItem(value: 'delete', child: Text('删除')),
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
        content: Text('确定删除「${s.name}」？'),
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

  void _showAddTypeDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
