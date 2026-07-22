// 全屏视频播放页：完整功能版
//
// 核心特性：
// 1. 基础交互：播放暂停、进度拖动、退出全屏、控制栏自动显隐、横竖屏切换
// 2. 标准手势：左侧调亮度、右侧调音量、左右滑动快进快退、长按倍速、双击步进
// 3. 设置面板：倍速切换、清晰度切换、画面比例设置
// 4. 系统适配：沉浸式状态栏、安全区、前后台切换、网络切换提醒
// 5. 状态反馈：缓冲、失败、手势操作的完整视觉反馈
// 6. 无缝衔接：复用全局 VideoPlayerController，不重新初始化
// 7. 系统亮度：使用 screen_brightness 实现全局亮度调节，退出时恢复原始亮度

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:video_player/video_player.dart';

import '../models/models.dart';
import '../models/subtitle_track.dart';
import '../providers/providers.dart';
import '../services/embbytok_service.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';
import '../widgets/subtitle_renderer.dart';
import '../widgets/video/video_gesture_mixin.dart';

/// 全屏视频播放页
class FullscreenVideoPage extends ConsumerStatefulWidget {
  const FullscreenVideoPage({super.key});

  @override
  ConsumerState<FullscreenVideoPage> createState() =>
      _FullscreenVideoPageState();
}

