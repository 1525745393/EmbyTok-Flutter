// 应用全局常量

const int kDefaultPageLimit = 20;
const String kAppName = 'EmbyTok';
const String kStorageKeyConfig = 'embytok_config';
const String kStorageKeyHistory = 'embytok_history';
const String kStorageKeySearchHistory = 'embytok_search_history';
const String kStorageKeySubtitle = 'embytok_subtitle';
const String kStorageKeyPlaybackRate = 'embytok_playback_rate';

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
const String kStorageKeyForceDeviceMode = 'embytok_force_device_mode';
const String kStorageKeyFeedType = 'embytok_feed_type';
const String kStorageKeyViewMode = 'embytok_view_mode';
const String kStorageKeyOrientationMode = 'embytok_orientation_mode';
const String kStorageKeyIsMuted = 'embytok_is_muted';
const String kStorageKeyIsAutoPlay = 'embytok_is_autoplay';
// 焦点恢复自动续播（来电结束后是否自动恢复播放，默认 true）
const String kStorageKeyAutoResumeAfterInterruption =
    'embytok_auto_resume_after_interruption';
const String kStorageKeyHiddenLibraryIds = 'embytok_hidden_library_ids';
const String kStorageKeyDefaultPlaybackRate = 'embytok_default_playback_rate';
const String kStorageKeyDefaultSubtitleLanguage =
    'embytok_default_subtitle_language';
const String kStorageKeySubtitleSize = 'embytok_subtitle_size';
// PR #78：推荐规则偏好（评分阈值 / 时长过滤 / 排除已观看）
const String kStorageKeyRecommendMinRating = 'embytok_recommend_min_rating';
const String kStorageKeyRecommendExcludePlayed =
    'embytok_recommend_exclude_played';
const String kStorageKeyFeedExcludePlayed = 'embytok_feed_exclude_played';
const String kStorageKeyRecommendMinRuntimeSec =
    'embytok_recommend_min_runtime_sec';
// PR #79：推荐 - 类型偏好（Movie/Episode/Video/MusicVideo/Series 的子集）
const String kStorageKeyRecommendIncludeTypes =
    'embytok_recommend_include_types';
// PR #85：推荐 - 用户控制（完播率门控开关 + 时间衰减半衰期）
const String kStorageKeyRecommendUseWatchHistory =
    'embytok_recommend_use_watch_history';
const String kStorageKeyRecommendHalfLifeDays =
    'embytok_recommend_half_life_days';
// PR #88：推荐 - 反推荐疲劳（30 天内不重推）
const String kStorageKeyRecommendAntiFatigueEnabled =
    'embytok_recommend_anti_fatigue_enabled';
const String kStorageKeyRecommendAntiFatigueDays =
    'embytok_recommend_anti_fatigue_days';
const String kStorageKeyRecentlyShownItemIds =
    'embytok_recently_shown_item_ids';
// PR #89：推荐 - 用户评分加权（Emby UserData.Rating 0-10）
// - 开启时：用户评分 < 阈值的 item 跳过（除非收藏）
// - 关闭时：仅按 communityRating 过滤（已有逻辑）
const String kStorageKeyRecommendUserRatingEnabled =
    'embytok_recommend_user_rating_enabled';
const String kStorageKeyRecommendUserRatingMin =
    'embytok_recommend_user_rating_min';
// PR #81：完播率统计（按 userId 分键，最多保留 500 条）
const String kStorageKeyWatchStats = 'embytok_watch_stats';
const String kStorageKeyLastPageIndex = 'embytok_last_page_index';
const String kStorageKeyLastGridScrollOffset =
    'embytok_last_grid_scroll_offset';
const String kStorageKeySelectedLibraryId = 'embytok_selected_library_id';
// 媒体库选择：推荐页独立（PR #66：视频流 / 推荐可分别设置）
const String kStorageKeySelectedLibraryIdForRecommend =
    'embytok_selected_library_id_for_recommend';
// 媒体库首次配置标记（PR #66：未配置时进入对应页面自动弹 LibrarySelector）
const String kStorageKeyFeedLibraryConfigured =
    'embytok_feed_library_configured';
const String kStorageKeyRecommendLibraryConfigured =
    'embytok_recommend_library_configured';
const String kStorageKeyActorsSelectedType = 'embytok_actors_selected_type';
const String kStorageKeyActorsSelectedTab = 'embytok_actors_selected_tab';
const String kStorageKeyActorsSearchQuery = 'embytok_actors_search_query';
const String kStorageKeyActorsScrollOffset = 'embytok_actors_scroll_offset';

// 登录页：服务器历史 & 记住凭据
const String kStorageKeyServerHistory = 'embytok_server_history';
const String kStorageKeySavedCredentials = 'embytok_saved_credentials';

