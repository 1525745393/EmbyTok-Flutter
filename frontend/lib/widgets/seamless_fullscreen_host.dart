// 无缝全屏切换宿主组件
//
// 放置在应用根部（HomeScaffold 的 Stack 顶层），负责：
// 1. 监听 seamlessFullscreenProvider 状态变化
// 2. 管理进入/退出动画的 AnimationController
// 3. 动画期间纯 VideoPlayer 画面缩放，避免控制层干扰视觉
// 4. 动画完成后淡入完整全屏播放器控制层
// 5. 统一管理 SystemChrome（沉浸式 + 方向锁定）
// 6. 响应系统返回键（退出全屏）
//
// 核心优化原理：
// - 不使用 Navigator.push（新路由），在同一路由 Stack 中叠加
// - 进入全屏前先让小窗 VideoPlayer 隐藏（provider 标记），下一帧开始动画
//   → 避免同一帧两个 VideoPlayer widget 同时持有同一 Texture 导致闪烁
// - 方向切换：先调用 SystemChrome.setPreferredOrientations，等待一帧让
//   MediaQuery 更新为新尺寸后再开始动画，确保目标 rect 准确
// - 进入动画：小窗位置 → 全屏位置（300ms easeOut），仅渲染纯视频画面
// - 退出动画：先淡出控制层，然后视频画面缩放回小窗（250ms easeIn）
//   动画结束后恢复方向为竖屏，通知 provider 已退出，小窗 VideoPlayer 恢复渲染
// - 全程 VideoPlayerController 不 dispose、不重新 initialize，音画不中断

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../providers/providers.dart';
import 'complete_fullscreen_player.dart';

class SeamlessFullscreenHost extends ConsumerStatefulWidget {
  const SeamlessFullscreenHost({super.key});

  @override
  ConsumerState<SeamlessFullscreenHost> createState() =>
      _SeamlessFullscreenHostState();
}

