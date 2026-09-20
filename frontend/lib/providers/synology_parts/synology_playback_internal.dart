// 从 synology_playback_provider.dart 拆分（part 文件，无行为变化）

part of '../synology_playback_provider.dart';

// ==================== 播放内部实现 ====================

extension _SynologyPlaybackInternal on SynologyPlaybackNotifier {
  Future<void> _persistPlayback({bool persistPosition = true}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'queue': state.queue.map((s) => s.toJson()).toList(),
        'currentIndex': state.currentIndex,
        'position': persistPosition ? state.position.inSeconds : 0,
        'mode': state.mode.name,
      };
      await prefs.setString(
          SynologyPlaybackNotifier._persistKey, jsonEncode(data));
    } catch (e) {
      AppLogger.warn('持久化播放状态失败', data: {'error': e.toString()});
    }
  }

  int _randomIndex(int length) {
    if (length <= 1) return 0;
    // 避免与当前索引重复
    final current = state.currentIndex;
    var idx = _random.nextInt(length);
    if (idx == current) idx = (idx + 1) % length;
    return idx;
  }

  void _tickSleepTimer() {
    final endsAt = state.sleepTimerEndsAtMs;
    if (endsAt == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final remainingMs = endsAt - now;
    final remainingSec = remainingMs / 1000.0;

    // 1) 到点
    if (remainingMs <= 0) {
      _stopBySleepTimer();
      return;
    }

    // 2) 最后 30 秒渐进淡出
    if (state.sleepTimerFadeOut && remainingSec <= 30.0) {
      final ratio = (remainingSec / 30.0).clamp(0.0, 1.0);
      final controller = _controller;
      if (controller != null && controller.value.isInitialized) {
        controller.setVolume(ratio);
      }
    }
  }

  Future<void> _stopBySleepTimer() async {
    final behavior = state.sleepTimerBehavior;
    // 恢复音量，避免下次播放残留低音量
    if (_controller != null && _controller!.value.isInitialized) {
      await _controller!.setVolume(_normalVolume);
    }
    if (behavior == SleepTimerBehavior.currentSongEnd) {
      // 标记：等本次自然播完再暂停（在 _startPositionTimer 的自然播完分支处理）
      _stopAfterThisSong = true;
      state = state.copyWith(clearSleepTimer: true);
      await _persistSleepTimer();
      AppLogger.info('睡眠定时器：等待当前歌曲结束后停止');
      return;
    }
    // 立即停止
    _stopAfterThisSong = false;
    state = state.copyWith(clearSleepTimer: true);
    await _persistSleepTimer();
    await pause();
    AppLogger.info('睡眠定时器：立即停止播放');
  }

  Future<void> _persistSleepTimer() async {
    final prefs = await SharedPreferences.getInstance();
    final endsAt = state.sleepTimerEndsAtMs;
    if (endsAt == null) {
      await prefs.remove(SynologyPlaybackNotifier._kSleepTimerKey);
      return;
    }
    await prefs.setString(
        SynologyPlaybackNotifier._kSleepTimerKey,
        json.encode({
          'endsAt': endsAt,
          'behavior': state.sleepTimerBehavior.name,
          'fadeOut': state.sleepTimerFadeOut,
        }));
  }

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

  Future<void> _loadLyrics(AudioSong song) async {
    state = state.copyWith(isLoadingLyrics: true, lyrics: null);
    final api = _ref.read(synologyAuthProvider.notifier).api;
    // 1. 用户手动编辑的歌词优先级最高
    var lyrics = await lyricsEditStore.read(song.id);
    // 2. NAS LRC
    lyrics ??= await api.getLyrics(song.id);
    // 3. NAS 无歌词时回退 LRCLIB
    if ((lyrics == null || lyrics.trim().isEmpty)) {
      lyrics = await lrclibService.fetchLyrics(
        artist: song.artistDisplay,
        title: song.title,
        album: song.albumDisplay,
        durationSec: song.audio?.duration,
      );
    }
    // 仅当仍是同一首歌时写入，避免切歌竞态
    if (!_disposed && state.currentSong?.id == song.id) {
      state = state.copyWith(isLoadingLyrics: false, lyrics: lyrics);
    }
  }

  Future<void> _playSong(AudioSong song) async {
    // 释放旧播放器
    await _controller?.dispose();
    _controller = null;

    final api = _ref.read(synologyAuthProvider.notifier).api;

    try {
      // 申请音频焦点（来电等场景自动暂停）
      await _ref.read(audioSessionHandlerProvider).requestFocus();

      // 优先用本地已下载文件（离线播放）
      final localPath =
          await SynologyDownloadService.instance.localPathFor(song.id);
      VideoPlayerController controller;
      if (localPath != null) {
        controller = VideoPlayerController.file(
          File(localPath),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
        );
      } else {
        final streamUrl = api.getStreamUrl(song.id);
        if (streamUrl == null) {
          state = state.copyWith(isLoading: false, error: '未登录群晖或流地址不可用');
          return;
        }
        controller = VideoPlayerController.networkUrl(
          Uri.parse(streamUrl),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
        );
      }
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
      _consecutiveFailures = 0; // 播放成功，重置失败计数
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
      _loadLyrics(song);
    } catch (e, st) {
      AppLogger.error('音乐播放失败',
          data: {'song': song.title}, error: e, stackTrace: st);
      _consecutiveFailures++;
      // 连续失败熔断：断网/服务端异常时不再顺序试完整队列
      final idx = state.currentIndex;
      if (_consecutiveFailures >=
          SynologyPlaybackNotifier._kMaxConsecutiveFailures) {
        AppLogger.warn('连续播放失败，停止自动切歌', data: {'count': _consecutiveFailures});
        state = state.copyWith(
            isLoading: false, isPlaying: false, error: '连续播放失败，请检查网络或服务器后重试');
        return;
      }
      // 播放失败自动切下一首（避免用户手动点）最多尝试队列末尾
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
      if (SynologyPlaybackNotifier.isNaturalFinish(
        controllerPlaying: playing,
        statePlaying: state.isPlaying,
        position: pos,
        duration: dur,
      )) {
        // 睡眠定时器「当前歌曲结束后停止」：自然播完时暂停而非切下一首
        if (_stopAfterThisSong) {
          _stopAfterThisSong = false;
          pause(); // fire-and-forget：回调为同步 void，不阻塞 timer
          AppLogger.info('睡眠定时器：当前歌曲已播完，停止播放');
          return;
        }
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
      // 睡眠定时器倒计时 / 淡出 / 到点停止
      _tickSleepTimer();
    });
  }

  Future<void> _handleFocusLost() async {
    await pause();
  }

  Future<void> _handleFocusGained() async {
    await resume();
  }
}
