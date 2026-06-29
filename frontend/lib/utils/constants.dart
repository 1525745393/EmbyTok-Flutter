// 应用全局常量

const int kDefaultPageLimit = 20;
const String kAppName = 'EmbyTok';
const String kStorageKeyConfig = 'embbytok_config';
const String kStorageKeyHistory = 'embbytok_history';
const String kStorageKeySearchHistory = 'embbytok_search_history';
const String kStorageKeySubtitle = 'embbytok_subtitle';
const String kStorageKeyPlaybackRate = 'embbytok_playback_rate';

// 设备模式
const String kDeviceModeTv = 'tv';
const String kDeviceModeStandard = 'standard';

// 浏览模式
// 注：kFeedTypeRecommend 已移除（PR #57），推荐改为独立路由 /recommend
const String kFeedTypeLatest = 'latest';
const String kFeedTypeRandom = 'random';
const String kFeedTypeFavorites = 'favorites';
const String kFeedTypeResume = 'resume';

// 视图模式
const String kViewModeFeed = 'feed';
const String kViewModeGrid = 'grid';

// 方向模式
const String kOrientationModeVertical = 'vertical';
const String kOrientationModeHorizontal = 'horizontal';
const String kOrientationModeBoth = 'both';

// 存储键
const String kStorageKeyForceDeviceMode = 'embbytok_force_device_mode';
const String kStorageKeyFeedType = 'embbytok_feed_type';
const String kStorageKeyViewMode = 'embbytok_view_mode';
const String kStorageKeyOrientationMode = 'embbytok_orientation_mode';
const String kStorageKeyIsMuted = 'embbytok_is_muted';
const String kStorageKeyIsAutoPlay = 'embbytok_is_autoplay';
const String kStorageKeyHiddenLibraryIds = 'embbytok_hidden_library_ids';
const String kStorageKeyDefaultPlaybackRate = 'embbytok_default_playback_rate';
const String kStorageKeyDefaultSubtitleLanguage = 'embbytok_default_subtitle_language';
const String kStorageKeyVideoQuality = 'embbytok_video_quality';
const String kStorageKeySubtitleSize = 'embbytok_subtitle_size';
// PR #78：推荐规则偏好（评分阈值 / 时长过滤 / 排除已观看）
const String kStorageKeyRecommendMinRating = 'embbytok_recommend_min_rating';
const String kStorageKeyRecommendExcludePlayed = 'embbytok_recommend_exclude_played';
const String kStorageKeyRecommendMinRuntimeSec = 'embbytok_recommend_min_runtime_sec';
// PR #79：推荐 - 类型偏好（Movie/Episode/Video/MusicVideo/Series 的子集）
const String kStorageKeyRecommendIncludeTypes = 'embbytok_recommend_include_types';
// PR #85：推荐 - 用户控制（完播率门控开关 + 时间衰减半衰期）
const String kStorageKeyRecommendUseWatchHistory =
    'embbytok_recommend_use_watch_history';
const String kStorageKeyRecommendHalfLifeDays =
    'embbytok_recommend_half_life_days';
// PR #88：推荐 - 反推荐疲劳（30 天内不重推）
const String kStorageKeyRecommendAntiFatigueEnabled =
    'embbytok_recommend_anti_fatigue_enabled';
const String kStorageKeyRecommendAntiFatigueDays =
    'embbytok_recommend_anti_fatigue_days';
const String kStorageKeyRecentlyShownItemIds =
    'embbytok_recently_shown_item_ids';
// PR #89：推荐 - 用户评分加权（Emby UserData.Rating 0-10）
// - 开启时：用户评分 < 阈值的 item 跳过（除非收藏）
// - 关闭时：仅按 communityRating 过滤（已有逻辑）
const String kStorageKeyRecommendUserRatingEnabled =
    'embbytok_recommend_user_rating_enabled';
const String kStorageKeyRecommendUserRatingMin =
    'embbytok_recommend_user_rating_min';
// PR #78：推荐结果本地缓存（30 分钟内启动直接用缓存）
const String kStorageKeyRecommendCache = 'embytok_recommend_cache';
const String kStorageKeyRecommendCacheTime = 'embytok_recommend_cache_time';
const int kRecommendCacheMaxAgeSec = 30 * 60; // 30 分钟
// PR #81：完播率统计（按 userId 分键，最多保留 500 条）
const String kStorageKeyWatchStats = 'embytok_watch_stats';
const String kStorageKeyLastPageIndex = 'embbytok_last_page_index';
const String kStorageKeyLastGridScrollOffset = 'embbytok_last_grid_scroll_offset';
const String kStorageKeySelectedLibraryId = 'embbytok_selected_library_id';
// 媒体库选择：推荐页独立（PR #66：视频流 / 推荐可分别设置）
const String kStorageKeySelectedLibraryIdForRecommend =
    'embbytok_selected_library_id_for_recommend';
