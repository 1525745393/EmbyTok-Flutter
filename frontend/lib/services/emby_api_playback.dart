// 从 emby_server_api.dart 拆分（part 文件，无行为变化）

part of 'emby_server_api.dart';

// ==================== _EmbyPlaybackApi ====================

mixin _EmbyPlaybackApi on EmbyServerApiBase {
  Future<List<SubtitleCue>> getSubtitleCues({
    required String itemId,
    required String mediaSourceId,
    required int index,
    String format = 'srt',
    String? directUrl,
    String? serverUrl,
    String? token,
  }) async {
    _ensureConfig(serverUrl, token);
    try {
      // 外挂字幕：Emby 提供了完整 DeliveryUrl，直接请求
      final url = directUrl ??
          '/Videos/$itemId/$mediaSourceId/Subtitles/$index/0/Stream.$format';
      AppLogger.debug('请求字幕', data: {'url': url, 'direct': directUrl != null});
      final resp = await _apiClient.dio.get<String>(
        url,
        options: Options(
          headers: {
            'Accept': 'text/plain',
          },
        ),
      );
      final text = resp.data;
      if (text == null || text.isEmpty) {
        AppLogger.debug('字幕内容为空',
            data: {'url': url, 'statusCode': resp.statusCode});
        return const <SubtitleCue>[];
      }
      final cues = parseSubtitle(text, format);
      AppLogger.debug('字幕解析完成', data: {
        'url': url,
        'format': format,
        'cuesCount': cues.length,
        'rawLength': text.length,
      });
      return cues;
    } catch (e) {
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
      final fileSize = await file.length();
      if (fileSize > EmbyServerApiBase.maxSubtitleFileSize) {
        AppLogger.warn('本地字幕文件过大', data: {
          'filePath': filePath,
          'fileSize': fileSize,
          'maxSize': EmbyServerApiBase.maxSubtitleFileSize,
        });
        return const <SubtitleCue>[];
      }
      final content = await file.readAsString();
      if (content.isEmpty) {
        AppLogger.warn('本地字幕文件为空', data: {'filePath': filePath});
        return const <SubtitleCue>[];
      }
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

  void clearSubtitleCache() {
    // 纯 API 层不维护缓存，空实现
  }

  String _detectFormatFromPath(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    switch (ext) {
      case 'vtt':
      case 'webvtt':
        return 'vtt';
      case 'ass':
      case 'ssa':
        return 'ass';
      case 'srt':
      case 'subrip':
      default:
        return 'srt';
    }
  }

  Future<void> reportCapabilities({
    String? serverUrl,
    String? token,
  }) async {
    _ensureConfig(serverUrl, token);
    try {
      await _apiClient.post<dynamic>(
        '/Sessions/Capabilities/Full',
        data: {
          'PlayableMediaTypes': ['Video'],
          'SupportsMediaControl': true,
          'SupportsPersistentConnections': false,
        },
      );
    } catch (e) {
      AppLogger.debug('上报播放能力失败', data: {'error': e.toString()});
    }
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
    _ensureConfig(serverUrl, token);
    final effectiveSessionId = playSessionId ?? _generatePlaySessionId();
    final body = <String, dynamic>{
      'ItemId': itemId,
      'PositionTicks': 0,
      'IsPaused': isPaused,
      'IsMuted': isMuted,
      'PlayMethod': playMethod,
      'EventName': 'PlaybackStart',
      'CanSeek': true,
      'QueueableMediaTypes': ['Video'],
      'MediaSourceId': mediaSourceId ?? itemId,
      'PlaySessionId': effectiveSessionId,
      if (volumeLevel != null) 'VolumeLevel': volumeLevel,
    };
    try {
      await _retry(
        () => _apiClient.post<dynamic>(
          '/Sessions/Playing',
          data: body,
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
  }) async {
    AppLogger.debug('上报播放进度', data: {
      'itemId': itemId,
      'positionTicks': positionTicks,
    });
    _ensureConfig(serverUrl, token);
    final effectiveSessionId = playSessionId ?? _generatePlaySessionId();
    final body = <String, dynamic>{
      'ItemId': itemId,
      'PositionTicks': positionTicks,
      'IsPaused': isPaused,
      'IsMuted': isMuted,
      'PlayMethod': playMethod,
      'EventName': eventName,
      'CanSeek': true,
      'QueueableMediaTypes': ['Video'],
      'MediaSourceId': mediaSourceId ?? itemId,
      'PlaySessionId': effectiveSessionId,
      if (volumeLevel != null) 'VolumeLevel': volumeLevel,
    };
    try {
      await _apiClient.post<dynamic>(
        '/Sessions/Playing/Progress',
        data: body,
      );
    } catch (e) {
      AppLogger.debug('上报播放进度失败', data: {'error': e.toString()});
    }
  }

  Future<void> reportPlaybackStopped({
    required String itemId,
    required int positionTicks,
    String? mediaSourceId,
    String? playSessionId,
    String? serverUrl,
    String? token,
  }) async {
    AppLogger.debug('上报播放停止', data: {
      'itemId': itemId,
      'positionTicks': positionTicks,
    });
    _ensureConfig(serverUrl, token);
    final effectiveSessionId = playSessionId ?? _generatePlaySessionId();
    final body = <String, dynamic>{
      'ItemId': itemId,
      'PositionTicks': positionTicks,
      'MediaSourceId': mediaSourceId ?? itemId,
      'PlaySessionId': effectiveSessionId,
    };
    try {
      await _retry(
        () => _apiClient.post<dynamic>(
          '/Sessions/Playing/Stopped',
          data: body,
        ),
        operationName: '上报播放停止',
      );
    } catch (e) {
      AppLogger.debug('上报播放停止失败', data: {'error': e.toString()});
    }
  }

  Future<List<SearchHint>> searchHints(
    String query, {
    int limit = 20,
    String? serverUrl,
    String? token,
  }) async {
    _ensureConfig(serverUrl, token);
    if (query.isEmpty) return [];
    final params = <String, dynamic>{
      'SearchTerm': query,
      'Limit': '$limit',
      'Recursive': 'true',
    };
    final resp = await _apiClient.get<dynamic>(
      '/Search/Hints',
      queryParameters: params,
    );
    final items = resp.data is List
        ? resp.data as List<dynamic>
        : (resp.data['SearchHints'] as List<dynamic>?) ??
            (resp.data['Items'] as List<dynamic>?) ??
            [];
    return items
        .whereType<Map<String, dynamic>>()
        .map((e) => SearchHint(
              id: (e['Id'] as String?) ?? '',
              name: (e['Name'] as String?) ?? '',
              type: (e['Type'] as String?),
              year: (e['ProductionYear'] as int?) ?? (e['year'] as int?),
              seriesName: (e['SeriesName'] as String?),
              thumbnailUrl: _defaultServerUrl != null
                  ? '$_defaultServerUrl/Items/${e['Id']}/Images/Primary'
                      '?MaxWidth=200&Format=jpg'
                      '${_defaultToken != null ? '&api_key=$_defaultToken' : ''}'
                  : null,
            ))
        .toList();
  }

  Future<PaginatedResponse<MediaItem>> searchItems(
    String query, {
    int limit = 30,
    int offset = 0,
    List<String>? includeTypes,
    String? userId,
    String? serverUrl,
    String? token,
  }) async {
    AppLogger.info('发送搜索请求', data: {
      'query': query,
      'limit': limit,
    });
    _ensureConfig(serverUrl, token);
    if (query.isEmpty) {
      return PaginatedResponse(
        items: const [],
        total: 0,
        offset: offset,
        limit: limit,
      );
    }
    final params = <String, dynamic>{
      'SearchTerm': query,
      'Limit': '$limit',
      'StartIndex': '$offset',
      'Recursive': 'true',
      'Fields':
          'Overview,Genres,People,CommunityRating,RunTimeTicks,ProductionYear,ImageTags,UserData',
      if (includeTypes != null && includeTypes.isNotEmpty)
        'IncludeItemTypes': includeTypes.join(','),
    };

    final effectiveUserId = userId ?? _defaultUserId;
    final path = (effectiveUserId != null && effectiveUserId.isNotEmpty)
        ? '/Users/$effectiveUserId/Items'
        : '/Items';

    final resp = await _apiClient.get<dynamic>(
      path,
      queryParameters: params,
    );
    final result =
        _parsePaginatedResponse(resp.data, offset: offset, limit: limit);
    AppLogger.debug('搜索响应', data: {
      'results': result.items.length,
      'total': result.total,
    });
    return result;
  }

  Future<List<Map<String, dynamic>>> searchPersons(
    String query, {
    int limit = 20,
    String? serverUrl,
    String? token,
  }) async {
    _ensureConfig(serverUrl, token);
    if (query.isEmpty) return [];

    final params = <String, dynamic>{
      'SearchTerm': query,
      'Limit': '$limit',
      'Fields': 'Overview,ImageTags,Name',
    };

    final resp = await _apiClient.get<dynamic>(
      '/Persons',
      queryParameters: params,
    );
    final data = resp.data;
    if (data is Map<String, dynamic>) {
      final items = data['Items'];
      if (items is List) {
        return items.cast<Map<String, dynamic>>();
      }
    }
    return [];
  }

  Future<List<MediaItem>> getWatchHistory({
    int limit = 50,
    String? userId,
    String? serverUrl,
    String? token,
  }) async {
    _ensureConfig(serverUrl, token);
    final effectiveUserId = userId ?? _defaultUserId;

    final isUserPath = effectiveUserId != null && effectiveUserId.isNotEmpty;
    final path = isUserPath ? '/Users/$effectiveUserId/Items' : '/Items';

    final params = <String, dynamic>{
      'Limit': '$limit',
      'Recursive': 'true',
      'SortBy': 'DatePlayed',
      'SortOrder': 'Descending',
      'Fields':
          'Overview,Genres,CommunityRating,RunTimeTicks,ProductionYear,ImageTags,UserData',
      'IncludeItemTypes': 'Movie,Episode,Video,MusicVideo,Series',
      'ExcludeItemTypes': 'Playlist',
      if (!isUserPath && effectiveUserId != null && effectiveUserId.isNotEmpty)
        'UserId': effectiveUserId,
    };

    final resp = await _apiClient.get<dynamic>(
      path,
      queryParameters: params,
    );
    final items = resp.data is List
        ? resp.data as List<dynamic>
        : (resp.data['Items'] as List<dynamic>?) ?? [];
    return items
        .whereType<Map<String, dynamic>>()
        .map((e) => MediaItem.fromJson(e))
        .toList();
  }

  Future<void> saveCloudSync({
    required String itemId,
    required String libraryId,
    String? libraryType,
    String? serverUrl,
    String? token,
  }) async {
    AppLogger.debug('保存续播云同步', data: {'itemId': itemId});
    _ensureConfig(serverUrl, token);
    final userId = _defaultUserId;
    if (userId == null || userId.isEmpty) {
      AppLogger.warn('未配置 userId，跳过云同步');
      return;
    }
    final body = <String, dynamic>{
      'Id': 'EmbyTok-Resume',
      'CustomPrefs': {
        'lastId': itemId,
        'libId': libraryId,
        'libType': libraryType ?? '',
        'date': DateTime.now().millisecondsSinceEpoch.toString(),
      },
    };
    await _apiClient.post<dynamic>(
      '/DisplayPreferences/EmbyTok-Resume?userId=$userId',
      data: body,
    );
  }

  Future<Map<String, dynamic>?> checkCloudSync({
    String? serverUrl,
    String? token,
  }) async {
    AppLogger.debug('检查续播云同步');
    _ensureConfig(serverUrl, token);
    final userId = _defaultUserId;
    if (userId == null || userId.isEmpty) return null;
    try {
      final resp = await _apiClient.get<dynamic>(
        '/DisplayPreferences/EmbyTok-Resume?userId=$userId',
      );
      final data = resp.data is Map
          ? Map<String, dynamic>.from(resp.data as Map)
          : <String, dynamic>{};
      final customPrefs = data['CustomPrefs'] as Map<String, dynamic>?;
      return customPrefs;
    } catch (e) {
      AppLogger.debug('云同步数据不存在或获取失败', data: {'error': e.toString()});
      return null;
    }
  }

  Future<dynamic> postRaw(
    String path, {
    Map<String, dynamic>? queryParameters,
    dynamic data,
    String? serverUrl,
    String? token,
  }) async {
    AppLogger.debug('POST 请求', data: {'path': path});
    _ensureConfig(serverUrl, token);
    final resp = await _apiClient.post<dynamic>(
      path,
      queryParameters: queryParameters,
      data: data,
    );
    return resp.data;
  }

  Future<dynamic> deleteRaw(
    String path, {
    Map<String, dynamic>? queryParameters,
    String? serverUrl,
    String? token,
  }) async {
    AppLogger.debug('DELETE 请求', data: {'path': path});
    _ensureConfig(serverUrl, token);
    final resp = await _apiClient.delete<dynamic>(
      path,
      queryParameters: queryParameters,
    );
    return resp.data;
  }

  String _generatePlaySessionId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final rand = Random().nextInt(0xFFFF).toRadixString(16).padLeft(4, '0');
    return 'emb-$now-$rand';
  }
}
