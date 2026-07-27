// EmbyTok 音频处理器：实现 MediaSession，支持锁屏/通知栏媒体控制
//
// 职责：
// - 播放/暂停/停止：通过 currentVideoControllerProvider 控制实际播放器
// - 下一集：通过 feedViewPageJumpRequestProvider 触发 feed_view_model 的下一集跳转
// - MediaSession 状态同步：播放状态变化时更新 MediaSession，显示标题、封面等
//
// 设计说明：
// - 继承 BaseAudioHandler（audio_service 0.18.x）获得 playbackState / mediaItem 等
//   BehaviorSubject，系统媒体按钮事件会路由到对应的 play/pause/stop/skipToNext 方法
// - mixin SeekHandler：复用 audio_service 提供的 seek 请求默认处理
//   （通过 seekStream 暴露，后续如需锁屏 seek 可由调用方订阅）
// - 不直接持有 VideoPlayerController，通过 Provider 间接访问，避免 widget 重建时引用错位

import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/video_list_provider.dart';
// 注意：video_playback_controller.dart 定义的 PlaybackState 类与 audio_service 的同名，
// 这里 hide 掉本项目的 PlaybackState，让 audio_service.PlaybackState 在本文件中可见
// （用于 playbackState.add(PlaybackState(...))）。playbackStateProvider 的返回类型
// 仍由类型推断正确解析，访问 .id 字段不受影响。
import '../providers/video_playback_controller.dart' hide PlaybackState;
import '../utils/logger.dart';

class EmbytokAudioHandler extends BaseAudioHandler with SeekHandler {
  final Ref _ref;

  EmbytokAudioHandler(this._ref);

  // ==================== BaseAudioHandler 实现 ====================

  @override
  Future<void> play() async {
    // 通过 currentVideoControllerProvider 获取播放器并播放
    final controller = _ref.read(currentVideoControllerProvider);
    if (controller != null && controller.value.isInitialized) {
      await controller.play();
    }
  }

  @override
  Future<void> pause() async {
    final controller = _ref.read(currentVideoControllerProvider);
    if (controller != null && controller.value.isInitialized) {
      await controller.pause();
    }
  }

  @override
  Future<void> stop() async {
    // 停止播放：仅暂停视频，不释放 controller（由 VideoPageItem 管理生命周期）
    final controller = _ref.read(currentVideoControllerProvider);
    if (controller != null && controller.value.isInitialized) {
      await controller.pause();
    }
    // 清除 MediaSession：通知栏移除媒体控制按钮
    playbackState.add(PlaybackState(
      controls: const [],
      playing: false,
      processingState: AudioProcessingState.idle,
    ));
  }

  @override
  Future<void> skipToNext() async {
    // 触发下一集跳转：通过 feedViewPageJumpRequestProvider 通知 FeedViewModel
    // FeedViewModel 监听该 Provider 并执行 PageController 跳页（见 feed_view_model.dart）
    //
    // 当前 index 通过 playbackStateProvider 的 id 在 videoList 中线性查找得到，
    // 不直接依赖 feedCurrentIndexProvider，避免与 feed_view_model.dart 形成循环 import
    // （feed_view_model.dart -> providers.dart -> audio_handler_provider.dart -> 本文件）
    final currentItem = _ref.read(playbackStateProvider);
    final videoState = _ref.read(videoListProvider);
    final items = videoState.items;
    if (items.isEmpty) {
      AppLogger.debug('AudioHandler: 视频列表为空，无法跳到下一集');
      return;
    }
    final currentId = currentItem.id;
    if (currentId == null) {
      AppLogger.debug('AudioHandler: 无当前播放项，无法跳到下一集');
      return;
    }
    final current = items.indexWhere((item) => item.id == currentId);
    if (current < 0) {
      AppLogger.debug('AudioHandler: 当前视频不在列表中，无法跳到下一集');
      return;
    }
    if (current < items.length - 1) {
      _ref.read(feedViewPageJumpRequestProvider.notifier).state = current + 1;
    } else {
      AppLogger.debug('AudioHandler: 已是最后一个视频，无法跳到下一集');
    }
  }

  // ==================== MediaSession 状态更新 ====================

  /// 更新 MediaSession 媒体项（播放开始时调用）
  ///
  /// 参数：
  /// - [title] 媒体标题（必填，显示在通知栏首行）
  /// - [artist] 艺术家/副标题（可选，如演员名、剧集信息）
  /// - [artUri] 封面图 URL（可选，需为完整 URL，用于通知栏背景/锁屏封面）
  /// - [duration] 媒体总时长（可选，用于锁屏进度条）
  void setMediaItem({
    required String title,
    String? artist,
    String? artUri,
    Duration? duration,
  }) {
    mediaItem.add(MediaItem(
      id: 'current',
      title: title,
      artist: artist,
      artUri: artUri != null ? Uri.tryParse(artUri) : null,
      duration: duration,
    ));
  }

  /// 更新播放状态（播放/暂停切换时调用）
  ///
  /// 参数：
  /// - [isPlaying] 是否正在播放
  /// - [position] 当前播放位置（可选，默认 Duration.zero）
  /// - [duration] 媒体总时长（可选，目前仅用于日志，进度条由系统根据 position 推算）
  ///
  /// 控件布局：
  /// - 播放中：[pause] [skipToNext] [stop]
  /// - 暂停时：[play]  [skipToNext] [stop]
  void updatePlaybackState({
    required bool isPlaying,
    Duration? position,
    Duration? duration,
  }) {
    final pos = position ?? Duration.zero;
    playbackState.add(PlaybackState(
      controls: [
        if (isPlaying) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1],
      playing: isPlaying,
      updatePosition: pos,
      bufferedPosition: pos,
      processingState: AudioProcessingState.ready,
    ));
  }
}
