// 演员列表页面：展示 Emby 服务器上的所有演员，支持关注/取消关注
// 状态管理已迁移至 actorsProvider（Riverpod StateNotifier）

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/constants.dart';
import '../utils/image_cache_manager.dart';

class ActorsView extends ConsumerStatefulWidget {
  final bool useScaffold;

  const ActorsView({super.key, this.useScaffold = true});

  @override
  ConsumerState<ActorsView> createState() => _ActorsViewState();
}

class _ActorsViewState extends ConsumerState<ActorsView> with TickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  bool _hasRestoredState = false;
  Timer? _scrollSaveTimer;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _scrollController.addListener(_onScroll);
    _searchController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _restoreState();
      // 首次加载演员数据
      ref.read(actorsProvider.notifier).loadActors();
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _scrollController.dispose();
    _tabController.dispose();
    _scrollSaveTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // ========== 状态持久化 ==========

  // 恢复保存的状态（类型筛选、Tab 索引、搜索关键词、滚动位置）
  Future<void> _restoreState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 恢复类型筛选
      final savedType = prefs.getString(kStorageKeyActorsSelectedType);
      if (savedType != null && savedType.isNotEmpty) {
        final type = savedType == 'null' ? null : savedType;
        ref.read(actorsProvider.notifier).setSelectedType(type);
      }

      // 恢复 Tab 索引
      final savedTab = prefs.getInt(kStorageKeyActorsSelectedTab);
      if (savedTab != null && savedTab >= 0 && savedTab < 3) {
        _tabController.index = savedTab;
      }

      // 恢复搜索关键词
      final savedSearch = prefs.getString(kStorageKeyActorsSearchQuery);
      if (savedSearch != null && savedSearch.isNotEmpty) {
        _searchController.text = savedSearch;
        ref.read(actorsProvider.notifier).searchActors(savedSearch);
      }

      _hasRestoredState = true;
    } catch (_) {}
  }

  // 保存类型筛选
  Future<void> _saveSelectedType(String? type) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kStorageKeyActorsSelectedType, type ?? 'null');
    } catch (_) {}
  }

  // 保存 Tab 索引
  Future<void> _saveSelectedTab(int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(kStorageKeyActorsSelectedTab, index);
    } catch (_) {}
  }

  // 保存搜索关键词
  Future<void> _saveSearchQuery(String query) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kStorageKeyActorsSearchQuery, query);
    } catch (_) {}
  }

  // 保存滚动位置（防抖）
  void _saveScrollOffset() {
    _scrollSaveTimer?.cancel();
    _scrollSaveTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        if (!_scrollController.hasClients) return;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble(kStorageKeyActorsScrollOffset, _scrollController.offset);
      } catch (_) {}
    });
  }

  // 恢复滚动位置
  Future<void> _restoreScrollOffset() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final offset = prefs.getDouble(kStorageKeyActorsScrollOffset);
      if (offset != null && offset > 0 && _scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        final safeOffset = offset.clamp(0.0, maxScroll);
        _scrollController.jumpTo(safeOffset);
      }
    } catch (_) {}
  }

  // Tab 变化时保存
  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    _saveSelectedTab(_tabController.index);
  }

  // 滚动监听：保存滚动位置
  void _onScroll() {
    _saveScrollOffset();
  }

  // 下拉刷新
  Future<void> _onRefresh() async {
    await ref.read(actorsProvider.notifier).loadActors(forceRefresh: true);
  }

  // 导航到演员详情
  void _navigateToPersonDetail(Person actor) {
    final mediaItem = MediaItem(
      id: actor.id ?? '',
      title: actor.name,
      type: 'Person',
      thumbnailUrl: actor.imageUrl,
    );
    context.push('/person/${actor.id}', extra: {
      'item': mediaItem,
      'personType': actor.type,
    });
  }

  // 构建类型筛选芯片
  Widget _buildTypeFilterChip(String label, String? type, ActorsState state) {
    final scheme = Theme.of(context).colorScheme;
    final isSelected = state.selectedPersonType == type;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (!selected) return;
        _saveSelectedType(type);
        ref.read(actorsProvider.notifier).setSelectedType(type);
        // 如果正在搜索，切换类型后重新搜索
        if (state.searchQuery.isNotEmpty) {
          ref.read(actorsProvider.notifier).searchActors(state.searchQuery);
        }
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

  // 构建演员网格列表（Tab 参数化，三个 Tab 共用）
  Widget _buildActorGrid(List<Person> actors, String? embyServerUrl, String? token, Set<String> favoritedIds, bool isSearchActive) {
    if (actors.isEmpty) {
      return SliverFillRemaining(
        child: _buildEmptyState(
          isSearchEmpty: isSearchActive,
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
              isFavorited: favoritedIds.contains(actor.id),
              onFavoriteTap: () => ref.read(actorsProvider.notifier).toggleFavorite(actor),
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
    final actorsState = ref.watch(actorsProvider);
    final embyServerUrl = authState.embyServerUrl;
    final token = authState.token;

    // 是否处于搜索状态
    final isSearchActive = actorsState.searchQuery.isNotEmpty;

    // 当前显示的演员列表（搜索时用搜索结果，否则用全量列表）
    final displayActors = isSearchActive ? actorsState.searchResults : actorsState.actors;

    // 各 Tab 过滤后的演员列表
    final allActors = displayActors;
    final favoritedActors = displayActors.where((a) => actorsState.favoritedIds.contains(a.id)).toList();
    final unfavoritedActors = displayActors.where((a) => !actorsState.favoritedIds.contains(a.id)).toList();

    // 各 Tab 计数
    final allCount = actorsState.actors.length;
    final favoritedCount = actorsState.favoritedIds.length;
    final unfavoritedCount = actorsState.actors.where((a) => !actorsState.favoritedIds.contains(a.id)).length;

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
                    controller: _searchController,
                    onChanged: (value) {
                      ref.read(actorsProvider.notifier).searchActors(value);
                      _saveSearchQuery(value);
                    },
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
                        _buildTypeFilterChip('全部', null, actorsState),
                        const SizedBox(width: 8),
                        _buildTypeFilterChip('演员', 'Actor', actorsState),
                        const SizedBox(width: 8),
                        _buildTypeFilterChip('导演', 'Director', actorsState),
                        const SizedBox(width: 8),
                        _buildTypeFilterChip('编剧', 'Writer', actorsState),
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
                    Tab(text: '全部($allCount)'),
                    Tab(text: '已关注($favoritedCount)'),
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
          // 全部 Tab
          _buildTabContent(
            actors: allActors,
            embyServerUrl: embyServerUrl,
            token: token,
            favoritedIds: actorsState.favoritedIds,
            isSearchActive: isSearchActive,
            loading: actorsState.loading,
            isSearching: actorsState.isSearching,
            error: actorsState.error,
            scheme: scheme,
            hasScrollController: true,
          ),
          // 已关注 Tab
          _buildTabContent(
            actors: favoritedActors,
            embyServerUrl: embyServerUrl,
            token: token,
            favoritedIds: actorsState.favoritedIds,
            isSearchActive: isSearchActive,
            loading: actorsState.loading,
            isSearching: actorsState.isSearching,
            error: actorsState.error,
            scheme: scheme,
            hasScrollController: false,
          ),
          // 未关注 Tab
          _buildTabContent(
            actors: unfavoritedActors,
            embyServerUrl: embyServerUrl,
            token: token,
            favoritedIds: actorsState.favoritedIds,
            isSearchActive: isSearchActive,
            loading: actorsState.loading,
            isSearching: actorsState.isSearching,
            error: actorsState.error,
            scheme: scheme,
            hasScrollController: false,
          ),
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

  // 构建单个 Tab 的内容（处理加载、错误、搜索中、正常显示等状态）
  Widget _buildTabContent({
    required List<Person> actors,
    required String? embyServerUrl,
    required String? token,
    required Set<String> favoritedIds,
    required bool isSearchActive,
    required bool loading,
    required bool isSearching,
    required String? error,
    required ColorScheme scheme,
    required bool hasScrollController,
  }) {
    // 加载中
    if (loading) {
      return _buildLoading();
    }

    // 搜索中
    if (isSearching) {
      return _buildLoading(message: '正在搜索...');
    }

    // 出错
    if (error != null) {
      return _buildError(scheme);
    }

    // 正常显示：全部 Tab 带下拉刷新和滚动控制器
    if (hasScrollController) {
      return RefreshIndicator(
        onRefresh: _onRefresh,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildActorGrid(actors, embyServerUrl, token, favoritedIds, isSearchActive),
            // 已加载全部演员的提示
            if (!loading && actors.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      '已加载全部 ${actors.length} 位演员',
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
      );
    }

    // 已关注/未关注 Tab：自定义滚动视图包裹 Sliver 网格
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        _buildActorGrid(actors, embyServerUrl, token, favoritedIds, isSearchActive),
      ],
    );
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
            onPressed: _onRefresh,
          ),
        ],
      ),
    );
  }
}

