// 音频会话管理器：管理音频焦点，处理来电/其他 App 播放时的暂停和恢复
//
// 职责：
// - 播放开始时请求音频焦点
// - 来电/其他 App 播放时自动暂停（焦点丢失）
// - 焦点恢复时根据设置决定是否续播
// - 播放停止时释放音频焦点
//
// 说明：基于 audio_session ^0.1.21 的实际 API 实现：
// - 中断事件通过 event.begin (bool) 区分开始/结束
// - event.type 取值为 pause / duck / unknown（非 began/ended）

import 'dart:async';

import 'package:audio_session/audio_session.dart';

import '../utils/logger.dart';

/// 音频会话处理器
///
/// 通过 [audio_session] 插件管理 Android/iOS 音频焦点：
/// - 播放前调用 [requestFocus] 申请焦点
/// - 来电、其他 App 播放等中断事件触发时通过回调通知上层暂停
/// - 中断结束后通过回调通知上层续播
/// - 播放停止后调用 [releaseFocus] 释放焦点
///
/// 上层通过设置 [onPauseRequested]、[onResumeRequested]、[isPlaying] 三个回调
/// 与播放状态联动，本类不直接持有任何播放器引用。
class AudioSessionHandler {
  AudioSession? _session;

  // 是否已因中断暂停：用于区分"被中断暂停"和"用户主动暂停"
  // 仅当焦点丢失导致暂停时为 true，中断结束时据此判断是否续播
  bool _isPausedByInterruption = false;

  // 中断事件流订阅，dispose 时取消
  StreamSubscription<AudioInterruptionEvent>? _interruptionSubscription;

  /// 回调：焦点丢失时暂停播放（由上层注入）
  void Function()? onPauseRequested;

  /// 回调：焦点恢复时续播（由上层注入）
  void Function()? onResumeRequested;

  /// 回调：判断当前是否正在播放（由上层注入）
  bool Function()? isPlaying;

  /// 初始化音频会话，注册中断监听
  ///
  /// 幂等：多次调用不会重复创建会话或重复订阅。
  /// 配置为媒体播放类型（movie + media），与视频播放语义一致。
  Future<void> init() async {
    // 已初始化则跳过
    if (_session != null) return;

    try {
      _session = await AudioSession.instance;
      await _session!.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.allowBluetooth,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.movie,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: true,
      ));

      // 注册中断事件监听（来电、其他 App 抢占焦点等）
      _interruptionSubscription =
          _session!.interruptionEventStream.listen(_handleInterruption);
    } catch (e) {
      AppLogger.warn('音频会话初始化失败', data: {'error': e.toString()});
    }
  }

  /// 处理音频焦点中断事件
  ///
  /// audio_session 0.1.21 的 API：
  /// - event.begin == true：中断开始（如来电）
  /// - event.begin == false：中断结束
  /// - event.type：pause / duck / unknown（中断类型，本类不细分）
  void _handleInterruption(AudioInterruptionEvent event) {
    if (event.begin) {
      // 焦点丢失开始（来电等）
      // 仅在正在播放时暂停，避免对已暂停的视频误标记
      if (isPlaying?.call() == true) {
        _isPausedByInterruption = true;
        onPauseRequested?.call();
      }
    } else {
      // 焦点恢复：仅当本次暂停是由中断引起时才尝试续播
      if (_isPausedByInterruption) {
        _isPausedByInterruption = false;
        onResumeRequested?.call();
      }
    }
  }

  /// 请求音频焦点（播放开始时调用）
  ///
  /// 返回 true 表示焦点申请成功，可以播放；
  /// 返回 false 表示申请失败（如系统拒绝或其他 App 持有更高优先级焦点）。
  Future<bool> requestFocus() async {
    // 懒初始化：首次调用时完成会话配置与监听注册
    if (_session == null) {
      await init();
    }
    if (_session == null) {
      // init 失败兜底
      return false;
    }
    try {
      return await _session!.setActive(true);
    } catch (e) {
      AppLogger.warn('请求音频焦点失败', data: {'error': e.toString()});
      return false;
    }
  }

  /// 释放音频焦点（播放停止时调用）
  ///
  /// 通知系统本 App 不再占用音频焦点，其他 App 可恢复播放。
  Future<void> releaseFocus() async {
    try {
      await _session?.setActive(false);
    } catch (e) {
      AppLogger.warn('释放音频焦点失败', data: {'error': e.toString()});
    }
  }

  /// 释放资源：取消订阅、清理回调引用
  ///
  /// 注意：本方法不释放 AudioSession 单例（由插件全局持有），
  /// 仅清理本实例的监听与回调，避免内存泄漏。
  void dispose() {
    _interruptionSubscription?.cancel();
    _interruptionSubscription = null;
    _session = null;
    _isPausedByInterruption = false;
    onPauseRequested = null;
    onResumeRequested = null;
    isPlaying = null;
  }
}
