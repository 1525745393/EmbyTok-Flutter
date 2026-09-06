// 推荐页面：独立路由 /recommend
//
// 背景（PR #57）：
// 推荐从 FeedType 中移除，改为独立路由 + 独立数据源。
// - 数据源：recommendProvider（StateNotifier）
// - 不与 video_list_provider / feed / grid 共享任何状态
// - 视频流中点"推荐"图标 → context.push('/recommend')
// - 推荐页点视频 → 进入视频流播放（context.go('/?initialId=...')）
//
// 特点：
// - 3 列网格布局（参考 PosterGridView）
// - 推荐内容是"个性化推荐 + 多库评分推荐"混合，一次性加载不分页
// - 包含独立 Scaffold + AppBar + 返回按钮

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/constants.dart';
import '../utils/image_cache_manager.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/error_state_card.dart';
import '../widgets/library_selector.dart';

/// 推荐页面
class RecommendView extends ConsumerStatefulWidget {
  const RecommendView({super.key});

  @override
  ConsumerState<RecommendView> createState() => _RecommendViewState();
}

class _RecommendViewState extends ConsumerState<RecommendView> {
  // PR #79：滚动监听 - 滚到底部自动 loadMore
  late final ScrollController _scrollController;
  // P0-2：常驻搜索框（本地过滤，不触发网络）
  late final TextEditingController _searchController;
  String _searchQuery = '';
  // P2-2：网格列数（2/3），持久化到 SharedPreferences，对齐演员页
  int _gridColumns = 3;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    // P0-2：搜索框文本变化 → 本地过滤（纯客户端，不请求服务器）
    _searchController = TextEditingController();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
    });
    // P2-2：恢复用户上次选择的网格列数（2/3）
    SharedPreferences.getInstance().then((prefs) {
      final saved = prefs.getInt(kStorageKeyRecommendGridColumns);
      if (saved != null && (saved == 2 || saved == 3) && mounted) {
        setState(() => _gridColumns = saved);
      }
    });
    // PR #66：首次未配置推荐媒体库 → 强制弹 LibrarySelector 让用户选一次
    // 监听 libraryListProvider 加载完成（不打断首帧）
    // 修复：用 ensureLoaded() 等待 _load() 异步 I/O 完成，
    // 而非 addPostFrameCallback（后者不等异步 I/O，会读到初始值 false）
    ref.listenManual<AsyncValue<List<Library>>>(libraryListProvider,
        (prev, next) {
      next.whenData((_) {
        ref
            .read(recommendLibraryConfiguredProvider.notifier)
            .ensureLoaded()
            .then((_) {
          if (!mounted) return;
          final configured = ref.read(recommendLibraryConfiguredProvider);
          if (configured) return;
          // 媒体库列表已加载但用户没配置过 → 弹 LibrarySelector
          LibrarySelector.show(context, scope: LibraryScope.recommend);
        });
      });
    });

    // 监听推荐页错误状态变化，error 非空时弹 SnackBar 提示
    // 使用 ref.listenManual 在 initState 中注册（Riverpod 推荐模式），
    // 而非在 build 中调用 _maybeShowError，避免每次 rebuild 重复注册 postFrameCallback。
    // ref.listenManual 订阅在 widget dispose 时自动关闭，无需手动 close。
    ref.listenManual<RecommendState>(recommendProvider, (prev, next) {
      final error = next.error;
      if (error == null || error.isEmpty) return;
      // 等到下一帧再弹 SnackBar，避免 build 期间触发 setState
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 3),
          ),
        );
        ref.read(recommendProvider.notifier).clearError();
      });
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // PR #79：分页 - 距底 200px 时触发 loadMore
  // 避免用户看到空白再加载，提升体验
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    // 距底 < 200px 时触发
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      final state = ref.read(recommendProvider);
      if (state.hasMore && !state.isLoadingMore && !state.isLoading) {
        ref.read(recommendProvider.notifier).loadMore();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final state = ref.watch(recommendProvider);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        elevation: 0,
        title: Row(
          children: [
            Icon(Icons.auto_awesome, color: scheme.primary, size: 22),
            const SizedBox(width: 8),
            const Text('推荐'),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // 返回上一页（独立路由，直接 pop）
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        actions: [
          // P2-2：网格 2/3 列切换（持久化到 SharedPreferences，对齐演员页）
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 2, label: Text('2列')),
              ButtonSegment(value: 3, label: Text('3列')),
            ],
            selected: {_gridColumns},
            onSelectionChanged: (newSelection) {
              final value = newSelection.first;
              setState(() => _gridColumns = value);
              _saveGridColumns(value);
            },
            style: const ButtonStyle(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 4),
          // 刷新按钮
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: state.isLoading
                ? null
                : () => ref.read(recommendProvider.notifier).refresh(),
          ),
        ],
      ),
      body: _buildBody(context, state, scheme),
    );
  }

  Widget _buildBody(
    BuildContext context,
    RecommendState state,
    ColorScheme scheme,
  ) {
    // P0-1：全面屏 SafeArea 底部避让（系统手势条/横条 18-34dp）
    // top=false：AppBar 已自动避开刘海/状态栏，Banner/TagBar 不需要额外 top 安全区
    // bottom=true：确保 GridView 末行卡片不被系统手势条遮挡
    return SafeArea(
      top: false,
      bottom: true,
      left: false,
      right: false,
      child: _buildBodyContent(context, state, scheme),
    );
  }

  Widget _buildBodyContent(
    BuildContext context,
    RecommendState state,
    ColorScheme scheme,
  ) {
    // PR #79：冷启动 Banner（仅当 isColdStart=true 时显示）
    // 提示用户"先观看几个视频，推荐会更准"
    final showColdStartBanner =
        state.isColdStart && state.taggedItems.isNotEmpty;

    // 首次加载
    if (state.isLoading && state.taggedItems.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    // 错误（无数据 + 错误信息）
    // P1-1：根据错误类型展示不同 CTA，引导用户进入下一步操作
    final errorMsg = state.error;
    if (state.taggedItems.isEmpty && errorMsg != null) {
      return _buildErrorCard(context, errorMsg);
    }

    // 空数据
    // P1-1：若未配置推荐媒体库，引导用户去选择；否则引导刷新
    if (state.taggedItems.isEmpty) {
      return _buildEmptyCard(context);
    }

    // 性能优化：displayItems 和 tagCounts 由 Provider 预计算
    // 避免在 build 中同步执行 where + map + length（O(n) × 7 次）
    final displayItems = state.displayItems;

    // P0-2：本地搜索过滤（不触发网络，纯客户端过滤当前已加载数据）
    // 匹配字段：标题、剧集名、年份、类型、演员/导演/编剧姓名
    // 搜索时不展示「加载更多」指示器，因为过滤范围仅限当前页数据
    final isSearching = _searchQuery.trim().isNotEmpty;
    final filteredItems = isSearching
        ? displayItems.where(_matchesSearch).toList(growable: false)
        : displayItems;
    final mediaItems = filteredItems.map((r) => r.item).toList(growable: false);
    final hasMoreSlot = state.hasMore && !isSearching;

    // 网格：P2-2 列数由 _gridColumns 驱动（2/3），默认 3 列
    return Column(
      children: [
        if (showColdStartBanner) _buildColdStartBanner(scheme),
        // P0-2：常驻搜索框（始终显示，搜索无结果时也保留，避免用户丢失输入上下文）
        _buildSearchBar(scheme),
        // PR #80：标签分类栏（P2-1：count==0 的源自动隐藏，「全部」始终展示）
        _buildTagBar(state, scheme),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.read(recommendProvider.notifier).refresh(),
            child: filteredItems.isEmpty
                // P0-2：搜索无结果 → 搜索空态；非搜索态空列表 → 分类空态
                // （两种空态均保持可滚动，避免下拉刷新失效）
                ? (isSearching
                    ? _buildSearchEmpty(scheme)
                    : _buildListEmpty(scheme))
                : GridView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _gridColumns,
                      childAspectRatio: 9 / 16, // 竖屏海报
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    itemCount: filteredItems.length + (hasMoreSlot ? 1 : 0),
                    itemBuilder: (context, index) {
                      // PR #79：最后一项 = 加载更多指示器
                      if (index >= filteredItems.length) {
                        return _LoadMoreIndicator(
                          isLoading: state.isLoadingMore,
                          hasMore: state.hasMore,
                        );
                      }
                      final recommendItem = filteredItems[index];
                      return _RecommendCard(
                        item: recommendItem.item,
                        onTap: () => _playItem(
                          context,
                          recommendItem.item,
                          mediaItems,
                          recommendItem.source,
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  // P0-2：本地搜索匹配判定（大小写不敏感）
  // 匹配：标题、剧集名、年份、类型、人员姓名（演员/导演/编剧）
  bool _matchesSearch(RecommendItem recommendItem) {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return true;
    final item = recommendItem.item;
    if (item.title.toLowerCase().contains(q)) return true;
    if (item.seriesName?.toLowerCase().contains(q) == true) return true;
    final year = item.year ?? item.productionYear;
    if (year != null && year.toString().contains(q)) return true;
    if (item.type.toLowerCase().contains(q)) return true;
    final people = item.people;
    if (people != null) {
      for (final p in people) {
        if (p.name.toLowerCase().contains(q)) return true;
      }
    }
    return false;
  }

  // P0-2：常驻搜索框
  Widget _buildSearchBar(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: '搜索当前推荐（标题 / 年份 / 演员）',
          hintStyle: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
          prefixIcon: Icon(Icons.search, size: 20, color: scheme.primary),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  icon: Icon(Icons.clear,
                      size: 18, color: scheme.onSurfaceVariant),
                  tooltip: '清空',
                  onPressed: () {
                    _searchController.clear();
                  },
                ),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: scheme.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: scheme.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: scheme.primary, width: 1.5),
          ),
        ),
      ),
    );
  }

  // P0-2：搜索无结果态 —— 保留搜索栏（在 Column 上层），仅此处提示 + 清空 CTA
  // 可滚动（AlwaysScrollableScrollPhysics），保证下拉刷新可用
  Widget _buildSearchEmpty(ColorScheme scheme) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: constraints.maxHeight,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.search_off,
                    size: 48, color: scheme.onSurfaceVariant),
                const SizedBox(height: 12),
                Text(
                  '未找到匹配「$_searchQuery」的内容',
                  style:
                      TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => _searchController.clear(),
                  icon: const Icon(Icons.clear, size: 18),
                  label: const Text('清空搜索'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // P0-2 修复：非搜索态空列表（当前标签/分类下无内容）
  // 与搜索空态区分，避免误显示「搜索无结果」；可滚动保留下拉刷新
  Widget _buildListEmpty(ColorScheme scheme) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: constraints.maxHeight,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.video_library_outlined,
                    size: 48, color: scheme.onSurfaceVariant),
                const SizedBox(height: 12),
                Text(
                  '当前分类下暂无内容',
                  style:
                      TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () =>
                      ref.read(recommendProvider.notifier).refresh(),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('刷新'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // P2-2：保存网格列数到 SharedPreferences
  Future<void> _saveGridColumns(int columns) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(kStorageKeyRecommendGridColumns, columns);
    } catch (_) {}
  }

  // P1-1：错误态卡片 —— 根据错误类型展示不同 CTA，避免用户看完文案无下一步可走
  Widget _buildErrorCard(BuildContext context, String errorMsg) {
    // 未登录 → 引导去登录
    if (errorMsg == '尚未登录') {
      return ErrorStateCard.notLoggedIn(
        onLogin: () => context.go('/login'),
      );
    }
    // 未选择推荐媒体库 → 引导去 LibrarySelector 选择
    if (errorMsg == '未选择媒体库') {
      return ErrorStateCard(
        icon: Icons.library_add_outlined,
        title: '还没选推荐使用的媒体库',
        subtitle: '选择后才能加载个性化推荐和高分内容',
        actionLabel: '去选择媒体库',
        onAction: () =>
            LibrarySelector.show(context, scope: LibraryScope.recommend),
      );
    }
    // 其他错误 → 重试
    return ErrorStateCard(
      title: '加载推荐失败',
      subtitle: errorMsg,
      actionLabel: '重试',
      onAction: () => ref.read(recommendProvider.notifier).refresh(),
    );
  }

  // P1-1：空态卡片 —— 未配置媒体库时引导选择，否则引导刷新
  Widget _buildEmptyCard(BuildContext context) {
    final selectedIds = ref.watch(recommendLibraryIdsProvider);
    // 未选择推荐使用的媒体库 → 引导去选
    if (selectedIds.isEmpty) {
      return EmptyStateCard(
        icon: Icons.library_add_outlined,
        title: '还没选推荐使用的媒体库',
        subtitle: '选择后才能加载个性化推荐和高分内容',
        actionLabel: '去选择媒体库',
        onAction: () =>
            LibrarySelector.show(context, scope: LibraryScope.recommend),
      );
    }
    // 已选库但推荐为空（可能是评分阈值过高/反疲劳过滤过强）
    // 给一个刷新 CTA，让用户重新拉取
    return EmptyStateCard(
      icon: Icons.auto_awesome,
      title: '暂无推荐',
      subtitle: '试试刷新，或在设置中调低评分门槛、放宽反疲劳天数',
      actionLabel: '刷新',
      onAction: () => ref.read(recommendProvider.notifier).refresh(),
    );
  }

  // PR #80：横向标签分类栏
  // - 显示 6 个标签：全部 / 追剧 / 续看 / 为你推荐 / 相似 / 高分
  // - 选中时高亮（scheme.primary 背景）
  // - 横向可滚动（不溢出）
  // - 点击切换 → state.selectedTag 变化 → view 自动 rebuild
  Widget _buildTagBar(RecommendState state, ColorScheme scheme) {
    // 性能优化：用预计算的 tagCounts 替代 where.length
    // O(1) Map 查找替代 O(n) 全量遍历
    int countFor(RecommendSource? s) {
      if (s == null) return state.taggedItems.length;
      return state.tagCounts[s.key] ?? 0;
    }

    final tags = <_RecommendTagInfo>[
      _RecommendTagInfo(label: '全部', sourceKey: null, count: countFor(null)),
      _RecommendTagInfo(
          label: RecommendSource.nextUp.label,
          sourceKey: RecommendSource.nextUp.key,
          count: countFor(RecommendSource.nextUp)),
      _RecommendTagInfo(
          label: RecommendSource.resume.label,
          sourceKey: RecommendSource.resume.key,
          count: countFor(RecommendSource.resume)),
      _RecommendTagInfo(
          label: RecommendSource.suggestions.label,
          sourceKey: RecommendSource.suggestions.key,
          count: countFor(RecommendSource.suggestions)),
      _RecommendTagInfo(
          label: RecommendSource.similar.label,
          sourceKey: RecommendSource.similar.key,
          count: countFor(RecommendSource.similar)),
      _RecommendTagInfo(
          label: RecommendSource.recommendations.label,
          sourceKey: RecommendSource.recommendations.key,
          count: countFor(RecommendSource.recommendations)),
    ];

    // P2-1：隐藏 count==0 的源标签（如「相似 (0)」），避免展示无意义空标签
    // 「全部」始终保留（sourceKey == null），保证用户总有回退入口
    final visibleTags =
        tags.where((t) => t.sourceKey == null || t.count > 0).toList();

    return Container(
      height: 44,
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: visibleTags.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final tag = visibleTags[i];
          final isSelected = state.selectedTag == tag.sourceKey;
          return ChoiceChip(
            label: Text('${tag.label} (${tag.count})'),
            selected: isSelected,
            onSelected: (_) {
              ref.read(recommendProvider.notifier).selectTag(tag.sourceKey);
            },
            selectedColor: scheme.primary,
            backgroundColor: scheme.surfaceContainerHighest,
            labelStyle: TextStyle(
              color: isSelected ? scheme.onPrimary : scheme.onSurface,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
            side: BorderSide(
              color: isSelected
                  ? scheme.primary
                  : scheme.outlineVariant.withValues(alpha: 0.3),
              width: 1,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4),
          );
        },
      ),
    );
  }

  // PR #79：冷启动 Banner
  // - 提示用户"先观看几个视频，推荐会更准"
  // - 显示在推荐页顶部，仅 isColdStart=true 时出现
  Widget _buildColdStartBanner(ColorScheme scheme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: scheme.primary.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.tips_and_updates_outlined,
              color: scheme.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '先观看几个视频，推荐会更准',
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 跳转到独立播放页（/play/:itemId）
  //
  // PR #63 修复：之前 context.go('/?initialId=item.id') 跳到首页视频流，
  // 但推荐页是独立数据源（Emby Suggestions + 多库评分推荐），推荐 video
  // 不在 video_list.items 中 → FeedView._waitForInitialItemToLoad 找不到
  // → loadMore 100 次（约 5 秒）超时 → 用户看到的不是推荐 video
  //
  // 现在改用 /play/:itemId 独立播放页（[PlaybackShell]），用推荐页的 items
  // 作为滑动列表，用户在播放页可以左右滑动看其他推荐 video。
  //
  // PR #83：传 source 标签（nextUp/resume/...）用于完播率统计门控
  void _playItem(
    BuildContext context,
    MediaItem item,
    List<MediaItem> items,
    RecommendSource? source,
  ) {
    context.push(
      '/play/${item.id}',
      extra: <String, dynamic>{
        'item': item,
        'items': items,
        'source': source?.key, // PR #83：完播率 source 标签
      },
    );
  }
}

