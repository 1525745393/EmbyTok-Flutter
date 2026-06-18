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
const String kFeedTypeLatest = 'latest';
const String kFeedTypeRandom = 'random';
const String kFeedTypeFavorites = 'favorites';

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
const String kStorageKeyIsPureMode = 'embbytok_is_pure_mode';
const String kStorageKeyHiddenLibraryIds = 'embbytok_hidden_library_ids';

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

// 智能进度条：仅对长于该时长的视频显示底部细进度条（秒）
const int kMinDurationSecondsForProgressBar = 180; // 3 分钟
const int kRandomListSize = 80; // 随机浏览模式的拉取数量
const int kPureModeHideMs = 300; // 纯净模式 UI 渐隐/渐显动画时长

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
