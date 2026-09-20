// 演员列表页面：展示 Emby 服务器上的所有演员，支持关注/取消关注
// 状态管理已迁移至 actorsProvider（Riverpod StateNotifier）

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../theme/actor_type_colors.dart';
import '../utils/utils.dart';
import '../widgets/person_avatar_image.dart';
part 'actor_parts/actor_actions.dart';
part 'actor_parts/actor_builders.dart';

class ActorsView extends ConsumerStatefulWidget {
  const ActorsView({super.key, this.useScaffold = true});
  final bool useScaffold;

  @override
  ConsumerState<ActorsView> createState() => _ActorsViewState();
}

class _ActorsViewState extends ConsumerState<ActorsView>
    with TickerProviderStateMixin {
  /// 演员页 Tab 数量：全部 / 已关注 / 未关注
  static const int _actorTabsCount = 3;

  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  Timer? _scrollSaveTimer;
  Timer? _searchSaveDebounceTimer;
  late final TextEditingController _searchController;
  String _sortMode = kActorsSortDefault;
  int _gridColumns = 3;

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: _actorTabsCount, vsync: this); // Task 5 同步修改
    _tabController.addListener(_onTabChanged);
    _scrollController.addListener(_onScroll);
    _searchController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _restoreState();
      // 首次加载演员数据
      await ref.read(actorsProvider.notifier).loadActors();
      // 加载完成后恢复滚动位置：等待一帧让 CustomScrollView 完成布局
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _restoreScrollOffset();
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _scrollController.dispose();
    _tabController.dispose();
    _scrollSaveTimer?.cancel();
    _searchSaveDebounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // ========== 状态持久化 ==========

  // 恢复保存的状态（类型筛选、Tab 索引、搜索关键词、滚动位置）

  // 保存类型筛选

  // 保存 Tab 索引

  // 保存搜索关键词（防抖 300ms，与 actorsProvider 搜索节奏一致）

  // 保存排序模式

  // 保存网格列数

  // 保存滚动位置（防抖）

  // 恢复滚动位置

  // Tab 变化时保存

  // 滚动监听：保存滚动位置

  // 下拉刷新

  // 当前显示的演员列表 getter：搜索时用 searchResults，否则用 actors
  List<Person> get displayActors {
    final actorsState = ref.read(actorsProvider);
    final isSearchActive = actorsState.searchQuery.isNotEmpty;
    return isSearchActive ? actorsState.searchResults : actorsState.actors;
  }

  // 排序：default=原顺序，name=按姓名升序，favoritedAt=已关注优先
  // Dart List.sort 不稳定，通过「原始 index」作为次排序键保证 default/favoritedAt 不打乱后端返回顺序

  // 构建排序模式 FilterChip

  // 导航到演员详情

  // 构建类型筛选芯片

  // 构建演员网格列表（Tab 参数化，三个 Tab 共用）

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
    final displayActors =
        isSearchActive ? actorsState.searchResults : actorsState.actors;

    // 应用排序（统一在 displayActors 派生之后，保证搜索态 searchResults 也经过排序）
    final sortedActors = _applySort(displayActors, actorsState.favoritedIds);

    // 各 Tab 过滤后的演员列表
    final allActors = sortedActors;
    final favoritedActors = sortedActors
        .where((a) => actorsState.favoritedIds.contains(a.id))
        .toList();
    final unfavoritedActors = sortedActors
        .where((a) => !actorsState.favoritedIds.contains(a.id))
        .toList();

    // 各 Tab 计数（基于 sortedActors，与列表内容一致）
    final allCount = sortedActors.length;
    final favoritedCount = sortedActors
        .where((a) => actorsState.favoritedIds.contains(a.id))
        .length;
    final unfavoritedCount = sortedActors
        .where((a) => !actorsState.favoritedIds.contains(a.id))
        .length;

    final content = NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverAppBar(
          backgroundColor: scheme.surface,
          foregroundColor: scheme.onSurface,
          title: const Text('演员', style: TextStyle(fontSize: 16)),
          pinned: true,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(200),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 搜索框
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      ref.read(actorsProvider.notifier).searchActors(value);
                      _saveSearchQuery(value);
                    },
                    decoration: InputDecoration(
                      hintText: '搜索演员...',
                      hintStyle: TextStyle(
                          color: scheme.onSurface.withValues(alpha: 0.5)),
                      prefixIcon: Icon(Icons.search,
                          color: scheme.onSurface.withValues(alpha: 0.5)),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.cancel,
                                  color:
                                      scheme.onSurface.withValues(alpha: 0.5)),
                              onPressed: () {
                                _searchController.clear();
                                ref.read(actorsProvider.notifier).clearSearch();
                                _saveSearchQuery('');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor:
                          scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      isDense: true,
                    ),
                    style: TextStyle(color: scheme.onSurface, fontSize: 14),
                  ),
                ),
                // 类型筛选器
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                // 排序 + 网格列数切换
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildSortChip('默认', kActorsSortDefault),
                          const SizedBox(width: 8),
                          _buildSortChip('按姓名', kActorsSortName),
                          const SizedBox(width: 8),
                          _buildSortChip('已关注优先', kActorsSortFavoritedAt),
                        ],
                      ),
                      SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(value: 3, label: Text('3列')),
                          ButtonSegment(value: 4, label: Text('4列')),
                        ],
                        selected: {_gridColumns},
                        onSelectionChanged: (Set<int> newSelection) {
                          final value = newSelection.first;
                          setState(() {
                            _gridColumns = value;
                          });
                          _saveGridColumns(value);
                        },
                        style: const ButtonStyle(
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                ),
                // TabBar
                TabBar(
                  controller: _tabController,
                  labelColor: scheme.primary,
                  unselectedLabelColor: scheme.onSurface.withValues(alpha: 0.6),
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
            isLoadingMore: actorsState.isLoadingMore,
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
            isLoadingMore: actorsState.isLoadingMore,
            error: actorsState.error,
            scheme: scheme,
            hasScrollController: false,
            isFavoriteTab: true,
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
            isLoadingMore: actorsState.isLoadingMore,
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
        // 无 AppBar：SafeArea 整体避让顶部状态栏与底部黑条（刘海屏）
        body: SafeArea(child: content),
      );
    }

    return content;
  }

  // 构建单个 Tab 的内容（处理加载、错误、搜索中、正常显示等状态）
  // 三个 Tab 统一包 RefreshIndicator + CustomScrollView + AlwaysScrollableScrollPhysics
  // 只有第一个 Tab（hasScrollController=true）传 _scrollController，避免 PrimaryScrollController 冲突

  // 构建优化的加载动画

  // 构建空状态提示
}

