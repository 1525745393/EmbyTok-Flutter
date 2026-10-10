// 本地媒体库设置：文件源管理、扫描、TMDB API Key、清除刮削缓存、退出本地模式
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../providers/file_sources_provider.dart';
import '../../providers/local_mode_provider.dart';
import '../../providers/local_video_provider.dart';
import '../../services/local_video_service.dart';
import '../../services/scrape_service.dart';
import '../../services/scrape_media_store.dart';
import '../../services/tmdb_service.dart';
import '../../utils/logger.dart';
import 'file_sources_view.dart';

class LocalLibrarySettingsPage extends ConsumerWidget {
  const LocalLibrarySettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sources = ref.watch(fileSourcesProvider);
    final enabledCount = sources.where((s) => s.enabled).length;
    final totalVideos = sources.fold<int>(0, (sum, s) => sum + s.videoCount);

    return Scaffold(
      appBar: AppBar(title: const Text('本地媒体库')),
      body: ListView(
        children: [
          const _SectionTitle('文件源'),
          ListTile(
            leading: const Icon(Icons.folder_special_outlined, color: Colors.purple),
            title: const Text('文件源管理'),
            subtitle: Text('$enabledCount 个启用源 · $totalVideos 个视频'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FileSourcesView()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.refresh, color: Colors.blue),
            title: const Text('立即扫描'),
            subtitle: const Text('重新扫描所有启用的文件源'),
            onTap: () => _scanNow(context, ref),
          ),
          const Divider(),
          const _SectionTitle('刮削'),
          ListTile(
            leading: const Icon(Icons.key, color: Colors.blue),
            title: const Text('TMDB API Key'),
            subtitle: const Text('配置自己的 TMDB key（留空使用内置演示 key）'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _editTmdbKey(context),
          ),
          ListTile(
            leading: const Icon(Icons.cloud_download, color: Colors.purple),
            title: const Text('清除刮削缓存'),
            subtitle: const Text('删除 TMDB 元数据、海报、演员头像（不删除视频旁 .nfo）'),
            onTap: () => _clearScrapeCache(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.history, color: Colors.teal),
            title: const Text('刮削记录'),
            subtitle: const Text('查看最近刮削历史与结果'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const _ScrapeHistoryPage()),
            ),
          ),
          const Divider(),
          const _SectionTitle('其他'),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('退出本地模式'),
            subtitle: const Text('返回登录页，连接 Emby 服务器'),
            onTap: () => _exitLocalMode(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _scanNow(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    var hasPerm = await LocalVideoService.hasManageExternalStorage();
    if (!hasPerm) {
      if (!context.mounted) return;
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('需要文件访问权限'),
          content: const Text(
            '刮削后写 .nfo/海报到视频文件夹需要存储权限。\n\n'
            '点击"去开启"后：\n'
            '• 如有"允许管理所有文件"开关 → 打开它\n'
            '• 如没有此开关 → 在应用信息页找"权限"→"文件和媒体"→ 允许访问所有文件',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('去开启')),
          ],
        ),
      );
      if (go == true) {
        await LocalVideoService.requestManageExternalStorage();
        hasPerm = await LocalVideoService.hasManageExternalStorage();
        if (!hasPerm && context.mounted) {
          messenger.showSnackBar(const SnackBar(
            content: Text('未获得存储权限，.nfo 将只写到 App 内部目录'),
            duration: Duration(seconds: 4),
          ));
        }
      } else {
        return;
      }
    }
    if (!context.mounted) return;
    messenger.showSnackBar(const SnackBar(content: Text('开始扫描…')));
    await ref.read(localVideoProvider.notifier).refresh();
    if (context.mounted) {
      messenger.showSnackBar(const SnackBar(content: Text('扫描完成')));
    }
  }

  Future<void> _editTmdbKey(BuildContext context) async {
    final current = await TmdbService.getUserKey();
    if (!context.mounted) return;
    final controller = TextEditingController(text: current ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('TMDB API Key'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '输入自己的 TMDB API key',
            helperText: '留空则恢复使用内置演示 key',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('保存')),
        ],
      ),
    );
    if (result != null) {
      await TmdbService.setUserKey(result);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存')));
      }
    }
  }

  Future<void> _clearScrapeCache(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清除刮削缓存？'),
        content: const Text('将删除 App 内保存的 TMDB 元数据、海报和演员头像。视频旁的 .nfo 文件不会被删除。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('清除')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ScrapeService.clearCache();
      await ScrapeMediaStore.clearCentral();
      await ref.read(localVideoProvider.notifier).refresh();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('刮削缓存已清除')));
      }
    } catch (e) {
      AppLogger.error('清除刮削缓存失败', error: e);
    }
  }

  void _exitLocalMode(BuildContext context, WidgetRef ref) {
    showDialog<Widget>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('退出本地模式'),
        content: const Text('确定退出本地媒体库模式并返回登录页？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () {
              ref.read(localModeProvider.notifier).state = false;
              ref.read(authProvider.notifier).reset();
              Navigator.pop(context);
              context.go('/login');
            },
            child: const Text('退出', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[600]),
      ),
    );
  }
}

class _ScrapeHistoryPage extends StatefulWidget {
  const _ScrapeHistoryPage();

  @override
  State<_ScrapeHistoryPage> createState() => _ScrapeHistoryPageState();
}

class _ScrapeHistoryPageState extends State<_ScrapeHistoryPage> {
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final h = await ScrapeMediaStore.loadHistory();
    if (mounted) setState(() { _history = h; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final success = _history.where((h) => h['status'] == 'success').length;
    final failed = _history.where((h) => h['status'] == 'failed').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('刮削记录'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '清空记录',
            onPressed: () async {
              await ScrapeMediaStore.clearHistory();
              _load();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? const Center(child: Text('暂无刮削记录'))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _statChip('成功 $success', Colors.green),
                          const SizedBox(width: 16),
                          _statChip('失败 $failed', Colors.red),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        itemCount: _history.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final h = _history[i];
                          final ok = h['status'] == 'success';
                          final time = DateTime.tryParse(h['time'] ?? '')?.toString().substring(0, 19) ?? '';
                          return ListTile(
                            leading: Icon(
                              ok ? Icons.check_circle : Icons.error,
                              color: ok ? Colors.green : Colors.red,
                            ),
                            title: Text(h['file'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                              ok ? '${h['title'] ?? ''} (${h['year'] ?? ''})' : (h['error'] ?? '失败'),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Text(time, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _statChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
    );
  }
}
