// 从 synology_music_view.dart 拆分（part 文件，无行为变化）

part of '../synology_music_view.dart';

// ==================== 布局与样式常量 ====================

// ===== 音乐库 UI 常量（避免魔法数字，提升可维护性）=====

/// 超小字体（时间戳、辅助信息）
const double _kFontSizeTiny = 10;

/// 小字体（标签、副标题）
const double _kFontSizeSmall = 12;

/// 中等字体（列表项正文）
const double _kFontSizeBody = 13;

/// 中字体（标题、按钮）
const double _kFontSizeMedium = 14;

/// 大字体（页面标题、歌手名）
const double _kFontSizeLarge = 16;

/// 超小间距
const double _kSpacingXSmall = 2;

/// 中间距
const double _kSpacingMedium = 6;

/// 大间距
const double _kSpacingLarge = 8;

/// 超大间距
const double _kSpacingXLarge = 10;

/// 特大间距
const double _kSpacingXXLarge = 12;

/// 巨大间距
const double _kSpacingXXXLarge = 16;

/// 最大间距
const double _kSpacingXXXXLarge = 20;

// ===== 快捷入口颜色常量（避免硬编码，支持主题扩展）=====

/// 快捷入口：歌曲 - 蓝色
const Color _kQuickEntryColorSongs = Color(0xFF4A90D9);

/// 快捷入口：专辑 - 橙色
const Color _kQuickEntryColorAlbums = Color(0xFFE67E22);

/// 快捷入口：歌手 - 紫色
const Color _kQuickEntryColorArtists = Color(0xFF9B59B6);

/// 快捷入口：歌单 - 绿色
const Color _kQuickEntryColorPlaylists = Color(0xFF27AE60);

/// 快捷入口：流派 - 青色
const Color _kQuickEntryColorGenres = Color(0xFF1ABC9C);

/// 快捷入口：文件夹 - 蓝色
const Color _kQuickEntryColorFolders = Color(0xFF3498DB);

/// 快捷入口：Random100 - 红色
const Color _kQuickEntryColorRandom = Color(0xFFE74C3C);

/// 快捷入口：设置 - 灰色
const Color _kQuickEntryColorSettings = Color(0xFF7F8C8D);

// ===== 音乐流派渐变色常量 =====

/// 音乐流派卡片渐变色组（6组循环使用）
const List<List<Color>> _kGenreGradients = [
  [Color(0xFF667EEA), Color(0xFF764BA2)],
  [Color(0xFFF093FB), Color(0xFFF5576C)],
  [Color(0xFF4FACFE), Color(0xFF00F2FE)],
  [Color(0xFF43E97B), Color(0xFF38F9D7)],
  [Color(0xFFFFD26F), Color(0xFFFF9472)],
  [Color(0xFFA18CD1), Color(0xFFFBC2EB)],
];

// ===== 列表/网格布局常量 =====

/// 歌曲列表：封面尺寸
const double _kSongCoverSize = 46.0;

/// 歌曲列表：水平内边距
const double _kSongListHorizontalPadding = 12.0;

/// 歌曲列表：垂直内边距
const double _kSongListVerticalPadding = 4.0;

/// 歌曲列表：圆角
const double _kSongListBorderRadius = 12.0;

/// 专辑网格：列数
const int _kAlbumGridCrossAxisCount = 2;

/// 专辑网格：宽高比
const double _kAlbumGridChildAspectRatio = 0.78;

/// 专辑网格：主轴间距
const double _kAlbumGridMainAxisSpacing = 16.0;

/// 专辑网格：交叉轴间距
const double _kAlbumGridCrossAxisSpacing = 14.0;

/// 专辑网格：圆角
const double _kAlbumGridBorderRadius = 14.0;

/// 歌手网格：列数
const int _kArtistGridCrossAxisCount = 3;

/// 歌手网格：宽高比
const double _kArtistGridChildAspectRatio = 0.82;

/// 歌手网格：主轴间距
const double _kArtistGridMainAxisSpacing = 14.0;

/// 歌手网格：交叉轴间距
const double _kArtistGridCrossAxisSpacing = 12.0;

/// 加载指示器：尺寸
const double _kLoadingIndicatorSize = 20.0;

/// 加载指示器：线宽
const double _kLoadingIndicatorStrokeWidth = 2.0;

// ===== 歌单列表布局常量 =====

