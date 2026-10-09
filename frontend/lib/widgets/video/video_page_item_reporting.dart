// 从 video_page_item.dart 拆分（part 文件，无行为变化）
// 注意：本文件仅保留类体中没有的方法；与类体重名的方法已删除
// （Dart 类成员优先于扩展成员，重名扩展是死代码）

part of 'video_page_item.dart';

// ==================== 播放上报与统计（仅类体中缺失的方法） ====================

extension _VideoPlaybackReporting on _VideoPageItemState {
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

  void _reportPlaybackProgress({bool isPauseEvent = false}) {
    final now = DateTime.now();
    if (!isPauseEvent) {
      final delta = now.difference(_lastProgressReport);
      if (delta.inSeconds < _VideoPageItemState._progressReportMinSeconds) {
        return;
      }
    }
    _lastProgressReport = now;
    // 统一获取位置：优先 ExoPlayer controller，MPV 模式下从 VideoPlayerWidget 统一接口获取
    final controller = _videoController;
    final mpvPos = _videoPlayerKey.currentState?.currentPosition;
    final position = controller?.value.position ??
        (mpvPos != Duration.zero ? mpvPos : null);
    final positionTicks = (position?.inMilliseconds ?? 0) * 10000;
    final isPaused = controller != null
        ? !controller.value.isPlaying
        : !(_videoPlayerKey.currentState?.isPlaying ?? false);
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
    final mpvPos = _videoPlayerKey.currentState?.currentPosition;
    final position = controller?.value.position ??
        (mpvPos != Duration.zero ? mpvPos : null);
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
}
