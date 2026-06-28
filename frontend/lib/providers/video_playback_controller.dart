// 视频播放控制器：当前播放条目、播放位置、倍速、字幕、播放就绪状态

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../models/models.dart';
import '../services/embbytok_service.dart';
import '../utils/app_preferences.dart';
import '../utils/constants.dart';

/// 全局 EmbytokService 实例（用于加载字幕、上报播放状态等）
final embbytokServiceProvider = Provider<EmbytokService>((ref) => EmbytokService());

/// 当前正在播放的视频 ID（仅 ID，不存对象引用）
///
/// 用途：作为"上一帧播了谁"的 session 状态，供其他视图（网格、收藏、历史）回显高亮。
///
/// 设计原则：
/// - 仅存 ID，避免对象引用陈旧
/// - 不持久化，进程内有效，重启清空
/// - 由 feed_view.onPageChanged 写入（权威源）
/// - 由 _jumpToPageWhenReady 写入（程序化跳转时）
/// - 网格等视图只读不写
final currentPlayingIdProvider = StateProvider<String?>((ref) => null);

/// 当前正在播放的媒体条目（供详情页/控制层引用）
///
/// 这是"视频流内"的当前播放信号源：
/// - 由 feed_view 的 onPageChanged 写入（PageView 真正切换完成时）
/// - 由 _jumpToPageWhenReady 写入（程序化跳转时）
/// - 由 video_page_item.onControllerReady 写入（兜底）
/// - 跨视图（feed ↔ grid）时通过 itemId 透传，不依赖此 provider 的历史值
final currentPlayingItemProvider = StateProvider<MediaItem?>((ref) => null);

/// 当前播放位置（用于跳转后记忆续播进度）
final currentPositionProvider = StateProvider<Duration>((ref) => Duration.zero);

/// 是否正在播放（用于中央播放按钮显示）
final isPlayingProvider = StateProvider<bool>((ref) => false);

/// 是否全屏播放（控制横屏沉浸模式切换）
final isFullscreenProvider = StateProvider<bool>((ref) => false);

/// 当前播放的 [VideoPlayerController]：用于全局 seek、快捷键操作、播放结束连播
///
/// 在 [VideoPageItem] 初始化成功后写入，组件 dispose 时清空。
final currentVideoControllerProvider = StateProvider<VideoPlayerController?>((ref) => null);

/// FeedView 外部跳页请求：全屏页（FullscreenVideoPage）等需要切换视频时设置目标 index
///
/// FullscreenVideoPage 中"上一集/下一集"按钮无法直接调用 FeedView 的 _pageController，
/// 因此通过这个 Provider 通知 FeedView 跳转到指定 index。
///
/// 设计：
/// - 设置为非 null 时触发跳转
/// - FeedView 处理完成后立即 reset 为 null（避免重复触发）
/// - 不传 pageController 引用，避免 widget 重建时引用错位
final feedViewPageJumpRequestProvider = StateProvider<int?>((ref) => null);

/// 播放降级等级 Notifier：0=DirectPlay，1=DirectStream，2=HLS 转码
///
/// 等级越高代表越保守的播放策略，用于不同网速下的自适应降级。
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

/// 当前播放倍速：1.0 / 1.25 / 1.5 / 2.0
final playbackRateProvider = StateProvider<double>((ref) => 1.0);

/// 当前选中的字幕轨道（语言或轨道 ID，null 表示关闭字幕）
final selectedSubtitleProvider = StateProvider<String?>((ref) => null);

/// videoReadyProvider：记录哪些 item 的视频已就绪
///
/// 用于驱动页面切换的渐入动画：
/// controller 初始化完成后标记该 item 为 ready，实现从骨架屏到视频的平滑过渡。
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

/// preloadThresholdProvider：预加载阈值（0.1 - 0.95）
///
/// 控制当当前视频播放进度达到多少后触发下一条视频的预加载。
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

/// isMutedProvider：是否静音自动播放
///
/// 从本地持久化存储读取，切换后自动保存。用于控制视频自动播放时是否静音。
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

/// isAutoPlayProvider：是否自动播放下一集 / 下一条
///
/// 从本地持久化存储读取，切换后自动保存。
class IsAutoPlayNotifier extends StateNotifier<bool> {
  // PR #72：初始值与 AppPreferences.isAutoPlay 默认值保持一致（false），
  // 避免 _load() 异步加载完成前短暂触发"纯净模式 → 工具栏隐藏"闪烁。
  IsAutoPlayNotifier() : super(false) {
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
