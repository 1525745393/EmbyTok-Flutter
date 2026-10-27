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

  static DeviceMode fromString(String? s,
      {DeviceMode fallback = DeviceMode.standard}) {
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

  static OrientationMode fromString(String? s,
      {OrientationMode fallback = OrientationMode.both}) {
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
  const AppPreferences({
    this.forceDeviceMode = DeviceMode.standard,
    this.feedType = FeedType.latest,
    this.viewMode = ViewMode.feed,
    this.orientationMode = OrientationMode.both,
    this.isMuted = true,
    this.isAutoPlay = false,
    this.autoResumeAfterInterruption = true,
    this.fullscreenGestureBackExcluded = true,
    this.hiddenLibraryIds = const <String>{},
    this.defaultPlaybackRate = 1.0,
    this.defaultSubtitleLanguage = '',
    this.subtitleSize = 'medium',
    this.feedExcludePlayed = false,
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
    this.recommendNextUpSeriesCount = 5,
    this.recommendFavActorNewCount = 20,
    this.followActorVideoCount = 3,
    this.followOnlyUnwatched = true,
    this.followMaxActors = 200,
    this.recommendTagSourceMapping = const {
      '最新影片': 'latest',
      '继续观看': 'resume',
      '为你推荐': 'suggestions',
      '精选': 'nativeRecommendations',
      '相似': 'similar',
      '高分': 'recommendations',
      '移动客户端推荐': 'localRecommend',
    },
  });
  final DeviceMode forceDeviceMode;
  final FeedType feedType;
  final ViewMode viewMode;
  final OrientationMode orientationMode;
  final bool isMuted;
  final bool isAutoPlay;
  // 焦点恢复自动续播（来电结束后是否自动恢复播放，默认 true）
  // 由 AudioSessionHandler 在中断结束时读取，决定是否调用 controller.play()
  final bool autoResumeAfterInterruption;
  // 全屏播放时排除 Android 边缘返回手势（默认 true）
  // true：排除左右边缘返回手势，避免水平拖动 seek 被系统返回抢占
  // false：保留系统边缘返回手势（全屏可用边缘滑动退出）
  final bool fullscreenGestureBackExcluded;
  final Set<String> hiddenLibraryIds;
  final double defaultPlaybackRate;
  final String defaultSubtitleLanguage;
  final String subtitleSize;
  // 视频流排除已观看（默认 false）
  final bool feedExcludePlayed;
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
  // 推荐 - 追剧队列数量平衡
  // - recommendNextUpSeriesCount: 取最近几部剧的下一集（默认 5，范围 [1,10]）
  // - recommendFavActorNewCount: 收藏演员新作品条数（默认 20，范围 [5,40]）
  final int recommendNextUpSeriesCount;
  final int recommendFavActorNewCount;
  // 关注页：每演员视频数（默认 3，范围 [1,10]）
  final int followActorVideoCount;
  // 推荐标签数据源映射（label → source key，默认一对一；用户可自定义）
  final Map<String, String> recommendTagSourceMapping;
  // 关注页：只看未观看（默认 true，开启后过滤已观看视频）
  final bool followOnlyUnwatched;
  // 关注页：收藏演员拉取上限（默认 200，范围 [10,500]）
  final int followMaxActors;

  AppPreferences copyWith({
    DeviceMode? forceDeviceMode,
    FeedType? feedType,
    ViewMode? viewMode,
    OrientationMode? orientationMode,
    bool? isMuted,
    bool? isAutoPlay,
    bool? autoResumeAfterInterruption,
    bool? fullscreenGestureBackExcluded,
    Set<String>? hiddenLibraryIds,
    double? defaultPlaybackRate,
    String? defaultSubtitleLanguage,
    String? subtitleSize,
    bool? feedExcludePlayed,
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
    int? recommendNextUpSeriesCount,
    int? recommendFavActorNewCount,
    int? followActorVideoCount,
    bool? followOnlyUnwatched,
    int? followMaxActors,
    Map<String, String>? recommendTagSourceMapping,
  }) {
    return AppPreferences(
      forceDeviceMode: forceDeviceMode ?? this.forceDeviceMode,
      feedType: feedType ?? this.feedType,
      viewMode: viewMode ?? this.viewMode,
      orientationMode: orientationMode ?? this.orientationMode,
      isMuted: isMuted ?? this.isMuted,
      isAutoPlay: isAutoPlay ?? this.isAutoPlay,
      autoResumeAfterInterruption:
          autoResumeAfterInterruption ?? this.autoResumeAfterInterruption,
      fullscreenGestureBackExcluded:
          fullscreenGestureBackExcluded ?? this.fullscreenGestureBackExcluded,
      hiddenLibraryIds: hiddenLibraryIds ?? this.hiddenLibraryIds,
      defaultPlaybackRate: defaultPlaybackRate ?? this.defaultPlaybackRate,
      defaultSubtitleLanguage:
          defaultSubtitleLanguage ?? this.defaultSubtitleLanguage,
      subtitleSize: subtitleSize ?? this.subtitleSize,
      feedExcludePlayed: feedExcludePlayed ?? this.feedExcludePlayed,
      recommendMinRating: recommendMinRating ?? this.recommendMinRating,
      recommendExcludePlayed:
          recommendExcludePlayed ?? this.recommendExcludePlayed,
      recommendMinRuntimeSec:
          recommendMinRuntimeSec ?? this.recommendMinRuntimeSec,
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
      recommendNextUpSeriesCount:
          recommendNextUpSeriesCount ?? this.recommendNextUpSeriesCount,
      recommendFavActorNewCount:
          recommendFavActorNewCount ?? this.recommendFavActorNewCount,
      followActorVideoCount:
          followActorVideoCount ?? this.followActorVideoCount,
      followOnlyUnwatched: followOnlyUnwatched ?? this.followOnlyUnwatched,
      followMaxActors: followMaxActors ?? this.followMaxActors,
      recommendTagSourceMapping:
          recommendTagSourceMapping ?? this.recommendTagSourceMapping,
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
    // 焦点恢复自动续播（默认 true）
    final autoResumeAfterInterruption =
        prefs.getBool(kStorageKeyAutoResumeAfterInterruption) ?? true;
    // 全屏排除边缘返回手势（默认 true）
    final fullscreenGestureBackExcluded =
        prefs.getBool(kStorageKeyFullscreenGestureBackExcluded) ?? true;

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

    final defaultPlaybackRate =
        prefs.getDouble(kStorageKeyDefaultPlaybackRate) ?? 1.0;
    final defaultSubtitleLanguage =
        prefs.getString(kStorageKeyDefaultSubtitleLanguage) ?? '';
    final subtitleSize = prefs.getString(kStorageKeySubtitleSize) ?? 'medium';

    // 视频流排除已观看（默认 false）
    final feedExcludePlayed =
        prefs.getBool(kStorageKeyFeedExcludePlayed) ?? false;

    // PR #78：推荐规则偏好
    final recommendMinRating =
        prefs.getDouble(kStorageKeyRecommendMinRating) ?? 4.0;
    final recommendExcludePlayed =
        prefs.getBool(kStorageKeyRecommendExcludePlayed) ?? true;
    final recommendMinRuntimeSec =
        prefs.getInt(kStorageKeyRecommendMinRuntimeSec) ?? 30;
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
    // 追剧队列数量平衡
    final recommendNextUpSeriesCount =
        prefs.getInt(kStorageKeyRecommendNextUpSeriesCount) ?? 5;
    final recommendFavActorNewCount =
        prefs.getInt(kStorageKeyRecommendFavActorNewCount) ?? 20;
    final followActorVideoCount =
        prefs.getInt(kStorageKeyFollowActorVideoCount) ?? 3;
    final followOnlyUnwatched =
        prefs.getBool(kStorageKeyFollowOnlyUnwatched) ?? true;
    final followMaxActors = prefs.getInt(kStorageKeyFollowMaxActors) ?? 200;
    final recommendTagSourceMappingRaw =
        prefs.getString(kStorageKeyRecommendTagSourceMapping);
    final recommendTagSourceMapping = <String, String>{
      '最新影片': 'latest',
      '继续观看': 'resume',
      '为你推荐': 'suggestions',
      '精选': 'nativeRecommendations',
      '相似': 'similar',
      '高分': 'recommendations',
      '移动客户端推荐': 'localRecommend',
    };
    if (recommendTagSourceMappingRaw != null &&
        recommendTagSourceMappingRaw.isNotEmpty) {
      try {
        final decoded = json.decode(recommendTagSourceMappingRaw);
        if (decoded is Map) {
          final merged = <String, String>{
            ...recommendTagSourceMapping,
            ...decoded.map((k, v) => MapEntry(k.toString(), v.toString())),
          };
          recommendTagSourceMapping
            ..clear()
            ..addAll(merged);
        }
      } catch (_) {
        // 解析失败回退默认映射
      }
    }

    return AppPreferences(
      forceDeviceMode: forceDeviceMode,
      feedType: feedType,
      viewMode: viewMode,
      orientationMode: orientationMode,
      isMuted: isMuted,
      isAutoPlay: isAutoPlay,
      autoResumeAfterInterruption: autoResumeAfterInterruption,
      fullscreenGestureBackExcluded: fullscreenGestureBackExcluded,
      hiddenLibraryIds: hiddenLibraryIds,
      defaultPlaybackRate: defaultPlaybackRate,
      defaultSubtitleLanguage: defaultSubtitleLanguage,
      subtitleSize: subtitleSize,
      feedExcludePlayed: feedExcludePlayed,
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
      recommendNextUpSeriesCount: recommendNextUpSeriesCount,
      recommendFavActorNewCount: recommendFavActorNewCount,
      followActorVideoCount: followActorVideoCount,
      followOnlyUnwatched: followOnlyUnwatched,
      followMaxActors: followMaxActors,
      recommendTagSourceMapping: recommendTagSourceMapping,
    );
  }

  // 保存全部偏好设置
  Future<void> save(AppPreferences preferences) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(kStorageKeyForceDeviceMode,
          preferences.forceDeviceMode.toStorageString()),
      prefs.setString(
          kStorageKeyFeedType, preferences.feedType.toStorageString()),
      prefs.setString(
          kStorageKeyViewMode, preferences.viewMode.toStorageString()),
      prefs.setString(kStorageKeyOrientationMode,
          preferences.orientationMode.toStorageString()),
      prefs.setBool(kStorageKeyIsMuted, preferences.isMuted),
      prefs.setBool(kStorageKeyIsAutoPlay, preferences.isAutoPlay),
      prefs.setBool(kStorageKeyAutoResumeAfterInterruption,
          preferences.autoResumeAfterInterruption),
      prefs.setBool(kStorageKeyFullscreenGestureBackExcluded,
          preferences.fullscreenGestureBackExcluded),
      prefs.setString(kStorageKeyHiddenLibraryIds,
          json.encode(preferences.hiddenLibraryIds.toList(growable: false))),
      prefs.setDouble(
          kStorageKeyDefaultPlaybackRate, preferences.defaultPlaybackRate),
      prefs.setString(kStorageKeyDefaultSubtitleLanguage,
          preferences.defaultSubtitleLanguage),
      prefs.setString(kStorageKeySubtitleSize, preferences.subtitleSize),
      // 视频流排除已观看
      prefs.setBool(
          kStorageKeyFeedExcludePlayed, preferences.feedExcludePlayed),
      // PR #78：推荐规则偏好
      prefs.setDouble(
          kStorageKeyRecommendMinRating, preferences.recommendMinRating),
      prefs.setBool(kStorageKeyRecommendExcludePlayed,
          preferences.recommendExcludePlayed),
      prefs.setInt(kStorageKeyRecommendMinRuntimeSec,
          preferences.recommendMinRuntimeSec),
      // PR #79：类型偏好
      prefs.setStringList(
        kStorageKeyRecommendIncludeTypes,
        preferences.recommendIncludeTypes.toList(growable: false),
      ),
      // PR #85：用户控制推荐门控
      prefs.setBool(kStorageKeyRecommendUseWatchHistory,
          preferences.recommendUseWatchHistory),
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
      // 追剧队列数量平衡
      prefs.setInt(kStorageKeyRecommendNextUpSeriesCount,
          preferences.recommendNextUpSeriesCount),
      prefs.setInt(kStorageKeyRecommendFavActorNewCount,
          preferences.recommendFavActorNewCount),
      // 关注页：每演员视频数 / 只看未观看
      prefs.setInt(
          kStorageKeyFollowActorVideoCount, preferences.followActorVideoCount),
      prefs.setBool(
          kStorageKeyFollowOnlyUnwatched, preferences.followOnlyUnwatched),
      prefs.setInt(kStorageKeyFollowMaxActors, preferences.followMaxActors),
      // 推荐标签数据源映射
      prefs.setString(kStorageKeyRecommendTagSourceMapping,
          json.encode(preferences.recommendTagSourceMapping)),
    ]);
  }

  /// 重置所有偏好设置到默认值
  ///
  /// 仅清除"设置类"偏好（播放、字幕、外观、推荐、媒体库、家长控制等），
  /// 不影响用户数据（登录信息、观看历史、搜索历史、收藏、缓存等）。
  /// 注意：Notifier 的 state 为进程内存值，_load() 只在构造时执行一次；
  /// 本方法只删除持久化 key，界面会在重启后回退到默认值
  /// （batch40-F1 配套：重置对话框文案已同步说明"重启后生效"）。
  Future<void> resetAllSettings() async {
    final prefs = await SharedPreferences.getInstance();
    // 需要重置的偏好 key 列表：播放/字幕/外观/推荐/媒体库/发现/关注/家长控制/PIN/智能缓存/服务模式等设置类 key；
    // 有意保留：登录与账户（kStorageKeyConfig/User/EmbyServerUrl/ActiveServerId/ServerRegistry/
    // SavedCredentials/AccessToken/ServerHistory/LastFmApiKey）、观看历史（WatchStats/recent_playbacks）、
    // 搜索历史/收藏与内容缓存、导航恢复与 UI 会话态（LastPageIndex/LastGridScrollOffset/LastFeedVideoIndex/
    // LastFeedVideoItemId/PlaybackShellPosition/RecommendScrollOffset/RecommendGridColumns/Actors*）、
    // 更新提示状态（UpdateCheckCache/update_shown_ver/update_skipped_ver）与配置标记（*LibraryConfigured）。
    const keysToRemove = <String>[
      kStorageKeyForceDeviceMode,
      kStorageKeyFeedType,
      kStorageKeyViewMode,
      kStorageKeyOrientationMode,
      kStorageKeyIsMuted,
      kStorageKeyIsAutoPlay,
      kStorageKeyAutoResumeAfterInterruption,
      kStorageKeyFullscreenGestureBackExcluded,
      kStorageKeyHiddenLibraryIds,
      kStorageKeyDefaultPlaybackRate,
      kStorageKeyDefaultSubtitleLanguage,
      kStorageKeySubtitleSize,
      kStorageKeyFeedExcludePlayed,
      kStorageKeyRecommendMinRating,
      kStorageKeyRecommendExcludePlayed,
      kStorageKeyRecommendMinRuntimeSec,
      kStorageKeyRecommendIncludeTypes,
      kStorageKeyRecommendUseWatchHistory,
      kStorageKeyRecommendHalfLifeDays,
      kStorageKeyRecommendAntiFatigueEnabled,
      kStorageKeyRecommendAntiFatigueDays,
      kStorageKeyRecommendUserRatingEnabled,
      kStorageKeyRecommendUserRatingMin,
      kStorageKeyFollowActorVideoCount,
      kStorageKeyFollowOnlyUnwatched,
      kStorageKeyRecommendTagSourceMapping,
      // —— batch40-F1 补全：此前遗漏的设置类 key ——
      kStorageKeySubtitle, // 字幕扩展设置（颜色/位置/阴影/偏移）
      kStorageKeyAllowSelfSignedCertificate, // 网络-允许自签名证书
      kStorageKeyPreferredDownloadMirror, // 下载-首选镜像
      kStorageKeyDiscoverGenres, // 发现页-类型
      kStorageKeyDiscoverTags, // 发现页-标签
      kStorageKeyDiscoverCollections, // 发现页-合集
      kStorageKeyRecommendNextUpSeriesCount, // 推荐-下一集数量
      kStorageKeyRecommendFavActorNewCount, // 推荐-关注演员新片数量
      kStorageKeyFollowMaxActors, // 关注-最大演员数
      kStorageKeyFavoriteIncludeTypes, // 收藏-包含类型
      kStorageKeySelectedLibraryId, // 媒体库-选择
      kStorageKeySelectedLibraryIdForRecommend, // 媒体库-推荐页选择
      'app_service_mode', // 服务模式（视频/音乐）（service_mode_provider._kStorageKeyServiceMode 私有常量，字面量对齐）
      'embytok_theme_mode', // 外观-主题（theme_provider._kStorageKeyTheme 私有常量，字面量对齐）
      'app_locale_language_code', // 语言（app_translations.dart 私有 key）
      'audio_offset_ms', // 播放-音频偏移（AudioOffsetNotifier._key）
      'video_fit_mode', // 播放-画面缩放（VideoFitModeNotifier._key）
      'auto_play_next', // 播放-自动连播下一集（AutoPlayNextNotifier._key）
      'parental_kids_mode', // 家长控制-儿童模式
      'parental_max_rating', // 家长控制-最高分级
      'parental_hide_restricted', // 家长控制-隐藏受限内容
      'app_pin_code', // 安全-PIN 锁（PinLockNotifier）
      'smart_cache_cleanup', // 存储-智能缓存清理（batch39-F1 开关）
      'log_min_level', // 日志-最小级别
      'move_failed_enabled', // 文件管理-失败移动开关
      // —— batch41-F3/F4 配套：新增持久化设置 key ——
      'danmaku_enabled', // 播放-弹幕开关（DanmakuEnabledNotifier._key，batch41-F3 起持久化）
      'playback_info_osd_enabled', // 播放-信息浮层开关（PlaybackInfoOsdNotifier._key，batch41-F3 起持久化）
      'nas_sync_enabled', // 音乐库-NAS 元数据同步开关（ArtistMetadataService，batch41-F4 起持久化）
    ];
    await Future.wait(
      keysToRemove.map((key) => prefs.remove(key)),
    );
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
    await prefs.setString(
        kStorageKeyHiddenLibraryIds, json.encode(ids.toList(growable: false)));
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

  // 单独更新字幕大小
  Future<void> setSubtitleSize(String size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kStorageKeySubtitleSize, size);
  }
}