/// 歌单网格：列数
const int _kPlaylistGridCrossAxisCount = 2;

/// 歌单网格：宽高比
const double _kPlaylistGridChildAspectRatio = 0.95;

/// 歌单网格：主轴间距
const double _kPlaylistGridMainAxisSpacing = 14.0;

/// 歌单网格：交叉轴间距
const double _kPlaylistGridCrossAxisSpacing = 14.0;

/// 歌单网格：圆角
const double _kPlaylistGridBorderRadius = 14.0;

/// 歌单封面图标尺寸
const double _kPlaylistCoverIconSize = 40.0;

/// 歌单列表渐变色组（6组循环使用，QQ音乐/酷狗歌单卡风格）
const List<List<Color>> _kPlaylistGradients = [
  [Color(0xFF5B8DEF), Color(0xFF8E6BF0)],
  [Color(0xFF26B8A0), Color(0xFF3F9DE0)],
  [Color(0xFFF07B5B), Color(0xFFF0A94F)],
  [Color(0xFFE05B8D), Color(0xFF8E5BF0)],
  [Color(0xFF3FA7D8), Color(0xFF6B8FE0)],
  [Color(0xFF6BC75B), Color(0xFF3FA7A0)],
];

// ===== 通用布局常量 =====

/// 导航栏搜索框宽度
const double _kSearchBarWidth = 48.0;

/// 列表项水平内边距
const double _kListItemHorizontalPadding = 16.0;

/// 列表项间距
const double _kListItemSpacing = 8.0;

/// 模块标题上下间距
const double _kSectionTitleTopPadding = 12.0;
const double _kSectionTitleBottomPadding = 24.0;

/// 顶部留白
const double _kTopSpacing = 60.0;

// ===== 首页模块标题常量 =====

/// 首页模块：最近播放
const String _kHomeSectionRecentPlaybacks = '最近播放';

/// 首页模块：最近添加
const String _kHomeSectionRecentAlbums = '最近添加';

/// 首页模块：我的锁定
const String _kHomeSectionPins = '我的锁定';

/// 首页模块：我的歌单
const String _kHomeSectionPlaylists = '我的歌单';

/// 首页模块：精选专辑
const String _kHomeSectionFeaturedAlbums = '精选专辑';

/// 首页模块：热门艺术家
const String _kHomeSectionTopArtists = '热门艺术家';

/// 首页模块：音乐流派
const String _kHomeSectionGenres = '音乐流派';

/// 首页模块：全空占位文本
const String _kHomeEmptyText = '音乐库暂无内容';

/// 精选专辑数量
const int _kFeaturedAlbumsCount = 12;

/// 首页歌单展示数量
const int _kHomePlaylistsCount = 8;

// ===== 卡片布局常量 =====

/// 最近播放卡片：小屏宽度
const double _kRecentCardWidthSmall = 100.0;

/// 最近播放卡片：中屏宽度
const double _kRecentCardWidthMedium = 110.0;

/// 最近播放卡片：大屏宽度
const double _kRecentCardWidthLarge = 120.0;

/// 最近播放卡片：小屏宽度阈值
const double _kRecentCardSmallThreshold = 360.0;

/// 最近播放卡片：中屏宽度阈值
const double _kRecentCardMediumThreshold = 414.0;

/// 卡片圆角
const double _kCardBorderRadius = 10.0;

/// 卡片间距
const double _kCardSpacing = 12.0;

// ===== 播放按钮常量 =====

/// 悬浮播放按钮：尺寸
const double _kPlayButtonSize = 32.0;

/// 悬浮播放按钮：图标尺寸
const double _kPlayButtonIconSize = 18.0;

/// 悬浮播放按钮：边距
const double _kPlayButtonMargin = 4.0;

// ===== 模块标题常量 =====

/// 模块标题：字号
const double _kSectionTitleFontSize = 17.0;

/// 模块标题：字重
const FontWeight _kSectionTitleFontWeight = FontWeight.w700;

/// 更多按钮：字号
const double _kMoreButtonFontSize = 14.0;

/// 更多按钮：图标尺寸
const double _kMoreButtonIconSize = 18.0;

// ===== 空状态常量 =====

/// 空状态：图标尺寸
const double _kEmptyIconSize = 56.0;

/// 空状态：图标与文字间距
const double _kEmptyIconTextSpacing = 24.0;

/// 快捷入口高度
const double _kQuickEntriesHeight = 72.0;
