// 群晖 Audio Station 音乐播放控制器
//
// 使用 video_player 播放音频流（与视频播放系统完全解耦）：
// - 支持播放队列（歌曲列表 / 专辑 / 歌单 / 搜索结果）
// - 上一首 / 下一首 / 暂停 / 继续 / 跳转
// - 通过 AudioSessionHandler 申请音频焦点，来电/其他 App 播放时自动暂停
// - 提供 mini player 所需的实时状态（曲目、封面、进度、时长）

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import '../models/audio_models.dart';
import '../services/synology_download_service.dart';
import '../services/lrclib_service.dart';
import '../services/music_widget_updater.dart';
import '../services/lyrics_edit_store.dart';
import 'play_events_provider.dart';
import '../utils/logger.dart';
import 'audio_focus_provider.dart';
import 'audio_handler_provider.dart';
import 'recent_playbacks_provider.dart';
import 'synology_auth_provider.dart';
part 'synology_parts/synology_playback_internal.dart';

/// 播放模式
enum SynologyPlaybackMode {
  listLoop('列表循环'),
  singleLoop('单曲循环'),
  shuffle('随机播放');

  const SynologyPlaybackMode(this.label);

  final String label;
}

/// 睡眠定时器到点后的停止行为
enum SleepTimerBehavior {
  /// 立即暂停（默认）
  immediateStop,

  /// 等当前歌曲自然播完再暂停（不打断当前歌曲）
  currentSongEnd;

  String get label => switch (this) {
        SleepTimerBehavior.immediateStop => '立即停止',
        SleepTimerBehavior.currentSongEnd => '当前歌曲结束后停止',
      };
}

/// 音乐播放状态
class SynologyPlaybackState {
  const SynologyPlaybackState({
    this.currentSong,
    this.queue = const [],
    this.currentIndex = -1,
    this.isPlaying = false,
    this.isLoading = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.error,
    this.coverUrl,
    this.mode = SynologyPlaybackMode.listLoop,
    this.lyrics,
    this.isLoadingLyrics = false,
    this.sleepTimerEndsAtMs,
    this.sleepTimerBehavior = SleepTimerBehavior.immediateStop,
    this.sleepTimerFadeOut = true,
  });
  final AudioSong? currentSong;
  final List<AudioSong> queue;
  final int currentIndex;
  final bool isPlaying;
  final bool isLoading;
  final Duration position;
  final Duration duration;
  final String? error;
  final String? coverUrl;
  final SynologyPlaybackMode mode;

  /// 当前歌曲 LRC 歌词原文（null=无歌词）
  final String? lyrics;

  /// 歌词加载中
  final bool isLoadingLyrics;

  // ===== 睡眠定时器 =====
  /// 定时到期时间（epoch 毫秒）；null 表示未开启
  final int? sleepTimerEndsAtMs;

  /// 到点停止行为
  final SleepTimerBehavior sleepTimerBehavior;

  /// 停止前是否 30 秒渐进淡出
  final bool sleepTimerFadeOut;

  /// 睡眠定时器是否启用
  bool get sleepTimerActive => sleepTimerEndsAtMs != null;

  /// 剩余秒数（未启用返回 0）
  int get sleepTimerRemainingSeconds {
    final ends = sleepTimerEndsAtMs;
    if (ends == null) return 0;
    final remainingMs = ends - DateTime.now().millisecondsSinceEpoch;
    return remainingMs <= 0 ? 0 : (remainingMs / 1000).ceil();
  }

  /// 是否已有曲目（用于 mini player 显隐）
  bool get hasSong => currentSong != null;

  SynologyPlaybackState copyWith({
    AudioSong? currentSong,
    List<AudioSong>? queue,
    int? currentIndex,
    bool? isPlaying,
    bool? isLoading,
    Duration? position,
    Duration? duration,
    String? error,
    String? coverUrl,
    SynologyPlaybackMode? mode,
    String? lyrics,
    bool? isLoadingLyrics,
    int? sleepTimerEndsAtMs,
    SleepTimerBehavior? sleepTimerBehavior,
    bool? sleepTimerFadeOut,
    bool clearSleepTimer = false,
  }) {
    return SynologyPlaybackState(
      currentSong: currentSong ?? this.currentSong,
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      error: error ?? this.error,
      coverUrl: coverUrl ?? this.coverUrl,
      mode: mode ?? this.mode,
      lyrics: lyrics ?? this.lyrics,
      isLoadingLyrics: isLoadingLyrics ?? this.isLoadingLyrics,
      sleepTimerEndsAtMs: clearSleepTimer
          ? null
          : (sleepTimerEndsAtMs ?? this.sleepTimerEndsAtMs),
      sleepTimerBehavior: sleepTimerBehavior ?? this.sleepTimerBehavior,
      sleepTimerFadeOut: sleepTimerFadeOut ?? this.sleepTimerFadeOut,
    );
  }
}

