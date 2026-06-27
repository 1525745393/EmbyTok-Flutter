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
    // 注意：dispose() 内 ref 已无 mounted 属性；用 State.mounted 即可
    Future.microtask(() {
      if (!mounted) return;
      ref.read(isFullscreenProvider.notifier).state = false;
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ★ 关键：从全局 store 读取同一个 controller
    // 不要在这里创建新 controller！那是进度丢失的根源。
    final controller = ref.watch(currentVideoControllerProvider);
    final item = ref.watch(currentPlayingItemProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      // PopScope 拦截系统返回键，退出全屏
      body: PopScope(
        canPop: true,
        child: Stack(
          children: [
            // 居中显示视频：保持原 aspectRatio，黑色背景填剩余空间
            if (controller != null && controller.value.isInitialized)
              Center(
                child: AspectRatio(
                  aspectRatio: controller.value.aspectRatio == 0
                      ? 16 / 9
                      : controller.value.aspectRatio,
                  child: VideoPlayer(controller),
                ),
              )
            else
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
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
            // 底部：进度条（从全局 controller 读取）
            if (controller != null && controller.value.isInitialized)
              Positioned(
                left: 0, right: 0, bottom: 0,
                child: SafeArea(
                  top: false,
                  child: _FullscreenProgressBar(controller: controller),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 全屏页底部进度条：读 controller 实时进度，点击可 seek
class _FullscreenProgressBar extends StatefulWidget {
  final VideoPlayerController controller;
  const _FullscreenProgressBar({required this.controller});

  @override
  State<_FullscreenProgressBar> createState() => _FullscreenProgressBarState();
}

class _FullscreenProgressBarState extends State<_FullscreenProgressBar> {
  // 监听 controller 变化，刷新进度条
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
    if (mounted) setState(() {});
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
