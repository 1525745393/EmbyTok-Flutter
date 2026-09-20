// 从 video_page_item.dart 拆分（part 文件，无行为变化）

part of 'video_page_item.dart';

// ==================== 播放上报与统计 ====================

extension _VideoPlaybackReporting on _VideoPageItemState {
  String _newPlaySessionId() =>
      'emb-flutter-${DateTime.now().microsecondsSinceEpoch}';

  void _ensureCapabilitiesReported() {
    if (_capabilitiesReported) return;
    _capabilitiesReported = true;
    _safeReport(
      () => _service.reportCapabilities(
        serverUrl: _authServerUrl(),
        token: _authToken(),
      ),
      'reportCapabilities',
    );
  }

  void _reportPlaybackStart() {
    if (_hasStartedReported) return;
    _hasStartedReported = true;
    // 如果来自预加载会话，则复用其 playSessionId，保证预加载和播放使用同一个会话
    // 空字符串视为无效，生成新的会话 ID
    final preloadedId = widget.preloadedSession?.playSessionId;
    _playSessionId = (preloadedId != null && preloadedId.isNotEmpty)
        ? preloadedId
        : _newPlaySessionId();
    _safeReport(
      () => _service.reportPlaybackStart(
        itemId: widget.item.id,
        mediaSourceId: widget.item.id,
        playSessionId: _playSessionId!,
        playMethod: 'DirectPlay',
        serverUrl: _authServerUrl(),
        token: _authToken(),
      ),
      'reportPlaybackStart',
    );
  }

  void _reportPlaybackProgress({bool isPauseEvent = false}) {
    final now = DateTime.now();
    if (!isPauseEvent) {
      final delta = now.difference(_lastProgressReport);
      if (delta.inSeconds < _VideoPageItemState._progressReportMinSeconds)
        return;
    }
    _lastProgressReport = now;
    final controller = _videoController;
    final position = controller?.value.position;
    final positionTicks = (position?.inMilliseconds ?? 0) * 10000;
    final isPaused = controller != null && !controller.value.isPlaying;
    final volume = controller?.value.volume;
    final volumeLevel = volume != null ? (volume * 100).round() : null;
    _safeReport(
      () => _service.reportPlaybackPosition(
        itemId: widget.item.id,
        positionTicks: positionTicks,
        mediaSourceId: widget.item.id,
        playSessionId: _playSessionId,
        isPaused: isPaused,
        volumeLevel: volumeLevel,
        playMethod: 'DirectPlay',
        eventName: isPauseEvent ? 'Pause' : 'TimeUpdate',
        serverUrl: _authServerUrl(),
        token: _authToken(),
      ),
      'reportPlaybackPosition',
    );

    // 同步 MediaSession 位置：与 Emby 上报同频（每 5 秒或暂停时），
    // 使锁屏进度条与实际播放位置保持一致
    // 注意：节流 return 时不会执行到此，避免无谓的 MediaSession 写入
    final audioHandler = ref.read(audioHandlerProvider);
    audioHandler.updatePlaybackState(
      isPlaying: !isPaused,
      position: position ?? Duration.zero,
    );
  }

  void _reportPlaybackStopped() {
    if (_hasStoppedReported) return;
    _hasStoppedReported = true;
    final controller = _videoController;
    final position = controller?.value.position;
    final positionTicks =
        position != null ? position.inMilliseconds * 10000 : 0;
    _safeReport(
      () => _service.reportPlaybackStopped(
        itemId: widget.item.id,
        positionTicks: positionTicks,
        mediaSourceId: widget.item.id,
        playSessionId: _playSessionId,
        serverUrl: _authServerUrl(),
        token: _authToken(),
      ),
      'reportPlaybackStopped',
    );

    // 清除 MediaSession：播放停止后通知栏移除播放控件，
    // 避免锁屏仍显示已结束媒体的播放按钮
    final audioHandler = ref.read(audioHandlerProvider);
    audioHandler.updatePlaybackState(
      isPlaying: false,
      position: Duration.zero,
    );
    // 播放停止后续播进度已变，失效续播、详情和观看历史缓存确保下次获取最新数据
    // watchHistory 列表（含 Resume）依赖播放进度，必须失效
    final serverUrl = _authServerUrl();
    final token = _authToken();
    if (serverUrl != null && token != null) {
      try {
        ref.read(cacheControllerProvider).invalidateResume(serverUrl, token);
        ref
            .read(cacheControllerProvider)
            .invalidateItemDetail(widget.item.id, serverUrl);
        ref.read(cacheControllerProvider).invalidateWatchHistory(serverUrl);
      } catch (e) {
        AppLogger.warn('更新观看历史缓存失败', data: {'error': e.toString()});
      }
    }
    _hasStartedReported = false;
  }

  void _recordWatchStats() {
    // 只有当前页才记录，避免预加载页误记录拉低完播率
    if (!widget.isCurrentPage) return;
    final controller = _videoController;
    if (controller == null) return;
    try {
      if (!controller.value.isInitialized) return;
      final position = controller.value.position;
      final duration = controller.value.duration;
      if (duration.inMilliseconds <= 0) return;
      // 使用微秒计算避免毫秒整数除法的精度损失
      final completionRate = position.inMicroseconds / duration.inMicroseconds;
      ref.read(watchStatsProvider.notifier).recordWatch(
            itemId: widget.item.id,
            itemType: widget.item.type,
            itemTitle: widget.item.title,
            completionRate: completionRate,
            source: widget.source,
          );
    } catch (e) {
      // controller 可能已被子 widget VideoPlayerWidget dispose，
      // 此时跳过统计记录，避免 dispose 链中断
      AppLogger.debug('recordWatchStats 跳过：controller 不可访问',
          data: {'itemId': widget.item.id, 'error': e.toString()});
    }
  }

  void _syncMediaSessionOnStart() {
    final audioHandler = ref.read(audioHandlerProvider);
    // 封面图 URL：需带 serverUrl 与 token 才能被系统 MediaSession 访问
    final serverUrl = _authServerUrl();
    final token = _authToken();
    final artUri = widget.item.primaryUrl(
      embyServerUrl: serverUrl,
      apiKey: token,
    );
    // ticks → Duration：1 tick = 100ns = 0.1μs，故 microseconds = ticks / 10
    final ticks = widget.item.runtimeTicks;
    final duration =
        ticks != null ? Duration(microseconds: (ticks / 10).round()) : null;
    audioHandler.setMediaItem(
      title: widget.item.title,
      artist: widget.item.seriesName,
      artUri: artUri,
      duration: duration,
    );
    audioHandler.updatePlaybackState(
      isPlaying: true,
      position: Duration.zero,
    );
  }

  void _safeReport(Future<void> Function() action, String operation) {
    safeUnawaited(
      action(),
      context: 'report:$operation(itemId:${widget.item.id})',
    );
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(_kProgressReportInterval, (_) {
      if (!mounted) return;
      _reportPlaybackProgress();
    });
  }
}
