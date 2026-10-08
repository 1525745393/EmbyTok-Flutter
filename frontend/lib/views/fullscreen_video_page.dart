// 全屏视频播放页：透明覆盖层
//
// 核心特性：
// 1. 基础交互：播放暂停、进度拖动、退出全屏、控制栏自动显隐、横竖屏切换
// 2. 标准手势：左侧调亮度、右侧调音量、左右滑动快进快退、长按倍速、双击步进
// 3. 设置面板：倍速切换、清晰度切换、画面比例设置
// 4. 系统适配：沉浸式状态栏、安全区、前后台切换、网络切换提醒
// 5. 状态反馈：缓冲、失败、手势操作的完整视觉反馈
// 6. 覆盖层架构：不做视频渲染，VideoPlayer 由底层 VideoPageItem 持续渲染，
//    本页为透明覆盖层，仅提供全屏控件和手势，避免 Texture 释放/重新注册导致黑屏
// 7. 系统亮度：使用 screen_brightness 实现全局亮度调节，退出时恢复原始亮度

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
import '../utils/logger.dart';
import '../utils/pip_util.dart';
import '../utils/safe_insets.dart';
import '../utils/system_gesture_exclusion.dart';
import '../widgets/video/episode_list_panel.dart';
import '../widgets/video/chapter_picker.dart';
import '../widgets/video/danmaku_overlay.dart';
import '../widgets/video/playback_info_osd.dart';
import '../widgets/video/subtitle_renderer.dart';
import '../widgets/video/subtitle_selector.dart';
import '../widgets/video/video_gesture_mixin.dart';
part 'fullscreen_widgets.dart';

// ===== UI 常量（避免魔法数字，提升可维护性）=====

/// 小字体（标签、辅助信息）
const double _kFontSizeSmall = 12;

/// 中等字体（按钮、列表项）
const double _kFontSizeBody = 13;

/// 大字体（标题、按钮文字）
const double _kFontSizeLarge = 16;

/// 超大字体（错误标题、手势提示）
const double _kFontSizeXLarge = 42;

/// 超小字体（时间戳、进度提示）
const double _kFontSizeTiny = 11;

/// 超小间距
const double _kSpacingXSmall = 4;

/// 小间距
const double _kSpacingSmall = 6;

/// 中间距
const double _kSpacingMedium = 8;

/// 大间距
const double _kSpacingLarge = 16;

/// 超大间距
const double _kSpacingXLarge = 20;

/// 全屏视频播放页
///
/// 作为覆盖层渲染在 VideoPageItem 的 Stack 中（非导航路由），
/// 避免 showGeneralDialog 的 ModalBarrier 干扰手势事件分发。
/// 退出时通过 [onExit] 回调通知父组件恢复 UI 状态。
class FullscreenVideoPage extends ConsumerStatefulWidget {
  const FullscreenVideoPage({super.key, this.onExit});

  /// 退出全屏时的回调，由父组件负责恢复 UI 状态
  final VoidCallback? onExit;

  @override
  ConsumerState<FullscreenVideoPage> createState() =>
      _FullscreenVideoPageState();
}

