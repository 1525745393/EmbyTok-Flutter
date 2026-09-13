// 收藏管理页面（方案 B：纵向堆叠 + 可折叠分组 + 统计概览 + 批量操作）
//
// 布局结构（自顶向下）：
//   1. AppBar：标题「我的收藏」+ 批量管理开关（进入/退出选择模式）+ 刷新
//   2. 搜索栏：页面内固定输入框，实时过滤三类内容
//   3. 统计概览：三列卡片显示影片/合集/人物数量
//   4. 分组列表（可折叠）：
//      - 收藏影片：3 列网格预览（最多 N 张）+ 「查看全部」跳转
//      - 收藏合集：横向列表卡（未看/进度/评分标签）+ 「查看全部」
//      - 收藏人物：4 列圆形头像 + 「查看全部」
//   5. 批量操作底部栏（选择模式时浮起）：已选数量 + 移动到合集/批量下载/取消收藏
//
// 关键特性：
//   - 分组默认：影片展开，合集/人物折叠（点击标题切换）
//   - 批量选择：AppBar 切换 → 卡片左上角出现勾选框 → 底部操作栏
//   - 撤销 SnackBar：保留原乐观更新 + 失败回滚机制

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/image_cache_manager.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/error_state_card.dart';
import '../widgets/video/video_page_item.dart';

/// 收藏排序方式
enum FavoritesSortMode {
  defaultOrder, // 服务端返回顺序（按添加时间）
  nameAsc, // 名称 A→Z
  yearDesc, // 年份 新→旧
  ratingDesc, // 评分 高→低
}

/// 分组标识：三个可折叠分组
enum _FavGroup { movie, boxSet, person }

// ===== 收藏页面常量（避免魔法数字和硬编码字符串）=====

/// AppBar 标题
const String _kAppBarTitle = '我的收藏';

/// 批量管理按钮文本
const String _kBulkManageButton = '批量管理';

/// 完成按钮文本
const String _kDoneButton = '完成';

/// 刷新按钮提示
const String _kRefreshTooltip = '刷新';

/// 排序按钮提示前缀
const String _kSortTooltipPrefix = '排序（';

/// 空列表提示：暂无影片
const String _kEmptyMoviesHint = '暂无影片';

/// 空列表提示：暂无合集
const String _kEmptyBoxSetsHint = '暂无合集';

/// 空列表提示：暂无人物
const String _kEmptyPeopleHint = '暂无人物';

/// 搜索框提示
const String _kSearchHint = '搜索收藏的影片、合集、人物';

/// 搜索框圆角
const double _kSearchBorderRadius = 14.0;

/// 搜索框图标尺寸
const double _kSearchIconSize = 18.0;

/// 搜索框图标间距
const double _kSearchIconSpacing = 8.0;

/// 搜索框字体大小
const double _kSearchFontSize = 14.0;

/// 搜索框垂直内边距
const double _kSearchVerticalPadding = 12.0;

/// 统计卡标签：收藏影片
const String _kStatLabelMovies = '收藏影片';

/// 统计卡标签：收藏合集
const String _kStatLabelBoxSets = '收藏合集';

/// 统计卡标签：收藏人物
const String _kStatLabelPeople = '收藏人物';

/// 统计卡间距
const double _kStatCardSpacing = 10.0;

/// 批量操作栏：已选择文本前缀
const String _kBulkSelectedPrefix = '已选择 ';

/// 批量操作栏：已选择文本后缀
const String _kBulkSelectedSuffix = ' 项';

/// 批量操作栏：空选择提示
const String _kBulkEmptyHint = '点击卡片进行选择';

/// 批量操作栏：有选择提示
const String _kBulkActionHint = '点击下方按钮执行批量操作';

/// 批量操作栏圆角
const double _kBulkBarBorderRadius = 18.0;

/// 批量操作栏水平边距
const double _kBulkBarHorizontalMargin = 16.0;

/// 批量操作栏底部边距
const double _kBulkBarBottomMargin = 16.0;

/// 批量操作栏计数容器尺寸
const double _kBulkCountContainerSize = 32.0;

/// 批量操作栏计数容器圆角
const double _kBulkCountContainerRadius = 10.0;

/// 批量操作栏计数字体大小
const double _kBulkCountFontSize = 13.0;

/// 批量操作栏标题字体大小
const double _kBulkTitleFontSize = 13.0;

/// 批量操作栏提示字体大小
const double _kBulkHintFontSize = 10.0;

/// 批量操作栏阴影模糊半径
const double _kBulkBarBlurRadius = 18.0;

/// 批量操作栏阴影偏移
const double _kBulkBarShadowOffset = 8.0;

// ===== 空状态和错误状态文本常量 =====

/// 空状态标题
const String _kEmptyStateTitle = '还没有收藏';

/// 空状态副标题
const String _kEmptyStateSubtitle = '双击视频即可收藏';

/// 空状态按钮文本
const String _kEmptyStateAction = '去逛逛';

/// 错误状态按钮文本
const String _kErrorStateAction = '重试';

/// 分组标题：收藏影片
const String _kGroupTitleMovies = '收藏影片';

/// 分组标题：收藏合集
const String _kGroupTitleBoxSets = '收藏合集';

/// 分组标题：收藏人物
const String _kGroupTitlePeople = '收藏人物';

/// 分组最近标签前缀
const String _kGroupRecentLabelPrefix = '按 ';

/// 分组最近标签后缀
const String _kGroupRecentLabelSuffix = ' 排序';

/// 加载失败标签
const String _kLoadFailedLabel = '加载失败';

/// 搜索框与统计卡间距
const double _kSearchStatsSpacing = 14.0;

/// 统计卡与内容区间距
const double _kStatsContentSpacing = 18.0;

/// 列表顶部内边距
const double _kListTopPadding = 12.0;

/// 列表底部内边距（普通模式）
const double _kListBottomPaddingNormal = 32.0;

/// 列表底部内边距（选择模式）
const double _kListBottomPaddingSelect = 120.0;

/// 合集分组标签前缀
const String _kGroupBoxSetsLabelPrefix = '';

/// 合集分组标签后缀
const String _kGroupBoxSetsLabelSuffix = ' 个系列';

/// 人物分组标签前缀
const String _kGroupPeopleLabelPrefix = '';

