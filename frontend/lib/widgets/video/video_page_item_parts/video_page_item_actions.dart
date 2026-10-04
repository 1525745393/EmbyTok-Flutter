// 从 video_page_item.dart 拆分（part 文件，无行为变化）

part of '../video_page_item.dart';

// ==================== 动作方法 ====================

extension _VideoPageItemActions on _VideoPageItemState {
  void _resetInfoHideTimer() {
    _infoHideTimer?.cancel();
    if (!mounted) return;
    setState(() => _isInfoVisible = true);
  }

  Future<void> _startPlaybackIfCurrent() async {
    if (!widget.isCurrentPage) return;
    final controller = _videoController;
    if (controller != null && controller.value.isInitialized) {
      final isMuted = ref.read(isMutedProvider);
      controller.setVolume(isMuted ? 0.0 : 1.0);
      try {
        controller.play();
      } catch (e) {
        AppLogger.warn('播放视频失败', data: {'error': e.toString()});
      }
      ref.read(isPlayingProvider.notifier).state = true;
    }
    ref.read(playbackStateProvider.notifier).setItem(widget.item);
    ref.read(currentVideoControllerProvider.notifier).state = _videoController;
    _resetInfoHideTimer();

    // 本地文件源：从 SharedPreferences 读取续播位置，跳过 Emby 上报
    if (widget.item.isLocalFile) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final saved = prefs.getInt('local_resume_${widget.item.id}') ?? 0;
        if (saved > 5000 && controller != null && controller.value.isInitialized) {
          await controller.seekTo(Duration(milliseconds: saved));
        }
      } catch (_) {}
      return;
    }

    // === 进度双向同步：从服务端拉取最新进度 ===
    int resumePositionTicks = 0;
    try {
      final auth = ref.read(authProvider);
      final serverPosition = await _service.getPlaybackPosition(
        widget.item.id,
        userId: auth.user?.id,
        serverUrl: auth.embyServerUrl,
        token: auth.token,
      );
      final localPosition =
          widget.item.userData?.playbackPositionTicks.toInt() ?? 0;
      // 取较新者：服务端进度更大说明其他设备看了更多
      resumePositionTicks =
          serverPosition > localPosition ? serverPosition : localPosition;
    } catch (_) {
      // 拉取失败，使用本地进度降级
      resumePositionTicks =
          widget.item.userData?.playbackPositionTicks.toInt() ?? 0;
    }

    // 使用合并后的进度执行 seek，覆盖 VideoPlayerWidget 中基于本地 userData 的初次 seek
    // 确保播放器定位到最新进度（其他设备的观看位置）
    if (resumePositionTicks > 0 &&
        controller != null &&
        controller.value.isInitialized) {
      final posMs = (resumePositionTicks / 10000.0).round();
      if (posMs > 0) {
        try {
          await controller.seekTo(Duration(milliseconds: posMs));
        } catch (e) {
          AppLogger.warn('跳转播放位置失败',
              data: {'error': e.toString(), 'position': posMs});
        }
      }
    }

    // 异步等待后 widget 可能已被 dispose，避免在 dispose 后访问 ref
    if (!mounted) return;

    _ensureCapabilitiesReported();
    _reportPlaybackStart();
    _startProgressTimer();

    // 同步 MediaSession：播放开始时设置媒体项并更新播放状态，
    // 使锁屏/通知栏显示标题、封面与播放控件
    _syncMediaSessionOnStart();
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

  void _onVideoChanged() {
    if (!mounted) return;
    final controller = _videoController;
    if (controller == null) return;
    // 播放状态：仅在变化时同步 Provider（避免每帧 setState 等效操作）
    final isPlaying = controller.value.isPlaying;
    if (ref.read(isPlayingProvider) != isPlaying) {
      ref.read(isPlayingProvider.notifier).state = isPlaying;
      // 播放状态变化时触发暂停上报（原 _onVideoChangedForReport 逻辑）
      if (!isPlaying) _reportPlaybackProgress(isPauseEvent: true);
    }
    // 位置：仅在跨秒时写入 Provider，减少级联重建
    final posSec = controller.value.position.inSeconds;
    if (posSec != _lastPositionSecond) {
      _lastPositionSecond = posSec;
      ref.read(currentPositionProvider.notifier).state =
          controller.value.position;
    }

    if (!_hasNotifiedEnded) {
      final pos = controller.value.position;
      final dur = controller.value.duration;
      // History 中已播放条目会更新，需失效以反映最新观看进度
        final serverUrl = _authServerUrl();
        final token = _authToken();
        if (serverUrl != null && token != null) {
          try {
            ref
                .read(cacheControllerProvider)
                .invalidateResume(serverUrl, token);
            ref
                .read(cacheControllerProvider)
                .invalidateItemDetail(widget.item.id, serverUrl);
            ref.read(cacheControllerProvider).invalidateNextUp(serverUrl);
            ref.read(cacheControllerProvider).invalidateWatchHistory(serverUrl);
          } catch (e) {
            AppLogger.warn('视频播放结束后更新缓存失败', data: {'error': e.toString()});
          }
        }
        ref.read(videoListProvider.notifier).removePlayedItem(widget.item.id);
        // 自动连播下一集：用户在设置中开启后，播放结束自动切到下一个视频
        if (ref.read(autoPlayNextProvider)) {
          ref.read(autoPlayNextTriggerProvider.notifier).state++;
        }
      }
  }

  String _newPlaySessionId() =>
      'emb-flutter-${DateTime.now().microsecondsSinceEpoch}';

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

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(_kProgressReportInterval, (_) {
      if (!mounted) return;
      _reportPlaybackProgress();
    });
  }

  void _safeReport(Future<void> Function() action, String operation) {
    safeUnawaited(
      action(),
      context: 'report:$operation(itemId:${widget.item.id})',
    );
  }

  Future<void> _openFullscreenPage() async {
    final success = await FullscreenNavigator.open(
      ref: ref,
      context: context,
      onExit: () {
        if (mounted) {
          ref.read(toolbarVisibilityProvider.notifier).show();
          ref.read(isFullscreenProvider.notifier).state = false;
          // 退出全屏后重新隐藏系统栏（全屏页 dispose 时会恢复 edgeToEdge）
          // feed 模式需要保持沉浸式
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        }
      },
    );
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('视频正在准备中，请稍后'),
          behavior: SnackBarBehavior.floating,
          duration: _kSnackBarDuration,
        ),
      );
    }
  }

  void _toggleControls() {
    if (_controlsVisible) {
      _hideControls();
    } else {
      _showControls();
    }
  }

  void _showControls() {
    _controlsHideTimer?.cancel();
    if (!mounted) return;
    setState(() => _controlsVisible = true);
    _controlsHideTimer = Timer(
        const Duration(seconds: _VideoPageItemState._controlsAutoHideSeconds),
        _hideControls);
  }

  void _hideControls() {
    _controlsHideTimer?.cancel();
    if (mounted) setState(() => _controlsVisible = false);
  }

  void _togglePlay() {
    final controller = _videoController;
    if (controller == null) return;
    try {
      if (controller.value.isPlaying) {
        controller.pause();
        ref.read(isPlayingProvider.notifier).state = false;
        // 暂停时显示▶播放图标，不自动隐藏（用户需要点击恢复播放）
        if (!ref.read(isAutoPlayProvider)) {
          _centerButtonHideTimer?.cancel();
          if (mounted) setState(() => _centerButtonVisible = true);
        }
      } else {
        controller.play();
        ref.read(isPlayingProvider.notifier).state = true;
        // 播放时立即隐藏中央按钮（不显示⏸）
        if (!ref.read(isAutoPlayProvider)) {
          _centerButtonHideTimer?.cancel();
          if (mounted) setState(() => _centerButtonVisible = false);
        }
      }
    } catch (e) {
      AppLogger.warn('播放/暂停操作失败，controller 可能已释放',
          data: {'itemId': widget.item.id, 'error': e.toString()});
    }
  }

  Future<void> _shareItem() async {
    final item = widget.item;
    final url = item.playbackUrl;
    final String text;
    if (url != null && url.isNotEmpty) {
      text = '${item.title}\n$url\n（来自 EmbyTok）';
    } else {
      text = '${item.title}\n（来自 EmbyTok）';
    }
    try {
      await Share.share(text, subject: item.title);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分享失败: $e'), duration: _kSnackBarDuration),
        );
      }
    }
  }

  Future<void> _showDeleteConfirmDialog() async {
    final confirmed =
        await sheet_utils.showDeleteConfirmDialog(context, widget.item.title);
    if (!confirmed) return;

    // 本地文件：从本地列表移除（不调 Emby 删除接口）
    if (widget.item.isLocalFile) {
      final pathHash = widget.item.id.replaceFirst('local_', '');
      ref.read(localVideoProvider.notifier).removeByPathHash(pathHash);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('已从本地列表移除'), duration: _kSnackBarDuration));
        widget.onVideoEnded?.call();
      }
      return;
    }

    // 提前获取认证信息并判空，避免 token 过期/丢失时强制断言崩溃
    final serverUrl = _authServerUrl();
    final token = _authToken();
    if (serverUrl == null || token == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('认证信息缺失，请重新登录后再试'),
            duration: _kSnackBarDuration,
          ),
        );
      }
      return;
    }
    try {
      await _service.deleteItem(
        itemId: widget.item.id,
        serverUrl: serverUrl,
        token: token,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('已删除'), duration: _kSnackBarDuration));
        // 从视频列表中移除当前 item，避免用户反向滑回已删除的视频
        ref.read(videoListProvider.notifier).removeItem(widget.item.id);
        widget.onVideoEnded?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e'), duration: _kAnimationNormal),
        );
      }
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.inSeconds <= 0) return '0:00';
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours >= 1) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
