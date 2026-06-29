/// 应用级偏好 Provider
///
/// 负责：feedType、viewMode、orientationMode、deviceMode、hiddenLibraryIds 的状态管理。
/// 所有状态变化时自动持久化到 SharedPreferences。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

// PR #85：用户控制推荐门控（完播率门控开关）
// - true（默认）：用完播率历史计算用户行为信号（黑名单/权重/种子）
// - false：使用默认信号（无门控，推荐结果完全由 Emby 服务器决定）
class RecommendUseWatchHistoryNotifier extends StateNotifier<bool> {
  RecommendUseWatchHistoryNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await const AppPreferencesService().load();
    state = prefs.recommendUseWatchHistory;
  }

  Future<void> setUse(bool value) async {
    state = value;
    final current = await const AppPreferencesService().load();
    await const AppPreferencesService().save(
      current.copyWith(recommendUseWatchHistory: value),
    );
  }
}

final recommendUseWatchHistoryProvider =
    StateNotifierProvider<RecommendUseWatchHistoryNotifier, bool>(
  (ref) => RecommendUseWatchHistoryNotifier(),
);

// PR #85：用户控制 - 时间衰减半衰期（天）
// - 0 = 不衰减（所有记录等权重，与 PR #84 之前行为一致）
// - 14 = 默认 14 天半衰期
// - 范围 [0, 90]（3 个月为最大记忆窗口）
class RecommendHalfLifeDaysNotifier extends StateNotifier<double> {
  RecommendHalfLifeDaysNotifier() : super(14.0) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await const AppPreferencesService().load();
    state = prefs.recommendHalfLifeDays;
  }

  Future<void> setDays(double days) async {
    // 范围限制 [0, 90]
    final clamped = days.clamp(0.0, 90.0);
    state = clamped;
    final current = await const AppPreferencesService().load();
    await const AppPreferencesService().save(
      current.copyWith(recommendHalfLifeDays: clamped),
    );
  }
}

final recommendHalfLifeDaysProvider =
    StateNotifierProvider<RecommendHalfLifeDaysNotifier, double>(
  (ref) => RecommendHalfLifeDaysNotifier(),
);

// PR #88：用户控制 - 反推荐疲劳（30 天内不重推）开关
class RecommendAntiFatigueEnabledNotifier extends StateNotifier<bool> {
  RecommendAntiFatigueEnabledNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await const AppPreferencesService().load();
    state = prefs.recommendAntiFatigueEnabled;
  }

  Future<void> setEnabled(bool value) async {
    state = value;
    final current = await const AppPreferencesService().load();
    await const AppPreferencesService().save(
      current.copyWith(recommendAntiFatigueEnabled: value),
    );
  }
}

final recommendAntiFatigueEnabledProvider =
    StateNotifierProvider<RecommendAntiFatigueEnabledNotifier, bool>(
  (ref) => RecommendAntiFatigueEnabledNotifier(),
);

// PR #88：用户控制 - 反推荐疲劳天数（默认 30）
class RecommendAntiFatigueDaysNotifier extends StateNotifier<int> {
  RecommendAntiFatigueDaysNotifier() : super(30) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await const AppPreferencesService().load();
    state = prefs.recommendAntiFatigueDays;
  }

  Future<void> setDays(int days) async {
    // 范围限制 [1, 90]
    final clamped = days.clamp(1, 90);
    state = clamped;
    final current = await const AppPreferencesService().load();
    await const AppPreferencesService().save(
      current.copyWith(recommendAntiFatigueDays: clamped),
    );
  }
}

final recommendAntiFatigueDaysProvider =
    StateNotifierProvider<RecommendAntiFatigueDaysNotifier, int>(
  (ref) => RecommendAntiFatigueDaysNotifier(),
);

// PR #88：最近展示过的 itemId 列表（用于反推荐疲劳）
// - Set<String> 表示 itemId
// - 持久化到 SharedPreferences
// - 最多保留 500 个（FIFO 清理）
class RecentlyShownItemIdsNotifier extends StateNotifier<Set<String>> {
  RecentlyShownItemIdsNotifier() : super(<String>{}) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(kStorageKeyRecentlyShownItemIds) ??
        const <String>[];
    state = list.toSet();
  }

  Future<void> addAll(Iterable<String> itemIds) async {
    if (itemIds.isEmpty) return;
    final next = <String>{...state, ...itemIds};
    // 容量限制 500，超过则删除最早的部分（FIFO 通过 List 维护）
    const int maxCount = 500;
    if (next.length > maxCount) {
      // 转换为 list 保留插入顺序，删除最前面的
      final ordered = <String>[...next];
      state = ordered.sublist(ordered.length - maxCount).toSet();
    } else {
      state = next;
    }
    await _persist();
  }

  Future<void> clear() async {
    state = <String>{};
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        kStorageKeyRecentlyShownItemIds, state.toList(growable: false));
  }
}

final recentlyShownItemIdsProvider =
    StateNotifierProvider<RecentlyShownItemIdsNotifier, Set<String>>(
  (ref) => RecentlyShownItemIdsNotifier(),
);
