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
part 'favorites_widgets.dart';
part 'favorites_widgets_cards.dart';
part 'favorites_widgets_more.dart';
part 'favorites_actions.dart';
part 'favorites_parts/favorites_view_build.dart';

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

  // ---------- Build ----------

  @override

  // ---------- AppBar ----------

  // ---------- Body：状态判断 + 内容 ----------

  // ---------- 搜索 ----------

  // ---------- 统计卡 ----------

  // ---------- 批量操作底部栏 ----------
  @override
  Widget build(BuildContext context) => _buildPage(context);
}

// ============================================================
// 子组件
// ============================================================

/// 统计卡
class FavoritesCategoryView extends ConsumerStatefulWidget {
  const FavoritesCategoryView({super.key, required this.category});
  final FavoritesCategory category;

  @override
  ConsumerState<FavoritesCategoryView> createState() =>
      _FavoritesCategoryViewState();
}
