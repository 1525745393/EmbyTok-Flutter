// 媒体库浏览页面：
// 1. 媒体库卡片网格（2列）
// 2. 点击卡片后在当前页面内进入该库影片列表（不跳转 feed 视频流）
// 3. 有返回按钮回到媒体库列表
// 4. 点击影片进入影片详情页

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers/library_provider.dart';
import '../providers/providers.dart';
import '../widgets/video/video_grid_card.dart';

class LibrariesBrowseView extends ConsumerStatefulWidget {
  const LibrariesBrowseView({super.key});

  @override
  ConsumerState<LibrariesBrowseView> createState() =>
      _LibrariesBrowseViewState();
}

class _LibrariesBrowseViewState extends ConsumerState<LibrariesBrowseView> {
  Library? _selectedLibrary;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selectedLibrary == null,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // 在媒体库内容页时，返回键先回到媒体库列表
        if (_selectedLibrary != null) {
          setState(() => _selectedLibrary = null);
        }
      },
      child: SafeArea(
        bottom: false,
        child: _selectedLibrary == null
            ? _buildLibraryGrid(context)
            : _buildLibraryContent(context, _selectedLibrary!),
      ),
    );
  }

  // ==================== 媒体库卡片网格 ====================

  Widget _buildLibraryGrid(BuildContext context) {
    // 底栏"媒体库"显示 Emby 服务器上的全部媒体库，不受设置里隐藏列表影响
    final librariesAsync = ref.watch(libraryListProvider);

    return librariesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败: $e')),
      data: (libraries) {
        if (libraries.isEmpty) {
          return const Center(child: Text('暂无媒体库'));
        }
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.6,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: libraries.length,
          itemBuilder: (context, index) {
            final lib = libraries[index];
            return _LibraryCard(
              library: lib,
              onTap: () => setState(() => _selectedLibrary = lib),
            );
          },
        );
      },
    );
  }

  // ==================== 单个媒体库内容浏览 ====================

  Widget _buildLibraryContent(BuildContext context, Library library) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _selectedLibrary = null),
              ),
              Expanded(
                child: Text(
                  library.name,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _LibraryItemsList(
            key: ValueKey(library.id),
            library: library,
          ),
        ),
      ],
    );
  }
}

/// 单个媒体库的影片网格列表
class _LibraryItemsList extends ConsumerStatefulWidget {
  const _LibraryItemsList({super.key, required this.library});
  final Library library;

  @override
  ConsumerState<_LibraryItemsList> createState() => _LibraryItemsListState();
}

class _LibraryItemsListState extends ConsumerState<_LibraryItemsList> {
  List<MediaItem> _items = [];
  bool _isLoading = true;
  String? _error;
  int _startIndex = 0;
  static const int _limit = 50;
  bool _hasMore = true;
  late final ScrollController _scrollController;

  // 排序选项
  static const _sortOptions = {
    '名称': ('SortName', 'Ascending'),
    '最新入库': ('DateCreated', 'Descending'),
    '评分': ('CommunityRating,SortName', 'Descending'),
    '上映年份': ('ProductionYear,SortName', 'Descending'),
  };
  String _sortLabel = '名称';

