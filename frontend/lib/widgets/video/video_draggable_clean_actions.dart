// 纯净模式下的可拖动按钮区组件
// 初始位置：屏幕右下角（受 bottomSafeArea 和 rightSafeArea 约束）
//
// PR #71：自动隐藏
// - 视频开始播放 4 秒后自动隐藏，保持 UI 纯净
// - 视频暂停 / 控制条显示 / 单击屏幕时重新显示
// - 用户拖动按钮后保留显示（不再自动隐藏，让用户看清新位置）
//
// PR #74：纯净模式下按钮持续隐藏
// - show() / hide() 是被动调用（isPlaying 变化、单击屏幕等）
// - 纯净模式下这些被动调用不再显示按钮（继续 _isHidden = true）
// - 用户主动操作按钮（onPointerDown）仍然能强制显示（直接 setState 绕过）

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';

class DraggableCleanActions extends ConsumerStatefulWidget {
  final Size containerSize;
  final double buttonWidth;
  final Widget buttons;
  final double bottomSafeArea; // 底部安全区（导航栏 + 手势条 + 边距）
  final double rightSafeArea; // 右侧安全区（边距）
  /// 自动隐藏延迟。传 [Duration.zero] 禁用自动隐藏（永久可见）。
  final Duration autoHideAfter;

  const DraggableCleanActions({
    super.key,
    required this.containerSize,
    required this.buttonWidth,
    required this.buttons,
    this.bottomSafeArea = 100,
    this.rightSafeArea = 16,
    this.autoHideAfter = const Duration(seconds: 4),
  });

  @override
  DraggableCleanActionsState createState() => DraggableCleanActionsState();
}

class DraggableCleanActionsState extends ConsumerState<DraggableCleanActions> {
  late Offset _offset;
  Offset? _startPointer;
  Offset? _startOffset;
  bool _isDragging = false;
  double _dragDistance = 0.0;
  // PR #71：auto-hide 状态
  bool _isHidden = false;
  // 用户是否已经拖动过；拖动后停止 auto-hide 让用户看清新位置
  bool _userInteracted = false;
  Timer? _autoHideTimer;
  // PR #74：纯净模式缓存（由 ref.listen 在 build 中同步）
  // 用缓存字段避免在 show()/hide() 中直接 ref.read（State 中拿 ref 不安全）
  bool _isAutoPlay = false;

  static const double _kDragThreshold = 10.0;
  static const double _kScaleFactor = 1.1;
  static const int _kHeightApprox = 140;