/// 人物分组标签后缀
const String _kGroupPeopleLabelSuffix = ' 位演员/导演';

/// 分组间距
const double _kGroupSpacing = 14.0;

// ===== 卡片组件常量 =====

/// 卡片选中时透明度
const double _kCardSelectedOpacity = 0.78;

/// 卡片选中动画时长（ms）
const int _kCardSelectedAnimationDuration = 150;

/// 卡片角标动画时长（ms）
const int _kCardBadgeAnimationDuration = 180;

/// 卡片角标位置偏移
const double _kCardBadgeOffset = 4.0;

/// 卡片角标尺寸
const double _kCardBadgeSize = 20.0;

/// 卡片角标圆角
const double _kCardBadgeRadius = 6.0;

/// 卡片角标边框宽度
const double _kCardBadgeBorderWidth = 1.6;

/// 卡片角标勾选图标尺寸
const double _kCardBadgeCheckIconSize = 13.0;

/// 卡片角标阴影模糊半径
const double _kCardBadgeShadowBlurRadius = 6.0;

/// 影片海报圆角
const double _kMoviePosterRadius = 10.0;

/// 影片海报最大宽度
const int _kMoviePosterMaxWidth = 260;

/// 影片海报边框透明度
const double _kMoviePosterBorderAlpha = 0.45;

// ===== 影片卡片角标和文本常量 =====

/// 评分角标圆角
const double _kRatingBadgeRadius = 6.0;

/// 评分角标背景透明度
const double _kRatingBadgeBgAlpha = 0.65;

/// 评分角标字体大小
const double _kRatingBadgeFontSize = 9.0;

/// 评分角标字间距
const double _kRatingBadgeLetterSpacing = 0.2;

/// 心形角标位置偏移
const double _kHeartBadgeOffset = 5.0;

/// 心形角标尺寸
const double _kHeartBadgeSize = 13.0;

/// 心形角标阴影模糊半径
const double _kHeartBadgeShadowBlurRadius = 3.0;

/// 心形角标阴影透明度
const double _kHeartBadgeShadowAlpha = 0.3;

/// 影片卡片标题字体大小
const double _kMovieTitleFontSize = 11.5;

/// 影片卡片标题行高
const double _kMovieTitleLineHeight = 1.18;

/// 影片卡片标题与副标题间距
const double _kMovieTitleSubtitleSpacing = 5.0;

/// 影片卡片副标题字体大小
const double _kMovieSubtitleFontSize = 10.0;

/// 影片卡片副标题与底部间距
const double _kMovieSubtitleBottomSpacing = 2.0;

/// 菜单顶部圆角
const double _kMenuTopRadius = 18.0;

/// 菜单标题字体大小
const double _kMenuTitleFontSize = 16.0;

/// 菜单内边距
const double _kMenuPadding = 20.0;

// ===== 菜单文本和 SnackBar 常量 =====

/// 菜单项：取消收藏
const String _kMenuItemRemoveFavorite = '取消收藏';

/// 菜单项：播放
const String _kMenuItemPlay = '播放';

/// 菜单项：查看详情
const String _kMenuItemViewDetails = '查看详情';

/// SnackBar：已取消收藏前缀
const String _kSnackBarRemovedPrefix = '已取消收藏「';

/// SnackBar：已取消收藏后缀
const String _kSnackBarRemovedSuffix = '」';

/// SnackBar：撤销
const String _kSnackBarUndo = '撤销';

/// SnackBar 时长（秒）
const int _kSnackBarDuration = 5;

/// 菜单底部间距
const double _kMenuBottomSpacing = 6.0;

/// AppBar 图标尺寸
const double _kAppBarIconSize = 22.0;

/// AppBar 标题间距
const double _kAppBarTitleSpacing = 8.0;

/// AppBar 计数间距
const double _kAppBarCountSpacing = 10.0;

/// AppBar 计数字体大小
const double _kAppBarCountFontSize = 13.0;

/// 加载指示器尺寸
const double _kLoadingIndicatorSize = 20.0;

/// 加载指示器线宽
const double _kLoadingIndicatorStrokeWidth = 2.0;

/// 影片网格列数
const int _kMovieGridCrossAxisCount = 3;

/// 人物网格列数
const int _kPersonGridCrossAxisCount = 4;

/// 影片网格宽高比
const double _kMovieGridChildAspectRatio = 0.62;

/// 人物网格宽高比
const double _kPersonGridChildAspectRatio = 0.72;

/// 网格主轴间距
const double _kGridMainAxisSpacing = 8.0;

/// 网格交叉轴间距
const double _kGridCrossAxisSpacing = 8.0;

/// 人物网格主轴间距
const double _kPersonGridMainAxisSpacing = 6.0;

/// 人物网格交叉轴间距
const double _kPersonGridCrossAxisSpacing = 6.0;

/// 影片网格预览数量
const int _kMovieGridPreviewCount = 6;

/// 人物网格预览数量
const int _kPersonGridPreviewCount = 8;

/// 全选复选框尺寸
const double _kSelectCheckboxSize = 20.0;

/// 全选复选框圆角
const double _kSelectCheckboxRadius = 6.0;

/// 全选复选框边框宽度
const double _kSelectCheckboxBorderWidth = 1.5;

/// 全选复选框勾选图标尺寸
const double _kSelectCheckIconSize = 13.0;

/// 全选提示字体大小
const double _kSelectHintFontSize = 11.0;

/// 全选提示间距
const double _kSelectHintSpacing = 8.0;

class FavoritesView extends ConsumerStatefulWidget {
  const FavoritesView({super.key});

  @override
  ConsumerState<FavoritesView> createState() => _FavoritesViewState();
}

