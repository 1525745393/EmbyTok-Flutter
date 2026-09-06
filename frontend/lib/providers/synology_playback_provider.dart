// 群晖 Audio Station 音乐播放控制器
//
// 使用 video_player 播放音频流（与视频播放系统完全解耦）：
// - 支持播放队列（歌曲列表 / 专辑 / 歌单 / 搜索结果）
// - 上一首 / 下一首 / 暂停 / 继续 / 跳转
// - 通过 AudioSessionHandler 申请音频焦点，来电/其他 App 播放时自动暂停
// - 提供 mini player 所需的实时状态（曲目、封面、进度、时长）

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../models/audio_models.dart';
import '../utils/logger.dart';
import 'audio_focus_provider.dart';
import 'synology_auth_provider.dart';

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
    );
  }
}

class SynologyPlaybackNotifier extends StateNotifier<SynologyPlaybackState> {
  final Ref _ref;

  VideoPlayerController? _controller;
  Timer? _positionTimer;
  bool _disposed = false;

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
    state = SynologyPlaybackState(
      currentSong: queue[index],
      queue: queue,
      currentIndex: index,
      isLoading: true,
      coverUrl: _coverUrlOf(queue[index]),
    );
    await _playSong(queue[index]);
  }

  /// 播放单曲（队列为该曲目单曲）
  Future<void> playSong(AudioSong song) => playQueue([song], 0);

  /// 暂停 / 继续
  Future<void> togglePlay() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state.isPlaying) {
      await _controller!.pause();
      state = state.copyWith(isPlaying: false);
    } else {
      await _controller!.play();
      state = state.copyWith(isPlaying: true);
    }
  }

  Future<void> pause() async {
    await _controller?.pause();
    state = state.copyWith(isPlaying: false);
  }

  Future<void> resume() async {
    if (_controller != null && _controller!.value.isInitialized) {
      await _controller!.play();
      state = state.copyWith(isPlaying: true);
    }
  }

  /// 下一首
  Future<void> next() async {
    final idx = state.currentIndex + 1;
    if (idx >= state.queue.length) return;
    await playQueue(state.queue, idx);
  }

  /// 上一首（回到开头或上一首）
  Future<void> previous() async {
    final idx = state.currentIndex - 1;
    if (idx < 0) return;
    await playQueue(state.queue, idx);
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
  }

  // ============================
  // 内部实现
  // ============================

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
      // 开始轮询进度
      _startPositionTimer();
      state = state.copyWith(
        isLoading: false,
        isPlaying: true,
        duration: controller.value.duration,
        error: null,
      );
    } catch (e, st) {
      AppLogger.error('音乐播放失败', data: {'song': song.title}, error: e, stackTrace: st);
      // 播放失败自动切下一首（避免用户手动点）最多尝试队列末尾
      final idx = state.currentIndex;
      if (idx >= 0 && idx < state.queue.length - 1) {
        await playQueue(state.queue, idx + 1);
      } else {
        state = state.copyWith(isLoading: false, isPlaying: false, error: '播放失败：$e');
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

      // 播放完毕自动下一首（video_player 在结尾 isPlaying 变 false）
      final finished = dur > Duration.zero && pos >= dur - const Duration(milliseconds: 300);
      if (finished && !playing) {
        next();
        return;
      }
      state = state.copyWith(
        position: pos,
        duration: dur,
        isPlaying: playing,
      );
    });
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
    return _ref.read(synologyAuthProvider.notifier).api.getSongCoverUrl(song.id);
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
