import '../models/models.dart';

abstract interface class EmbyPlaybackApi {
  // ============================

  /// 获取播放信息
  Future<MediaItem?> getPlaybackInfo(
    String itemId, {
    String? serverUrl,
    String? token,
  });

  /// 从服务端获取指定项的最新播放进度
  ///
  /// 通过 GET /Users/{userId}/Items/{itemId} 获取 UserData.PlaybackPositionTicks。
  /// 用于播放开始时拉取服务端最新进度，实现多端进度互通。
  /// 返回值：PlaybackPositionTicks（单位：ticks，1 tick = 100 ns）
  /// 若无播放记录返回 0。
  Future<int> getPlaybackPosition(
    String itemId, {
    String? userId,
    String? serverUrl,
    String? token,
  });

  /// 字幕 Cues 加载（从服务器获取并解析 SRT/VTT）
  Future<List<SubtitleCue>> getSubtitleCues({
    required String itemId,
    required String mediaSourceId,
    required int index,
    String format = 'srt',
    String? directUrl,
    String? serverUrl,
    String? token,
  });

  /// 清空字幕缓存（视频切换或用户登出时调用）
  void clearSubtitleCache();

  /// 从本地文件加载字幕（外挂字幕）
  Future<List<SubtitleCue>> getSubtitleCuesFromFile({
    required String filePath,
    String? format,
  });

  // ============================
  // 播放上报
  // ============================

  /// 上报播放能力（播放开始前调用）
  Future<void> reportCapabilities({
    String? serverUrl,
    String? token,
  });

  /// 上报播放开始
  Future<void> reportPlaybackStart({
    required String itemId,
    String? mediaSourceId,
    String? playSessionId,
    bool isPaused = false,
    bool isMuted = false,
    int? volumeLevel,
    String playMethod = 'DirectPlay',
    String? serverUrl,
    String? token,
  });

  /// 上报播放进度
  Future<void> reportPlaybackPosition({
    required String itemId,
    required int positionTicks,
    String? mediaSourceId,
    String? playSessionId,
    bool isPaused = false,
    bool isMuted = false,
    int? volumeLevel,
    String playMethod = 'DirectPlay',
    String eventName = 'TimeUpdate',
    String? serverUrl,
    String? token,
  });

  /// 上报播放停止
  Future<void> reportPlaybackStopped({
    required String itemId,
    required int positionTicks,
    String? mediaSourceId,
    String? playSessionId,
    String? serverUrl,
    String? token,
  });
}
