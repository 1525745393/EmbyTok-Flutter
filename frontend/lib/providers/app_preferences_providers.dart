/// 应用级偏好 Provider
///
/// 负责：feedType、viewMode、orientationMode、deviceMode、hiddenLibraryIds 的状态管理。
/// 所有状态变化时自动持久化到 SharedPreferences。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/app_preferences.dart';
import '../utils/logger.dart';

// ---------------- 设备模式（standard / tv） ----------------

/// 设备模式：standard（标准竖屏）/ tv（TV 遥控器模式）
///
/// 切换模式后自动持久化，下次启动沿用上次选择。
class DeviceModeNotifier extends StateNotifier<DeviceMode> {
  DeviceModeNotifier() : super(DeviceMode.standard) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await const AppPreferencesService().load();
    state = prefs.forceDeviceMode;
  }

  Future<void> setMode(DeviceMode mode) async {
    state = mode;
    await const AppPreferencesService().setForceDeviceMode(mode);
  }
}

/// 顶层设备模式 Provider
final deviceModeProvider =
    StateNotifierProvider<DeviceModeNotifier, DeviceMode>((ref) => DeviceModeNotifier());

// ---------------- feedType（最新/随机/收藏） ----------------

/// 浏览模式：latest / random / favorites / resume
class FeedTypeNotifier extends StateNotifier<FeedType> {
  FeedTypeNotifier() : super(FeedType.latest) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await const AppPreferencesService().load();
    state = prefs.feedType;
  }

  Future<void> setType(FeedType type) async {
    state = type;
    await const AppPreferencesService().setFeedType(type);
  }
}

/// 顶层浏览模式 Provider
final feedTypeProvider =
    StateNotifierProvider<FeedTypeNotifier, FeedType>((ref) => FeedTypeNotifier());

// ---------------- viewMode（视频流/网格） ----------------

/// 视图模式：feed（视频流）/ grid（网格）
class ViewModeNotifier extends StateNotifier<ViewMode> {
  ViewModeNotifier() : super(ViewMode.feed) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await const AppPreferencesService().load();
    state = prefs.viewMode;
  }

  Future<void> setMode(ViewMode mode) async {
    state = mode;
    await const AppPreferencesService().setViewMode(mode);
  }
}

/// 顶层视图模式 Provider
final viewModeProvider =
    StateNotifierProvider<ViewModeNotifier, ViewMode>((ref) => ViewModeNotifier());

// ---------------- orientationMode ----------------

/// 方向过滤模式：vertical / horizontal / both
class OrientationModeNotifier extends StateNotifier<OrientationMode> {
  OrientationModeNotifier() : super(OrientationMode.both) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await const AppPreferencesService().load();
    state = prefs.orientationMode;
  }

  Future<void> setMode(OrientationMode mode) async {
    state = mode;
    await const AppPreferencesService().setOrientationMode(mode);
  }
}

/// 顶层方向过滤模式 Provider
final orientationModeProvider =
    StateNotifierProvider<OrientationModeNotifier, OrientationMode>(
  (ref) => OrientationModeNotifier(),
);

// ---------------- hiddenLibraryIds ----------------

/// 隐藏媒体库 ID 集合：在设置中勾选/取消，下次启动沿用
class HiddenLibraryIdsNotifier extends StateNotifier<Set<String>> {
  HiddenLibraryIdsNotifier() : super(const <String>{}) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await const AppPreferencesService().load();
    state = prefs.hiddenLibraryIds;
  }

  Future<void> toggle(String libId) async {
    final newSet = Set<String>.from(state);
    if (newSet.contains(libId)) {
      newSet.remove(libId);
    } else {
      newSet.add(libId);
    }
    state = newSet;
    await const AppPreferencesService().setHiddenLibraryIds(newSet);
  }

  Future<void> clear() async {
    state = const <String>{};
    await const AppPreferencesService().setHiddenLibraryIds(const <String>{});
  }
}

