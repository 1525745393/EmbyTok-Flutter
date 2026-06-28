import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/app_preferences.dart' show FeedType;
import 'tv_focusable.dart';

/// 媒体库选择器作用域（PR #66）
///
/// 视频流和推荐可分别设置媒体库。
enum LibraryScope {
  /// 视频流：用于 feed（视频流页面）
  feed,

  /// 推荐：用于 recommend（推荐页面）
  recommend,
}

extension on LibraryScope {
  String get title {
    switch (this) {
      case LibraryScope.feed:
        return '视频流';
      case LibraryScope.recommend:
        return '推荐';
    }
  }
}

/// 媒体库选择器：居中弹窗，2列网格布局，多选模式
///
/// 参考 EmbyX 实现：
/// - 居中 Dialog 弹窗
/// - 2 列网格卡片布局
/// - 收藏夹入口（特殊卡片，仅视频流）
/// - 媒体库分组
/// - 多选模式：点击切换选中状态，确认后关闭弹窗
///
/// PR #66：通过 [scope] 区分视频流/推荐的媒体库
/// - scope=feed：操作 selectedLibraryIdsProvider，标记 feedLibraryConfigured
/// - scope=recommend：操作 recommendLibraryIdsProvider，标记 recommendLibraryConfigured
class LibrarySelector extends ConsumerStatefulWidget {
  const LibrarySelector({super.key, this.scope = LibraryScope.feed});

  /// 当前作用域（视频流 / 推荐）
  final LibraryScope scope;

  /// 显示媒体库选择器（居中弹窗）
  ///
  /// [scope] 决定操作哪个媒体库 provider
  static Future<void> show(
    BuildContext context, {
    LibraryScope scope = LibraryScope.feed,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (_) => LibrarySelector(scope: scope),
    );
  }

  @override
  ConsumerState<LibrarySelector> createState() => _LibrarySelectorState();
}

class _LibrarySelectorState extends ConsumerState<LibrarySelector> {
  // 本地选中状态（确认前临时使用）
  Set<String> _localSelectedIds = {};

