// 工具栏可见性状态管理
// 全局单一状态：true = 显示；false = 隐藏
// 通过 Riverpod StateNotifier 实现防抖与状态去重

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

  /// 显示工具栏
  void show() {
    _setVisible(true);
  }

  /// 隐藏工具栏
  void hide() {
    _setVisible(false);
  }

  /// 切换显示/隐藏
  void toggle() {
    _setVisible(!state);
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
