// 用户偏好持久化：集中管理所有跨页面的用户设置（Task 1 新增）
// 负责读写 SharedPreferences 中保存的：设备模式、浏览模式、视图模式、
// 方向过滤、静音/自动连播、隐藏媒体库 ID 列表等。

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'constants.dart';

// 设备模式
enum DeviceMode {
  standard,
  tv;

  static DeviceMode fromString(String? s, {DeviceMode fallback = DeviceMode.standard}) {
    if (s == null || s.isEmpty) return fallback;
    return switch (s.trim().toLowerCase()) {
      kDeviceModeTv => DeviceMode.tv,
      kDeviceModeStandard => DeviceMode.standard,
      _ => fallback,
    };
  }

  String toStorageString() {
    return switch (this) {
      DeviceMode.standard => kDeviceModeStandard,
      DeviceMode.tv => kDeviceModeTv,
    };
  }
}

// 浏览模式（最新/随机/收藏/继续观看）
// 注："推荐"已从 FeedType 移除，改为独立路由 /recommend + 独立数据源
// 原因：与 video_list_provider/feed 共享会污染视频流；详见 PR #57
enum FeedType {
  latest,
  random,
  favorites,
  resume;

  static FeedType fromString(String? s, {FeedType fallback = FeedType.latest}) {
    if (s == null || s.isEmpty) return fallback;
    return switch (s.trim().toLowerCase()) {
      kFeedTypeRandom => FeedType.random,
      kFeedTypeFavorites => FeedType.favorites,
      kFeedTypeResume => FeedType.resume,
      _ => FeedType.latest,
    };
  }

  String toStorageString() {
    return switch (this) {
      FeedType.latest => kFeedTypeLatest,
      FeedType.random => kFeedTypeRandom,
      FeedType.favorites => kFeedTypeFavorites,
      FeedType.resume => kFeedTypeResume,
    };
  }

  String get zhLabel {
    return switch (this) {
      FeedType.latest => '最新',
      FeedType.random => '随机',
      FeedType.favorites => '收藏',
      FeedType.resume => '继续观看',
    };
  }
}

// 视图模式（视频流/网格）
enum ViewMode {
  feed,
  grid;

  static ViewMode fromString(String? s, {ViewMode fallback = ViewMode.feed}) {
    if (s == null || s.isEmpty) return fallback;
    return switch (s.trim().toLowerCase()) {
      kViewModeGrid => ViewMode.grid,
      _ => ViewMode.feed,
    };
  }

  String toStorageString() {
    return switch (this) {
      ViewMode.feed => kViewModeFeed,
      ViewMode.grid => kViewModeGrid,
    };
  }
}

// 视频方向过滤（仅竖屏/仅横屏/全部）
enum OrientationMode {
  vertical,
  horizontal,
  both;

  static OrientationMode fromString(String? s, {OrientationMode fallback = OrientationMode.both}) {
    if (s == null || s.isEmpty) return fallback;
    return switch (s.trim().toLowerCase()) {
      kOrientationModeVertical => OrientationMode.vertical,
      kOrientationModeHorizontal => OrientationMode.horizontal,
      _ => OrientationMode.both,
    };
  }

  String toStorageString() {
    return switch (this) {
      OrientationMode.vertical => kOrientationModeVertical,
      OrientationMode.horizontal => kOrientationModeHorizontal,
      OrientationMode.both => kOrientationModeBoth,
    };
  }

  String get zhLabel {
    return switch (this) {
      OrientationMode.vertical => '仅竖屏',
      OrientationMode.horizontal => '仅横屏',
      OrientationMode.both => '全部',
    };
  }
}

