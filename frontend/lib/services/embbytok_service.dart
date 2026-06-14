// 核心业务服务：直接调用 Emby 原生 API（不再经过后端）
// 提供：登录、媒体库、视频列表、继续观看、NextUp、相似影片、演员、类型、
//       工作室、收藏、标记已看、播放信息、季/集、预告片、搜索提示

import 'dart:convert';

import '../models/models.dart';
import 'api_client.dart';

class EmbytokService {
  final ApiClient _apiClient;
  String? _embyServerUrl;
  String? _userId;
  String? _apiKey;

  EmbytokService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  // ============================
  // 认证配置
  // ============================

  // 配置 Emby 服务器连接信息（在其他 API 调用前设置）
  void setupAuth({
    required String embyServerUrl,
    required String userId,
    required String apiKey,
  }) {
    _embyServerUrl = embyServerUrl;
    _userId = userId;
    _apiKey = apiKey;
    _apiClient.setBaseUrl(embyServerUrl);
    _apiClient.setToken(apiKey);
  }

  // ============================
  // 登录：Emby /Users/AuthenticateByName
  // ============================

  Future<User> login({
    required String embyServerUrl,
    required String username,
    required String password,
  }) async {
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
    final authInfo = data['SessionInfo'] as Map<String, dynamic>? ?? {};
    final accessToken = data['AccessToken'] as String? ??
        (authInfo['AccessToken'] as String?) ??
        '';
    final serverId = (data['ServerId'] as String?) ?? '';

    final user = User(
      id: (userInfo['Id'] as String?) ?? '',
      name: (userInfo['Name'] as String?) ?? username,
      accessToken: accessToken,
      serverUrl: embyServerUrl,
      serverId: serverId,
    );

    // 保存配置方便后续直接调用
    _embyServerUrl = embyServerUrl;
    _userId = user.id;
    _apiKey = accessToken;
    _apiClient.setToken(accessToken);

    return user;
  }

  // ============================
  // 媒体库列表：/Library/VirtualFolders 或 /Library/MediaFolders
  // ============================

  Future<List<Library>> getLibraries() async {
    _requireAuth();
    final resp = await _apiClient.get<dynamic>(
      '/Library/VirtualFolders',
      queryParameters: {},
    );

    final items = resp.data is List
        ? resp.data as List<dynamic>
        : (resp.data['Items'] as List<dynamic>?) ?? [];

    return items
        .whereType<Map<String, dynamic>>()
        .map((e) => Library(
              id: (e['Id'] as String?) ?? (e['ItemId'] as String?) ?? '',
              name: (e['Name'] as String?) ?? '',
              type: (e['CollectionType'] as String?) ?? 'movies',
            ))
        .toList();
  }

  // ============================
  // 获取某媒体库下的视频列表：/Users/{userId}/Items
  // ============================

  Future<PaginatedResponse<MediaItem>> getLibraryItems(
    String libraryId, {
    int limit = 20,
    int offset = 0,
    String sortBy = 'DateCreated,SortName',
    String sortOrder = 'Descending',
    List<String>? includeTypes,
  }) async {
    _requireAuth();
    final params = <String, dynamic>{
      'ParentId': libraryId,
      'Limit': '$limit',
      'StartIndex': '$offset',
      'SortBy': sortBy,
      'SortOrder': sortOrder,
      'Recursive': 'true',
      'Fields':
          'Overview,Genres,People,CommunityRating,RunTimeTicks,ProductionYear,ImageTags,UserData',
      'IncludeItemTypes':
          includeTypes?.join(',') ?? 'Movie,Series,MusicVideo,Episode',
      if (_userId != null) 'UserId': _userId,
    };

    final path = _userId != null ? '/Users/$_userId/Items' : '/Items';
    final resp = await _apiClient.get<dynamic>(path, queryParameters: params);
    return _parsePaginatedResponse(resp.data);
  }

  // ============================
  // 获取项详情
  // ============================

  Future<MediaItem> getItemDetail(String itemId) async {
    _requireAuth();
    final params = <String, dynamic>{
      'Fields':
          'Overview,Genres,People,CommunityRating,CriticRating,OfficialRating,'
              'RunTimeTicks,ProductionYear,PremiereDate,DateCreated,Studios,'
              'MediaSources,UserData,ParentIndexNumber,IndexNumber,SeriesName,'
              'SeasonName,SeriesId,SeasonId,ImageTags,BackdropImageTags',
      if (_userId != null) 'UserId': _userId,
    };
    final path = _userId != null ? '/Users/$_userId/Items/$itemId' : '/Items/$itemId';
    final resp = await _apiClient.get<dynamic>(path, queryParameters: params);
    final data = resp.data is Map ? resp.data as Map<String, dynamic> : {};
    return MediaItem.fromJson(data);
  }

