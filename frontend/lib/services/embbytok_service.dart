// 核心业务服务：直接调用 Emby 原生 API（不再经过后端）
// 设计思路：每个方法都接受可选的 serverUrl / token 参数，调用方可以显式传入，
// 也可以先调用 setupAuth 后使用无参方法。这样既有灵活性又便于 Provider 使用。

import 'dart:math';

import 'package:dio/dio.dart';

import '../models/models.dart';
import '../utils/logger.dart';
import 'api_client.dart';

class EmbytokService {
  static final EmbytokService _instance = EmbytokService._internal();

  factory EmbytokService() => _instance;

  EmbytokService._internal()
      : _apiClient = ApiClient();

  EmbytokService.withClient(this._apiClient);

  final ApiClient _apiClient;
  String? _defaultServerUrl;
  String? _defaultToken;
  // 保存当前登录用户的 userId，用于 Views 端点和云同步等需要用户身份的接口
  String? _defaultUserId;

  // ============================
  // 认证配置（设置默认 server/token，后续调用可省略参数）
  // ============================
  void setupAuth({
    required String embyServerUrl,
    required String apiKey,
    String? userId,
  }) {
    _defaultServerUrl = embyServerUrl;
    _defaultToken = apiKey;
    // 保存 userId 供后续 Views 端点和云同步使用
    _defaultUserId = userId;
    _apiClient.setBaseUrl(embyServerUrl);
    _apiClient.setToken(apiKey);
  }

  // 清除认证信息
  void clearAuth() {
    _defaultServerUrl = null;
    _defaultToken = null;
    _defaultUserId = null;
  }

  // ============================
  // 登录：Emby /Users/AuthenticateByName
  // ============================
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

      // 保存配置方便后续直接调用
      _defaultServerUrl = embyServerUrl;
      _defaultToken = accessToken;
      // 保存登录用户的 userId，供 Views 端点和云同步使用
      _defaultUserId = user.id;
      _apiClient.setToken(accessToken);

