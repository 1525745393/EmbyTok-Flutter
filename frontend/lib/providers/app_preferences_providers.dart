// 应用级偏好 Provider（Task 2 新增）
// 负责：feedType、viewMode、orientationMode、isMuted、isAutoPlay、hiddenLibraryIds 的状态管理
// 所有状态变化时自动持久化到 SharedPreferences。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/app_preferences.dart';

// ---------------- 设备模式（standard / tv） ----------------
// 初始值从 SharedPreferences 异步加载，设备模式变更时自动持久化
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

final deviceModeProvider =
    StateNotifierProvider<DeviceModeNotifier, DeviceMode>((ref) => DeviceModeNotifier());

// ---------------- feedType（最新/随机/收藏） ----------------
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

final feedTypeProvider =
    StateNotifierProvider<FeedTypeNotifier, FeedType>((ref) => FeedTypeNotifier());

// ---------------- viewMode（视频流/网格） ----------------
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

final viewModeProvider =
    StateNotifierProvider<ViewModeNotifier, ViewMode>((ref) => ViewModeNotifier());

// ---------------- orientationMode ----------------
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

final orientationModeProvider =
    StateNotifierProvider<OrientationModeNotifier, OrientationMode>(
  (ref) => OrientationModeNotifier(),
);

// ---------------- hiddenLibraryIds ----------------
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

final hiddenLibraryIdsProvider =
    StateNotifierProvider<HiddenLibraryIdsNotifier, Set<String>>(
  (ref) => HiddenLibraryIdsNotifier(),
);

// 注意：isMutedProvider 和 isAutoPlayProvider 在 video_playback_controller.dart 中定义，
// 避免重复定义导致编译错误。
