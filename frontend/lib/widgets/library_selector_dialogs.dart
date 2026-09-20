// 从 library_selector.dart 拆分（part 文件，无行为变化）

part of 'library_selector.dart';

// ==================== 类型筛选弹窗 ====================

class _FavoriteTypeFilterDialog extends ConsumerStatefulWidget {
  const _FavoriteTypeFilterDialog({required this.scheme});

  final ColorScheme scheme;

  @override
  ConsumerState<_FavoriteTypeFilterDialog> createState() =>
      _FavoriteTypeFilterDialogState();
}

class _FavoriteTypeFilterDialogState
    extends ConsumerState<_FavoriteTypeFilterDialog> {
  Map<String, int> _counts = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    try {
      final authState = ref.read(authProvider);
      if (authState.embyServerUrl == null || authState.token == null) {
        setState(() => _loading = false);
        return;
      }
      final service = ref.read(embytokServiceProvider);
      final userId = authState.user?.id;
      final counts = await service.getFavoriteCounts(
        serverUrl: authState.embyServerUrl,
        token: authState.token,
        userId: userId,
      );
      if (mounted) {
        setState(() {
          _counts = counts;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedTypes = ref.watch(favoriteIncludeTypesProvider);
    const availableTypes = [
      {'code': 'Movie', 'name': '影片', 'icon': Icons.movie},
      {'code': 'Series', 'name': '剧集', 'icon': Icons.tv},
      {'code': 'BoxSet', 'name': '合集', 'icon': Icons.collections},
      {'code': 'Person', 'name': '人物', 'icon': Icons.person},
    ];

    return AlertDialog(
      title: const Text('收藏类型筛选'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: availableTypes.map((type) {
          final code = type['code'] as String;
          final name = type['name'] as String;
          final icon = type['icon'] as IconData;
          final isSelected = selectedTypes.contains(code);
          final count = _counts[code];
          return CheckboxListTile(
            value: isSelected,
            onChanged: (_) {
              ref.read(favoriteIncludeTypesProvider.notifier).toggle(code);
            },
            title: Row(
              children: [
                Icon(icon, size: 20, color: widget.scheme.primary),
                const SizedBox(width: 12),
                Text(name),
                const Spacer(),
                if (_loading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (count != null)
                  Text(
                    '$count 个',
                    style: TextStyle(
                      color: widget.scheme.onSurface.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            ref.read(videoListProvider.notifier).refresh();
          },
          child: const Text('确认'),
        ),
      ],
    );
  }
}
