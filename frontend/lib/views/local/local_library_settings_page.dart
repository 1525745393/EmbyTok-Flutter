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
    final hasPerm = await LocalVideoService.hasManageExternalStorage();
    if (!hasPerm) {
      if (!context.mounted) return;
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('需要所有文件访问权限'),
          content: const Text('扫描手机文件夹需要"允许管理所有文件"权限。是否前往开启？'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('去开启')),
          ],
        ),
      );
      if (go == true) {
        await LocalVideoService.requestManageExternalStorage();
      }
      return;
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
