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
/// 即可进入全屏。退出全屏请用系统返回键或 ESC。
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

  @override
  void initState() {
    super.initState();
    // 进入全屏：强制横屏（仅左右横屏，避免反向）
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [],
    );
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    // 标记全局全屏状态
    Future.microtask(() {
      if (mounted) {
        ref.read(isFullscreenProvider.notifier).state = true;
      }
    });
    // 默认 4 秒后自动隐藏控制层
    _startHideTimer();
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
    // 这是 PR #62 修复点
    ref.read(isFullscreenProvider.notifier).state = false;
    super.dispose();
  }

  // 自动隐藏控制层（4 秒无操作）
  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  // 切换控制层显隐
  void _toggleControls() {
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

  @override
  Widget build(BuildContext context) {
    // ★ 关键：从全局 store 读取同一个 controller
    // 不要在这里创建新 controller！那是进度丢失的根源。
    final controller = ref.watch(currentVideoControllerProvider);
    final playingItem = ref.watch(currentPlayingItemProvider);
    final items = ref.watch(videoListProvider.select((s) => s.items));

    final onNextEpisode = _computeOnNextEpisode(playingItem, items);
    final onPrevEpisode = _computeOnPrevEpisode(playingItem, items);

    return Scaffold(
      backgroundColor: Colors.black,
      // PopScope 拦截系统返回键，退出全屏
      body: PopScope(
        canPop: true,
        child: Stack(
          children: [
            // 居中显示视频：保持原 aspectRatio，黑色背景填剩余空间
            // 外层包 GestureOverlay 启用完整手势（单击切换控制层 / 双击 ±10s /
            // 长按 2x 倍速 / 水平拖动 seek）
            //
            // enableGestures 在控制层隐藏时启用，避免和控制层 Slider 抢手势
            if (controller != null && controller.value.isInitialized)
              GestureOverlay(
                controller: controller,
                // playingItem 通常非空（从 VideoPageItem 进入全屏时已设置）；
                // 极端情况下为 null 时用空 MediaItem 兜底，双击点赞自然无效
                item: playingItem ??
                    const MediaItem(id: '', title: '', type: 'Unknown'),
                onSingleTap: _toggleControls,
                enableGestures: !_controlsVisible,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: controller.value.aspectRatio == 0
                        ? 16 / 9
                        : controller.value.aspectRatio,
                    child: VideoPlayer(controller),
                  ),
                ),
              )
            else
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),

              // 顶部：标题 + 退出全屏按钮（控制层可见时显示）
              if (_controlsVisible)
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
                        ],
                      ),
                    ),
                  ),
                ),

              // 底部：复用小屏的 VideoControls（含 play/pause + 上一集/下一集 +
              // 可拖动 seek 进度条 + 倍速 + 字幕 + 退出全屏按钮）
              // 控制层可见时显示，隐藏时不显示
              if (_controlsVisible && controller != null && controller.value.isInitialized)
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
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