  // ============================
  // 继续观看列表
  // ============================

  Future<PaginatedResponse<MediaItem>> getResumeItems({
    int limit = 20,
    int offset = 0,
  }) async {
    _requireAuth();
    final params = <String, dynamic>{
      'Limit': '$limit',
      'StartIndex': '$offset',
      'Recursive': 'true',
      'Fields':
          'Overview,Genres,CommunityRating,RunTimeTicks,ProductionYear,ImageTags,UserData',
      if (_userId != null) 'UserId': _userId,
    };
    final path = _userId != null
        ? '/Users/$_userId/Items/Resume'
        : '/Items/Resume';
    final resp = await _apiClient.get<dynamic>(path, queryParameters: params);
    return _parsePaginatedResponse(resp.data);
  }

  // ============================
  // Next Up（下一步看什么）——剧集的下一集
  // ============================

  Future<PaginatedResponse<MediaItem>> getNextUp({int limit = 20}) async {
    _requireAuth();
    final params = <String, dynamic>{
      'Limit': '$limit',
      'Fields':
          'Overview,CommunityRating,RunTimeTicks,ProductionYear,ImageTags,UserData,SeriesName,ParentIndexNumber,IndexNumber',
      if (_userId != null) 'UserId': _userId,
    };
    final resp = await _apiClient.get<dynamic>(
      '/Shows/NextUp',
      queryParameters: params,
    );
    return _parsePaginatedResponse(resp.data);
  }

  // ============================
  // 最近添加
  // ============================

  Future<PaginatedResponse<MediaItem>> getRecentlyAdded({
    int limit = 20,
    int offset = 0,
    String? libraryId,
  }) async {
    _requireAuth();
    final params = <String, dynamic>{
      'Limit': '$limit',
      'StartIndex': '$offset',
      if (libraryId != null) 'ParentId': libraryId,
      'Recursive': 'true',
      'SortBy': 'DateCreated',
      'SortOrder': 'Descending',
      'Fields':
          'Overview,Genres,CommunityRating,RunTimeTicks,ProductionYear,ImageTags,UserData',
      'IncludeItemTypes': 'Movie,Series,MusicVideo',
      if (_userId != null) 'UserId': _userId,
    };
    final path =
        _userId != null ? '/Users/$_userId/Items/Latest' : '/Items/Latest';
    final resp = await _apiClient.get<dynamic>(path, queryParameters: params);

    // Latest 接口有些返回 flat array 而不是 { Items, TotalRecordCount }
    if (resp.data is List) {
      final items = resp.data as List<dynamic>;
      return PaginatedResponse(
        items: items
            .whereType<Map<String, dynamic>>()
            .map((e) => MediaItem.fromJson(e))
            .toList(),
        totalRecordCount: items.length,
      );
    }
    return _parsePaginatedResponse(resp.data);
  }

  // ============================
  // 相似影片
  // ============================

  Future<List<MediaItem>> getSimilarItems(
    String itemId, {
    int limit = 20,
  }) async {
    _requireAuth();
    final params = <String, dynamic>{
      'Limit': '$limit',
      'Fields':
          'Overview,Genres,CommunityRating,RunTimeTicks,ProductionYear,ImageTags,UserData',
      if (_userId != null) 'UserId': _userId,
    };
    final path =
        _userId != null
            ? '/Users/$_userId/Items/$itemId/Similar'
            : '/Items/$itemId/Similar';
    final resp = await _apiClient.get<dynamic>(path, queryParameters: params);
    final items = resp.data is List
        ? resp.data as List<dynamic>
        : (resp.data['Items'] as List<dynamic>?) ?? [];
    return items
        .whereType<Map<String, dynamic>>()
        .map((e) => MediaItem.fromJson(e))
        .toList();
  }

  // ============================
  // 人员（演员/导演）列表
  // ============================