  @override
  void initState() {
    super.initState();
    _offset = Offset(
      widget.containerSize.width - widget.buttonWidth - widget.rightSafeArea,
      widget.containerSize.height - _kHeightApprox - widget.bottomSafeArea,
    );
    // 帧挂载后启动 auto-hide 定时器（先短暂显示，再隐藏）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scheduleAutoHide();
    });
  }

  @override
  void didUpdateWidget(covariant DraggableCleanActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.containerSize != widget.containerSize) {
      setState(() {
        _offset = Offset(
          _offset.dx.clamp(0.0, widget.containerSize.width - widget.buttonWidth),
          _offset.dy.clamp(0.0, widget.containerSize.height - _kHeightApprox),
        );
      });
    }
    // autoHideAfter 配置变化时重启定时器
    if (oldWidget.autoHideAfter != widget.autoHideAfter) {
      _scheduleAutoHide();
    }
  }

  @override
  void dispose() {
    _autoHideTimer?.cancel();
    super.dispose();
  }

  /// 调度自动隐藏（PR #71）
  ///
  /// 规则：
  /// - 拖动过的按钮组不再自动隐藏
  /// - autoHideAfter = Duration.zero 表示禁用
  void _scheduleAutoHide() {
    _autoHideTimer?.cancel();
    if (_userInteracted) return;
    if (widget.autoHideAfter == Duration.zero) return;
    _autoHideTimer = Timer(widget.autoHideAfter, () {
      if (!mounted) return;
      setState(() => _isHidden = true);
    });
  }

  /// 外部触发显示（视频暂停 / 控制条显示 / 单击屏幕时调用）
  ///
  /// 显示后按当前 [autoHideAfter] 重新调度隐藏。
  ///
  /// PR #74：纯净模式下按钮持续隐藏
  /// - 纯净模式设计意图是"按钮永不显示"，但 PR #71 留了几个 show() 入口
  ///   （isPlaying 变化、控制条显示、单击屏幕等），这些入口在纯净模式下应该无效
  /// - 这里直接 return，不改变 _isHidden，也不调度 timer
  /// - 用户主动操作按钮的 onPointerDown 仍然能强制显示（不经过本方法）
  void show() {
    if (!mounted) return;
    if (_isAutoPlay) {
      // 纯净模式：保持隐藏，不响应被动 show() 调用
      return;
    }
    if (_isHidden) {
      setState(() => _isHidden = false);
    }
    _scheduleAutoHide();
  }

  /// 外部触发立即隐藏
  void hide() {
    if (!mounted) return;
    _autoHideTimer?.cancel();
    if (!_isHidden) {
      setState(() => _isHidden = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // PR #74：纯净模式缓存同步
    // - ref.listen：异步同步到本地字段，触发 setState 不需要
    // - ref.watch：触发当前 build（如果 isAutoPlay 变化，DraggableCleanActions 会重建）
    // 这样 show() 调 _isAutoPlay 时拿到最新值
    ref.listen<bool>(isAutoPlayProvider, (prev, next) {
      _isAutoPlay = next;
    });
    _isAutoPlay = ref.watch(isAutoPlayProvider);
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        AnimatedPositioned(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          left: _offset.dx,
          top: _offset.dy,
          child: AnimatedOpacity(
            // PR #71：用 _isHidden 控制淡入淡出
            opacity: _isHidden ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            child: Listener(
              // PR #74：纯净模式下按钮持续隐藏
              // onPointerDown 是 PR #71 设计的"用户主动操作按钮就强制显示"逻辑
              // 但纯净模式下应该不响应 → 直接 return，不记录 pointer，不显示按钮
              onPointerDown: (event) {
                if (_isAutoPlay) {
                  // 纯净模式：保持隐藏，不响应任何被动 pointer 事件
                  // （包括单指按压、双指按压等所有 onPointerDown）
                  return;
                }
                _startPointer = event.localPosition;
                _startOffset = _offset;
                _dragDistance = 0.0;
                // PR #71：用户开始交互，停止 auto-hide 并强制显示
                _userInteracted = true;
                _autoHideTimer?.cancel();
                if (_isHidden) {
                  setState(() => _isHidden = false);
                }
              },
              onPointerMove: (event) {
                if (_startPointer == null || _startOffset == null) return;
                final delta = event.localPosition - _startPointer!;
                _dragDistance = delta.distance;

                if (!_isDragging && _dragDistance > _kDragThreshold) {
                  setState(() => _isDragging = true);
                }

                if (_isDragging) {
                  setState(() {
                    double newX = _startOffset!.dx + delta.dx;
                    double newY = _startOffset!.dy + delta.dy;
                    newX = newX.clamp(
                        0.0, widget.containerSize.width - widget.buttonWidth);
                    newY = newY
                        .clamp(0.0, widget.containerSize.height - _kHeightApprox);
                    _offset = Offset(newX, newY);
                  });
                }
              },
              onPointerUp: (_) {
                _startPointer = null;
                _startOffset = null;
                if (_isDragging) setState(() => _isDragging = false);
                _dragDistance = 0.0;
              },
              child: IgnorePointer(
                // 隐藏时不接收点击，避免透明区域拦截手势
                ignoring: _isDragging || _isHidden,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  transform: Matrix4.identity()
                    ..scale(_isDragging ? _kScaleFactor : 1.0),
                  child: Container(
                    width: widget.buttonWidth,
                    height: _kHeightApprox.toDouble(),
                    padding: const EdgeInsets.only(right: 16),
                    alignment: Alignment.centerRight,
                    decoration: _isDragging
                        ? BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: scheme.onSurface.withOpacity(0.25),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ],
                          )
                        : null,
                    child: widget.buttons,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
