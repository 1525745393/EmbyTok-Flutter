// 从 fullscreen_video_page.dart 拆分（part 文件，无行为变化）

part of '../fullscreen_video_page.dart';

// ==================== _FullscreenControls ====================

extension _FullscreenControls on _FullscreenVideoPageState {
  void _setupControllerListener(VideoPlayerController? controller) {
    if (_watchedController == controller) return;
    _watchedController?.removeListener(_onControllerTick);
    _watchedController = controller;
    if (controller != null) {
      controller.addListener(_onControllerTick);
      final v = controller.value;
      _lastIsPlaying = v.isPlaying;
      _lastHasError = v.hasError;
      _bufferingNotifier.value = v.isBuffering;
      _wasControllerReady = v.isInitialized && !v.hasError;
      _lastHasSize = !v.size.isEmpty;
    } else {
      _lastIsPlaying = false;
      _lastHasError = false;
      _bufferingNotifier.value = false;
      _wasControllerReady = false;
      _lastHasSize = false;
    }
  }

  void _onControllerTick() {
    if (!mounted) return;
    final c = _watchedController;
    if (c == null) return;
    final v = c.value;

    bool needsRebuild = false;

    if (v.isBuffering != _bufferingNotifier.value) {
      _bufferingNotifier.value = v.isBuffering;
    }

    if (v.hasError != _lastHasError) {
      _lastHasError = v.hasError;
      needsRebuild = true;
    }

    if (v.isPlaying != _lastIsPlaying) {
      _lastIsPlaying = v.isPlaying;
      if (v.isPlaying &&
          _controlsVisible &&
          !_isScreenLocked &&
          !_showSettingsPanel) {
        _startHideTimer();
      } else {
        _hideTimer?.cancel();
      }
    }

    final isReady = v.isInitialized && !v.hasError;
    if (isReady != _wasControllerReady) {
      _wasControllerReady = isReady;
      needsRebuild = true;
    }

    // 尺寸变化检测：从空变为有效时触发重建，确保 VideoPlayer 切换到正确尺寸
    final hasSizeNow = !v.size.isEmpty;
    if (hasSizeNow != _lastHasSize) {
      _lastHasSize = hasSizeNow;
      if (hasSizeNow) {
        needsRebuild = true;
      }
    }

    // 位置秒数节流更新，用于字幕渲染（每秒最多一次）
    final ms = v.position.inMilliseconds;
    if (ms != _lastPositionMs) {
      _lastPositionMs = ms;
      _positionMsNotifier.value = ms;
    }

    if (needsRebuild && mounted) {
      setState(() {});
    }
  }

  Future<void> _initBrightness() async {
    try {
      _originalBrightness = await ScreenBrightness().current;
      _brightnessValue = _originalBrightness ?? 1.0;
      if (mounted) setState(() {});
    } catch (e) {
      AppLogger.warn('读取屏幕亮度失败', data: {'error': e.toString()});
      _brightnessValue = 1.0;
    }
  }

  Future<void> _setSystemBrightness(double value) async {
    final oldValue = _brightnessValue;
    _brightnessValue = value;
    if (mounted) setState(() {});
    try {
      await ScreenBrightness().setScreenBrightness(value);
    } catch (e) {
      AppLogger.warn('设置屏幕亮度失败，回滚到旧值', data: {'error': e.toString()});
      _brightnessValue = oldValue;
      if (mounted) setState(() {});
    }
  }

