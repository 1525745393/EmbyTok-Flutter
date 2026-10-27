// 设置页面辅助组件
// 从 settings_view.dart 分离，提升代码可维护性

part of '../settings_view.dart';

// ==================== 智能缓存清理开关 ====================

/// 智能缓存清理开关（batch39-F2）
///
/// 独立 StatefulWidget 持有 Future——原实现（settings_view.dart 的
/// StatefulBuilder）每次 rebuild 都在 builder 内新建
/// `SharedPreferences.getInstance().then(...)`，开关切换触发 rebuild 后
/// future 进入 pending、`?? true` 兜底闪回开启再回落，视觉抖动且重复读 prefs。
/// 此处 future 在 initState 创建一次；切换时用 `Future.value` 替换避免 pending 窗口。
/// 开关值由 MemoryPressureHandler（batch39-F1）消费。
class _SmartCacheTile extends StatefulWidget {
  const _SmartCacheTile({super.key});

  @override
  State<_SmartCacheTile> createState() => _SmartCacheTileState();
}

class _SmartCacheTileState extends State<_SmartCacheTile> {
  late Future<bool> _enabledFuture;

  @override
  void initState() {
    super.initState();
    _enabledFuture = SharedPreferences.getInstance()
        .then((p) => p.getBool('smart_cache_cleanup') ?? true);
  }

  Future<void> _toggle(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('smart_cache_cleanup', v);
    setState(() => _enabledFuture = Future.value(v));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _enabledFuture,
      builder: (context, snapshot) {
        final enabled = snapshot.data ?? true;
        return SwitchListTile(
          secondary: const Icon(Icons.memory, color: Colors.teal),
          title: const Text('智能缓存清理'),
          subtitle: const Text('内存不足时自动清理图片和视频缓存'),
          value: enabled,
          onChanged: _toggle,
        );
      },
    );
  }
}

// ==================== 手势项组件 ====================

class _GestureItem extends StatelessWidget {
  const _GestureItem({
    required this.icon,
    required this.title,
    required this.description,
  });
  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, color: scheme.primary, size: _kGestureItemIconSize),
        const SizedBox(width: _kGestureItemIconSpacing),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: _kFontSizeSmall,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ==================== 通用选项对话框 ====================

class _OptionDialog<T> extends StatelessWidget {
  const _OptionDialog({
    required this.title,
    required this.options,
    required this.currentValue,
    required this.onSelect,
  });
  final String title;
  final List<(String label, T value)> options;
  final T currentValue;
  final ValueChanged<T> onSelect;

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
            title: Text(
              opt.$1,
              style: TextStyle(
                color: selected ? scheme.primary : scheme.onSurface,
                fontSize: _kFontSizeLarge,
              ),
            ),
            trailing:
                selected ? Icon(Icons.check, color: scheme.primary) : null,
            onTap: () {
              // 使用对话框自身的context关闭，避免依赖外层context
              Navigator.pop(context);
              onSelect(opt.$2);
            },
          );
        }).toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(_kDialogCloseLabel,
              style: TextStyle(color: scheme.onSurfaceVariant)),
        ),
      ],
    );
  }
}

// ==================== 语言设置 tile（batch41-F1） ====================

/// 语言设置 tile（batch41-F1）
///
/// 原实现（settings_builders.dart）缺陷：RadioGroup groupValue 硬编码
/// `'system'`（不反映当前语言）；onChanged 仅弹 SnackBar，从不调用
/// `AppLocale.save()`——选择被丢弃；且 app.dart 的 `locale: null` 从不消费
/// `AppLocale.load()`，语言设置整体无效。
/// 修复：独立 StatefulWidget 在 initState 读取当前语言（AppLocale.load），
/// 选择后 AppLocale.save/clear 持久化；app.dart 启动时加载并作为
/// MaterialApp.locale，重启后按保存值显示。
class _LanguageTile extends StatefulWidget {
  const _LanguageTile({super.key});

  @override
  State<_LanguageTile> createState() => _LanguageTileState();
}

class _LanguageTileState extends State<_LanguageTile> {
  Locale? _current;

