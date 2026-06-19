// 视频播放控制器：当前播放条目、播放位置、倍速、字幕、播放就绪状态

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../models/models.dart';
import '../utils/app_preferences.dart';
import '../utils/constants.dart';

// 当前正在播放的媒体条目
final currentPlayingItemProvider = StateProvider<MediaItem?>((ref) => null);

// 当前播放位置（秒）
final currentPositionProvider = StateProvider<Duration>((ref) => Duration.zero);

// 是否正在播放
final isPlayingProvider = StateProvider<bool>((ref) => false);

// 当前视频索引（用于网格视图跳转）
final currentIndexProvider = StateProvider<int>((ref) => 0);

// 是否全屏播放
final isFullscreenProvider = StateProvider<bool>((ref) => false);

// 当前播放的 VideoPlayerController（用于全局 seek 操作，播放结束时的连播跳转等）
// 当 VideoPageItem 播放初始化成功后写入，dispose 时清空
final currentVideoControllerProvider = StateProvider<VideoPlayerController?>((ref) => null);

// 当前播放的降级等级：0=DirectPlay，1=DirectStream，2=HLS
// 在 VideoPlayerWidget 内成功切换播放 URL 时更新
class PlaybackLevelNotifier extends StateNotifier<int> {
  PlaybackLevelNotifier() : super(0);

  void setLevel(int level) {
    if (level >= 0 && level <= 2) state = level;
  }

  void reset() {
    state = 0;
  }
}

final playbackLevelProvider =
    StateNotifierProvider<PlaybackLevelNotifier, int>(
  (ref) => PlaybackLevelNotifier(),
);

// 当前播放倍速：1.0 / 1.25 / 1.5 / 2.0
final playbackRateProvider = StateProvider<double>((ref) => 1.0);

// 当前选中的字幕（字幕语言或轨道 ID，null 表示关闭）
final selectedSubtitleProvider = StateProvider<String?>((ref) => null);

// ---------------- videoReadyProvider：记录哪些 item 的视频已就绪 ----------------
// 用于驱动页面切换的渐入动画：controller 初始化完成后标记该 item 为 ready
class VideoReadyNotifier extends StateNotifier<Set<String>> {
  VideoReadyNotifier() : super({});

  void markReady(String itemId) {
    if (!state.contains(itemId)) {
      state = {...state, itemId};
    }
  }

  void clear(String itemId) {
    if (state.contains(itemId)) {
      final next = Set<String>.from(state);
      next.remove(itemId);
      state = next;
    }
  }

  bool isReady(String itemId) => state.contains(itemId);
}

final videoReadyProvider =
    StateNotifierProvider<VideoReadyNotifier, Set<String>>(
  (ref) => VideoReadyNotifier(),
);

// ---------------- preloadThresholdProvider：预加载阈值 ----------------
class PreloadThresholdNotifier extends StateNotifier<double> {
  PreloadThresholdNotifier() : super(kDefaultPreloadThreshold);

  void setThreshold(double value) {
    if (value >= 0.1 && value <= 0.95) state = value;
  }
}

final preloadThresholdProvider =
    StateNotifierProvider<PreloadThresholdNotifier, double>(
  (ref) => PreloadThresholdNotifier(),
);

// ---------------- isMuted（自动播放前是否静音） ----------------
class IsMutedNotifier extends StateNotifier<bool> {
  IsMutedNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await const AppPreferencesService().load();
    state = prefs.isMuted;
  }

  Future<void> setMuted(bool value) async {
    state = value;
    await const AppPreferencesService().setIsMuted(value);
  }

  Future<void> toggle() async {
    await setMuted(!state);
  }
}

final isMutedProvider =
    StateNotifierProvider<IsMutedNotifier, bool>((ref) => IsMutedNotifier());

// ---------------- isAutoPlay（自动播放下一集） ----------------
class IsAutoPlayNotifier extends StateNotifier<bool> {
  IsAutoPlayNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await const AppPreferencesService().load();
    state = prefs.isAutoPlay;
  }

  Future<void> setEnabled(bool value) async {
    state = value;
    await const AppPreferencesService().setIsAutoPlay(value);
  }

  Future<void> toggle() async {
    await setEnabled(!state);
  }
}

final isAutoPlayProvider =
    StateNotifierProvider<IsAutoPlayNotifier, bool>(
  (ref) => IsAutoPlayNotifier(),
);
