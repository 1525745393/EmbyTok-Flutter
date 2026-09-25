// 从 embytok_service.dart 拆分（part 文件，无行为变化）

part of '../embytok_service.dart';

// ==================== EmbytokPlaybackApi ====================

mixin EmbytokPlaybackApi on EmbytokServiceBase {
  Future<MediaItem?> getPlaybackInfo(
    String itemId, {
    String? serverUrl,
    String? token,
  }) {
    return _api.getPlaybackInfo(
      itemId,
      serverUrl: serverUrl,
      token: token,
    );
  }

  Future<int> getPlaybackPosition(
    String itemId, {
    String? userId,
    String? serverUrl,
    String? token,
  }) {
    return _api.getPlaybackPosition(
      itemId,
      userId: userId,
      serverUrl: serverUrl,
      token: token,
    );
  }

  Future<List<SubtitleCue>> getSubtitleCues({
    required String itemId,
    required String mediaSourceId,
    required int index,
    String format = 'srt',
    String? directUrl,
    String? serverUrl,
    String? token,
  }) async {
    // 内存缓存：仅缓存成功且非空的结果，避免重复请求
    // 空结果和失败请求不缓存，确保下次可以重试
    final cacheKey =
        '${itemId}_${mediaSourceId}_${index}_$format${directUrl != null ? '_direct' : ''}';
    final cached = _subtitleCache.get(cacheKey);
    if (cached != null) {
      AppLogger.debug('字幕缓存命中',
          data: {'cacheKey': cacheKey, 'count': cached.length});
      return cached;
    }
    try {
      final cues = await _api.getSubtitleCues(
        itemId: itemId,
        mediaSourceId: mediaSourceId,
        index: index,
        format: format,
        directUrl: directUrl,
        serverUrl: serverUrl,
        token: token,
      );
      // 仅缓存非空结果
      if (cues.isNotEmpty) {
        _subtitleCache.set(cacheKey, cues);
      }
      return cues;
    } catch (e) {
      // 字幕加载失败不中断播放，不缓存失败结果以便下次重试
      AppLogger.warn('字幕请求失败', data: {
        'itemId': itemId,
        'mediaSourceId': mediaSourceId,
        'index': index,
        'format': format,
        'error': e.toString(),
      });
      return const <SubtitleCue>[];
    }
  }

  void clearSubtitleCache() {
    _subtitleCache.clear();
  }

  Future<List<SubtitleCue>> getSubtitleCuesFromFile({
    required String filePath,
    String? format,
  }) async {
    AppLogger.debug('从本地文件加载字幕',
        data: {'filePath': filePath, 'format': format});
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        AppLogger.warn('本地字幕文件不存在', data: {'filePath': filePath});
        return const <SubtitleCue>[];
      }
      // 文件大小校验：避免过大文件导致内存问题
      final fileSize = await file.length();
      if (fileSize > EmbytokServiceBase.maxSubtitleFileSize) {
        AppLogger.warn('本地字幕文件过大', data: {
          'filePath': filePath,
          'fileSize': fileSize,
          'maxSize': EmbytokServiceBase.maxSubtitleFileSize,
        });
        return const <SubtitleCue>[];
      }
      final content = await file.readAsString();
      if (content.isEmpty) {
        AppLogger.warn('本地字幕文件为空', data: {'filePath': filePath});
        return const <SubtitleCue>[];
      }
      // 从文件扩展名推断格式
      final effectiveFormat = format ?? _detectFormatFromPath(filePath);
      final cues = parseSubtitle(content, effectiveFormat);
      AppLogger.debug('本地字幕加载完成', data: {
        'filePath': filePath,
        'format': effectiveFormat,
        'cuesCount': cues.length,
      });
      return cues;
    } catch (e) {
      AppLogger.warn('本地字幕加载失败', data: {
        'filePath': filePath,
        'error': e.toString(),
      });
      return const <SubtitleCue>[];
    }
  }

  Future<void> reportCapabilities({
    String? serverUrl,
    String? token,
  }) {
    return _api.reportCapabilities(
      serverUrl: serverUrl,
      token: token,
    );
  }

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
  }) async {
    try {
      await _retry(
        () => _api.reportPlaybackStart(
          itemId: itemId,
          mediaSourceId: mediaSourceId,
          playSessionId: playSessionId,
          isPaused: isPaused,
          isMuted: isMuted,
          volumeLevel: volumeLevel,
          playMethod: playMethod,
          serverUrl: serverUrl,
          token: token,
        ),
        operationName: '上报播放开始',
      );
    } catch (e) {
      AppLogger.debug('上报播放开始失败', data: {'error': e.toString()});
    }
  }

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
  }) {
    return _api.reportPlaybackPosition(
      itemId: itemId,
      positionTicks: positionTicks,
      mediaSourceId: mediaSourceId,
      playSessionId: playSessionId,
      isPaused: isPaused,
      isMuted: isMuted,
      volumeLevel: volumeLevel,
      playMethod: playMethod,
      eventName: eventName,
      serverUrl: serverUrl,
      token: token,
    );
  }

  Future<void> reportPlaybackStopped({
    required String itemId,
    required int positionTicks,
    String? mediaSourceId,
    String? playSessionId,
    String? serverUrl,
    String? token,
  }) async {
    try {
      await _retry(
        () => _api.reportPlaybackStopped(
          itemId: itemId,
          positionTicks: positionTicks,
          mediaSourceId: mediaSourceId,
          playSessionId: playSessionId,
          serverUrl: serverUrl,
          token: token,
        ),
        operationName: '上报播放停止',
      );
    } catch (e) {
      AppLogger.debug('上报播放停止失败', data: {'error': e.toString()});
    }
  }

  Future<dynamic> postRaw(
    String path, {
    Map<String, dynamic>? queryParameters,
    dynamic data,
    String? serverUrl,
    String? token,
  }) {
    return _api.postRaw(
      path,
      queryParameters: queryParameters,
      data: data,
      serverUrl: serverUrl,
      token: token,
    );
  }

  Future<dynamic> deleteRaw(
    String path, {
    Map<String, dynamic>? queryParameters,
    String? serverUrl,
    String? token,
  }) {
    return _api.deleteRaw(
      path,
      queryParameters: queryParameters,
      serverUrl: serverUrl,
      token: token,
    );
  }

  Future<void> deleteItem({
    required String itemId,
    required String serverUrl,
    required String token,
  }) {
    return _api.deleteItem(
      itemId: itemId,
      serverUrl: serverUrl,
      token: token,
    );
  }
}
