// 媒体库浏览页面：
// 1. 媒体库卡片网格（2列）
// 2. 点击卡片后在当前页面内进入该库影片列表（不跳转 feed 视频流）
// 3. 有返回按钮回到媒体库列表
// 4. 点击影片进入影片详情页

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers/library_provider.dart';
import '../providers/providers.dart';
import '../utils/image_cache_manager.dart';
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
      error: (e, _) => const Center(
        child: Text('加载失败，请稍后重试'),
      ),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      library.name,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: scheme.onSurface,
                      ),
                    ),
                    if (library.itemCount != null)
                      Text(
                        '${library.itemCount} 项',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
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
  int _total = 0; // 媒体库影片总数
  late final ScrollController _scrollController;
  int _requestId = 0; // 竞态防护：只接受最新请求的结果

  // 排序选项
  static const _sortOptions = {
    '名称': ('SortName', 'Ascending'),
    '最新入库': ('DateCreated', 'Descending'),
    '评分': ('CommunityRating,SortName', 'Descending'),
    '上映年份': ('ProductionYear,SortName', 'Descending'),
  };
  String _sortLabel = '名称';
  bool _sortAscending = false; // 用户可切换升序/降序

  // 观看状态筛选
  static const _filterOptions = ['全部', '未观看', '已观看'];
  String _filterLabel = '全部';

  // 搜索
  String _searchQuery = '';
  bool _showSearch = false;
  final _searchController = TextEditingController();

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
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _isLoading) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 500) {
      _loadItems(loadMore: true);
    }
  }

  Future<void> _showItemActions(BuildContext context, MediaItem item) async {
    final auth = ref.read(authProvider);
    final service = ref.read(embytokServiceProvider);
    final played = item.isWatched;

    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                item.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: const Text('播放'),
              onTap: () => Navigator.pop(context, 'play'),
            ),
            ListTile(
              leading: Icon(played ? Icons.remove_done : Icons.done_all),
              title: Text(played ? '标记为未观看' : '标记为已观看'),
              onTap: () => Navigator.pop(context, 'toggle_played'),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('查看详情'),
              onTap: () => Navigator.pop(context, 'details'),
            ),
          ],
        ),
      ),
    );

    if (result == 'play') {
      if (context.mounted) {
        ref.read(playbackListProvider.notifier).setPlaybackList([item], item.id);
        context.push('/play/${item.id}', extra: item);
      }
    } else if (result == 'toggle_played') {
      try {
        if (played) {
          await service.markAsUnplayed(item.id,
              serverUrl: auth.embyServerUrl, token: auth.token);
        } else {
          await service.markAsPlayed(item.id,
              serverUrl: auth.embyServerUrl, token: auth.token);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(played ? '已标记为未观看' : '已标记为已观看')),
          );
          _loadItems(); // 刷新列表
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('操作失败，请重试')),
          );
        }
      }
    } else if (result == 'details') {
      if (context.mounted) {
        context.push('/item/${item.id}', extra: item);
      }
    }
  }

  Future<void> _loadItems({bool loadMore = false}) async {
    if (_isLoading && loadMore) return;
    final myRequestId = ++_requestId; // 递增请求 ID
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated || auth.embyServerUrl == null || auth.token == null) {
      if (myRequestId != _requestId) return; // 已有更新请求
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
      final libType = widget.library.type;
      String? includeItemTypes;
      if (libType == 'movies') {
        includeItemTypes = 'Movie';
      } else if (libType == 'tvshows') {
        includeItemTypes = 'Series';
      }
      final sort = _sortOptions[_sortLabel]!;
      final sortOrder = _sortAscending ? 'Ascending' : 'Descending';
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
        sortOrder: sortOrder,
        includeItemTypes: includeItemTypes,
        playedFilter: playedFilter,
        searchTerm: _searchQuery.isEmpty ? null : _searchQuery,
      );

      if (myRequestId != _requestId) return; // 已有更新请求，丢弃旧结果
      setState(() {
        if (loadMore) {
          _items.addAll(resp.items);
        } else {
          _items = resp.items;
        }
        _startIndex += resp.items.length;
        _total = resp.total;
        _hasMore = _startIndex < resp.total;
        _isLoading = false;
      });
    } catch (e) {
      if (myRequestId != _requestId) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_isLoading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: scheme.error),
            const SizedBox(height: 12),
            Text('加载失败', style: TextStyle(fontSize: 16, color: scheme.onSurface)),
            const SizedBox(height: 4),
            Text('请检查网络后重试', style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => _loadItems(),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.video_library_outlined, size: 48, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty ? '未找到相关影片' : '此媒体库暂无内容',
              style: TextStyle(fontSize: 16, color: scheme.onSurface),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // 标题栏：库名 + 影片总数
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.library.name,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              if (_total > 0)
                Text(
                  '$_total 项',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        // 搜索框（展开时显示）
        if (_showSearch)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '在${widget.library.name}中搜索…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _showSearch = false;
                      _searchQuery = '';
                      _searchController.clear();
                    });
                    _loadItems();
                  },
                ),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onSubmitted: (value) {
                setState(() => _searchQuery = value.trim());
                _loadItems();
              },
            ),
          ),
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
              IconButton(
                icon: Icon(
                  _sortAscending
                      ? Icons.arrow_upward
                      : Icons.arrow_downward,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
                tooltip: _sortAscending ? '升序' : '降序',
                onPressed: () {
                  setState(() => _sortAscending = !_sortAscending);
                  _loadItems();
                },
              ),
              IconButton(
                icon: Icon(
                  _showSearch ? Icons.filter_alt : Icons.search,
                  size: 20,
                  color: scheme.onSurfaceVariant,
                ),
                onPressed: () {
                  setState(() => _showSearch = !_showSearch);
                  if (!_showSearch) {
                    _searchQuery = '';
                    _searchController.clear();
                    _loadItems();
                  }
                },
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                // 自适应列数：平板宽度 4 列，手机 3 列
                final width = constraints.maxWidth;
                final crossAxisCount = width >= 600 ? 4 : 3;
                return GridView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: 0.67,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: _items.length + 1, // 底部状态行
                  itemBuilder: (context, index) {
                    if (index >= _items.length) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            _isLoading && _hasMore
                                ? '加载中…'
                                : '共 ${_items.length} 项',
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    }
                    final item = _items[index];
                    return VideoGridCard(
                      item: item,
                      onTap: () {
                        context.push('/item/${item.id}', extra: item);
                      },
                      onLongPress: () => _showItemActions(context, item),
                    );
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
              CachedNetworkImage(
                imageUrl: coverUrl,
                cacheManager: AppImageCacheManager.thumbnail,
                fit: BoxFit.cover,
                memCacheWidth: 400,
                errorWidget: (_, __, ___) => _buildFallback(scheme),
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