// 演员卡片组件
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

  /// 构建头像图片：合并 actor.imageUrl 和 embyServerUrl/token 拼装逻辑，
  /// 单独抽方法便于处理空安全（Dart 不会跨方法对字段做类型提升）
  Widget _buildAvatarImage(ColorScheme scheme) {
    final actorImageUrl = actor.imageUrl;
    final rawId = actor.id; // String?，不能直接 isNotEmpty
    final rawServer = embyServerUrl; // String?，不能直接 isNotEmpty
    String? url;
    if (actorImageUrl != null && actorImageUrl.isNotEmpty) {
      url = actorImageUrl;
    } else if (rawId != null &&
        rawId.isNotEmpty &&
        rawServer != null &&
        rawServer.isNotEmpty) {
      // 在已校验非空后再提取一次到 final 局部变量，触发 Dart 类型提升
      final id = rawId;
      final server = rawServer;
      final tk = token;
      url = '$server/Items/$id/Images/Primary?MaxWidth=200'
          '${tk != null ? '&api_key=$tk' : ''}';
    }
    if (url == null || url.isEmpty) {
      return Center(
        child: Icon(Icons.person, color: scheme.onSurface.withOpacity(0.5)),
      );
    }
    final img = url;
    final tk = token;
    return CachedNetworkImage(
      imageUrl: img,
      cacheManager: AppImageCacheManager.thumbnail,
      fit: BoxFit.cover,
      memCacheWidth: 240,
      httpHeaders: tk != null && tk.isNotEmpty
          ? embyAuthHeaders(tk)
          : null,
      placeholder: (_, __) => Center(
        child: Icon(Icons.person, color: scheme.onSurface.withOpacity(0.5)),
      ),
      errorWidget: (_, __, ___) => Center(
        child: Icon(Icons.person, color: scheme.onSurface.withOpacity(0.5)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

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
                    child: _buildAvatarImage(scheme),
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
          // 名字 + 类型标签
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  actor.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              _buildTypeChip(actor.type, scheme),
            ],
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

  // 类型标签：Actor=蓝色, Director=橙色, Writer=绿色
  Widget _buildTypeChip(String type, ColorScheme scheme) {
    Color chipColor;
    switch (type) {
      case 'Director':
        chipColor = Colors.orange;
        break;
      case 'Writer':
        chipColor = Colors.green;
        break;
      default: // 'Actor' 或其他
        chipColor = Colors.blue;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: chipColor.withOpacity(0.4), width: 0.5),
      ),
      child: Text(
        type,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: chipColor,
        ),
      ),
    );
  }
}