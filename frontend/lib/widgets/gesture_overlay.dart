// 手势交互层：单击/双击/长按倍速/水平拖动进度
// 设计要点：拖动过程中只更新预览 UI，不调用 seekTo（避免高频调用导致 MediaCodec 崩溃）
//           只有松手时才执行一次 seek
// 单击行为变更：原为切换播放/暂停，现改为切换控制层显示/隐藏（TikTok 风格）

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/constants.dart';

// 手势交互层：统一处理视频画面上的手势事件
class GestureOverlay extends ConsumerStatefulWidget {
  final Widget child;
  final MediaItem item;
  final VideoPlayerController? controller;
  // 单击回调：用于切换控制层显示/隐藏（由父组件 VideoPageItem 提供）
  final VoidCallback? onSingleTap;
  // 是否启用「长按倍速 / 水平拖动 seek」手势
  //
  // - true（默认）：全手势可用（小屏场景）
  // - false：仅单击 / 双击可用，长按和水平拖动被禁用
  //   用于全屏页控制层显示时，避免和控制层 Slider 抢手势
  final bool enableGestures;

  const GestureOverlay({
    super.key,
    required this.child,
    required this.item,
    required this.controller,
    this.onSingleTap,
    this.enableGestures = true,
  });

  @override
  ConsumerState<GestureOverlay> createState() => _GestureOverlayState();
}

class _GestureOverlayState extends ConsumerState<GestureOverlay> {
  Timer? _singleTapTimer;
  bool _pendingSingleTap = false;
  bool _isLongPressing = false;
  double _originalRate = 1.0; // 保存长按前的原始播放速度

  // 水平拖动状态
  bool _isDragging = false;
  double _dragStartX = 0.0;
  Duration _dragStartPosition = Duration.zero; // 拖动起始时的播放位置
  Duration _previewPosition = Duration.zero; // 当前预览位置（拖动中展示用）

  // 动画状态
  bool _showHeart = false;
  Timer? _dragHideTimer; // 拖动结束后隐藏进度条的延迟

  // 双击快进/快退：记录最后一次 tap 位置 + 视觉反馈
  Offset? _lastTapPosition;
  bool _showSeekFeedback = false;
  bool _isSeekForward = false;

  // 安全检查：控制器是否可用
  bool get _controllerReady {
    final c = widget.controller;
    if (c == null) return false;
    if (!c.value.isInitialized) return false;
    if (c.value.hasError) return false;
    return true;
  }

  // ---- 单击 ----
  // 新行为：切换控制层显示/隐藏（TikTok 风格），不再直接控制播放/暂停
  void _onSingleTap() {
    widget.onSingleTap?.call();
  }

