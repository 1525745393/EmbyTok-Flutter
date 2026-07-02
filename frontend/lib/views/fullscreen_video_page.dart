// 全屏视频播放页：复用全局 currentVideoControllerProvider
//
// 核心设计：方案 A —— 全屏页不创建新的 VideoPlayerController，
// 直接从 currentVideoControllerProvider 读取同一个 controller。
//
// 优势：
// - 零额外内存（不创建新 native player）
// - 进度 100% 不丢（小屏和全屏是同一个 controller）
// - 零额外加载（不需要重新加载视频源）
// - 进入/退出全屏无白屏/缓冲
//
// 交互功能：
// - 播放/暂停、上/下一集、进度拖动、控制层 4s 自动隐藏
// - 手势：单击切换控制层、双击左右 1/3 快进/快退 10s、长按 2x 倍速、
//         水平拖动 seek、右侧垂直滑动调音量
// - 锁屏防误触（隐藏所有控件）
// - 横竖屏切换按钮
// - 缓冲/错误状态反馈
//
// 配合：VideoPageItem._onVideoChanged 持续同步 position 到
// currentPositionProvider，全局任意时刻可读到精确进度。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../widgets/gesture_overlay.dart';
import '../widgets/video_controls.dart';

/// 全屏视频播放页
///
/// 用法：在小屏任意位置调用 `Navigator.push(context,
/// MaterialPageRoute(builder: (_) => const FullscreenVideoPage()))`
/// 即可进入全屏。退出全屏请用系统返回键、ESC 或顶部退出按钮。
class FullscreenVideoPage extends ConsumerStatefulWidget {
  const FullscreenVideoPage({super.key});

  @override
  ConsumerState<FullscreenVideoPage> createState() => _FullscreenVideoPageState();
}

class _FullscreenVideoPageState extends ConsumerState<FullscreenVideoPage> {
  // 控制层（VideoControls）的显隐
  bool _controlsVisible = true;
  // 自动隐藏计时器
  Timer? _hideTimer;
  // 锁屏状态：锁屏时只显示解锁按钮，手势和控制层全部禁用
  bool _isScreenLocked = false;
  // 横竖屏模式：true=横屏，false=竖屏
  bool _isLandscape = true;
  // 重试触发标记（用于通知 VideoPlayerWidget 重新初始化）
  int _retryKey = 0;

  @override
  void initState() {
    super.initState();
    _applyOrientations();
    _applySystemUI();
    // 标记全局全屏状态
    Future.microtask(() {
      if (mounted) {
        ref.read(isFullscreenProvider.notifier).state = true;
      }
    });
    // 默认 4 秒后自动隐藏控制层
    _startHideTimer();
  }

  // 应用屏幕方向
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