// 不可变的用户偏好快照
class AppPreferences {
  final DeviceMode forceDeviceMode;
  final FeedType feedType;
  final ViewMode viewMode;
  final OrientationMode orientationMode;
  final bool isMuted;
  final bool isAutoPlay;
  final Set<String> hiddenLibraryIds;
  final double defaultPlaybackRate;
  final String defaultSubtitleLanguage;
  final String videoQuality;
  final String subtitleSize;
  // PR #78：推荐规则偏好
  // - recommendMinRating: 评分阈值（Emby 满分 10），0 表示不过滤
  // - recommendExcludePlayed: 排除已观看（默认 true）
  // - recommendMinRuntimeSec: 最短时长（秒），过滤测试片/预告片，默认 30
  // - recommendIncludeTypes: 偏好类型（Movie/Episode/Video/MusicVideo/Series 的子集）
  final double recommendMinRating;
  final bool recommendExcludePlayed;
  final int recommendMinRuntimeSec;
  final Set<String> recommendIncludeTypes;
  // PR #85：用户控制推荐门控
  // - recommendUseWatchHistory: 是否用完播率优化推荐（false = 用默认信号，无门控）
  // - recommendHalfLifeDays: 时间衰减半衰期（天）
  //   - 0 = 不衰减（所有记录等权重）
  //   - 14 = 默认 14 天衰减
  //   - 范围 [0, 90]
  final bool recommendUseWatchHistory;
  final double recommendHalfLifeDays;
  // PR #88：用户控制反推荐疲劳
  // - recommendAntiFatigueEnabled: 是否启用"X 天内不重推"过滤
  // - recommendAntiFatigueDays: 不重推的天数（默认 30）
  //   - 范围 [1, 90]
  final bool recommendAntiFatigueEnabled;
  final int recommendAntiFatigueDays;
  // PR #89：用户评分加权（Emby UserData.Rating 0-10）
  // - recommendUserRatingEnabled: 是否启用"用户评分 < 阈值"的过滤
  //   - true（默认）：用户评分低于 recommendUserRatingMin 的 item 不推荐
  //   - false：仅按 communityRating 过滤（已有逻辑）
  // - recommendUserRatingMin: 最低用户评分阈值（0-10，默认 4.0）
  //   - null = 不过滤
  //   - 收藏项豁免（用户主动喜欢 > 用户评分低）
  final bool recommendUserRatingEnabled;
  final double recommendUserRatingMin;

  const AppPreferences({
    this.forceDeviceMode = DeviceMode.standard,
    this.feedType = FeedType.latest,
    this.viewMode = ViewMode.feed,
    this.orientationMode = OrientationMode.both,
    this.isMuted = true,
    this.isAutoPlay = false,
    this.hiddenLibraryIds = const <String>{},
    this.defaultPlaybackRate = 1.0,
    this.defaultSubtitleLanguage = '',
    this.videoQuality = 'auto',
    this.subtitleSize = 'medium',
    this.recommendMinRating = 4.0,
    this.recommendExcludePlayed = true,
    this.recommendMinRuntimeSec = 30,
    this.recommendIncludeTypes = const <String>{
      'Movie',
      'Episode',
      'Video',
      'MusicVideo',
      'Series',
    },
    this.recommendUseWatchHistory = true,
    this.recommendHalfLifeDays = 14.0,
    this.recommendAntiFatigueEnabled = true,
    this.recommendAntiFatigueDays = 30,
    this.recommendUserRatingEnabled = true,
    this.recommendUserRatingMin = 4.0,
  });

  AppPreferences copyWith({
    DeviceMode? forceDeviceMode,
    FeedType? feedType,
    ViewMode? viewMode,
    OrientationMode? orientationMode,
    bool? isMuted,
    bool? isAutoPlay,
    Set<String>? hiddenLibraryIds,
    double? defaultPlaybackRate,
    String? defaultSubtitleLanguage,
    String? videoQuality,
    String? subtitleSize,
    double? recommendMinRating,
    bool? recommendExcludePlayed,
    int? recommendMinRuntimeSec,
    Set<String>? recommendIncludeTypes,
    bool? recommendUseWatchHistory,
    double? recommendHalfLifeDays,
    bool? recommendAntiFatigueEnabled,
    int? recommendAntiFatigueDays,
    bool? recommendUserRatingEnabled,
    double? recommendUserRatingMin,
  }) {
    return AppPreferences(
      forceDeviceMode: forceDeviceMode ?? this.forceDeviceMode,
      feedType: feedType ?? this.feedType,
      viewMode: viewMode ?? this.viewMode,
      orientationMode: orientationMode ?? this.orientationMode,
      isMuted: isMuted ?? this.isMuted,
      isAutoPlay: isAutoPlay ?? this.isAutoPlay,
      hiddenLibraryIds: hiddenLibraryIds ?? this.hiddenLibraryIds,
      defaultPlaybackRate: defaultPlaybackRate ?? this.defaultPlaybackRate,
      defaultSubtitleLanguage: defaultSubtitleLanguage ?? this.defaultSubtitleLanguage,
      videoQuality: videoQuality ?? this.videoQuality,
      subtitleSize: subtitleSize ?? this.subtitleSize,
      recommendMinRating: recommendMinRating ?? this.recommendMinRating,
      recommendExcludePlayed: recommendExcludePlayed ?? this.recommendExcludePlayed,
      recommendMinRuntimeSec: recommendMinRuntimeSec ?? this.recommendMinRuntimeSec,
      recommendIncludeTypes:
          recommendIncludeTypes ?? this.recommendIncludeTypes,
      recommendUseWatchHistory:
          recommendUseWatchHistory ?? this.recommendUseWatchHistory,
      recommendHalfLifeDays:
          recommendHalfLifeDays ?? this.recommendHalfLifeDays,
      recommendAntiFatigueEnabled:
          recommendAntiFatigueEnabled ?? this.recommendAntiFatigueEnabled,
      recommendAntiFatigueDays:
          recommendAntiFatigueDays ?? this.recommendAntiFatigueDays,
      recommendUserRatingEnabled:
          recommendUserRatingEnabled ?? this.recommendUserRatingEnabled,
      recommendUserRatingMin:
          recommendUserRatingMin ?? this.recommendUserRatingMin,
    );
  }
}

