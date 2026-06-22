import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import 'tv_focusable.dart';
import 'video_page_item.dart';

/// 排序选项枚举
enum SortOption {
  recentlyAdded('最近添加'),
  rating('评分'),
  title('标题');

  final String label;
  const SortOption(this.label);
}

/// 海报墙视图：网格布局展示视频缩略图
class PosterGridView extends ConsumerStatefulWidget {
  const PosterGridView({super.key});

  @override
  ConsumerState<PosterGridView> createState() => _PosterGridViewState();
}

class _PosterGridViewState extends ConsumerState<PosterGridView> {
  // 搜索和排序状态
  final TextEditingController _searchController = TextEditingController();
  SortOption _sortOption = SortOption.recentlyAdded;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 根据屏幕宽度计算网格列数
  int _getCrossAxisCount(double width) {
    if (width < 600) return 3;
    if (width < 900) return 4;
    if (width < 1200) return 5;
    return 6;
  }

  // 过滤并排序视频列表
  List<MediaItem> _filterAndSortItems(List<MediaItem> items) {
    var filtered = items;

    // 搜索过滤
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((item) {
        return item.title.toLowerCase().contains(query) ||
            (item.seriesName?.toLowerCase().contains(query) ?? false) ||
            item.displayGenres.any((g) => g.toLowerCase().contains(query));
      }).toList();
    }

    // 排序
    switch (_sortOption) {
      case SortOption.recentlyAdded:
        // 按 productionYear 降序（较新的在前）
        filtered.sort((a, b) => (b.productionYear ?? 0).compareTo(a.productionYear ?? 0));
        break;
      case SortOption.rating:
        // 按评分降序
        filtered.sort((a, b) => (b.displayRating ?? 0).compareTo(a.displayRating ?? 0));
        break;
      case SortOption.title:
        // 按标题升序
        filtered.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
    }