// 演员卡片组件
class _ActorCard extends StatelessWidget {
  const _ActorCard({
    required this.actor,
    required this.embyServerUrl,
    required this.token,
    required this.isFavorited,
    required this.onFavoriteTap,
    required this.onTap,
  });
  final Person actor;
  final String? embyServerUrl;
  final String? token;
  final bool isFavorited;
  final VoidCallback onFavoriteTap;
  final VoidCallback onTap;

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
        child:
            Icon(Icons.person, color: scheme.onSurface.withValues(alpha: 0.5)),
      );
    }
    final img = url;
    final tk = token;
    return PersonAvatarImage(
      imageUrl: img,
      httpHeaders: tk != null && tk.isNotEmpty ? embyAuthHeaders(tk) : null,
      size: 80,
      memCacheWidth: 240,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
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
                      color: scheme.surface.withValues(alpha: 0.3),
                      child: _buildAvatarImage(scheme),
                    ),
                  ),
                  // 增大关注按钮点击区域至 44x44（圆形水波纹，半径 22）
                  Positioned(
                    right: 2,
                    top: 2,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onFavoriteTap,
                        borderRadius: BorderRadius.circular(22),
                        child: Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                isFavorited ? scheme.primary : scheme.surface,
                            border: Border.all(
                                color: scheme.onSurface.withValues(alpha: 0.3),
                                width: 2),
                          ),
                          child: Icon(
                            isFavorited
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: isFavorited
                                ? scheme.onPrimary
                                : scheme.onSurface,
                            size: 20,
                          ),
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
                color: isFavorited
                    ? scheme.primary
                    : scheme.onSurface.withValues(alpha: 0.5),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 类型标签：Actor=蓝色, Director=橙色, Writer=绿色
  Widget _buildTypeChip(String type, ColorScheme scheme) {
    Color chipColor;
    switch (type) {
      case 'Director':
        chipColor = ActorTypeColors.director;
        break;
      case 'Writer':
        chipColor = ActorTypeColors.writer;
        break;
      default: // 'Actor' 或其他
        chipColor = ActorTypeColors.actor;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: chipColor.withValues(alpha: 0.4), width: 0.5),
      ),
      child: Text(
        personTypeLabelFromCode(type),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: chipColor,
        ),
      ),
    );
  }
}

// 搜索无结果提示组件：复用收藏页空状态视觉模式
class _SearchNoResultHint extends StatelessWidget {
  const _SearchNoResultHint({
    required this.query,
    required this.onClear,
  });
  final String query;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: scheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            '没有找到「$query」',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '换个关键词试试，或者清空搜索词',
            style: TextStyle(
              fontSize: 14,
              color: scheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.clear, size: 18),
            label: const Text('清空搜索词'),
            style: OutlinedButton.styleFrom(
              foregroundColor: scheme.primary,
              side: BorderSide(color: scheme.primary.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
