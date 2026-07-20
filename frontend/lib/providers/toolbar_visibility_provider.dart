// 工具栏可见性状态管理
// 全局单一状态：true = 显示；false = 隐藏
// 通过 Riverpod StateNotifier 实现防抖与状态去重
//
// 隐藏语义（PR #72）：
// - 纯净模式（isAutoPlay=true）时持续 hide（独立维度）
// - 全屏 push/pop 用引用计数 hide/show（临时）
// - state = (纯净模式未开) AND (全屏引用计数 == 0) AND (普通 hideCount == 0)

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/constants.dart';

/// 工具栏可见性通知器
///
/// 提供 `show()` / `hide()` / `toggle()` 三个显式方法，
/// 内部维护 `_lastSetAt` 时间戳用于防抖：
/// 两次状态变更请求间隔小于 `kToolbarHideDelayMs` 时忽略。
class ToolbarVisibilityNotifier extends StateNotifier<bool> {
  ToolbarVisibilityNotifier() : super(true);

  DateTime _lastSetAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _lastRequestedVisible = true;

  // PR #72：纯净模式标志（独立维度）
  // 进入纯净模式时调用 setAutoPlayActive(true)，工具栏持续 hide；
  // 退出纯净模式时调用 setAutoPlayActive(false)。
  bool _autoPlayActive = false;

  // PR #72：普通 hide/show 引用计数
  // 全屏 push/pop 等临时场景下配对调用 hide()/show()。
  int _hideCount = 0;

  /// 显示工具栏
  void show() {
    if (_hideCount > 0) _hideCount--;
    else if (_hideCount < 0) _hideCount = 0;
    _setVisible(_recompute());
  }

  /// 隐藏工具栏
  void hide() {
    _hideCount++;
    _setVisible(_recompute());
  }

  /// 切换显示/隐藏
  ///
  /// 注意：纯净模式下工具栏持续隐藏，toggle() 不会改变状态。
  void toggle() {
    if (_autoPlayActive) return;
    if (_hideCount == 0) {
      hide();
    } else {
      show();
    }
  }

  /// PR #72：同步纯净模式状态
  ///
  /// 由 video_page_item 监听 isAutoPlayProvider 时调用：
  /// - isAutoPlay=true → 工具栏持续隐藏（与全屏 hide 状态独立）
  /// - isAutoPlay=false → 工具栏恢复显示（除非还有全屏引用计数）
  void setAutoPlayActive(bool active) {
    if (_autoPlayActive == active) return;
    _autoPlayActive = active;
    _setVisible(_recompute());
  }

  /// 重新计算 state（基于三个维度的与运算）
  ///
  /// 仅返回计算值，不直接修改 state，由调用方通过 _setVisible() 统一决定。
  bool _recompute() {
    return !_autoPlayActive && _hideCount == 0;
  }

  /// 核心设置方法：防抖 + 去重
  void _setVisible(bool visible) {
    // 与当前状态相同，直接跳过（去重）
    if (visible == state) return;
    final now = DateTime.now();
    final diff = now.difference(_lastSetAt).inMilliseconds;
    // 防抖：距离上一次设置小于 kToolbarHideDelayMs 时忽略
    if (diff < kToolbarHideDelayMs && visible == _lastRequestedVisible) return;
    _lastSetAt = now;
    _lastRequestedVisible = visible;
    state = visible;
  }
}

/// 工具栏可见性 Provider
///
/// 使用方式：
/// ```dart
/// // 读取当前值
/// final visible = ref.read(toolbarVisibilityProvider);
/// // 修改值
/// ref.read(toolbarVisibilityProvider.notifier).hide();
/// // 监听（用于动画驱动）
/// final visible = ref.watch(toolbarVisibilityProvider);
/// ```
final toolbarVisibilityProvider =
    StateNotifierProvider<ToolbarVisibilityNotifier, bool>(
  (ref) => ToolbarVisibilityNotifier(),
);
