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
    String? includeItemTypes,
    String? playedFilter, // 'all' | 'unplayed' | 'played'
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
      'IncludeItemTypes': includeItemTypes ?? 'Movie,Episode,Video,MusicVideo,Series',
      'ExcludeItemTypes': 'Playlist',
      if (searchTerm != null && searchTerm.isNotEmpty) 'SearchTerm': searchTerm,
      if (excludePlayed) 'Filters': 'IsUnplayed',
      if (playedFilter == 'unplayed') 'Filters': 'IsUnplayed',
      if (playedFilter == 'played') 'Filters': 'IsPlayed',
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