class _FavoritesViewState extends ConsumerState<FavoritesView>
    with AutomaticKeepAliveClientMixin<FavoritesView> {
  @override
  bool get wantKeepAlive => true;

  // 搜索
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // 排序
  FavoritesSortMode _sortMode = FavoritesSortMode.defaultOrder;

  // 分组折叠状态：movie 默认展开，boxSet/person 默认折叠
  final Map<_FavGroup, bool> _groupOpen = {
    _FavGroup.movie: true,
    _FavGroup.boxSet: false,
    _FavGroup.person: false,
  };

  // 批量选择模式
  bool _selectMode = false;
  final Set<String> _selectedIds = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(favoritesProvider.notifier).loadFavorites();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ---------- 过滤 + 排序 ----------

  List<MediaItem> _filter(List<MediaItem> items) {
    var result = items;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result
          .where((item) => item.title.toLowerCase().contains(q))
          .toList();
    }
    return _sort(result);
  }

  List<MediaItem> _sort(List<MediaItem> items) {
    if (_sortMode == FavoritesSortMode.defaultOrder) return items;
    final sorted = List<MediaItem>.from(items);
    switch (_sortMode) {
      case FavoritesSortMode.nameAsc:
        sorted.sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case FavoritesSortMode.yearDesc:
        sorted.sort((a, b) {
          final ya = a.productionYear ?? a.year ?? 0;
          final yb = b.productionYear ?? b.year ?? 0;
          return yb.compareTo(ya);
        });
        break;
      case FavoritesSortMode.ratingDesc:
        sorted.sort((a, b) {
          final ra = a.displayRating ?? 0;
          final rb = b.displayRating ?? 0;
          return rb.compareTo(ra);
        });
        break;
      case FavoritesSortMode.defaultOrder:
        // 已在方法开头处理，这里不会到达
        break;
    }
    return sorted;
  }

  String get _sortLabel {
    switch (_sortMode) {
      case FavoritesSortMode.defaultOrder:
        return '默认';
      case FavoritesSortMode.nameAsc:
        return '名称';
      case FavoritesSortMode.yearDesc:
        return '年份';
      case FavoritesSortMode.ratingDesc:
        return '评分';
    }
  }

  // ---------- 批量选择 ----------

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _toggleSelectAll(Iterable<String> ids) {
    final allSelected = ids.every((id) => _selectedIds.contains(id));
    setState(() {
      if (allSelected) {
        _selectedIds.removeAll(ids);
      } else {
        _selectedIds.addAll(ids);
      }
    });
  }

  void _exitSelectMode() {
    setState(() {
      _selectMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _bulkUnfavorite() async {
    if (_selectedIds.isEmpty) return;
    final notifier = ref.read(favoritesProvider.notifier);
    final state = ref.read(favoritesProvider);
    // 从三组列表中找到对应 MediaItem
    final all = [...state.movies, ...state.boxSets, ...state.people];
    final targets =
        all.where((item) => _selectedIds.contains(item.id)).toList();
    if (targets.isEmpty) {
      _exitSelectMode();
      return;
    }

    // 捕获 ScaffoldMessenger（在 async gap 之前）
    final messenger = ScaffoldMessenger.of(context);

    // 逐条执行：乐观更新 + SnackBar 合并提示
    for (final item in targets) {
      await notifier.toggleFavorite(item);
    }

    final n = targets.length;
    _exitSelectMode();

    messenger.showSnackBar(
      SnackBar(
        content: Text('已批量取消收藏 $n 项'),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: '撤销',
          onPressed: () async {
            // 逐条重新收藏（撤销）
            for (final item in targets) {
              await notifier.toggleFavorite(item);
            }
            // 简单校验：至少一条失败则提示
            final anyFailed = targets.any((e) => !notifier.isFavorite(e.id));
            if (anyFailed) {
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('部分撤销失败，请重试'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  // ---------- Build ----------

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
          if (_selectMode)
            _buildBulkActionBar(scheme),
        ],
      ),
    );
  }

  // ---------- AppBar ----------

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
          icon: Icon(Icons.sort, color: scheme.onSurfaceVariant, size: _kAppBarIconSize),
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
              : Icon(Icons.refresh, color: scheme.onSurfaceVariant, size: _kAppBarIconSize),
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

  // ---------- Body：状态判断 + 内容 ----------

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
          16, _kListTopPadding, 16, _selectMode ? _kListBottomPaddingSelect : _kListBottomPaddingNormal),
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
            onRetry: () => ref.read(favoritesProvider.notifier).loadFavorites(),
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
                    onToggleAll: () => _toggleSelectAll(movies.map((e) => e.id)),
                    allSelected:
                        movies.isNotEmpty && movies.every((e) => _selectedIds.contains(e.id)),
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
            recentLabel: '$_kGroupBoxSetsLabelPrefix${state.boxSets.length}$_kGroupBoxSetsLabelSuffix',
            error: _searchQuery.isEmpty ? state.boxSetsError : null,
            onRetry: () => ref.read(favoritesProvider.notifier).loadFavorites(),
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
            recentLabel: '$_kGroupPeopleLabelPrefix${people.length}$_kGroupPeopleLabelSuffix',
            error: _searchQuery.isEmpty ? state.peopleError : null,
            onRetry: () => ref.read(favoritesProvider.notifier).loadFavorites(),
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

  String _recentLabel(String? err) {
    if (err != null) return _kLoadFailedLabel;
    return '$_kGroupRecentLabelPrefix$_sortLabel$_kGroupRecentLabelSuffix';
  }

  // ---------- 搜索 ----------

  Widget _buildSearchField(ColorScheme scheme) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_kSearchBorderRadius),
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        children: [
          Icon(Icons.search, size: _kSearchIconSize, color: scheme.onSurfaceVariant),
          const SizedBox(width: _kSearchIconSpacing),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: _kSearchHint,
                hintStyle: TextStyle(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: _kSearchVerticalPadding),
              ),
              style: TextStyle(color: scheme.onSurface, fontSize: _kSearchFontSize),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            GestureDetector(
              onTap: () {
                setState(() {
                  _searchQuery = '';
                  _searchController.clear();
                });
              },
              child: Icon(
                Icons.cancel,
                size: _kSearchIconSize,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
        ],
      ),
    );
  }

  // ---------- 统计卡 ----------

  Widget _buildStatsRow(ColorScheme scheme, FavoritesState state) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: _kStatLabelMovies,
            count: state.movies.length,
            icon: Icons.movie_outlined,
            bgColor: scheme.primary.withValues(alpha: 0.10),
            fgColor: scheme.primary,
          ),
        ),
        const SizedBox(width: _kStatCardSpacing),
        Expanded(
          child: _StatCard(
            label: _kStatLabelBoxSets,
            count: state.boxSets.length,
            icon: Icons.featured_play_list,
            bgColor: scheme.tertiary.withValues(alpha: 0.10),
            fgColor: scheme.tertiary,
          ),
        ),
        const SizedBox(width: _kStatCardSpacing),
        Expanded(
          child: _StatCard(
            label: _kStatLabelPeople,
            count: state.people.length,
            icon: Icons.person_outline,
            bgColor: scheme.error.withValues(alpha: 0.10),
            fgColor: scheme.error,
          ),
        ),
      ],
    );
  }

  // ---------- 批量操作底部栏 ----------

  Widget _buildBulkActionBar(ColorScheme scheme) {
    final n = _selectedIds.length;
    return Positioned(
      left: _kBulkBarHorizontalMargin,
      right: _kBulkBarHorizontalMargin,
      bottom: _kBulkBarBottomMargin + MediaQuery.of(context).padding.bottom,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_kBulkBarBorderRadius),
          color: scheme.surface.withValues(alpha: 0.95),
          border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: _kBulkBarBlurRadius,
              offset: const Offset(0, _kBulkBarShadowOffset),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          left: false,
          right: false,
          child: Row(
            children: [
              Container(
                width: _kBulkCountContainerSize,
                height: _kBulkCountContainerSize,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_kBulkCountContainerRadius),
                  color: scheme.primary.withValues(alpha: 0.18),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$n',
                  style: TextStyle(
                    color: scheme.primary,
                    fontSize: _kBulkCountFontSize,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$_kBulkSelectedPrefix$n$_kBulkSelectedSuffix',
                      style: const TextStyle(
                          fontSize: _kBulkTitleFontSize, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      n == 0 ? _kBulkEmptyHint : _kBulkActionHint,
                      style: TextStyle(
                        fontSize: _kBulkHintFontSize,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              _IconAction(
                icon: Icons.playlist_play,
                onTap: n == 0 ? null : () {}, // TODO: 移动到合集
              ),
              const SizedBox(width: 4),
              _IconAction(
                icon: Icons.download_for_offline_outlined,
                onTap: n == 0 ? null : () {}, // TODO: 批量下载
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: n == 0 ? null : _bulkUnfavorite,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: scheme.error.withValues(alpha: 0.15),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.favorite_border,
                        color: scheme.error,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '取消收藏',
                        style: TextStyle(
                          color: scheme.error,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyListHint(ColorScheme scheme, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// 子组件
// ============================================================

/// 统计卡
class _StatCard extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color bgColor;
  final Color fgColor;
  const _StatCard({
    required this.label,
    required this.count,
    required this.icon,
    required this.bgColor,
    required this.fgColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: bgColor,
            ),
            child: Icon(icon, color: fgColor, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// 可折叠分组：标题 + 状态/数量 + chevron + 内容
class _GroupSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accentColor;
  final int count;
  final String recentLabel;
  final String? error;
  final VoidCallback? onRetry;
  final bool isOpen;
  final VoidCallback onToggleOpen;
  final VoidCallback? onViewAll;
  final Widget child;

  const _GroupSection({
    super.key,
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.count,
    required this.recentLabel,
    required this.error,
    required this.onRetry,
    required this.isOpen,
    required this.onToggleOpen,
    required this.onViewAll,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行（可点击折叠）
          Material(
            color: Colors.transparent,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: InkWell(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              onTap: onToggleOpen,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: accentColor.withValues(alpha: 0.15),
                      ),
                      child: Icon(icon, color: accentColor, size: 17),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: scheme.onSurface,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 1.5),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  color: scheme.outlineVariant
                                      .withValues(alpha: 0.3),
                                ),
                                child: Text(
                                  '$count',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 1),
                          Text(
                            recentLabel,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: error != null
                                  ? scheme.error
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (onViewAll != null && count > 0)
                      TextButton(
                        onPressed: onViewAll,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '全部',
                              style: TextStyle(
                                  color: scheme.primary, fontSize: 12),
                            ),
                            const SizedBox(width: 1),
                            Icon(Icons.chevron_right,
                                color: scheme.primary, size: 16),
                          ],
                        ),
                      ),
                    const SizedBox(width: 2),
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: scheme.surface.withValues(alpha: 0.7),
                      ),
                      child: AnimatedRotation(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                        turns: isOpen ? 0.25 : 0,
                        child: Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),
          ),
          // 分组错误提示
          if (error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Row(
                children: [
                  Icon(Icons.error_outline,
                      color: scheme.error, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      error!,
                      style: TextStyle(color: scheme.error, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (onRetry != null)
                    TextButton(
                      onPressed: onRetry,
                      child: const Text('重试', style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
            ),
          // 分组内容（AnimatedCrossFade 平滑折叠）
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 280),
            firstCurve: Curves.easeOutCubic,
            secondCurve: Curves.easeOutCubic,
            sizeCurve: Curves.easeOutCubic,
            crossFadeState: isOpen
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

/// 图标按钮：批量操作栏用
class _IconAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _IconAction({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final disabled = onTap == null;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: scheme.onSurface.withValues(alpha: disabled ? 0.03 : 0.06),
          ),
          child: Icon(
            icon,
            size: 17,
            color: disabled
                ? scheme.onSurfaceVariant.withValues(alpha: 0.35)
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// 分组内容：影片网格 / 合集列表 / 人物网格
// ============================================================

/// 影片 3 列网格（可预览最多 6 张 + 加载更多 + 全选）
class _MovieGrid extends StatelessWidget {
  final List<MediaItem> items;
  final List<MediaItem> allItems;
  final bool selectMode;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggle;
  final VoidCallback onToggleAll;
  final bool allSelected;
  final bool hasMore;
  final VoidCallback onLoadMore;

  const _MovieGrid({
    required this.items,
    required this.allItems,
    required this.selectMode,
    required this.selectedIds,
    required this.onToggle,
    required this.onToggleAll,
    required this.allSelected,
    required this.hasMore,
    required this.onLoadMore,
  });

  // 预览数量：分组内只显示前 6 张（更多请进"全部"页面）
  static const int _previewMax = _kMovieGridPreviewCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final preview = items.take(_previewMax).toList();
    final showMoreTile = items.length > _previewMax || hasMore;

    return Column(
      children: [
        // 全选提示条
        if (selectMode && items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 4, 2, 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: onToggleAll,
                  child: Container(
                    width: _kSelectCheckboxSize,
                    height: _kSelectCheckboxSize,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(_kSelectCheckboxRadius),
                      border: Border.all(
                        color: allSelected
                            ? scheme.primary
                            : scheme.outlineVariant,
                        width: _kSelectCheckboxBorderWidth,
                      ),
                      color: allSelected ? scheme.primary : Colors.transparent,
                    ),
                    child: allSelected
                        ? Icon(Icons.check,
                            size: _kSelectCheckIconSize, color: scheme.onPrimary)
                        : null,
                  ),
                ),
                const SizedBox(width: _kSelectHintSpacing),
                Text(
                  allSelected ? '取消全选本组影片' : '全选本组影片',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: _kSelectHintFontSize,
                  ),
                ),
              ],
            ),
          ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _kMovieGridCrossAxisCount,
            childAspectRatio: _kMovieGridChildAspectRatio,
            crossAxisSpacing: _kGridCrossAxisSpacing,
            mainAxisSpacing: _kGridMainAxisSpacing,
          ),
          itemCount: preview.length + (showMoreTile ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == preview.length) {
              return _MoreTile(
                remaining: (items.length - _previewMax).clamp(0, 1 << 31),
                hasMore: hasMore,
                onTap: () => context.push('/favorites/category/movie'),
              );
            }
            final item = preview[index];
            return _SelectableCard(
              selectMode: selectMode,
              selected: selectedIds.contains(item.id),
              onTap: () => onToggle(item.id),
              child: _MoviePosterCard(
                item: item,
                allItems: allItems,
              ),
            );
          },
        ),
        if (hasMore)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _LoadMoreHint(onTap: onLoadMore),
          ),
      ],
    );
  }
}

/// 合集列表：横向 ListTile 风格
class _BoxSetList extends StatelessWidget {
  final List<MediaItem> items;
  final List<MediaItem> allItems;
  final bool selectMode;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggle;

  const _BoxSetList({
    required this.items,
    required this.allItems,
    required this.selectMode,
    required this.selectedIds,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 预览最多 3 条合集
    final preview = items.take(3).toList();
    final showMore = items.length > 3;
    return Column(
      children: [
        ...preview.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _SelectableCard(
              selectMode: selectMode,
              selected: selectedIds.contains(item.id),
              onTap: () => onToggle(item.id),
              child: _BoxSetTile(item: item),
            ),
          ),
        ),
        if (showMore)
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => context.push('/favorites/category/boxset'),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '还有 ${items.length - 3} 个合集 →',
                    style: TextStyle(
                      color: scheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// 人物 4 列头像网格
class _PersonGrid extends StatelessWidget {
  final List<MediaItem> items;
  final bool selectMode;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggle;

  const _PersonGrid({
    required this.items,
    required this.selectMode,
    required this.selectedIds,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final preview = items.take(_kPersonGridPreviewCount).toList();
    final showMore = items.length > _kPersonGridPreviewCount;
    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _kPersonGridCrossAxisCount,
            childAspectRatio: _kPersonGridChildAspectRatio,
            crossAxisSpacing: _kPersonGridCrossAxisSpacing,
            mainAxisSpacing: _kPersonGridMainAxisSpacing,
          ),
          itemCount: preview.length + (showMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == preview.length) {
              return _MorePersonTile(
                remaining: (items.length - _kPersonGridPreviewCount).clamp(0, 1 << 31),
                onTap: () => context.push('/favorites/category/person'),
              );
            }
            final item = preview[index];
            return _SelectableCard(
              selectMode: selectMode,
              selected: selectedIds.contains(item.id),
              onTap: () => onToggle(item.id),
              child: _PersonTile(item: item),
            );
          },
        ),
      ],
    );
  }
}

// ============================================================
// 原子组件：海报卡 / 合集卡 / 人物卡 / MoreTile / LoadMore
// ============================================================

/// 选择包装：左上角勾选角标（选择模式下可点击切换选中）
class _SelectableCard extends StatelessWidget {
  final bool selectMode;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  const _SelectableCard({
    required this.selectMode,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!selectMode) return child;
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Stack(
        children: [
          AnimatedOpacity(
            opacity: selected ? _kCardSelectedOpacity : 1,
            duration: const Duration(milliseconds: _kCardSelectedAnimationDuration),
            child: child,
          ),
          Positioned(
            top: _kCardBadgeOffset,
            left: _kCardBadgeOffset,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: _kCardBadgeAnimationDuration),
              curve: Curves.easeOutCubic,
              width: _kCardBadgeSize,
              height: _kCardBadgeSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_kCardBadgeRadius),
                border: Border.all(
                  color: selected ? scheme.primary : Colors.white.withValues(alpha: 0.85),
                  width: _kCardBadgeBorderWidth,
                ),
                color: selected ? scheme.primary : Colors.black.withValues(alpha: 0.35),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: scheme.primary.withValues(alpha: 0.35),
                          blurRadius: _kCardBadgeShadowBlurRadius,
                        ),
                      ]
                    : null,
              ),
              child: selected
                  ? Icon(Icons.check, size: _kCardBadgeCheckIconSize, color: scheme.onPrimary)
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// 影片海报卡（点击跳转播放/详情，长按菜单）
class _MoviePosterCard extends ConsumerWidget {
  final MediaItem item;
  final List<MediaItem> allItems;

  const _MoviePosterCard({
    required this.item,
    required this.allItems,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final authState = ref.watch(authProvider);
    final imageUrl = item.thumbnailUrlWithAuth(
      authState.embyServerUrl,
      authState.token,
      maxWidth: _kMoviePosterMaxWidth,
    );
    final headers = item.authHeaders(authState.token);

    return InkWell(
      borderRadius: BorderRadius.circular(_kMoviePosterRadius),
      onTap: () {
        ref
            .read(playbackListProvider.notifier)
            .setPlaybackList(allItems, item.id);
        context.push('/play/${item.id}', extra: item);
      },
      onLongPress: () => _showMenu(context, ref),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_kMoviePosterRadius),
                color: scheme.surfaceContainerHighest,
                border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: _kMoviePosterBorderAlpha)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_kMoviePosterRadius),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imageUrl != null && imageUrl.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: imageUrl,
                        cacheManager: AppImageCacheManager.thumbnail,
                        fit: BoxFit.cover,
                        httpHeaders: headers.isNotEmpty ? headers : null,
                        memCacheWidth: 400,
                        placeholder: (_, __) => Container(
                          color: scheme.surfaceContainerHighest,
                          child: Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: scheme.primary,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Center(
                          child: Icon(Icons.movie_outlined,
                              color: scheme.onSurfaceVariant, size: 30),
                        ),
                      )
                    else
                      Center(
                        child: Icon(Icons.movie_outlined,
                            color: scheme.onSurfaceVariant, size: 30),
                      ),
                    // 评分角标
                    if ((item.displayRating ?? 0) > 0)
                      Positioned(
                        top: _kHeartBadgeOffset,
                        right: _kHeartBadgeOffset,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(_kRatingBadgeRadius),
                            color: Colors.black.withValues(alpha: _kRatingBadgeBgAlpha),
                          ),
                          child: Text(
                            '★ ${item.displayRating!.toStringAsFixed(1)}',
                            style: TextStyle(
                              color: Colors.amber.shade300,
                              fontSize: _kRatingBadgeFontSize,
                              fontWeight: FontWeight.w700,
                              letterSpacing: _kRatingBadgeLetterSpacing,
                            ),
                          ),
                        ),
                      ),
                    // 心形角标
                    Positioned(
                      bottom: _kHeartBadgeOffset,
                      right: _kHeartBadgeOffset,
                      child: Icon(
                        Icons.favorite,
                        color: scheme.primary,
                        size: _kHeartBadgeSize,
                        shadows: [
                          Shadow(
                            color: scheme.onSurface.withValues(alpha: _kHeartBadgeShadowAlpha),
                            blurRadius: _kHeartBadgeShadowBlurRadius,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: _kMovieTitleSubtitleSpacing),
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: _kMovieTitleFontSize,
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
              height: _kMovieTitleLineHeight,
            ),
          ),
          const SizedBox(height: _kMovieSubtitleBottomSpacing),
          Text(
            _subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: _kMovieSubtitleFontSize,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String get _subtitle {
    final parts = <String>[];
    final y = item.productionYear ?? item.year;
    if (y != null) parts.add('$y');
    if (parts.isEmpty) return item.type;
    return parts.join(' · ');
  }

  void _showMenu(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(_kMenuTopRadius)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(_kMenuPadding, 16, _kMenuPadding, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: _kMenuTitleFontSize,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.favorite_border, color: scheme.error),
                title: Text(_kMenuItemRemoveFavorite,
                    style: TextStyle(color: scheme.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  final notifier = ref.read(favoritesProvider.notifier);
                  notifier.toggleFavorite(item);
                  final messenger = ScaffoldMessenger.of(context);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('$_kSnackBarRemovedPrefix${item.title}$_kSnackBarRemovedSuffix'),
                      action: SnackBarAction(
                        label: _kSnackBarUndo,
                        onPressed: () =>
                            _undoUnfavorite(messenger, notifier, item),
                      ),
                      duration: const Duration(seconds: _kSnackBarDuration),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.play_arrow, color: scheme.primary),
                title: Text(_kMenuItemPlay),
                onTap: () {
                  Navigator.pop(ctx);
                  ref
                      .read(playbackListProvider.notifier)
                      .setPlaybackList(allItems, item.id);
                  context.push('/play/${item.id}', extra: item);
                },
              ),
              ListTile(
                leading: Icon(Icons.info_outline,
                    color: scheme.onSurfaceVariant),
                title: const Text(_kMenuItemViewDetails),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/item/${item.id}', extra: item);
                },
              ),
              const SizedBox(height: _kMenuBottomSpacing),
            ],
          ),
        );
      },
    );
  }
}

