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

  VideoPlayerController? get _videoController;

  bool get _gesturesEnabled => true;

  void _onSingleTap();

  void _onDoubleTapLeft() => _seekBySeconds(-10);

  void _onDoubleTapRight() => _seekBySeconds(10);

  void _onDoubleTapCenter();

  bool get _handleLeftVerticalDrag => false;

  void _onLeftVerticalDragUpdate(double delta) {}

  void _onSeekTo(Duration target) {
    _videoController?.seekTo(target);
  }

  void _onSetVolume(double value) {
    _videoController?.setVolume(value);
  }

  MediaItem? get _currentItem => null;

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
  bool _isDragging = false;
  String? _dragAxis;
  double _dragStartX = 0.0;
  double _dragStartY = 0.0;

  // 水平 seek
  Duration _dragStartPosition = Duration.zero;
  final _previewPositionNotifier = ValueNotifier<Duration>(Duration.zero);

  // 垂直音量
  bool _isVolumeSide = false;
  double _volumeStartValue = 0.0;
  final _previewVolumeNotifier = ValueNotifier<double>(0.0);
  final _showVolumeUINotifier = ValueNotifier<bool>(false);
  Timer? _volumeHideTimer;

  // 长按倍速
  bool _isLongPressing = false;
  double _originalRate = 1.0;
  final _showSpeedBadgeNotifier = ValueNotifier<bool>(false);

  // 双击 seek 反馈
  bool _showSeekFeedback = false;
  bool _isSeekForward = false;
  int _seekFeedbackCount = 0;
  Timer? _seekFeedbackResetTimer;

  // 爱心动画
  bool _showHeart = false;
  Timer? _heartHideTimer;

  // 拖动隐藏延迟
  Timer? _dragHideTimer;

  // ==================== 单击/双击 ====================

  void _handleTap() {
    if (!_gesturesEnabled) return;
    if (_isDragging) return;
    if (_pendingSingleTap) {
      _singleTapTimer?.cancel();
      _pendingSingleTap = false;
      _onDoubleTap();
    } else {
      _pendingSingleTap = true;
      _singleTapTimer = Timer(_kSingleTapDelay, () {
        if (_pendingSingleTap && mounted) {
          _pendingSingleTap = false;
          _onSingleTap();
        }
      });
    }
  }

  void _handleTapDown(TapDownDetails details) {
    _lastTapPosition = details.globalPosition;
  }

  void _onDoubleTap() {
    if (!mounted) return;
    final pos = _lastTapPosition;
    final c = _videoController;

    if (pos != null && c != null && c.value.isInitialized) {
      final screenWidth = MediaQuery.of(context).size.width;
      final relativeX = pos.dx / screenWidth;
      if (relativeX < 0.33) {
        _onDoubleTapLeft();
        return;
      } else if (relativeX > 0.67) {
        _onDoubleTapRight();
        return;
      }
    }

    _onDoubleTapCenter();
  }

  void _showSeekFeedbackAnimation(bool forward) {
    _seekFeedbackResetTimer?.cancel();
    if (_showSeekFeedback && _isSeekForward == forward) {
      _seekFeedbackCount++;
    } else {
      _seekFeedbackCount = 1;
    }
    if (!mounted) return;
    setState(() {
      _isSeekForward = forward;
      _showSeekFeedback = true;
    });
    _seekFeedbackResetTimer = Timer(_kDragHideDelay, () {
      if (mounted) {
        setState(() {
          _showSeekFeedback = false;
          _seekFeedbackCount = 0;
        });
      }
    });
  }

  void _seekBySeconds(int seconds) {
    final c = _videoController;
    if (c == null || !c.value.isInitialized) return;
    try {
      final current = c.value.position;
      final duration = c.value.duration;
      var target = current + Duration(seconds: seconds);
      if (target < Duration.zero) target = Duration.zero;
      if (duration > Duration.zero && target > duration) target = duration;
      _onSeekTo(target);
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

  void _onPanStart(DragStartDetails d) {
    if (!_gesturesEnabled) return;
    _cancelSingleTap();
    final c = _videoController;
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
    final c = _videoController;
    if (c == null || !c.value.isInitialized) return;

    final dx = d.globalPosition.dx - _dragStartX;
    final dy = d.globalPosition.dy - _dragStartY;

    if (_dragAxis == null) {
      if (dx.abs() > dy.abs() && dx.abs() > 8) {
        _dragAxis = 'h';
        _dragStartPosition = c.value.position;
        _previewPositionNotifier.value = c.value.position;
        HapticFeedback.selectionClick();
        if (mounted) setState(() {});
      } else if (dy.abs() > dx.abs() && dy.abs() > 8) {
        _dragAxis = 'v';
        final screenWidth = MediaQuery.of(context).size.width;
        _isVolumeSide = _dragStartX >= screenWidth / 2;

        if (_isVolumeSide) {
          _volumeStartValue = c.value.volume;
          _previewVolumeNotifier.value = _volumeStartValue;
          _showVolumeUINotifier.value = true;
        } else if (_handleLeftVerticalDrag) {
          // 左侧垂直滑动由子类处理
        } else {
          // 左侧不处理，取消拖动
          _isDragging = false;
          _dragAxis = null;
          return;
        }
        if (mounted) setState(() {});
      }
      return;
    }

    if (_dragAxis == 'h') {
      final seekMs = (dx * _kSeekPerPixelMs).toInt();
      var target = _dragStartPosition + Duration(milliseconds: seekMs);
      final duration = c.value.duration;
      if (target < Duration.zero) target = Duration.zero;
      if (duration > Duration.zero && target > duration) target = duration;
      _previewPositionNotifier.value = target;
    } else if (_dragAxis == 'v') {
      final screenHeight = MediaQuery.of(context).size.height;
      final delta = -dy / (screenHeight * 0.6);

      if (_isVolumeSide) {
        var newVolume = (_volumeStartValue + delta).clamp(0.0, 1.0);
        _previewVolumeNotifier.value = newVolume;
        try {
          _onSetVolume(newVolume);
        } catch (_) {}
      } else {
        _onLeftVerticalDragUpdate(delta);
      }
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

  // ==================== 水平拖动（小屏模式）====================

  void _onHorizontalDragStart(DragStartDetails d) {
    if (!_gesturesEnabled) return;
    _cancelSingleTap();
    final c = _videoController;
    if (c == null || !c.value.isInitialized) return;
    _isDragging = true;
    _dragAxis = 'h';
    _dragStartX = d.globalPosition.dx;
    _dragStartPosition = c.value.position;
    _previewPositionNotifier.value = c.value.position;
    _dragHideTimer?.cancel();
    HapticFeedback.selectionClick();
    if (mounted) setState(() {});
  }

  void _onHorizontalDragUpdate(DragUpdateDetails d) {
    if (!_isDragging || _dragAxis != 'h') return;
    final c = _videoController;
    if (c == null || !c.value.isInitialized) return;
    final dx = d.globalPosition.dx - _dragStartX;
    final seekMs = (dx * _kSeekPerPixelMs).toInt();
    var target = _dragStartPosition + Duration(milliseconds: seekMs);
    final duration = c.value.duration;
    if (target < Duration.zero) target = Duration.zero;
    if (duration > Duration.zero && target > duration) target = duration;
    _previewPositionNotifier.value = target;
  }

  void _onHorizontalDragEnd(DragEndDetails d) {
    _endDrag();
  }

  void _onHorizontalDragCancel() {
    _isDragging = false;
    _dragAxis = null;
    if (mounted) setState(() {});
  }

  // ==================== 公共方法 ====================

  void _endDrag() {
    final c = _videoController;
    _volumeHideTimer?.cancel();

    if (_dragAxis == 'h') {
      if (c != null && c.value.isInitialized) {
        try {
          final duration = c.value.duration;
          var target = _previewPositionNotifier.value;
          if (target < Duration.zero) target = Duration.zero;
          if (duration > Duration.zero && target > duration) target = duration;
          _onSeekTo(target);
          HapticFeedback.lightImpact();
        } catch (e) {
          AppLogger.debug('拖动进度seek失败', data: {'error': e.toString()});
        }
      }
      _dragHideTimer?.cancel();
      _dragHideTimer = Timer(_kDragHideDelay, () {
        if (!mounted) return;
        _previewPositionNotifier.value = Duration.zero;
        _dragStartPosition = Duration.zero;
      });
    } else if (_dragAxis == 'v' && _isVolumeSide) {
      _volumeHideTimer = Timer(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        _showVolumeUINotifier.value = false;
      });
    }

    _isDragging = false;
    _dragAxis = null;
    if (mounted) setState(() {});
  }

  // ==================== 长按倍速 ====================

  void _onLongPressStart(LongPressStartDetails details) {
    if (!_gesturesEnabled) return;
    final c = _videoController;
    if (c == null || !c.value.isInitialized) return;
    try {
      _isLongPressing = true;
      _originalRate = c.value.playbackSpeed;
      c.setPlaybackSpeed(_kLongPressRate);
      _showSpeedBadgeNotifier.value = true;
    } catch (e) {
      AppLogger.debug('长按倍速启动失败', data: {'error': e.toString()});
    }
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    if (!_isLongPressing) return;
    _isLongPressing = false;
    final c = _videoController;
    if (c == null || !c.value.isInitialized) return;
    try {
      c.setPlaybackSpeed(_originalRate);
    } catch (e) {
      AppLogger.debug('长按倍速结束失败', data: {'error': e.toString()});
    }
    _showSpeedBadgeNotifier.value = false;
  }

  // ==================== 爱心动画 ====================

  void _triggerHeart() {
    if (!mounted) return;
    setState(() => _showHeart = true);
    _heartHideTimer?.cancel();
    _heartHideTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _showHeart = false);
    });
  }

  // ==================== 资源清理 ====================

  void _disposeGestureTimers() {
    _singleTapTimer?.cancel();
    _dragHideTimer?.cancel();
    _volumeHideTimer?.cancel();
    _seekFeedbackResetTimer?.cancel();
    _heartHideTimer?.cancel();
    _previewPositionNotifier.dispose();
    _previewVolumeNotifier.dispose();
    _showVolumeUINotifier.dispose();
    _showSpeedBadgeNotifier.dispose();
  }
}
