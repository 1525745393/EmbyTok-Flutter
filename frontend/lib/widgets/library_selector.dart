import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/app_preferences.dart' show FeedType;
import 'loading_state_card.dart';
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
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) => LibrarySelector(scope: scope),
    );
  }

  @override
  ConsumerState<LibrarySelector> createState() => _LibrarySelectorState();
}

class _LibrarySelectorState extends ConsumerState<LibrarySelector> {
  // 本地选中状态（确认前临时使用）
  Set<String> _localSelectedIds = {};
  // 是否选中收藏夹（确认前临时使用）
  bool _localIsFavorites = false;

  @override
  void initState() {
    super.initState();
    // PR #67：打开弹窗时强制重载 libraryListProvider
    // 背景：libraryListProvider 之前某次加载失败（网络/401 等）会留下 error 状态
    //       且 Riverpod 不会自动重试 FutureProvider，导致 LibrarySelector
    //       永远显示「加载失败」。这里 invalidate 强制重跑，error 时给「重试」按钮
    // 修复：ref.invalidate 内部会访问 ProviderScope 容器（dependOnInheritedWidgetOfExactType），
    // 不能在 initState 中直接调用，否则触发断言。延迟到首帧后执行。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(libraryListProvider);
      // 初始化本地选中状态：从 provider 读取当前选中的 ID
      // 修复：之前在 build 中初始化，时机不对，导致打勾不显示
      final selectedIds = widget.scope == LibraryScope.feed
          ? ref.read(selectedLibraryIdsProvider)
          : ref.read(recommendLibraryIdsProvider);
      if (selectedIds.isNotEmpty) {
        setState(() {
          _localSelectedIds = Set.from(selectedIds);
        });
      }
      // 初始化收藏夹选中状态
      if (widget.scope == LibraryScope.feed) {
        final currentFeedType = ref.read(feedTypeProvider);
        setState(() {
          _localIsFavorites = currentFeedType == FeedType.favorites;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final librariesAsync = ref.watch(libraryListProvider);
    final visibleLibraries = ref.watch(visibleLibraryListProvider);

    // 如果还没有初始化本地选中状态，默认选中第一个库（仅非收藏夹模式）
    if (!_localIsFavorites && _localSelectedIds.isEmpty && visibleLibraries.isNotEmpty) {
      _localSelectedIds.add(visibleLibraries.first.id);
    }

    // 判断是否全选
    final allSelected = visibleLibraries.isNotEmpty &&
        _localSelectedIds.length >= visibleLibraries.length;

    return Dialog(
      backgroundColor: scheme.surface.withValues(alpha: 0.95),
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
                  // 修复：标题在窄屏（竖屏手机）上会溢出 Row，用 Expanded 约束宽度并截断
                  Expanded(
                    child: Text(
                      _localSelectedIds.isEmpty
                          ? '选择媒体库 - ${widget.scope.title}'
                          : '选择媒体库 - ${widget.scope.title} (已选 ${_localSelectedIds.length} 个)',
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
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
                          _localSelectedIds =
                              visibleLibraries.map((lib) => lib.id).toSet();
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
                    icon: Icon(Icons.close,
                        color: scheme.onSurface.withValues(alpha: 0.6)),
                    tooltip: '关闭',
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1),
            // 内容区域
            Expanded(
              child: librariesAsync.when(
                loading: () => const Center(
                  child: LoadingStateCard(title: '加载中...'),
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
                          color: scheme.onSurface.withValues(alpha: 0.5),
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
                          err.toString(),
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: scheme.onSurface.withValues(alpha: 0.6),
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
                          onPressed: () => ref.invalidate(libraryListProvider),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (_) => _buildGridContent(
                  scheme,
                  visibleLibraries,
                  _localSelectedIds.toList(),
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
  ) {
    if (libraries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.video_library_outlined,
                size: 48,
                color: scheme.onSurface.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                '暂无可用媒体库',
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '请在 Emby 服务器上创建媒体库后重试',
                style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

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
              childAspectRatio: 1.2,
              children: [
                _buildLibraryCard(
                  scheme: scheme,
                  icon: Icons.favorite,
                  name: '收藏夹',
                  count: null,
                  isSelected: _localIsFavorites,
                  onTap: () {
                    setState(() {
                      _localIsFavorites = !_localIsFavorites;
                      // 互斥：选中收藏夹时清空媒体库选中
                      if (_localIsFavorites) {
                        _localSelectedIds.clear();
                      }
                    });
                  },
                  gradientColors: [
                    scheme.primary.withValues(alpha: 0.6),
                    scheme.primary.withValues(alpha: 0.2),
                  ],
                ),
                // 收藏类型筛选卡片
                _buildLibraryCard(
                  scheme: scheme,
                  icon: Icons.filter_list,
                  name: '类型筛选',
                  count: null,
                  isSelected: false,
                  onTap: () => _showFavoriteTypeFilter(context, scheme),
                  gradientColors: [
                    scheme.tertiary.withValues(alpha: 0.6),
                    scheme.tertiary.withValues(alpha: 0.2),
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
            childAspectRatio: 1.2,
            children: libraries.map((lib) {
              final isSelected =
                  !_localIsFavorites && _localSelectedIds.contains(lib.id);
              return _buildLibraryCard(
                scheme: scheme,
                icon: _getLibraryIcon(lib.type),
                name: lib.name,
                count: lib.itemCount,
                isSelected: isSelected,
                onTap: () {
                  // 多选模式：切换该库的选中状态，不关闭弹窗
                  setState(() {
                    // 互斥：点击媒体库时取消收藏夹选中
                    if (!_localIsFavorites && _localSelectedIds.contains(lib.id)) {
                      _localSelectedIds.remove(lib.id);
                      // 确保至少保留一个
                      if (_localSelectedIds.isEmpty) {
                        _localSelectedIds.add(lib.id);
                      }
                    } else {
                      // 点击媒体库时取消收藏夹选中
                      _localIsFavorites = false;
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
                  style:
                      TextStyle(color: scheme.onSurface.withValues(alpha: 0.6)),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: (_localSelectedIds.isEmpty && !_localIsFavorites)
                    ? null
                    : () {
                        // PR #66：根据 scope 写到对应 provider
                        if (widget.scope == LibraryScope.feed) {
                          if (_localIsFavorites) {
                            // 选中收藏夹：设置 feedType 为 favorites
                            ref
                                .read(feedTypeProvider.notifier)
                                .setType(FeedType.favorites);
                            ref.read(videoListProvider.notifier).refresh();
                          } else {
                            // 选中媒体库：设置选中的媒体库 ID
                            ref
                                .read(selectedLibraryIdsProvider.notifier)
                                .setLibraries(_localSelectedIds.toList());
                          }
                          ref
                              .read(feedLibraryConfiguredProvider.notifier)
                              .set(true);
                        } else {
                          ref
                              .read(recommendLibraryIdsProvider.notifier)
                              .setLibraries(_localSelectedIds.toList());
                          ref
                              .read(recommendLibraryConfiguredProvider.notifier)
                              .set(true);
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
          color: scheme.onSurface.withValues(alpha: 0.5),
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
          scheme.primary.withValues(alpha: isSelected ? 0.25 : 0.15),
          scheme.primary.withValues(alpha: isSelected ? 0.1 : 0.05),
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
              : Border.all(
                  color: scheme.onSurface.withValues(alpha: 0.1), width: 1),
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
                    color: isSelected
                        ? scheme.primary
                        : scheme.onSurface.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected
                        ? scheme.onPrimary
                        : scheme.onSurface.withValues(alpha: 0.7),
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
                          color: scheme.onSurface.withValues(alpha: 0.5),
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

  // 显示收藏类型筛选弹窗
  void _showFavoriteTypeFilter(BuildContext context, ColorScheme scheme) {
    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final selectedTypes = ref.watch(favoriteIncludeTypesProvider);
          final availableTypes = const [
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
                return CheckboxListTile(
                  value: isSelected,
                  onChanged: (_) {
                    ref.read(favoriteIncludeTypesProvider.notifier).toggle(code);
                  },
                  title: Row(
                    children: [
                      Icon(icon, size: 20, color: scheme.primary),
                      const SizedBox(width: 12),
                      Text(name),
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
                  // 刷新收藏夹列表
                  ref.read(videoListProvider.notifier).refresh();
                },
                child: const Text('确认'),
              ),
            ],
          );
        },
      ),
    );
  }
}