  @override
  void initState() {
    super.initState();
    // PR #67：打开弹窗时强制重载 libraryListProvider
    // 背景：libraryListProvider 之前某次加载失败（网络/401 等）会留下 error 状态
    //       且 Riverpod 不会自动重试 FutureProvider，导致 LibrarySelector
    //       永远显示「加载失败」。这里 invalidate 强制重跑，error 时给「重试」按钮
    ref.invalidate(libraryListProvider);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final librariesAsync = ref.watch(libraryListProvider);
    final visibleLibraries = ref.watch(visibleLibraryListProvider);
    // PR #66：根据 scope 选择当前读哪个 provider
    final selectedIds = widget.scope == LibraryScope.feed
        ? ref.watch(selectedLibraryIdsProvider)
        : ref.watch(recommendLibraryIdsProvider);
    final currentFeedType = ref.watch(feedTypeProvider);

    // 判断是否为收藏夹模式（仅视频流有收藏夹）
    final isFavoritesMode =
        widget.scope == LibraryScope.feed && currentFeedType == FeedType.favorites;

    // 初始化本地选中状态（仅首次打开弹窗时）
    if (_localSelectedIds.isEmpty && selectedIds.isNotEmpty) {
      _localSelectedIds = Set.from(selectedIds);
    } else if (_localSelectedIds.isEmpty) {
      // 默认选中第一个库
      if (visibleLibraries.isNotEmpty) {
        _localSelectedIds.add(visibleLibraries.first.id);
      }
    }

    // 判断是否全选
    final allSelected = visibleLibraries.isNotEmpty &&
        _localSelectedIds.length >= visibleLibraries.length;

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
                    _localSelectedIds.isEmpty
                        ? '选择媒体库 - ${widget.scope.title}'
                        : '选择媒体库 - ${widget.scope.title} (已选 ${_localSelectedIds.length} 个)',
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  // 全选/取消全选按钮
                  TextButton(
                    onPressed: () {
                      setState(() {
                        if (allSelected) {
                          // 取消全选，只保留第一个
                          _localSelectedIds = visibleLibraries.isNotEmpty
                              ? {visibleLibraries.first.id}
                              : {};
                        } else {
                          // 全选
                          _localSelectedIds = visibleLibraries.map((lib) => lib.id).toSet();
                        }
                      });
                    },
                    child: Text(
                      allSelected ? '取消全选' : '全选',
                      style: TextStyle(
                        color: scheme.primary,
                        fontSize: 14,
                      ),
                    ),
                  ),
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
                // PR #67：error 分支增强——显示具体错误 + 重试按钮
                // 解决：libraryListProvider 之前失败后缓存 error 状态，
                //       旧实现只显示「加载失败」让用户无解
                error: (err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: scheme.onSurface.withOpacity(0.5),
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '加载失败',
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          err?.toString() ?? '未知错误',
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: scheme.onSurface.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('重试'),
                          style: FilledButton.styleFrom(
                            backgroundColor: scheme.primary,
                          ),
                          // 重试 = 重新 invalidate，强制重跑 FutureProvider
                          onPressed: () =>
                              ref.invalidate(libraryListProvider),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (_) => _buildGridContent(
                  scheme,
                  visibleLibraries,
                  _localSelectedIds.toList(),
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
          // 收藏夹入口（特殊卡片，仅视频流显示，PR #66）
          if (widget.scope == LibraryScope.feed) ...[
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
                    // PR #66：标记视频流媒体库已配置（避免再次弹引导）
                    ref.read(feedLibraryConfiguredProvider.notifier).set(true);
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
          ],
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
              final isSelected = !isFavoritesMode && _localSelectedIds.contains(lib.id);
              return _buildLibraryCard(
                scheme: scheme,
                icon: _getLibraryIcon(lib.type),
                name: lib.name,
                count: lib.itemCount,
                isSelected: isSelected,
                onTap: () {
                  // 多选模式：切换该库的选中状态，不关闭弹窗
                  setState(() {
                    if (_localSelectedIds.contains(lib.id)) {
                      _localSelectedIds.remove(lib.id);
                      // 确保至少保留一个
                      if (_localSelectedIds.isEmpty) {
                        _localSelectedIds.add(lib.id);
                      }
                    } else {
                      _localSelectedIds.add(lib.id);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          // 确认/取消按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  '取消',
                  style: TextStyle(color: scheme.onSurface.withOpacity(0.6)),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _localSelectedIds.isEmpty
                    ? null
                    : () {
                        // PR #66：根据 scope 写到对应 provider
                        // 仅 setLibraries：selectedLibraryIdsProvider / recommendLibraryIdsProvider
                        // 监听器会自动触发 refresh（PR #60 修复过的逻辑）
                        if (widget.scope == LibraryScope.feed) {
                          ref.read(selectedLibraryIdsProvider.notifier).setLibraries(_localSelectedIds.toList());
                          ref.read(feedLibraryConfiguredProvider.notifier).set(true);
                        } else {
                          ref.read(recommendLibraryIdsProvider.notifier).setLibraries(_localSelectedIds.toList());
                          ref.read(recommendLibraryConfiguredProvider.notifier).set(true);
                        }
                        Navigator.of(context).pop();
                      },
                child: const Text('确认'),
              ),
            ],
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
          scheme.primary.withOpacity(isSelected ? 0.25 : 0.15),
          scheme.primary.withOpacity(isSelected ? 0.1 : 0.05),
        ];

    return TvFocusable(
      onTap: onTap,
      borderRadius: 12,
      borderWidth: isSelected ? 2 : 1,
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
        child: Stack(
          children: [
            Column(
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
            // 右上角勾选标记
            if (isSelected)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
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
