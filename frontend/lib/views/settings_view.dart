// 设置页面：主题、默认倍速、字幕、缓存、用户信息、退出登录

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';

class SettingsView extends ConsumerWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final themeMode = ref.watch(themeModeProvider);
    final defaultRate = ref.watch(defaultPlaybackRateProvider);
    final defaultSubtitle = ref.watch(defaultSubtitleLanguageProvider);
    final auth = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        title: Row(
          children: [
            Icon(Icons.settings, color: scheme.primary, size: 24),
            const SizedBox(width: 8),
            const Text('设置'),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _sectionTitle('外观', scheme),
          _settingTile(
            icon: Icons.dark_mode_outlined,
            title: '主题',
            subtitle: _themeLabel(themeMode),
            onTap: () => _showThemeDialog(context, ref, themeMode),
            scheme: scheme,
          ),

          _sectionTitle('播放', scheme),
          _settingTile(
            icon: Icons.speed_outlined,
            title: '默认倍速',
            subtitle: '${defaultRate.toStringAsFixed(1)}x',
            onTap: () => _showPlaybackRateDialog(context, ref, defaultRate),
            scheme: scheme,
          ),

          _sectionTitle('字幕', scheme),
          _settingTile(
            icon: Icons.closed_caption_outlined,
            title: '默认字幕语言',
            subtitle: defaultSubtitle.isEmpty ? '关闭' : defaultSubtitle,
            onTap: () => _showSubtitleDialog(context, ref, defaultSubtitle),
            scheme: scheme,
          ),

          _sectionTitle('存储', scheme),
          _settingTile(
            icon: Icons.cleaning_services_outlined,
            title: '清除缓存',
            subtitle: '${_formatSize(ref.watch(cacheSizeProvider))}',
            onTap: () => _showClearCacheDialog(context, ref),
            scheme: scheme,
          ),

          _sectionTitle('账户', scheme),
          _profileTile(auth, scheme),
          _logoutTile(context, ref, scheme),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, ColorScheme scheme) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Text(title,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            )),
      );

  Widget _settingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required ColorScheme scheme,
  }) {
    return ListTile(
      leading: Icon(icon, color: scheme.primary, size: 24),
      title: Text(title,
          style: TextStyle(color: scheme.onSurface, fontSize: 15)),
      subtitle: Text(subtitle,
          style: TextStyle(
              color: scheme.onSurfaceVariant.withOpacity(0.8), fontSize: 13)),
      trailing: Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
      onTap: onTap,
      tileColor: scheme.onSurface.withOpacity(0.05),
    );
  }

  Widget _profileTile(AuthState auth, ColorScheme scheme) {
    final name = auth.user?.name ?? '未登录';
    return ListTile(
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: scheme.primary,
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
              color: scheme.onPrimary, fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      title: Text(name,
          style: TextStyle(
              color: scheme.onSurface, fontSize: 15, fontWeight: FontWeight.w600)),
      subtitle: Text(auth.backendUrl ?? '未连接服务器',
          style: TextStyle(
              color: scheme.onSurfaceVariant.withOpacity(0.8), fontSize: 12)),
      tileColor: scheme.onSurface.withOpacity(0.05),
    );
  }

  Widget _logoutTile(BuildContext context, WidgetRef ref, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: Icon(Icons.logout, color: scheme.onError),
          label: Text('退出登录',
              style: TextStyle(color: scheme.onError, fontSize: 16)),
          style: ElevatedButton.styleFrom(
            backgroundColor: scheme.error,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () => _showLogoutDialog(context, ref),
        ),
      ),
    );
  }

  // ---- 主题选择 ----
  void _showThemeDialog(BuildContext context, WidgetRef ref, String current) {
    showDialog<void>(
      context: context,
      builder: (_) => _OptionDialog(
        title: '选择主题',
        options: const [
          ('跟随系统', 'system'),
          ('深色', 'dark'),
          ('浅色', 'light'),
        ],
        currentValue: current,
        onSelect: (v) {
          ref.read(themeModeProvider.notifier).setTheme(v);
          Navigator.pop(context);
        },
      ),
    );
  }

  // ---- 倍速选择 ----
  void _showPlaybackRateDialog(
      BuildContext context, WidgetRef ref, double current) {
    showDialog<void>(
      context: context,
      builder: (_) => _OptionDialog(
        title: '默认播放倍速',
        options: const [
          ('0.5x', 0.5),
          ('0.75x', 0.75),
          ('1.0x', 1.0),
          ('1.25x', 1.25),
          ('1.5x', 1.5),
          ('2.0x', 2.0),
        ],
        currentValue: current,
        onSelect: (v) {
          ref.read(defaultPlaybackRateProvider.notifier).set(v);
          Navigator.pop(context);
        },
      ),
    );
  }

  // ---- 默认字幕语言 ----
  void _showSubtitleDialog(
      BuildContext context, WidgetRef ref, String current) {
    showDialog<void>(
      context: context,
      builder: (_) => _OptionDialog(
        title: '默认字幕语言',
        options: const [
          ('关闭', ''),
          ('中文（简体）', 'zh-CN'),
          ('中文（繁体）', 'zh-TW'),
          ('英语', 'en'),
          ('日语', 'ja'),
          ('韩语', 'ko'),
        ],
        currentValue: current,
        onSelect: (v) {
          ref.read(defaultSubtitleLanguageProvider.notifier).set(v);
          Navigator.pop(context);
        },
      ),
    );
  }

  // ---- 清除缓存 ----
  void _showClearCacheDialog(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: scheme.surface,
        title: Text('清除缓存', style: TextStyle(color: scheme.onSurface)),
        content: Text('确定要清除全部缓存吗？这将删除临时下载的缩略图和字幕文件。',
            style: TextStyle(color: scheme.onSurfaceVariant)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消', style: TextStyle(color: scheme.onSurfaceVariant)),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(cacheSizeProvider.notifier).clear();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: const Text('缓存已清除'),
                    backgroundColor: scheme.primary),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: scheme.error),
            child: Text('清除', style: TextStyle(color: scheme.onError)),
          ),
        ],
      ),
    );
  }

  // ---- 退出登录 ----
  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: scheme.surface,
        title: Text('退出登录', style: TextStyle(color: scheme.onSurface)),
        content: Text('确定要退出当前账号吗？',
            style: TextStyle(color: scheme.onSurfaceVariant)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消', style: TextStyle(color: scheme.onSurfaceVariant)),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(authProvider.notifier).logout();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: scheme.error),
            child: Text('退出', style: TextStyle(color: scheme.onError)),
          ),
        ],
      ),
    );
  }

  static String _themeLabel(String mode) {
    switch (mode) {
      case 'dark':
        return '深色';
      case 'light':
        return '浅色';
      case 'system':
      default:
        return '跟随系统';
    }
  }

  static String _formatSize(int bytes) {
    if (bytes <= 0) return '暂无缓存';
    if (bytes < 1024) return '${bytes} B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// 通用选项对话框
class _OptionDialog<T> extends StatelessWidget {
  final String title;
  final List<(String label, T value)> options;
  final T currentValue;
  final void Function(T) onSelect;

  const _OptionDialog({
    required this.title,
    required this.options,
    required this.currentValue,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      backgroundColor: scheme.surface,
      title: Text(title, style: TextStyle(color: scheme.onSurface)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: options.map((opt) {
          final selected = opt.$2 == currentValue;
          return ListTile(
            title: Text(opt.$1,
                style: TextStyle(
                    color: selected ? scheme.primary : scheme.onSurface,
                    fontSize: 15)),
            trailing: selected
                ? Icon(Icons.check, color: scheme.primary)
                : null,
            onTap: () => onSelect(opt.$2),
          );
        }).toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('关闭', style: TextStyle(color: scheme.onSurfaceVariant)),
        ),
      ],
    );
  }
}