  // 应用沉浸式系统 UI
  void _applySystemUI() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [],
    );
    // 全面屏手势适配：全屏视频是黑底，必须把状态栏 / 导航栏图标改为浅色，
    // 否则 white-on-white 不可见；同时背景透明让黑底透出。
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
  void dispose() {
    _hideTimer?.cancel();
    // 退出全屏：恢复竖屏 + 恢复系统 UI
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    // 直接写 isFullscreenProvider（不通过 Future.microtask：
    // dispose 内 mounted 已为 false，Future.microtask 中 mounted 检查会让 state=false 永远不生效）
    ref.read(isFullscreenProvider.notifier).state = false;
    super.dispose();
  }

  // 自动隐藏控制层（4 秒无操作）
  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && !_isScreenLocked) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  // 切换控制层显隐
  void _toggleControls() {
    if (_isScreenLocked) return; // 锁屏时不切换控制层
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) {
      _startHideTimer();
    } else {
      _hideTimer?.cancel();
    }
  }

  // 退出全屏
  void _exitFullscreen() {
    Navigator.of(context).pop();
  }

  // 切换横竖屏
  void _toggleOrientation() {
    setState(() => _isLandscape = !_isLandscape);
    _applyOrientations();
  }

  // 锁屏
  void _lockScreen() {
    setState(() {
      _isScreenLocked = true;
      _controlsVisible = false;
    });
    _hideTimer?.cancel();
    HapticFeedback.mediumImpact();
  }

  // 解锁
  void _unlockScreen() {
    setState(() => _isScreenLocked = false);
    _startHideTimer();
    HapticFeedback.mediumImpact();
  }

  // 重试加载视频
  void _retryVideo() {
    final controller = ref.read(currentVideoControllerProvider);
    if (controller != null) {
      // 尝试重新播放
      try {
        controller.play();
      } catch (_) {}
      // 递增 retryKey 触发 VideoPlayerWidget 重建
      setState(() => _retryKey++);
    }
  }

  // 计算 onNextEpisode / onPrevEpisode：复用 FeedView._jumpToNextEpisode 逻辑
  // 全屏页不能直接调用 FeedView 的 _pageController，通过 feedViewPageJumpRequestProvider 通信
  VoidCallback? _computeOnNextEpisode(MediaItem? playingItem, List<MediaItem> items) {
    if (playingItem == null) return null;
    final currentIndex = items.indexWhere((i) => i.id == playingItem.id);
    if (currentIndex < 0) return null;

    // 剧集类内容：找同 series 的下一集（参考 FeedView._jumpToNextEpisode）
    final series = playingItem.seriesName;
    if (series != null && series.isNotEmpty) {
      // 优先找同 series 的下一集
      final nextSameSeries = items.indexWhere(
        (i) =>
            i.id != playingItem.id &&
            i.seriesName == series &&
            (i.indexNumber ?? 0) > (playingItem.indexNumber ?? 0),
      );
      if (nextSameSeries >= 0) {
        return () {
          ref.read(feedViewPageJumpRequestProvider.notifier).state = nextSameSeries;
        };
      }
    }
    // 否则切到 items 中的下一个
    if (currentIndex + 1 < items.length) {
      return () {
        ref.read(feedViewPageJumpRequestProvider.notifier).state = currentIndex + 1;
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
          ref.read(feedViewPageJumpRequestProvider.notifier).state = prevSameSeries;
        };
      }
    }
    if (currentIndex - 1 >= 0) {
      return () {
        ref.read(feedViewPageJumpRequestProvider.notifier).state = currentIndex - 1;
      };
    }
    return null;
  }

  // 构建顶部显示的标题（剧集显示 "剧名 E集数"）
  String _displayTitle(MediaItem? item) {
    if (item == null) return '';
    if (item.seriesName != null && item.seriesName!.isNotEmpty && item.indexNumber != null) {
      return '${item.seriesName} · E${item.indexNumber}';
    }
    return item.title;
  }

  @override
  Widget build(BuildContext context) {
    // ★ 关键：从全局 store 读取同一个 controller
    // 不要在这里创建新 controller！那是进度丢失的根源。
    final controller = ref.watch(currentVideoControllerProvider);
    final playingItem = ref.watch(currentPlayingItemProvider);
    final items = ref.watch(videoListProvider.select((s) => s.items));

    final onNextEpisode = _computeOnNextEpisode(playingItem, items);
    final onPrevEpisode = _computeOnPrevEpisode(playingItem, items);

    final isControllerReady = controller != null && controller.value.isInitialized;
    final hasError = controller != null && controller.value.hasError;

    return Scaffold(
      backgroundColor: Colors.black,
      // PopScope 拦截系统返回键，退出全屏
      body: PopScope(
        canPop: true,
        child: Stack(
          children: [
            // 居中显示视频：保持原 aspectRatio，黑色背景填剩余空间
            // 外层包 GestureOverlay 启用完整手势（单击切换控制层 / 双击 ±10s /
            // 长按 2x 倍速 / 水平拖动 seek / 右侧垂直滑动调音量）
            //
            // enableGestures 在控制层隐藏时启用，避免和控制层 Slider 抢手势
            if (isControllerReady)
              IgnorePointer(
                ignoring: _isScreenLocked,
                child: GestureOverlay(
                  key: ValueKey('gesture_$_retryKey'),
                  controller: controller,
                  // playingItem 通常非空（从 VideoPageItem 进入全屏时已设置）；
                  // 极端情况下为 null 时用空 MediaItem 兜底，双击点赞自然无效
                  item: playingItem ??
                      const MediaItem(id: '', title: '', type: 'Unknown'),
                  onSingleTap: _toggleControls,
                  enableGestures: !_controlsVisible && !_isScreenLocked,
                  enableVerticalVolumeDrag: true,
                  child: Center(
                    child: RepaintBoundary(
                      child: AspectRatio(
                        aspectRatio: controller.value.aspectRatio == 0
                            ? 16 / 9
                            : controller.value.aspectRatio,
                        child: VideoPlayer(controller),
                      ),
                    ),
                  ),
                ),
              )
            else if (hasError)
              // 错误状态
              Center(
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
              )
            else
              // 初始加载状态
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),

            // 缓冲指示器：播放中缓冲时显示小尺寸 loading
            if (isControllerReady && !hasError)
              ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: controller!,
                builder: (context, value, child) {
                  if (value.isBuffering) {
                    return const Center(
                      child: SizedBox(
                        width: 40,
                        height: 40,
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

            // 顶部：退出按钮 + 标题 + 锁屏按钮 + 旋转按钮（控制层可见时显示）
            if (_controlsVisible && !_isScreenLocked)
              Positioned(
                left: 0, right: 0, top: 0,
                child: SafeArea(
                  bottom: false,
                  child: AnimatedOpacity(
                    opacity: _controlsVisible ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.fullscreen_exit,
                            color: Colors.white,
                            size: 28,
                          ),
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
                        // 横竖屏切换
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
                        // 锁屏按钮
                        IconButton(
                          icon: const Icon(
                            Icons.lock_open,
                            color: Colors.white,
                            size: 24,
                          ),
                          onPressed: _lockScreen,
                          tooltip: '锁屏',
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // 底部：复用小屏的 VideoControls（含 play/pause + 上一集/下一集 +
            // 可拖动 seek 进度条 + 倍速 + 字幕）
            // 控制层可见时显示，隐藏时不显示
            if (_controlsVisible && isControllerReady && !_isScreenLocked)
              Positioned(
                left: 0, right: 0, bottom: 0,
                child: SafeArea(
                  top: false,
                  child: AnimatedOpacity(
                    opacity: _controlsVisible ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: IgnorePointer(
                      ignoring: !_controlsVisible,
                      child: VideoControls(
                        controller: controller,
                        subtitleTracks: playingItem?.subtitleTracks ?? const <SubtitleTrack>[],
                        onPrevEpisode: onPrevEpisode,
                        onNextEpisode: onNextEpisode,
                        // onToggleFullscreen 由 VideoControls 内部的"全屏"按钮调用，
                        // 但我们已经处于全屏，禁用该按钮（不传）
                        onToggleFullscreen: null,
                        isInFullscreen: true,
                        // Slider 拖动时取消自动隐藏，松手后重启计时器
                        onSeekStart: () {
                          _hideTimer?.cancel();
                        },
                        onSeekEnd: () {
                          _startHideTimer();
                        },
                      ),
                    ),
                  ),
                ),
              ),

            // 锁屏 UI：左侧显示解锁按钮
            if (_isScreenLocked)
              Positioned(
                left: 12,
                top: 0,
                bottom: 0,
                child: SafeArea(
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
              ),
          ],
        ),
      ),
    );
  }
}
