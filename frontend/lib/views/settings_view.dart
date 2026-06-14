// 设置页面：主题、默认倍速、字幕、缓存、用户信息、退出登录

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/app_preferences.dart';

class SettingsView extends ConsumerWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final defaultRate = ref.watch(defaultPlaybackRateProvider);
    final defaultSubtitle = ref.watch(defaultSubtitleLanguageProvider);
    final auth = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Row(
          children: const [
            Icon(Icons.settings, color: Color(0xFFFF5983), size: 24),
            SizedBox(width: 8),
            Text('设置'),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _sectionTitle('外观'),
          _settingTile(
            icon: Icons.dark_mode_outlined,
            title: '主题',
            subtitle: _themeLabel(themeMode),
            onTap: () => _showThemeDialog(context, ref, themeMode),
          ),
          _settingTile(
            icon: Icons.tv_outlined,
            title: '设备模式',
            subtitle: _deviceModeLabel(ref.watch(deviceModeProvider)),
            onTap: () => _showDeviceModeDialog(context, ref),
          ),

          _sectionTitle('视频浏览'),
          _settingTile(
            icon: Icons.filter_list_outlined,
            title: '浏览模式',
            subtitle: _feedTypeLabel(ref.watch(feedTypeProvider)),
            onTap: () => _showFeedTypeDialog(context, ref),
          ),
          _settingTile(
            icon: Icons.video_settings_outlined,
            title: '视图模式',
            subtitle: _viewModeLabel(ref.watch(viewModeProvider)),
            onTap: () => _showViewModeDialog(context, ref),
          ),
          _settingTile(
            icon: Icons.crop_rotate,
            title: '方向过滤',
            subtitle: _orientationModeLabel(ref.watch(orientationModeProvider)),
            onTap: () => _showOrientationModeDialog(context, ref),
          ),

          _sectionTitle('播放'),
          _settingTile(
            icon: Icons.speed_outlined,
            title: '默认倍速',
            subtitle: '${defaultRate.toStringAsFixed(1)}x',
            onTap: () => _showPlaybackRateDialog(context, ref, defaultRate),
          ),

          _sectionTitle('字幕'),
          _settingTile(
            icon: Icons.closed_caption_outlined,
            title: '默认字幕语言',
            subtitle: defaultSubtitle.isEmpty ? '关闭' : defaultSubtitle,
            onTap: () => _showSubtitleDialog(context, ref, defaultSubtitle),
          ),

          _sectionTitle('存储'),
          _settingTile(
            icon: Icons.cleaning_services_outlined,
            title: '清除缓存',
            subtitle: '${_formatSize(ref.watch(cacheSizeProvider))}',
            onTap: () => _showClearCacheDialog(context, ref),
          ),

          _sectionTitle('账户'),
          _profileTile(auth),
          _logoutTile(context, ref),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Text(title,
            style: const TextStyle(
              color: Colors.white54,
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
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFFFF5983), size: 24),
      title: Text(title,
          style: const TextStyle(color: Colors.white, fontSize: 15)),
      subtitle: Text(subtitle,
          style: const TextStyle(color: Colors.white54, fontSize: 13)),
      trailing: const Icon(Icons.chevron_right, color: Colors.white38),
      onTap: onTap,
      tileColor: Colors.white10,
    );
  }

  Widget _profileTile(AuthState auth) {
    final name = auth.user?.name ?? '未登录';
    return ListTile(
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: const Color(0xFFE91E63),
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      title: Text(name,
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
      subtitle: Text(auth.backendUrl ?? '未连接服务器',
          style: const TextStyle(color: Colors.white54, fontSize: 12)),
      tileColor: Colors.white10,
    );
  }

  Widget _logoutTile(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.logout, color: Colors.white),
          label: const Text('退出登录',
              style: TextStyle(color: Colors.white, fontSize: 16)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
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

  // ---- 设备模式 ----
  void _showDeviceModeDialog(BuildContext context, WidgetRef ref) {
    final current = ref.read(deviceModeProvider);
    showDialog<void>(
      context: context,
      builder: (_) => _OptionDialog<DeviceMode>(
        title: '设备模式',
        options: const [
          ('标准模式（手机/平板）', DeviceMode.standard),
          ('TV 模式（大屏/遥控器）', DeviceMode.tv),
        ],
        currentValue: current,
        onSelect: (v) {
          ref.read(deviceModeProvider.notifier).setMode(v);
          Navigator.pop(context);
        },
      ),
    );
  }

  // ---- 浏览模式 ----
  void _showFeedTypeDialog(BuildContext context, WidgetRef ref) {
    final current = ref.read(feedTypeProvider);
    showDialog<void>(
      context: context,
      builder: (_) => _OptionDialog<FeedType>(
        title: '浏览模式',
        options: const [
          ('最新视频（按时间排序）', FeedType.latest),
          ('随机推荐', FeedType.random),
          ('收藏夹', FeedType.favorites),
        ],
        currentValue: current,
        onSelect: (v) {
          ref.read(feedTypeProvider.notifier).setType(v);
          Navigator.pop(context);
        },
      ),
    );
  }

  // ---- 视图模式 ----
  void _showViewModeDialog(BuildContext context, WidgetRef ref) {
    final current = ref.read(viewModeProvider);
    showDialog<void>(
      context: context,
      builder: (_) => _OptionDialog<ViewMode>(
        title: '视图模式',
        options: const [
          ('视频流（上下滑动）', ViewMode.feed),
          ('网格视图', ViewMode.grid),
        ],
        currentValue: current,
        onSelect: (v) {
          ref.read(viewModeProvider.notifier).setMode(v);
          Navigator.pop(context);
        },
      ),
    );
  }

  // ---- 方向过滤 ----
  void _showOrientationModeDialog(BuildContext context, WidgetRef ref) {
    final current = ref.read(orientationModeProvider);
    showDialog<void>(
      context: context,
      builder: (_) => _OptionDialog<OrientationMode>(
        title: '方向过滤',
        options: const [
          ('全部视频', OrientationMode.both),
          ('仅竖屏（短视频）', OrientationMode.vertical),
          ('仅横屏（电影/剧集）', OrientationMode.horizontal),
        ],
        currentValue: current,
        onSelect: (v) {
          ref.read(orientationModeProvider.notifier).setMode(v);
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
          ref.read(defaultPlaybackRateProvider.notifier).set(v as double);
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
          ref.read(defaultSubtitleLanguageProvider.notifier).set(v as String);
          Navigator.pop(context);
        },
      ),
    );
  }

  // ---- 清除缓存 ----
  void _showClearCacheDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('清除缓存',
            style: TextStyle(color: Colors.white)),
        content: const Text('确定要清除全部缓存吗？这将删除临时下载的缩略图和字幕文件。',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(cacheSizeProvider.notifier).clear();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('缓存已清除'),
                    backgroundColor: Colors.green),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('清除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ---- 退出登录 ----
  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('退出登录', style: TextStyle(color: Colors.white)),
        content: const Text('确定要退出当前账号吗？',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(authProvider.notifier).logout();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('退出', style: TextStyle(color: Colors.white)),
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

  static String _deviceModeLabel(DeviceMode mode) {
    switch (mode) {
      case DeviceMode.tv:
        return 'TV 模式';
      case DeviceMode.standard:
        return '标准模式';
    }
  }

  static String _feedTypeLabel(FeedType type) {
    switch (type) {
      case FeedType.latest:
        return '最新视频';
      case FeedType.random:
        return '随机推荐';
      case FeedType.favorites:
        return '收藏夹';
    }
  }

  static String _viewModeLabel(ViewMode mode) {
    switch (mode) {
      case ViewMode.feed:
        return '视频流';
      case ViewMode.grid:
        return '网格视图';
    }
  }

  static String _orientationModeLabel(OrientationMode mode) {
    switch (mode) {
      case OrientationMode.vertical:
        return '仅竖屏';
      case OrientationMode.horizontal:
        return '仅横屏';
      case OrientationMode.both:
        return '全部';
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
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      title: Text(title, style: const TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: options.map((opt) {
          final selected = opt.$2 == currentValue;
          return ListTile(
            title: Text(opt.$1,
                style: TextStyle(
                    color: selected ? const Color(0xFFFF5983) : Colors.white,
                    fontSize: 15)),
            trailing: selected
                ? const Icon(Icons.check, color: Color(0xFFFF5983))
                : null,
            onTap: () => onSelect(opt.$2),
          );
        }).toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭', style: TextStyle(color: Colors.white70)),
        ),
      ],
    );
  }
}
