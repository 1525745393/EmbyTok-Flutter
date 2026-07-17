// 手势交互层：单击/双击/长按倍速/水平拖动进度/垂直滑动音量
// 设计要点：拖动过程中只更新预览 UI，不调用 seekTo（避免高频调用导致 MediaCodec 崩溃）
//           只有松手时才执行一次 seek
// 单击行为变更：原为切换播放/暂停，现改为切换控制层显示/隐藏（TikTok 风格）
// 垂直滑动：屏幕右侧 1/2 区域上下滑动调节音量（仅在 enableVerticalVolumeDrag=true 时启用，
//           避免和小屏 PageView 的垂直滑动切换视频冲突）

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';

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
  // 是否启用垂直滑动音量调节
  // - true：使用 onPan 同时处理水平/垂直拖动（全屏场景，无 PageView 冲突）
  // - false：仅启用水平拖动 seek（小屏场景，避免和 PageView 垂直滑动切换视频冲突）
  final bool enableVerticalVolumeDrag;

  const GestureOverlay({
    super.key,
    required this.child,
    required this.item,
    required this.controller,
    this.onSingleTap,
    this.enableGestures = true,
    this.enableVerticalVolumeDrag = false,
  });

  @override
  ConsumerState<GestureOverlay> createState() => _GestureOverlayState();
}

class _GestureOverlayState extends ConsumerState<GestureOverlay> {
  Timer? _singleTapTimer;
  bool _pendingSingleTap = false;
  bool _isLongPressing = false;
  double _originalRate = 1.0; // 保存长按前的原始播放速度

  // 拖动通用状态
  bool _isDragging = false;
  // 拖动方向：'h'=水平seek，'v'=垂直音量，null=未确定
  String? _dragAxis;
  double _dragStartX = 0.0;
  double _dragStartY = 0.0;

  // 水平拖动状态（seek）
  Duration _dragStartPosition = Duration.zero;
  Duration _previewPosition = Duration.zero;

  // 垂直拖动状态（音量）
  bool _isVolumeSide = false;
  double _volumeStartValue = 0.0;
  bool _showVolumeUI = false;
  double _volumePreviewValue = 0.0;

  // 动画状态
  bool _showHeart = false;
  Timer? _dragHideTimer;
  Timer? _volumeHideTimer;

  // 双击快进/快退：记录最后一次 tap 位置 + 视觉反馈
  Offset? _lastTapPosition;
  bool _showSeekFeedback = false;
  bool _isSeekForward = false;
  // 连续双击累积次数（用于显示 +20s/+30s 等累积偏移）
  int _seekFeedbackCount = 0;
  Timer? _seekFeedbackResetTimer;

  // 长按倍速视觉反馈
  bool _showSpeedBadge = false;

  // 安全检查：控制器是否可用
  bool get _controllerReady {
    final c = widget.controller;
    if (c == null) return false;
    if (!c.value.isInitialized) return false;
    if (c.value.hasError) return false;
    return true;
  }

  // ---- 单击 ----
  void _onSingleTap() {
    widget.onSingleTap?.call();
  }

  // ---- 双击 ----
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

