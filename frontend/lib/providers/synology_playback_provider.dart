// 群晖 Audio Station 音乐播放控制器
//
// 使用 video_player 播放音频流（与视频播放系统完全解耦）：
// - 支持播放队列（歌曲列表 / 专辑 / 歌单 / 搜索结果）
// - 上一首 / 下一首 / 暂停 / 继续 / 跳转
// - 通过 AudioSessionHandler 申请音频焦点，来电/其他 App 播放时自动暂停
// - 提供 mini player 所需的实时状态（曲目、封面、进度、时长）

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import '../models/audio_models.dart';
import '../utils/logger.dart';
import 'audio_focus_provider.dart';
import 'audio_handler_provider.dart';
import 'recent_playbacks_provider.dart';
import 'synology_auth_provider.dart';

/// 播放模式
enum SynologyPlaybackMode {
  listLoop('列表循环'),
  singleLoop('单曲循环'),
  shuffle('随机播放');

  final String label;
  const SynologyPlaybackMode(this.label);
}

/// 音乐播放状态
class SynologyPlaybackState {
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
  });

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
    );
  }
}

class SynologyPlaybackNotifier extends StateNotifier<SynologyPlaybackState> {
  final Ref _ref;

  VideoPlayerController? _controller;
  Timer? _positionTimer;
  bool _disposed = false;
  final Random _random = Random();

  /// 恢复播放时待 seek 的进度（restorePlayback 设置，_playSong 播放后清除）
  Duration? _pendingSeek;