/// 合集 ListTile
class _BoxSetTile extends ConsumerWidget {
  final MediaItem item;
  const _BoxSetTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final authState = ref.watch(authProvider);
    final imageUrl = item.thumbnailUrlWithAuth(
      authState.embyServerUrl,
      authState.token,
      maxWidth: 180,
    );
    final headers = item.authHeaders(authState.token);
    final year = item.productionYear ?? item.year;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => context.push('/boxset/${item.id}', extra: item),
      onLongPress: () => _showMenu(context, ref),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: scheme.surface.withValues(alpha: 0.7),
          border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            // 缩略方块
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: scheme.tertiary.withValues(alpha: 0.15),
              ),
              clipBehavior: Clip.antiAlias,
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      cacheManager: AppImageCacheManager.thumbnail,
                      fit: BoxFit.cover,
                      httpHeaders: headers.isNotEmpty ? headers : null,
                      errorWidget: (_, __, ___) => Center(
                        child: Icon(Icons.featured_play_list,
                            color: scheme.tertiary, size: 24),
                      ),
                    )
                  : Center(
                      child: Icon(Icons.featured_play_list,
                          color: scheme.tertiary, size: 24),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (year != null) '$year',
                      item.type,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 10.5, color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: scheme.outlineVariant.withValues(alpha: 0.25),
                        ),
                        child: Text(
                          '未看 2',
                          style: TextStyle(
                            fontSize: 10,
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      if ((item.displayRating ?? 0) > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: Colors.amber.withValues(alpha: 0.15),
                          ),
                          child: Text(
                            '★ ${item.displayRating!.toStringAsFixed(1)}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.amber.shade300,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: scheme.onSurfaceVariant, size: 18),
          ],
        ),
      ),
    );
  }

  void _showMenu(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  item.title,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.favorite_border, color: scheme.error),
                title: Text('取消收藏',
                    style: TextStyle(color: scheme.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  final notifier = ref.read(favoritesProvider.notifier);
                  notifier.toggleFavorite(item);
                  final messenger = ScaffoldMessenger.of(context);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('已取消收藏「${item.title}」'),
                      action: SnackBarAction(
                        label: '撤销',
                        onPressed: () =>
                            _undoUnfavorite(messenger, notifier, item),
                      ),
                      duration: const Duration(seconds: 5),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.info_outline,
                    color: scheme.onSurfaceVariant),
                title: const Text('查看详情'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/boxset/${item.id}', extra: item);
                },
              ),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
  }
}

