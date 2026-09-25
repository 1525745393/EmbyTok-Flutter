// 媒体库浏览页面：显示所有媒体库卡片，点击进入该媒体库内容
//
// 设计：和 Emby Web 端一样，首页显示媒体库卡片网格。
// 点击某个媒体库后，临时筛选 feed 流只显示该库内容（不修改设置）。
// 通过底栏"媒体库"标签进入，与设置里的媒体库选择完全独立。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/library_provider.dart';
import '../providers/page_navigation_provider.dart';
import '../providers/providers.dart';

class LibrariesBrowseView extends ConsumerWidget {
  const LibrariesBrowseView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final librariesAsync = ref.watch(libraryListProvider);
    final visibleLibraries = ref.watch(visibleLibraryListProvider);
    final topBarFilter = ref.watch(topBarLibraryFilterProvider);
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          // 顶部标题栏
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Text(
                  '媒体库',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
                const Spacer(),
                if (topBarFilter != null)
                  TextButton.icon(
                    onPressed: () {
                      ref.read(topBarLibraryFilterProvider.notifier).state = null;
                    },
                    icon: const Icon(Icons.filter_alt_off, size: 18),
                    label: const Text('清除筛选'),
                  ),
              ],
            ),
          ),
          // 媒体库网格
          Expanded(
            child: librariesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text('加载媒体库失败: $e'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => ref.invalidate(libraryListProvider),
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
              data: (libraries) {
                if (visibleLibraries.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.video_library_outlined,
                            size: 64, color: scheme.onSurfaceVariant),
                        const SizedBox(height: 16),
                        Text(
                          '暂无可见媒体库',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '请在设置中添加媒体库',
                          style: TextStyle(
                              color: scheme.onSurfaceVariant, fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.6,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: visibleLibraries.length,
                  itemBuilder: (context, index) {
                    final lib = visibleLibraries[index];
                    final isSelected = topBarFilter == lib.id;
                    return _LibraryCard(
                      library: lib,
                      isSelected: isSelected,
                      onTap: () {
                        // 设置临时筛选
                        ref.read(topBarLibraryFilterProvider.notifier).state =
                            lib.id;
                        // 跳转到 feed 页面查看该媒体库内容
                        ref
                            .read(pageNavigationNotifierProvider)
                            .goToPage(PageIndices.feed);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 媒体库卡片：显示名称和类型图标
class _LibraryCard extends StatelessWidget {
  const _LibraryCard({
    required this.library,
    required this.isSelected,
    required this.onTap,
  });

  final Library library;
  final bool isSelected;
  final VoidCallback onTap;

  IconData get _icon {
    final type = library.type;
    if (type.contains('movie')) return Icons.movie_outlined;
    if (type.contains('tv')) return Icons.tv_outlined;
    if (type.contains('music')) return Icons.library_music_outlined;
    if (type.contains('boxsets')) return Icons.collections_outlined;
    return Icons.video_library_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: isSelected
          ? scheme.primaryContainer.withValues(alpha: 0.5)
          : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _icon,
                size: 36,
                color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const Spacer(),
              Text(
                library.name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: scheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                library.type,
                style: TextStyle(
                  fontSize: 11,
                  color: scheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
