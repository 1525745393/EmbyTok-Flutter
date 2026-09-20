// 从 favorites_view.dart 拆分（part 文件，无行为变化）

part of '../favorites_view.dart';

// ==================== _FavoritesViewState build 实现 ====================

extension _FavoritesViewBuild on _FavoritesViewState {
  Widget _buildPage(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final state = ref.watch(favoritesProvider);

    final movies = _filter(state.movies);
    final boxSets = _filter(state.boxSets);
    final people = _filter(state.people);
    final totalCount =
        state.movies.length + state.boxSets.length + state.people.length;
    final filteredCount = movies.length + boxSets.length + people.length;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: _buildAppBar(scheme, totalCount, state.isLoading),
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: _buildBody(
              scheme,
              state,
              movies: movies,
              boxSets: boxSets,
              people: people,
              filteredCount: filteredCount,
            ),
          ),
          // 批量操作底部栏
          if (_selectMode) _buildBulkActionBar(scheme),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    ColorScheme scheme,
    int totalCount,
    bool isLoading,
  ) {
    return AppBar(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      title: Row(
        children: [
          Icon(Icons.favorite, color: scheme.primary, size: _kAppBarIconSize),
          const SizedBox(width: _kAppBarTitleSpacing),
          const Text(_kAppBarTitle),
          const SizedBox(width: _kAppBarCountSpacing),
          Text(
            '$totalCount',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: _kAppBarCountFontSize,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      actions: [
        // 批量管理入口：选择模式 <-> 完成
        if (totalCount > 0)
          TextButton(
            onPressed: () {
              setState(() {
                if (_selectMode) {
                  _exitSelectMode();
                } else {
                  _selectMode = true;
                  _selectedIds.clear();
                }
              });
            },
            child: Text(_selectMode ? _kDoneButton : _kBulkManageButton),
          ),
        // 排序
        PopupMenuButton<FavoritesSortMode>(
          icon: Icon(Icons.sort,
              color: scheme.onSurfaceVariant, size: _kAppBarIconSize),
          tooltip: '$_kSortTooltipPrefix$_sortLabel）',
          onSelected: (mode) => setState(() => _sortMode = mode),
          itemBuilder: (ctx) => [
            _sortMenuItem(FavoritesSortMode.defaultOrder, '默认顺序'),
            _sortMenuItem(FavoritesSortMode.nameAsc, '名称 A-Z'),
            _sortMenuItem(FavoritesSortMode.yearDesc, '年份 新-旧'),
            _sortMenuItem(FavoritesSortMode.ratingDesc, '评分 高-低'),
          ],
        ),
        // 刷新
        IconButton(
          icon: isLoading
              ? SizedBox(
                  width: _kLoadingIndicatorSize,
                  height: _kLoadingIndicatorSize,
                  child: CircularProgressIndicator(
                    strokeWidth: _kLoadingIndicatorStrokeWidth,
                    color: scheme.onSurfaceVariant,
                  ),
                )
              : Icon(Icons.refresh,
                  color: scheme.onSurfaceVariant, size: _kAppBarIconSize),
          onPressed: isLoading
              ? null
              : () => ref.read(favoritesProvider.notifier).loadFavorites(),
          tooltip: _kRefreshTooltip,
        ),
      ],
    );
  }

  PopupMenuItem<FavoritesSortMode> _sortMenuItem(
    FavoritesSortMode mode,
    String label,
  ) {
    return PopupMenuItem<FavoritesSortMode>(
      value: mode,
      child: Row(
        children: [
          if (_sortMode == mode)
            Icon(Icons.check,
                size: 18, color: Theme.of(context).colorScheme.primary)
          else
            const SizedBox(width: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildBody(
    ColorScheme scheme,
    FavoritesState state, {
    required List<MediaItem> movies,
    required List<MediaItem> boxSets,
    required List<MediaItem> people,
    required int filteredCount,
  }) {
    // 加载中（全部为空）
    if (state.isLoading &&
        state.movies.isEmpty &&
        state.boxSets.isEmpty &&
        state.people.isEmpty) {
      return Center(child: CircularProgressIndicator(color: scheme.primary));
    }

    // 全局错误（且全部为空）
    final globalErr = state.error;
    if (globalErr != null &&
        state.movies.isEmpty &&
        state.boxSets.isEmpty &&
        state.people.isEmpty) {
      return ErrorStateCard(
        title: globalErr,
        actionLabel: _kErrorStateAction,
        onAction: () => ref.read(favoritesProvider.notifier).loadFavorites(),
      );
    }

    // 空状态（三栏全空且无错误）
    if (state.movies.isEmpty &&
        state.boxSets.isEmpty &&
        state.people.isEmpty &&
        state.moviesError == null &&
        state.boxSetsError == null &&
        state.peopleError == null &&
        state.error == null) {
      return EmptyStateCard(
        icon: Icons.favorite_border,
        title: _kEmptyStateTitle,
        subtitle: _kEmptyStateSubtitle,
        actionLabel: _kEmptyStateAction,
        onAction: () => context.go('/'),
      );
    }

    // 主内容：搜索框 + 统计卡 + 内容区（分组堆叠 / 搜索无结果提示）
    final allAny = movies.isNotEmpty || boxSets.isNotEmpty || people.isNotEmpty;
    final isSearchNoResult = _searchQuery.isNotEmpty && filteredCount == 0;
    return RefreshIndicator(
      onRefresh: () => ref.read(favoritesProvider.notifier).loadFavorites(),
      child: ListView(
        padding: EdgeInsets.fromLTRB(
            16,
            _kListTopPadding,
            16,
            _selectMode
                ? _kListBottomPaddingSelect
                : _kListBottomPaddingNormal),
        children: [
          // 搜索框（常驻：即使搜索无结果也保留，便于用户清空搜索词返回全量）
          _buildSearchField(scheme),
          const SizedBox(height: _kSearchStatsSpacing),
          // 统计概览卡
          _buildStatsRow(scheme, state),
          const SizedBox(height: _kStatsContentSpacing),
          // 搜索无结果：给出明确提示 + 一键清空搜索词返回全量
          if (isSearchNoResult)
            _SearchNoResultHint(
              query: _searchQuery,
              onClear: () {
                setState(() {
                  _searchQuery = '';
                  _searchController.clear();
                });
              },
            )
          else if (!allAny)
            const SizedBox.shrink()
          else ...[
            // 分组：收藏影片
            _GroupSection(
              key: const ValueKey('grp-movie'),
              title: _kGroupTitleMovies,
              icon: Icons.movie_outlined,
              accentColor: scheme.primary,
              count: movies.length,
              recentLabel: _recentLabel(state.moviesError),
              error: _searchQuery.isEmpty ? state.moviesError : null,
              onRetry: () =>
                  ref.read(favoritesProvider.notifier).loadFavorites(),
              isOpen: _groupOpen[_FavGroup.movie] ?? true,
              onToggleOpen: () => setState(() {
                _groupOpen[_FavGroup.movie] =
                    !(_groupOpen[_FavGroup.movie] ?? true);
              }),
              onViewAll: movies.isNotEmpty && _searchQuery.isEmpty
                  ? () => context.push('/favorites/category/movie')
                  : null,
              child: movies.isEmpty
                  ? _buildEmptyListHint(scheme, _kEmptyMoviesHint)
                  : _MovieGrid(
                      items: movies,
                      allItems: movies,
                      selectMode: _selectMode,
                      selectedIds: _selectedIds,
                      onToggle: _toggleSelect,
                      onToggleAll: () =>
                          _toggleSelectAll(movies.map((e) => e.id)),
                      allSelected: movies.isNotEmpty &&
                          movies.every((e) => _selectedIds.contains(e.id)),
                      hasMore: state.hasMoreMovies && _searchQuery.isEmpty,
                      onLoadMore: () => ref
                          .read(favoritesProvider.notifier)
                          .loadMore(FavoritesCategory.movie),
                    ),
            ),
            const SizedBox(height: _kGroupSpacing),
            // 分组：收藏合集
            _GroupSection(
              key: const ValueKey('grp-boxset'),
              title: _kGroupTitleBoxSets,
              icon: Icons.featured_play_list,
              accentColor: scheme.tertiary,
              count: boxSets.length,
              recentLabel:
                  '$_kGroupBoxSetsLabelPrefix${state.boxSets.length}$_kGroupBoxSetsLabelSuffix',
              error: _searchQuery.isEmpty ? state.boxSetsError : null,
              onRetry: () =>
                  ref.read(favoritesProvider.notifier).loadFavorites(),
              isOpen: _groupOpen[_FavGroup.boxSet] ?? false,
              onToggleOpen: () => setState(() {
                _groupOpen[_FavGroup.boxSet] =
                    !(_groupOpen[_FavGroup.boxSet] ?? false);
              }),
              onViewAll: boxSets.isNotEmpty && _searchQuery.isEmpty
                  ? () => context.push('/favorites/category/boxset')
                  : null,
              child: boxSets.isEmpty
                  ? _buildEmptyListHint(scheme, _kEmptyBoxSetsHint)
                  : _BoxSetList(
                      items: boxSets,
                      allItems: boxSets,
                      selectMode: _selectMode,
                      selectedIds: _selectedIds,
                      onToggle: _toggleSelect,
                    ),
            ),
            const SizedBox(height: _kGroupSpacing),
            // 分组：收藏人物
            _GroupSection(
              key: const ValueKey('grp-person'),
              title: _kGroupTitlePeople,
              icon: Icons.person_outline,
              accentColor: scheme.error,
              count: people.length,
              recentLabel:
                  '$_kGroupPeopleLabelPrefix${people.length}$_kGroupPeopleLabelSuffix',
              error: _searchQuery.isEmpty ? state.peopleError : null,
              onRetry: () =>
                  ref.read(favoritesProvider.notifier).loadFavorites(),
              isOpen: _groupOpen[_FavGroup.person] ?? false,
              onToggleOpen: () => setState(() {
                _groupOpen[_FavGroup.person] =
                    !(_groupOpen[_FavGroup.person] ?? false);
              }),
              onViewAll: people.isNotEmpty && _searchQuery.isEmpty
                  ? () => context.push('/favorites/category/person')
                  : null,
              child: people.isEmpty
                  ? _buildEmptyListHint(scheme, _kEmptyPeopleHint)
                  : _PersonGrid(
                      items: people,
                      selectMode: _selectMode,
                      selectedIds: _selectedIds,
                      onToggle: _toggleSelect,
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
