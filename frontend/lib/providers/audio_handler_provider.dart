// AudioHandler Provider：全局管理 EmbytokAudioHandler 的生命周期
//
// 设计说明：
// - 通过 Provider 持有 EmbytokAudioHandler 单例，整个 App 共享一个实例
// - 在 App 启动时（app.dart 的 initState）通过 AudioService.init 注册到系统，
//   注册后即可接收锁屏/通知栏的媒体按钮事件
// - Handler 内部通过 Ref 读写其他 Provider，与现有播放状态体系（currentVideoControllerProvider
//   等）解耦，仅在媒体按钮触发时单向操作播放器

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/embytok_audio_handler.dart';

/// 全局 AudioHandler Provider
///
/// 使用方式：
/// ```dart
/// // App 启动时注册到 AudioService（一次性初始化）
/// await AudioService.init(
///   builder: () => ref.read(audioHandlerProvider),
///   config: const AudioServiceConfig(...),
/// );
///
/// // 业务层调用 setMediaItem / updatePlaybackState 更新 MediaSession
/// ref.read(audioHandlerProvider).setMediaItem(...);
/// ```
final audioHandlerProvider = Provider<EmbytokAudioHandler>((ref) {
  return EmbytokAudioHandler(ref);
});