      AppLogger.info('登录成功', data: {'userId': user.id});
      return user;
    } catch (e) {
      AppLogger.error('登录请求失败', error: e);
      rethrow;
    }
  }

  // ============================
  // 媒体库列表：默认使用 /Users/{userId}/Views（用户视角），向后兼容 /Library/VirtualFolders
  // ============================
  Future<List<Library>> getLibraries({
    String? userId,
    String? serverUrl,
    String? token,
  }) async {
    AppLogger.debug('请求媒体库列表');
    _ensureConfig(serverUrl, token);
    // 优先使用传入的 userId，其次使用登录后保存的 _defaultUserId
    // 都没有时回退到管理员视角的 /Library/VirtualFolders
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
            ))
        .toList();

    AppLogger.debug('媒体库列表响应', data: {'count': libraries.length});
    return libraries;
  }

  // ============================
  // 用户视图：GET /Users/{userId}/Views（getLibraries 的别名，语义更明确）
  // ============================
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

  // ============================
  // 获取某媒体库下的视频列表
  // ============================
  Future<PaginatedResponse<MediaItem>> getLibraryItems(
    String libraryId, {
    int limit = 20,
    int offset = 0,
    String? userId,
    String? serverUrl,
    String? token,
  }) async {
    AppLogger.debug('请求视频列表', data: {
      'libraryId': libraryId,
      'limit': limit,
      'offset': offset,
    });
    _ensureConfig(serverUrl, token);
    final params = <String, dynamic>{
      'ParentId': libraryId,
      'Limit': '$limit',
      'StartIndex': '$offset',
      'SortBy': 'DateCreated,SortName',
      'SortOrder': 'Descending',
      'Recursive': 'true',
      'Fields':
          'Overview,Genres,People,CommunityRating,RunTimeTicks,ProductionYear,ImageTags,UserData,MediaSources,Path',
      'IncludeItemTypes': 'Movie,Episode,Video,MusicVideo,Series',
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
    final result = _parsePaginatedResponse(resp.data, offset: offset, limit: limit);
    AppLogger.debug('视频列表响应', data: {
      'count': result.items.length,
      'total': result.total,
    });
    return result;
  }

  // ============================
  // 获取项详情
  // ============================
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

  // ============================
  // 继续观看列表
  // ============================
  Future<PaginatedResponse<MediaItem>> getResumeItems({
    int limit = 20,
    int offset = 0,
    String? serverUrl,
    String? token,
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
    final resp = await _apiClient.get<dynamic>(
      '/Items/Resume',
      queryParameters: params,
    );
    return _parsePaginatedResponse(resp.data, offset: offset, limit: limit);
  }

  // ============================
  // 推荐列表：按社区评分从高到低排序
  // ============================
  Future<PaginatedResponse<MediaItem>> getRecommendations({
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
      'SortBy': 'CommunityRating,SortName',
      'SortOrder': 'Descending',
      'MinCommunityRating': '6.0',
      'Fields':
          'Overview,Genres,People,CommunityRating,RunTimeTicks,ProductionYear,ImageTags,UserData,MediaSources,Path',
      'IncludeItemTypes': 'Movie,Episode,Video,MusicVideo,Series',
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

  // ============================
  // Next Up（下一步看什么）—— 剧集的下一集
  // 可选 seriesId：传入则只返回指定剧集的下一集
  // ============================
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
    // 指定 seriesId 时只查询该剧集的下一集
    if (seriesId != null && seriesId.isNotEmpty) {
      params['SeriesId'] = seriesId;
    }
    final resp = await _apiClient.get<dynamic>(
      '/Shows/NextUp',
      queryParameters: params,
    );
    return _parsePaginatedResponse(resp.data, offset: 0, limit: limit);
  }

  // ============================
  // 最近添加
  // ============================
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

  // ============================
  // 相似影片
  // ============================
  Future<List<MediaItem>> getSimilarItems(
    String itemId, {
    int limit = 20,
    String? serverUrl,
    String? token,
  }) async {
    _ensureConfig(serverUrl, token);
    final params = <String, dynamic>{
      'Limit': '$limit',
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

  // ============================
  // 人员（演员/导演）列表
  // ============================
  Future<PaginatedResponse<Person>> getPeople({
    int limit = 50,
    int startIndex = 0,
    List<String>? personTypes,
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
    // 使用传入的 token 或默认 token
    final effectiveToken = token ?? _defaultToken;
    final people = items
        .whereType<Map<String, dynamic>>()
        .map((e) {
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
        })
        .toList();
    return PaginatedResponse<Person>(
      items: people,
      total: total,
      offset: startIndex,
      limit: limit,
    );
  }

  // ============================
  // 某演员出演的作品
  // ============================
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

  // ============================
  // 获取单个演员详情（包含 overview）
  // ============================
  Future<MediaItem?> getPersonDetail(
    String personId, {
    String? serverUrl,
    String? token,
  }) async {
    _ensureConfig(serverUrl, token);
    final params = <String, dynamic>{
      'Fields': 'Overview,Genres,CommunityRating,ProductionYear,ImageTags,UserData',
    };
    try {
      final resp = await _apiClient.get<dynamic>(
        '/Items/$personId',
        queryParameters: params,
      );
      if (resp.data is Map<String, dynamic>) {
        return MediaItem.fromJson(resp.data);
      }
      return null;
    } catch (e) {
      AppLogger.error('获取演员详情失败', error: e);
      return null;
    }
  }

  // ============================
  // 类型列表（Genres）
  // ============================
  Future<List<Library>> getGenres({
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
      '/Genres',
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
              type: 'Genre',
            ))
        .toList();
  }

  // ============================
  // 某类型下的影片
  // ============================
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
      'Fields':
          'Overview,Genres,CommunityRating,RunTimeTicks,ProductionYear,ImageTags,UserData',
    };
    final resp = await _apiClient.get<dynamic>(
      '/Items',
      queryParameters: params,
    );
    return _parsePaginatedResponse(resp.data, offset: offset, limit: limit);
  }

  // ============================
  // 工作室列表
  // ============================
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

  // ============================
  // 某工作室下的影片
  // ============================
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

  // ============================
  // 收藏列表（从 Emby 获取）
  // ============================
  Future<List<MediaItem>> getFavorites({
    int limit = 100,
    int offset = 0,
    String? serverUrl,
    String? token,
  }) async {
    _ensureConfig(serverUrl, token);
    final params = <String, dynamic>{
      'Limit': '$limit',
      'StartIndex': '$offset',
      'Recursive': 'true',
      'Filters': 'IsFavorite',
      'Fields':
          'Overview,Genres,CommunityRating,RunTimeTicks,ProductionYear,ImageTags,UserData',
      'SortBy': 'DateCreated',
      'SortOrder': 'Descending',
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
        .map((e) => MediaItem.fromJson(e))
        .toList();
  }

  // ============================
  // 收藏影片（按类型：电影/剧集/音乐视频/单集，使用用户视图路径，与 EmbyX 对齐）
  // ============================
  Future<List<MediaItem>> getFavoriteMovies({
    int limit = 100,
    int offset = 0,
    String? userId,
    String? serverUrl,
    String? token,
  }) async {
    _ensureConfig(serverUrl, token);
    final params = <String, dynamic>{
      'Limit': '$limit',
      'StartIndex': '$offset',
      'Recursive': 'true',
      'Filters': 'IsFavorite',
      'Fields':
          'Overview,Genres,CommunityRating,RunTimeTicks,ProductionYear,ImageTags,UserData',
      'IncludeItemTypes': 'Movie,Episode,Video,MusicVideo,Series',
      'ExcludeItemTypes': 'Playlist',
      'SortBy': 'DateCreated',
      'SortOrder': 'Descending',
    };

    final effectiveUserId = userId ?? _defaultUserId;
    final path = (effectiveUserId != null && effectiveUserId.isNotEmpty)
        ? '/Users/$effectiveUserId/Items'
        : '/Items';

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

  // ============================
  // 收藏合集（BoxSet，使用用户视图路径，与 EmbyX 对齐）
  // ============================
  Future<List<MediaItem>> getFavoriteBoxSets({
    int limit = 100,
    int offset = 0,
    String? userId,
    String? serverUrl,
    String? token,
  }) async {
    _ensureConfig(serverUrl, token);
    final params = <String, dynamic>{
      'Limit': '$limit',
      'StartIndex': '$offset',
      'Recursive': 'true',
      'Filters': 'IsFavorite',
      'Fields':
          'Overview,Genres,CommunityRating,RunTimeTicks,ProductionYear,ImageTags,UserData',
      'IncludeItemTypes': 'BoxSet',
      'SortBy': 'DateCreated',
      'SortOrder': 'Descending',
    };

    final effectiveUserId = userId ?? _defaultUserId;
    final path = (effectiveUserId != null && effectiveUserId.isNotEmpty)
        ? '/Users/$effectiveUserId/Items'
        : '/Items';

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

  // ============================
  // 收藏人物（Person，使用用户视图路径，与 EmbyX 对齐）
  // ============================
  Future<List<MediaItem>> getFavoritePeople({
    int limit = 100,
    int offset = 0,
    String? userId,
    String? serverUrl,
    String? token,
  }) async {
    _ensureConfig(serverUrl, token);
    final params = <String, dynamic>{
      'Limit': '$limit',
      'StartIndex': '$offset',
      'Recursive': 'true',
      'Filters': 'IsFavorite',
      'Fields':
          'Overview,Genres,CommunityRating,RunTimeTicks,ProductionYear,ImageTags,UserData',
      'IncludeItemTypes': 'Person',
      'SortBy': 'DateCreated',
      'SortOrder': 'Descending',
    };

    final effectiveUserId = userId ?? _defaultUserId;
    final path = (effectiveUserId != null && effectiveUserId.isNotEmpty)
        ? '/Users/$effectiveUserId/Items'
        : '/Items';

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

  // ============================
  // 切换收藏状态（带 userId 端点，与 EmbyX 对齐）
  // ============================
  Future<void> toggleFavorite({
    required String itemId,
    required bool isFavorite,
    String? userId,
    String? serverUrl,
    String? token,
  }) async {
    AppLogger.debug('切换收藏状态请求', data: {
      'itemId': itemId,
      'isFavorite': isFavorite,
    });
    _ensureConfig(serverUrl, token);
    // 使用带 userId 端点：/Users/{userId}/FavoriteItems/{itemId}
    // 无 userId 时回退到无 userId 的短路径
    final effectiveUserId = userId ?? _defaultUserId;
    final path = (effectiveUserId ?? '').isNotEmpty
        ? '/Users/$effectiveUserId/FavoriteItems/$itemId'
        : '/UserFavoriteItems/$itemId';
    if (isFavorite) {
      await _apiClient.post<dynamic>(path);
    } else {
      await _apiClient.delete<dynamic>(path);
    }
    AppLogger.debug('收藏状态已更新');
  }

  // ============================
  // 标记已看 / 未看
  // ============================
  Future<void> markAsPlayed(
    String itemId, {
    String? serverUrl,
    String? token,
  }) async {
    _ensureConfig(serverUrl, token);
    await _apiClient.post<dynamic>('/UserPlayedItems/$itemId');
  }

  Future<void> markAsUnplayed(
    String itemId, {
    String? serverUrl,
    String? token,
  }) async {
    _ensureConfig(serverUrl, token);
    await _apiClient.delete<dynamic>('/UserPlayedItems/$itemId');
  }

  // ============================
  // 剧集季列表
  // ============================
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

  // ============================
  // 剧集集列表
  // ============================
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
    String path;
    if (seasonId != null && seasonId.isNotEmpty) {
      path = '/Shows/$seriesId/Episodes';
    } else {
      path = '/Shows/$seriesId/Episodes';
    }
    final resp = await _apiClient.get<dynamic>(path, queryParameters: params);
    return _parsePaginatedResponse(resp.data, offset: offset, limit: limit);
  }

  // ============================
  // 预告片
  // ============================
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

  // ============================
  // 播放信息（通过 getItemDetail 获取，MediaSources 在详情中已包含）
  // ============================
  Future<MediaItem?> getPlaybackInfo(
    String itemId, {
    String? serverUrl,
    String? token,
  }) async {
    return getItemDetail(itemId, serverUrl: serverUrl, token: token);
  }

  // ============================
  // 字幕 Cues 加载（从 Emby 获取并解析 SRT/VTT）
  // - index: 字幕轨道 index（与 MediaStream.index）
  // - mediaSourceId: 媒体源 ID
  //
  // 字幕 URL 格式：/Videos/{itemId}/{mediaSourceId}/Subtitles/{index}/0/36000000000.{format}
  // 返回：按 start / end / text
  // ============================
  Future<List<SubtitleCue>> getSubtitleCues({
    required String itemId,
    required String mediaSourceId,
    required int index,
    String format = 'srt',
    String? serverUrl,
    String? token,
  }) async {
    _ensureConfig(serverUrl, token);
    try {
      // URL: /Videos/{itemId}/{mediaSourceId}/Subtitles/{index}/0/36000000000.{format}
      // 36000000000 = 1小时（1 tick = 100ns）
      final url =
          '/Videos/$itemId/$mediaSourceId/Subtitles/$index/0/36000000000.$format';
      // 需要非 JSON 请求（SRT 文本）
      final resp = await _apiClient.dio.get<String>(
        url,
        options: Options(
          headers: {
            'Accept': 'text/plain',
          },
        ),
      );
      final text = resp.data;
      if (text == null || text.isEmpty) return const <SubtitleCue>[];
      // 调用 parseSrt 解析
      return parseSrt(text);
    } catch (e) {
      // 字幕加载失败不中断播放，返回空列表
      return const <SubtitleCue>[];
    }
  }

  // ============================
  // 上报播放进度 / 停止位置
  // ============================

  // 上报播放能力（播放开始前调用）
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
      // 上报失败不中断播放：仅记录日志，不抛到 UI 层
      AppLogger.debug('上报播放能力失败', data: {'error': e.toString()});
    }
  }

  // 上报播放开始
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
    // 未传 playSessionId 时自动生成（时间戳 + 短随机数，不依赖 uuid 包）
    final effectiveSessionId = playSessionId ?? _generatePlaySessionId();
    final body = <String, dynamic>{
      'ItemId': itemId,
      'PositionTicks': 0,
      'IsPaused': isPaused,
      'IsMuted': isMuted,
      'PlayMethod': playMethod,
      'EventName': 'TimeUpdate',
      'CanSeek': true,
      'QueueableMediaTypes': ['Video'],
      'MediaSourceId': mediaSourceId ?? itemId,
      'PlaySessionId': effectiveSessionId,
      if (volumeLevel != null) 'VolumeLevel': volumeLevel,
    };
    try {
      await _apiClient.post<dynamic>(
        '/Sessions/Playing',
        data: body,
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
      await _apiClient.post<dynamic>(
        '/Sessions/Playing/Stopped',
        data: body,
      );
    } catch (e) {
      AppLogger.debug('上报播放停止失败', data: {'error': e.toString()});
    }
  }

  // ============================
  // 观看历史（从 Emby 获取最近观看的条目）
  //
  // 优先使用用户级路径 /Users/{userId}/Items，该路径在多数 Emby 服务器上
  // 对继续观看列表的权限更明确。若 userId 为空，则降级到全局 /Items
  // 并附加 UserId 查询参数保证向后兼容。
  // ============================
  Future<List<MediaItem>> getWatchHistory({
    int limit = 50,
    String? userId,
    String? serverUrl,
    String? token,
  }) async {
    _ensureConfig(serverUrl, token);
    final effectiveUserId = userId ?? _defaultUserId;

    // 先决定路径：用户级路径优先，降级到全局 /Items
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
      // 仅在降级到全局 /Items 路径时附加 UserId 参数
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

  // ============================
  // 搜索提示
  // ============================
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

  // ============================
  // 通用搜索（获取完整 MediaItem 对象，使用用户视图路径，与 EmbyX 对齐）
  // ============================
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
    final result = _parsePaginatedResponse(resp.data, offset: offset, limit: limit);
    AppLogger.debug('搜索响应', data: {
      'results': result.items.length,
      'total': result.total,
    });
    return result;
  }

  // ============================
  // 获取子项（孩子节点）
  // ============================
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
    final result = _parsePaginatedResponse(resp.data, offset: offset, limit: limit);
    return result.items;
  }

  // ============================
  // 续播云同步：使用 DisplayPreferences 实现跨设备续播同步
  // ============================

  // 保存续播位置到云端（DisplayPreferences）
  Future<void> saveCloudSync({
    required String itemId,
    required String libraryId,
    String? libraryType,
    String? serverUrl,
    String? token,
  }) async {
    AppLogger.debug('保存续播云同步', data: {'itemId': itemId});
    _ensureConfig(serverUrl, token);
    // 使用登录后保存的 userId，未配置则跳过云同步
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

  // 从云端获取续播位置
  Future<Map<String, dynamic>?> checkCloudSync({
    String? serverUrl,
    String? token,
  }) async {
    AppLogger.debug('检查续播云同步');
    _ensureConfig(serverUrl, token);
    // 使用登录后保存的 userId，未配置则返回 null
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

  // ============================
  // 通用 POST 请求
  // ============================
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

  // ============================
  // 通用 DELETE 请求
  // ============================
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

  // ============================
  // 删除媒体项
  // ============================
  /// 删除指定的媒体项（调用 Emby DELETE /Items/{itemId}）
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

  // ============================
  // 内部辅助方法
  // ============================

  // 生成播放会话 ID：时间戳 + 真随机数，降低碰撞概率
  String _generatePlaySessionId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final rand = Random().nextInt(0xFFFF).toRadixString(16).padLeft(4, '0');
    return 'emb-$now-$rand';
  }

  // 确保 API client 已配置 serverUrl 和 token
  void _ensureConfig(String? serverUrl, String? token) {
    final url = serverUrl ?? _defaultServerUrl;
    final tk = token ?? _defaultToken;
    if (url == null || url.isEmpty) {
      AppLogger.warn('服务器地址未配置');
      throw '请先登录或提供 Emby 服务器地址';
    }
    if (url != _apiClient.optionsBaseUrl) {
      _apiClient.setBaseUrl(url);
    }
    if (tk != null && tk.isNotEmpty) {
      _apiClient.setToken(tk);
    }
  }

  // 解析分页响应
  PaginatedResponse<MediaItem> _parsePaginatedResponse(
    dynamic data, {
    int offset = 0,
    int limit = 20,
  }) {
    if (data is! Map<String, dynamic>) {
      return PaginatedResponse<MediaItem>(
        items: const <MediaItem>[],
        total: 0,
        offset: offset,
        limit: limit,
      );
    }
    final items = (data['Items'] as List<dynamic>?) ?? [];
    final total = (data['TotalRecordCount'] as int?) ?? items.length;
    return PaginatedResponse(
      items: items
          .whereType<Map<String, dynamic>>()
          .map((e) => MediaItem.fromJson(e))
          .toList(),
      total: total,
      offset: offset,
      limit: limit,
    );
  }
}