class SynologyPlaybackNotifier extends StateNotifier<SynologyPlaybackState> {
  SynologyPlaybackNotifier(this._ref) : super(const SynologyPlaybackState()) {
    // 中断回调：焦点丢失暂停 / 恢复续播
    final handler = _ref.read(audioSessionHandlerProvider);
    handler.onPauseRequested = _handleFocusLost;
    handler.onResumeRequested = _handleFocusGained;
  }
  final Ref _ref;

  VideoPlayerController? _controller;
  Timer? _positionTimer;
  bool _disposed = false;
  final Random _random = Random();

  /// 恢复播放时待 seek 的进度（restorePlayback 设置，_playSong 播放后清除）
  Duration? _pendingSeek;

  // ===== 睡眠定时器内部状态 =====
  /// currentSongEnd 模式到点后，等本次自然播完再暂停
  bool _stopAfterThisSong = false;

  /// 渐进淡出前记录的原始音量（取消/结束时恢复）
  double _normalVolume = 1.0;

  /// 连续播放失败计数：断网/服务端异常时熔断，避免顺序试完整队列
  int _consecutiveFailures = 0;
  static const int _kMaxConsecutiveFailures = 3;

  static const String _kSleepTimerKey = 'sleep_timer_v1';

  // ============================
  // 播放控制
  // ============================

  /// 播放队列中的第 [index] 首
  Future<void> playQueue(List<AudioSong> queue, int index) async {
    if (queue.isEmpty || index < 0 || index >= queue.length) return;
    final song = queue[index];
    state = SynologyPlaybackState(
      currentSong: song,
      queue: queue,
      currentIndex: index,
      isLoading: true,
      coverUrl: _coverUrlOf(song),
    );
    // 同步桌面 Widget 曲名
    updateMusicWidget(song.title);
    // 写入最近播放记录（PRD 首页核心模块，客户端本地存储）
    try {
      _ref.read(recentPlaybacksProvider.notifier).add(RecentPlayback(
            mediaId: song.id,
            mediaType: RecentPlaybackType.song,
            title: song.title,
            subtitle: song.artistDisplay,
            coverUrl: _coverUrlOf(song),
            lastPlayTime: DateTime.now().millisecondsSinceEpoch,
          ));
      // 记录完整播放事件（供播放统计聚合）
      _ref.read(playEventsProvider.notifier).add(PlayEvent(
            songId: song.id,
            title: song.title,
            artist: song.artistDisplay,
            album: song.tag?.album ?? '',
            durationSeconds: song.audio?.duration ?? 0,
            playedAtMs: DateTime.now().millisecondsSinceEpoch,
          ));
    } catch (_) {
      // 存储操作失败不影响主流程，静默处理
    }
    await _playSong(song);
    // 切歌时仅持久化队列和索引，不持久化进度（新歌曲 position 为 0）
    _persistPlayback(persistPosition: false);
  }

  /// 播放单曲（队列为该曲目单曲）
  Future<void> playSong(AudioSong song) => playQueue([song], 0);

  // ===== 播放状态持久化（PRD：退出 App 后续听） =====

  static const String _persistKey = 'playback_state_v1';

  /// 持久化当前播放队列、索引、进度、模式到 SharedPreferences
  ///
  /// [persistPosition]：是否持久化播放进度。
  /// - 切歌（playQueue）时传 false：新歌曲刚开始播放，position 为 0，
  ///   持久化无意义且可能覆盖暂停时保存的正确进度。
  /// - 暂停时传 true（默认）：保存当前实际播放进度。

