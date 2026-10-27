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