    return filtered;
  }

  // 显示长按操作菜单
  void _showActionMenu(BuildContext context, MediaItem item) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: const Text('播放'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    body: VideoPageItem(item: item),
                  ),
                ));
              },
            ),
            ListTile(
              leading: Icon(item.isFavorite == true ? Icons.favorite : Icons.favorite_border),
              title: Text(item.isFavorite == true ? '取消收藏' : '收藏'),
              onTap: () {
                // TODO: 实现收藏功能
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('详情'),
              onTap: () {
                Navigator.pop(context);
                // TODO: 实现详情页
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final videoState = ref.watch(videoListProvider);

    if (videoState.items.isEmpty && videoState.isLoading) {
      return Center(child: CircularProgressIndicator(color: scheme.primary));
    }
    if (videoState.items.isEmpty) {
      return Center(
        child: Text('暂无视频', style: TextStyle(color: scheme.onSurface.withOpacity(0.7), fontSize: 16)),
      );
    }

    // 过滤并排序后的视频列表
    final filteredItems = _filterAndSortItems(videoState.items);

    return Column(
      children: [
        // 搜索和排序栏
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: Row(
            children: [
              // 搜索框
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '搜索视频...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),
              const SizedBox(width: 8),
              // 排序选择器
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: scheme.outline.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<SortOption>(
                    value: _sortOption,
                    isDense: true,
                    items: SortOption.values.map((option) {
                      return DropdownMenuItem(
                        value: option,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.sort, size: 16, color: scheme.primary),
                            const SizedBox(width: 4),
                            Text(option.label),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _sortOption = value);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        // 过滤结果提示
        if (_searchQuery.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                Text(
                  '找到 ${filteredItems.length} 个结果',
                  style: TextStyle(color: scheme.onSurface.withOpacity(0.6), fontSize: 12),
                ),
              ],
            ),
          ),
        // 网格视图
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = _getCrossAxisCount(constraints.maxWidth);
              return GridView.builder(
                padding: const EdgeInsets.all(8),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: 0.65,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: filteredItems.length + (videoState.hasMore && _searchQuery.isEmpty ? 1 : 0),
                itemBuilder: (context, index) {
                  // 分页加载触发
                  if (videoState.hasMore && index >= filteredItems.length - 3 && !videoState.isLoading && _searchQuery.isEmpty) {
                    ref.read(videoListProvider.notifier).loadMore();
                  }
                  // 末尾加载指示器
                  if (index >= filteredItems.length) {
                    return Center(child: CircularProgressIndicator(color: scheme.primary));
                  }
                  final item = filteredItems[index];
                  return _PosterCard(
                    key: Key(item.id),
                    item: item,
                    onLongPress: () => _showActionMenu(context, item),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 单个海报卡片
class _PosterCard extends ConsumerStatefulWidget {
  final MediaItem item;
  final VoidCallback? onLongPress;

  const _PosterCard({super.key, required this.item, this.onLongPress});

  @override
  ConsumerState<_PosterCard> createState() => _PosterCardState();
}

class _PosterCardState extends ConsumerState<_PosterCard> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  // 类型标签映射
  static String _getTypeLabel(String? type) {
    switch (type?.toLowerCase()) {
      case 'movie':
      case 'video':
        return '电影';
      case 'episode':
        return '剧集';
      case 'series':
        return '系列';
      case 'musicalbum':
        return '音乐';
      case 'musicvideo':
        return '音乐视频';
      case 'trailer':
        return '预告片';
      case 'boxset':
        return '合集';
      default:
        return type ?? '视频';
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final authState = ref.watch(authProvider);
    final thumbnailUrl = widget.item.thumbnailUrlWithAuth(authState.embyServerUrl, authState.token);

    return GestureDetector(
      onLongPress: widget.onLongPress,
      child: TvFocusable(
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              backgroundColor: Theme.of(context).colorScheme.surface,
              body: VideoPageItem(item: widget.item),
            ),
          ));
        },
        borderRadius: 8,
        borderWidth: 2,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (thumbnailUrl != null && thumbnailUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: thumbnailUrl,
                  fit: BoxFit.cover,
                  httpHeaders: widget.item.authHeaders(authState.token),
                  memCacheWidth: 400,
                  placeholder: (_, __) => _ShimmerPlaceholder(scheme: scheme, animation: _shimmerAnimation),
                  errorWidget: (_, __, ___) => Container(
                    color: scheme.surface.withOpacity(0.3),
                    child: Icon(Icons.broken_image, color: scheme.onSurface.withOpacity(0.4)),
                  ),
                )
              else
                Container(
                  color: scheme.surface.withOpacity(0.3),
                  child: Icon(Icons.movie, color: scheme.onSurface.withOpacity(0.4)),
                ),
              // 底部渐变 + 标题 + 类型/标签
              Positioned(
                left: 0, right: 0, bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(6, 20, 6, 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        scheme.surface.withOpacity(0.85),
                        scheme.surface.withOpacity(0.6),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 类型标签
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: scheme.primary.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _getTypeLabel(widget.item.type),
                          style: TextStyle(
                            color: scheme.onPrimary,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      // 标题
                      Text(
                        widget.item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      // 标签（genres）
                      if (widget.item.displayGenres.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.item.displayGenres.take(3).join(' / '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // 继续观看进度条：当有播放位置时在底部显示细粉色条
              if (widget.item.hasProgress)
                Positioned(
                  left: 0, right: 0, bottom: 0,
                  child: LinearProgressIndicator(
                    value: widget.item.progressPercent,
                    minHeight: 3,
                    backgroundColor: scheme.onSurface.withOpacity(0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 骨架屏占位符组件：渐变 shimmer 效果
class _ShimmerPlaceholder extends StatelessWidget {
  final ColorScheme scheme;
  final Animation<double> animation;

  const _ShimmerPlaceholder({required this.scheme, required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                scheme.surface.withOpacity(0.3),
                scheme.surface.withOpacity(0.5),
                scheme.surface.withOpacity(0.3),
              ],
              stops: [
                (animation.value - 1).clamp(0.0, 1.0),
                animation.value.clamp(0.0, 1.0),
                (animation.value + 1).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}
