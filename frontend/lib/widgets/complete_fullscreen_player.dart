// 完整功能全屏播放器组件
//
// 核心特性：
// 1. 基础交互：播放暂停、进度拖动、退出全屏、控制栏自动显隐、横竖屏切换
// 2. 标准手势：左侧调亮度（系统级）、右侧调音量、左右滑动快进快退、长按倍速、双击步进
// 3. 设置面板：倍速切换、清晰度切换（DirectPlay/DirectStream/HLS）、画面比例设置
// 4. 系统适配：沉浸式状态栏、安全区、前后台切换、网络切换提醒
// 5. 状态反馈：缓冲、失败、手势操作的完整视觉反馈
// 6. 无缝衔接：复用外部 VideoPlayerController，不重新初始化
// 7. 系统亮度：使用 screen_brightness 实现全局亮度调节，退出时恢复原始亮度
//
// 接入方式：
// ```dart
// Navigator.push(
//   context,
//   MaterialPageRoute(
//     builder: (_) => const CompleteFullscreenPlayer(),
//     fullscreenDialog: true,
//   ),
// );
// ```
//
// 依赖：
// - screen_brightness: ^0.2.2+1（系统级亮度调节）
// - connectivity_plus: ^5.0.0（项目已存在）

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:video_player/video_player.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/constants.dart';

// ============================================================================
// 主组件入口
// ============================================================================

class CompleteFullscreenPlayer extends ConsumerStatefulWidget {
  const CompleteFullscreenPlayer({super.key});

  @override
  ConsumerState<CompleteFullscreenPlayer> createState() =>
      _CompleteFullscreenPlayerState();
}

