// 从 recommend_view.dart 拆分（part 文件，无行为变化）

part of 'recommend_view.dart';

// ==================== State 私有动作/构建 ====================

extension _RecommendViewActions on _RecommendViewState {
  Widget _buildPage(BuildContext context) {
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

  Future<void> _saveScrollOffset(double offset) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(kStorageKeyRecommendScrollOffset, offset);
    } catch (_) {
      // 保存失败不影响退出流程
    }
  }

  void _tryRestoreScroll() {
    if (_scrollRestored) return;
    final target = _pendingScrollOffset;
    // 磁盘位置尚未读到：本次跳过且不标记完成，等 prefs 回调再次触发
    if (target == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _scrollRestored) return;
      // GridView 尚未渲染（仍是骨架屏）：跳过，等数据加载监听再次触发
      if (!_scrollController.hasClients) return;
      final maxExtent = _scrollController.position.maxScrollExtent;
      // 内容不足以到达目标位置（如重启后只加载了第一页）：放弃恢复，
      // 停留在顶部，避免 animateTo 被 clamp 到当前列表底部造成错位
      if (target > maxExtent + 1) {
        _scrollRestored = true;
        _pendingScrollOffset = null;
        return;
      }
      _scrollRestored = true;
      _pendingScrollOffset = null;
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    // 距底 < 200px 时触发
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      final state = ref.read(recommendProvider);
      if (state.hasMore && !state.isLoadingMore && !state.isLoading) {
        ref.read(recommendProvider.notifier).loadMore();
      }
      // 预加载下一页海报图片
      _preloadNextPageImages(state);
    }
  }

  void _preloadNextPageImages(RecommendState state) {
    if (!mounted) return;
    final auth = ref.read(authProvider);
    final serverUrl = auth.embyServerUrl;
    final token = auth.token;
    if (serverUrl == null || token == null) return;

    // 预加载当前页末尾 10 个图片（下一页内容还未加载到 items 中）
    final items = state.taggedItems;
    final preloadStart = items.length > 10 ? items.length - 10 : 0;

    for (var i = preloadStart; i < items.length; i++) {
      final item = items[i].item;
      final imageUrl = item.primaryUrl(
        embyServerUrl: serverUrl,
        apiKey: token,
        maxWidth: 500,
      );
      if (imageUrl != null) {
        precacheImage(
          CachedNetworkImageProvider(imageUrl),
          context,
        );
      }
    }
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

    // 首次加载：显示骨架屏
    if (state.isLoading && state.taggedItems.isEmpty) {
      return SkeletonGrid(
        crossAxisCount: _gridColumns,
        itemCount: 12,
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
                    : _buildListEmpty(state, scheme))
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

  Widget _buildListEmpty(RecommendState state, ColorScheme scheme) {
    // 追剧标签空态：引导用户去收藏演员（不再回退 NextUp）
    if (state.selectedTag == RecommendSource.nextUp.key) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: constraints.maxHeight,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_search_outlined,
                      size: 48, color: scheme.onSurfaceVariant),
                  const SizedBox(height: 12),
                  Text(
                    '还没有关注任何演员',
                    style:
                        TextStyle(color: scheme.onSurfaceVariant, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      '去演员页关注喜欢的演员后，这里会展示他们的最新作品',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: scheme.onSurfaceVariant, fontSize: 13),
                    ),
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

  Future<void> _saveGridColumns(int columns) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(kStorageKeyRecommendGridColumns, columns);
    } catch (_) {
      // 操作失败不影响主流程，静默处理
    }
  }

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
    // 其他错误 → 自动重试
    return AutoRetryErrorCard(
      title: '加载推荐失败',
      subtitle: errorMsg,
      onRetry: () => ref.read(recommendProvider.notifier).refresh(),
    );
  }

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

  Widget _buildTagBar(RecommendState state, ColorScheme scheme) {
    // 性能优化：用预计算的 tagCounts 替代 where.length
    // O(1) Map 查找替代 O(n) 全量遍历
    int countFor(RecommendSource? s) {
      if (s == null) return state.taggedItems.length;
      return state.tagCounts[s.key] ?? 0;
    }

    // 标签 ↔ 数据源映射（用户可自定义）：标签栏始终显示全部标签，
    // 每个标签的计数按映射后的数据源统计。
    final sourceMapping = ref.watch(recommendTagSourceMappingProvider);

    final tags = <_RecommendTagInfo>[
      _RecommendTagInfo(label: '全部', sourceKey: null, count: countFor(null)),
      for (final entry in sourceMapping.entries)
        _RecommendTagInfo(
          label: entry.key,
          sourceKey: entry.value,
          count: state.tagCounts[entry.value] ?? 0,
        ),
    ];

    // 所有标签始终显示（count==0 也显示 (0)），让用户知道每个标签的存在；
    // 「全部」始终保留（sourceKey == null），保证用户总有回退入口
    // 注：「追剧」标签已移至首页顶栏（改名「关注」），不再在此展示
    final visibleTags = tags;

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