class _SeamlessFullscreenHostState
    extends ConsumerState<SeamlessFullscreenHost>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  AnimationController? _animController;
  Animation<Rect?>? _rectAnim;
  // 退出阶段的缩放/透明度动画（坐标系不同，不用 RectTween）
  Animation<double>? _exitScaleAnim;
  Animation<double>? _exitFadeAnim;

  // 阶段：
  // 0 = 空闲（不显示全屏层）
  // 1 = 进入动画中（纯视频缩放）
  // 2 = 全屏播放中（显示完整控制层）
  // 3 = 退出动画中（控制层淡出 + 视频缩放回小窗）
  int _phase = 0;
  bool _isLandscape = true;
  String? _currentItemId;
  // 保存小窗原始 rect（退出动画用）
  Rect? _cachedSourceRect;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.listenManual<SeamlessFullscreenState>(
        seamlessFullscreenProvider,
        _onStateChanged,
        fireImmediately: true,
      );
    });
  }

  @override
  void didChangeMetrics() {
    // 屏幕旋转/尺寸变化时，如果处于全屏播放阶段，不响应；
    // 如果处于动画中，重新读取 MediaQuery 尺寸（系统可能在方向切换中）
    // 不做特殊处理，动画会自然适配当前帧尺寸
  }

  void _onStateChanged(
      SeamlessFullscreenState? prev, SeamlessFullscreenState next) {
    final prevFullscreen = prev?.isFullscreen ?? false;
    if (!prevFullscreen && next.isFullscreen) {
      _startEnterAnimation(next);
    } else if (prevFullscreen && !next.isFullscreen && _phase == 2) {
      _startExitAnimation(next);
    }
  }

  void _applyFullscreenSystemUI() {
    if (_isLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [],
    );
  }

  void _restoreSystemUI() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  Future<void> _startEnterAnimation(SeamlessFullscreenState state) async {
    _currentItemId = state.sourceItemId;
    _cachedSourceRect = state.sourceRect;
    _animController?.dispose();
    _animController = null;
    _rectAnim = null;

    // 第一步：先设置方向为横屏，让 MediaQuery 下一帧更新为横屏尺寸
    setState(() => _phase = 1);
    _applyFullscreenSystemUI();
    ref.read(isFullscreenProvider.notifier).state = true;

    // 等待一帧：方向切换生效 + 小窗 VideoPlayerWidget 收到 renderVideo=false
    // 移除 VideoPlayer widget，避免两个 VideoPlayer 同时持有同一 Texture 导致闪烁
    await Future.delayed(Duration.zero);
    if (!mounted || _phase != 1) return;

    // 第二帧后 MediaQuery 尺寸已是新的全屏尺寸
    final screenSize = MediaQuery.of(context).size;
    final fullRect = Offset.zero & screenSize;
    final sourceRect = _cachedSourceRect ?? state.sourceRect;

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _rectAnim = RectTween(begin: sourceRect, end: fullRect).animate(
      CurvedAnimation(parent: _animController!, curve: Curves.easeOutCubic),
    );

    _animController!.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _phase = 2);
      }
    });

    // 触发重绘并启动动画
    setState(() {});
    _animController!.forward();
  }

  void _startExitAnimation(SeamlessFullscreenState state) {
    if (_phase != 2) return;

    _animController?.dispose();

    // 退出动画策略：
    // 由于进入时方向从竖屏切换到横屏，退出时坐标系不一致，无法精确缩回到小窗原始位置。
    // 采用：控制层快速淡出 → 视频画面缩放（1.0→0.0 中心缩小）+ 淡出 → 恢复方向和 UI
    // 动画结束后 markExited() 让小窗 VideoPlayer 恢复渲染（同一个 controller，画面无缝续上）
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );

    // 缩放动画：1.0 → 0.85（中心轻微缩小，避免视觉突兀）
    // 透明度动画：1.0 → 0.0
    final scaleAnim = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _animController!, curve: Curves.easeInCubic),
    );
    final fadeAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animController!, curve: Curves.easeInCubic),
    );

    setState(() => _phase = 3);

    _animController!.addStatusListener((status) async {
      if (status == AnimationStatus.completed) {
        // 动画完成：先恢复方向/系统 UI，让 MediaQuery 回到竖屏尺寸
        _restoreSystemUI();
        // 等一帧让方向切换生效
        await Future.delayed(Duration.zero);
        if (!mounted) return;
        // 通知小窗可以恢复渲染 VideoPlayer 了（controller 从未销毁，画面立即出现）
        ref.read(seamlessFullscreenProvider.notifier).markExited();
        // 再等一帧，让小窗 build 完成，再移除全屏层
        await Future.delayed(Duration.zero);
        if (mounted) {
          setState(() {
            _phase = 0;
            _currentItemId = null;
            _cachedSourceRect = null;
          });
        }
      }
    });

    // 保存动画引用供 build 使用（通过 AnimatedBuilder 读取 controller.value）
    _exitScaleAnim = scaleAnim;
    _exitFadeAnim = fadeAnim;

    _animController!.forward();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animController?.dispose();
    _restoreSystemUI();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == 0) return const SizedBox.shrink();

    final controller = ref.watch(currentVideoControllerProvider);
    final controllerReady =
        controller != null && controller.value.isInitialized;

    // 动画中（phase 1/3）或全屏中（phase 2）
    final isAnimating = _phase == 1 || _phase == 3;
    final showControls = _phase == 2;

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            // 背景黑色层（动画期间覆盖底部栏）
            if (isAnimating)
              const Positioned.fill(
                child: ColoredBox(color: Colors.black),
              ),

            // 进入动画阶段（phase 1）：纯视频画面，用 RectTween 做位置+大小动画
            if (_phase == 1 && controllerReady && _rectAnim != null)
              AnimatedBuilder(
                animation: _animController!,
                builder: (context, child) {
                  final rect = _rectAnim!.value;
                  if (rect == null) return const SizedBox.shrink();
                  return Positioned(
                    left: rect.left,
                    top: rect.top,
                    width: rect.width,
                    height: rect.height,
                    child: ClipRect(child: _buildPureVideo(controller)),
                  );
                },
              ),

            // 退出动画阶段（phase 3）：纯视频画面，用中心缩放+淡出
            if (_phase == 3 && controllerReady)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _animController!,
                  builder: (context, child) {
                    final scale = _exitScaleAnim?.value ?? 1.0;
                    final opacity = _exitFadeAnim?.value ?? 1.0;
                    return Opacity(
                      opacity: opacity,
                      child: Transform.scale(
                        scale: scale,
                        alignment: Alignment.center,
                        child: _buildPureVideo(controller),
                      ),
                    );
                  },
                ),
              ),

            // 全屏完整播放器（动画完成后显示，退出时通过 opacity 淡出）
            if (showControls || _phase == 3)
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: _phase == 3,
                  child: AnimatedOpacity(
                    opacity: showControls ? 1.0 : 0.0,
                    duration: Duration(milliseconds: _phase == 3 ? 80 : 200),
                    curve: Curves.easeOut,
                    child: CompleteFullscreenPlayer(
                      key: const ValueKey('seamless-fullscreen'),
                      seamlessMode: true,
                      onSeamlessExit: _requestExit,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _requestExit() {
    ref.read(seamlessFullscreenProvider.notifier).exit();
  }

  Widget _buildPureVideo(VideoPlayerController controller) {
    final size = controller.value.size;
    final isPortraitVideo = size.height > size.width;
    final fit = isPortraitVideo ? BoxFit.cover : BoxFit.contain;
    return ColoredBox(
      color: Colors.black,
      child: SizedBox.expand(
        child: FittedBox(
          fit: fit,
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: VideoPlayer(controller),
          ),
        ),
      ),
    );
  }
}