class _CompleteFullscreenPlayerState
    extends ConsumerState<CompleteFullscreenPlayer>
    with WidgetsBindingObserver {
  bool _controlsVisible = true;
  Timer? _hideTimer;

  bool _isScreenLocked = false;
  bool _isLandscape = true;
  _AspectRatioMode _aspectMode = _AspectRatioMode.auto;

  bool _showSettingsPanel = false;
  _SettingsTab _settingsTab = _SettingsTab.speed;

  AppLifecycleState? _lastLifecycleState;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  String? _networkToastMessage;
  Timer? _networkToastTimer;

  int _retryKey = 0;

  // 系统亮度值（通过 screen_brightness 实现全局调节）
  double _brightnessValue = 1.0;
  // 进入全屏前的原始亮度，退出时恢复
  double? _originalBrightness;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _applyOrientations();
    _applySystemUI();
    _initConnectivity();
    _initBrightness();

    Future.microtask(() {
      if (mounted) {
        ref.read(isFullscreenProvider.notifier).state = true;
      }
    });

    _startHideTimer();
  }

  Future<void> _initBrightness() async {
    try {
      // 读取并保存当前系统亮度
      _originalBrightness = await ScreenBrightness().current;
      _brightnessValue = _originalBrightness ?? 1.0;
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Failed to read screen brightness: $e');
      _brightnessValue = 1.0;
    }
  }

  Future<void> _setSystemBrightness(double value) async {
    try {
      await ScreenBrightness().setScreenBrightness(value);
    } catch (e) {
      debugPrint('Failed to set screen brightness: $e');
    }
  }

  void _initConnectivity() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      _onConnectivityChanged(results);
    });
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.none)) {
      _showNetworkToast('网络已断开');
    } else if (results.contains(ConnectivityResult.wifi)) {
      _showNetworkToast('已切换到 WiFi');
    } else if (results.contains(ConnectivityResult.mobile)) {
      _showNetworkToast('已切换到移动网络');
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
    if (_isLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
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
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          try {
            controller?.play();
          } catch (_) {}
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    _networkToastTimer?.cancel();
    _connectivitySub?.cancel();

    // 恢复进入全屏前的系统亮度
    if (_originalBrightness != null) {
      try {
        ScreenBrightness().resetScreenBrightness();
      } catch (_) {}
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

  void _exitFullscreen() {
    Navigator.of(context).pop();
  }

  void _toggleOrientation() {
    setState(() => _isLandscape = !_isLandscape);
    _applyOrientations();
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
    final controller = ref.read(currentVideoControllerProvider);
    if (controller != null) {
      try {
        controller.play();
      } catch (_) {}
      setState(() => _retryKey++);
    }
  }

  VoidCallback? _computeOnNextEpisode(MediaItem? playingItem, List<MediaItem> items) {
    if (playingItem == null) return null;
    final currentIndex = items.indexWhere((i) => i.id == playingItem.id);
    if (currentIndex < 0) return null;

    final series = playingItem.seriesName;
    if (series != null && series.isNotEmpty) {
      final nextSameSeries = items.indexWhere(
        (i) =>
            i.id != playingItem.id &&
            i.seriesName == series &&
            (i.indexNumber ?? 0) > (playingItem.indexNumber ?? 0),
      );
      if (nextSameSeries >= 0) {
        return () {
          ref.read(feedViewPageJumpRequestProvider.notifier).state =
              nextSameSeries;
        };
      }
    }
    if (currentIndex + 1 < items.length) {
      return () {
        ref.read(feedViewPageJumpRequestProvider.notifier).state =
            currentIndex + 1;
      };
    }
    return null;
  }

  VoidCallback? _computeOnPrevEpisode(MediaItem? playingItem, List<MediaItem> items) {
    if (playingItem == null) return null;
    final currentIndex = items.indexWhere((i) => i.id == playingItem.id);
    if (currentIndex < 0) return null;

    final series = playingItem.seriesName;
    if (series != null && series.isNotEmpty) {
      final prevSameSeries = items.lastIndexWhere(
        (i) =>
            i.id != playingItem.id &&
            i.seriesName == series &&
            (i.indexNumber ?? 0) < (playingItem.indexNumber ?? 0),
      );
      if (prevSameSeries >= 0) {
        return () {
          ref.read(feedViewPageJumpRequestProvider.notifier).state =
              prevSameSeries;
        };
      }
    }
    if (currentIndex - 1 >= 0) {
      return () {
        ref.read(feedViewPageJumpRequestProvider.notifier).state =
            currentIndex - 1;
      };
    }
    return null;
  }

  String _displayTitle(MediaItem? item) {
    if (item == null) return '';
    if (item.seriesName != null &&
        item.seriesName!.isNotEmpty &&
        item.indexNumber != null) {
      return '${item.seriesName} · E${item.indexNumber}';
    }
    return item.title;
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

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(currentVideoControllerProvider);
    final playingItem = ref.watch(currentPlayingItemProvider);
    final items = ref.watch(videoListProvider.select((s) => s.items));

    final onNextEpisode = _computeOnNextEpisode(playingItem, items);
    final onPrevEpisode = _computeOnPrevEpisode(playingItem, items);

    final isControllerReady =
        controller != null && controller.value.isInitialized;
    final hasError = controller != null && controller.value.hasError;

    return Scaffold(
      backgroundColor: Colors.black,
      body: PopScope(
        canPop: true,
        child: Stack(
          children: [
            // 视频渲染层 + 手势层
            if (isControllerReady)
              IgnorePointer(
                ignoring: _isScreenLocked,
                child: _PlayerGestureLayer(
                  key: ValueKey('gesture_$_retryKey'),
                  controller: controller,
                  item: playingItem ??
                      const MediaItem(
                          id: '', title: '', type: 'Unknown'),
                  onSingleTap: _toggleControls,
                  enableGestures: !_controlsVisible &&
                      !_isScreenLocked &&
                      !_showSettingsPanel,
                  enableVerticalDrag: true,
                  initialBrightness: _brightnessValue,
                  onBrightnessChanged: (v) {
                    setState(() => _brightnessValue = v);
                    _setSystemBrightness(v);
                  },
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: _resolveAspectRatio(controller),
                      child: FittedBox(
                        fit: _getBoxFit(),
                        child: SizedBox(
                          width: controller.value.size.width,
                          height: controller.value.size.height,
                          child: VideoPlayer(controller),
                        ),
                      ),
                    ),
                  ),
                ),
              )
            else if (hasError)
              _buildErrorState(controller)
            else
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),

            // 缓冲指示器
            if (isControllerReady && !hasError)
              ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: controller!,
                builder: (context, value, child) {
                  if (value.isBuffering) {
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
                  }
                  return const SizedBox.shrink();
                },
              ),

            // 顶部控制栏
            if (_controlsVisible && !_isScreenLocked)
              _buildTopBar(playingItem),

            // 底部控制栏
            if (_controlsVisible && isControllerReady && !_isScreenLocked)
              _buildBottomBar(controller, playingItem, onPrevEpisode, onNextEpisode),

            // 设置面板
            if (_showSettingsPanel && isControllerReady && !_isScreenLocked)
              _buildSettingsPanel(controller),

            // 锁屏 UI
            if (_isScreenLocked) _buildLockUI(),

            // 网络状态 Toast
            if (_networkToastMessage != null)
              _buildNetworkToast(),
          ],
        ),
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

  Widget _buildTopBar(MediaItem? playingItem) {
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
                  onPressed: _exitFullscreen,
                  tooltip: '退出全屏',
                ),
                if (playingItem != null)
                  Expanded(
                    child: Text(
                      _displayTitle(playingItem),
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
                  icon: Icon(
                    _isLandscape
                        ? Icons.screen_lock_portrait
                        : Icons.screen_lock_landscape,
                    color: Colors.white,
                    size: 24,
                  ),
                  onPressed: _toggleOrientation,
                  tooltip: _isLandscape ? '切换竖屏' : '切换横屏',
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
    VoidCallback? onPrev,
    VoidCallback? onNext,
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
            child: _FullscreenControls(
              controller: controller,
              subtitleTracks:
                  playingItem?.subtitleTracks ?? const <SubtitleTrack>[],
              onPrevEpisode: onPrev,
              onNextEpisode: onNext,
              isInFullscreen: true,
              onSeekStart: () {
                _hideTimer?.cancel();
              },
              onSeekEnd: () {
                _startHideTimer();
              },
              onSpeedTap: () => _toggleSettingsPanel(_SettingsTab.speed),
              onQualityTap: () => _toggleSettingsPanel(_SettingsTab.quality),
              onRatioTap: () => _toggleSettingsPanel(_SettingsTab.ratio),
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
      case _SettingsTab.quality:
        return Icons.hd;
      case _SettingsTab.ratio:
        return Icons.aspect_ratio;
    }
  }

  Widget _buildSettingsContent(VideoPlayerController controller) {
    switch (_settingsTab) {
      case _SettingsTab.speed:
        return _buildSpeedList(controller);
      case _SettingsTab.quality:
        return _buildQualityList();
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

  Widget _buildQualityList() {
    final currentLevel = ref.watch(playbackLevelProvider);
    const qualities = [
      _QualityOption(0, '原画画质', 'Direct Play'),
      _QualityOption(1, '高清 Remux', 'Direct Stream'),
      _QualityOption(2, '流畅转码', 'HLS'),
    ];
    return Column(
      children: qualities.map((q) {
        final selected = q.level == currentLevel;
        return _SettingsListItem(
          label: q.label,
          subtitle: q.desc,
          selected: selected,
          onTap: () {
            ref.read(playbackLevelProvider.notifier).setLevel(q.level);
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
}

// ============================================================================
// 手势层组件
// ============================================================================

class _PlayerGestureLayer extends ConsumerStatefulWidget {
  final Widget child;
  final MediaItem item;
  final VideoPlayerController controller;
  final VoidCallback? onSingleTap;
  final bool enableGestures;
  final bool enableVerticalDrag;
  final double initialBrightness;
  final ValueChanged<double>? onBrightnessChanged;

  const _PlayerGestureLayer({
    super.key,
    required this.child,
    required this.item,
    required this.controller,
    this.onSingleTap,
    this.enableGestures = true,
    this.enableVerticalDrag = false,
    this.initialBrightness = 1.0,
    this.onBrightnessChanged,
  });

  @override
  ConsumerState<_PlayerGestureLayer> createState() =>
      _PlayerGestureLayerState();
}

class _PlayerGestureLayerState extends ConsumerState<_PlayerGestureLayer> {
  Timer? _singleTapTimer;
  bool _pendingSingleTap = false;
  bool _isLongPressing = false;
  double _originalRate = 1.0;

  bool _isDragging = false;
  String? _dragAxis;
  double _dragStartX = 0.0;
  double _dragStartY = 0.0;

  Duration _dragStartPosition = Duration.zero;
  Duration _previewPosition = Duration.zero;

  bool _isBrightnessSide = false;
  bool _isVolumeSide = false;
  double _dragStartBrightness = 0.0;
  double _dragStartVolume = 0.0;
  bool _showBrightnessUI = false;
  bool _showVolumeUI = false;
  double _previewBrightness = 0.0;
  double _previewVolume = 0.0;

  bool _showHeart = false;
  Timer? _dragHideTimer;
  Timer? _verticalHideTimer;

  Offset? _lastTapPosition;
  bool _showSeekFeedback = false;
  bool _isSeekForward = false;
  bool _showSpeedBadge = false;

  bool get _controllerReady {
    final c = widget.controller;
    if (!c.value.isInitialized) return false;
    if (c.value.hasError) return false;
    return true;
  }

  void _onSingleTap() {
    widget.onSingleTap?.call();
  }

  void _onDoubleTap() {
    final pos = _lastTapPosition;
    final screenWidth = MediaQuery.of(context).size.width;

    if (pos != null && _controllerReady) {
      final relativeX = pos.dx / screenWidth;
      if (relativeX < 0.33) {
        _seekBySeconds(-10);
        return;
      } else if (relativeX > 0.67) {
        _seekBySeconds(10);
        return;
      }
    }

    setState(() => _showHeart = true);
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _showHeart = false);
    });
    try {
      unawaited(
          ref.read(favoritesProvider.notifier).toggleFavorite(widget.item));
    } catch (e) {
      debugPrint('_onDoubleTap toggleFavorite error: $e');
    }
  }

  void _seekBySeconds(int seconds) {
    final c = widget.controller;
    if (!_controllerReady) return;
    try {
      final current = c.value.position;
      final duration = c.value.duration;
      var target = current + Duration(seconds: seconds);
      if (target < Duration.zero) target = Duration.zero;
      if (duration > Duration.zero && target > duration) target = duration;
      c.seekTo(target);
      HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('doubleTap seek error: $e');
    }
    setState(() {
      _isSeekForward = seconds > 0;
      _showSeekFeedback = true;
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _showSeekFeedback = false);
    });
  }

  void _onLongPressStart() {
    final c = widget.controller;
    if (!_controllerReady) return;
    try {
      _isLongPressing = true;
      _originalRate = c.value.playbackSpeed;
      c.setPlaybackSpeed(kLongPressPlaybackRate);
      if (mounted) setState(() => _showSpeedBadge = true);
    } catch (e) {
      debugPrint('_onLongPressStart error: $e');
    }
  }

  void _onLongPressEnd() {
    if (!_isLongPressing) return;
    _isLongPressing = false;
    final c = widget.controller;
    if (!_controllerReady) return;
    try {
      c.setPlaybackSpeed(_originalRate);
      ref.read(playbackRateProvider.notifier).state = _originalRate;
    } catch (e) {
      debugPrint('_onLongPressEnd error: $e');
    }
    if (mounted) setState(() => _showSpeedBadge = false);
  }

  void _onPanStart(DragStartDetails d) {
    final c = widget.controller;
    if (!_controllerReady) return;
    _dragStartX = d.globalPosition.dx;
    _dragStartY = d.globalPosition.dy;
    _isDragging = true;
    _dragAxis = null;
    _dragHideTimer?.cancel();
    _verticalHideTimer?.cancel();
    if (mounted) setState(() {});
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final c = widget.controller;
    if (!_controllerReady) return;

    final dx = d.globalPosition.dx - _dragStartX;
    final dy = d.globalPosition.dy - _dragStartY;

    if (_dragAxis == null) {
      if (dx.abs() > dy.abs() && dx.abs() > 8) {
        _dragAxis = 'h';
        _dragStartPosition = c.value.position;
        _previewPosition = c.value.position;
        HapticFeedback.selectionClick();
        if (mounted) setState(() {});
      } else if (dy.abs() > dx.abs() && dy.abs() > 8) {
        _dragAxis = 'v';
        final screenWidth = MediaQuery.of(context).size.width;
        _isBrightnessSide = _dragStartX < screenWidth / 2;
        _isVolumeSide = _dragStartX >= screenWidth / 2;

        if (_isBrightnessSide) {
          _dragStartBrightness = widget.initialBrightness;
          _previewBrightness = _dragStartBrightness;
          _showBrightnessUI = true;
        } else if (_isVolumeSide) {
          _dragStartVolume = c.value.volume;
          _previewVolume = _dragStartVolume;
          _showVolumeUI = true;
        }
        if (mounted) setState(() {});
      }
      return;
    }

    if (_dragAxis == 'h') {
      final seekMs = (dx * kSeekPerPixelMs).toInt();
      var target = _dragStartPosition + Duration(milliseconds: seekMs);
      final duration = c.value.duration;
      if (target < Duration.zero) target = Duration.zero;
      if (duration > Duration.zero && target > duration) target = duration;
      _previewPosition = target;
      if (mounted) setState(() {});
    } else if (_dragAxis == 'v') {
      final screenHeight = MediaQuery.of(context).size.height;
      final delta = -dy / (screenHeight * 0.6);

      if (_isBrightnessSide) {
        var newBrightness = (_dragStartBrightness + delta).clamp(0.0, 1.0);
        _previewBrightness = newBrightness;
        widget.onBrightnessChanged?.call(newBrightness);
        if (mounted) setState(() {});
      } else if (_isVolumeSide) {
        var newVolume = (_dragStartVolume + delta).clamp(0.0, 1.0);
        _previewVolume = newVolume;
        try {
          c.setVolume(newVolume);
        } catch (_) {}
        if (mounted) setState(() {});
      }
    }
  }

  void _onPanEnd(DragEndDetails d) {
    _endDrag();
  }

  void _onPanCancel() {
    _isDragging = false;
    _dragAxis = null;
    _showBrightnessUI = false;
    _showVolumeUI = false;
    if (mounted) setState(() {});
  }

  void _onHorizontalDragStart(DragStartDetails d) {
    final c = widget.controller;
    if (!_controllerReady) return;
    _isDragging = true;
    _dragAxis = 'h';
    _dragStartX = d.globalPosition.dx;
    _dragStartPosition = c.value.position;
    _previewPosition = c.value.position;
    _dragHideTimer?.cancel();
    HapticFeedback.selectionClick();
    if (mounted) setState(() {});
  }

  void _onHorizontalDragUpdate(DragUpdateDetails d) {
    if (!_isDragging || _dragAxis != 'h' || !_controllerReady) return;
    final c = widget.controller;
    final dx = d.globalPosition.dx - _dragStartX;
    final seekMs = (dx * kSeekPerPixelMs).toInt();
    var target = _dragStartPosition + Duration(milliseconds: seekMs);
    final dur = c.value.duration;
    if (target < Duration.zero) target = Duration.zero;
    if (dur > Duration.zero && target > dur) target = dur;
    _previewPosition = target;
    if (mounted) setState(() {});
  }

  void _onHorizontalDragEnd(DragEndDetails d) {
    _endDrag();
  }

  void _onHorizontalDragCancel() {
    _isDragging = false;
    _dragAxis = null;
    if (mounted) setState(() {});
  }

  void _endDrag() {
    final c = widget.controller;
    _verticalHideTimer?.cancel();

    if (_dragAxis == 'h') {
      if (_controllerReady) {
        try {
          final duration = c.value.duration;
          var target = _previewPosition;
          if (target < Duration.zero) target = Duration.zero;
          if (duration > Duration.zero && target > duration) target = duration;
          c.seekTo(target);
          HapticFeedback.lightImpact();
        } catch (e) {
          debugPrint('seekTo error: $e');
        }
      }
      _dragHideTimer?.cancel();
      _dragHideTimer = Timer(const Duration(milliseconds: 800), () {
        if (mounted) setState(() {});
      });
    } else if (_dragAxis == 'v') {
      _verticalHideTimer = Timer(const Duration(milliseconds: 600), () {
        if (mounted) {
          setState(() {
            _showBrightnessUI = false;
            _showVolumeUI = false;
          });
        }
      });
    }

    _isDragging = false;
    _dragAxis = null;
    if (mounted) setState(() {});
  }

  void _handleTap() {
    if (_isDragging) return;
    if (_pendingSingleTap) {
      _singleTapTimer?.cancel();
      _pendingSingleTap = false;
      _onDoubleTap();
    } else {
      _pendingSingleTap = true;
      _singleTapTimer = Timer(const Duration(milliseconds: kDoubleTapMs), () {
        if (_pendingSingleTap) {
          _pendingSingleTap = false;
          _onSingleTap();
        }
      });
    }
  }

  @override
  void dispose() {
    _singleTapTimer?.cancel();
    _dragHideTimer?.cancel();
    _verticalHideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final duration = _controllerReady ? c.value.duration : Duration.zero;
    final currentPosition = (_isDragging && _dragAxis == 'h')
        ? _previewPosition
        : (_controllerReady ? c.value.position : Duration.zero);

    return Stack(
      alignment: Alignment.center,
      children: [
        widget.child,
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) {
              _lastTapPosition = details.globalPosition;
            },
            onTap: _handleTap,
            onLongPressStart:
                widget.enableGestures ? (_) => _onLongPressStart() : null,
            onLongPressEnd:
                widget.enableGestures ? (_) => _onLongPressEnd() : null,
            onLongPressCancel:
                widget.enableGestures ? _onLongPressEnd : null,
            onPanStart: (widget.enableGestures && widget.enableVerticalDrag)
                ? _onPanStart
                : null,
            onPanUpdate: (widget.enableGestures && widget.enableVerticalDrag)
                ? _onPanUpdate
                : null,
            onPanEnd: (widget.enableGestures && widget.enableVerticalDrag)
                ? _onPanEnd
                : null,
            onPanCancel: (widget.enableGestures && widget.enableVerticalDrag)
                ? _onPanCancel
                : null,
            onHorizontalDragStart:
                (widget.enableGestures && !widget.enableVerticalDrag)
                    ? _onHorizontalDragStart
                    : null,
            onHorizontalDragUpdate:
                (widget.enableGestures && !widget.enableVerticalDrag)
                    ? _onHorizontalDragUpdate
                    : null,
            onHorizontalDragEnd:
                (widget.enableGestures && !widget.enableVerticalDrag)
                    ? _onHorizontalDragEnd
                    : null,
            onHorizontalDragCancel:
                (widget.enableGestures && !widget.enableVerticalDrag)
                    ? _onHorizontalDragCancel
                    : null,
            child: Container(color: Colors.transparent),
          ),
        ),
        if ((_isDragging && _dragAxis == 'h') ||
            (_dragHideTimer?.isActive == true &&
                _dragAxis == null &&
                _previewPosition != Duration.zero))
          Positioned(
            top: 48,
            left: 32,
            right: 32,
            child: _SeekPreviewBar(
              current: currentPosition,
              total: duration,
              offset: _previewPosition - _dragStartPosition,
            ),
          ),
        if (_showBrightnessUI && _isBrightnessSide && _dragAxis == 'v')
          _buildVerticalIndicator(
            icon: _brightnessIcon(),
            value: _previewBrightness,
            label: '亮度',
          ),
        if (_showVolumeUI && _isVolumeSide && _dragAxis == 'v')
          _buildVerticalIndicator(
            icon: _volumeIcon(),
            value: _previewVolume,
            label: '音量',
          ),
        if (_showSpeedBadge)
          IgnorePointer(
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
          ),
        if (_showHeart) const IgnorePointer(child: _FlyingHeart()),
        if (_showSeekFeedback)
          IgnorePointer(
            child: Positioned(
              top: 0,
              bottom: 0,
              left: _isSeekForward ? null : 0,
              right: _isSeekForward ? 0 : null,
              width: MediaQuery.of(context).size.width / 3,
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: _isSeekForward
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    end: _isSeekForward
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
                      _isSeekForward
                          ? Icons.fast_forward
                          : Icons.fast_rewind,
                      color: Colors.white,
                      size: 48,
                      shadows: [
                        Shadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 8),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isSeekForward ? '+10s' : '-10s',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        shadows: [
                          Shadow(color: Colors.black45, blurRadius: 4),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  IconData _brightnessIcon() {
    if (_previewBrightness <= 0.1) return Icons.brightness_low;
    if (_previewBrightness < 0.5) return Icons.brightness_medium;
    return Icons.brightness_high;
  }

  IconData _volumeIcon() {
    if (_previewVolume <= 0) return Icons.volume_off;
    if (_previewVolume < 0.5) return Icons.volume_down;
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
}

// ============================================================================
// 底部控制栏组件
// ============================================================================

class _FullscreenControls extends ConsumerStatefulWidget {
  final VideoPlayerController controller;
  final List<SubtitleTrack> subtitleTracks;
  final VoidCallback? onPrevEpisode;
  final VoidCallback? onNextEpisode;
  final bool isInFullscreen;
  final VoidCallback? onSeekStart;
  final VoidCallback? onSeekEnd;
  final VoidCallback? onSpeedTap;
  final VoidCallback? onQualityTap;
  final VoidCallback? onRatioTap;

  const _FullscreenControls({
    required this.controller,
    this.subtitleTracks = const <SubtitleTrack>[],
    this.onPrevEpisode,
    this.onNextEpisode,
    this.isInFullscreen = false,
    this.onSeekStart,
    this.onSeekEnd,
    this.onSpeedTap,
    this.onQualityTap,
    this.onRatioTap,
  });

  @override
  ConsumerState<_FullscreenControls> createState() =>
      _FullscreenControlsState();
}

class _FullscreenControlsState
    extends ConsumerState<_FullscreenControls> {
  late bool _lastIsPlaying;
  bool _isSeeking = false;
  Duration? _previewPosition;

  @override
  void initState() {
    super.initState();
    _lastIsPlaying = widget.controller.value.isPlaying;
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    final isPlaying = widget.controller.value.isPlaying;
    if (isPlaying != _lastIsPlaying) {
      _lastIsPlaying = isPlaying;
      ref.read(isPlayingProvider.notifier).state = isPlaying;
    }
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      final hours = d.inHours;
      final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return '$hours:$minutes:$seconds';
    }
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _togglePlay() {
    if (widget.controller.value.isPlaying) {
      widget.controller.pause();
    } else {
      widget.controller.play();
    }
    ref.read(isPlayingProvider.notifier).state =
        widget.controller.value.isPlaying;
  }

  Future<void> _showSubtitleMenu() async {
    if (widget.subtitleTracks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('未检测到可用字幕'), duration: Duration(seconds: 1)),
      );
      return;
    }
    final selectedSubId = ref.read(selectedSubtitleProvider);
    await showModalBottomSheet(
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
            ...widget.subtitleTracks.map((track) {
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
                  ref.read(selectedSubtitleProvider.notifier).state =
                      track.id;
                  Navigator.pop(context);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: controller,
            builder: (context, value, child) {
              final position = _isSeeking
                  ? (_previewPosition ?? value.position)
                  : value.position;
              final duration = value.duration;
              final progress = duration.inMilliseconds > 0
                  ? position.inMilliseconds / duration.inMilliseconds
                  : 0.0;
              return Row(
                children: [
                  Text(
                    '${_formatDuration(position)} / ${_formatDuration(duration)}',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Slider(
                      value: progress.clamp(0.0, 1.0),
                      onChangeStart: (v) {
                        setState(() {
                          _isSeeking = true;
                          _previewPosition = Duration(
                            milliseconds:
                                (v * duration.inMilliseconds).toInt(),
                          );
                        });
                        widget.onSeekStart?.call();
                        HapticFeedback.selectionClick();
                      },
                      onChanged: (v) {
                        setState(() {
                          _previewPosition = Duration(
                            milliseconds:
                                (v * duration.inMilliseconds).toInt(),
                          );
                        });
                      },
                      onChangeEnd: (v) {
                        final target = Duration(
                          milliseconds:
                              (v * duration.inMilliseconds).toInt(),
                        );
                        controller.seekTo(target);
                        setState(() {
                          _isSeeking = false;
                          _previewPosition = null;
                        });
                        widget.onSeekEnd?.call();
                        HapticFeedback.lightImpact();
                      },
                      activeColor: Theme.of(context).colorScheme.primary,
                      inactiveColor: Colors.white24,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.skip_previous, color: Colors.white),
              onPressed: widget.onPrevEpisode,
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
                  onPressed: _togglePlay,
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.skip_next, color: Colors.white),
              onPressed: widget.onNextEpisode,
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.subtitles, color: Colors.white, size: 22),
              onPressed: _showSubtitleMenu,
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
              onPressed: widget.onSpeedTap,
              tooltip: '倍速',
            ),
            IconButton(
              icon: const Icon(Icons.hd, color: Colors.white, size: 22),
              onPressed: widget.onQualityTap,
              tooltip: '清晰度',
            ),
            IconButton(
              icon: const Icon(Icons.aspect_ratio,
                  color: Colors.white, size: 22),
              onPressed: widget.onRatioTap,
              tooltip: '画面比例',
            ),
          ],
        ),
      ],
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
              shadows: [
                Shadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 4)),
              ],
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

enum _SettingsTab { speed, quality, ratio }
enum _AspectRatioMode { auto, contain, cover, fill, sixteenNine, fourThree }

class _QualityOption {
  final int level;
  final String label;
  final String desc;
  const _QualityOption(this.level, this.label, this.desc);
}
