// 演员列表页面：展示 Emby 服务器上的所有演员，支持关注/取消关注

import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../services/embbytok_service.dart';
import '../utils/constants.dart';
import '../utils/image_cache_manager.dart';

class ActorsView extends ConsumerStatefulWidget {
  final bool useScaffold;

  const ActorsView({super.key, this.useScaffold = true});

  @override
  ConsumerState<ActorsView> createState() => _ActorsViewState();
}

class _ActorsViewState extends ConsumerState<ActorsView> with TickerProviderStateMixin {
  List<Person> _actors = const <Person>[];
  bool _loading = true;
  bool _isLoadingMore = false;
  String? _error;
  Set<String> _favoritedIds = {};
  String? _selectedPersonType;
  String _searchQuery = '';
  DateTime? _debounceTimer;
  late TabController _tabController;
  int _total = 0;
  static const int _pageSize = 50;
  static const int _cacheExpiryHours = 24;
  final ScrollController _scrollController = ScrollController();
  bool _isSearching = false;
  List<Person> _searchResults = const [];
  bool _hasTriggeredLoadMore = false;
  bool _isRefreshingFromCache = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadActors());
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // 滚动监听：检测是否接近底部（带防抖）
  void _onScroll() {
    if (_loading || _isLoadingMore || !hasMore || _isSearching) return;
    
    // 防抖：只在滚动方向向下且真正接近底部时触发
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200 && !_hasTriggeredLoadMore) {
      _hasTriggeredLoadMore = true;
      _loadMore();
    }
    // 滚动向上时重置防抖标记
    if (position.pixels < position.maxScrollExtent - 300) {
      _hasTriggeredLoadMore = false;
    }
  }

  bool get hasMore => _actors.length < _total;

  // 根据类型获取缓存键
  String _getCacheKey(String? personType) {
    return personType == null ? kStorageKeyActorsCache : '$kStorageKeyActorsCachePrefix$personType';
  }

  // 根据类型获取缓存时间键
  String _getCacheTimeKey(String? personType) {
    return personType == null ? kStorageKeyActorsCacheTime : '$kStorageKeyActorsCacheTimePrefix$personType';
  }

  Future<Map<String, dynamic>?> _loadActorsFromCache(String? personType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheJson = prefs.getString(_getCacheKey(personType));
      if (cacheJson == null || cacheJson.isEmpty) return null;

      final decoded = json.decode(cacheJson);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _saveActorsToCache(List<Person> actors, int total, String? personType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final actorsJson = actors.map((a) => a.toJson()).toList();
      final cacheData = {
        'actors': actorsJson,
        'total': total,
        'personType': personType,
      };
      await prefs.setString(_getCacheKey(personType), json.encode(cacheData));
      await prefs.setInt(_getCacheTimeKey(personType), DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  Future<int?> _getCacheTimestamp(String? personType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_getCacheTimeKey(personType));
    } catch (_) {
      return null;
    }
  }

  Future<bool> _isCacheExpired(String? personType) async {
    final timestamp = await _getCacheTimestamp(personType);
    if (timestamp == null) return true;
    final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    return now.difference(cacheTime).inHours >= _cacheExpiryHours;
  }

  Future<void> _loadActors({bool forceRefresh = false}) async {
    final personType = _selectedPersonType;
    final cacheData = await _loadActorsFromCache(personType);
    final isExpired = await _isCacheExpired(personType);
    final hasCache = cacheData != null;

    // 强制刷新或无缓存时，显示加载动画
    if (forceRefresh || !hasCache) {
      setState(() {
        _loading = true;
        _error = null;
        _actors = [];
      });
      _fetchAllActorsFromServer(forceRefresh: forceRefresh);
      return;
    }

    // 有缓存时，先显示缓存数据
    final actorsList = (cacheData['actors'] as List<dynamic>)
        .map((e) => Person.fromJson(e as Map<String, dynamic>))
        .toList();
    final total = cacheData['total'] as int? ?? 0;

    if (mounted) {
      setState(() {
        _actors = actorsList;
        _total = total;
        _loading = false;
        _error = null;
        _isRefreshingFromCache = !isExpired;
      });
    }

    _loadFavoritePeople();

    // 缓存过期时，后台静默刷新
    if (isExpired) {
      _fetchAllActorsFromServer(forceRefresh: false);
    }
  }

  Future<void> _loadFavoritePeople() async {
    try {
      final auth = ref.read(authProvider);
      final service = EmbytokService();
      final favoritePeople = await service.getFavoritePeople(
        serverUrl: auth.embyServerUrl,
        token: auth.token,
        userId: auth.user?.id,
      );
      if (mounted) {
        setState(() {
          _favoritedIds = Set.from(favoritePeople.map((p) => p.id).where((id) => id != null && id.isNotEmpty));
        });
      }
    } catch (_) {}
  }

  // 一次性加载全部演员数据并缓存
  Future<void> _fetchAllActorsFromServer({bool forceRefresh = false}) async {
    try {
      final auth = ref.read(authProvider);
      final service = EmbytokService();

      List<String>? personTypes;
      if (_selectedPersonType != null) {
        personTypes = [_selectedPersonType!];
      }

      // 先获取总数
      final initialResponse = await service.getPeople(
        limit: _pageSize,
        startIndex: 0,
        personTypes: personTypes,
        serverUrl: auth.embyServerUrl,
        token: auth.token,
      );

      final total = initialResponse.total;
      final allActors = List<Person>.from(initialResponse.items);

      // 如果总数大于当前页大小，继续加载剩余数据
      if (total > _pageSize) {
        int startIndex = _pageSize;
        while (startIndex < total) {
          final response = await service.getPeople(
            limit: _pageSize,
            startIndex: startIndex,
            personTypes: personTypes,
            serverUrl: auth.embyServerUrl,
            token: auth.token,
          );
          allActors.addAll(response.items);
          startIndex += _pageSize;
        }
      }

      final favoritePeople = await service.getFavoritePeople(
        serverUrl: auth.embyServerUrl,
        token: auth.token,
        userId: auth.user?.id,
      );

      // 缓存全部演员数据
      _saveActorsToCache(allActors, total, _selectedPersonType);

      if (mounted) {
        setState(() {
          _actors = allActors;
          _total = total;
          _favoritedIds = Set.from(favoritePeople.map((p) => p.id).where((id) => id != null && id.isNotEmpty));
          _loading = false;
          _error = null;
          _isRefreshingFromCache = false;
        });
      }
    } catch (e) {
      if (mounted && (forceRefresh || _actors.isEmpty)) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  // 仅加载第一页（用于下拉刷新等场景）
  Future<void> _fetchActorsFirstPage({bool forceRefresh = false}) async {
    try {
      final auth = ref.read(authProvider);
      final service = EmbytokService();

      List<String>? personTypes;
      if (_selectedPersonType != null) {
        personTypes = [_selectedPersonType!];
      }

      final response = await service.getPeople(
        limit: _pageSize,
        startIndex: 0,
        personTypes: personTypes,
        serverUrl: auth.embyServerUrl,
        token: auth.token,
      );

      final favoritePeople = await service.getFavoritePeople(
        serverUrl: auth.embyServerUrl,
        token: auth.token,
        userId: auth.user?.id,
      );

      if (mounted) {
        setState(() {
          _actors = response.items;
          _total = response.total;
          _favoritedIds = Set.from(favoritePeople.map((p) => p.id).where((id) => id != null && id.isNotEmpty));
          _loading = false;
          _error = null;
          _isRefreshingFromCache = false;
        });
      }
    } catch (e) {
      if (mounted && forceRefresh) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  // 加载更多（分页加载）
  Future<void> _loadMore() async {
    if (_isLoadingMore || !hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final auth = ref.read(authProvider);
      final service = EmbytokService();

      List<String>? personTypes;
      if (_selectedPersonType != null) {
        personTypes = [_selectedPersonType!];
      }

      final nextStartIndex = _actors.length;
      final response = await service.getPeople(
        limit: _pageSize,
        startIndex: nextStartIndex,
        personTypes: personTypes,
        serverUrl: auth.embyServerUrl,
        token: auth.token,
      );

      if (mounted) {
        setState(() {
          _actors = [..._actors, ...response.items];
          _total = response.total;
          _isLoadingMore = false;
          _hasTriggeredLoadMore = false; // 重置防抖标记
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          _hasTriggeredLoadMore = false; // 重置防抖标记
        });
      }
    }
  }

  // 下拉刷新
  Future<void> _onRefresh() async {
    await _loadActors(forceRefresh: true);
  }

  Future<void> _toggleFavorite(Person actor) async {
    final isFavorited = _favoritedIds.contains(actor.id);
    try {
      final auth = ref.read(authProvider);
      final service = EmbytokService();

      // 创建 MediaItem 用于收藏操作
      final mediaItem = MediaItem(
        id: actor.id ?? '',
        title: actor.name,
        type: 'Person',
        imageTags: actor.imageUrl != null ? {'Primary': actor.imageUrl!} : {},
      );

      await service.toggleFavorite(
        itemId: actor.id ?? '',
        isFavorite: !isFavorited,
        userId: auth.user?.id,
        serverUrl: auth.embyServerUrl,
        token: auth.token,
      );

      if (mounted) {
        setState(() {
          if (isFavorited) {
            _favoritedIds.remove(actor.id);
          } else {
            _favoritedIds.add(actor.id ?? '');
          }
        });

        // 更新 favoritesProvider
        ref.read(favoritesProvider.notifier).toggleFavorite(mediaItem);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e'), duration: const Duration(seconds: 2)),
        );
      }
    }
  }

  void _navigateToPersonDetail(Person actor) {
    final mediaItem = MediaItem(
      id: actor.id ?? '',
      title: actor.name,
      type: 'Person',
      thumbnailUrl: actor.imageUrl,
    );
    context.push('/person/${actor.id}', extra: mediaItem);
  }

  // 根据搜索关键词返回演员列表（搜索时使用 API 结果）
  List<Person> get _filteredActors {
    // 有搜索关键词时返回搜索结果
    if (_searchQuery.isNotEmpty) {
      return _searchResults;
    }
    // 无搜索时返回已加载的演员列表
    return _actors;
  }

  // 防抖处理搜索输入，调用 API 进行全局搜索
  void _onSearchChanged(String value) {
    final now = DateTime.now();
    _debounceTimer = now;
    Future.delayed(const Duration(milliseconds: 300), () async {
      if (_debounceTimer == now && mounted) {
        if (value.isEmpty) {
          setState(() {
            _searchQuery = '';
            _searchResults = [];
            _isSearching = false;
          });
        } else {
          setState(() {
            _searchQuery = value;
            _isSearching = true;
          });
          await _searchActors(value);
        }
      }
    });
  }

  // 从 API 搜索演员（使用服务器端搜索）
  Future<void> _searchActors(String query) async {
    try {
      final auth = ref.read(authProvider);
      final service = EmbytokService();

      // 使用 Emby SearchHints API 进行服务器端搜索
      final searchResults = await service.searchHints(
        query,
        serverUrl: auth.embyServerUrl,
        token: auth.token,
      );

      if (mounted) {
        // 过滤出 Person 类型的搜索结果
        final personResults = searchResults
            .where((hint) => hint.type == 'Person')
            .map((hint) => Person(
                  id: hint.id,
                  name: hint.name,
                  type: 'Actor',
                  imageUrl: hint.thumbnailUrl,
                ))
            .toList();

        setState(() {
          _searchResults = personResults;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  // 根据 Tab 过滤演员
  List<Person> _getActorsByTab(int tabIndex) {
    // 使用搜索过滤后的列表
    final actors = _filteredActors;
    switch (tabIndex) {
      case 1:
        // 已关注：从过滤后的列表中过滤出已关注的演员
        return actors.where((actor) => actor.id != null && _favoritedIds.contains(actor.id)).toList();
      case 2:
        // 未关注：从过滤后的列表中过滤出未关注的演员
        return actors.where((actor) => actor.id == null || !_favoritedIds.contains(actor.id)).toList();
      default:
        return actors;
    }
  }

  // 构建类型筛选芯片
  Widget _buildTypeFilterChip(String label, String? type) {
    final scheme = Theme.of(context).colorScheme;
    final isSelected = _selectedPersonType == type;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedPersonType = type;
        });
        _loadActors(forceRefresh: true);
      },
      backgroundColor: scheme.surfaceContainerHighest.withOpacity(0.5),
      selectedColor: scheme.primaryContainer,
      labelStyle: TextStyle(
        color: isSelected ? scheme.onPrimaryContainer : scheme.onSurface,
        fontSize: 13,
      ),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  // 构建演员网格列表
  Widget _buildActorGrid(List<Person> actors, String? embyServerUrl, String? token) {
    if (actors.isEmpty) {
      return SliverFillRemaining(
        child: _buildEmptyState(
          isSearchEmpty: _searchQuery.isNotEmpty,
          isFavoriteEmpty: false,
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.75,
          crossAxisSpacing: 12,
          mainAxisSpacing: 16,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final actor = actors[index];
            return _ActorCard(
              actor: actor,
              embyServerUrl: embyServerUrl,
              token: token,
              isFavorited: _favoritedIds.contains(actor.id),
              onFavoriteTap: () => _toggleFavorite(actor),
              onTap: () => _navigateToPersonDetail(actor),
            );
          },
          childCount: actors.length,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final authState = ref.watch(authProvider);
    final embyServerUrl = authState.embyServerUrl;
    final token = authState.token;
    final favoriteCount = _favoritedIds.length;
    // 显示已加载的演员数量和总数
    final loadedCount = _actors.length;
    final totalCount = _total;
    final allCount = _actors.length; // 全部 Tab 显示已加载数量
    final unfavoritedCount = _actors.where((actor) => actor.id != null && !_favoritedIds.contains(actor.id)).length;

    final content = NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverAppBar(
          backgroundColor: scheme.surface,
          foregroundColor: scheme.onSurface,
          title: const Text('演员', style: TextStyle(fontSize: 16)),
          pinned: true,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(130),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 搜索框
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: '搜索演员...',
                      hintStyle: TextStyle(color: scheme.onSurface.withOpacity(0.5)),
                      prefixIcon: Icon(Icons.search, color: scheme.onSurface.withOpacity(0.5)),
                      filled: true,
                      fillColor: scheme.surfaceContainerHighest.withOpacity(0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      isDense: true,
                    ),
                    style: TextStyle(color: scheme.onSurface, fontSize: 14),
                  ),
                ),
                // 类型筛选器
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildTypeFilterChip('全部', null),
                        const SizedBox(width: 8),
                        _buildTypeFilterChip('演员', 'Actor'),
                        const SizedBox(width: 8),
                        _buildTypeFilterChip('导演', 'Director'),
                        const SizedBox(width: 8),
                        _buildTypeFilterChip('编剧', 'Writer'),
                      ],
                    ),
                  ),
                ),
                // TabBar
                TabBar(
                  controller: _tabController,
                  labelColor: scheme.primary,
                  unselectedLabelColor: scheme.onSurface.withOpacity(0.6),
                  indicatorColor: scheme.primary,
                  indicatorWeight: 2,
                  tabs: [
                    Tab(text: totalCount > loadedCount ? '全部($loadedCount/$totalCount)' : '全部($allCount)'),
                    Tab(text: '已关注($favoriteCount)'),
                    Tab(text: '未关注($unfavoritedCount)'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
      body: TabBarView(
        controller: _tabController,
        children: [
          // 全部
          _loading
              ? _buildLoading()
              : _isSearching
                  ? _buildLoading(message: '正在搜索...')
                  : _error != null
                      ? _buildError(scheme)
                      : RefreshIndicator(
                          onRefresh: _onRefresh,
                          child: CustomScrollView(
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            slivers: [
                              _buildActorGrid(_getActorsByTab(0), embyServerUrl, token),
                              if (_isLoadingMore)
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: scheme.primary,
                                      ),
                                    ),
                                  ),
                                ),
                              if (!_loading && !_isLoadingMore && !hasMore && _actors.isNotEmpty)
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    child: Center(
                                      child: Text(
                                        '已加载全部 ${_actors.length} 位演员',
                                        style: TextStyle(
                                          color: scheme.onSurface.withOpacity(0.5),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
          // 已关注
          _loading
              ? _buildLoading()
              : _error != null
                  ? _buildError(scheme)
                  : _buildActorGrid(_getActorsByTab(1), embyServerUrl, token),
          // 未关注
          _loading
              ? _buildLoading()
              : _error != null
                  ? _buildError(scheme)
                  : _buildActorGrid(_getActorsByTab(2), embyServerUrl, token),
        ],
      ),
    );

    if (widget.useScaffold) {
      return Scaffold(
        backgroundColor: scheme.surface,
        body: content,
      );
    }

    return content;
  }

  // 构建优化的加载动画
  Widget _buildLoading({String message = '正在加载演员...'}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // 构建空状态提示
  Widget _buildEmptyState({bool isSearchEmpty = false, bool isFavoriteEmpty = false}) {
    final scheme = Theme.of(context).colorScheme;

    if (isSearchEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: scheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              '未找到相关演员',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '换个关键词试试吧',
              style: TextStyle(
                fontSize: 14,
                color: scheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      );
    }

    if (isFavoriteEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_border,
              size: 64,
              color: scheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              '暂无关注的演员',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '快去关注你喜欢的演员吧',
              style: TextStyle(
                fontSize: 14,
                color: scheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.touch_app,
                    size: 16,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '点击演员卡片上的爱心图标即可关注',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // 默认空状态
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: scheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无演员',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '请检查 Emby 服务器是否正常',
            style: TextStyle(
              fontSize: 14,
              color: scheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(ColorScheme scheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            color: scheme.error,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            '加载演员列表失败',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '请检查 Emby 服务器是否正常运行',
            style: TextStyle(
              color: scheme.onSurface.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('重试'),
            onPressed: _loadActors,
          ),
        ],
      ),
    );
  }
}

class _ActorCard extends StatelessWidget {
  final Person actor;
  final String? embyServerUrl;
  final String? token;
  final bool isFavorited;
  final VoidCallback onFavoriteTap;
  final VoidCallback onTap;

  const _ActorCard({
    required this.actor,
    required this.embyServerUrl,
    required this.token,
    required this.isFavorited,
    required this.onFavoriteTap,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    String? imageUrl;
    if (actor.imageUrl != null && actor.imageUrl!.isNotEmpty) {
      imageUrl = actor.imageUrl;
    } else if (actor.id != null && actor.id!.isNotEmpty && embyServerUrl != null) {
      imageUrl = '$embyServerUrl/Items/${actor.id!}/Images/Primary?MaxWidth=200'
          '${token != null ? '&api_key=$token' : ''}';
    }

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 圆形裁剪头像
                ClipOval(
                  child: Container(
                    width: double.infinity,
                    color: scheme.surface.withOpacity(0.3),
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            cacheManager: AppImageCacheManager.thumbnail,
                            fit: BoxFit.cover,
                            httpHeaders: token != null && token!.isNotEmpty
                                ? {'X-Emby-Token': token!}
                                : null,
                            placeholder: (_, __) => Center(
                              child: Icon(Icons.person, color: scheme.onSurface.withOpacity(0.5)),
                            ),
                            errorWidget: (_, __, ___) => Center(
                              child: Icon(Icons.person, color: scheme.onSurface.withOpacity(0.5)),
                            ),
                          )
                        : Center(
                            child: Icon(Icons.person, color: scheme.onSurface.withOpacity(0.5)),
                          ),
                  ),
                ),
                // 增大关注按钮点击区域至 44x44
                Positioned(
                  right: 2,
                  top: 2,
                  child: GestureDetector(
                    onTap: onFavoriteTap,
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isFavorited ? scheme.primary : scheme.surface,
                        border: Border.all(color: scheme.onSurface.withOpacity(0.3), width: 2),
                      ),
                      child: Icon(
                        isFavorited ? Icons.favorite : Icons.favorite_border,
                        color: isFavorited ? scheme.onPrimary : scheme.onSurface,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            actor.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            isFavorited ? '已关注' : '未关注',
            style: TextStyle(
              color: isFavorited ? scheme.primary : scheme.onSurface.withOpacity(0.5),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}