// 安全存储键（用于 flutter_secure_storage）
const String kStorageKeyAccessToken = 'embytok_access_token';
const String kStorageKeyEmbyServerUrl = 'embytok_emby_server_url';
const String kStorageKeyUser = 'embytok_user';

const int kMaxSearchHistory = 10;
const double kDefaultPlaybackRate = 1.0;
const double kLongPressPlaybackRate = 2.0;
const int kDebounceMs = 300;
const int kDoubleTapMs = 300;
// 水平拖动 seek 速率（毫秒/像素）
// 原值 100ms/px 在 1080p 屏幕全宽拖动会跳过 3.2 分钟，过于敏感
// 新值 40ms/px 全宽约 77 秒，更符合行业标准，平衡灵敏度与误触
const int kSeekPerPixelMs = 40;

// 视频切换与引导动画时长（毫秒）
const int kVideoFadeInMs = 200;
const int kGuideFadeMs = 500;
const double kGuideSlideDistance = 40.0;
const int kGuideSwipeThreshold = 3;

// 沉浸式交互：工具栏可见性与动画参数
const int kToolbarAnimMs = 200; // 工具栏动画时长
const double kAppToolbarHeight =
    56.0; // 顶部工具栏高度（使用 kApp 前缀避免与 Flutter 内置 kToolbarHeight 冲突）
const double kBottomNavHeight = 72.0; // 底部导航栏高度（Material 3 NavigationBar 最小高度）
const int kToolbarHideDelayMs = 200; // 状态防抖延迟
const int kToolbarAutoHideS = 3; // 点击唤醒后的自动隐藏秒数
const double kMinSwipeDistancePx = 24.0; // 触发消隐的最小滑动距离

// 预加载参数
const double kDefaultPreloadThreshold = 0.6;
const int kMaxPreloadControllers = 1;
const int kPreloadFirstChunkBytes = 1048576; // 1MB

/// PlaybackCoordinator 初始 item 轮询间隔（ms）
/// 用于等待 playbackListProvider 初始化完成的轮询周期
const int kInitialItemPollIntervalMs = 100;

/// PlaybackCoordinator 初始 item 轮询重试上限
/// 50 次 * 100ms = 约 5 秒超时（避免 playbackListProvider 永远不就绪时卡死）
const int kInitialItemPollMaxRetries = 50;

/// VideoPoolService disposeAll 分批释放每批数量
/// 每批 dispose 2 个 controller，批次间让出主线程给 GC，避免低端设备卡顿/OOM
const int kVideoPoolDisposeBatchSize = 2;

/// 预加载 VideoPlayerController 初始化超时（秒）
/// 预加载时 controller 初始化最长等待时间，超过则降级下一级播放协议
/// 注意：该值比 kLoadTimeoutSeconds(8s) 略长是因为预加载在后台，允许更宽限
const int kVideoPreloadInitTimeoutSec = 12;

/// 全屏进入/退出过渡动画时长（ms）
/// 从底部滑入动画的时长，略长于工具栏动画(kToolbarAnimMs=200)以获得更自然的感知
const int kFullscreenTransitionMs = 300;

// 错误重试参数
const int kMaxRetryAttempts = 3;
const int kLoadTimeoutSeconds = 8;
const int kSwipeProgressIntervalSeconds = 5;

// 内存缓存参数
const Duration kCacheDefaultTtl = Duration(minutes: 5);
const int kCacheMaxEntries = 100;

// 水平拖动进度条动画参数
const int kProgressBarFadeInMs = 150; // 进度条淡入时长
const int kProgressBarFadeOutMs = 300; // 进度条淡出时长
const int kProgressBarAnimMs = 80; // 进度条填充动画（避免过快抖动）

const String kSubtitleColorWhite = 'white';
const String kSubtitleColorYellow = 'yellow';
const String kSubtitleSizeSmall = 'small';
const String kSubtitleSizeMedium = 'medium';
const String kSubtitleSizeLarge = 'large';
const String kSubtitlePosBottom = 'bottom';
const String kSubtitlePosLower = 'lower';
const String kSubtitlePosCenter = 'center';
// 字幕描边宽度（像素）
const double kSubtitleStrokeWidthMin = 0.0;
const double kSubtitleStrokeWidthMax = 5.0;
const double kSubtitleStrokeWidthDefault = 3.0;
// 字幕阴影
const bool kSubtitleShadowDefault = true;
// 字幕背景透明度（0-100）
const int kSubtitleBgOpacityMin = 0;
const int kSubtitleBgOpacityMax = 100;
const int kSubtitleBgOpacityDefault = 72;
// 字幕时间轴微调（毫秒）
const int kSubtitleTimeOffsetMin = -500;
const int kSubtitleTimeOffsetMax = 500;
const int kSubtitleTimeOffsetDefault = 0;

// ===== Design Tokens：间距 / 圆角 =====
// 与 theme/theme_extensions.dart 同步，为组件提供语义化间距/圆角常量
// 导入方式：import 'package:embytok_flutter/utils/constants.dart';

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

