// 设置页面常量定义
// 从 settings_view.dart 分离，提升代码可维护性

part of '../settings_view.dart';

// ===== 设置页面 UI 常量（避免魔法数字，提升可维护性）=====

/// 超小字体（辅助信息、时间戳）
const double _kFontSizeTiny = 11;

/// 小字体（标签、副标题）
const double _kFontSizeSmall = 12;

/// 中等字体（列表项正文、设置值）
const double _kFontSizeBody = 13;

/// 中字体（标题、按钮）
const double _kFontSizeMedium = 14;

/// 大字体（分组标题、重要值）
const double _kFontSizeLarge = 15;

/// 超大字体（页面标题、对话框标题）
const double _kFontSizeXLarge = 16;

/// 特大字体（强调标题）
const double _kFontSizeXXLarge = 18;

/// 最大字体（捐赠/关于页面大标题）
const double _kFontSizeXXXLarge = 20;

/// 超小间距
const double _kSpacingXSmall = 4;

/// 小间距
const double _kSpacingSmall = 6;

/// 中间距
const double _kSpacingMedium = 8;

/// 大间距
const double _kSpacingLarge = 10;

/// 超大间距
const double _kSpacingXLarge = 12;

/// 特大间距
const double _kSpacingXXLarge = 16;

/// 巨大间距
const double _kSpacingXXXLarge = 20;

/// 最大间距（页面底部留白）
const double _kSpacingXXXXLarge = 32;

// ===== 分组标题和卡片容器常量 =====

/// 分组标题图标容器尺寸
const double _kSectionIconContainerSize = 28.0;

/// 分组标题图标容器圆角
const double _kSectionIconContainerRadius = 7.0;

/// 分组标题图标尺寸
const double _kSectionIconSize = 16.0;

/// 分组标题图标与文字间距
const double _kSectionIconTextSpacing = 8.0;

/// 分组标题字间距
const double _kSectionTitleLetterSpacing = 0.5;

/// 分组标题垂直内边距
const double _kSectionTitleVerticalPadding = 10.0;

/// 分组标题顶部内边距
const double _kSectionTitleTopPadding = 24.0;

/// 分组卡片圆角
const double _kSectionCardRadius = 16.0;

/// 分组卡片水平边距
const double _kSectionCardHorizontalMargin = 16.0;

/// 分组卡片边框宽度
const double _kSectionCardBorderWidth = 0.5;

/// 分组卡片边框透明度
const double _kSectionCardBorderAlpha = 0.06;

/// 列表项分隔线缩进
const double _kDividerIndent = 56.0;

// ===== 设置项组件常量 =====

/// 设置项图标容器尺寸
const double _kTileIconContainerSize = 36.0;

/// 设置项图标容器圆角
const double _kTileIconContainerRadius = 8.0;

/// 设置项图标容器背景透明度
const double _kTileIconContainerBgAlpha = 0.12;

/// 设置项图标尺寸
const double _kTileIconSize = 20.0;

/// 设置项副标题透明度
const double _kTileSubtitleAlpha = 0.8;

// ===== 对话框常量 =====

/// 对话框关闭按钮文本
const String _kDialogCloseLabel = '关闭';

// ===== 手势项常量 =====

/// 手势项图标尺寸
const double _kGestureItemIconSize = 24.0;

/// 手势项图标与文字间距
const double _kGestureItemIconSpacing = 12.0;

// ===== 对话框标题常量 =====

/// 对话框：选择主题
const String _kDialogSelectTheme = '选择主题';

// ===== 设置项标题常量 =====

/// 设置项：视频流使用
const String _kTitleFeedLibrary = '视频流使用';

/// 设置项：排除已观看
const String _kTitleExcludePlayed = '排除已观看';

/// 设置项：自动播放
const String _kTitleAutoPlay = '自动播放';

/// 设置项：默认播放倍速
const String _kTitlePlaybackRate = '默认播放倍速';

/// 设置项：手势控制
const String _kTitleGestureControl = '手势控制';

/// 设置项：主题
const String _kTitleTheme = '主题';

/// 设置项：批量补全歌手元数据
const String _kTitleBatchScan = '批量补全歌手元数据';

/// 提示：请先登录群晖音乐服务器
const String _kHintLoginFirst = '请先登录群晖音乐服务器';

/// 提示：音乐库中没有歌手
const String _kHintNoArtists = '音乐库中没有歌手';

/// SnackBar 时长（秒）
const int _kSnackBarDurationShort = 2;

// ===== 设置项副标题常量 =====

/// 副标题：自动播放说明
const String _kSubtitleAutoPlay = '视频结束后自动播放下一个';

/// 副标题：手势控制说明
const String _kSubtitleGestureControl = '查看手势说明';
