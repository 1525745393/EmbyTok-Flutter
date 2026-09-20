// 从 emby_api_discovery.dart 拆分（part 文件，无行为变化）

part of 'emby_server_api.dart';

// ==================== _EmbyDiscoveryApi2 ====================

mixin _EmbyDiscoveryApi2 on EmbyServerApiBase {
  Future<PaginatedResponse<MediaItem>> getResumeItems({
    int limit = 20,
    int offset = 0,
    String? serverUrl,
    String? token,
    CancelToken? cancelToken,
    String? userId,
  }) async {
    _ensureConfig(serverUrl, token);
    final params = <String, dynamic>{
      'Limit': '$limit',
      'StartIndex': '$offset',
      'Recursive': 'true',
      'Fields':
          'Overview,Genres,CommunityRating,RunTimeTicks,ProductionYear,ImageTags,UserData,People',
      'IncludeItemTypes': 'Movie,Episode,Video,MusicVideo,Series',
      'ExcludeItemTypes': 'Playlist',
    };
    // 多用户服务器：显式带 userId（/Users/{id}/Items/Resume），
    // 无 userId 时回退 /Items/Resume（依赖 token 上下文）
    final effectiveUserId = userId ?? _defaultUserId;
    final path = (effectiveUserId != null && effectiveUserId.isNotEmpty)
        ? '/Users/$effectiveUserId/Items/Resume'
        : '/Items/Resume';
    final resp = await _apiClient.get<dynamic>(
      path,
      queryParameters: params,
      cancelToken: cancelToken,
    );
    return _parsePaginatedResponse(resp.data, offset: offset, limit: limit);
  }

  Future<PaginatedResponse<MediaItem>> getRecommendations({
    int limit = 20,
    int offset = 0,
    String? libraryId,
    String? userId,
    String? serverUrl,
    String? token,
    double minCommunityRating = 4.0,
    bool excludePlayed = true,
    Set<String>? includeItemTypes,
  }) async {
    _ensureConfig(serverUrl, token);
    final types = includeItemTypes ??
        const <String>{'Movie', 'Episode', 'Video', 'MusicVideo', 'Series'};
    final params = <String, dynamic>{
      'Limit': '$limit',
      'StartIndex': '$offset',
      if (libraryId != null) 'ParentId': libraryId,
      'Recursive': 'true',
      'SortBy': 'CommunityRating,SortName',
      'SortOrder': 'Descending',
      'MinCommunityRating': minCommunityRating.toStringAsFixed(1),
      'Fields':
          'Overview,Genres,People,CommunityRating,RunTimeTicks,ProductionYear,ImageTags,UserData,MediaSources,Path',
      'IncludeItemTypes': types.join(','),
      'ExcludeItemTypes': 'Playlist',
      if (excludePlayed) 'Filters': 'IsUnplayed',
    };

    final effectiveUserId = userId ?? _defaultUserId;
    final path = (effectiveUserId != null && effectiveUserId.isNotEmpty)
        ? '/Users/$effectiveUserId/Items'
        : '/Items';

    final resp = await _apiClient.get<dynamic>(
      path,
      queryParameters: params,
    );
    return _parsePaginatedResponse(resp.data, offset: offset, limit: limit);
  }

  Future<PaginatedResponse<MediaItem>> getLatestItems({
    int limit = 20,
    int offset = 0,
    String? libraryId,
    String? userId,
    String? serverUrl,
    String? token,
    Set<String>? includeItemTypes,
  }) async {
    _ensureConfig(serverUrl, token);
    final types = includeItemTypes ?? const <String>{'Movie'};
    final params = <String, dynamic>{
      'Limit': '$limit',
      'StartIndex': '$offset',
      if (libraryId != null) 'ParentId': libraryId,
      'Recursive': 'true',
      'Fields':
          'Overview,Genres,People,CommunityRating,RunTimeTicks,ProductionYear,ImageTags,UserData,MediaSources,Path',
      'IncludeItemTypes': types.join(','),
      'ExcludeItemTypes': 'Playlist',
    };

    // 使用 Emby 原生 /Items/Latest（服务端专门优化的"最新入库"端点），
    // 而非自己拼 SortBy=DateCreated。该端点按入库时间倒序，无需 SortBy。
    final effectiveUserId = userId ?? _defaultUserId;
    final path = (effectiveUserId != null && effectiveUserId.isNotEmpty)
        ? '/Users/$effectiveUserId/Items/Latest'
        : '/Items/Latest';

    final resp = await _apiClient.get<dynamic>(
      path,
      queryParameters: params,
    );
    // /Items/Latest 直接返回 List，而非 {Items,TotalRecordCount} 分页结构
    if (resp.data is List) {
      final items = resp.data as List<dynamic>;
      return PaginatedResponse(
        items: items
            .whereType<Map<String, dynamic>>()
            .map((e) => MediaItem.fromJson(e))
            .toList(),
        total: items.length,
        offset: offset,
        limit: limit,
      );
    }
    return _parsePaginatedResponse(resp.data, offset: offset, limit: limit);
  }

  Future<List<MediaItem>> getSuggestions({
    int limit = 20,
    String? userId,
    String? serverUrl,
    String? token,
  }) async {
    _ensureConfig(serverUrl, token);
    final effectiveUserId = userId ?? _defaultUserId;
    if (effectiveUserId == null || effectiveUserId.isEmpty) {
      return <MediaItem>[];
    }
    final params = <String, dynamic>{
      'Limit': '$limit',
      'Fields':
          'Overview,Genres,People,CommunityRating,RunTimeTicks,ProductionYear,ImageTags,UserData,MediaSources,Path',
      'IncludeItemTypes': 'Movie,Episode,Video,MusicVideo,Series',
    };

    final resp = await _apiClient.get<dynamic>(
      '/Users/$effectiveUserId/Suggestions',
      queryParameters: params,
    );
    final data = resp.data;
    if (data is! Map<String, dynamic>) {
      return <MediaItem>[];
    }
    final items = (data['Items'] as List<dynamic>?) ?? [];
    return items
        .whereType<Map<String, dynamic>>()
        .map((e) => MediaItem.fromJson(e))
        .toList();
  }

  Future<List<MediaItem>> getMovieRecommendations({
    int categoryLimit = 6,
    int itemLimit = 10,
    String? userId,
    String? libraryId,
    String? serverUrl,
    String? token,
  }) async {
    _ensureConfig(serverUrl, token);
    final effectiveUserId = userId ?? _defaultUserId;
    if (effectiveUserId == null || effectiveUserId.isEmpty) {
      return <MediaItem>[];
    }
    final params = <String, dynamic>{
      'UserId': effectiveUserId,
      'CategoryLimit': '$categoryLimit',
      'ItemLimit': '$itemLimit',
      'EnableImages': 'true',
      'EnableUserData': 'true',
      'ImageTypeLimit': '1',
      'EnableImageTypes': 'Primary,Backdrop,Thumb',
      if (libraryId != null) 'ParentId': libraryId,
    };
    final resp = await _apiClient.get<dynamic>(
      '/Movies/Recommendations',
      queryParameters: params,
    );
    // 响应为 RecommendationDto[]：[{ Items: [...], RecommendationType, BaselineItemName }]
    final data = resp.data;
    if (data is! List) return <MediaItem>[];
    final result = <MediaItem>[];
    final seen = <String>{};
    for (final group in data.whereType<Map<String, dynamic>>()) {
      final items = (group['Items'] as List<dynamic>?) ?? const [];
      for (final e in items.whereType<Map<String, dynamic>>()) {
        final item = MediaItem.fromJson(e);
        if (seen.add(item.id)) result.add(item);
      }
    }
    return result;
  }

  Future<List<NativeRecGroup>> getMovieRecommendationGroups({
    int categoryLimit = 6,
    int itemLimit = 10,
    String? userId,
    String? libraryId,
    String? serverUrl,
    String? token,
  }) async {
    _ensureConfig(serverUrl, token);
    final effectiveUserId = userId ?? _defaultUserId;
    if (effectiveUserId == null || effectiveUserId.isEmpty) {
      return <NativeRecGroup>[];
    }
    final params = <String, dynamic>{
      'UserId': effectiveUserId,
      'CategoryLimit': '$categoryLimit',
      'ItemLimit': '$itemLimit',
      'EnableImages': 'true',
      'EnableUserData': 'true',
      'ImageTypeLimit': '1',
      'EnableImageTypes': 'Primary,Backdrop,Thumb',
      if (libraryId != null) 'ParentId': libraryId,
    };
    final resp = await _apiClient.get<dynamic>(
      '/Movies/Recommendations',
      queryParameters: params,
    );
    final data = resp.data;
    if (data is! List) return <NativeRecGroup>[];
    final groups = <NativeRecGroup>[];
    for (final g in data.whereType<Map<String, dynamic>>()) {
      final group = NativeRecGroup.fromJson(g);
      if (group.items.isNotEmpty) groups.add(group);
    }
    return groups;
  }

  Future<List<MediaItem>> getRecommendedShows({
    int limit = 30,
    String? userId,
    String? libraryId,
    String? serverUrl,
    String? token,
  }) async {
    _ensureConfig(serverUrl, token);
    final effectiveUserId = userId ?? _defaultUserId;
    if (effectiveUserId == null || effectiveUserId.isEmpty) {
      return <MediaItem>[];
    }
    final params = <String, dynamic>{
      'UserId': effectiveUserId,
      'Limit': '$limit',
      'Fields':
          'Overview,Genres,People,CommunityRating,RunTimeTicks,ProductionYear,ImageTags,UserData,SeriesName,MediaSources,Path',
      'IncludeItemTypes': 'Series,Episode',
      if (libraryId != null) 'ParentId': libraryId,
    };
    final resp = await _apiClient.get<dynamic>(
      '/Shows/Recommended',
      queryParameters: params,
    );
    final data = resp.data;
    final List<dynamic> items;
    if (data is List) {
      items = data;
    } else if (data is Map<String, dynamic>) {
      items = (data['Items'] as List<dynamic>?) ?? const [];
    } else {
      return <MediaItem>[];
    }
    return items
        .whereType<Map<String, dynamic>>()
        .map((e) => MediaItem.fromJson(e))
        .toList();
  }

  Future<PaginatedResponse<MediaItem>> getNextUp({
    int limit = 20,
    String? seriesId,
    String? serverUrl,
    String? token,
  }) async {
    _ensureConfig(serverUrl, token);
    final params = <String, dynamic>{
      'Limit': '$limit',
      'Fields':
          'Overview,CommunityRating,RunTimeTicks,ProductionYear,ImageTags,UserData,SeriesName,ParentIndexNumber,IndexNumber,People',
      'IncludeItemTypes': 'Episode',
    };
    if (seriesId != null && seriesId.isNotEmpty) {
      params['SeriesId'] = seriesId;
    }
    final resp = await _apiClient.get<dynamic>(
      '/Shows/NextUp',
      queryParameters: params,
    );
    return _parsePaginatedResponse(resp.data, offset: 0, limit: limit);
  }

  Future<PaginatedResponse<MediaItem>> getRecentlyAdded({
    int limit = 20,
    int offset = 0,
    String? libraryId,
    String? userId,
    String? serverUrl,
    String? token,
  }) async {
    _ensureConfig(serverUrl, token);
    final params = <String, dynamic>{
      'Limit': '$limit',
      'StartIndex': '$offset',
      if (libraryId != null) 'ParentId': libraryId,
      'Recursive': 'true',
      'SortBy': 'DateCreated',
      'SortOrder': 'Descending',
      'Fields':
          'Overview,Genres,CommunityRating,RunTimeTicks,ProductionYear,ImageTags,UserData',
      'IncludeItemTypes': 'Movie,Episode,Video,MusicVideo,Series',
      'ExcludeItemTypes': 'Playlist',
    };

    final effectiveUserId = userId ?? _defaultUserId;
    final path = (effectiveUserId != null && effectiveUserId.isNotEmpty)
        ? '/Users/$effectiveUserId/Items/Latest'
        : '/Items/Latest';

    final resp = await _apiClient.get<dynamic>(
      path,
      queryParameters: params,
    );

    if (resp.data is List) {
      final items = resp.data as List<dynamic>;
      return PaginatedResponse(
        items: items
            .whereType<Map<String, dynamic>>()
            .map((e) => MediaItem.fromJson(e))
            .toList(),
        total: items.length,
        offset: offset,
        limit: limit,
      );
    }
    return _parsePaginatedResponse(resp.data, offset: offset, limit: limit);
  }

  Future<List<MediaItem>> getSimilarItems(
    String itemId, {
    int limit = 20,
    String? serverUrl,
    String? token,
    String? userId,
  }) async {
    _ensureConfig(serverUrl, token);
    final effectiveUserId = userId ?? _defaultUserId;
    final params = <String, dynamic>{
      'Limit': '$limit',
      if (effectiveUserId != null && effectiveUserId.isNotEmpty)
        'UserId': effectiveUserId,
      'Fields':
          'Overview,Genres,CommunityRating,RunTimeTicks,ProductionYear,ImageTags,UserData',
    };
    final resp = await _apiClient.get<dynamic>(
      '/Items/$itemId/Similar',
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

  Future<PaginatedResponse<MediaItem>> getTrailers({
    int limit = 30,
    int offset = 0,
    String? serverUrl,
    String? token,
  }) async {
    _ensureConfig(serverUrl, token);
    final params = <String, dynamic>{
      'Limit': '$limit',
      'StartIndex': '$offset',
      'Recursive': 'true',
      'IncludeItemTypes': 'Trailer',
      'Fields':
          'Overview,Genres,CommunityRating,RunTimeTicks,ProductionYear,ImageTags,UserData',
    };
    final resp = await _apiClient.get<dynamic>(
      '/Items',
      queryParameters: params,
    );
    return _parsePaginatedResponse(resp.data, offset: offset, limit: limit);
  }

  Future<List<MediaItem>> getSeasons(
    String seriesId, {
    String? serverUrl,
    String? token,
  }) async {
    _ensureConfig(serverUrl, token);
    final params = <String, dynamic>{
      'Fields':
          'Overview,RunTimeTicks,ProductionYear,ImageTags,UserData,IndexNumber',
    };
    final resp = await _apiClient.get<dynamic>(
      '/Shows/$seriesId/Seasons',
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
}