// ===== Emby API 认证头 =====
//
// Emby REST API 规范要求：所有请求必须携带 X-Emby-Authorization 头，
// 其值格式为：
//   MediaBrowser Client="<app>", Device="<device>", DeviceId="<id>", Version="<ver>"[, Token="<token>"]
// Token 字段在登录后的所有请求中必须内嵌（而非作为独立头部），
// 同时保留 X-Emby-Token 头以兼容旧版 Emby 服务器。
//
// 参考：https://emby.media/community/index.php?/topic/17346-how-to-authenticate-a-user/

/// Emby 客户端标识前缀（不含 Token，用于登录前的匿名请求）
const String kEmbyAuthPrefix = 'MediaBrowser Client="EmbyTok", Device="Mobile",'
    ' DeviceId="embytok-client", Version="1.0.0"';

/// 构造含 Token 的完整 X-Emby-Authorization 头值
///
/// Emby 规范要求 Token 内嵌在 Authorization 头中，
/// 仅发送 X-Emby-Token 不满足部分版本 Emby 服务器的认证要求。
String embyAuthHeader(String token) => '$kEmbyAuthPrefix, Token="$token"';

/// 构造 Emby 视频流 / 图片 / API 请求所需的完整认证头 Map
///
/// 同时包含：
/// - X-Emby-Authorization：规范要求，含 Token 内嵌
/// - X-Emby-Token：向后兼容旧版 Emby 服务器
///
/// 用于 VideoPlayerController.networkUrl(httpHeaders: ...)
/// 和 CachedNetworkImage(httpHeaders: ...)
Map<String, String> embyAuthHeaders(String token) => {
      'X-Emby-Authorization': embyAuthHeader(token),
      'X-Emby-Token': token,
    };

// ===== 全屏播放页（FullscreenVideoPage）参数 =====
//
// 提取自 lib/views/fullscreen_video_page.dart 的 magic number，
// 集中管理便于后续调参与避免硬编码数值散落各处。
// 分类：时长 / 业务阈值 / UI 尺寸。

// —— 时长（毫秒/秒）——

/// 亮度手势 UI 自动隐藏延迟（毫秒）
/// 用户结束垂直拖动后，亮度浮层继续显示该时长后消失
const int kFullscreenBrightnessHideMs = 600;

/// 网络状态 Toast 显示时长（秒）
/// 网络切换（WiFi/移动/断开）时提示信息停留时长
const int kFullscreenNetworkToastSec = 2;

/// 屏幕旋转结束检测延迟（毫秒）
/// didChangeMetrics 触发后等待该时长无新事件，判定旋转结束
const int kFullscreenRotateEndMs = 350;

/// 应用回到前台后恢复播放的延迟（毫秒）
/// 短暂延迟避免与系统 UI 切换抢资源
const int kFullscreenResumePlayDelayMs = 300;

/// 控制栏自动隐藏延迟（秒）
/// 用户无操作超过该时长后隐藏顶/底栏
const int kFullscreenControlsHideSec = 4;

/// 双击点赞爱心动画时长（毫秒）
const int kFullscreenFlyingHeartAnimMs = 700;

// —— 业务阈值与参数 ——

/// 双击左右区域 seek 步进秒数
/// 与 VideoGestureMixin.onDoubleTapLeft/Right 的步进值保持一致
const int kDoubleTapSeekStepSec = 10;

/// 倍速选择容差（用于判定 Slider 选中的 rate 是否匹配当前播放速率）
const double kPlaybackRateTolerance = 0.01;

/// 亮度低档阈值（归一化值，0.0-1.0）
/// 低于该值显示 brightness_low 图标
const double kBrightnessLowThreshold = 0.1;

/// 亮度/音量中档阈值（归一化值，0.0-1.0）
/// 低于该值显示 medium 图标，否则显示 high 图标
const double kVolumeBrightnessMidThreshold = 0.5;

// —— UI 尺寸 ——

/// 字幕渲染层距底部偏移（像素）
const double kFullscreenSubtitleBottom = 60.0;

/// 设置面板距底部偏移（像素，不含 SafeInsets）
const double kFullscreenSettingsPanelBottom = 100.0;

/// 设置面板宽度（像素）
const double kFullscreenSettingsPanelWidth = 200.0;

/// 亮度/音量指示器中进度条宽度（像素）
const double kFullscreenVolumeBarWidth = 120.0;

/// 缓冲加载指示器尺寸（像素，宽高一致）
const double kFullscreenLoadingIndicatorSize = 44.0;

/// 缓冲加载指示器描边宽度（像素）
const double kFullscreenLoadingStrokeWidth = 2.5;

/// 飞心动画缩放起始值
const double kFlyingHeartScaleBegin = 0.6;

/// 飞心动画缩放结束值
const double kFlyingHeartScaleEnd = 2.8;