// 偏好读写服务（面向 Riverpod 注入）
class AppPreferencesService {
  const AppPreferencesService();

  // 从 SharedPreferences 读取全部偏好设置
  Future<AppPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();

    final forceDeviceMode = DeviceMode.fromString(
      prefs.getString(kStorageKeyForceDeviceMode),
      fallback: DeviceMode.standard,
    );
    final feedType = FeedType.fromString(
      prefs.getString(kStorageKeyFeedType),
      fallback: FeedType.latest,
    );
    final viewMode = ViewMode.fromString(
      prefs.getString(kStorageKeyViewMode),
      fallback: ViewMode.feed,
    );
    final orientationMode = OrientationMode.fromString(
      prefs.getString(kStorageKeyOrientationMode),
      fallback: OrientationMode.both,
    );
    final isMuted = prefs.getBool(kStorageKeyIsMuted) ?? true;
    final isAutoPlay = prefs.getBool(kStorageKeyIsAutoPlay) ?? false;

    // 隐藏媒体库 ID 列表以 JSON 数组字符串存储
    final rawHiddenIds = prefs.getString(kStorageKeyHiddenLibraryIds);
    final hiddenLibraryIds = <String>{};
    if (rawHiddenIds != null && rawHiddenIds.isNotEmpty) {
      try {
        final decoded = json.decode(rawHiddenIds);
        if (decoded is List<dynamic>) {
          hiddenLibraryIds.addAll(decoded.whereType<String>());
        }
      } catch (_) {
        // 解析失败时忽略，不影响启动
      }
    }

    final defaultPlaybackRate = prefs.getDouble(kStorageKeyDefaultPlaybackRate) ?? 1.0;
    final defaultSubtitleLanguage = prefs.getString(kStorageKeyDefaultSubtitleLanguage) ?? '';
    final videoQuality = prefs.getString(kStorageKeyVideoQuality) ?? 'auto';
    final subtitleSize = prefs.getString(kStorageKeySubtitleSize) ?? 'medium';

    // PR #78：推荐规则偏好
    final recommendMinRating = prefs.getDouble(kStorageKeyRecommendMinRating) ?? 4.0;
    final recommendExcludePlayed = prefs.getBool(kStorageKeyRecommendExcludePlayed) ?? true;
    final recommendMinRuntimeSec = prefs.getInt(kStorageKeyRecommendMinRuntimeSec) ?? 30;
    // PR #79：类型偏好（默认全部）
    final recommendIncludeTypesJson =
        prefs.getStringList(kStorageKeyRecommendIncludeTypes);
    final recommendIncludeTypes = recommendIncludeTypesJson != null &&
            recommendIncludeTypesJson.isNotEmpty
        ? recommendIncludeTypesJson.toSet()
        : const <String>{
            'Movie',
            'Episode',
            'Video',
            'MusicVideo',
            'Series',
          };
    // PR #85：用户控制推荐门控
    final recommendUseWatchHistory =
        prefs.getBool(kStorageKeyRecommendUseWatchHistory) ?? true;
    final recommendHalfLifeDays =
        prefs.getDouble(kStorageKeyRecommendHalfLifeDays) ?? 14.0;
    // PR #88：用户控制反推荐疲劳
    final recommendAntiFatigueEnabled =
        prefs.getBool(kStorageKeyRecommendAntiFatigueEnabled) ?? true;
    final recommendAntiFatigueDays =
        prefs.getInt(kStorageKeyRecommendAntiFatigueDays) ?? 30;
    // PR #89：用户评分加权
    final recommendUserRatingEnabled =
        prefs.getBool(kStorageKeyRecommendUserRatingEnabled) ?? true;
    final recommendUserRatingMin =
        prefs.getDouble(kStorageKeyRecommendUserRatingMin) ?? 4.0;

