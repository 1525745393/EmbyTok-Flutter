part of '../settings_view.dart';

// 从 settings_view.dart 拆分（part 文件，无行为变化）

class _SettingEntry {
  const _SettingEntry({
    required this.title,
    required this.section,
    required this.keywords,
    required this.onTap,
  });
  final String title;
  final String section;
  final String keywords;
  final void Function(BuildContext context) onTap;

  /// 判断该入口是否匹配搜索词（标题、分组、关键词任一命中即可）
  bool matches(String query) {
    final q = query.toLowerCase();
    return title.toLowerCase().contains(q) ||
        section.toLowerCase().contains(q) ||
        keywords.toLowerCase().contains(q);
  }
}

/// 设置搜索底部表单：实时过滤设置项，点击后执行对应操作并关闭
class _SettingsSearchSheet extends StatefulWidget {
  const _SettingsSearchSheet({required this.entries});
  final List<_SettingEntry> entries;

  @override
  State<_SettingsSearchSheet> createState() => _SettingsSearchSheetState();
}

class _SettingsSearchSheetState extends State<_SettingsSearchSheet> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<_SettingEntry> get _filtered {
    if (_query.isEmpty) return widget.entries;
    return widget.entries.where((e) => e.matches(_query)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final results = _filtered;
    // 设置为屏幕高度的 70%，确保 Expanded 有明确的高度约束
    final sheetHeight = MediaQuery.of(context).size.height * 0.7;
    return SizedBox(
      height: sheetHeight,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          children: [
            // 搜索框
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: TextField(
                controller: _controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '搜索设置项…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _controller.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: scheme.outline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: scheme.primary, width: 2),
                  ),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            // 搜索结果列表
            Expanded(
              child: results.isEmpty
                  ? Center(
                      child: Text(
                        '未找到匹配的设置项',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    )
                  : ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final entry = results[index];
                        return ListTile(
                          leading: Icon(Icons.settings_outlined,
                              color: scheme.primary),
                          title: Text(entry.title),
                          subtitle: Text(
                            entry.section,
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: _kFontSizeSmall,
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.pop(context);
                            entry.onTap(context);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
