// 从 actors_view.dart 拆分（part 文件，无行为变化）

part of '../actors_view.dart';

// ==================== _ActorBuilders ====================

extension _ActorBuilders on _ActorsViewState {
  Widget _buildSortChip(String label, String mode) {
    final scheme = Theme.of(context).colorScheme;
    final isSelected = _sortMode == mode;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (!selected) return;
        setState(() {
          _sortMode = mode;
        });
        _saveSortMode(mode);
      },
      backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
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
      backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
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

  Widget _buildActorGrid(
    List<Person> actors,
    String? embyServerUrl,
    String? token,
    Set<String> favoritedIds,
    bool isSearchActive, {
    bool isFavoriteTab = false,
  }) {
    if (actors.isEmpty) {
      return SliverFillRemaining(
        child: _buildEmptyState(
          isSearchEmpty: isSearchActive,
          // "已关注"Tab 空列表且非搜索状态时显示"暂无关注的演员"引导
          isFavoriteEmpty: isFavoriteTab && !isSearchActive,
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _gridColumns,
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
              onFavoriteTap: () =>
                  ref.read(actorsProvider.notifier).toggleFavorite(actor),
              onTap: () => _navigateToPersonDetail(actor),
            );
          },
          childCount: actors.length,
        ),
      ),
    );
  }

  Widget _buildTabContent({
    required List<Person> actors,
    required String? embyServerUrl,
    required String? token,
    required Set<String> favoritedIds,
    required bool isSearchActive,
    required bool loading,
    required bool isSearching,
    required bool isLoadingMore,
    required String? error,
    required ColorScheme scheme,
    required bool hasScrollController,
    bool isFavoriteTab = false,
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

    // 三个 Tab 统一：RefreshIndicator + CustomScrollView + AlwaysScrollableScrollPhysics
    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: CustomScrollView(
        controller: hasScrollController ? _scrollController : null,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          _buildActorGrid(
              actors, embyServerUrl, token, favoritedIds, isSearchActive,
              isFavoriteTab: isFavoriteTab),
          // 加载更多提示
          if (hasScrollController && isLoadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text(
                        '加载更多演员...',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // 已加载全部演员的提示（仅在有滚动控制器的 Tab 显示，避免重复）
          if (hasScrollController && !loading && actors.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    '已加载全部 ${actors.length} 位演员',
                    style: TextStyle(
                      color: scheme.onSurface.withValues(alpha: 0.5),
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
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
      {bool isSearchEmpty = false, bool isFavoriteEmpty = false}) {
    final scheme = Theme.of(context).colorScheme;

    if (isSearchEmpty) {
      final query = ref.read(actorsProvider).searchQuery;
      return _SearchNoResultHint(
        query: query,
        onClear: () {
          _searchController.clear();
          ref.read(actorsProvider.notifier).clearSearch();
          _saveSearchQuery('');
        },
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
              color: scheme.onSurface.withValues(alpha: 0.3),
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
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.5),
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
            color: scheme.onSurface.withValues(alpha: 0.3),
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
              color: scheme.onSurface.withValues(alpha: 0.6),
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
              color: scheme.onSurface.withValues(alpha: 0.6),
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
