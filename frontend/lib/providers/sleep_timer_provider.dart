import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 睡眠定时器状态
class SleepTimerState {
  final Duration? remaining;
  final bool isActive;
  final bool stopAfterCurrent;

  const SleepTimerState({
    this.remaining,
    this.isActive = false,
    this.stopAfterCurrent = false,
  });

  SleepTimerState copyWith({
    Duration? remaining,
    bool? isActive,
    bool? stopAfterCurrent,
  }) {
    return SleepTimerState(
      remaining: remaining ?? this.remaining,
      isActive: isActive ?? this.isActive,
      stopAfterCurrent: stopAfterCurrent ?? this.stopAfterCurrent,
    );
  }
}

/// 睡眠定时器 Provider
/// 倒计时结束时调用 onTimeout 回调暂停播放
class SleepTimerNotifier extends StateNotifier<SleepTimerState> {
  Timer? _timer;
  VoidCallback? _onTimeout;

  SleepTimerNotifier() : super(const SleepTimerState());

  /// 设置超时回调（由播放器注册）
  void setOnTimeout(VoidCallback callback) {
    _onTimeout = callback;
  }

  /// 启动倒计时
  void start(Duration duration) {
    cancel();
    state = SleepTimerState(
      remaining: duration,
      isActive: true,
    );
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final remaining = state.remaining;
      if (remaining == null || remaining.inSeconds <= 1) {
        _fireTimeout();
      } else {
        state = state.copyWith(remaining: remaining - const Duration(seconds: 1));
      }
    });
  }

  /// 设置当前视频结束后暂停
  void setStopAfterCurrent() {
    cancel();
    state = const SleepTimerState(
      isActive: true,
      stopAfterCurrent: true,
    );
  }

  /// 当前视频结束时调用（由播放器在 onPlayerCompleted 中触发）
  void onCurrentVideoCompleted() {
    if (state.stopAfterCurrent) {
      _fireTimeout();
    }
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
    state = const SleepTimerState();
  }

  void _fireTimeout() {
    _timer?.cancel();
    _timer = null;
    _onTimeout?.call();
    state = const SleepTimerState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final sleepTimerProvider =
    StateNotifierProvider<SleepTimerNotifier, SleepTimerState>(
        (ref) => SleepTimerNotifier());
