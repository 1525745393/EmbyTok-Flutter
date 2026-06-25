import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/app_preferences.dart' show FeedType;
import 'tv_focusable.dart';

/// 媒体库选择器：居中弹窗，2列网格布局，单选模式
///
/// 参考 EmbyX 实现：
/// - 居中 Dialog 弹窗
/// - 2 列网格卡片布局
/// - 收藏夹入口（特殊卡片）
/// - 媒体库分组
/// - 单选模式：点击即切换并关闭弹窗
class LibrarySelector extends ConsumerStatefulWidget {
  const LibrarySelector({super.key});

  /// 显示媒体库选择器（居中弹窗）
  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (_) => const LibrarySelector(),
    );
  }

  @override
  ConsumerState<LibrarySelector> createState() => _LibrarySelectorState();
}

class _LibrarySelectorState extends ConsumerState<LibrarySelector> {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final librariesAsync = ref.watch(libraryListProvider);
    final visibleLibraries = ref.watch(visibleLibraryListProvider);
    final selectedIds = ref.watch(selectedLibraryIdsProvider);
    final currentFeedType = ref.watch(feedTypeProvider);

    // 判断是否为收藏夹模式
    final isFavoritesMode = currentFeedType == FeedType.favorites;

    return Dialog(
      backgroundColor: scheme.surface.withOpacity(0.95),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 8),
              child: Row(
                children: [
                  Icon(Icons.video_library, color: scheme.primary, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    '选择媒体库',
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: scheme.onSurface.withOpacity(0.6)),
                    tooltip: '关闭',
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1),
            // 内容区域
            Expanded(
              child: librariesAsync.when(
                loading: () => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: CircularProgressIndicator(color: scheme.primary),
                  ),
                ),
                error: (_, __) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      '加载失败',
                      style: TextStyle(color: scheme.onSurface.withOpacity(0.6)),
                    ),
                  ),
                ),
                data: (_) => _buildGridContent(
                  scheme,
                  visibleLibraries,
                  selectedIds,
                  isFavoritesMode,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridContent(
    ColorScheme scheme,
    List<Library> libraries,
    List<String> selectedIds,
    bool isFavoritesMode,
  ) {
    if (libraries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            '暂无可用媒体库',
            style: TextStyle(color: scheme.onSurface.withOpacity(0.6)),
          ),
        ),
      );
    }

    // 收藏夹是否选中
    final favoritesSelected = isFavoritesMode;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 收藏夹入口（特殊卡片）
          _buildSectionTitle(scheme, '快捷入口'),
          const SizedBox(height: 8),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: [
              _buildLibraryCard(
                scheme: scheme,
                icon: Icons.favorite,
                name: '收藏夹',
                count: null,
                isSelected: favoritesSelected,
                onTap: () {
                  ref.read(feedTypeProvider.notifier).setType(FeedType.favorites);
                  ref.read(videoListProvider.notifier).refresh();
                  Navigator.of(context).pop();
                },
                gradientColors: [
                  scheme.primary.withOpacity(0.6),
                  scheme.primary.withOpacity(0.2),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          // 媒体库分组
          _buildSectionTitle(scheme, '媒体库'),
          const SizedBox(height: 8),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: libraries.map((lib) {
              final isSelected = !isFavoritesMode && selectedIds.contains(lib.id);
              return _buildLibraryCard(
                scheme: scheme,
                icon: _getLibraryIcon(lib.type),
                name: lib.name,
                count: lib.itemCount,
                isSelected: isSelected,
                onTap: () {
                  // 单选模式：设置为单个媒体库 + 切换回 latest 模式
                  ref.read(selectedLibraryIdsProvider.notifier).setLibrary(lib.id);
                  ref.read(feedTypeProvider.notifier).setType(FeedType.latest);
                  ref.read(videoListProvider.notifier).refresh();
                  Navigator.of(context).pop();
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // 分组标题
  Widget _buildSectionTitle(ColorScheme scheme, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: TextStyle(
          color: scheme.onSurface.withOpacity(0.5),
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // 单个媒体库卡片
  Widget _buildLibraryCard({
    required ColorScheme scheme,
    required IconData icon,
    required String name,
    required int? count,
    required bool isSelected,
    required VoidCallback onTap,
    List<Color>? gradientColors,
  }) {
    final bgGradient = gradientColors ??
        [
          scheme.primary.withOpacity(0.15),
          scheme.primary.withOpacity(0.05),
        ];

    return TvFocusable(
      onTap: onTap,
      borderRadius: 12,
      borderWidth: 2,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: bgGradient,
          ),
          border: isSelected
              ? Border.all(color: scheme.primary, width: 2)
              : Border.all(color: scheme.onSurface.withOpacity(0.1), width: 1),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 图标
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected ? scheme.primary : scheme.onSurface.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isSelected ? scheme.onPrimary : scheme.onSurface.withOpacity(0.7),
                size: 20,
              ),
            ),
            // 名称 + 数量
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected ? scheme.primary : scheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                if (count != null)
                  Text(
                    '$count 个视频',
                    style: TextStyle(
                      color: scheme.onSurface.withOpacity(0.5),
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 根据媒体库类型获取图标
  IconData _getLibraryIcon(String type) {
    switch (type.toLowerCase()) {
      case 'movies':
      case 'movie':
        return Icons.movie;
      case 'tvshows':
      case 'tvshows ':
        return Icons.tv;
      case 'music':
        return Icons.music_note;
      case 'musicvideos':
        return Icons.music_video;
      case 'boxsets':
        return Icons.collections;
      case 'playlists':
        return Icons.playlist_play;
      default:
        return Icons.folder;
    }
  }
}