  /// 从 SharedPreferences 恢复播放队列和进度（不自动播放）
  ///
  /// App 启动时调用，恢复后 Mini 播放栏显示上次曲目，
  /// 用户点击播放后从恢复的进度继续。
  Future<void> restorePlayback() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_persistKey);
      if (raw == null || raw.isEmpty) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final queueJson = data['queue'] as List<dynamic>?;
      if (queueJson == null || queueJson.isEmpty) return;
      final queue = queueJson
          .map((e) => AudioSong.fromJson(e as Map<String, dynamic>))
          .toList();
      final index = (data['currentIndex'] as int?) ?? 0;
      if (index < 0 || index >= queue.length) return;
      final position = Duration(seconds: (data['position'] as int?) ?? 0);
      final modeName = data['mode'] as String?;
      final mode = SynologyPlaybackMode.values.firstWhere(
        (m) => m.name == modeName,
        orElse: () => SynologyPlaybackMode.listLoop,
      );
      state = SynologyPlaybackState(
        currentSong: queue[index],
        queue: queue,
        currentIndex: index,
        isPlaying: false,
        position: position,
        duration: Duration(seconds: queue[index].audio?.duration ?? 0),
        coverUrl: _coverUrlOf(queue[index]),
        mode: mode,
      );
      // 记录待 seek 的进度，_playSong 播放后自动跳转到该位置
      if (position.inSeconds > 0) {
        _pendingSeek = position;
      }
      AppLogger.info('恢复播放状态', data: {
        'songs': queue.length,
        'index': index,
        'position': position.inSeconds,
      });
    } catch (e) {
      AppLogger.warn('恢复播放状态失败', data: {'error': e.toString()});
    }
    // 恢复未过期的睡眠定时器
    await restoreSleepTimerIfNeeded();
  }

  /// 暂停 / 继续
  Future<void> togglePlay() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state.isPlaying) {
      await _controller!.pause();
      state = state.copyWith(isPlaying: false);
      _syncMediaSession(isPlaying: false, position: state.position);
      _persistPlayback(); // 暂停时持久化进度
    } else {
      await _controller!.play();
      state = state.copyWith(isPlaying: true);
      _syncMediaSession(isPlaying: true, position: state.position);
    }
  }

  Future<void> pause() async {
    await _controller?.pause();
    state = state.copyWith(isPlaying: false);
    _syncMediaSession(isPlaying: false, position: state.position);
  }

  Future<void> resume() async {
    if (_controller != null && _controller!.value.isInitialized) {
      await _controller!.play();
      state = state.copyWith(isPlaying: true);
      _syncMediaSession(isPlaying: true, position: state.position);
    }
  }

  /// 下一首（按播放模式：列表循环 / 随机 / 单曲）
  Future<void> next() async {
    final queue = state.queue;
    if (queue.isEmpty || state.currentIndex < 0) return;
    final mode = state.mode;
    switch (mode) {
      case SynologyPlaybackMode.singleLoop:
        // 单曲循环：重播当前曲
        await _playSong(queue[state.currentIndex]);
      case SynologyPlaybackMode.shuffle:
        final idx = _randomIndex(queue.length);
        await playQueue(queue, idx);
      case SynologyPlaybackMode.listLoop:
        final idx = (state.currentIndex + 1) % queue.length;
        await playQueue(queue, idx);
    }
  }

  /// 上一首（回到开头或上一首；随机模式跳随机）
  Future<void> previous() async {
    final queue = state.queue;
    if (queue.isEmpty) return;
    if (state.mode == SynologyPlaybackMode.shuffle) {
      await playQueue(queue, _randomIndex(queue.length));
      return;
    }
    final idx = state.currentIndex - 1;
    if (idx < 0) return;
    await playQueue(queue, idx);
  }

  /// 切换播放模式（列表循环 → 单曲循环 → 随机）
  void cycleMode() {
    final nextMode = switch (state.mode) {
      SynologyPlaybackMode.listLoop => SynologyPlaybackMode.singleLoop,
      SynologyPlaybackMode.singleLoop => SynologyPlaybackMode.shuffle,
      SynologyPlaybackMode.shuffle => SynologyPlaybackMode.listLoop,
    };
    state = state.copyWith(mode: nextMode);
    AppLogger.info('切换播放模式', data: {'mode': nextMode.label});
  }

  /// 跳转到指定位置
  Future<void> seekTo(Duration position) async {
    if (_controller != null && _controller!.value.isInitialized) {
      await _controller!.seekTo(position);
      state = state.copyWith(position: position);
    }
  }

  /// 停止并释放播放器
  Future<void> stop() async {
    _positionTimer?.cancel();
    _positionTimer = null;
    await _controller?.dispose();
    _controller = null;
    await _ref.read(audioSessionHandlerProvider).releaseFocus();
    state = const SynologyPlaybackState();
    // 移除通知栏媒体控制
    try {
      _ref.read(audioHandlerProvider).clearMusicSession();
    } catch (e) {
      AppLogger.warn('清除系统媒体控制失败', data: {'error': e.toString()});
    }
  }

  // ============================
  // 睡眠定时器
  // ============================

  /// 启动睡眠定时器
  ///
  /// [duration] 定时时长；[behavior] 到点停止行为；[fadeOut] 停止前 30 秒渐降音量。
  Future<void> startSleepTimer({
    required Duration duration,
    required SleepTimerBehavior behavior,
    bool fadeOut = true,
  }) async {
    _normalVolume = 1.0;
    _stopAfterThisSong = false;
    final endsAt = DateTime.now().add(duration).millisecondsSinceEpoch;
    state = state.copyWith(
      sleepTimerEndsAtMs: endsAt,
      sleepTimerBehavior: behavior,
      sleepTimerFadeOut: fadeOut,
    );
    await _persistSleepTimer();
    AppLogger.info('睡眠定时器启动', data: {
      'minutes': duration.inMinutes,
      'behavior': behavior.name,
      'fadeOut': fadeOut,
    });
  }

  /// 取消睡眠定时器，音量恢复
  Future<void> cancelSleepTimer() async {
    _stopAfterThisSong = false;
    // 恢复音量（若正在淡出）
    if (_controller != null && _controller!.value.isInitialized) {
      await _controller!.setVolume(_normalVolume);
    }
    state = state.copyWith(clearSleepTimer: true);
    await _persistSleepTimer();
    AppLogger.info('睡眠定时器取消');
  }

  /// 由 position timer 每 500ms 调用：更新剩余时间、执行淡出、到点停止

  /// 到点执行停止

  /// 持久化睡眠定时器到 SharedPreferences（重启恢复）

  /// 启动时恢复未过期的睡眠定时器
  Future<void> restoreSleepTimerIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kSleepTimerKey);
      if (raw == null) return;
      final map = json.decode(raw) as Map<String, dynamic>;
      final endsAt = map['endsAt'] as int?;
      if (endsAt == null) return;
      // 已过期则清理
      if (endsAt <= DateTime.now().millisecondsSinceEpoch) {
        await prefs.remove(_kSleepTimerKey);
        return;
      }
      state = state.copyWith(
        sleepTimerEndsAtMs: endsAt,
        sleepTimerBehavior: SleepTimerBehavior.values.firstWhere(
          (b) => b.name == map['behavior'],
          orElse: () => SleepTimerBehavior.immediateStop,
        ),
        sleepTimerFadeOut: map['fadeOut'] as bool? ?? true,
      );
      AppLogger.info('恢复睡眠定时器', data: {'endsAt': endsAt});
    } catch (_) {
      // 恢复失败不影响播放
    }
  }

  // ============================
  // 内部实现
  // ============================

  // ============================
  // 内部实现
  // ============================

  /// 同步歌曲信息与播放状态到系统媒体控制（通知栏/锁屏）

  /// 异步加载当前歌曲歌词（切歌后旧结果丢弃）
  /// 三级降级：NAS LRC → LRCLIB 在线源 → 无歌词

  /// 用户保存手动编辑的歌词（PRD #22）
  Future<void> saveEditedLyrics(String text) async {
    final song = state.currentSong;
    if (song == null) return;
    await lyricsEditStore.save(song.id, text);
    if (!_disposed && state.currentSong?.id == song.id) {
      state = state.copyWith(lyrics: text.trim().isEmpty ? null : text);
    }
  }

  /// 清除用户编辑的歌词，回退到 NAS/LRCLIB
  Future<void> clearEditedLyrics() async {
    final song = state.currentSong;
    if (song == null) return;
    await lyricsEditStore.clear(song.id);
    await _loadLyrics(song);
  }

  /// 是否自然播放完毕（供播放器定时器判定；独立纯函数便于单测）
  ///
  /// - [controllerPlaying]：video_player 当前 isPlaying
  /// - [statePlaying]：应用层播放状态（用户暂停后为 false）
  ///
  /// 三者同时满足才算自然播完：有进度、已到结尾、播放器停止、
  /// 且应用层仍认为在播放（用户手动暂停不会触发切歌）。
  static bool isNaturalFinish({
    required bool controllerPlaying,
    required bool statePlaying,
    required Duration position,
    required Duration duration,
    Duration tail = const Duration(milliseconds: 300),
  }) {
    if (duration <= Duration.zero) return false;
    final atEnd = position >= duration - tail;
    return atEnd && !controllerPlaying && statePlaying;
  }

  /// 焦点丢失（来电等）：暂停

  /// 焦点恢复：续播（尊重用户设置由视频系统统一处理，这里直接续播音乐）

  String? _coverUrlOf(AudioSong song) {
    return _ref
        .read(synologyAuthProvider.notifier)
        .api
        .getSongCoverUrl(song.id);
  }

  @override
  void dispose() {
    _disposed = true;
    _positionTimer?.cancel();
    _positionTimer = null;
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }
}

/// 音乐播放 Provider
final synologyPlaybackProvider =
    StateNotifierProvider<SynologyPlaybackNotifier, SynologyPlaybackState>(
  (ref) => SynologyPlaybackNotifier(ref),
);