// 媒体库首次配置标记（PR #66：未配置时进入对应页面自动弹 LibrarySelector）
const String kStorageKeyFeedLibraryConfigured = 'embbytok_feed_library_configured';
const String kStorageKeyRecommendLibraryConfigured =
    'embbytok_recommend_library_configured';
const String kStorageKeyActorsCache = 'embbytok_actors_cache';
const String kStorageKeyActorsCacheTime = 'embbytok_actors_cache_time';
const String kStorageKeyActorsCachePrefix = 'embbytok_actors_cache_';
const String kStorageKeyActorsCacheTimePrefix = 'embbytok_actors_cache_time_';
const String kStorageKeyActorsSelectedType = 'embbytok_actors_selected_type';
const String kStorageKeyActorsSelectedTab = 'embbytok_actors_selected_tab';
const String kStorageKeyActorsSearchQuery = 'embbytok_actors_search_query';
const String kStorageKeyActorsScrollOffset = 'embbytok_actors_scroll_offset';

const int kMaxSearchHistory = 10;
const double kDefaultPlaybackRate = 1.0;
const double kLongPressPlaybackRate = 2.0;
const int kDebounceMs = 300;
const int kDoubleTapMs = 300;
const int kSeekPerPixelMs = 100;

// 视频切换与引导动画时长（毫秒）
const int kVideoFadeInMs = 200;
const int kGuideFadeMs = 500;
const double kGuideSlideDistance = 40.0;
const int kGuideSwipeThreshold = 3;

// 沉浸式交互：工具栏可见性与动画参数
const int kToolbarAnimMs = 200;        // 工具栏动画时长
const double kAppToolbarHeight = 56.0;    // 顶部工具栏高度（使用 kApp 前缀避免与 Flutter 内置 kToolbarHeight 冲突）
const double kBottomNavHeight = 64.0;  // 底部导航栏高度
const int kToolbarHideDelayMs = 200;   // 状态防抖延迟
const int kToolbarAutoHideS = 3;       // 点击唤醒后的自动隐藏秒数
const double kMinSwipeDistancePx = 24.0; // 触发消隐的最小滑动距离

// 预加载参数
const double kDefaultPreloadThreshold = 0.6;
const int kMaxPreloadControllers = 1;
const int kPreloadFirstChunkBytes = 1048576; // 1MB

// 错误重试参数
const int kMaxRetryAttempts = 3;
const int kLoadTimeoutSeconds = 8;
const int kSwipeProgressIntervalSeconds = 5;

// 水平拖动进度条动画参数
const int kProgressBarFadeInMs = 150;   // 进度条淡入时长
const int kProgressBarFadeOutMs = 300;  // 进度条淡出时长
const int kProgressBarAnimMs = 80;      // 进度条填充动画（避免过快抖动）

const String kSubtitleColorWhite = 'white';
const String kSubtitleColorYellow = 'yellow';
const String kSubtitleSizeSmall = 'small';
const String kSubtitleSizeMedium = 'medium';
const String kSubtitleSizeLarge = 'large';
const String kSubtitlePosBottom = 'bottom';
const String kSubtitlePosLower = 'lower';
const String kSubtitlePosCenter = 'center';

// ===== Design Tokens：间距 / 圆角 =====
// 与 theme/theme_extensions.dart 同步，为组件提供语义化间距/圆角常量
// 导入方式：import 'package:embbytok_flutter/utils/constants.dart';

// 间距（8px 基准，适用于 EdgeInsets.all / symmetric / only）
const double kSpacingXs = 4.0;
const double kSpacingSm = 8.0;
const double kSpacingMd = 12.0;
const double kSpacingLg = 16.0;
const double kSpacingXl = 24.0;
const double kSpacingXxl = 32.0;

// 圆角（适用于 BorderRadius.circular）
const double kRadiusSm = 4.0;
const double kRadiusMd = 8.0;
const double kRadiusLg = 12.0;
const double kRadiusXl = 16.0;
const double kRadiusPill = 9999.0;

// 字号（与 Flutter TextTheme.bodyMedium 等对齐）
const double kFontSizeBodySmall = 12.0;
const double kFontSizeBodyMedium = 14.0;
const double kFontSizeBodyLarge = 16.0;
const double kFontSizeTitleSmall = 14.0; // 粗体
const double kFontSizeTitleMedium = 16.0;
const double kFontSizeTitleLarge = 22.0;
