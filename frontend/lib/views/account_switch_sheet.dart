// 多账号切换 Bottom Sheet（PRD #30）
//
// 列出已保存账号，支持：切换、设为默认、添加账号、删除。
// 切换：停止播放 → 用账号密码重新 login → 重载音乐库。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/recent_playbacks_provider.dart';
import '../providers/play_events_provider.dart';
import '../providers/syno_accounts_provider.dart';
import '../providers/synology_auth_provider.dart';
import '../providers/synology_music_provider.dart';
import '../providers/synology_playback_provider.dart';

/// 弹出账号切换 sheet
Future<void> showAccountSwitchSheet(BuildContext context, WidgetRef ref) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const _AccountSheet(),
  );
}

class _AccountSheet extends ConsumerWidget {
  const _AccountSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(synoAccountsProvider);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('切换账号',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          if (state.accounts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('还没有保存的账号，点击下方添加',
                  style: TextStyle(color: Colors.grey)),
            ),
          ...state.accounts.map((a) {
            final isCurrent = a.accountId == state.currentAccountId;
            return ListTile(
              leading: Icon(
                isCurrent ? Icons.check_circle : Icons.person_outline,
                color: isCurrent ? Colors.green : Colors.grey,
              ),
              title: Row(
                children: [
                  Text(a.username),
                  if (a.isDefault)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('默认',
                          style: TextStyle(fontSize: 10, color: Colors.orange)),
                    ),
                ],
              ),
              subtitle: Text(a.serverUrl,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: isCurrent
                  ? const Text('当前',
                      style: TextStyle(color: Colors.green, fontSize: 12))
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.star_border, size: 20),
                          tooltip: '设为默认',
                          onPressed: () => ref
                              .read(synoAccountsProvider.notifier)
                              .setDefault(a.accountId),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          tooltip: '删除',
                          onPressed: () => _confirmDelete(context, ref, a),
                        ),
                      ],
                    ),
              onTap: isCurrent ? null : () => _switchTo(context, ref, a),
            );
          }),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('添加账号'),
            onTap: () => _showAddDialog(context, ref),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _switchTo(
      BuildContext context, WidgetRef ref, SynoAccount a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('切换账号'),
        content: Text('切换到 ${a.username} 将清空当前播放队列，确定？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('切换')),
        ],
      ),
    );
    if (ok != true) return;
    if (!context.mounted) return;

    // 停止播放
    try {
      ref.read(synologyPlaybackProvider.notifier).stop();
    } catch (_) {}

    final pwd =
        await ref.read(synoAccountsProvider.notifier).readPassword(a.accountId);
    if (pwd == null || pwd.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('该账号密码已丢失，请重新添加')));
      }
      return;
    }
    try {
      await ref.read(synologyAuthProvider.notifier).login(
            serverUrl: a.serverUrl,
            account: a.username,
            password: pwd,
          );
      ref.read(synoAccountsProvider.notifier).setCurrent(a.accountId);
      await ref.read(synologyMusicProvider.notifier).loadHomeData(force: true);
      // 按账号隔离：重载该账号的播放历史/统计数据
      await ref.read(recentPlaybacksProvider.notifier).reload();
      await ref.read(playEventsProvider.notifier).reload();
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已切换到 ${a.username}')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('切换失败：$e')));
      }
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, SynoAccount a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除账号'),
        content: Text('删除 ${a.username} 将清除其保存的密码，确定？'),
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
      await ref.read(synoAccountsProvider.notifier).remove(a.accountId);
    }
  }

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    final serverCtl = TextEditingController(
        text: ref.read(synologyAuthProvider).serverUrl ?? '');
    final userCtl = TextEditingController();
    final pwdCtl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('添加账号'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: serverCtl,
                decoration: const InputDecoration(labelText: '服务器地址')),
            TextField(
                controller: userCtl,
                decoration: const InputDecoration(labelText: '用户名')),
            TextField(
                controller: pwdCtl,
                obscureText: true,
                decoration: const InputDecoration(labelText: '密码')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('登录并保存')),
        ],
      ),
    );
    if (ok != true) return;
    if (!context.mounted) return;
    try {
      await ref.read(synologyAuthProvider.notifier).login(
            serverUrl: serverCtl.text.trim(),
            account: userCtl.text.trim(),
            password: pwdCtl.text,
          );
      final account = await ref
          .read(synoAccountsProvider.notifier)
          .addAccount(
            serverUrl: serverCtl.text.trim(),
            username: userCtl.text.trim(),
            password: pwdCtl.text,
          );
      ref.read(synoAccountsProvider.notifier).setCurrent(account.accountId);
      await ref.read(synologyMusicProvider.notifier).loadHomeData(force: true);
      await ref.read(recentPlaybacksProvider.notifier).reload();
      await ref.read(playEventsProvider.notifier).reload();
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('登录失败：$e')));
      }
    }
  }
}