/// 顶层隐藏媒体库 ID 集合 Provider
final hiddenLibraryIdsProvider =
    StateNotifierProvider<HiddenLibraryIdsNotifier, Set<String>>(
  (ref) => HiddenLibraryIdsNotifier(),
);

/// 注意：[isMutedProvider] 和 [isAutoPlayProvider] 在 `video_playback_controller.dart` 中定义，
/// 避免重复定义导致编译错误。

// ---------------- PR #78：推荐规则偏好 ----------------

/// 推荐评分阈值（Emby 满分 10，0 表示不过滤）
/// 默认 4.0，与 Emby 默认推荐质量一致
class RecommendMinRatingNotifier extends StateNotifier<double> {
  RecommendMinRatingNotifier() : super(4.0) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await const AppPreferencesService().load();
    state = prefs.recommendMinRating;
  }

  Future<void> setRating(double rating) async {
    // 限制范围 [0, 10]，0 表示不过滤
    final clamped = rating.clamp(0.0, 10.0);
    state = clamped;
    final current = await const AppPreferencesService().load();
    await const AppPreferencesService().save(
      current.copyWith(recommendMinRating: clamped),
    );
  }
}

final recommendMinRatingProvider =
    StateNotifierProvider<RecommendMinRatingNotifier, double>(
  (ref) => RecommendMinRatingNotifier(),
);

/// 推荐排除已观看开关（默认 true）
class RecommendExcludePlayedNotifier extends StateNotifier<bool> {
  RecommendExcludePlayedNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await const AppPreferencesService().load();
    state = prefs.recommendExcludePlayed;
  }

  Future<void> setExclude(bool value) async {
    state = value;
    final current = await const AppPreferencesService().load();
    await const AppPreferencesService().save(
      current.copyWith(recommendExcludePlayed: value),
    );
  }
}

final recommendExcludePlayedProvider =
    StateNotifierProvider<RecommendExcludePlayedNotifier, bool>(
  (ref) => RecommendExcludePlayedNotifier(),
);

/// 推荐最短时长过滤（秒，默认 30）
/// 过滤测试片 / 预告片（< 30s）
class RecommendMinRuntimeSecNotifier extends StateNotifier<int> {
  RecommendMinRuntimeSecNotifier() : super(30) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await const AppPreferencesService().load();
    state = prefs.recommendMinRuntimeSec;
  }

  Future<void> setMinRuntime(int seconds) async {
    // 0 表示不过滤
    final clamped = seconds.clamp(0, 3600);
    state = clamped;
    final current = await const AppPreferencesService().load();
    await const AppPreferencesService().save(
      current.copyWith(recommendMinRuntimeSec: clamped),
    );
  }
}

final recommendMinRuntimeSecProvider =
    StateNotifierProvider<RecommendMinRuntimeSecNotifier, int>(
  (ref) => RecommendMinRuntimeSecNotifier(),
);

/// PR #79：推荐 - 类型偏好（Set<String>）
/// 默认：Movie, Episode, Video, MusicVideo, Series
class RecommendIncludeTypesNotifier extends StateNotifier<Set<String>> {
  RecommendIncludeTypesNotifier()
      : super(const <String>{
          'Movie',
          'Episode',
          'Video',
          'MusicVideo',
          'Series',
        }) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await const AppPreferencesService().load();
    state = prefs.recommendIncludeTypes;
  }

  /// 切换某个类型
  Future<void> toggle(String type) async {
    final next = state.contains(type)
        ? (state.toSet()..remove(type))
        : (state.toSet()..add(type));
    // 至少保留一个类型（避免全空）
    if (next.isEmpty) {
      AppLogger.debug('推荐：类型偏好不能全空');
      return;
    }
    state = next;
    final current = await const AppPreferencesService().load();
    await const AppPreferencesService().save(
      current.copyWith(recommendIncludeTypes: next),
    );
  }
}

final recommendIncludeTypesProvider =
    StateNotifierProvider<RecommendIncludeTypesNotifier, Set<String>>(
  (ref) => RecommendIncludeTypesNotifier(),
);
