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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../providers/providers.dart';

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
  }

  @override
  void dispose() {
    // 退出全屏：恢复竖屏 + 恢复系统 UI
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    // 标记全局全屏状态
    Future.microtask(() {
      if (!ref.mounted) return;
      ref.read(isFullscreenProvider.notifier).state = false;
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = ref.watch(currentPlayingItemProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: PopScope(
        canPop: true,
        child: Stack(
          children: [
            // 视频画面：独立 ConsumerWidget，避免 controller 状态变化导致整页重建
            const _FullscreenVideoDisplay(),
            // 顶部：标题 + 退出全屏按钮
            Positioned(
              left: 0, right: 0, top: 0,
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.fullscreen_exit,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: '退出全屏',
                    ),
                    if (item != null)
                      Expanded(
                        child: Text(
                          item.title,
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
            // 底部：进度条（独立 ConsumerWidget）
            const _FullscreenProgressBarWrapper(),
          ],
        ),
      ),
    );
  }
}

/// 全屏视频画面：独立 ConsumerWidget，仅订阅 controller 状态，
/// 避免 controller 每帧变化触发 FullscreenVideoPage 整页重建。
class _FullscreenVideoDisplay extends ConsumerWidget {
  const _FullscreenVideoDisplay();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(currentVideoControllerProvider);
    if (controller != null && controller.value.isInitialized) {
      return Center(
        child: AspectRatio(
          aspectRatio: controller.value.aspectRatio == 0
              ? 16 / 9
              : controller.value.aspectRatio,
          child: VideoPlayer(controller),
        ),
      );
    }
    return const Center(
      child: CircularProgressIndicator(color: Colors.white),
    );
  }
}

/// 进度条包装器：独立 ConsumerWidget，仅订阅 controller 状态。
class _FullscreenProgressBarWrapper extends ConsumerWidget {
  const _FullscreenProgressBarWrapper();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(currentVideoControllerProvider);
    if (controller != null && controller.value.isInitialized) {
      return Positioned(
        left: 0, right: 0, bottom: 0,
        child: SafeArea(
          top: false,
          child: _FullscreenProgressBar(controller: controller),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

/// 全屏页底部进度条：读 controller 实时进度，点击可 seek
///
/// 功耗优化：进度条节流刷新，仅在跨秒或间隔 ≥100ms 时才 setState，
/// 避免视频每帧（30-60fps）触发不必要的 Widget 重建。
class _FullscreenProgressBar extends StatefulWidget {
  final VideoPlayerController controller;
  const _FullscreenProgressBar({required this.controller});

  @override
  State<_FullscreenProgressBar> createState() => _FullscreenProgressBarState();
}

class _FullscreenProgressBarState extends State<_FullscreenProgressBar> {
  DateTime _lastRebuild = DateTime.fromMicrosecondsSinceEpoch(0);
  int _lastSecond = -1;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    final now = DateTime.now();
    final sec = widget.controller.value.position.inSeconds;
    // 跨秒 或 距上次刷新超过 100ms 才 setState，减少 ~70% 的无效重建
    if (sec != _lastSecond ||
        now.difference(_lastRebuild).inMilliseconds >= 100) {
      _lastSecond = sec;
      _lastRebuild = now;
      setState(() {});
    }
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.controller.value;
    final pos = v.position;
    final dur = v.duration;
    final progress = dur.inMilliseconds > 0
        ? pos.inMilliseconds / dur.inMilliseconds
        : 0.0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black54],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
              overlayColor: Colors.white24,
              trackHeight: 3,
            ),
            child: Slider(
              value: progress.clamp(0.0, 1.0),
              onChanged: (v) {
                final target = Duration(
                  milliseconds: (v * dur.inMilliseconds).round(),
                );
                widget.controller.seekTo(target);
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _fmt(pos),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              Text(
                _fmt(dur),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
