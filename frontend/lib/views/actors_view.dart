// 演员列表页面：展示 Emby 服务器上的所有演员，支持关注/取消关注

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../services/embbytok_service.dart';

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
  // 类型筛选状态：null 表示全部，'Actor'/'Director'/'Writer' 表示对应类型
  String? _selectedPersonType;
  String _searchQuery = '';
  DateTime? _debounceTimer;
  late TabController _tabController;
  // 分页状态
  int _total = 0;
  static const int _pageSize = 50;
  final ScrollController _scrollController = ScrollController();

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

  // 滚动监听：检测是否接近底部
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  bool get hasMore => _actors.length < _total;

  Future<void> _loadActors() async {
    setState(() {
      _loading = true;
      _error = null;
      _actors = [];
    });
    try {
      final auth = ref.read(authProvider);
      final service = EmbytokService();

      // 根据选择的类型设置 personTypes 参数
      List<String>? personTypes;
      if (_selectedPersonType != null) {
        personTypes = [_selectedPersonType!];
      }

      // 获取演员列表（支持分页）
      final response = await service.getPeople(
        limit: _pageSize,
        startIndex: 0,
        personTypes: personTypes,
        serverUrl: auth.embyServerUrl,
        token: auth.token,
      );

      // 获取已收藏的演员
      final favoritePeople = await service.getFavoritePeople(
        serverUrl: auth.embyServerUrl,
        token: auth.token,
        userId: auth.user?.id,
      );

      if (mounted) {
        setState(() {
          _actors = response.items;
          _total = response.total;
          _favoritedIds = Set.from(favoritePeople.map((p) => p.id));
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
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
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  // 下拉刷新
  Future<void> _onRefresh() async {
    await _loadActors();
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
      imageTags: actor.imageUrl != null ? {'Primary': actor.imageUrl!} : {},
    );
    context.push('/person/${actor.id}', extra: mediaItem);
  }

  // 根据搜索关键词过滤演员
  List<Person> get _filteredActors {
    if (_searchQuery.isEmpty) return _actors;
    final query = _searchQuery.toLowerCase();
    return _actors.where((actor) => actor.name.toLowerCase().contains(query)).toList();
  }

  // 防抖处理搜索输入
  void _onSearchChanged(String value) {
    final now = DateTime.now();
    _debounceTimer = now;
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_debounceTimer == now && mounted) {
        setState(() {
          _searchQuery = value;
        });
      }
    });
  }

  // 根据 Tab 过滤演员
  List<Person> _getActorsByTab(int tabIndex) {
    final actors = _filteredActors;
    switch (tabIndex) {
      case 1:
        return actors.where((actor) => _favoritedIds.contains(actor.id)).toList();
      case 2:
        return actors.where((actor) => !_favoritedIds.contains(actor.id)).toList();
      default:
        return actors;
    }
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
    final allCount = _filteredActors.length;
    final unfavoritedCount = _filteredActors.where((actor) => !_favoritedIds.contains(actor.id)).toList().length;

    final content = NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverAppBar(
          backgroundColor: scheme.surface,
          foregroundColor: scheme.onSurface,
          title: const Text('演员', style: TextStyle(fontSize: 16)),
          pinned: true,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(100),
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
                // TabBar
                TabBar(
                  controller: _tabController,
                  labelColor: scheme.primary,
                  unselectedLabelColor: scheme.onSurface.withOpacity(0.6),
                  indicatorColor: scheme.primary,
                  indicatorWeight: 2,
                  tabs: [
                    Tab(text: '全部($allCount)'),
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
  Widget _buildLoading() {
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
            '正在加载演员...',
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
                            fit: BoxFit.cover,
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