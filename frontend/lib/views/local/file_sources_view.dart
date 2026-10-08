import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/file_source.dart';
import '../../providers/file_sources_provider.dart';
import '../../providers/local_video_provider.dart';
import '../../services/scrape_media_store.dart';
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

  /// 本地文件夹源副标题：优先多文件夹 paths，回退单 path
  String _dirSubtitle(FileSource s) {
    final paths = <String>[];
    final raw = s.config['paths'];
    if (raw != null && raw.isNotEmpty) {
      paths.addAll(raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty));
    }
    final old = s.config['path'];
    if (old != null && old.isNotEmpty && !paths.contains(old)) paths.add(old);
    if (paths.isEmpty) return '';
    return paths.join(', ');
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
                        MaterialPageRoute<Widget>(builder: (_) => FileSourceBrowseView(source: s),
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
                        ? _dirSubtitle(s)
                        : s.type == FileSourceType.webdav
                            ? s.config['url'] ?? ''
                            : '${s.config['host'] ?? ''}:${s.config['port'] ?? '445'}'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              // 启用/禁用开关（本地源也允许切换，用于临时隐藏手机相册）
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    value: s.enabled,
                    onChanged: (_) {
                      ref.read(fileSourcesProvider.notifier).toggleEnabled(s.id);
                      ref.read(localVideoProvider.notifier).refresh();
                    },
                  ),
                  // 所有源都有菜单；local_default 不可删
                  PopupMenuButton<String>(
                      onSelected: (v) async {
                        if (v == 'edit') {
                          if (s.type == FileSourceType.localDir) {
                            // 重新选目录
                            final path = await Navigator.push<String>(
                              context,
                              MaterialPageRoute<String>(builder: (_) => LocalDirectoryBrowserView(
                                  pickMode: true,
                                  initialPath: s.config['path'] ?? '',
                                ),
                              ),
                            );
                            if (path != null) {
                              // 同步更新 path 和 paths（多文件夹）
                              final paths = <String>[];
                              final raw = s.config['paths'];
                              if (raw != null && raw.isNotEmpty) {
                                paths.addAll(raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty));
                              }
                              if (!paths.contains(path)) paths.add(path);
                              ref.read(fileSourcesProvider.notifier).update(
                                    s.copyWith(config: {
                                      ...s.config,
                                      'path': path,
                                      'paths': paths.join(','),
                                    }),
                                  );
                              if (context.mounted) {
                                ref.read(localVideoProvider.notifier).refresh();
                              }
                            }
                          } else if (s.type != FileSourceType.local) {
                            Navigator.push(
                              context,
                              MaterialPageRoute<Widget>(builder: (_) => FileSourceEditView(existing: s),
                              ),
                            );
                          }
                        } else if (v == 'rescan') {
                          if (s.type == FileSourceType.local) {
                            ref.read(localVideoProvider.notifier).refresh();
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute<Widget>(builder: (_) => FileSourceBrowseView(source: s),
                              ),
                            );
                          }
                        } else if (v == 'rename') {
                          final ctrl = TextEditingController(text: s.name);
                          final newName = await showDialog<String>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('重命名媒体库'),
                              content: TextField(
                                controller: ctrl,
                                autofocus: true,
                                decoration: const InputDecoration(hintText: '输入新名称'),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('取消'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, ctrl.text.trim()),
                                  child: const Text('确定'),
                                ),
                              ],
                            ),
                          );
                          if (newName != null && newName.isNotEmpty) {
                            ref.read(fileSourcesProvider.notifier).update(
                                  s.copyWith(name: newName),
                                );
                          }
                        } else if (v == 'addfolder') {
                          // 添加另一个文件夹到此媒体库（多文件夹挂载）
                          final path = await Navigator.push<String>(
                            context,
                            MaterialPageRoute<String>(builder: (_) => const LocalDirectoryBrowserView(pickMode: true),
                            ),
                          );
                          if (path != null) {
                            final paths = <String>[];
                            final raw = s.config['paths'];
                            if (raw != null && raw.isNotEmpty) {
                              paths.addAll(raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty));
                            }
                            final old = s.config['path'];
                            if (old != null && old.isNotEmpty && !paths.contains(old)) {
                              paths.add(old);
                            }
                            if (!paths.contains(path)) paths.add(path);
                            ref.read(fileSourcesProvider.notifier).update(
                                  s.copyWith(config: {...s.config, 'paths': paths.join(',')}),
                                );
                            // 自动重扫媒体库
                            if (context.mounted) {
                              ref.read(localVideoProvider.notifier).refresh();
                            }
                          }
                        } else if (v == 'scrape') {
                          // 刮削此文件夹：打开浏览页自动触发刮削
                          if (context.mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute<Widget>(builder: (_) => FileSourceBrowseView(source: s),
                              ),
                            );
                          }
                        } else if (v == 'delete') {
                          _confirmDelete(context, ref, s);
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'rescan', child: Text(s.type == FileSourceType.local ? '重新扫描' : '进入浏览/重扫')),
                        if (s.type == FileSourceType.localDir)
                          const PopupMenuItem(value: 'addfolder', child: Text('添加文件夹到此媒体库')),
                        const PopupMenuItem(value: 'rename', child: Text('重命名媒体库')),
                        const PopupMenuItem(value: 'scrape', child: Text('刮削此媒体库')),
                        if (s.type != FileSourceType.local)
                          const PopupMenuItem(value: 'edit', child: Text('编辑/换目录')),
                        if (s.id != 'local_default')
                          const PopupMenuItem(value: 'delete', child: Text('删除')),
                      ],
                    ),
                ],
              ),
            ),
            // 挂载路径列表（多文件夹）
            Builder(builder: (_) {
              final paths = <String>[];
              final raw = s.config['paths'];
              if (raw != null && raw.isNotEmpty) {
                paths.addAll(raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty));
              }
              final old = s.config['path'];
              if (old != null && old.isNotEmpty && !paths.contains(old)) paths.add(old);
              if (paths.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final p in paths)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            Icon(Icons.folder, size: 12, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                p,
                                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            }),
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
    showDialog<Widget>(context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除文件源'),
        content: Text('确定删除「${s.name}」？\n该源下的影片将从媒体库移除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              // 清理该源下视频的刮削缓存
              try {
                final videos = ref.read(localVideoProvider).items;
                for (final v in videos) {
                  if (v.sourceId == s.id) {
                    try { await ScrapeMediaStore.delete(v); } catch (e) { debugPrint('删除元数据失败 ${v.name}: $e'); }
                  }
                }
              } catch (e) { debugPrint('清理源元数据失败: $e'); }
              ref.read(fileSourcesProvider.notifier).remove(s.id);
              ref.read(localVideoProvider.notifier).refresh();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// 选择媒体类型：电影 / 电视剧 / 短视频
  Future<String?> _showMediaTypeDialog(BuildContext context) {
    return showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('选择媒体类型'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'movie'),
            child: const ListTile(
              leading: Icon(Icons.movie, color: Colors.blue),
              title: Text('电影'),
              subtitle: Text('单个影片，按年份刮削'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'tv'),
            child: const ListTile(
              leading: Icon(Icons.tv, color: Colors.green),
              title: Text('电视剧'),
              subtitle: Text('按剧名+集数刮削，支持 01/02/03 编号'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'short'),
            child: const ListTile(
              leading: Icon(Icons.videocam, color: Colors.orange),
              title: Text('短视频'),
              subtitle: Text('不刮削，按文件名显示'),
            ),
          ),
        ],
      ),
    );
  }

  /// 输入媒体库名称
  Future<String?> _showNameDialog(BuildContext context, String defaultName) {
    final ctrl = TextEditingController(text: defaultName);
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('媒体库名称'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '例如：我的电影、收藏剧集',
          ),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text),
            child: const Text('确定'),
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
                  MaterialPageRoute<String>(builder: (_) => const LocalDirectoryBrowserView(pickMode: true),
                  ),
                );
                if (path == null || !context.mounted) return;
                // 选媒体类型
                if (!context.mounted) return;
                final mediaType = await _showMediaTypeDialog(context);
                if (mediaType == null || !context.mounted) return;
                // 输入媒体库名称
                if (!context.mounted) return;
                final defaultName = path.split('/').last;
                final name = await _showNameDialog(context, defaultName);
                if (name == null || !context.mounted) return;
                ref.read(fileSourcesProvider.notifier).add(FileSource(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      type: FileSourceType.localDir,
                      name: name.trim().isEmpty ? (defaultName.isEmpty ? '手机文件夹' : defaultName) : name.trim(),
                      config: {'path': path, 'mediaType': mediaType},
                    ));
                if (context.mounted) {
                  ref.read(localVideoProvider.notifier).refresh();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.lan),
              title: const Text('SMB 共享'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute<Widget>(builder: (_) => const FileSourceEditView(type: FileSourceType.smb),
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
                  MaterialPageRoute<Widget>(builder: (_) => const FileSourceEditView(type: FileSourceType.webdav),
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
