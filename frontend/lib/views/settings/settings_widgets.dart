// 设置页面辅助组件
// 从 settings_view.dart 分离，提升代码可维护性

part of '../settings_view.dart';

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
          child: Text(_kDialogCloseLabel, style: TextStyle(color: scheme.onSurfaceVariant)),
        ),
      ],
    );
  }
}
