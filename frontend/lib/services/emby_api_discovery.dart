// 从 emby_server_api.dart 拆分（part 文件，无行为变化）

part of 'emby_server_api.dart';

// ==================== _EmbyDiscoveryApi ====================

mixin _EmbyDiscoveryApi on EmbyServerApiBase {
  void setupAuth({
    required String embyServerUrl,
    required String apiKey,
    String? userId,
  }) {
    _defaultServerUrl = embyServerUrl;
    _defaultToken = apiKey;
    _defaultUserId = userId;
    _apiClient.setBaseUrl(embyServerUrl);
    _apiClient.setToken(apiKey);
  }

  void clearAuth() {
    _defaultServerUrl = null;
    _defaultToken = null;
    _defaultUserId = null;
  }

  Future<User> login({
    required String embyServerUrl,
    required String username,
    required String password,
  }) async {
    AppLogger.info('发送登录请求', data: {
      'serverUrl': embyServerUrl,
      'username': username,
    });

    try {
      _apiClient.setBaseUrl(embyServerUrl);

      final resp = await _apiClient.post<Map<String, dynamic>>(
        '/Users/AuthenticateByName',
        data: {
          'Username': username,
          'Pw': password,
        },
      );

      final data = resp.data as Map<String, dynamic>;
      final userInfo = data['User'] as Map<String, dynamic>? ?? {};
      final accessToken = (data['AccessToken'] as String?) ?? '';

      final user = User(
        id: (userInfo['Id'] as String?) ?? '',
        name: (userInfo['Name'] as String?) ?? username,
        accessToken: accessToken,
      );

      _defaultServerUrl = embyServerUrl;
      _defaultToken = accessToken;
      _defaultUserId = user.id;
      _apiClient.setToken(accessToken);

      AppLogger.info('登录成功', data: {'userId': user.id});
      return user;
    } catch (e) {
      AppLogger.error('登录请求失败', error: e);
      rethrow;
    }
  }

  Future<List<Library>> getLibraries({
    String? userId,
    String? serverUrl,
    String? token,
  }) async {
    AppLogger.debug('请求媒体库列表');
    _ensureConfig(serverUrl, token);
    final effectiveUserId = userId ?? _defaultUserId;
    final path = effectiveUserId != null && effectiveUserId.isNotEmpty
        ? '/Users/$effectiveUserId/Views'
        : '/Library/VirtualFolders';
    final resp = await _apiClient.get<dynamic>(
      path,
      queryParameters: {},
    );

    final items = resp.data is List
        ? resp.data as List<dynamic>
        : (resp.data['Items'] as List<dynamic>?) ?? [];

    final libraries = items
        .whereType<Map<String, dynamic>>()
        .map((e) => Library(
              id: (e['Id'] as String?) ?? (e['ItemId'] as String?) ?? '',
              name: (e['Name'] as String?) ?? '',
              type: (e['CollectionType'] as String?) ?? 'movies',
              itemCount: e['RecursiveItemCount'] as int?,
              coverImageUrl: e['ImageTags']?['Primary'] as String?,
            ))
        .toList();

    final needsCount = libraries.any((lib) => lib.itemCount == null);
    if (needsCount && effectiveUserId != null && effectiveUserId.isNotEmpty) {
      for (var i = 0; i < libraries.length; i++) {
        final lib = libraries[i];
        if (lib.itemCount == null) {
          try {
            final resp = await getLibraryItems(
              lib.id,
              limit: 0,
              userId: effectiveUserId,
              serverUrl: serverUrl,
              token: token,
            );
            libraries[i] = Library(
              id: lib.id,
              name: lib.name,
              type: lib.type,
              itemCount: resp.total,
              coverImageUrl: lib.coverImageUrl,
            );
          } catch (e) {
            AppLogger.debug('获取库 ${lib.name} 视频数量失败',
                data: {'error': e.toString()});
          }
        }
      }
    }

    AppLogger.debug('媒体库列表响应', data: {'count': libraries.length});
    return libraries;
  }

  Future<List<Library>> getUserViews({
    String? userId,
    String? serverUrl,
    String? token,
  }) {
    return getLibraries(
      userId: userId,
      serverUrl: serverUrl,
      token: token,
    );
  }

  Future<PaginatedResponse<MediaItem>> getLibraryItems(
    String libraryId, {
    int limit = 20,
    int offset = 0,
    String? userId,
    String? serverUrl,
    String? token,
    String sortBy = 'DateCreated,SortName',
    String sortOrder = 'Descending',
    String? searchTerm,
    bool excludePlayed = false,
    CancelToken? cancelToken,
  }) async {
    AppLogger.debug('请求视频列表', data: {
      'libraryId': libraryId,
      'limit': limit,
      'offset': offset,
      'sortBy': sortBy,
      'sortOrder': sortOrder,
      if (searchTerm != null) 'searchTerm': searchTerm,
      'excludePlayed': excludePlayed,
    });
    _ensureConfig(serverUrl, token);
    final params = <String, dynamic>{
      'ParentId': libraryId,
      'Limit': '$limit',
      'StartIndex': '$offset',
      'SortBy': sortBy,
      'SortOrder': sortOrder,
      'Recursive': 'true',
      'Fields':
          'Overview,Genres,People,CommunityRating,RunTimeTicks,ProductionYear,ImageTags,UserData,MediaSources,Path',
      'IncludeItemTypes': 'Movie,Episode,Video,MusicVideo,Series',
      'ExcludeItemTypes': 'Playlist',
      if (searchTerm != null && searchTerm.isNotEmpty) 'SearchTerm': searchTerm,
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
    final result =
        _parsePaginatedResponse(resp.data, offset: offset, limit: limit);
    AppLogger.debug('视频列表响应', data: {
      'count': result.items.length,
      'total': result.total,
    });
    return result;
  }

  Future<MediaItem> getItemDetail(
    String itemId, {
    String? userId,
    String? serverUrl,
    String? token,
  }) async {
    _ensureConfig(serverUrl, token);
    final params = <String, dynamic>{
      'Fields':
          'Overview,Genres,People,CommunityRating,CriticRating,OfficialRating,'
              'RunTimeTicks,ProductionYear,PremiereDate,DateCreated,Studios,'
              'MediaSources,UserData,ParentIndexNumber,IndexNumber,SeriesName,'
              'SeasonName,SeriesId,SeasonId,ImageTags,BackdropImageTags',
    };
    final effectiveUserId = userId ?? _defaultUserId;
    final path = (effectiveUserId != null && effectiveUserId.isNotEmpty)
        ? '/Users/$effectiveUserId/Items/$itemId'
        : '/Items/$itemId';
    final resp = await _apiClient.get<dynamic>(
      path,
      queryParameters: params,
    );
    final data = resp.data is Map
        ? Map<String, dynamic>.from(resp.data as Map)
        : <String, dynamic>{};
    return MediaItem.fromJson(data);
  }

  Future<List<MediaItem>> getChildren(
    String parentId, {
    int limit = 100,
    int offset = 0,
    String? serverUrl,
    String? token,
  }) async {
    AppLogger.debug('获取子项', data: {'parentId': parentId, 'limit': limit});
    _ensureConfig(serverUrl, token);
    final params = <String, dynamic>{
      'limit': '$limit',
      'startIndex': '$offset',
    };
    final resp = await _apiClient.get<dynamic>(
      '/Items/$parentId/Children',
      queryParameters: params,
    );
    final result =
        _parsePaginatedResponse(resp.data, offset: offset, limit: limit);
    return result.items;
  }

  Future<void> deleteItem({
    required String itemId,
    required String serverUrl,
    required String token,
  }) async {
    AppLogger.debug('删除媒体项', data: {'itemId': itemId});
    _ensureConfig(serverUrl, token);
    await _apiClient.delete<dynamic>('/Items/$itemId');
    AppLogger.info('媒体项已删除', data: {'itemId': itemId});
  }

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

  Future<PaginatedResponse<MediaItem>> getEpisodes(
    String seriesId, {
    String? seasonId,
    int limit = 100,
    int offset = 0,
    String? serverUrl,
    String? token,
  }) async {
    _ensureConfig(serverUrl, token);
    final params = <String, dynamic>{
      'Limit': '$limit',
      'StartIndex': '$offset',
      'Fields':
          'Overview,RunTimeTicks,ProductionYear,ImageTags,UserData,IndexNumber,ParentIndexNumber,SeriesName',
      if (seasonId != null && seasonId.isNotEmpty) 'SeasonId': seasonId,
    };
    final path = '/Shows/$seriesId/Episodes';
    final resp = await _apiClient.get<dynamic>(path, queryParameters: params);
    return _parsePaginatedResponse(resp.data, offset: offset, limit: limit);
  }

  Future<PaginatedResponse<Person>> getPeople({
    int limit = 50,
    int startIndex = 0,
    List<String>? personTypes,
    String? searchTerm,
    String? serverUrl,
    String? token,
  }) async {
    _ensureConfig(serverUrl, token);
    final params = <String, dynamic>{
      'Limit': '$limit',
      'StartIndex': '$startIndex',
      'Recursive': 'true',
      if (personTypes != null && personTypes.isNotEmpty)
        'PersonTypes': personTypes.join(','),
      if (searchTerm != null && searchTerm.isNotEmpty) 'SearchTerm': searchTerm,
      'Fields': 'PrimaryImageTag,Overview',
    };
    final resp = await _apiClient.get<dynamic>(
      '/Persons',
      queryParameters: params,
    );
    final items = resp.data is List
        ? resp.data as List<dynamic>
        : (resp.data['Items'] as List<dynamic>?) ?? [];
    final total = (resp.data is Map<String, dynamic>)
        ? (resp.data['TotalRecordCount'] as int?) ?? items.length
        : items.length;
    final baseUrl = _defaultServerUrl ?? serverUrl ?? '';
    final effectiveToken = token ?? _defaultToken;
    final people = items.whereType<Map<String, dynamic>>().map((e) {
      final id = (e['Id'] as String?) ?? '';
      final name = (e['Name'] as String?) ?? '';
      final imageTag = (e['PrimaryImageTag'] as String?) ??
          (e['ImageTags']?['Primary'] as String?);
      String? imgUrl;
      if (imageTag != null && baseUrl.isNotEmpty) {
        imgUrl = '$baseUrl/Items/$id/Images/Primary?MaxWidth=300'
            '&Tag=${Uri.encodeQueryComponent(imageTag)}&Format=jpg'
            '${effectiveToken != null && effectiveToken.isNotEmpty ? '&api_key=$effectiveToken' : ''}';
      }
      return Person(
        id: id,
        name: name,
        type: (e['Type'] as String?) ?? 'Actor',
        imageUrl: imgUrl,
      );
    }).toList();
    return PaginatedResponse<Person>(
      items: people,
      total: total,
      offset: startIndex,
      limit: limit,
    );
  }

  Future<PaginatedResponse<MediaItem>> getPersonItems(
    String personId, {
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
      'PersonIds': personId,
      'Fields':
          'Overview,Genres,CommunityRating,RunTimeTicks,ProductionYear,ImageTags,UserData,People',
    };
    final resp = await _apiClient.get<dynamic>(
      '/Items',
      queryParameters: params,
    );
    return _parsePaginatedResponse(resp.data, offset: offset, limit: limit);
  }

  Future<PaginatedResponse<MediaItem>> getItemsByPersonIds({
    required List<String> personIds,
    int limit = 30,
    int offset = 0,
    String? serverUrl,
    String? token,
    String? userId,
  }) async {
    _ensureConfig(serverUrl, token);
    final params = <String, dynamic>{
      'Limit': '$limit',
      'StartIndex': '$offset',
      'Recursive': 'true',
      'PersonIds': personIds.join(','),
      'SortBy': 'DateCreated,SortName',
      'SortOrder': 'Descending',
      'Fields':
          'Overview,Genres,CommunityRating,RunTimeTicks,ProductionYear,ImageTags,UserData,People',
      'ExcludeItemTypes': 'Playlist',
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

  Future<PaginatedResponse<MediaItem>> getBoxSetItems(
    String boxSetId, {
    int limit = 50,
    int offset = 0,
    bool excludePlayed = false,
    String? serverUrl,
    String? token,
  }) async {
    _ensureConfig(serverUrl, token);
    final params = <String, dynamic>{
      'Limit': '$limit',
      'StartIndex': '$offset',
      'Recursive': 'true',
      'ParentId': boxSetId,
      'IncludeItemTypes': 'Movie,Episode,Video,MusicVideo,Series',
      'Fields':
          'Overview,Genres,CommunityRating,RunTimeTicks,ProductionYear,ImageTags,UserData,People',
      if (excludePlayed) 'Filters': 'IsUnplayed',
    };
    final resp = await _apiClient.get<dynamic>(
      '/Items',
      queryParameters: params,
    );
    return _parsePaginatedResponse(resp.data, offset: offset, limit: limit);
  }

  Future<MediaItem?> getPersonDetail(
    String personId, {
    String? personName,
    String? serverUrl,
    String? token,
    String? userId,
  }) async {
    _ensureConfig(serverUrl, token);
    final params = <String, dynamic>{
      'Fields':
          'Overview,Genres,CommunityRating,ProductionYear,ImageTags,UserData,People',
    };
    try {
      // 优先使用 /Persons/{name} 端点，确保 Overview 字段返回
      // /Items/{id} 对 Person 类型可能不返回 Overview
      if (personName != null && personName.isNotEmpty) {
        final resp = await _apiClient.get<dynamic>(
          '/Persons/${Uri.encodeComponent(personName)}',
          queryParameters: params,
        );
        final data = resp.data;
        if (data is Map<String, dynamic> &&
            (data['Overview'] as String?)?.isNotEmpty == true) {
          return MediaItem.fromJson(data);
        }
      }
      // fallback: 使用 /Items/{id} 端点
      final resp2 = await _apiClient.get<dynamic>(
        '/Items/$personId',
        queryParameters: params,
      );
      final data2 = resp2.data;
      if (data2 is Map<String, dynamic>) {
        return MediaItem.fromJson(data2);
      }
      return null;
    } catch (e) {
      AppLogger.error('获取演员详情失败', error: e);
      return null;
    }
  }

  Future<List<Library>> getGenres({
    int limit = 100,
    String? serverUrl,
    String? token,
  }) async {
    _ensureConfig(serverUrl, token);
    final all = <Library>[];
    final seen = <String>{};
    // 类型可能超过单页上限，分页拉取全量
    var startIndex = 0;
    while (all.length < EmbyServerApiBase._kDiscoverListMax) {
      final params = <String, dynamic>{
        'Limit': '$limit',
        'StartIndex': '$startIndex',
        'Recursive': 'true',
        // 视频发现场景：只拉取视频类媒体类型，避免混入音乐/照片等流派
        'IncludeItemTypes': 'Movie,Series,Episode,Video,MusicVideo',
      };
      final resp = await _apiClient.get<dynamic>(
        '/Genres',
        queryParameters: params,
      );
      final items = resp.data is List
          ? resp.data as List<dynamic>
          : (resp.data['Items'] as List<dynamic>?) ?? [];
      final total = resp.data is Map
          ? (resp.data['TotalRecordCount'] as num?)?.toInt()
          : null;
      var pageCount = 0;
      for (final e in items.whereType<Map<String, dynamic>>()) {
        final lib = Library(
          id: (e['Id'] as String?) ?? '',
          name: (e['Name'] as String?) ?? '',
          type: 'Genre',
        );
        if (lib.id.isEmpty || lib.name.isEmpty) continue;
        if (seen.add(lib.id)) {
          all.add(lib);
          pageCount++;
        }
      }
      if (pageCount == 0) break; // 空页或服务端忽略 StartIndex 返回重复页
      if (total != null && startIndex + pageCount >= total) break;
      startIndex += pageCount;
    }
    return all;
  }

  Future<PaginatedResponse<MediaItem>> getItemsByGenre(
    String genre, {
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
      'Genres': genre,
      // 视频发现场景：只返回视频类媒体，与 getBoxSetItems 对齐
      'IncludeItemTypes': 'Movie,Series,Episode,Video,MusicVideo',
      'Fields':
          'Overview,Genres,CommunityRating,RunTimeTicks,ProductionYear,ImageTags,UserData,People',
    };
    final resp = await _apiClient.get<dynamic>(
      '/Items',
      queryParameters: params,
    );
    return _parsePaginatedResponse(resp.data, offset: offset, limit: limit);
  }

  Future<List<Library>> getCollections({
    int limit = 100,
    String? serverUrl,
    String? token,
  }) async {
    _ensureConfig(serverUrl, token);
    final params = <String, dynamic>{
      'Limit': '$limit',
      'Recursive': 'true',
      'IncludeItemTypes': 'BoxSet',
      'Fields': 'Name,PrimaryImageHash',
    };
    final resp = await _apiClient.get<dynamic>(
      '/Items',
      queryParameters: params,
    );
    final items = resp.data is List
        ? resp.data as List<dynamic>
        : (resp.data['Items'] as List<dynamic>?) ?? [];
    return items
        .whereType<Map<String, dynamic>>()
        .map((e) => Library(
              id: (e['Id'] as String?) ?? '',
              name: (e['Name'] as String?) ?? '',
              type: 'BoxSet',
              itemCount: e['ChildCount'] as int?,
            ))
        .toList();
  }

  Future<List<Library>> getTags({
    int limit = 100,
    String? serverUrl,
    String? token,
  }) async {
    _ensureConfig(serverUrl, token);
    final all = <Library>[];
    final seen = <String>{};
    // 标签可能超过单页上限，分页拉取全量
    var startIndex = 0;
    while (all.length < EmbyServerApiBase._kDiscoverListMax) {
      final params = <String, dynamic>{
        'Limit': '$limit',
        'StartIndex': '$startIndex',
        'Recursive': 'true',
        // 视频发现场景：只拉取视频类媒体上的标签，避免混入音乐/照片标签
        'IncludeItemTypes': 'Movie,Series,Episode,Video,MusicVideo',
      };
      final resp = await _apiClient.get<dynamic>(
        '/Tags',
        queryParameters: params,
      );
      // Emby /Tags 返回 QueryResult<String>：Items 为字符串数组；
      // 兼容部分服务器返回对象数组的情况。
      final items = resp.data is List
          ? resp.data as List<dynamic>
          : (resp.data['Items'] as List<dynamic>?) ?? [];
      final total = resp.data is Map
          ? (resp.data['TotalRecordCount'] as num?)?.toInt()
          : null;
      var pageCount = 0;
      for (final e in items) {
        final Library lib;
        if (e is String) {
          lib = Library(id: e, name: e, type: 'Tag');
        } else if (e is Map<String, dynamic>) {
          lib = Library(
            id: (e['Id'] as String?) ?? (e['Name'] as String?) ?? '',
            name: (e['Name'] as String?) ?? '',
            type: 'Tag',
          );
        } else {
          lib = Library(id: '$e', name: '$e', type: 'Tag');
        }
        if (lib.id.isEmpty || lib.name.isEmpty) continue;
        if (seen.add(lib.id)) {
          all.add(lib);
          pageCount++;
        }
      }
      if (pageCount == 0) break; // 空页或服务端忽略 StartIndex 返回重复页
      if (total != null && startIndex + pageCount >= total) break;
      startIndex += pageCount;
    }
    return all;
  }

  Future<PaginatedResponse<MediaItem>> getItemsByTag(
    String tag, {
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
      'Tags': tag,
      // 视频发现场景：只返回视频类媒体，与 getBoxSetItems 对齐
      'IncludeItemTypes': 'Movie,Series,Episode,Video,MusicVideo',
      'Fields':
          'Overview,Genres,CommunityRating,RunTimeTicks,ProductionYear,ImageTags,UserData,People',
    };
    final resp = await _apiClient.get<dynamic>(
      '/Items',
      queryParameters: params,
    );
    return _parsePaginatedResponse(resp.data, offset: offset, limit: limit);
  }

  Future<List<Library>> getStudios({
    int limit = 100,
    String? serverUrl,
    String? token,
  }) async {
    _ensureConfig(serverUrl, token);
    final params = <String, dynamic>{
      'Limit': '$limit',
      'Recursive': 'true',
    };
    final resp = await _apiClient.get<dynamic>(
      '/Studios',
      queryParameters: params,
    );
    final items = resp.data is List
        ? resp.data as List<dynamic>
        : (resp.data['Items'] as List<dynamic>?) ?? [];
    return items
        .whereType<Map<String, dynamic>>()
        .map((e) => Library(
              id: (e['Id'] as String?) ?? '',
              name: (e['Name'] as String?) ?? '',
              type: 'Studio',
            ))
        .toList();
  }

  Future<PaginatedResponse<MediaItem>> getItemsByStudio(
    String studio, {
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
      'Studios': studio,
      'Fields':
          'Overview,Genres,CommunityRating,RunTimeTicks,ProductionYear,ImageTags,UserData',
    };
    final resp = await _apiClient.get<dynamic>(
      '/Items',
      queryParameters: params,
    );
    return _parsePaginatedResponse(resp.data, offset: offset, limit: limit);
  }

  Future<MediaItem?> getPlaybackInfo(
    String itemId, {
    String? serverUrl,
    String? token,
  }) async {
    return getItemDetail(itemId, serverUrl: serverUrl, token: token);
  }

  Future<int> getPlaybackPosition(
    String itemId, {
    String? userId,
    String? serverUrl,
    String? token,
  }) async {
    try {
      final item = await getItemDetail(
        itemId,
        userId: userId,
        serverUrl: serverUrl,
        token: token,
      );
      final ticks = item.userData?.playbackPositionTicks;
      if (ticks == null || ticks <= 0) {
        return 0;
      }
      return ticks.toInt();
    } catch (e) {
      AppLogger.warn('获取服务端播放进度失败', data: {
        'itemId': itemId,
        'error': e.toString(),
      });
      return 0;
    }
  }
}