    return AppPreferences(
      forceDeviceMode: forceDeviceMode,
      feedType: feedType,
      viewMode: viewMode,
      orientationMode: orientationMode,
      isMuted: isMuted,
      isAutoPlay: isAutoPlay,
      hiddenLibraryIds: hiddenLibraryIds,
      defaultPlaybackRate: defaultPlaybackRate,
      defaultSubtitleLanguage: defaultSubtitleLanguage,
      videoQuality: videoQuality,
      subtitleSize: subtitleSize,
      recommendMinRating: recommendMinRating,
      recommendExcludePlayed: recommendExcludePlayed,
      recommendMinRuntimeSec: recommendMinRuntimeSec,
      recommendIncludeTypes: recommendIncludeTypes,
      recommendUseWatchHistory: recommendUseWatchHistory,
      recommendHalfLifeDays: recommendHalfLifeDays,
      recommendAntiFatigueEnabled: recommendAntiFatigueEnabled,
      recommendAntiFatigueDays: recommendAntiFatigueDays,
      recommendUserRatingEnabled: recommendUserRatingEnabled,
      recommendUserRatingMin: recommendUserRatingMin,
    );
  }

  // 保存全部偏好设置
  Future<void> save(AppPreferences preferences) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(kStorageKeyForceDeviceMode, preferences.forceDeviceMode.toStorageString()),
      prefs.setString(kStorageKeyFeedType, preferences.feedType.toStorageString()),
      prefs.setString(kStorageKeyViewMode, preferences.viewMode.toStorageString()),
      prefs.setString(kStorageKeyOrientationMode, preferences.orientationMode.toStorageString()),
      prefs.setBool(kStorageKeyIsMuted, preferences.isMuted),
      prefs.setBool(kStorageKeyIsAutoPlay, preferences.isAutoPlay),
      prefs.setString(kStorageKeyHiddenLibraryIds, json.encode(preferences.hiddenLibraryIds.toList(growable: false))),
      prefs.setDouble(kStorageKeyDefaultPlaybackRate, preferences.defaultPlaybackRate),
      prefs.setString(kStorageKeyDefaultSubtitleLanguage, preferences.defaultSubtitleLanguage),
      prefs.setString(kStorageKeyVideoQuality, preferences.videoQuality),
      prefs.setString(kStorageKeySubtitleSize, preferences.subtitleSize),
      // PR #78：推荐规则偏好
      prefs.setDouble(kStorageKeyRecommendMinRating, preferences.recommendMinRating),
      prefs.setBool(kStorageKeyRecommendExcludePlayed, preferences.recommendExcludePlayed),
      prefs.setInt(kStorageKeyRecommendMinRuntimeSec, preferences.recommendMinRuntimeSec),
      // PR #79：类型偏好
      prefs.setStringList(
        kStorageKeyRecommendIncludeTypes,
        preferences.recommendIncludeTypes.toList(growable: false),
      ),
      // PR #85：用户控制推荐门控
      prefs.setBool(
          kStorageKeyRecommendUseWatchHistory, preferences.recommendUseWatchHistory),
      prefs.setDouble(
          kStorageKeyRecommendHalfLifeDays, preferences.recommendHalfLifeDays),
      // PR #88：用户控制反推荐疲劳
      prefs.setBool(kStorageKeyRecommendAntiFatigueEnabled,
          preferences.recommendAntiFatigueEnabled),
      prefs.setInt(kStorageKeyRecommendAntiFatigueDays,
          preferences.recommendAntiFatigueDays),
      // PR #89：用户评分加权
      prefs.setBool(kStorageKeyRecommendUserRatingEnabled,
          preferences.recommendUserRatingEnabled),
      prefs.setDouble(kStorageKeyRecommendUserRatingMin,
          preferences.recommendUserRatingMin),
    ]);
  }

  // 单独更新设备模式
  Future<void> setForceDeviceMode(DeviceMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kStorageKeyForceDeviceMode, mode.toStorageString());
  }

  // 单独更新浏览模式（最新/随机/收藏）
  Future<void> setFeedType(FeedType type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kStorageKeyFeedType, type.toStorageString());
  }

  // 单独更新视图模式（视频流/网格）
  Future<void> setViewMode(ViewMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kStorageKeyViewMode, mode.toStorageString());
  }

  // 单独更新方向过滤
  Future<void> setOrientationMode(OrientationMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kStorageKeyOrientationMode, mode.toStorageString());
  }

  // 单独更新静音
  Future<void> setIsMuted(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kStorageKeyIsMuted, value);
  }

  // 单独更新自动连播
  Future<void> setIsAutoPlay(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kStorageKeyIsAutoPlay, value);
  }

  // 更新隐藏的媒体库 ID 集合
  Future<void> setHiddenLibraryIds(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kStorageKeyHiddenLibraryIds, json.encode(ids.toList(growable: false)));
  }

  // 单独更新默认播放速度
  Future<void> setDefaultPlaybackRate(double rate) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(kStorageKeyDefaultPlaybackRate, rate);
  }

  // 单独更新默认字幕语言
  Future<void> setDefaultSubtitleLanguage(String language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kStorageKeyDefaultSubtitleLanguage, language);
  }

  // 单独更新视频画质
  Future<void> setVideoQuality(String quality) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kStorageKeyVideoQuality, quality);
  }

  // 单独更新字幕大小
  Future<void> setSubtitleSize(String size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kStorageKeySubtitleSize, size);
  }
}
