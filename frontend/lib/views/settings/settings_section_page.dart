import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 设置分组二级页面
///
/// 主设置页只显示分组入口列表，点击后跳转到本页面展示该分组的所有设置项。
class SettingsSectionPage extends ConsumerWidget {
  const SettingsSectionPage({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.childrenBuilder,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> Function(BuildContext context, WidgetRef ref)
      childrenBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
            0, 12, 0, 12 + MediaQuery.paddingOf(context).bottom),
        children: [
          // 分组标题卡片
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 该分组下的所有设置项
          ...childrenBuilder(context, ref),
        ],
      ),
    );
  }
}
