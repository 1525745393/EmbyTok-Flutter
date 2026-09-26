// 媒体库浏览页面：
// 1. 媒体库卡片网格（2列）
// 2. 点击卡片后在当前页面内进入该库影片列表（不跳转 feed 视频流）
// 3. 有返回按钮回到媒体库列表
// 4. 点击影片进入影片详情页

import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers/library_provider.dart';
import '../providers/providers.dart';
import '../utils/image_cache_manager.dart';
import '../utils/logger.dart';
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
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            const Text('加载失败，请稍后重试'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => ref.invalidate(libraryListProvider),
              child: const Text('重试'),
            ),
          ],
        ),
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
  int _total = 0;
  late final ScrollController _scrollController;
  int _requestId = 0; // 竞态防护：只接受最新请求的结果

  // 排序选项
  static const _sortOptions = {
    '名称': ('SortName', 'Ascending'),
    '最新入库': ('DateCreated', 'Descending'),
    '评分': ('CommunityRating,SortName', 'Descending'),
    '上映年份': ('ProductionYear,SortName', 'Descending'),
    '随机': ('Random', 'Ascending'),
  };
  String _sortLabel = '名称';
  // 初始化排序方向跟随"名称"选项的默认值（Ascending）
  bool _sortAscending = true;

  // 观看状态筛选
  static const _filterOptions = ['全部', '续看', '未观看', '已观看'];
  String _filterLabel = '全部';

  // 最低评分筛选（0=不限，7/8/9 对应 Emby MinCommunityRating）
  static const _ratingOptions = [0, 7, 8, 9];
  int _minRating = 0;
  bool _showRatingFilter = false;

  // 视图密度：1=大图(2列) 2=中图(3列) 3=小图(4列)
  int _gridDensity = 2;

  // 类型筛选（从已加载数据中提取）
  String? _selectedGenre;
  bool _showGenreFilter = false;
  List<String> _serverGenres = []; // 从 Emby /Genres 获取的完整类型列表
  bool _loadingGenres = false;

  // 年份筛选
  int? _selectedYear;
  bool _showYearFilter = false;

  // 搜索
  String _searchQuery = '';
  bool _showSearch = false;
  final _searchController = TextEditingController();

  // 视图模式：grid 网格 / list 列表
  bool _isListView = false;

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
    if (!_hasMore || _isLoading || _error != null) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 500) {
      _loadItems(loadMore: true);
    }
  }

  /// 播放当前库全部影片（顺序）
  void _playAll() {
    if (_items.isEmpty) return;
    ref.read(playbackListProvider.notifier).setPlaybackList(_items, _items.first.id);
    context.push('/play/${_items.first.id}', extra: _items.first);
  }

  /// 随机播放当前库中的一部影片
  void _playRandom() {
    if (_items.isEmpty) return;
    final item = _items[Random().nextInt(_items.length)];
    ref.read(playbackListProvider.notifier).setPlaybackList(_items, item.id);
    context.push('/play/${item.id}', extra: item);
  }

  Future<void> _showItemActions(BuildContext context, MediaItem item) async {
    final auth = ref.read(authProvider);
    final service = ref.read(embytokServiceProvider);
    final played = item.isWatched;
    final favorites = ref.read(favoritesProvider);
    final isFav = favorites.favoriteIds.contains(item.id);

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
              leading: Icon(
                isFav ? Icons.favorite : Icons.favorite_border,
                color: isFav ? Theme.of(context).colorScheme.primary : null,
              ),
              title: Text(isFav ? '取消收藏' : '收藏'),
              onTap: () => Navigator.pop(context, 'favorite'),
            ),
            ListTile(
              leading: Icon(played ? Icons.visibility_off : Icons.visibility),
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
    } else if (result == 'favorite') {
      ref.read(favoritesProvider.notifier).toggleFavorite(item);
    } else if (result == 'toggle_played') {
      // 乐观更新：先改本地列表，再调 API，失败回滚
      final idx = _items.indexWhere((e) => e.id == item.id);
      MediaItem? rolledBack;
      if (idx >= 0) {
        final old = _items[idx];
        rolledBack = old;
        final newData = UserData(
          playbackPositionTicks: old.userData?.playbackPositionTicks ?? 0,
          isFavorite: old.userData?.isFavorite ?? false,
          played: !played,
          unplayedItemCount: old.userData?.unplayedItemCount ?? 0,
          lastPlayedDate: old.userData?.lastPlayedDate,
          playCount: old.userData?.playCount ?? 0,
          rating: old.userData?.rating,
        );
        setState(() {
          _items[idx] = old.copyWith(userData: newData);
        });
      }
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
        }
      } catch (e, st) {
        AppLogger.error('标记观看状态失败', error: e, stackTrace: st);
        if (mounted && rolledBack != null && idx >= 0) {
          setState(() => _items[idx] = rolledBack!);
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

  /// 从 Emby 服务器获取完整类型列表（对标 Emby Web 类型筛选）
  Future<List<String>> _loadServerGenres() async {
    if (_serverGenres.isNotEmpty) return _serverGenres;
    if (_loadingGenres) return const [];
    _loadingGenres = true;
    try {
      final auth = ref.read(authProvider);
      final service = ref.read(embytokServiceProvider);
      final genres = await service.getGenres(
        serverUrl: auth.embyServerUrl,
        token: auth.token,
      );
      _serverGenres = genres.map((g) => g.name).toList();
    } catch (e) {
      AppLogger.error('加载类型列表失败', error: e);
    } finally {
      _loadingGenres = false;
    }
    return _serverGenres;
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
      bool resumable = false;
      if (_filterLabel == '续看') resumable = true;
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
        resumable: resumable,
        genre: _selectedGenre,
        year: _selectedYear,
        minCommunityRating: _minRating > 0 ? _minRating.toDouble() : null,
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
    } catch (e, st) {
      if (myRequestId != _requestId) return;
      AppLogger.error('媒体库列表加载失败', error: e, stackTrace: st);
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
      final hasFilter = _selectedGenre != null ||
          _selectedYear != null ||
          _filterLabel != '全部' ||
          _searchQuery.isNotEmpty;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.video_library_outlined, size: 48, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty
                  ? '未找到相关影片'
                  : hasFilter
                      ? '当前筛选条件下无影片'
                      : '此媒体库暂无内容',
              style: TextStyle(fontSize: 16, color: scheme.onSurface),
            ),
            if (hasFilter) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedGenre = null;
                    _selectedYear = null;
                    _filterLabel = '全部';
                    _searchQuery = '';
                    _searchController.clear();
                  });
                  _loadItems();
                },
                icon: const Icon(Icons.clear, size: 16),
                label: const Text('清除筛选'),
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      children: [
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
        // 合并工具栏：排序 + 观看状态筛选（一行可横向滚动）
        if (_items.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                // 排序选项
                ..._sortOptions.keys.map((label) {
                  final selected = label == _sortLabel;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: ChoiceChip(
                      label: Text(label, style: const TextStyle(fontSize: 12)),
                      selected: selected,
                      onSelected: (_) {
                        if (_sortLabel != label) {
                          setState(() {
                            _sortLabel = label;
                            // 切换排序字段时重置为该字段的默认方向
                            _sortAscending = _sortOptions[label]!.$2 == 'Ascending';
                          });
                          _loadItems();
                        }
                      },
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  );
                }),
                // 分隔 + 升序/降序切换（随机排序时无意义，隐藏）
                if (_sortLabel != '随机')
                  IconButton(
                    icon: Icon(
                      _sortAscending
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                      size: 16,
                      color: scheme.onSurfaceVariant,
                    ),
                    tooltip: _sortAscending ? '升序' : '降序',
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      setState(() => _sortAscending = !_sortAscending);
                      _loadItems();
                    },
                  ),
                // 观看状态筛选
                ..._filterOptions.map((label) {
                  final selected = label == _filterLabel;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
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
                }),
                // 评分筛选按钮（非全部评分时高亮）
                IconButton(
                  icon: Icon(
                    Icons.star_border,
                    size: 18,
                    color: _minRating > 0
                        ? Colors.amber[700]
                        : scheme.onSurfaceVariant,
                  ),
                  tooltip: '评分筛选',
                  visualDensity: VisualDensity.compact,
                  onPressed: () =>
                      setState(() => _showRatingFilter = !_showRatingFilter),
                ),
                // 视图切换（列表/网格）
                IconButton(
                  icon: Icon(
                    _isListView ? Icons.grid_view : Icons.view_list,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                  tooltip: _isListView ? '网格视图' : '列表视图',
                  onPressed: () => setState(() => _isListView = !_isListView),
                ),
                // 网格密度切换（仅网格视图时可用）
                if (!_isListView)
                  IconButton(
                    icon: Icon(
                      Icons.grid_on,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                    tooltip: '切换卡片大小',
                    onPressed: () => setState(() => _gridDensity = _gridDensity >= 3 ? 1 : _gridDensity + 1),
                  ),
                // 搜索
                IconButton(
                  icon: Icon(
                    _showSearch ? Icons.filter_alt : Icons.search,
                    size: 18,
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
                // 类型筛选按钮
                IconButton(
                  icon: Icon(
                    _selectedGenre != null
                        ? Icons.label
                        : Icons.label_outline,
                    size: 18,
                    color: _selectedGenre != null
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
                  ),
                  tooltip: _selectedGenre != null ? '类型: $_selectedGenre' : '按类型筛选',
                  onPressed: () =>
                      setState(() => _showGenreFilter = !_showGenreFilter),
                ),
                // 年份筛选按钮
                IconButton(
                  icon: Icon(
                    _selectedYear != null
                        ? Icons.calendar_today
                        : Icons.calendar_today_outlined,
                    size: 18,
                    color: _selectedYear != null
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
                  ),
                  tooltip: _selectedYear != null ? '年份: $_selectedYear' : '按年份筛选',
                  onPressed: () =>
                      setState(() => _showYearFilter = !_showYearFilter),
                ),
                // 播放全部（顺序）
                IconButton(
                  icon: Icon(Icons.play_arrow, size: 18, color: scheme.onSurfaceVariant),
                  tooltip: '播放全部',
                  onPressed: _items.isEmpty ? null : _playAll,
                ),
                // 随机播放
                IconButton(
                  icon: Icon(Icons.shuffle, size: 18, color: scheme.onSurfaceVariant),
                  tooltip: '随机播放',
                  onPressed: _items.isEmpty ? null : _playRandom,
                ),
              ],
            ),
          ),
        // 类型筛选展开条
        if (_items.isNotEmpty && _showGenreFilter)
          FutureBuilder<List<String>>(
            future: _loadServerGenres(),
            builder: (context, snapshot) {
              // 优先用服务器完整类型列表，fallback 到当前页提取
              final genres = <String>{};
              if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                genres.addAll(snapshot.data!);
              } else {
                for (final item in _items) {
                  genres.addAll(item.displayGenres);
                }
              }
              final sorted = genres.toList()..sort();
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      if (_loadingGenres ||
                          (snapshot.connectionState == ConnectionState.waiting &&
                              _serverGenres.isEmpty))
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ChoiceChip(
                        label: const Text('全部', style: TextStyle(fontSize: 12)),
                        selected: _selectedGenre == null,
                        onSelected: (_) {
                          setState(() {
                            _selectedGenre = null;
                            _showGenreFilter = false;
                          });
                          _loadItems();
                        },
                        visualDensity: VisualDensity.compact,
                      ),
                      ...sorted.map((g) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: ChoiceChip(
                              label: Text(g, style: const TextStyle(fontSize: 12)),
                              selected: _selectedGenre == g,
                              onSelected: (_) {
                                setState(() {
                                  _selectedGenre = g;
                                  _showGenreFilter = false;
                                });
                                _loadItems();
                              },
                              visualDensity: VisualDensity.compact,
                            ),
                          )),
                    ],
                  ),
                ),
              );
            },
          ),
        // 年份筛选展开条
        if (_items.isNotEmpty && _showYearFilter)
          Builder(builder: (_) {
            // 从已加载数据提取年份，降序排列
            final years = <int>{};
            for (final item in _items) {
              if (item.productionYear != null) years.add(item.productionYear!);
            }
            final sorted = years.toList()..sort((a, b) => b.compareTo(a));
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('全部', style: TextStyle(fontSize: 12)),
                      selected: _selectedYear == null,
                      onSelected: (_) {
                        setState(() {
                          _selectedYear = null;
                          _showYearFilter = false;
                        });
                        _loadItems();
                      },
                      visualDensity: VisualDensity.compact,
                    ),
                    ...sorted.map((y) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: ChoiceChip(
                            label: Text('$y', style: const TextStyle(fontSize: 12)),
                            selected: _selectedYear == y,
                            onSelected: (_) {
                              setState(() {
                                _selectedYear = y;
                                _showYearFilter = false;
                              });
                              _loadItems();
                            },
                            visualDensity: VisualDensity.compact,
                          ),
                        )),
                  ],
                ),
              ),
            );
          }),
        // 评分筛选展开条
        if (_items.isNotEmpty && _showRatingFilter)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _ratingOptions.map((r) {
                  final selected = r == _minRating;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: ChoiceChip(
                      label: Text(
                        r == 0 ? '全部评分' : '≥$r分',
                        style: const TextStyle(fontSize: 12),
                      ),
                      selected: selected,
                      onSelected: (_) {
                        setState(() {
                          _minRating = r;
                          _showRatingFilter = false;
                        });
                        _loadItems();
                      },
                      visualDensity: VisualDensity.compact,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _loadItems(),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                // 底部状态行
                Widget buildFooter() {
                  // 分页加载更多失败：显示错误+点击重试
                  if (_error != null && _items.isNotEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextButton.icon(
                          onPressed: () {
                            setState(() => _error = null);
                            _loadItems(loadMore: true);
                          },
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('加载失败，点击重试'),
                        ),
                      ),
                    );
                  }
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _isLoading && _hasMore
                            ? '加载中…'
                            : _total > 0
                                ? '已加载 ${_items.length} / $_total 项'
                                : '共 ${_items.length} 项',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                }

                if (_isListView) {
                  // 列表视图（对标 Emby Web 列表模式）
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: _items.length + 1,
                    itemBuilder: (context, index) {
                      if (index >= _items.length) return buildFooter();
                      final item = _items[index];
                      return _LibraryListItem(
                        item: item,
                        onTap: () => context.push('/item/${item.id}', extra: item),
                        onLongPress: () => _showItemActions(context, item),
                      );
                    },
                  );
                }

                // 网格视图：根据密度和屏幕宽度计算列数
                int crossAxisCount;
                double childRatio;
                if (width >= 600) {
                  crossAxisCount = _gridDensity == 1 ? 3 : _gridDensity == 2 ? 4 : 5;
                } else {
                  crossAxisCount = _gridDensity == 1 ? 2 : _gridDensity == 2 ? 3 : 4;
                }
                childRatio = _gridDensity == 1 ? 0.55 : 0.67; // 大图更高
                return GridView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: childRatio,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: _items.length + 1,
                  itemBuilder: (context, index) {
                    if (index >= _items.length) return buildFooter();
                    final item = _items[index];
                    // NEW 标签：7天内添加的影片（左上角，与未观看蓝点错开）
                    final isNew = item.dateCreated != null &&
                        DateTime.now().difference(item.dateCreated!).inDays <= 7;
                    return Stack(
                      children: [
                        VideoGridCard(
                          item: item,
                          showFavoriteButton: true,
                          onTap: () => context.push('/item/${item.id}', extra: item),
                          onLongPress: () => _showItemActions(context, item),
                        ),
                        if (isNew)
                          Positioned(
                            right: 6,
                            top: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.green[600],
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const Text(
                                'NEW',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
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

            // 左上角类型图标（对标 Emby Web）
            Positioned(
              left: 10,
              top: 10,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _icon,
                  size: 18,
                  color: Colors.white,
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
    // 按库类型生成彩色渐变（对标 Emby Web）
    final type = library.type;
    List<Color> gradient;
    if (type.contains('movie')) {
      gradient = [const Color(0xFF1565C0), const Color(0xFF0D47A1)];
    } else if (type.contains('tv')) {
      gradient = [const Color(0xFF6A1B9A), const Color(0xFF4A148C)];
    } else if (type.contains('music')) {
      gradient = [const Color(0xFF2E7D32), const Color(0xFF1B5E20)];
    } else {
      gradient = [scheme.surfaceContainerHighest, scheme.surfaceContainerHighest];
    }
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
      ),
      child: Center(
        child: Icon(_icon, size: 40, color: Colors.white.withValues(alpha: 0.9)),
      ),
    );
  }
}

/// 列表视图的影片行：缩略图 + 标题/年份/评分 + 收藏心形
class _LibraryListItem extends ConsumerWidget {
  const _LibraryListItem({
    required this.item,
    required this.onTap,
    required this.onLongPress,
  });
  final MediaItem item;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  String _formatDuration(double seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final auth = ref.read(authProvider);
    final favorited = ref.watch(
      favoritesProvider.select((s) => s.favoriteIds.contains(item.id)),
    );

    String? thumbUrl;
    if (item.imageUrl != null &&
        auth.embyServerUrl != null &&
        auth.token != null) {
      thumbUrl =
          '${auth.embyServerUrl}/Items/${item.id}/Images/Primary?MaxWidth=120&Tag=${item.imageUrl}&api_key=${auth.token}';
    }

    return Stack(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 缩略图
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 60,
                      height: 90,
                      child: thumbUrl != null
                          ? CachedNetworkImage(
                              imageUrl: thumbUrl,
                              cacheManager: AppImageCacheManager.thumbnail,
                              fit: BoxFit.cover,
                              memCacheWidth: 120,
                              errorWidget: (_, __, ___) => Container(
                                color: scheme.surfaceContainerHighest,
                                child: const Icon(Icons.movie_outlined, size: 24),
                              ),
                            )
                          : Container(
                              color: scheme.surfaceContainerHighest,
                              child: const Icon(Icons.movie_outlined, size: 24),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 标题信息
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (item.productionYear != null)
                              Text(
                                '${item.productionYear}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            if (item.communityRating != null) ...[
                              const SizedBox(width: 8),
                              Icon(Icons.star, size: 12, color: Colors.amber[700]),
                              const SizedBox(width: 2),
                              Text(
                                item.communityRating!.toStringAsFixed(1),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                            // 时长
                            if (item.durationSeconds != null &&
                                item.durationSeconds! > 0) ...[
                              const SizedBox(width: 8),
                              Text(
                                _formatDuration(item.durationSeconds!),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                            // HD/4K 标签
                            if (item.videoHeight != null &&
                                item.videoHeight! >= 1080) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 3, vertical: 0.5),
                                decoration: BoxDecoration(
                                  color: item.videoHeight! >= 2160
                                      ? Colors.amber[700]
                                      : Colors.blue,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                child: Text(
                                  item.videoHeight! >= 2160 ? '4K' : 'HD',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        // 类型标签（最多显示前3个）
                        if (item.displayGenres.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            item.displayGenres.take(3).join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                        // 播放进度条（续看）
                        if (item.progressPercent > 0) ...[
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: item.progressPercent,
                              minHeight: 3,
                              backgroundColor:
                                  scheme.onSurfaceVariant.withValues(alpha: 0.2),
                              valueColor:
                                  AlwaysStoppedAnimation(scheme.primary),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // 预留心形按钮位置，避免内容被遮挡
                  const SizedBox(width: 40),
                ],
              ),
            ),
          ),
        ),
        // 收藏心形按钮在外层 Stack，只拦截 tap，长按穿透到下层 InkWell
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          child: Center(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () =>
                  ref.read(favoritesProvider.notifier).toggleFavorite(item),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  favorited ? Icons.favorite : Icons.favorite_border,
                  color: favorited ? Colors.red : scheme.onSurfaceVariant,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
