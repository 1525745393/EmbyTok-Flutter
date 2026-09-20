// 从 emby_api_discovery_extra.dart 拆分（part 文件，无行为变化）

part of 'emby_server_api.dart';

// ==================== _EmbyDiscoveryApi3 ====================

mixin _EmbyDiscoveryApi3 on EmbyServerApiBase {
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
}
