// 视频手势 Mixin：抽取 GestureOverlay 和 FullscreenVideoPage 共有的手势逻辑
//
// 功能：
// - 单击/双击判定（左/中/右区域分发）
// - Pan 模式 + HorizontalDrag 模式
// - 水平拖动 seek（预览+结束时 seek）
// - 垂直拖动音量
// - 长按倍速
// - 双击 seek 反馈 + 爱心动画
//
// 子类通过钩子方法填充业务差异。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../models/models.dart';
import '../../utils/constants.dart';
import '../../utils/logger.dart';

mixin VideoGestureMixin<T extends StatefulWidget> on State<T> {
  // ==================== 钩子方法（子类实现/重写）====================

  VideoPlayerController? get videoController;

  bool get gesturesEnabled => true;

  void onSingleTap();

  void onDoubleTapLeft() => seekBySeconds(-10);

  void onDoubleTapRight() => seekBySeconds(10);

  void onDoubleTapCenter();

  bool get handleLeftVerticalDrag => false;

  void onLeftVerticalDragUpdate(double delta) {}

  void onSeekTo(Duration target) {
    videoController?.seekTo(target);
  }

  void onSetVolume(double value) {
    videoController?.setVolume(value);
  }

  MediaItem? get currentItem => null;

  // ==================== 常量 ====================

  static const _kSingleTapDelay = Duration(milliseconds: 300);
  static const _kSeekPerPixelMs = 40;
  static const _kDragHideDelay = Duration(milliseconds: 800);
  static const _kLongPressRate = 2.0;

  // ==================== 状态变量 ====================

  // 单击/双击
  Timer? _singleTapTimer;
  bool _pendingSingleTap = false;
  Offset? _lastTapPosition;

  // 拖动通用
  bool isDragging = false;
  String? dragAxis;
  double _dragStartX = 0.0;
  double _dragStartY = 0.0;

  // 水平 seek
  Duration dragStartPosition = Duration.zero;
  final previewPositionNotifier = ValueNotifier<Duration>(Duration.zero);

  // 垂直音量
  bool isVolumeSide = false;
  double _volumeStartValue = 0.0;
  final previewVolumeNotifier = ValueNotifier<double>(0.0);
  final showVolumeUINotifier = ValueNotifier<bool>(false);
  Timer? _volumeHideTimer;

  // 长按倍速
  bool _isLongPressing = false;
  double originalRate = 1.0;
  final showSpeedBadgeNotifier = ValueNotifier<bool>(false);

  // 双击 seek 反馈
  bool showSeekFeedback = false;
  bool isSeekForward = false;
  int seekFeedbackCount = 0;
  Timer? _seekFeedbackResetTimer;

  // 爱心动画
  bool showHeart = false;
  Timer? _heartHideTimer;

  // 拖动隐藏延迟
  Timer? _dragHideTimer;

  // ==================== 单击/双击 ====================

  void handleTap() {
    if (!gesturesEnabled) return;
    if (isDragging) return;
    if (_pendingSingleTap) {
      _singleTapTimer?.cancel();
      _pendingSingleTap = false;
      _onDoubleTap();
    } else {
      _pendingSingleTap = true;
      _singleTapTimer = Timer(_kSingleTapDelay, () {
        if (_pendingSingleTap && mounted) {
          _pendingSingleTap = false;
          onSingleTap();
        }
      });
    }
  }

  void handleTapDown(TapDownDetails details) {
    _lastTapPosition = details.globalPosition;
  }

  void _onDoubleTap() {
    if (!mounted) return;
    final pos = _lastTapPosition;
    final c = videoController;

    if (pos != null && c != null && c.value.isInitialized) {
      final screenWidth = MediaQuery.of(context).size.width;
      final relativeX = pos.dx / screenWidth;
      if (relativeX < 0.33) {
        onDoubleTapLeft();
        return;
      } else if (relativeX > 0.67) {
        onDoubleTapRight();
        return;
      }
    }

    onDoubleTapCenter();
  }

  void _showSeekFeedbackAnimation(bool forward) {
    _seekFeedbackResetTimer?.cancel();
    if (showSeekFeedback && isSeekForward == forward) {
      seekFeedbackCount++;
    } else {
      seekFeedbackCount = 1;
    }
    if (!mounted) return;
    setState(() {
      isSeekForward = forward;
      showSeekFeedback = true;
    });
    _seekFeedbackResetTimer = Timer(_kDragHideDelay, () {
      if (mounted) {
        setState(() {
          showSeekFeedback = false;
          seekFeedbackCount = 0;
        });
      }
    });
  }

  void seekBySeconds(int seconds) {
    final c = videoController;
    if (c == null || !c.value.isInitialized) return;
    try {
      final current = c.value.position;
      final duration = c.value.duration;
      var target = current + Duration(seconds: seconds);
      if (target < Duration.zero) target = Duration.zero;
      if (duration > Duration.zero && target > duration) target = duration;
      onSeekTo(target);
      HapticFeedback.lightImpact();
    } catch (e) {
      AppLogger.debug('双击seek失败', data: {'error': e.toString()});
    }
    _showSeekFeedbackAnimation(seconds > 0);
  }

  void _cancelSingleTap() {
    _singleTapTimer?.cancel();
    _pendingSingleTap = false;
  }

  // ==================== Pan 拖动（全屏模式）====================

  void onPanStart(DragStartDetails d) {
    if (!gesturesEnabled) return;
    _cancelSingleTap();
    final c = videoController;
    if (c == null || !c.value.isInitialized) return;
    _dragStartX = d.globalPosition.dx;
    _dragStartY = d.globalPosition.dy;
    isDragging = true;
    dragAxis = null;
    _dragHideTimer?.cancel();
    _volumeHideTimer?.cancel();
    if (mounted) setState(() {});
  }

  void onPanUpdate(DragUpdateDetails d) {
    final c = videoController;
    if (c == null || !c.value.isInitialized) return;

    final dx = d.globalPosition.dx - _dragStartX;
    final dy = d.globalPosition.dy - _dragStartY;

    if (dragAxis == null) {
      if (dx.abs() > dy.abs() && dx.abs() > 8) {
        dragAxis = 'h';
        dragStartPosition = c.value.position;
        previewPositionNotifier.value = c.value.position;
        HapticFeedback.selectionClick();
        if (mounted) setState(() {});
      } else if (dy.abs() > dx.abs() && dy.abs() > 8) {
        dragAxis = 'v';
        final screenWidth = MediaQuery.of(context).size.width;
        isVolumeSide = _dragStartX >= screenWidth / 2;

        if (isVolumeSide) {
          _volumeStartValue = c.value.volume;
          previewVolumeNotifier.value = _volumeStartValue;
          showVolumeUINotifier.value = true;
        } else if (handleLeftVerticalDrag) {
          // 左侧垂直滑动由子类处理
        } else {
          // 左侧不处理，取消拖动
          isDragging = false;
          dragAxis = null;
          return;
        }
        if (mounted) setState(() {});
      }
      return;
    }

    if (dragAxis == 'h') {
      final seekMs = (dx * _kSeekPerPixelMs).toInt();
      var target = dragStartPosition + Duration(milliseconds: seekMs);
      final duration = c.value.duration;
      if (target < Duration.zero) target = Duration.zero;
      if (duration > Duration.zero && target > duration) target = duration;
      previewPositionNotifier.value = target;
    } else if (dragAxis == 'v') {
      final screenHeight = MediaQuery.of(context).size.height;
      final delta = -dy / (screenHeight * 0.6);

      if (isVolumeSide) {
        var newVolume = (_volumeStartValue + delta).clamp(0.0, 1.0);
        previewVolumeNotifier.value = newVolume;
        try {
          onSetVolume(newVolume);
        } catch (_) {}
      } else {
        onLeftVerticalDragUpdate(delta);
      }
    }
  }

  void onPanEnd(DragEndDetails d) {
    endDrag();
  }

  void onPanCancel() {
    isDragging = false;
    dragAxis = null;
    if (mounted) setState(() {});
  }

  // ==================== 水平拖动（小屏模式）====================

  void onHorizontalDragStart(DragStartDetails d) {
    if (!gesturesEnabled) return;
    _cancelSingleTap();
    final c = videoController;
    if (c == null || !c.value.isInitialized) return;
    isDragging = true;
    dragAxis = 'h';
    _dragStartX = d.globalPosition.dx;
    dragStartPosition = c.value.position;
    previewPositionNotifier.value = c.value.position;
    _dragHideTimer?.cancel();
    HapticFeedback.selectionClick();
    if (mounted) setState(() {});
  }

  void onHorizontalDragUpdate(DragUpdateDetails d) {
    if (!isDragging || dragAxis != 'h') return;
    final c = videoController;
    if (c == null || !c.value.isInitialized) return;
    final dx = d.globalPosition.dx - _dragStartX;
    final seekMs = (dx * _kSeekPerPixelMs).toInt();
    var target = dragStartPosition + Duration(milliseconds: seekMs);
    final duration = c.value.duration;
    if (target < Duration.zero) target = Duration.zero;
    if (duration > Duration.zero && target > duration) target = duration;
    previewPositionNotifier.value = target;
  }

  void onHorizontalDragEnd(DragEndDetails d) {
    endDrag();
  }

  void onHorizontalDragCancel() {
    isDragging = false;
    dragAxis = null;
    if (mounted) setState(() {});
  }

  // ==================== 公共方法 ====================

  void endDrag() {
    final c = videoController;
    _volumeHideTimer?.cancel();

    if (dragAxis == 'h') {
      if (c != null && c.value.isInitialized) {
        try {
          final duration = c.value.duration;
          var target = previewPositionNotifier.value;
          if (target < Duration.zero) target = Duration.zero;
          if (duration > Duration.zero && target > duration) target = duration;
          onSeekTo(target);
          HapticFeedback.lightImpact();
        } catch (e) {
          AppLogger.debug('拖动进度seek失败', data: {'error': e.toString()});
        }
      }
      _dragHideTimer?.cancel();
      _dragHideTimer = Timer(_kDragHideDelay, () {
        if (!mounted) return;
        previewPositionNotifier.value = Duration.zero;
        dragStartPosition = Duration.zero;
      });
    } else if (dragAxis == 'v' && isVolumeSide) {
      _volumeHideTimer = Timer(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        showVolumeUINotifier.value = false;
      });
    }

    isDragging = false;
    dragAxis = null;
    if (mounted) setState(() {});
  }

  // ==================== 长按倍速 ====================

  void onLongPressStart(LongPressStartDetails details) {
    if (!gesturesEnabled) return;
    final c = videoController;
    if (c == null || !c.value.isInitialized) return;
    try {
      _isLongPressing = true;
      originalRate = c.value.playbackSpeed;
      c.setPlaybackSpeed(_kLongPressRate);
      showSpeedBadgeNotifier.value = true;
    } catch (e) {
      AppLogger.debug('长按倍速启动失败', data: {'error': e.toString()});
    }
  }

  void onLongPressEnd(LongPressEndDetails details) {
    if (!_isLongPressing) return;
    _isLongPressing = false;
    final c = videoController;
    if (c == null || !c.value.isInitialized) return;
    try {
      c.setPlaybackSpeed(originalRate);
    } catch (e) {
      AppLogger.debug('长按倍速结束失败', data: {'error': e.toString()});
    }
    showSpeedBadgeNotifier.value = false;
  }

  // ==================== 爱心动画 ====================

  void triggerHeart() {
    if (!mounted) return;
    setState(() => showHeart = true);
    _heartHideTimer?.cancel();
    _heartHideTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => showHeart = false);
    });
  }

  // ==================== 资源清理 ====================

  void disposeGestureTimers() {
    _singleTapTimer?.cancel();
    _dragHideTimer?.cancel();
    _volumeHideTimer?.cancel();
    _seekFeedbackResetTimer?.cancel();
    _heartHideTimer?.cancel();
    previewPositionNotifier.dispose();
    previewVolumeNotifier.dispose();
    showVolumeUINotifier.dispose();
    showSpeedBadgeNotifier.dispose();
  }
}