  // 观看状态筛选
  static const _filterOptions = ['全部', '未观看', '已观看'];
  String _filterLabel = '全部';

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _loadItems();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _isLoading) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 500) {
      _loadItems(loadMore: true);
    }
  }

  Future<void> _loadItems({bool loadMore = false}) async {
    if (_isLoading && loadMore) return;
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated || auth.embyServerUrl == null || auth.token == null) {
      setState(() {
        _error = '未登录';
        _isLoading = false;
      });
      return;
    }
    setState(() {
      _isLoading = true;
      if (!loadMore) {
        _error = null;
        _startIndex = 0;
        _hasMore = true;
      }
    });

    try {
      final service = ref.read(embytokServiceProvider);
      // 根据媒体库类型设置 IncludeItemTypes：
      // - movies 库只返回电影
      // - tvshows 库只返回 Series（不返回单集 Episode）
      // - 其他保持默认（混合）
      final libType = widget.library.type;
      String? includeItemTypes;
      if (libType == 'movies') {
        includeItemTypes = 'Movie';
      } else if (libType == 'tvshows') {
        includeItemTypes = 'Series';
      }
      final sort = _sortOptions[_sortLabel]!;
      String? playedFilter;
      if (_filterLabel == '未观看') playedFilter = 'unplayed';
      if (_filterLabel == '已观看') playedFilter = 'played';
      final resp = await service.getLibraryItems(
        widget.library.id,
        limit: _limit,
        offset: _startIndex,
        serverUrl: auth.embyServerUrl,
        token: auth.token,
        sortBy: sort.$1,
        sortOrder: sort.$2,
        includeItemTypes: includeItemTypes,
        playedFilter: playedFilter,
      );

      setState(() {
        if (loadMore) {
          _items.addAll(resp.items);
        } else {
          _items = resp.items;
        }
        _startIndex += resp.items.length;
        _hasMore = _startIndex < resp.total;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('加载失败: $_error'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => _loadItems(),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return const Center(child: Text('此媒体库暂无内容'));
    }

    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        // 排序栏
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Icon(Icons.sort, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _sortOptions.keys.map((label) {
                      final selected = label == _sortLabel;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(label, style: const TextStyle(fontSize: 12)),
                          selected: selected,
                          onSelected: (_) {
                            if (_sortLabel != label) {
                              setState(() => _sortLabel = label);
                              _loadItems();
                            }
                          },
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
        // 观看状态筛选
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: Row(
            children: [
              Icon(Icons.filter_list, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _filterOptions.map((label) {
                      final selected = label == _filterLabel;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(label, style: const TextStyle(fontSize: 12)),
                          selected: selected,
                          onSelected: (_) {
                            if (_filterLabel != label) {
                              setState(() => _filterLabel = label);
                              _loadItems();
                            }
                          },
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _loadItems(),
            child: GridView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.67,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: _items.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= _items.length) {
                  return const Center(child: CircularProgressIndicator());
                }
                final item = _items[index];
                return VideoGridCard(
                  item: item,
                  onTap: () {
                    context.push('/item/${item.id}', extra: item);
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// 媒体库卡片：封面图背景 + 半透明文字叠加（对标 Emby Web）
class _LibraryCard extends ConsumerWidget {
  const _LibraryCard({required this.library, required this.onTap});
  final Library library;
  final VoidCallback onTap;

  IconData get _icon {
    final type = library.type;
    if (type.contains('movie')) return Icons.movie_outlined;
    if (type.contains('tv')) return Icons.tv_outlined;
    if (type.contains('music')) return Icons.library_music_outlined;
    return Icons.video_library_outlined;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final auth = ref.read(authProvider);

    // 构建媒体库封面图 URL（ImageTags.Primary）
    String? coverUrl;
    if (library.coverImageUrl != null &&
        auth.embyServerUrl != null &&
        auth.token != null) {
      coverUrl =
          '${auth.embyServerUrl}/Items/${library.id}/Images/Primary?MaxWidth=400&Tag=${library.coverImageUrl}&api_key=${auth.token}';
    }

    return Material(
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 封面图背景
            if (coverUrl != null)
              Image.network(
                coverUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildFallback(scheme),
              )
            else
              _buildFallback(scheme),

            // 半透明渐变叠加
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                  stops: const [0.4, 1.0],
                ),
              ),
            ),

            // 文字内容
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    library.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (library.itemCount != null)
                    Text(
                      '${library.itemCount} 项',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallback(ColorScheme scheme) {
    return Container(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: Icon(_icon, size: 40, color: scheme.primary),
      ),
    );
  }
}