  void _initConnectivity() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((result) {
      _onConnectivityChanged(result);
    });
  }

  void _onConnectivityChanged(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.none:
        _showNetworkToast('网络已断开');
        break;
      case ConnectivityResult.wifi:
        _showNetworkToast('已切换到 WiFi');
        break;
      case ConnectivityResult.mobile:
        _showNetworkToast('已切换到移动网络');
        break;
      default:
        break;
    }
  }

  void _showNetworkToast(String message) {
    _networkToastTimer?.cancel();
    setState(() => _networkToastMessage = message);
    _networkToastTimer = Timer(
      const Duration(seconds: kFullscreenNetworkToastSec),
      () {
        if (mounted) setState(() => _networkToastMessage = null);
      },
    );
  }

  void _applyOrientations() {
    switch (_orientationPref) {
      case _OrientationPref.landscape:
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        break;
      case _OrientationPref.portrait:
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
        break;
      case _OrientationPref.sensor:
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
          DeviceOrientation.portraitDown,
        ]);
        break;
    }
  }

  void _toggleOrientation() {
    setState(() {
      switch (_orientationPref) {
        case _OrientationPref.landscape:
          _orientationPref = _OrientationPref.portrait;
          break;
        case _OrientationPref.portrait:
          _orientationPref = _OrientationPref.sensor;
          break;
        case _OrientationPref.sensor:
          _orientationPref = _OrientationPref.landscape;
          break;
      }
    });
    _applyOrientations();
    HapticFeedback.selectionClick();
  }

  void _applySystemUI() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [],
    );
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );
    // 排除 Android 边缘返回手势，避免与水平拖动 seek 冲突
    //（旋转后由 didChangeMetrics 重新调用以按新尺寸重算）
    SystemGestureExclusion.setFullscreenExclusion(
      ref.read(fullscreenGestureBackExcludedProvider),
    );
  }

  Future<void> _loadSubtitle(String? selectedTrackId) async {
    if (!mounted) return;
    if (selectedTrackId == null) {
      setState(() {
        _subtitleCues = const <SubtitleCue>[];
      });
      return;
    }
    final item = ref.read(playbackStateProvider).item;
    if (item == null) return;

    // 先从本地字幕轨道中查找
    final localTracks = ref.read(localSubtitleTracksProvider);
    SubtitleTrack? selectedTrack;
    int? trackIndex;
    bool isLocal = false;

    for (final track in localTracks) {
      if (track.id == selectedTrackId) {
        selectedTrack = track;
        isLocal = true;
        break;
      }
    }

    // 本地没找到，再从服务器字幕轨道中查找
    String? mediaSourceId;
    if (selectedTrack == null) {
      final sources = item.mediaSources;
      mediaSourceId =
          (sources != null && sources.isNotEmpty) ? sources.first.id : null;
      if (mediaSourceId == null || mediaSourceId.isEmpty) return;

      final tracks = item.subtitleTracks;
      for (int i = 0; i < tracks.length; i++) {
        if (tracks[i].id == selectedTrackId) {
          selectedTrack = tracks[i];
          final maybeIndex = int.tryParse(tracks[i].id);
          if (maybeIndex != null) {
            trackIndex = maybeIndex;
            break;
          }
          trackIndex = i;
          break;
        }
      }
      trackIndex ??= int.tryParse(selectedTrackId);
      if (trackIndex == null) return;
    }

    if (selectedTrack == null) return;

    try {
      final embService = ref.read(embytokServiceProvider);
      final authState = ref.read(authProvider);
      final serverUrl = authState.embyServerUrl;
      final token = authState.token;
      if (serverUrl != null && token != null) {
        embService.setupAuth(
          embyServerUrl: serverUrl,
          apiKey: token,
          userId: authState.user?.id,
        );
      }
      final format = selectedTrack.format;
      List<SubtitleCue> cues;
      // 本地外挂字幕：从文件读取
      if (isLocal &&
          selectedTrack.localFilePath != null &&
          selectedTrack.localFilePath!.isNotEmpty) {
        cues = await embService.getSubtitleCuesFromFile(
          filePath: selectedTrack.localFilePath!,
          format: format,
        );
      } else {
        // 服务器字幕：按轨道的原始格式请求，保留原生样式（ASS/VTT 等）
        cues = await embService.getSubtitleCues(
          itemId: item.id,
          mediaSourceId: mediaSourceId!,
          index: trackIndex!,
          format: format,
        );
      }
      if (mounted) {
        setState(() {
          _subtitleCues = cues;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _subtitleCues = const <SubtitleCue>[];
        });
      }
      AppLogger.warn('字幕加载失败', data: {'error': e.toString()});
    }
  }

  void _autoLoadDefaultSubtitle() {
    final item = ref.read(playbackStateProvider).item;
    if (item == null) return;
    final tracks = item.subtitleTracks;
    if (tracks.isEmpty) return;
    final settings = ref.read(subtitleSettingsProvider);
    SubtitleTrack? matchedTrack;

    if (settings.language.isNotEmpty) {
      matchedTrack = tracks.firstWhere(
        (t) => t.language.toLowerCase() == settings.language.toLowerCase(),
        orElse: () => tracks.first,
      );
      if (matchedTrack.language.toLowerCase() !=
          settings.language.toLowerCase()) {
        matchedTrack = null;
      }
    }

    matchedTrack ??= tracks.firstWhere(
      (t) => t.isDefault,
      orElse: () => tracks.first,
    );

    ref.read(selectedSubtitleProvider.notifier).state = matchedTrack.id;
    _loadSubtitle(matchedTrack.id);
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(
      const Duration(seconds: kFullscreenControlsHideSec),
      () {
        if (mounted && !_isScreenLocked && !_showSettingsPanel) {
          setState(() => _controlsVisible = false);
        }
      },
    );
  }

  void _toggleControls() {
    if (_isScreenLocked) return;
    if (_showSettingsPanel) {
      setState(() => _showSettingsPanel = false);
      _startHideTimer();
      return;
    }
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) {
      _startHideTimer();
    } else {
      _hideTimer?.cancel();
    }
  }

  void _lockScreen() {
    setState(() {
      _isScreenLocked = true;
      _controlsVisible = false;
      _showSettingsPanel = false;
    });
    _hideTimer?.cancel();
    HapticFeedback.mediumImpact();
  }

  void _unlockScreen() {
    setState(() => _isScreenLocked = false);
    _startHideTimer();
    HapticFeedback.mediumImpact();
  }

  void _toggleSettingsPanel(_SettingsTab tab) {
    if (_isScreenLocked) return;
    setState(() {
      if (_showSettingsPanel && _settingsTab == tab) {
        _showSettingsPanel = false;
      } else {
        _showSettingsPanel = true;
        _settingsTab = tab;
        _controlsVisible = true;
      }
    });
    _hideTimer?.cancel();
    if (!_showSettingsPanel) _startHideTimer();
  }

  void _retryVideo() {
    // 全屏页不拥有 controller，通过 Provider 通知 VideoPageItem 触发重试
    final item = ref.read(playbackStateProvider).item;
    if (item != null) {
      ref.read(videoRetryRequestProvider.notifier).state = item.id;
      setState(() => _retryKey++);
    }
  }

  String _formatDuration(Duration d) {
    if (d.inSeconds < 0) return '0:00';
    if (d.inHours > 0) {
      final h = d.inHours;
      final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return '$h:$m:$s';
    }
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  bool _hasPrevious() {
    final idx = _getCurrentIndex();
    return idx != null && idx > 0;
  }

  void _jumpToPrevious() {
    final idx = _getCurrentIndex();
    if (idx == null || idx <= 0) return;
    ref.read(feedViewPageJumpRequestProvider.notifier).state = idx - 1;
  }

  /// 显示剧集列表面板
  void _showEpisodeList(MediaItem currentItem) {
    showEpisodeListPanel(
      context,
      currentItem,
      onPlayEpisode: (episode, seasonEpisodes) {
        // 更新播放列表为当前季完整剧集
        ref
            .read(playbackListProvider.notifier)
            .setPlaybackList(seasonEpisodes, episode.id);
        // 在新列表中定位目标剧集
        final targetIndex =
            seasonEpisodes.indexWhere((e) => e.id == episode.id);
        if (targetIndex >= 0) {
          ref.read(feedViewPageJumpRequestProvider.notifier).state =
              targetIndex;
        } else {
          ref
              .read(playbackStateProvider.notifier)
              .setPlaying(episode.id, episode);
          ref.read(feedViewPageJumpRequestProvider.notifier).state = 0;
        }
      },
    );
  }
}
