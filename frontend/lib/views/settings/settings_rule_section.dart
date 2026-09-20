part of '../settings_view.dart';

// 从 settings_view.dart 拆分（part 文件，无行为变化）

class _RuleSection extends StatefulWidget {
  const _RuleSection({
    required this.icon,
    required this.title,
    required this.childrenBuilder,
    this.initiallyExpanded = false,
  });

  final IconData icon;
  final String title;
  final List<Widget> Function() childrenBuilder;
  final bool initiallyExpanded;

  @override
  State<_RuleSection> createState() => _RuleSectionState();
}

class _RuleSectionState extends State<_RuleSection> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 12, 6),
            child: Row(
              children: [
                Icon(widget.icon, size: 16, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: _kFontSizeSmall,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        if (_expanded) ...widget.childrenBuilder(),
        settingsRuleSectionDivider(scheme),
      ],
    );
  }
}

// ==================== 设置搜索 ====================

/// 单个可搜索的设置入口
