// 个人中心页面（PRD：头像入口 → 个人中心）
//
// 展示：用户信息、NAS 连接状态、媒体库统计、最近播放、设置入口、退出登录

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/recent_playbacks_provider.dart';
import '../providers/synology_auth_provider.dart';
import '../providers/synology_music_provider.dart';
import '../providers/synology_playback_provider.dart';

class ProfileView extends ConsumerWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(synologyAuthProvider);
    final music = ref.watch(synologyMusicProvider);
    final recentPlaybacks = ref.watch(recentPlaybacksProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('个人中心'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 用户信息卡片
          _buildUserCard(auth, scheme),
          const SizedBox(height: 16),
          // 媒体库统计
          _buildStatsCard(music, scheme),
          const SizedBox(height: 16),
          // 最近播放
          if (recentPlaybacks.isNotEmpty) ...[
            _buildSectionTitle('最近播放', scheme),
            const SizedBox(height: 8),
            ...recentPlaybacks.take(5).map((r) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: scheme.primaryContainer,
                    child: Icon(Icons.music_note,
                        size: 18, color: scheme.onPrimaryContainer),
                  ),
                  title: Text(r.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(r.subtitle,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: const Icon(Icons.play_arrow, size: 20),
                  onTap: () {
                    final songs = ref.read(synologyMusicProvider).songs;
                    final match =
                        songs.where((s) => s.id == r.mediaId).toList();
                    if (match.isNotEmpty) {
                      ref
                          .read(synologyPlaybackProvider.notifier)
                          .playQueue(match, 0);
                    }
                  },
                )),
            const SizedBox(height: 16),
          ],
          // 设置入口
          _buildMenuTile(
            icon: Icons.settings,
            title: '设置',
            subtitle: '服务模式、服务器管理、外观',
            onTap: () => context.go('/settings'),
          ),
          // 服务器管理入口
          _buildMenuTile(
            icon: Icons.dns,
            title: '服务器管理',
            subtitle: '添加、编辑、切换媒体服务器',
            onTap: () => context.go('/servers'),
          ),
          const SizedBox(height: 16),
          // 退出登录
          if (auth.isLoggedIn)
            OutlinedButton.icon(
              onPressed: () => _showLogoutConfirm(context, ref),
              icon: const Icon(Icons.logout),
              label: const Text('退出群晖登录'),
              style: OutlinedButton.styleFrom(
                foregroundColor: scheme.error,
                side: BorderSide(color: scheme.error.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUserCard(SynologyAuthState auth, ColorScheme scheme) {
    final account = auth.account ?? '未登录';
    final initial = account.isNotEmpty ? account[0].toUpperCase() : '?';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary.withValues(alpha: 0.15),
            scheme.secondary.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: scheme.primary,
            child: Text(initial,
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: scheme.onPrimary)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(account,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: auth.isLoggedIn
                            ? Colors.greenAccent
                            : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      auth.isLoggedIn ? 'NAS 已连接' : 'NAS 未连接',
                      style: TextStyle(
                          fontSize: 13, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
                if (auth.serverUrl != null) ...[
                  const SizedBox(height: 2),
                  Text(auth.serverUrl!,
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(SynologyMusicState music, ColorScheme scheme) {
    final stats = [
      _StatItem(
          icon: Icons.music_note,
          label: '歌曲',
          value: music.songs.length),
      _StatItem(
          icon: Icons.album, label: '专辑', value: music.albums.length),
      _StatItem(
          icon: Icons.person, label: '歌手', value: music.artists.length),
      _StatItem(icon: Icons.playlist_play,
          label: '歌单',
          value: music.playlists.length),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: stats
            .map((s) => Column(
                  children: [
                    Icon(s.icon, size: 22, color: scheme.primary),
                    const SizedBox(height: 6),
                    Text('${s.value}',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface)),
                    Text(s.label,
                        style: TextStyle(
                            fontSize: 12, color: scheme.onSurfaceVariant)),
                  ],
                ))
            .toList(),
      ),
    );
  }

  Widget _buildSectionTitle(String title, ColorScheme scheme) {
    return Text(title,
        style: TextStyle(
            fontSize: 17, fontWeight: FontWeight.w700, color: scheme.onSurface));
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  void _showLogoutConfirm(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出群晖 Audio Station 登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(synologyAuthProvider.notifier).logout();
              context.go('/login');
            },
            child: Text('退出',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
  }
}

class _StatItem {
  const _StatItem(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final int value;
}