  Future<List<Person>> getPeople({
    int limit = 50,
    List<String>? personTypes,
  }) async {
    _requireAuth();
    final params = <String, dynamic>{
      'Limit': '$limit',
      'Recursive': 'true',
      if (personTypes != null && personTypes.isNotEmpty)
        'PersonTypes': personTypes.join(','),
      'Fields': 'PrimaryImageTag,Overview',
    };
    final path =
        _userId != null ? '/Users/$_userId/Persons' : '/Persons';
    final resp = await _apiClient.get<dynamic>(path, queryParameters: params);
    final items = resp.data is List
        ? resp.data as List<dynamic>
        : (resp.data['Items'] as List<dynamic>?) ?? [];
    return items
        .whereType<Map<String, dynamic>>()
        .map((e) {
          // 解析 Person（Emby 字段）
          final id = (e['Id'] as String?) ?? '';
          final name = (e['Name'] as String?) ?? '';
          final imageTag = (e['PrimaryImageTag'] as String?) ??
              (e['ImageTags']?['Primary'] as String?);
          String? imgUrl;
          if (imageTag != null && _embyServerUrl != null) {
            imgUrl =
                '$_embyServerUrl/Items/$id/Images/Primary?MaxWidth=300&Tag=${Uri.encodeQueryComponent(imageTag)}&Format=jpg'
                '${_apiKey != null ? '&api_key=$_apiKey' : ''}';
          }
          return Person(
            id: id,
            name: name,
            type: (e['Type'] as String?) ?? 'Actor',
            imageUrl: imgUrl,
          );
        })
        .toList();
  }

  // ============================
  // 某演员出演的作品
  // ============================

  Future<PaginatedResponse<MediaItem>> getPersonItems(
    String personId, {
    int limit = 30,
    int offset = 0,
  }) async {
    _requireAuth();
    final params = <String, dynamic>{
      'Limit': '$limit',
      'StartIndex': '$offset',
      'Recursive': 'true',
      'PersonIds': personId,
      'Fields':
          'Overview,Genres,CommunityRating,RunTimeTicks,ProductionYear,ImageTags,UserData',
      if (_userId != null) 'UserId': _userId,
    };
    final path = _userId != null ? '/Users/$_userId/Items' : '/Items';
    final resp = await _apiClient.get<dynamic>(path, queryParameters: params);
    return _parsePaginatedResponse(resp.data);
  }

  // ============================
  // 类型列表
  // ============================

  Future<List<Library>> getGenres({int limit = 100}) async {
    _requireAuth();
    final params = <String, dynamic>{
      'Limit': '$limit',
      'Recursive': 'true',
      if (_userId != null) 'UserId': _userId,
    };
    final path = _userId != null ? '/Users/$_userId/Genres' : '/Genres';
    final resp = await _apiClient.get<dynamic>(path, queryParameters: params);
    final items = resp.data is List
        ? resp.data as List<dynamic>
        : (resp.data['Items'] as List<dynamic>?) ?? [];
    return items
        .whereType<Map<String, dynamic>>()
        .map((e) => Library(
              id: (e['Id'] as String?) ?? '',
              name: (e['Name'] as String?) ?? '',
              type: 'Genre',
            ))
        .toList();
  }

  // ============================
  // 某类型下的作品
  // ============================

  Future<PaginatedResponse<MediaItem>> getItemsByGenre(
    String genre, {
    int limit = 30,
    int offset = 0,
  }) async {
    _requireAuth();
    final params = <String, dynamic>{
      'Limit': '$limit',
      'StartIndex': '$offset',
      'Recursive': 'true',
      'Genres': genre,
      'Fields':
          'Overview,Genres,CommunityRating,RunTimeTicks,ProductionYear,ImageTags,UserData',
      if (_userId != null) 'UserId': _userId,
    };
    final path = _userId != null ? '/Users/$_userId/Items' : '/Items';
    final resp = await _apiClient.get<dynamic>(path, queryParameters: params);
    return _parsePaginatedResponse(resp.data);
  }

  // ============================
  // 工作室列表
  // ============================