  // ---- 双击 ----
  // YouTube 风格：双击左 1/3 快退 10s，双击右 1/3 快进 10s，双击中间点赞
  void _onDoubleTap() {
    final pos = _lastTapPosition;
    final screenWidth = MediaQuery.of(context).size.width;

    // 判断 tap 位置在哪个区域
    if (pos != null && _controllerReady) {
      final relativeX = pos.dx / screenWidth;
      if (relativeX < 0.33) {
        // 左 1/3：快退 10 秒
        _seekBySeconds(-10);
        return;
      } else if (relativeX > 0.67) {
        // 右 1/3：快进 10 秒
        _seekBySeconds(10);
        return;
      }
    }

    // 中间区域：保留双击点赞
    setState(() {
      _showHeart = true;
    });
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) {
        setState(() {
          _showHeart = false;
        });
      }
    });
    try {
      unawaited(ref.read(favoritesProvider.notifier).toggleFavorite(widget.item));
    } catch (e) {
      debugPrint('_onDoubleTap toggleFavorite error: $e');
    }
  }

  // 双击快进/快退：seek 指定秒数并显示视觉反馈
  void _seekBySeconds(int seconds) {
    final c = widget.controller;
    if (c == null || !c.value.isInitialized) return;
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
    // 显示快进/快退视觉反馈
    setState(() {
      _isSeekForward = seconds > 0;
      _showSeekFeedback = true;
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _showSeekFeedback = false;
        });
      }
    });
  }

  // ---- 长按倍速 ----
  void _onLongPressStart() {
    final c = widget.controller;
    if (c == null || !c.value.isInitialized) return;
    try {
      _isLongPressing = true;
      _originalRate = c.value.playbackSpeed; // 先保存原始速度
      c.setPlaybackSpeed(kLongPressPlaybackRate);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('_onLongPressStart error: $e');
    }
  }

  void _onLongPressEnd() {
    if (!_isLongPressing) return;
    _isLongPressing = false;
    final c = widget.controller;
    if (c == null || !c.value.isInitialized) return;
    try {
      c.setPlaybackSpeed(_originalRate); // 用保存的原始速度恢复
      ref.read(playbackRateProvider.notifier).state = _originalRate;
    } catch (e) {
      debugPrint('_onLongPressEnd error: $e');
    }
    if (mounted) setState(() {});
  }

  // ---- 水平拖动（快进/快退）----
  // 关键优化：拖动过程中只更新预览位置 + 震动反馈，不调用 seekTo
  //          只在拖动结束后执行一次 seek，避免高频调用 MediaCodec 导致崩溃
  void _onHorizontalDragStart(DragStartDetails d) {
    if (!_controllerReady) return;
    final c = widget.controller!;
    _isDragging = true;
    _dragStartX = d.globalPosition.dx;
    _dragStartPosition = c.value.position;
    _previewPosition = c.value.position;
    _dragHideTimer?.cancel();
    // 轻震动提示：进入拖动模式
    HapticFeedback.selectionClick();
    if (mounted) setState(() {});
  }

  void _onHorizontalDragUpdate(DragUpdateDetails d) {
    if (!_isDragging) return;
    if (!_controllerReady) return;
    final c = widget.controller!;

    // 计算水平偏移 -> 目标进度（毫秒）
    final dx = d.globalPosition.dx - _dragStartX;
    final seekMs = (dx * kSeekPerPixelMs).toInt();
    var target = _dragStartPosition + Duration(milliseconds: seekMs);

    // 夹紧到有效范围
    final duration = c.value.duration;
    if (target < Duration.zero) {
      target = Duration.zero;
    } else if (duration > Duration.zero && target > duration) {
      target = duration;
    }

    // ⚠️ 关键：只更新预览变量，不调用 seekTo
    // 拖动过程中频繁 seek 是导致 Android MediaCodec 崩溃的主要原因
    _previewPosition = target;

    // 每约 0.5 秒给一次轻震动，让用户有进度变化的反馈
    if (mounted) setState(() {});
  }

  void _onHorizontalDragEnd() {
    if (!_isDragging) return;
    _isDragging = false;
    final c = widget.controller;
    if (c != null && _controllerReady) {
      // 只执行一次 seek —— 这是正确的做法
      try {
        final duration = c.value.duration;
        var target = _previewPosition;
        if (target < Duration.zero) target = Duration.zero;
        if (duration > Duration.zero && target > duration) target = duration;
        c.seekTo(target);
        // seek 成功的轻震动反馈
        HapticFeedback.lightImpact();
      } catch (e) {
        debugPrint('seekTo error: $e');
      }
    }
    // 延迟 800ms 隐藏进度条，给用户看清最终位置
    _dragHideTimer?.cancel();
    _dragHideTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() {});
    });
    if (mounted) setState(() {});
  }

  // ---- 单击/双击区分：300ms 定时器 ----
  void _handleTap() {
    // 拖动状态下点击事件忽略（避免松手后触发单击）
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final duration = _controllerReady
        ? widget.controller!.value.duration
        : Duration.zero;
    final currentPosition =
        _isDragging ? _previewPosition : (_controllerReady ? widget.controller!.value.position : Duration.zero);

    return Stack(
      alignment: Alignment.center,
      children: [
        widget.child,
        // 手势识别层
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) {
              _lastTapPosition = details.globalPosition;
            },
            onTap: _handleTap,
            // 仅在 enableGestures=true 时注册长按和水平拖动
            // （全屏控制层显示时禁用，避免和 Slider 抢手势）
            onLongPressStart: widget.enableGestures
                ? (_) => _onLongPressStart()
                : null,
            onLongPressEnd:
                widget.enableGestures ? (_) => _onLongPressEnd() : null,
            onLongPressCancel:
                widget.enableGestures ? _onLongPressEnd : null,
            onHorizontalDragStart:
                widget.enableGestures ? _onHorizontalDragStart : null,
            onHorizontalDragUpdate:
                widget.enableGestures ? _onHorizontalDragUpdate : null,
            onHorizontalDragEnd: widget.enableGestures
                ? (_) => _onHorizontalDragEnd()
                : null,
            onHorizontalDragCancel:
                widget.enableGestures ? _onHorizontalDragEnd : null,
            child: Container(color: Colors.transparent),
          ),
        ),
        // 拖动进度条：拖动中显示位置指示
        if (_isDragging || _dragHideTimer?.isActive == true)
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
        // 双击心形动画
        if (_showHeart)
          const IgnorePointer(child: _FlyingHeart()),
        // 双击快进/快退视觉反馈
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
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.22),
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
                      color: Theme.of(context).colorScheme.onPrimary,
                      size: 48,
                      shadows: [
                        Shadow(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.33),
                            blurRadius: 8),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isSeekForward ? '+10s' : '-10s',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        shadows: [
                          Shadow(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.33),
                              blurRadius: 4),
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
}

// ---- 内部子组件：拖动进度预览条 ----
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
        color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
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
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${_format(current)} / ${_format(total)}',
                style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: clampedProgress,
            backgroundColor:
                Theme.of(context).colorScheme.onSurface.withOpacity(0.14),
            valueColor:
                AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
          ),
        ],
      ),
    );
  }
}

// ---- 内部子组件：飞行心形 ----
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
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.33),
                    blurRadius: 16,
                    offset: Offset(0, 4)),
              ],
            ),
          ),
        );
      },
    );
  }
}