class _FullscreenVideoPageState
    extends ConsumerState<FullscreenVideoPage>
    with WidgetsBindingObserver, VideoGestureMixin {
  // ===== VideoGestureMixin 钩子实现 =====

  @override
  VideoPlayerController? get videoController => _watchedController;

  @override
  bool get gesturesEnabled => true;

  @override
  void onSingleTap() {
    _toggleControls();
  }

  @override
  void onDoubleTapLeft() {
    super.onDoubleTapLeft();
  }

  @override
  void onDoubleTapRight() {
    super.onDoubleTapRight();
  }

  @override
  void onDoubleTapCenter() {
    final item = ref.read(currentPlayingItemProvider);
    if (item != null) {
      try {
        ref.read(favoritesProvider.notifier).toggleFavorite(item);
      } catch (e) {
        AppLogger.warn('全屏点赞失败', data: {'error': e.toString()});
      }
    }
    triggerHeart();
  }

  @override
  bool get handleLeftVerticalDrag => true;

  @override
  void onLeftVerticalDragUpdate(double delta) {
    if (!_showBrightnessUINotifier.value) {
      _dragStartBrightness = _brightnessValue;
      _previewBrightnessNotifier.value = _dragStartBrightness;
      _showBrightnessUINotifier.value = true;
    }
    var newBrightness = (_dragStartBrightness + delta).clamp(0.0, 1.0);
    _previewBrightnessNotifier.value = newBrightness;
    _setSystemBrightness(newBrightness);
  }

  @override
  void endDrag() {
    final wasVerticalBrightness = dragAxis == 'v' && !isVolumeSide;
    super.endDrag();
    if (wasVerticalBrightness) {
      _brightnessHideTimer?.cancel();
      _brightnessHideTimer = Timer(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        _showBrightnessUINotifier.value = false;
      });
    }
  }

  @override
  void onLongPressEnd(LongPressEndDetails details) {
    super.onLongPressEnd(details);
    ref.read(playbackRateProvider.notifier).state = originalRate;
  }

  @override
  MediaItem? get currentItem => ref.read(currentPlayingItemProvider);

  // ===== 全屏页特有状态 =====

  bool _controlsVisible = true;
  Timer? _hideTimer;

  bool _isScreenLocked = false;
  _OrientationPref _orientationPref = _OrientationPref.landscape;
  _AspectRatioMode _aspectMode = _AspectRatioMode.auto;

  bool _showSettingsPanel = false;
  _SettingsTab _settingsTab = _SettingsTab.speed;

  AppLifecycleState? _lastLifecycleState;
  StreamSubscription<ConnectivityResult>? _connectivitySub;
  String? _networkToastMessage;
  Timer? _networkToastTimer;

  int _retryKey = 0;

  bool _isRotating = false;
  Timer? _rotateEndTimer;

  double _brightnessValue = 1.0;
  double? _originalBrightness;
  double _dragStartBrightness = 0.0;
  final ValueNotifier<bool> _showBrightnessUINotifier = ValueNotifier<bool>(false);
  final ValueNotifier<double> _previewBrightnessNotifier = ValueNotifier<double>(0.0);
  Timer? _brightnessHideTimer;

  // 功耗优化：状态缓存
  final ValueNotifier<bool> _bufferingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<int> _positionSecondsNotifier = ValueNotifier<int>(0);
  bool _lastIsPlaying = false;
  bool _lastHasError = false;
  bool _wasControllerReady = false;
  VideoPlayerController? _watchedController;
  int _lastPositionSec = -1;

  // 字幕
  List<SubtitleCue> _subtitleCues = const <SubtitleCue>[];
  bool _isLoadingSubtitle = false;

  Timer? _resumePlayTimer;

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
      _wasControllerReady = v.isInitialized && !v.hasError && !v.size.isEmpty;
    } else {
      _lastIsPlaying = false;
      _lastHasError = false;
      _bufferingNotifier.value = false;
      _wasControllerReady = false;
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

    final isReady = v.isInitialized && !v.hasError && !v.size.isEmpty;
    if (isReady != _wasControllerReady) {
      _wasControllerReady = isReady;
      needsRebuild = true;
    }

    // 位置秒数节流更新，用于字幕渲染（每秒最多一次）
    final sec = v.position.inSeconds;
    if (sec != _lastPositionSec) {
      _lastPositionSec = sec;
      _positionSecondsNotifier.value = sec;
    }

    if (needsRebuild && mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 同步初始化 controller listener，确保首帧时 listener 已正确设置
    // （避免 build 中有副作用）
    final initialController = ref.read(currentVideoControllerProvider);
    _setupControllerListener(initialController);

    // 监听 controller 变化，安全注册 listener
    ref.listen<VideoPlayerController?>(currentVideoControllerProvider,
        (prev, next) {
      _setupControllerListener(next);
      if (mounted) setState(() {});
    });

    // 监听字幕选择变化，异步加载字幕
    ref.listen<String?>(selectedSubtitleProvider, (previous, next) {
      if (next != previous) {
        _loadSubtitle(next);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctrl = ref.read(currentVideoControllerProvider);
      if (ctrl != null && ctrl.value.isInitialized) {
        final size = ctrl.value.size;
        final isLandscapeVideo = size.width >= size.height;
        _orientationPref =
            isLandscapeVideo ? _OrientationPref.landscape : _OrientationPref.sensor;
      }
      _applyOrientations();
      _applySystemUI();
      // isFullscreenProvider 由调用方在 Navigator.push 前同步设置，
      // 避免 VideoPageItem 和 FullscreenVideoPage 短暂同时渲染同一 controller
    });

    _applySystemUI();
    _applyOrientations();
    _initConnectivity();
    _initBrightness();
    _startHideTimer();
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
    _connectivitySub =
        Connectivity().onConnectivityChanged.listen((result) {
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
    _networkToastTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _networkToastMessage = null);
    });
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

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (!_isRotating && mounted) {
      _isRotating = true;
      _hideTimer?.cancel();
    }
    _rotateEndTimer?.cancel();
    _rotateEndTimer = Timer(const Duration(milliseconds: 350), () {
      _isRotating = false;
      if (mounted) {
        if (_controlsVisible && !_isScreenLocked && !_showSettingsPanel) {
          _startHideTimer();
        }
        setState(() {});
      }
    });
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
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!mounted) return;

    final prev = _lastLifecycleState;
    _lastLifecycleState = state;
    if (prev == null) return;

    final wasForeground = prev == AppLifecycleState.resumed;
    final isForeground = state == AppLifecycleState.resumed;
    final controller = ref.read(currentVideoControllerProvider);
    final wasPlaying = controller?.value.isPlaying ?? false;

    if (wasForeground && !isForeground) {
      try {
        controller?.pause();
      } catch (_) {}
    }

    if (!wasForeground && isForeground && wasPlaying) {
      _resumePlayTimer?.cancel();
      _resumePlayTimer = Timer(const Duration(milliseconds: 300), () {
        if (mounted) {
          try {
            controller?.play();
          } catch (_) {}
        }
      });
    }
  }

  // 异步加载字幕
  Future<void> _loadSubtitle(String? selectedTrackId) async {
    if (!mounted) return;
    if (selectedTrackId == null) {
      setState(() {
        _subtitleCues = const <SubtitleCue>[];
      });
      return;
    }
    final item = ref.read(currentPlayingItemProvider);
    if (item == null) return;
    final sources = item.mediaSources;
    final mediaSourceId =
        (sources != null && sources.isNotEmpty) ? sources.first.id : null;
    if (mediaSourceId == null || mediaSourceId.isEmpty) return;

    final tracks = item.subtitleTracks;
    int? trackIndex;
    for (int i = 0; i < tracks.length; i++) {
      if (tracks[i].id == selectedTrackId) {
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

    setState(() => _isLoadingSubtitle = true);
    try {
      final embService = ref.read(embbytokServiceProvider);
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
      final cues = await embService.getSubtitleCues(
        itemId: item.id,
        mediaSourceId: mediaSourceId,
        index: trackIndex,
      );
      if (mounted) {
        setState(() {
          _subtitleCues = cues;
          _isLoadingSubtitle = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingSubtitle = false;
          _subtitleCues = const <SubtitleCue>[];
        });
      }
      AppLogger.warn('字幕加载失败', data: {'error': e.toString()});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    disposeGestureTimers();
    _hideTimer?.cancel();
    _networkToastTimer?.cancel();
    _connectivitySub?.cancel();
    _rotateEndTimer?.cancel();
    _brightnessHideTimer?.cancel();
    _resumePlayTimer?.cancel();
    _watchedController?.removeListener(_onControllerTick);
    _bufferingNotifier.dispose();
    _positionSecondsNotifier.dispose();
    _showBrightnessUINotifier.dispose();
    _previewBrightnessNotifier.dispose();

    if (_originalBrightness != null) {
      try {
        ScreenBrightness().resetScreenBrightness();
      } catch (e) {
        AppLogger.warn('重置屏幕亮度失败', data: {'error': e.toString()});
      }
    }

    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    ref.read(isFullscreenProvider.notifier).state = false;

    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && !_isScreenLocked && !_showSettingsPanel) {
        setState(() => _controlsVisible = false);
      }
    });
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
    final item = ref.read(currentPlayingItemProvider);
    if (item != null) {
      ref.read(videoRetryRequestProvider.notifier).state = item.id;
      setState(() => _retryKey++);
    }
  }

  // 视频渲染表面：根据画面比例模式正确显示
  Widget _buildVideoSurface(VideoPlayerController controller) {
    final videoSize = controller.value.size;
    final hasValidSize = !videoSize.isEmpty;
    // 尺寸为空时使用 1x1 占位，保证 VideoPlayer 渲染管线不断
    final width = hasValidSize ? videoSize.width : 1.0;
    final height = hasValidSize ? videoSize.height : 1.0;

    switch (_aspectMode) {
      case _AspectRatioMode.auto:
        final isPortraitVideo = hasValidSize && videoSize.height > videoSize.width;
        return FittedBox(
          fit: isPortraitVideo ? BoxFit.cover : BoxFit.contain,
          child: SizedBox(
            width: width,
            height: height,
            child: VideoPlayer(controller),
          ),
        );
      case _AspectRatioMode.contain:
      case _AspectRatioMode.cover:
      case _AspectRatioMode.fill:
        return FittedBox(
          fit: _getBoxFit(),
          child: SizedBox(
            width: width,
            height: height,
            child: VideoPlayer(controller),
          ),
        );
      case _AspectRatioMode.sixteenNine:
      case _AspectRatioMode.fourThree:
        // 固定比例模式：外层按指定比例布局，内层裁剪/拉伸由 fit 决定
        final targetRatio =
            _aspectMode == _AspectRatioMode.sixteenNine ? 16 / 9 : 4 / 3;
        return Center(
          child: AspectRatio(
            aspectRatio: targetRatio,
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: width,
                height: height,
                child: VideoPlayer(controller),
              ),
            ),
          ),
        );
    }
  }

  BoxFit _getBoxFit() {
    switch (_aspectMode) {
      case _AspectRatioMode.auto:
        final controller = ref.read(currentVideoControllerProvider);
        if (controller != null && controller.value.isInitialized) {
          final size = controller.value.size;
          final isPortraitVideo = size.height > size.width;
          return isPortraitVideo ? BoxFit.cover : BoxFit.contain;
        }
        return BoxFit.contain;
      case _AspectRatioMode.contain:
        return BoxFit.contain;
      case _AspectRatioMode.cover:
        return BoxFit.cover;
      case _AspectRatioMode.fill:
        return BoxFit.fill;
      case _AspectRatioMode.sixteenNine:
        return BoxFit.contain;
      case _AspectRatioMode.fourThree:
        return BoxFit.contain;
    }
  }

  double _resolveAspectRatio(VideoPlayerController controller) {
    if (_aspectMode == _AspectRatioMode.sixteenNine) return 16 / 9;
    if (_aspectMode == _AspectRatioMode.fourThree) return 4 / 3;
    if (!controller.value.isInitialized) return 16 / 9;
    final ratio = controller.value.aspectRatio;
    return ratio == 0 ? 16 / 9 : ratio;
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

  int? _getCurrentIndex() {
    final items = ref.read(videoListProvider).items;
    final current = ref.read(currentPlayingItemProvider);
    if (current == null) return null;
    for (int i = 0; i < items.length; i++) {
      if (items[i].id == current.id) return i;
    }
    return null;
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

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(currentVideoControllerProvider);
    final playingItem = ref.watch(currentPlayingItemProvider);
    final items = ref.watch(videoListProvider.select((s) => s.items));

    bool isControllerReady;
    bool hasError;
    if (controller != null) {
      final v = controller.value;
      // 增加尺寸检查，避免尺寸为空时认为控制器就绪导致黑屏
      isControllerReady = v.isInitialized && !v.hasError && !v.size.isEmpty;
      hasError = v.hasError;
    } else {
      isControllerReady = false;
      hasError = false;
    }

    final mediaOrientation = MediaQuery.orientationOf(context);
    final isActuallyLandscape = mediaOrientation == Orientation.landscape;
    final videoVisible = !_isScreenLocked;
    final gesturesEnabled = !_isScreenLocked && !_showSettingsPanel && !_controlsVisible;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        key: ValueKey('fs-stack-$_retryKey'),
        children: [
          // 视频渲染层
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: handleTapDown,
              onTap: handleTap,
              onLongPressStart:
                  gesturesEnabled && controller != null
                      ? onLongPressStart
                      : null,
              onLongPressEnd:
                  gesturesEnabled && controller != null
                      ? onLongPressEnd
                      : null,
              onLongPressCancel:
                  gesturesEnabled && controller != null
                      ? () => onLongPressEnd(LongPressEndDetails())
                      : null,
              onPanStart: gesturesEnabled ? onPanStart : null,
              onPanUpdate: gesturesEnabled ? onPanUpdate : null,
              onPanEnd: gesturesEnabled ? onPanEnd : null,
              onPanCancel: gesturesEnabled ? onPanCancel : null,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: Colors.black),

                  if (isControllerReady && controller != null)
                    Offstage(
                      offstage: hasError || !videoVisible,
                      child: _buildVideoSurface(controller),
                    ),

                  if (hasError && controller != null)
                    _buildErrorState(controller),

                  if (!isControllerReady && !hasError)
                    const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),

                  if (isControllerReady && !hasError)
                    ValueListenableBuilder<bool>(
                      valueListenable: _bufferingNotifier,
                      builder: (context, isBuffering, child) {
                        if (!isBuffering) return const SizedBox.shrink();
                        return const Center(
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: CircularProgressIndicator(
                              color: Colors.white70,
                              strokeWidth: 2.5,
                            ),
                          ),
                        );
                      },
                    ),

                  // 字幕渲染层
                  if (isControllerReady &&
                      !hasError &&
                      _subtitleCues.isNotEmpty &&
                      ref.watch(selectedSubtitleProvider) != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 60,
                      child: RepaintBoundary(
                        child: ValueListenableBuilder<int>(
                          valueListenable: _positionSecondsNotifier,
                          builder: (_, seconds, __) {
                            return SubtitleRenderer(
                              position: Duration(seconds: seconds),
                              cues: _subtitleCues,
                              enabled: true,
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 顶部控制栏
          if (_controlsVisible && !_isScreenLocked)
            _buildTopBar(playingItem, isActuallyLandscape),

          // 底部控制栏
          if (_controlsVisible && isControllerReady && controller != null && !_isScreenLocked)
            _buildBottomBar(controller, playingItem, items),

          // 设置面板
          if (_showSettingsPanel && isControllerReady && controller != null && !_isScreenLocked)
            _buildSettingsPanel(controller),

          // 锁屏 UI
          if (_isScreenLocked) _buildLockUI(),

          // 网络状态 Toast
          if (_networkToastMessage != null) _buildNetworkToast(),

          // 手势反馈 UI
          ValueListenableBuilder<Duration>(
            valueListenable: previewPositionNotifier,
            builder: (context, previewPos, _) {
              if (!isDragging || dragAxis != 'h' || controller == null) return const SizedBox.shrink();
              return Positioned(
                top: 48,
                left: 32,
                right: 32,
                child: _SeekPreviewBar(
                  current: previewPos,
                  total: controller.value.duration,
                  offset: previewPos - dragStartPosition,
                ),
              );
            },
          ),

          ValueListenableBuilder<double>(
            valueListenable: _previewBrightnessNotifier,
            builder: (context, brightness, _) {
              if (!_showBrightnessUINotifier.value || isVolumeSide || dragAxis != 'v') return const SizedBox.shrink();
              return _buildVerticalIndicator(
                icon: _brightnessIconFor(brightness),
                value: brightness,
                label: '亮度',
              );
            },
          ),

          ValueListenableBuilder<double>(
            valueListenable: previewVolumeNotifier,
            builder: (context, volume, _) {
              if (!showVolumeUINotifier.value || !isVolumeSide || dragAxis != 'v') return const SizedBox.shrink();
              return _buildVerticalIndicator(
                icon: _volumeIconFor(volume),
                value: volume,
                label: '音量',
              );
            },
          ),

          ValueListenableBuilder<bool>(
            valueListenable: showSpeedBadgeNotifier,
            builder: (context, show, _) {
              if (!show) return const SizedBox.shrink();
              return IgnorePointer(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${kLongPressPlaybackRate.toStringAsFixed(0)}x',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -1,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          if (showHeart) const IgnorePointer(child: _FlyingHeart()),

          if (showSeekFeedback)
            IgnorePointer(
              child: Positioned(
                top: 0,
                bottom: 0,
                left: isSeekForward ? null : 0,
                right: isSeekForward ? 0 : null,
                width: MediaQuery.of(context).size.width / 3,
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: isSeekForward
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      end: isSeekForward
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      colors: [
                        Colors.white.withOpacity(0.15),
                        Colors.transparent
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSeekForward
                            ? Icons.fast_forward
                            : Icons.fast_rewind,
                        color: Colors.white,
                        size: 48,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${isSeekForward ? '+' : '-'}${seekFeedbackCount * 10}s',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorState(VideoPlayerController? controller) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.white70, size: 56),
          const SizedBox(height: 16),
          const Text(
            '视频加载失败',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            controller?.value.errorDescription ?? '网络错误或资源不可用',
            style: const TextStyle(color: Colors.white54, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: _retryVideo,
            icon: const Icon(Icons.refresh, size: 20),
            label: const Text('重试', style: TextStyle(fontSize: 16)),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.white24,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(MediaItem? playingItem, bool isActuallyLandscape) {
    final IconData orientIcon;
    final String orientTooltip;
    switch (_orientationPref) {
      case _OrientationPref.landscape:
        orientIcon = Icons.screen_lock_portrait;
        orientTooltip = '切换竖屏';
        break;
      case _OrientationPref.portrait:
        orientIcon = Icons.screen_rotation;
        orientTooltip = '跟随系统';
        break;
      case _OrientationPref.sensor:
        orientIcon = Icons.screen_lock_landscape;
        orientTooltip = '锁定横屏';
        break;
    }

    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: SafeArea(
        bottom: false,
        child: AnimatedOpacity(
          opacity: _controlsVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.7),
                  Colors.transparent,
                ],
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.fullscreen_exit,
                      color: Colors.white, size: 28),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: '退出全屏',
                ),
                if (playingItem != null)
                  Expanded(
                    child: Text(
                      playingItem.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                IconButton(
                  icon: Icon(orientIcon, color: Colors.white, size: 24),
                  onPressed: _toggleOrientation,
                  tooltip: orientTooltip,
                ),
                IconButton(
                  icon: const Icon(Icons.settings, color: Colors.white, size: 24),
                  onPressed: () => _toggleSettingsPanel(_SettingsTab.speed),
                  tooltip: '设置',
                ),
                IconButton(
                  icon: const Icon(Icons.lock_open, color: Colors.white, size: 24),
                  onPressed: _lockScreen,
                  tooltip: '锁屏',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(
    VideoPlayerController controller,
    MediaItem? playingItem,
    List<MediaItem> items,
  ) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: AnimatedOpacity(
          opacity: _controlsVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.7),
                ],
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: controller,
                  builder: (context, value, child) {
                    final position = value.position;
                    final duration = value.duration;
                    final progress = duration.inMilliseconds > 0
                        ? position.inMilliseconds / duration.inMilliseconds
                        : 0.0;
                    return Row(
                      children: [
                        Text(
                          _formatDuration(position),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Slider(
                            value: progress.clamp(0.0, 1.0),
                            onChanged: (v) {
                              final target = Duration(
                                milliseconds:
                                    (v * duration.inMilliseconds).round(),
                              );
                              controller.seekTo(target);
                            },
                            activeColor: Theme.of(context).colorScheme.primary,
                            inactiveColor: Colors.white24,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDuration(duration),
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    );
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.skip_previous, color: Colors.white),
                      onPressed: _hasPrevious() ? _jumpToPrevious : null,
                    ),
                    ValueListenableBuilder<VideoPlayerValue>(
                      valueListenable: controller,
                      builder: (context, value, child) {
                        return IconButton(
                          icon: Icon(
                            value.isPlaying
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_filled,
                            color: Colors.white,
                            size: 44,
                          ),
                          onPressed: () {
                            if (value.isPlaying) {
                              controller.pause();
                            } else {
                              controller.play();
                            }
                          },
                        );
                      },
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.subtitles,
                          color: Colors.white, size: 22),
                      onPressed: playingItem?.subtitleTracks.isNotEmpty == true
                          ? () => _showSubtitleMenu(playingItem!)
                          : null,
                      tooltip: '字幕',
                    ),
                    IconButton(
                      icon: ValueListenableBuilder<VideoPlayerValue>(
                        valueListenable: controller,
                        builder: (context, value, child) {
                          return Text(
                            '${value.playbackSpeed.toStringAsFixed(1)}x',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                          );
                        },
                      ),
                      onPressed: () => _toggleSettingsPanel(_SettingsTab.speed),
                      tooltip: '倍速',
                    ),
                    IconButton(
                      icon: const Icon(Icons.aspect_ratio,
                          color: Colors.white, size: 22),
                      onPressed: () => _toggleSettingsPanel(_SettingsTab.ratio),
                      tooltip: '画面比例',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsPanel(VideoPlayerController controller) {
    return Positioned(
      right: 16,
      bottom: 100,
      child: SafeArea(
        child: AnimatedOpacity(
          opacity: _showSettingsPanel ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            width: 200,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.88),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSettingsTabBar(),
                const Divider(color: Colors.white24, height: 1),
                _buildSettingsContent(controller),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsTabBar() {
    return Row(
      children: _SettingsTab.values.map((tab) {
        final selected = _settingsTab == tab;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _settingsTab = tab),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: selected ? Colors.white : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Icon(
                _tabIcon(tab),
                color: selected ? Colors.white : Colors.white54,
                size: 20,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  IconData _tabIcon(_SettingsTab tab) {
    switch (tab) {
      case _SettingsTab.speed:
        return Icons.speed;
      case _SettingsTab.ratio:
        return Icons.aspect_ratio;
    }
  }

  Widget _buildSettingsContent(VideoPlayerController controller) {
    switch (_settingsTab) {
      case _SettingsTab.speed:
        return _buildSpeedList(controller);
      case _SettingsTab.ratio:
        return _buildRatioList();
    }
  }

  Widget _buildSpeedList(VideoPlayerController controller) {
    const rates = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    final currentRate = ref.watch(playbackRateProvider);
    return Column(
      children: rates.map((rate) {
        final selected = (rate - currentRate).abs() < 0.01;
        return _SettingsListItem(
          label: '${rate.toStringAsFixed(rate.truncateToDouble() == rate ? 0 : 2)}x',
          selected: selected,
          onTap: () {
            controller.setPlaybackSpeed(rate);
            ref.read(playbackRateProvider.notifier).state = rate;
            _startHideTimer();
          },
        );
      }).toList(),
    );
  }

  Widget _buildRatioList() {
    const modes = [
      (_AspectRatioMode.auto, '自适应'),
      (_AspectRatioMode.contain, '完整显示'),
      (_AspectRatioMode.cover, '填满裁剪'),
      (_AspectRatioMode.fill, '拉伸填充'),
      (_AspectRatioMode.sixteenNine, '16:9'),
      (_AspectRatioMode.fourThree, '4:3'),
    ];
    return Column(
      children: modes.map((m) {
        final selected = m.$1 == _aspectMode;
        return _SettingsListItem(
          label: m.$2,
          selected: selected,
          onTap: () {
            setState(() => _aspectMode = m.$1);
            _startHideTimer();
          },
        );
      }).toList(),
    );
  }

  Widget _buildLockUI() {
    return Positioned(
      left: 12,
      top: 0,
      bottom: 0,
      child: SafeArea(
        child: Center(
          child: GestureDetector(
            onTap: _unlockScreen,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white24, width: 1),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.lock_outline, color: Colors.white, size: 28),
                  SizedBox(height: 6),
                  Text(
                    '点击\n解锁',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNetworkToast() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 60,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.75),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                _networkToastMessage ?? '',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _brightnessIconFor(double value) {
    if (value <= 0.1) return Icons.brightness_low;
    if (value < 0.5) return Icons.brightness_medium;
    return Icons.brightness_high;
  }

  IconData _volumeIconFor(double value) {
    if (value <= 0) return Icons.volume_off;
    if (value < 0.5) return Icons.volume_down;
    return Icons.volume_up;
  }

  Widget _buildVerticalIndicator({
    required IconData icon,
    required double value,
    required String label,
  }) {
    return IgnorePointer(
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 36),
              const SizedBox(height: 8),
              SizedBox(
                width: 120,
                child: LinearProgressIndicator(
                  value: value,
                  backgroundColor: Colors.white24,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.white),
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${(value * 100).round()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showSubtitleMenu(MediaItem item) async {
    final selectedSubId = ref.read(selectedSubtitleProvider);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.9),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('关闭字幕',
                  style: TextStyle(color: Colors.white)),
              leading: const Icon(Icons.close, color: Colors.white54),
              onTap: () {
                ref.read(selectedSubtitleProvider.notifier).state = null;
                Navigator.pop(context);
              },
            ),
            ...item.subtitleTracks.map((track) {
              final selected = track.id == selectedSubId;
              return ListTile(
                title: Text(
                  track.name,
                  style: TextStyle(
                    color: selected ? Colors.blue : Colors.white,
                    fontWeight:
                        selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                leading: Icon(
                  selected ? Icons.check : Icons.subtitles,
                  color: selected ? Colors.blue : Colors.white54,
                ),
                onTap: () {
                  ref.read(selectedSubtitleProvider.notifier).state = track.id;
                  Navigator.pop(context);
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 内部辅助组件
// ============================================================================

class _SeekPreviewBar extends StatelessWidget {
  final Duration current;
  final Duration total;
  final Duration offset;

  const _SeekPreviewBar({
    required this.current,
    required this.total,
    required this.offset,
  });

  String _format(Duration d) {
    if (d.inSeconds < 0) return '0:00';
    if (d.inHours > 0) {
      final h = d.inHours;
      final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return '$h:$m:$s';
    }
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return '${m.toString().padLeft(1, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final progress = total.inMilliseconds > 0
        ? current.inMilliseconds / total.inMilliseconds
        : 0.0;
    final clampedProgress = progress.clamp(0.0, 1.0);
    final isForward = offset >= Duration.zero;
    final offsetText =
        '${isForward ? '+' : '-'}${(offset.inSeconds.abs() ~/ 1)}s';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: Theme.of(context).colorScheme.primary, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                isForward ? Icons.fast_forward : Icons.fast_rewind,
                color: Theme.of(context).colorScheme.primary,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                offsetText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${_format(current)} / ${_format(total)}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: clampedProgress,
            backgroundColor: Colors.white24,
            valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary),
          ),
        ],
      ),
    );
  }
}

class _FlyingHeart extends StatefulWidget {
  const _FlyingHeart();

  @override
  State<_FlyingHeart> createState() => _FlyingHeartState();
}

class _FlyingHeartState extends State<_FlyingHeart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _opacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _scale = Tween<double>(begin: 0.6, end: 2.8).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.scale(
            scale: _scale.value,
            child: Icon(
              Icons.favorite,
              color: Theme.of(context).colorScheme.primary,
              size: 96,
            ),
          ),
        );
      },
    );
  }
}

class _SettingsListItem extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _SettingsListItem({
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white70,
                      fontSize: 14,
                      fontWeight:
                          selected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }
}

enum _SettingsTab { speed, ratio }
enum _AspectRatioMode { auto, contain, cover, fill, sixteenNine, fourThree }
enum _OrientationPref { landscape, portrait, sensor }

class _QualityOption {
  final int level;
  final String label;
  final String desc;
  const _QualityOption(this.level, this.label, this.desc);
}