/// PR #80：标签分类 - 单个标签的信息（label + sourceKey + count）
class _RecommendTagInfo {
  final String label;
  final String? sourceKey; // null = 全部
  final int count;
  const _RecommendTagInfo({
    required this.label,
    required this.sourceKey,
    required this.count,
  });
}

/// 推荐卡片：竖屏海报 + 标题
class _RecommendCard extends ConsumerWidget {
  final MediaItem item;
  final VoidCallback onTap;

  const _RecommendCard({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final auth = ref.watch(authProvider);
    final imageUrl = item.primaryUrl(
      embyServerUrl: auth.embyServerUrl,
      apiKey: auth.token,
      maxWidth: 500,
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      cacheManager: AppImageCacheManager.thumbnail,
                      memCacheWidth: 300,
                      placeholder: (context, url) => Container(
                        color: scheme.surfaceContainerHighest,
                        child: const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: scheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.movie_outlined,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : Container(
                      color: scheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.movie_outlined,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

/// PR #79：分页加载指示器
/// - 加载中：显示 CircularProgressIndicator
/// - 加载完但 hasMore=false：显示「没有更多了」
class _LoadMoreIndicator extends StatelessWidget {
  final bool isLoading;
  final bool hasMore;
  const _LoadMoreIndicator({required this.isLoading, required this.hasMore});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (isLoading) {
      return Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (!hasMore) {
      // 没有更多数据
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            '没有更多了',
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