  Future<List<Library>> getStudios({int limit = 100}) async {
    _requireAuth();
    final params = <String, dynamic>{
      'Limit': '$limit',
      'Recursive': 'true',
      if (_userId != null) 'UserId': _userId,
    };
    final path = _userId != null ? '/Users/$_userId/Studios' : '/Studios';
    final resp = await _apiClient.get<dynamic>(path, queryParameters: params);
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

  // ============================
  // 某工作室下的作品
  // ============================

  Future<PaginatedResponse<MediaItem>> getItemsByStudio(
    String studio, {
    int limit = 30,
    int offset = 0,
  }) async {
    _requireAuth();
    final params = <String, dynamic>{
      'Limit': '$limit',
      'StartIndex': '$offset',
      'Recursive': 'true',
      'Studios': studio,
      'Fields':
          'Overview,Genres,CommunityRating,RunTimeTicks,ProductionYear,ImageTags,UserData',
      if (_userId != null) 'UserId': _userId,
    };
    final path = _userId != null ? '/Users/$_userId/Items' : '/Items';
    final resp = await _apiClient.get<dynamic>(path, queryParameters: params);
    return _parsePaginatedResponse(resp.data);
  }

  // ============================
  // 收藏切换
  // ============================

  Future<void> toggleFavorite(String itemId, {required bool isFavorite}) async {
    _requireAuth();
    if (_userId == null) throw '未登录';
    if (isFavorite) {
      await _apiClient.post<dynamic>('/Users/$_userId/FavoriteItems/$itemId');
    } else {
      await _apiClient.delete<dynamic>('/Users/$_userId/FavoriteItems/$itemId');
    }
  }

  // ============================
  // 标记已看 / 未看
  // ============================

  Future<void> markAsPlayed(String itemId) async {
    _requireAuth();
    if (_userId == null) throw '未登录';
    await _apiClient.post<dynamic>(
      '/Users/$_userId/PlayedItems/$itemId',
    );
  }

  Future<void> markAsUnplayed(String itemId) async {
    _requireAuth();
    if (_userId == null) throw '未登录';
    await _apiClient.delete<dynamic>(
      '/Users/$_userId/PlayedItems/$itemId',
    );
  }

  // ============================
  // 剧集季列表
  // ============================

  Future<List<MediaItem>> getSeasons(String seriesId) async {
    _requireAuth();
    final params = <String, dynamic>{
      'Fields':
          'Overview,RunTimeTicks,ProductionYear,ImageTags,UserData,IndexNumber',
      if (_userId != null) 'UserId': _userId,
    };
    final path = '/Shows/$seriesId/Seasons';
    final resp = await _apiClient.get<dynamic>(path, queryParameters: params);
    final items = resp.data is List
        ? resp.data as List<dynamic>
        : (resp.data['Items'] as List<dynamic>?) ?? [];
    return items
        .whereType<Map<String, dynamic>>()
        .map((e) => MediaItem.fromJson(e))
        .toList();
  }

  // ============================
  // 剧集集列表
  // ============================

  Future<PaginatedResponse<MediaItem>> getEpisodes(
    String seriesId, {
    String? seasonId,
    int limit = 100,
    int offset = 0,
  }) async {
    _requireAuth();
    final params = <String, dynamic>{
      'Limit': '$limit',
      'StartIndex': '$offset',
      'Fields':
          'Overview,RunTimeTicks,ProductionYear,ImageTags,UserData,IndexNumber,ParentIndexNumber,SeriesName',
      if (_userId != null) 'UserId': _userId,
    };
    String path;
    if (seasonId != null && seasonId.isNotEmpty) {
      path = '/Shows/$seriesId/Episodes';
      params['SeasonId'] = seasonId;
    } else {
      path = '/Shows/$seriesId/Episodes';
    }
    final resp = await _apiClient.get<dynamic>(path, queryParameters: params);
    return _parsePaginatedResponse(resp.data);
  }

  // ============================
  // 预告片
  // ============================

  Future<PaginatedResponse<MediaItem>> getTrailers({
    int limit = 30,
    int offset = 0,
  }) async {
    _requireAuth();
    final params = <String, dynamic>{
      'Limit': '$limit',
      'StartIndex': '$offset',
      'Recursive': 'true',
      'IncludeItemTypes': 'Trailer',
      'Fields':
          'Overview,Genres,CommunityRating,RunTimeTicks,ProductionYear,ImageTags,UserData',
      if (_userId != null) 'UserId': _userId,
    };
    final path = _userId != null ? '/Users/$_userId/Items' : '/Items';
    final resp = await _apiClient.get<dynamic>(path, queryParameters: params);
    return _parsePaginatedResponse(resp.data);
  }

  // ============================
  // 播放信息（获取媒体源 & 音/字幕轨）
  // ============================

  Future<MediaItem?> getPlaybackInfo(String itemId) async {
    _requireAuth();
    // 通过 getItemDetail + MediaSources 信息获取播放信息
    // Emby 在 getItemDetail 时已经包含 MediaSources
    return getItemDetail(itemId);
  }

  // ============================
  // 上报播放进度 / 停止位置
  // ============================

  Future<void> reportPlaybackPosition({
    required String itemId,
    required int positionTicks,
    String? mediaSourceId,
    String? playSessionId,
  }) async {
    _requireAuth();
    final body = <String, dynamic>{
      'ItemId': itemId,
      'PositionTicks': positionTicks,
      if (mediaSourceId != null) 'MediaSourceId': mediaSourceId,
      if (playSessionId != null) 'PlaySessionId': playSessionId,
    };
    await _apiClient.post<dynamic>(
      '/Sessions/Playing/Progress',
      data: body,
    );
  }

  Future<void> reportPlaybackStopped({
    required String itemId,
    required int positionTicks,
    String? mediaSourceId,
    String? playSessionId,
  }) async {
    _requireAuth();
    final body = <String, dynamic>{
      'ItemId': itemId,
      'PositionTicks': positionTicks,
      if (mediaSourceId != null) 'MediaSourceId': mediaSourceId,
      if (playSessionId != null) 'PlaySessionId': playSessionId,
    };
    await _apiClient.post<dynamic>(
      '/Sessions/Playing/Stopped',
      data: body,
    );
  }

  // ============================
  // 搜索提示
  // ============================

  Future<List<SearchHint>> searchHints(
    String query, {
    int limit = 20,
  }) async {
    _requireAuth();
    if (query.isEmpty) return [];
    final params = <String, dynamic>{
      'SearchTerm': query,
      'Limit': '$limit',
      'Recursive': 'true',
      if (_userId != null) 'UserId': _userId,
    };
    final path =
        _userId != null
            ? '/Users/$_userId/Search/Hints'
            : '/Search/Hints';
    final resp = await _apiClient.get<dynamic>(path, queryParameters: params);
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
              thumbnailUrl: _embyServerUrl != null
                  ? '$_embyServerUrl/Items/${e['Id']}/Images/Primary?MaxWidth=200&Format=jpg${_apiKey != null ? '&api_key=$_apiKey' : ''}'
                  : null,
              year: (e['ProductionYear'] as int?) ?? (e['year'] as int?),
              seriesName: (e['SeriesName'] as String?),
            ))
        .toList();
  }

  // ============================
  // 通用搜索（获取完整 MediaItem 对象）
  // ============================

  Future<PaginatedResponse<MediaItem>> searchItems(
    String query, {
    int limit = 30,
    int offset = 0,
    List<String>? includeTypes,
  }) async {
    _requireAuth();
    if (query.isEmpty) return PaginatedResponse(items: [], totalRecordCount: 0);
    final params = <String, dynamic>{
      'SearchTerm': query,
      'Limit': '$limit',
      'StartIndex': '$offset',
      'Recursive': 'true',
      'Fields':
          'Overview,Genres,People,CommunityRating,RunTimeTicks,ProductionYear,ImageTags,UserData',
      if (includeTypes != null) 'IncludeItemTypes': includeTypes.join(','),
      if (_userId != null) 'UserId': _userId,
    };
    final path = _userId != null ? '/Users/$_userId/Items' : '/Items';
    final resp = await _apiClient.get<dynamic>(path, queryParameters: params);
    return _parsePaginatedResponse(resp.data);
  }

  // ============================
  // 辅助方法
  // ============================

  void _requireAuth() {
    if (_embyServerUrl == null || _embyServerUrl!.isEmpty) {
      throw '未配置 Emby 服务器地址，请先登录';
    }
  }

  PaginatedResponse<MediaItem> _parsePaginatedResponse(dynamic data) {
    if (data is! Map<String, dynamic>) {
      return PaginatedResponse(items: [], totalRecordCount: 0);
    }
    final items = (data['Items'] as List<dynamic>?) ?? [];
    final total = (data['TotalRecordCount'] as int?) ?? items.length;
    return PaginatedResponse(
      items: items
          .whereType<Map<String, dynamic>>()
          .map((e) => MediaItem.fromJson(e))
          .toList(),
      totalRecordCount: total,
    );
  }
}