class _FullscreenVideoPageState extends ConsumerState<FullscreenVideoPage>
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
  void onDoubleTapCenter() {
    final item = ref.read(playbackStateProvider).item;
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
    final newBrightness = (_dragStartBrightness + delta).clamp(0.0, 1.0);
    _previewBrightnessNotifier.value = newBrightness;
    _setSystemBrightness(newBrightness);
  }

  @override
  void endDrag() {
    final wasVerticalBrightness = dragAxis == 'v' && !isVolumeSide;
    super.endDrag();
    if (wasVerticalBrightness) {
      _brightnessHideTimer?.cancel();
      _brightnessHideTimer = Timer(
        const Duration(milliseconds: kFullscreenBrightnessHideMs),
        () {
          if (!mounted) return;
          _showBrightnessUINotifier.value = false;
        },
      );
    }
  }

  @override
  void onLongPressEnd(LongPressEndDetails details) {
    super.onLongPressEnd(details);
    ref.read(playbackRateProvider.notifier).state = originalRate;
  }

  /// 长按取消：恢复播放速率并清理状态
  void _onLongPressCancel() {
    cancelLongPress();
    ref.read(playbackRateProvider.notifier).state = originalRate;
  }

  /// 拖动被系统手势抢占/中断：隐藏亮度反馈 UI（亮度值保持当前已调值）
  @override
  void onDragCancelled() {
    _brightnessHideTimer?.cancel();
    _showBrightnessUINotifier.value = false;
  }

  @override
  MediaItem? get currentItem => ref.read(playbackStateProvider).item;

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
  final ValueNotifier<bool> _showBrightnessUINotifier =
      ValueNotifier<bool>(false);
  final ValueNotifier<double> _previewBrightnessNotifier =
      ValueNotifier<double>(0.0);
  Timer? _brightnessHideTimer;

  // 功耗优化：状态缓存
  final ValueNotifier<bool> _bufferingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<int> _positionMsNotifier = ValueNotifier<int>(0);
  bool _lastIsPlaying = false;
  bool _lastHasError = false;
  bool _wasControllerReady = false;
  bool _lastHasSize = false;
  VideoPlayerController? _watchedController;
  int _lastPositionMs = -1;

  // 进度条拖动防抖处理器：拖动期间仅更新预览，结束时才 seek 一次
  // 顶层公开类，便于单元测试（参考 feed_autopause_test.dart 的可测试性设计）
  final SliderSeekHandler _sliderSeekHandler = SliderSeekHandler();

  // 字幕
  List<SubtitleCue> _subtitleCues = const <SubtitleCue>[];

  Timer? _resumePlayTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 同步竖屏已设置的画面比例，避免横屏选中态与渲染不一致
    final currentFit = ref.read(videoFitModeProvider);
    _aspectMode = switch (currentFit) {
      VideoFitMode.fit => _AspectRatioMode.contain,
      VideoFitMode.fill => _AspectRatioMode.cover,
      VideoFitMode.stretch => _AspectRatioMode.fill,
      VideoFitMode.sixteenNine => _AspectRatioMode.sixteenNine,
      VideoFitMode.fourThree => _AspectRatioMode.fourThree,
    };

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

    // 全屏排除边缘返回手势开关变化时，对已打开的全屏页即时生效
    ref.listen<bool>(fullscreenGestureBackExcludedProvider, (previous, next) {
      if (next != previous && mounted) {
        SystemGestureExclusion.setFullscreenExclusion(next);
      }
    });

    // 主动加载当前选中的字幕（避免 listen 因值未变而不触发）
    // 场景：从 feed 模式进入全屏，selectedSubtitleProvider 已有值
    // 如果为 null，自动匹配默认字幕轨道
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final currentSub = ref.read(selectedSubtitleProvider);
      if (currentSub != null) {
        _loadSubtitle(currentSub);
      } else {
        _autoLoadDefaultSubtitle();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctrl = ref.read(currentVideoControllerProvider);
      if (ctrl != null && ctrl.value.isInitialized) {
        final size = ctrl.value.size;
        final isLandscapeVideo = size.width >= size.height;
        _orientationPref = isLandscapeVideo
            ? _OrientationPref.landscape
            : _OrientationPref.sensor;
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

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (!_isRotating && mounted) {
      _isRotating = true;
      _hideTimer?.cancel();
    }
    _rotateEndTimer?.cancel();
    _rotateEndTimer = Timer(
      const Duration(milliseconds: kFullscreenRotateEndMs),
      () {
        _isRotating = false;
        if (mounted) {
          if (_controlsVisible && !_isScreenLocked && !_showSettingsPanel) {
            _startHideTimer();
          }
          // 旋转结束：屏幕尺寸已变，按新尺寸重设边缘手势排除区域
          SystemGestureExclusion.setFullscreenExclusion(
            ref.read(fullscreenGestureBackExcludedProvider),
          );
          setState(() {});
        }
      },
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
      } catch (_) {
        // 操作失败不影响主流程，静默处理
      }
    }

    if (!wasForeground && isForeground && wasPlaying) {
      _resumePlayTimer?.cancel();
      _resumePlayTimer = Timer(
        const Duration(milliseconds: kFullscreenResumePlayDelayMs),
        () {
          if (mounted) {
            try {
              controller?.play();
            } catch (_) {
              // 操作失败不影响主流程，静默处理
            }
          }
        },
      );
    }
  }

  // 异步加载字幕
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
    _positionMsNotifier.dispose();
    _showBrightnessUINotifier.dispose();
    _previewBrightnessNotifier.dispose();

    if (_originalBrightness != null) {
      try {
        ScreenBrightness().resetScreenBrightness();
      } catch (e) {
        AppLogger.warn('重置屏幕亮度失败', data: {'error': e.toString()});
      }
    }

    // 退出全屏：恢复为沉浸式模式（FeedView 也是沉浸式的）
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    // 清除边缘手势排除，恢复系统边缘返回手势
    SystemGestureExclusion.setFullscreenExclusion(false);
    ref.read(isFullscreenProvider.notifier).state = false;

    super.dispose();
  }

  int? _getCurrentIndex() {
    final items = ref.read(videoListProvider).items;
    final current = ref.read(playbackStateProvider).item;
    if (current == null) return null;
    for (int i = 0; i < items.length; i++) {
      if (items[i].id == current.id) return i;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(currentVideoControllerProvider);
    final playingItem = ref.watch(playbackStateProvider.select((s) => s.item));
    final items = ref.watch(videoListProvider.select((s) => s.items));

    bool isControllerReady;
    bool hasError;
    bool hasValidSize;
    if (controller != null) {
      final v = controller.value;
      // isControllerReady 不再检查尺寸，确保 VideoPlayer 能及时构建
      isControllerReady = v.isInitialized && !v.hasError;
      hasError = v.hasError;
      hasValidSize = !v.size.isEmpty;
    } else {
      isControllerReady = false;
      hasError = false;
      hasValidSize = false;
    }

    final mediaOrientation = MediaQuery.orientationOf(context);
    final isActuallyLandscape = mediaOrientation == Orientation.landscape;
    final gesturesEnabled =
        !_isScreenLocked && !_showSettingsPanel && !_controlsVisible;

    // 直接返回 Stack（非 Scaffold），因为本页作为覆盖层渲染在 VideoPageItem 的 Stack 中，
    // 不需要额外的 Scaffold 包装，避免导航 UI 干扰
    return Stack(
      key: ValueKey('fs-stack-$_retryKey'),
      children: [
        // 手势层：透明覆盖，接收所有触摸事件
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: handleTapDown,
            onTap: handleTap,
            onLongPressStart:
                gesturesEnabled && controller != null ? onLongPressStart : null,
            onLongPressEnd:
                gesturesEnabled && controller != null ? onLongPressEnd : null,
            onLongPressCancel: gesturesEnabled && controller != null
                ? _onLongPressCancel
                : null,
            onPanStart: gesturesEnabled ? onPanStart : null,
            onPanUpdate: gesturesEnabled ? onPanUpdate : null,
            onPanEnd: gesturesEnabled ? onPanEnd : null,
            onPanCancel: gesturesEnabled ? onPanCancel : null,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 覆盖层架构：不做视频渲染，VideoPlayer 由底层 VideoPageItem 持续渲染
                // 本页为透明覆盖层，仅提供全屏控件和手势

                // 错误状态：controller 有错误时显示
                if (hasError && controller != null)
                  _buildErrorState(controller),

                // 加载指示器仅在控制器未初始化时显示
                // 已初始化但尺寸为空时，VideoPlayer 会用占位尺寸渲染，无需显示加载指示器
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
                          width: kFullscreenLoadingIndicatorSize,
                          height: kFullscreenLoadingIndicatorSize,
                          child: CircularProgressIndicator(
                            color: Colors.white70,
                            strokeWidth: kFullscreenLoadingStrokeWidth,
                          ),
                        ),
                      );
                    },
                  ),

                // 播放信息 OSD（PRD P1：多播放器引擎/编码/分辨率显示，左上角半透明）
                if (isControllerReady && !hasError && playingItem != null)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: PlaybackInfoOsd(item: playingItem),
                  ),

                // 弹幕层（PRD P1：danmaku_overlay 接入横屏）
                if (isControllerReady &&
                    !hasError &&
                    ref.watch(danmakuEnabledProvider))
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DanmakuOverlay(
                        positionMs: _positionMsNotifier,
                        // TODO: 接入 dandanplay_api.dart 根据影片名拉取弹幕
                        danmakus: const [],
                        enabled: true,
                      ),
                    ),
                  ),

                // 字幕渲染层
                if (isControllerReady &&
                    !hasError &&
                    _subtitleCues.isNotEmpty &&
                    ref.watch(selectedSubtitleProvider) != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: kFullscreenSubtitleBottom,
                    child: RepaintBoundary(
                      child: ValueListenableBuilder<int>(
                        valueListenable: _positionMsNotifier,
                        builder: (_, ms, __) {
                          return SubtitleRenderer(
                            position: Duration(milliseconds: ms),
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

        // 顶部栏：尺寸有效时才显示，避免画面未就绪时显示控制栏
        if (_controlsVisible &&
            isControllerReady &&
            hasValidSize &&
            !_isScreenLocked)
          _buildTopBar(playingItem, isActuallyLandscape),

        // 底部控制栏：尺寸有效时才显示，避免画面未就绪时显示控制栏
        if (_controlsVisible &&
            isControllerReady &&
            hasValidSize &&
            controller != null &&
            !_isScreenLocked)
          _buildBottomBar(controller, playingItem, items),

        // 设置面板：尺寸有效时才显示，避免画面未就绪时显示设置面板
        if (_showSettingsPanel &&
            isControllerReady &&
            hasValidSize &&
            controller != null &&
            !_isScreenLocked)
          _buildSettingsPanel(controller, playingItem),

        // 锁屏 UI
        if (_isScreenLocked) _buildLockUI(),

        // 网络状态 Toast
        if (_networkToastMessage != null) _buildNetworkToast(),

        // 手势反馈 UI
        ValueListenableBuilder<Duration>(
          valueListenable: previewPositionNotifier,
          builder: (context, previewPos, _) {
            if (!isDragging || dragAxis != 'h' || controller == null) {
              return const SizedBox.shrink();
            }
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
            if (!_showBrightnessUINotifier.value ||
                isVolumeSide ||
                dragAxis != 'v') {
              return const SizedBox.shrink();
            }
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
            if (!showVolumeUINotifier.value ||
                !isVolumeSide ||
                dragAxis != 'v') {
              return const SizedBox.shrink();
            }
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
                      fontSize: _kFontSizeXLarge,
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
                      Colors.white.withValues(alpha: 0.15),
                      Colors.transparent
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSeekForward ? Icons.fast_forward : Icons.fast_rewind,
                      color: Colors.white,
                      size: 48,
                    ),
                    const SizedBox(height: _kSpacingXSmall),
                    Text(
                      '${isSeekForward ? '+' : '-'}${seekFeedbackCount * kDoubleTapSeekStepSec}s',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: _kFontSizeLarge,
                        fontWeight: FontWeight.w700,
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

  IconData _tabIcon(_SettingsTab tab) {
    switch (tab) {
      case _SettingsTab.speed:
        return Icons.speed;
      case _SettingsTab.ratio:
        return Icons.aspect_ratio;
      case _SettingsTab.subtitle:
        return Icons.subtitles;
      case _SettingsTab.audio:
        return Icons.audiotrack;
      case _SettingsTab.quality:
        return Icons.hd;
    }
  }

  IconData _brightnessIconFor(double value) {
    if (value <= kBrightnessLowThreshold) return Icons.brightness_low;
    if (value < kVolumeBrightnessMidThreshold) return Icons.brightness_medium;
    return Icons.brightness_high;
  }

  IconData _volumeIconFor(double value) {
    if (value <= 0) return Icons.volume_off;
    if (value < kVolumeBrightnessMidThreshold) return Icons.volume_down;
    return Icons.volume_up;
  }

  // === 合并自 fullscreen_controls.dart ===
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

  /// PRD P1：是否有下一集（播放列表中还有后续项）
  bool _hasNext() {
    final idx = _getCurrentIndex();
    if (idx == null) return false;
    final list = ref.read(playbackListProvider).items;
    return idx < list.length - 1;
  }

  /// PRD P1：跳转到下一集
  void _jumpToNext() {
    final idx = _getCurrentIndex();
    if (idx == null) return;
    final list = ref.read(playbackListProvider).items;
    if (idx >= list.length - 1) return;
    ref.read(feedViewPageJumpRequestProvider.notifier).state = idx + 1;
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

  // === 合并自 fullscreen_builders.dart ===
Widget _buildErrorState(VideoPlayerController? controller) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.white70, size: 56),
          const SizedBox(height: _kSpacingLarge),
          const Text(
            '视频加载失败',
            style: TextStyle(color: Colors.white70, fontSize: _kFontSizeLarge),
          ),
          const SizedBox(height: _kSpacingMedium),
          Text(
            controller?.value.errorDescription ?? '网络错误或资源不可用',
            style: const TextStyle(
                color: Colors.white54, fontSize: _kFontSizeBody),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: _kSpacingXLarge),
          TextButton.icon(
            onPressed: _retryVideo,
            icon: const Icon(Icons.refresh, size: 20),
            label:
                const Text('重试', style: TextStyle(fontSize: _kFontSizeLarge)),
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
      // 沉浸式（immersiveSticky）下 MediaQuery.padding 被系统置 0，SafeArea 失效；
      // 改用 SafeInsets 取物理刘海/挖孔避让值，确保横屏左右刘海与顶部刘海均被避开
      child: Padding(
        padding: EdgeInsets.only(
          left: SafeInsets.leftOf(context),
          top: SafeInsets.topOf(context),
          right: SafeInsets.rightOf(context),
        ),
        child: AnimatedOpacity(
          opacity: _controlsVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: kToolbarAnimMs),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.7),
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
                  onPressed: () {
                    widget.onExit?.call();
                    Navigator.of(context).pop();
                  },
                  tooltip: '退出全屏',
                ),
                if (playingItem != null)
                  Expanded(
                    child: Text(
                      playingItem.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: _kFontSizeLarge,
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
                // PRD P1：睡眠定时器入口（与竖屏一致）
                IconButton(
                  icon: const Icon(Icons.bedtime, color: Colors.white, size: 24),
                  onPressed: _showSleepTimerMenu,
                  tooltip: '睡眠定时器',
                ),
                // PRD P0：画中画 PiP 按钮
                IconButton(
                  icon: const Icon(Icons.picture_in_picture_alt,
                      color: Colors.white, size: 24),
                  onPressed: () => PipUtil.enterPip(),
                  tooltip: '画中画',
                ),
                IconButton(
                  icon:
                      const Icon(Icons.settings, color: Colors.white, size: 24),
                  onPressed: () => _toggleSettingsPanel(_SettingsTab.speed),
                  tooltip: '设置',
                ),
                IconButton(
                  icon: const Icon(Icons.lock_open,
                      color: Colors.white, size: 24),
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
    // 绑定最新 controller 的 seekTo，确保拖动结束时 seek 到当前 controller
    _sliderSeekHandler.seekTo = controller.seekTo;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      // 沉浸式（immersiveSticky）下 MediaQuery.padding 被系统置 0，SafeArea 失效；
      // 改用 SafeInsets 取物理避让值，确保底部进度条不被手势条遮挡、横屏左右不被侧边刘海遮挡
      child: Padding(
        padding: EdgeInsets.only(
          left: SafeInsets.leftOf(context),
          right: SafeInsets.rightOf(context),
          bottom: SafeInsets.bottomOf(context),
        ),
        child: AnimatedOpacity(
          opacity: _controlsVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: kToolbarAnimMs),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.7),
                ],
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 帧预览缩略图：拖动进度条时在进度条上方显示
                // 使用 throttledPreviewMs 避免每帧发 HTTP 请求（1s 节流）
                if (_sliderSeekHandler.seekPreviewMs != null)
                  _buildFramePreview(context, _sliderSeekHandler.throttledPreviewMs!),
                ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: controller,
                  builder: (context, value, child) {
                    final position = value.position;
                    final duration = value.duration;
                    final progress = duration.inMilliseconds > 0
                        ? position.inMilliseconds / duration.inMilliseconds
                        : 0.0;
                    // 拖动期间显示预览时间，否则显示真实播放位置
                    final previewMs = _sliderSeekHandler.seekPreviewMs;
                    final displayPosition = previewMs != null
                        ? Duration(milliseconds: previewMs.round())
                        : position;
                    return Row(
                      children: [
                        Text(
                          _formatDuration(displayPosition),
                          style: const TextStyle(
                              color: Colors.white, fontSize: _kFontSizeSmall),
                        ),
                        const SizedBox(width: _kSpacingMedium),
                        Expanded(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // PRD P1：缓冲进度指示（Slider 下层叠加灰色缓冲条）
                              ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: duration.inMilliseconds > 0 &&
                                          value.buffered.isNotEmpty
                                      ? value.buffered.last.end.inMilliseconds /
                                          duration.inMilliseconds
                                      : 0.0,
                                  minHeight: 2,
                                  backgroundColor: Colors.white12,
                                  valueColor:
                                      const AlwaysStoppedAnimation(Colors.white38),
                                ),
                              ),
                              Slider(
                                value: progress.clamp(0.0, 1.0),
                                // 拖动开始：标记进入拖动状态，初始化预览
                                onChangeStart: (_) {
                                  _sliderSeekHandler.startDrag();
                                  setState(() {});
                                },
                                // 拖动中：仅更新预览时间，不发起 seek（防抖核心）
                                onChanged: (v) {
                                  setState(() {
                                    _sliderSeekHandler.updateDrag(v, duration);
                                  });
                                },
                                // 拖动结束：触发一次 seekTo 并清除预览
                                onChangeEnd: (v) {
                                  _sliderSeekHandler.endDrag(v, duration);
                                  setState(() {});
                                },
                                activeColor:
                                    Theme.of(context).colorScheme.primary,
                                inactiveColor: Colors.transparent,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: _kSpacingMedium),
                        Text(
                          _formatDuration(duration),
                          style: const TextStyle(
                              color: Colors.white70, fontSize: _kFontSizeSmall),
                        ),
                      ],
                    );
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon:
                          const Icon(Icons.skip_previous, color: Colors.white),
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
                    // PRD P1：下一集按钮（与上一集对称）
                    IconButton(
                      icon: const Icon(Icons.skip_next, color: Colors.white),
                      onPressed: _hasNext() ? _jumpToNext : null,
                    ),
                    const Spacer(),
                    // 剧集列表按钮（仅剧集显示）
                    if (playingItem?.seriesId != null)
                      IconButton(
                        icon: const Icon(Icons.playlist_play,
                            color: Colors.white, size: 22),
                        onPressed: () => _showEpisodeList(playingItem!),
                        tooltip: '剧集列表',
                      ),
                    IconButton(
                      icon: const Icon(Icons.subtitles,
                          color: Colors.white, size: 22),
                      onPressed: playingItem != null
                          ? () => _showSubtitleMenu(playingItem)
                          : null,
                      tooltip: '字幕',
                    ),
                    // PRD P1：章节导航按钮（有章节时才显示）
                    if (playingItem?.chapters != null &&
                        playingItem!.chapters!.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.list,
                            color: Colors.white, size: 22),
                        onPressed: () => _showChapterPicker(playingItem, controller),
                        tooltip: '章节',
                      ),
                    IconButton(
                      icon: ValueListenableBuilder<VideoPlayerValue>(
                        valueListenable: controller,
                        builder: (context, value, child) {
                          return Text(
                            '${value.playbackSpeed.toStringAsFixed(1)}x',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: _kFontSizeBody,
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

  Widget _buildSettingsPanel(VideoPlayerController controller, MediaItem? playingItem) {
    // 沉浸式下 SafeArea 失效（padding 被置 0），改用 SafeInsets 避让物理刘海
    final safeInsets = SafeInsets.of(context);
    return Positioned(
      right: kSpacingLg + safeInsets.right,
      bottom: kFullscreenSettingsPanelBottom + safeInsets.bottom,
      child: AnimatedOpacity(
        opacity: _showSettingsPanel ? 1.0 : 0.0,
        duration: const Duration(milliseconds: kToolbarAnimMs),
        child: Container(
          width: kFullscreenSettingsPanelWidth,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(kRadiusLg),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSettingsTabBar(),
              const Divider(color: Colors.white24, height: 1),
              _buildSettingsContent(controller, playingItem),
            ],
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

  Widget _buildSettingsContent(
      VideoPlayerController controller, MediaItem? playingItem) {
    switch (_settingsTab) {
      case _SettingsTab.speed:
        return _buildSpeedList(controller);
      case _SettingsTab.ratio:
        return _buildRatioList();
      case _SettingsTab.subtitle:
        return _buildSubtitleList(playingItem);
      case _SettingsTab.audio:
        return _buildAudioTrackList(playingItem);
      case _SettingsTab.quality:
        return _buildQualityList();
    }
  }

  /// 字幕列表（PRD P1：横屏设置面板内嵌字幕轨道选择）
  Widget _buildSubtitleList(MediaItem? playingItem) {
    final tracks = playingItem?.subtitleTracks ?? [];
    final selectedId = ref.watch(selectedSubtitleProvider);
    if (tracks.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('本片无字幕轨道', style: TextStyle(color: Colors.white54)),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 关闭字幕选项
        _SettingsListItem(
          label: '关闭字幕',
          selected: selectedId == null,
          onTap: () {
            ref.read(subtitleSettingsProvider.notifier).setLanguage('');
            ref.read(selectedSubtitleProvider.notifier).state = null;
            _startHideTimer();
          },
        ),
        ...tracks.map((t) => _SettingsListItem(
              label: t.displayName,
              selected: t.id == selectedId,
              onTap: () {
                if (t.language != 'local') {
                  ref
                      .read(subtitleSettingsProvider.notifier)
                      .setLanguage(t.language);
                }
                ref.read(selectedSubtitleProvider.notifier).state = t.id;
                _startHideTimer();
              },
            )),
      ],
    );
  }

  /// 音轨列表（PRD P1：横屏设置面板内嵌音轨选择，点击切换）
  Widget _buildAudioTrackList(MediaItem? playingItem) {
    final tracks = playingItem?.audioTracks ?? [];
    if (tracks.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('本片无多音轨', style: TextStyle(color: Colors.white54)),
      );
    }
    final selectedIdx = ref.watch(selectedAudioStreamIndexProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: tracks
          .map((t) => _SettingsListItem(
                label: t.displayTitle ?? t.language ?? '音轨 ${t.index}',
                selected: t.index == selectedIdx,
                onTap: () {
                  // 切换音轨：player_widget 监听 selectedAudioStreamIndexProvider 重建 controller
                  ref.read(selectedAudioStreamIndexProvider.notifier).state = t.index;
                  _startHideTimer();
                },
              ))
          .toList(),
    );
  }

  /// 清晰度列表（PRD P1：横屏设置面板内嵌码率切换）
  Widget _buildQualityList() {
    // TODO: 接入 quality_button.dart 的码率切换逻辑
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Text('自动（清晰度切换接入中）', style: TextStyle(color: Colors.white70)),
    );
  }

  Widget _buildSpeedList(VideoPlayerController controller) {
    // 与竖屏统一：0.25–2.0 七档（PRD P1 倍速档位不一致）
    const rates = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    final currentRate = ref.watch(playbackRateProvider);
    return Column(
      children: rates.map((rate) {
        final selected = (rate - currentRate).abs() < kPlaybackRateTolerance;
        return _SettingsListItem(
          label:
              '${rate.toStringAsFixed(rate.truncateToDouble() == rate ? 0 : 2)}x',
          selected: selected,
          onTap: () {
            // 统一控制通道：三引擎（EXO/MPV/VLC）同步倍速
            // 横屏为覆盖层，controller 参数是隐藏的 EXO 实例，
            // 必须走 currentPlayerControlProvider 才能作用于 MPV/VLC
            ref.read(currentPlayerControlProvider)?.setRate(rate);
            // 兼容：直接调 EXO controller 作为 fallback
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
            // 通过全局 Provider 通知底层 VideoPlayerWidget 应用画面比例
            // 横屏为覆盖层，视频由底层渲染，必须经 provider 才能生效
            final fitMode = switch (m.$1) {
              _AspectRatioMode.auto => VideoFitMode.fit,
              _AspectRatioMode.contain => VideoFitMode.fit,
              _AspectRatioMode.cover => VideoFitMode.fill,
              _AspectRatioMode.fill => VideoFitMode.stretch,
              _AspectRatioMode.sixteenNine => VideoFitMode.sixteenNine,
              _AspectRatioMode.fourThree => VideoFitMode.fourThree,
            };
            ref.read(videoFitModeProvider.notifier).setMode(fitMode);
            _startHideTimer();
          },
        );
      }).toList(),
    );
  }

  Widget _buildLockUI() {
    // 沉浸式下 SafeArea 失效（padding 被置 0），改用 SafeInsets 避让物理刘海
    final safeInsets = SafeInsets.of(context);
    return Positioned(
      left: 12 + safeInsets.left,
      top: safeInsets.top,
      bottom: safeInsets.bottom,
      child: Center(
        child: GestureDetector(
          onTap: _unlockScreen,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white24, width: 1),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, color: Colors.white, size: 28),
                SizedBox(height: _kSpacingSmall),
                Text(
                  '点击\n解锁',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: _kFontSizeTiny,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNetworkToast() {
    return Positioned(
      // 沉浸式下 MediaQuery.padding.top 归零，改用 SafeInsets.topOf 取物理刘海高度，
      // 保证 Toast 在刘海下方 60px 处显示，不被遮挡
      top: SafeInsets.topOf(context) + 60,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline, color: Colors.white, size: 18),
              const SizedBox(width: _kSpacingMedium),
              Text(
                _networkToastMessage ?? '',
                style: const TextStyle(
                    color: Colors.white, fontSize: _kFontSizeBody),
              ),
            ],
          ),
        ),
      ),
    );
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
              const SizedBox(height: _kSpacingMedium),
              SizedBox(
                width: kFullscreenVolumeBarWidth,
                child: LinearProgressIndicator(
                  value: value,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: _kSpacingXSmall),
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

  /// PRD P1：章节导航弹窗（复用竖屏 chapter_picker.dart）
  void _showChapterPicker(MediaItem item, VideoPlayerController controller) {
    showChapterPicker(
      context: context,
      chapters: item.chapters ?? [],
      onSeek: (seconds) {
        controller.seekTo(Duration(seconds: seconds.round()));
      },
    );
  }

  /// PRD P1：睡眠定时器菜单（与竖屏一致）
  Future<void> _showSleepTimerMenu() async {
    final current = ref.read(sleepTimerProvider);
    const minutes = [15, 30, 45, 60];
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('睡眠定时器',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            if (current.isActive)
              ListTile(
                leading: const Icon(Icons.timer_off, color: Colors.red),
                title: Text(current.stopAfterCurrent
                    ? '当前结束后暂停（已设置）'
                    : '取消（剩余 ${current.remaining?.inMinutes ?? 0}:${((current.remaining?.inSeconds ?? 0) % 60).toString().padLeft(2, '0')}）'),
                onTap: () {
                  ref.read(sleepTimerProvider.notifier).cancel();
                  Navigator.pop(context);
                },
              ),
            ...minutes.map((m) => ListTile(
                  leading: Icon(Icons.bedtime,
                      color: Theme.of(context).colorScheme.primary),
                  title: Text('$m 分钟后暂停'),
                  onTap: () {
                    ref
                        .read(sleepTimerProvider.notifier)
                        .start(Duration(minutes: m));
                    Navigator.pop(context);
                  },
                )),
            ListTile(
              leading: Icon(Icons.stop_circle,
                  color: Theme.of(context).colorScheme.primary),
              title: const Text('当前视频结束后暂停'),
              onTap: () {
                ref.read(sleepTimerProvider.notifier).setStopAfterCurrent();
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _showSubtitleMenu(MediaItem item) async {
    final selectedSubId = ref.read(selectedSubtitleProvider);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SubtitleSelector(
        tracks: item.subtitleTracks,
        selectedTrackId: selectedSubId,
        onSelected: (track) {
          if (track == null) {
            ref.read(subtitleSettingsProvider.notifier).setLanguage('');
            ref.read(selectedSubtitleProvider.notifier).state = null;
          } else {
            // 本地字幕不保存语言偏好（语言代码为 'local'）
            if (track.language != 'local') {
              ref
                  .read(subtitleSettingsProvider.notifier)
                  .setLanguage(track.language);
            }
            ref.read(selectedSubtitleProvider.notifier).state = track.id;
          }
        },
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }

  /// 帧预览缩略图（多播放器 PRD：拖动进度条时显示 Emby trickplay 缩略图）
  ///
  /// Emby API: /Items/{itemId}/Images/Playback/{width}?mediaSourceId=...&offset={ticks}
  /// 服务端未配置 trickplay 时返回 404，错误图占位。
  Widget _buildFramePreview(BuildContext context, double previewMs) {
    final item = currentItem;
    final auth = ref.read(authProvider);
    if (item == null || auth.embyServerUrl == null || auth.token == null) {
      return const SizedBox.shrink();
    }
    final msId = item.primaryMediaSource?.id;
    if (msId == null) return const SizedBox.shrink();

    // 1 tick = 100ns，毫秒转 tick = ms * 10000
    final offsetTicks = (previewMs * 10000).round();
    final url =
        '${auth.embyServerUrl}/Items/${item.id}/Images/Playback/288?mediaSourceId=$msId&offset=$offsetTicks&X-Emby-Token=${auth.token}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      width: 160,
      height: 90,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        url,
        fit: BoxFit.cover,
        headers: const {'Accept': 'image/*'},
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.image_not_supported_outlined,
              color: Colors.white24, size: 24),
        ),
      ),
    );
  }
}

// ============================================================================
// 内部辅助组件
// ============================================================================
class SliderSeekHandler {
  /// 当前 seek 回调；widget 在每次 _buildBottomBar 时用最新 controller 绑定。
  /// 设为可空以容忍 controller 尚未就绪的场景。
  void Function(Duration target)? seekTo;

  // 拖动进度条时的预览位置（毫秒），null 表示未在拖动。
  // 拖动期间用此值显示预览时间，避免每帧 seek。
  double? _seekPreviewMs;

  /// 当前预览位置（毫秒）；null 表示未在拖动，UI 应回退到真实 position。
  double? get seekPreviewMs => _seekPreviewMs;

  // 帧预览节流：仅当预览位置变化超过 1 秒时才生成新缩略图 URL，
  // 避免拖动时每帧发 HTTP 请求。
  double? _lastThrottledPreviewMs;

  /// 帧预览用的节流位置（毫秒），与 [seekPreviewMs] 偏差 < 1s 时保持不变。
  double? get throttledPreviewMs => _lastThrottledPreviewMs ?? _seekPreviewMs;

  /// 拖动开始：标记进入拖动状态。
  void startDrag() {
    _seekPreviewMs = 0.0;
    _lastThrottledPreviewMs = 0.0;
  }

  /// 拖动中：仅更新预览位置，不调用 seekTo。
  void updateDrag(double v, Duration duration) {
    if (duration.inMilliseconds <= 0) return;
    _seekPreviewMs = v * duration.inMilliseconds;
    // 帧预览节流：位置变化超过 1 秒才更新缩略图 URL
    final last = _lastThrottledPreviewMs;
    if (last == null || (_seekPreviewMs! - last).abs() > 1000) {
      _lastThrottledPreviewMs = _seekPreviewMs;
    }
  }

  /// 拖动结束：清除预览状态，并触发一次 seekTo。
  /// duration 无效或 seekTo 未绑定时安全跳过。
  void endDrag(double v, Duration duration) {
    _seekPreviewMs = null;
    _lastThrottledPreviewMs = null;
    final fn = seekTo;
    if (fn == null || duration.inMilliseconds <= 0) return;
    final target = Duration(
      milliseconds: (v * duration.inMilliseconds).round(),
    );
    fn(target);
  }
}