  SynologyPlaybackNotifier(this._ref) : super(const SynologyPlaybackState()) {
    // 中断回调：焦点丢失暂停 / 恢复续播
    final handler = _ref.read(audioSessionHandlerProvider);
    handler.onPauseRequested = _handleFocusLost;
    handler.onResumeRequested = _handleFocusGained;
  }

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
    } catch (_) {}
    await _playSong(song);
    _persistPlayback();
  }

  /// 播放单曲（队列为该曲目单曲）
  Future<void> playSong(AudioSong song) => playQueue([song], 0);

  // ===== 播放状态持久化（PRD：退出 App 后续听） =====

  static const String _persistKey = 'playback_state_v1';

  /// 持久化当前播放队列、索引、进度、模式到 SharedPreferences
  ///
  /// 在切歌（playQueue）和暂停时调用，不自动播放。
  Future<void> _persistPlayback() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'queue': state.queue.map((s) => s.toJson()).toList(),
        'currentIndex': state.currentIndex,
        'position': state.position.inSeconds,
        'mode': state.mode.name,
      };
      await prefs.setString(_persistKey, jsonEncode(data));
    } catch (e) {
      AppLogger.warn('持久化播放状态失败', data: {'error': e.toString()});
    }
  }

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
    if (queue.isEmpty) return;
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

  int _randomIndex(int length) {
    if (length <= 1) return 0;
    // 避免与当前索引重复
    final current = state.currentIndex;
    var idx = _random.nextInt(length);
    if (idx == current) idx = (idx + 1) % length;
    return idx;
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
  // 内部实现
  // ============================

  // ============================
  // 内部实现
  // ============================

  /// 同步歌曲信息与播放状态到系统媒体控制（通知栏/锁屏）
  void _syncMediaSession({
    required bool isPlaying,
    Duration? position,
    Duration? duration,
  }) {
    final song = state.currentSong;
    if (song == null) return;
    try {
      final handler = _ref.read(audioHandlerProvider);
      if (isPlaying || position != null) {
        handler.syncMusicMediaItem(
          title: song.title,
          artist: song.artistDisplay.isEmpty ? '群晖音乐' : song.artistDisplay,
          artUri: state.coverUrl,
          duration: duration,
        );
      }
      handler.syncMusicPlaybackState(
        isPlaying: isPlaying,
        position: position,
        duration: duration,
      );
    } catch (e) {
      // 媒体会话同步失败不影响音乐播放，仅记录
      AppLogger.warn('同步系统媒体控制失败', data: {'error': e.toString()});
    }
  }

  /// 异步加载当前歌曲歌词（切歌后旧结果丢弃）
  Future<void> _loadLyrics(String songId) async {
    state = state.copyWith(isLoadingLyrics: true, lyrics: null);
    final api = _ref.read(synologyAuthProvider.notifier).api;
    final lyrics = await api.getLyrics(songId);
    // 仅当仍是同一首歌时写入，避免切歌竞态
    if (!_disposed && state.currentSong?.id == songId) {
      state = state.copyWith(isLoadingLyrics: false, lyrics: lyrics);
    }
  }

  Future<void> _playSong(AudioSong song) async {
    // 释放旧播放器
    await _controller?.dispose();
    _controller = null;

    final api = _ref.read(synologyAuthProvider.notifier).api;
    final streamUrl = api.getStreamUrl(song.id);
    if (streamUrl == null) {
      state = state.copyWith(isLoading: false, error: '未登录群晖或流地址不可用');
      return;
    }

    try {
      // 申请音频焦点（来电等场景自动暂停）
      await _ref.read(audioSessionHandlerProvider).requestFocus();

      final controller = VideoPlayerController.networkUrl(
        Uri.parse(streamUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
      );
      _controller = controller;
      await controller.initialize();
      if (_disposed) {
        await controller.dispose();
        return;
      }
      await controller.play();
      // 恢复播放进度：如果有 pendingSeek，跳转到该位置后清除
      final pending = _pendingSeek;
      if (pending != null && pending.inSeconds > 0) {
        await controller.seekTo(pending);
        _pendingSeek = null;
      }
      // 开始轮询进度
      _startPositionTimer();
      state = state.copyWith(
        isLoading: false,
        isPlaying: true,
        duration: controller.value.duration,
        error: null,
      );
      // 同步系统媒体控制（通知栏/锁屏显示歌曲与播放状态）
      _syncMediaSession(
        isPlaying: true,
        position: controller.value.position,
        duration: controller.value.duration,
      );
      // 异步加载歌词（不阻塞播放）
      _loadLyrics(song.id);
    } catch (e, st) {
      AppLogger.error('音乐播放失败',
          data: {'song': song.title}, error: e, stackTrace: st);
      // 播放失败自动切下一首（避免用户手动点）最多尝试队列末尾
      final idx = state.currentIndex;
      if (idx >= 0 && idx < state.queue.length - 1) {
        await playQueue(state.queue, idx + 1);
      } else {
        state = state.copyWith(
            isLoading: false, isPlaying: false, error: '播放失败：$e');
      }
    }
  }

  void _startPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      final controller = _controller;
      if (controller == null || !controller.value.isInitialized) return;
      final pos = controller.value.position;
      final dur = controller.value.duration;
      final playing = controller.value.isPlaying;

      // 播放完毕自动下一首（video_player 在结尾 isPlaying 变 false）。
      // 注意区分「自然播完」与「用户暂停在末尾」：只有仍在播放状态时
      // 才算自然播完（用户暂停后 state.isPlaying 已为 false）。
      if (isNaturalFinish(
        controllerPlaying: playing,
        statePlaying: state.isPlaying,
        position: pos,
        duration: dur,
      )) {
        next();
        return;
      }
      state = state.copyWith(
        position: pos,
        duration: dur,
        isPlaying: playing,
      );
      // 定期同步进度到系统媒体控制（锁屏进度条）
      _syncMediaSession(isPlaying: playing, position: pos, duration: dur);
    });
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
  Future<void> _handleFocusLost() async {
    await pause();
  }

  /// 焦点恢复：续播（尊重用户设置由视频系统统一处理，这里直接续播音乐）
  Future<void> _handleFocusGained() async {
    await resume();
  }

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