/// 人物头像 + 名称
class _PersonTile extends ConsumerWidget {
  final MediaItem item;
  const _PersonTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final authState = ref.watch(authProvider);
    final imageUrl = item.thumbnailUrlWithAuth(
      authState.embyServerUrl,
      authState.token,
      maxWidth: 160,
    );
    final headers = item.authHeaders(authState.token);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => context.push('/person/${item.id}', extra: item),
      onLongPress: () => _showMenu(context, ref),
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.error.withValues(alpha: 0.12),
                border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.35)),
              ),
              clipBehavior: Clip.antiAlias,
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      cacheManager: AppImageCacheManager.thumbnail,
                      fit: BoxFit.cover,
                      httpHeaders: headers.isNotEmpty ? headers : null,
                      errorWidget: (_, __, ___) => Center(
                        child: Text(
                          item.title.isNotEmpty ? item.title[0].toUpperCase() : '?',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: scheme.error.withValues(alpha: 0.65),
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Icon(Icons.person,
                          color: scheme.error.withValues(alpha: 0.65), size: 22),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.5,
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  void _showMenu(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(item.title,
                    style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.favorite_border, color: scheme.error),
                title: Text('取消收藏',
                    style: TextStyle(color: scheme.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  final notifier = ref.read(favoritesProvider.notifier);
                  notifier.toggleFavorite(item);
                  final messenger = ScaffoldMessenger.of(context);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('已取消收藏「${item.title}」'),
                      action: SnackBarAction(
                        label: '撤销',
                        onPressed: () =>
                            _undoUnfavorite(messenger, notifier, item),
                      ),
                      duration: const Duration(seconds: 5),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.info_outline,
                    color: scheme.onSurfaceVariant),
                title: const Text('查看详情'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/person/${item.id}', extra: item);
                },
              ),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
  }
}

/// 影片/人物：更多卡片
class _MoreTile extends StatelessWidget {
  final int remaining;
  final bool hasMore;
  final VoidCallback onTap;
  const _MoreTile({
    required this.remaining,
    required this.hasMore,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final suffix = hasMore ? '…' : '';
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: scheme.outlineVariant.withValues(alpha: 0.18),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.4),
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.grid_view_outlined,
                color: scheme.onSurfaceVariant, size: 24),
            const SizedBox(height: 6),
            Text(
              '+$remaining$suffix',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              '查看全部',
              style: TextStyle(
                fontSize: 9.5,
                color: scheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MorePersonTile extends StatelessWidget {
  final int remaining;
  final VoidCallback onTap;
  const _MorePersonTile({required this.remaining, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.outlineVariant.withValues(alpha: 0.2),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.4),
                  style: BorderStyle.solid,
                ),
              ),
              child: Center(
                child: Text(
                  '+$remaining',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '更多',
            style: TextStyle(
              fontSize: 10.5,
              color: scheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadMoreHint extends StatelessWidget {
  final VoidCallback onTap;
  const _LoadMoreHint({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.expand_more, size: 14, color: scheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              '点击加载更多（查看全部完整列表）',
              style: TextStyle(
                fontSize: 10.5,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 搜索无结果提示卡：给出明确无结果文案 + 一键清空搜索词「返回」全量列表
///
/// 设计动机：用户输入一个不存在的词后，若直接让搜索框消失就会「无法返回」；
/// 这里同时保留搜索框（用户可点 × 清空）并增加显式「清空搜索词」按钮，
/// 提供双路径返回全量收藏内容。
class _SearchNoResultHint extends StatelessWidget {
  final String query;
  final VoidCallback onClear;

  const _SearchNoResultHint({
    required this.query,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(18, 26, 18, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        border:
            Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 56, color: scheme.onSurfaceVariant),
          const SizedBox(height: 14),
          Text(
            '没有找到「$query」',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '可以换个关键词试试，或直接清空搜索词返回全部收藏',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.clear_all, size: 16),
                label: const Text('清空搜索词'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: scheme.primary,
                  side: BorderSide(
                      color: scheme.primary.withValues(alpha: 0.55)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 撤销取消收藏
// ============================================================

/// 撤销取消收藏：重新收藏，失败时提示用户
///
/// 与原实现一致：FavoritesNotifier.toggleFavorite 采用乐观更新 + 失败回滚，
/// 通过 isFavorite 判定撤销结果，避免依赖异常机制。
Future<void> _undoUnfavorite(
  ScaffoldMessengerState messenger,
  FavoritesNotifier notifier,
  MediaItem item,
) async {
  await notifier.toggleFavorite(item);
  if (!notifier.isFavorite(item.id)) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('撤销失败，请重试'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

// ============================================================
// 二级分类详情页（保持原有实现，不改动）
// FavoritesCategoryView / _GridCard
// ============================================================

class FavoritesCategoryView extends ConsumerStatefulWidget {
  final FavoritesCategory category;
  const FavoritesCategoryView({super.key, required this.category});

  @override
  ConsumerState<FavoritesCategoryView> createState() =>
      _FavoritesCategoryViewState();
}

class _FavoritesCategoryViewState
    extends ConsumerState<FavoritesCategoryView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(favoritesProvider.notifier).ensureLoaded();
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final offset = _scrollController.position.pixels;
    final maxExtent = _scrollController.position.maxScrollExtent;
    if (offset >= maxExtent - 300) {
      final state = ref.read(favoritesProvider);
      final hasMore = switch (widget.category) {
        FavoritesCategory.movie => state.hasMoreMovies,
        FavoritesCategory.boxSet => state.hasMoreBoxSets,
        FavoritesCategory.person => state.hasMorePeople,
      };
      if (hasMore && !state.isLoadingMore) {
        ref.read(favoritesProvider.notifier).loadMore(widget.category);
      }
    }
  }

  String get _title {
    return switch (widget.category) {
      FavoritesCategory.movie => '收藏影片',
      FavoritesCategory.boxSet => '收藏合集',
      FavoritesCategory.person => '收藏人物',
    };
  }

  List<MediaItem> _items(FavoritesState state) {
    return switch (widget.category) {
      FavoritesCategory.movie => state.movies,
      FavoritesCategory.boxSet => state.boxSets,
      FavoritesCategory.person => state.people,
    };
  }

  String? _error(FavoritesState state) {
    return switch (widget.category) {
      FavoritesCategory.movie => state.moviesError,
      FavoritesCategory.boxSet => state.boxSetsError,
      FavoritesCategory.person => state.peopleError,
    };
  }

  bool _hasMore(FavoritesState state) {
    return switch (widget.category) {
      FavoritesCategory.movie => state.hasMoreMovies,
      FavoritesCategory.boxSet => state.hasMoreBoxSets,
      FavoritesCategory.person => state.hasMorePeople,
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final state = ref.watch(favoritesProvider);
    final items = _items(state);
    final error = _error(state);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_title),
            const SizedBox(width: 8),
            Text(
              '${items.length}',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: state.isLoading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.onSurfaceVariant,
                    ),
                  )
                : Icon(Icons.refresh,
                    color: scheme.onSurfaceVariant, size: 22),
            onPressed: state.isLoading
                ? null
                : () => ref.read(favoritesProvider.notifier).loadFavorites(),
            tooltip: '刷新',
          ),
        ],
      ),
      body: _buildBody(state, items, error, scheme),
    );
  }

  Widget _buildBody(
    FavoritesState state,
    List<MediaItem> items,
    String? error,
    ColorScheme scheme,
  ) {
    if (state.isLoading && items.isEmpty && error == null) {
      return Center(child: CircularProgressIndicator(color: scheme.primary));
    }

    if (error != null && items.isEmpty) {
      return ErrorStateCard(
        title: error,
        actionLabel: '重试',
        onAction: () => ref.read(favoritesProvider.notifier).loadFavorites(),
      );
    }

    if (items.isEmpty) {
      return EmptyStateCard.noFavorites();
    }

    final crossAxisCount = widget.category == FavoritesCategory.person ? 4 : 3;
    final aspectRatio =
        widget.category == FavoritesCategory.person ? 0.7 : 0.65;
    final hasMore = _hasMore(state);

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: aspectRatio,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: items.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (hasMore && index == items.length) {
          return Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.primary,
              ),
            ),
          );
        }
        final item = items[index];
        return _GridCard(
          key: Key(item.id),
          item: item,
          category: widget.category,
          allItems: items,
        );
      },
    );
  }
}

class _GridCard extends ConsumerWidget {
  final MediaItem item;
  final FavoritesCategory category;
  final List<MediaItem> allItems;

  const _GridCard({
    super.key,
    required this.item,
    required this.category,
    required this.allItems,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final authState = ref.watch(authProvider);
    final imageUrl = item.thumbnailUrlWithAuth(
      authState.embyServerUrl,
      authState.token,
      maxWidth: 300,
    );
    final headers = item.authHeaders(authState.token);

    return InkWell(
      onTap: () => _navigateTo(context, ref),
      onLongPress: () => _showLongPressMenu(context, ref),
      borderRadius: BorderRadius.circular(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: scheme.surfaceContainerHighest,
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imageUrl != null && imageUrl.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: imageUrl,
                        cacheManager: AppImageCacheManager.thumbnail,
                        fit: BoxFit.cover,
                        httpHeaders: headers.isNotEmpty ? headers : null,
                        memCacheWidth: 600,
                        placeholder: (_, __) => Container(
                          color: scheme.surfaceContainerHighest,
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: scheme.primary,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        ),
                        errorWidget: (_, __, ___) =>
                            _gridPlaceholder(category, scheme),
                      )
                    else
                      _gridPlaceholder(category, scheme),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Icon(
                        Icons.favorite,
                        color: scheme.primary,
                        size: 16,
                        shadows: [
                          Shadow(
                            color: scheme.onSurface.withValues(alpha: 0.3),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _subtitle(item),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _gridPlaceholder(FavoritesCategory cat, ColorScheme scheme) {
    final icon = switch (cat) {
      FavoritesCategory.person => Icons.person,
      FavoritesCategory.boxSet => Icons.featured_play_list,
      FavoritesCategory.movie => Icons.movie_outlined,
    };
    return Center(child: Icon(icon, color: scheme.onSurfaceVariant, size: 36));
  }

  String _subtitle(MediaItem item) {
    if (category == FavoritesCategory.person) return '演员';
    final parts = <String>[];
    final year = item.productionYear ?? item.year;
    if (year != null) parts.add(year.toString());
    final rating = item.displayRating;
    if (rating != null && rating > 0) {
      parts.add('★ ${rating.toStringAsFixed(1)}');
    }
    if (parts.isEmpty) return item.type;
    return parts.join(' · ');
  }

  void _navigateTo(BuildContext context, WidgetRef ref) {
    switch (category) {
      case FavoritesCategory.movie:
        ref
            .read(playbackListProvider.notifier)
            .setPlaybackList(allItems, item.id);
        context.push('/play/${item.id}', extra: item);
        break;
      case FavoritesCategory.boxSet:
        context.push('/boxset/${item.id}', extra: item);
        break;
      case FavoritesCategory.person:
        context.push('/person/${item.id}', extra: item);
        break;
    }
  }

  void _showLongPressMenu(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.favorite_border, color: scheme.error),
                title: Text('取消收藏',
                    style: TextStyle(color: scheme.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  final notifier = ref.read(favoritesProvider.notifier);
                  notifier.toggleFavorite(item);
                  final messenger = ScaffoldMessenger.of(context);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('已取消收藏「${item.title}」'),
                      action: SnackBarAction(
                        label: '撤销',
                        onPressed: () =>
                            _undoUnfavorite(messenger, notifier, item),
                      ),
                      duration: const Duration(seconds: 5),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              if (category == FavoritesCategory.movie)
                ListTile(
                  leading: Icon(Icons.play_arrow, color: scheme.primary),
                  title: const Text('播放'),
                  onTap: () {
                    Navigator.pop(ctx);
                    ref
                        .read(playbackListProvider.notifier)
                        .setPlaybackList(allItems, item.id);
                    context.push('/play/${item.id}', extra: item);
                  },
                ),
              ListTile(
                leading:
                    Icon(Icons.info_outline, color: scheme.onSurfaceVariant),
                title: const Text('查看详情'),
                onTap: () {
                  Navigator.pop(ctx);
                  switch (category) {
                    case FavoritesCategory.movie:
                      context.push('/item/${item.id}', extra: item);
                      break;
                    case FavoritesCategory.boxSet:
                      context.push('/boxset/${item.id}', extra: item);
                      break;
                    case FavoritesCategory.person:
                      context.push('/person/${item.id}', extra: item);
                      break;
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
