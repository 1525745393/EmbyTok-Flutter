// 音频焦点 Provider：通过 Riverpod 管理音频焦点生命周期
//
// 设计要点：
// - AudioSessionHandler 为有状态对象，通过 Provider 单例化
// - 回调内部使用 ref.read 读取最新的 VideoPlayerController，
//   避免在 Provider 构造时一次性读取导致后续页面切换时引用过期
// - Provider dispose 时联动释放 Handler 资源

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/audio_session_handler.dart';
import 'video_playback_controller.dart';

/// 音频焦点处理器单例 Provider
///
/// 上层通过 `ref.read(audioSessionHandlerProvider)` 获取 [AudioSessionHandler]，
/// 在播放开始时调用 `requestFocus()`，播放停止时调用 `releaseFocus()`。
///
/// 中断事件（来电、其他 App 抢占焦点）会自动通过回调驱动
/// [currentVideoControllerProvider] 暂停/续播，无需上层额外处理。
///
/// 注意：回调内部使用 `ref.read` 实时读取 controller，确保页面切换后
/// 仍然作用于当前可见页的播放器，而非 Provider 构造时的快照。
final audioSessionHandlerProvider = Provider<AudioSessionHandler>((ref) {
  final handler = AudioSessionHandler();

  // 判断当前是否正在播放：实时读取最新 controller 的播放状态
  handler.isPlaying = () {
    final controller = ref.read(currentVideoControllerProvider);
    return controller?.value.isPlaying ?? false;
  };

  // 焦点丢失时暂停当前播放器
  handler.onPauseRequested = () {
    ref.read(currentVideoControllerProvider)?.pause();
  };

  // 焦点恢复时续播
  // 说明：此处直接续播；如未来需要"用户偏好控制是否自动续播"，
  // 可在此处读取偏好 Provider 后决定是否调用 play()。
  handler.onResumeRequested = () {
    final controller = ref.read(currentVideoControllerProvider);
    // 仅在 controller 存在且当前未播放时续播，避免重复调用
    if (controller != null && !controller.value.isPlaying) {
      controller.play();
    }
  };

  // Provider 销毁时联动清理 Handler 资源（取消订阅、清空回调）
  ref.onDispose(handler.dispose);

  return handler;
});