    // 中间区域：双击点赞
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
      AppLogger.warn('双击点赞失败', data: {'error': e.toString()});
    }
  }

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
      AppLogger.debug('双击seek失败', data: {'error': e.toString()});
    }
    // 累积逻辑：同方向连续双击时累加显示（+10s → +20s → +30s）
    // 反方向或超时（800ms）则重置
    final isForward = seconds > 0;
    _seekFeedbackResetTimer?.cancel();
    if (_showSeekFeedback && _isSeekForward == isForward) {
      _seekFeedbackCount++;
    } else {
      _seekFeedbackCount = 1;
    }
    setState(() {
      _isSeekForward = isForward;
      _showSeekFeedback = true;
    });
    // 800ms 内无后续双击则隐藏反馈
    _seekFeedbackResetTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _showSeekFeedback = false;
          _seekFeedbackCount = 0;
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
      _originalRate = c.value.playbackSpeed;
      c.setPlaybackSpeed(kLongPressPlaybackRate);
      if (mounted) {
        setState(() {
          _showSpeedBadge = true;
        });
      }
    } catch (e) {
      AppLogger.debug('长按倍速启动失败', data: {'error': e.toString()});
    }
  }

  void _onLongPressEnd() {
    if (!_isLongPressing) return;
    _isLongPressing = false;
    final c = widget.controller;
    if (c == null || !c.value.isInitialized) return;
    try {
      c.setPlaybackSpeed(_originalRate);
      ref.read(playbackRateProvider.notifier).state = _originalRate;
    } catch (e) {
      AppLogger.debug('长按倍速结束失败', data: {'error': e.toString()});
    }
    if (mounted) {
      setState(() {
        _showSpeedBadge = false;
      });
    }
  }

  // ---- Pan 模式：同时支持水平/垂直拖动（全屏场景）----
  void _onPanStart(DragStartDetails d) {
    final c = widget.controller;
    if (c == null || !c.value.isInitialized) return;
    _dragStartX = d.globalPosition.dx;
    _dragStartY = d.globalPosition.dy;
    _isDragging = true;
    _dragAxis = null;
    _dragHideTimer?.cancel();
    _volumeHideTimer?.cancel();
    if (mounted) setState(() {});
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final c = widget.controller;
    if (c == null || !c.value.isInitialized) return;

    final dx = d.globalPosition.dx - _dragStartX;
    final dy = d.globalPosition.dy - _dragStartY;

    // 尚未决定方向时，根据移动距离判断
    if (_dragAxis == null) {
      if (dx.abs() > dy.abs() && dx.abs() > 8) {
        _dragAxis = 'h';
        _dragStartPosition = c.value.position;
        _previewPosition = c.value.position;
        HapticFeedback.selectionClick();
      } else if (dy.abs() > dx.abs() && dy.abs() > 8) {
        _dragAxis = 'v';
        final screenWidth = MediaQuery.of(context).size.width;
        _isVolumeSide = _dragStartX > screenWidth / 2;
        if (_isVolumeSide) {
          _volumeStartValue = c.value.volume;
          _volumePreviewValue = c.value.volume;
          setState(() {
            _showVolumeUI = true;
          });
        } else {
          // 左侧垂直滑动：让父级（PageView）处理，取消当前拖动
          _isDragging = false;
          _dragAxis = null;
          return;
        }
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
    } else if (_dragAxis == 'v' && _isVolumeSide) {
      final screenHeight = MediaQuery.of(context).size.height;
      final delta = -dy / (screenHeight * 0.6);
      var newVolume = (_volumeStartValue + delta).clamp(0.0, 1.0);
      _volumePreviewValue = newVolume;
      try {
        c.setVolume(newVolume);
      } catch (_) {}
      if (mounted) setState(() {});
    }
  }

  void _onPanEnd(DragEndDetails d) {
    _endDrag();
  }

  void _onPanCancel() {
    _isDragging = false;
    _dragAxis = null;
    if (mounted) setState(() {});
  }

  // ---- 水平拖动模式：仅水平 seek（小屏场景）----
  void _onHorizontalDragStart(DragStartDetails d) {
    final c = widget.controller;
    if (c == null || !c.value.isInitialized) return;
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
    if (!_isDragging || _dragAxis != 'h') return;
    final c = widget.controller;
    if (c == null || !c.value.isInitialized) return;
    final dx = d.globalPosition.dx - _dragStartX;
    final seekMs = (dx * kSeekPerPixelMs).toInt();
    var target = _dragStartPosition + Duration(milliseconds: seekMs);
    final duration = c.value.duration;
    if (target < Duration.zero) target = Duration.zero;
    if (duration > Duration.zero && target > duration) target = duration;
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

  // 拖动结束：统一处理 seek 执行和 UI 隐藏
  void _endDrag() {
    final c = widget.controller;
    _volumeHideTimer?.cancel();

    if (_dragAxis == 'h') {
      if (c != null && _controllerReady) {
        try {
          final duration = c.value.duration;
          var target = _previewPosition;
          if (target < Duration.zero) target = Duration.zero;
          if (duration > Duration.zero && target > duration) target = duration;
          c.seekTo(target);
          HapticFeedback.lightImpact();
        } catch (e) {
          AppLogger.debug('拖动进度seek失败', data: {'error': e.toString()});
        }
      }
      _dragHideTimer?.cancel();
      _dragHideTimer = Timer(const Duration(milliseconds: 800), () {
        if (mounted) setState(() {});
      });
    } else if (_dragAxis == 'v' && _isVolumeSide) {
      _volumeHideTimer = Timer(const Duration(milliseconds: 600), () {
        if (mounted) {
          setState(() {
            _showVolumeUI = false;
          });
        }
      });
    }

    _isDragging = false;
    _dragAxis = null;
    if (mounted) setState(() {});
  }

  // ---- 单击/双击区分：300ms 定时器 ----
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
    _volumeHideTimer?.cancel();
    _seekFeedbackResetTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final duration = (c != null && c.value.isInitialized)
        ? c.value.duration
        : Duration.zero;
    final currentPosition = (_isDragging && _dragAxis == 'h')
        ? _previewPosition
        : (c != null && c.value.isInitialized ? c.value.position : Duration.zero);

    final usePan = widget.enableVerticalVolumeDrag;

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
            onLongPressStart: widget.enableGestures
                ? (_) => _onLongPressStart()
                : null,
            onLongPressEnd:
                widget.enableGestures ? (_) => _onLongPressEnd() : null,
            onLongPressCancel:
                widget.enableGestures ? _onLongPressEnd : null,
            // Pan 模式：同时支持水平/垂直（全屏无 PageView 冲突）
            onPanStart: (widget.enableGestures && usePan) ? _onPanStart : null,
            onPanUpdate: (widget.enableGestures && usePan) ? _onPanUpdate : null,
            onPanEnd: (widget.enableGestures && usePan) ? _onPanEnd : null,
            onPanCancel: (widget.enableGestures && usePan) ? _onPanCancel : null,
            // 纯水平模式：小屏场景，不影响 PageView 垂直滑动
            onHorizontalDragStart: (widget.enableGestures && !usePan)
                ? _onHorizontalDragStart
                : null,
            onHorizontalDragUpdate: (widget.enableGestures && !usePan)
                ? _onHorizontalDragUpdate
                : null,
            onHorizontalDragEnd: (widget.enableGestures && !usePan)
                ? _onHorizontalDragEnd
                : null,
            onHorizontalDragCancel: (widget.enableGestures && !usePan)
                ? _onHorizontalDragCancel
                : null,
            child: Container(color: Colors.transparent),
          ),
        ),
        // 拖动进度条
        if ((_isDragging && _dragAxis == 'h') ||
            (_dragHideTimer?.isActive == true && _dragAxis == null && _previewPosition != Duration.zero))
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
        // 音量调节 UI
        if (_showVolumeUI && _isVolumeSide && _dragAxis == 'v')
          IgnorePointer(
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
                    Icon(
                      _volumePreviewValue <= 0
                          ? Icons.volume_off
                          : _volumePreviewValue < 0.5
                              ? Icons.volume_down
                              : Icons.volume_up,
                      color: Colors.white,
                      size: 36,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 120,
                      child: LinearProgressIndicator(
                        value: _volumePreviewValue,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        minHeight: 4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(_volumePreviewValue * 100).round()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // 标签：与全屏页统一，明确指示当前调节的是音量
                    const Text(
                      '音量',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        // 长按倍速中央大图标反馈
        if (_showSpeedBadge)
          IgnorePointer(
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
                      // 累积偏移：连续双击时显示 +20s/+30s 等
                      '${_isSeekForward ? '+' : '-'}${_seekFeedbackCount * 10}s',
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