  @override
  void initState() {
    super.initState();
    AppLocale.load().then((l) {
      if (mounted) setState(() => _current = l);
    });
  }

  String _subtitle() {
    final c = _current;
    if (c == null) return '跟随系统';
    if (c.languageCode == 'zh') return '简体中文';
    if (c.languageCode == 'en') return 'English';
    return '跟随系统';
  }

  Future<void> _openDialog() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('选择语言'),
        content: RadioGroup<String>(
          // groupValue 由当前已保存语言决定，不再硬编码 'system'
          groupValue: _current == null ? 'system' : _current!.languageCode,
          onChanged: (v) => Navigator.pop(dialogContext, v),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              RadioListTile<String>(
                title: Text('跟随系统'),
                value: 'system',
              ),
              RadioListTile<String>(
                title: Text('简体中文'),
                value: 'zh',
              ),
              RadioListTile<String>(
                title: Text('English'),
                value: 'en',
              ),
            ],
          ),
        ),
      ),
    );
    if (selected == null || !mounted) return;

    final Locale? next;
    final String msg;
    switch (selected) {
      case 'zh':
        next = const Locale('zh', 'CN');
        msg = '已选择简体中文（重启后生效）';
      case 'en':
        next = const Locale('en', 'US');
        msg = 'English selected (restart to apply)';
      default:
        next = null;
        msg = '将跟随系统语言（重启后生效）';
    }
    // 持久化选择：'system' 清除保存值（恢复跟随系统），zh/en 写 AppLocale.save
    if (next == null) {
      await AppLocale.clear();
    } else {
      await AppLocale.save(next);
    }
    if (!mounted) return;
    setState(() => _current = next);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return settingsTapTile(
      icon: Icons.language_outlined,
      iconColor: Colors.indigo,
      title: '语言',
      subtitle: _subtitle(),
      onTap: _openDialog,
      helpText: '选择 App 显示语言。\n\n· 跟随系统 → 使用设备默认语言\n· 简体中文 → 始终中文\n· English → 始终英文\n\n切换后重启 App 生效。',
    );
  }
}

// ==================== 歌手元数据缓存 tile（batch41-F5） ====================

/// 歌手元数据缓存 tile（batch41-F5）
///
/// 原实现（settings_builders.dart）在 build 中新建
/// `ref.read(artistMetadataServiceProvider).getCacheSize()` future——每次
/// rebuild（切分组/返回页面/其他开关）都回 pending 再 resolve，缓存大小闪回
/// 且重复执行本地统计。修复：future 在 initState 创建一次；清除缓存成功后
/// 手动重建 future 刷新大小。
class _ArtistMetadataCacheTile extends ConsumerStatefulWidget {
  const _ArtistMetadataCacheTile({super.key});

  @override
  ConsumerState<_ArtistMetadataCacheTile> createState() =>
      _ArtistMetadataCacheTileState();
}

class _ArtistMetadataCacheTileState
    extends ConsumerState<_ArtistMetadataCacheTile> {
  late Future<int> _sizeFuture;

  @override
  void initState() {
    super.initState();
    _sizeFuture = ref.read(artistMetadataServiceProvider).getCacheSize();
  }

  Future<void> _clear() async {
    final cleared =
        await _showClearArtistMetadataDialog(context, ref);
    if (cleared && mounted) {
      // 清除成功后重建 future，刷新显示的大小
      setState(() => _sizeFuture =
          ref.read(artistMetadataServiceProvider).getCacheSize());
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: _sizeFuture,
      builder: (context, snapshot) {
        final size = snapshot.data ?? 0;
        return settingsTapTile(
          icon: Icons.person_outline,
          iconColor: Colors.purple,
          title: '歌手元数据缓存',
          subtitle: '简介/头像缓存 ${formatBytes(size)}，点击清除',
          onTap: _clear,
          helpText:
              '管理艺术家/歌手元数据缓存（头像、简介等）。\n\n· 查看缓存条目数\n· 清理缓存后，歌手详情将从数据源重新拉取\n\n适用于音乐服务模式。',
        );
      },
    );
  }
}
