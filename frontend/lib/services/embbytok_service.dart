// EmbytokService：直接与 Emby 服务器通信
// 不再需要 FastAPI 中间层
//
// 核心 API 映射（已实现）：
//   登录          → POST /Users/AuthenticateByName
//   媒体库列表    → GET  /Library/VirtualFolders
//   视频列表      → GET  /Items?ParentId=...&Recursive=true
//   搜索          → GET  /Items?SearchTerm=...
//   收藏列表      → GET  /Items?Filters=IsFavorite
//   切换收藏      → POST/DELETE /Users/{userId}/FavoriteItems/{itemId}
//   播放进度      → POST /Users/{userId}/PlayingItems/{itemId}/Progress
//   播放停止      → POST /Users/{userId}/PlayingItems/{itemId}/Stopped
//
// 新增的 API 映射（v1.2）：
//   项详情         → GET  /Users/{userId}/Items/{itemId}?Fields=...
//   继续观看       → GET  /Users/{userId}/Items/Resume
//   Next Up       → GET  /Shows/NextUp
//   最近加入       → GET  /Users/{userId}/Items/Latest
//   相似影片       → GET  /Items/{itemId}/Similar
//   人员列表       → GET  /Persons?PersonTypes=Actor,Director
//   人员作品       → GET  /Persons/{personId}/Items
//   类型/工作室    → GET  /Genres | /Studios
//   类型下影片     → GET  /Items?Genres=<name>
//   预告片         → GET  /Items?IncludeItemTypes=Trailer
//   标记已看/未看  → POST/DELETE /Users/{userId}/PlayedItems/{itemId}
//   搜索提示       → GET  /Search/Hints
//   播放信息(音轨/字幕轨) → GET /Items/{itemId}/PlaybackInfo
//   剧集季         → GET  /Shows/{seriesId}/Seasons
//   剧集集         → GET  /Shows/{seriesId}/Episodes
//   系统信息       → GET  /System/Info

import 'dart:convert';
import 'dart:math' as math;

import '../models/models.dart';
import 'api_client.dart';

class EmbytokService {
  final ApiClient _apiClient;

  // 鉴权信息（登录后由 setupAuth 配置）
  String? _embyServerUrl;
  String? _apiKey; // 即 Emby AccessToken
  String? _userId;

  EmbytokService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  // 暴露给外部用于构造 URL 的只读属性
  String? get embyServerUrl => _embyServerUrl;
  String? get apiKey => _apiKey;
  String? get userId => _userId;

  // ========================================================================
  // 鉴权 / 连接
  // ========================================================================

  void setupAuth({
    required String embyServerUrl,
    required String userId,
    required String apiKey,
  }) {
    _embyServerUrl = embyServerUrl.endsWith('/')
        ? embyServerUrl.substring(0, embyServerUrl.length - 1)
        : embyServerUrl;
    _apiKey = apiKey;
    _userId = userId;

    _apiClient.setBaseUrl(_embyServerUrl!);
    _apiClient.setToken(apiKey);
    _apiClient.setUserId(userId);
  }

  // 登录：POST /Users/AuthenticateByName
  Future<Map<String, dynamic>> login({
    required String embyServerUrl,
    required String username,
    required String password,
  }) async {
    final base = embyServerUrl.endsWith('/')
        ? embyServerUrl.substring(0, embyServerUrl.length - 1)
        : embyServerUrl;
    _apiClient.setBaseUrl(base);

    final body = <String, dynamic>{
      'Username': username,
      'Pw': password,
    };

    final resp = await _apiClient.post<dynamic>(
      '/Users/AuthenticateByName',
      data: body,
    );

    final data = _asMap(resp.data);

    final accessToken = data['AccessToken'] as String?;
    final userObj = data['User'] as Map<String, dynamic>?;
    final uid = userObj?['Id'] as String?;

    if (accessToken != null && uid != null) {
      _apiKey = accessToken;
      _userId = uid;
      _embyServerUrl = base;
      _apiClient.setToken(accessToken);
      _apiClient.setUserId(uid);
    }

    return data;
  }

  // 服务器可达性验证：GET /System/Info/Public（无需鉴权）
  Future<Map<String, dynamic>> pingServer(String embyServerUrl) async {
    final base = embyServerUrl.endsWith('/')
        ? embyServerUrl.substring(0, embyServerUrl.length - 1)
        : embyServerUrl;
    _apiClient.setBaseUrl(base);
    final resp = await _apiClient.get<dynamic>('/System/Info/Public');
    return _asMap(resp.data);
  }

  // 系统信息：GET /System/Info（需鉴权）
  Future<Map<String, dynamic>> getSystemInfo() async {
    _requireAuth();
    final resp = await _apiClient.get<dynamic>('/System/Info');
    return _asMap(resp.data);
  }

  // ========================================================================
  // 媒体库 / 视频列表
  // ========================================================================

  // 媒体库列表
  Future<List<Library>> getLibraries() async {
    _requireAuth();
    final resp = await _apiClient.get<dynamic>('/Library/VirtualFolders');
    final list = _asList(resp.data);
    final libraries = list.map((e) => Library.fromJson(_asMap(e))).toList();

    const usefulTypes = <String>{
      'movies',
      'tvshows',
      'homevideos',
      'mixed',
      'boxsets',
      '',
    };
    return libraries.where((lib) {
      final type = lib.type.toLowerCase();
      return usefulTypes.contains(type) ||
          usefulTypes.contains(lib.collectionType?.toLowerCase() ?? '');
    }).toList();
  }

  // 视频列表（库内）
  Future<PaginatedResponse<MediaItem>> getItems({
    String? libraryId,
    String? libraryType,
    int limit = 20,
    int offset = 0,
  }) async {
    _requireAuth();
    final sortInfo = _selectSortStrategy(libraryType);
    final params = <String, dynamic>{
      'Recursive': true,
      'IncludeItemTypes': 'Movie,Episode,Video,MusicVideo',
      'Fields': 'Overview,Genres,CommunityRating,ProductionYear,'
          'RuntimeTicks,UserData,DateCreated,PremiereDate,People,'
          'Studios,ImageTags,BackdropImageTags',
      'SortBy': sortInfo.sortBy,
      'SortOrder': sortInfo.sortOrder,
      'StartIndex': offset,
      'Limit': limit,
      if (_userId != null) 'UserId': _userId,
      if (libraryId != null && libraryId.isNotEmpty) 'ParentId': libraryId,
    };

    final resp = await _apiClient.get<dynamic>(
      '/Items',
      queryParameters: params,
    );
    return _parsePaginatedItems(resp.data, offset, limit);
  }

  // ========================================================================
  // 项详情（完整字段：演员、评分、类型、音轨等）
  // ========================================================================

  // 详情：GET /Users/{userId}/Items/{itemId}?Fields=...
  Future<MediaItem> getItemDetail(String itemId) async {
    _requireAuth();
    final params = <String, dynamic>{
      'Fields': 'Overview,Genres,People,CommunityRating,CriticRating,'
          'OfficialRating,RuntimeTicks,ProductionYear,PremiereDate,'
          'DateCreated,Studios,MediaSources,UserData,ParentIndexNumber,'
          'IndexNumber,SeriesName,SeasonName,SeriesId,SeasonId,'
          'ImageTags,BackdropImageTags,RunTimeTicks',
      if (_userId != null) 'UserId': _userId,
    };

    final path = '/Users/$_userId/Items/$itemId';
    final resp = await _apiClient.get<dynamic>(
      path,
      queryParameters: params,
    );

    final data = _asMap(resp.data);
    // 注入缩略图/播放 URL/认证头
    return MediaItem.fromJson(data)
        .withEmbyUrls(_embyServerUrl!, _apiKey!);
  }

  // ========================================================================
  // 继续观看 / Next Up / 最近加入
  // ========================================================================

  // 继续观看：GET /Users/{userId}/Items/Resume?Recursive=true&Limit=...
  Future<PaginatedResponse<MediaItem>> getResumeItems({
    int limit = 20,
    int offset = 0,
  }) async {
    _requireAuth();
    final params = <String, dynamic>{
      'Recursive': true,
      'Limit': limit,
      'Fields': 'Overview,Genres,CommunityRating,ProductionYear,'
          'RuntimeTicks,UserData,ImageTags',
      'StartIndex': offset,
      if (_userId != null) 'UserId': _userId,
    };
    final path = '/Users/$_userId/Items/Resume';
    final resp = await _apiClient.get<dynamic>(
      path,
      queryParameters: params,
    );
    return _parsePaginatedItems(resp.data, offset, limit);
  }

  // Next Up（下一步看什么）：GET /Shows/NextUp
  Future<PaginatedResponse<MediaItem>> getNextUp({int limit = 20}) async {
    _requireAuth();
    final params = <String, dynamic>{
      'Limit': limit,
      'Fields': 'Overview,CommunityRating,ProductionYear,RuntimeTicks,'
          'UserData,ImageTags,SeriesName,SeasonName,IndexNumber,ParentIndexNumber',
      if (_userId != null) 'UserId': _userId,
    };
    final resp = await _apiClient.get<dynamic>(
      '/Shows/NextUp',
      queryParameters: params,
    );
    return _parsePaginatedItems(resp.data, 0, limit);
  }

  // 最近加入：GET /Users/{userId}/Items/Latest（Emby 原生推荐接口）
  // 或者使用 GET /Items?SortBy=DateCreated&SortOrder=Descending
  Future<PaginatedResponse<MediaItem>> getRecentlyAdded({
    String? libraryId,
    int limit = 20,
    int offset = 0,
  }) async {
    _requireAuth();
    final params = <String, dynamic>{
      'Recursive': true,
      'IncludeItemTypes': 'Movie,Season,Series,MusicVideo',
      'SortBy': 'DateCreated',
      'SortOrder': 'Descending',
      'Limit': limit,
      'StartIndex': offset,
      'Fields': 'Overview,CommunityRating,ProductionYear,RuntimeTicks,'
          'UserData,DateCreated,ImageTags,SeriesName',
      if (_userId != null) 'UserId': _userId,
      if (libraryId != null && libraryId.isNotEmpty) 'ParentId': libraryId,
    };
    final resp = await _apiClient.get<dynamic>(
      '/Items',
      queryParameters: params,
    );
    return _parsePaginatedItems(resp.data, offset, limit);
  }

  // ========================================================================
  // 相似影片
  // ========================================================================

  // 相似影片：GET /Items/{itemId}/Similar
  Future<List<MediaItem>> getSimilarItems(
    String itemId, {
    int limit = 12,
  }) async {
    _requireAuth();
    final params = <String, dynamic>{
      'Limit': limit,
      'Fields': 'Overview,CommunityRating,ProductionYear,RuntimeTicks,'
          'UserData,ImageTags',
      if (_userId != null) 'UserId': _userId,
    };
    final resp = await _apiClient.get<dynamic>(
      '/Items/$itemId/Similar',
      queryParameters: params,
    );
    return _parseMediaItemList(resp.data);
  }

  // ========================================================================
  // 人员（演员/导演）
  // ========================================================================

  // 人员列表：GET /Persons?PersonTypes=Actor,Director&Recursive=true&Limit=...
  // 按出演作品数（ItemCount）排序
  Future<List<Person>> getPeople({
    String personTypes = 'Actor,Director',
    int limit = 50,
    int offset = 0,
  }) async {
    _requireAuth();
    final params = <String, dynamic>{
      'PersonTypes': personTypes,
      'Recursive': true,
      'SortBy': 'SortName',
      'SortOrder': 'Ascending',
      'StartIndex': offset,
      'Limit': limit,
      'Fields': 'Overview,ImageTags',
      if (_userId != null) 'UserId': _userId,
    };
    final resp = await _apiClient.get<dynamic>(
      '/Persons',
      queryParameters: params,
    );
    final list = _asList(resp.data);
    // Persons 响应可能是 {Items: [...], TotalRecordCount: N} 或 [...]
    final items = (list.isNotEmpty)
        ? list
        : (resp.data is Map<String, dynamic>
            ? _asList((resp.data as Map<String, dynamic>)['Items'])
            : <dynamic>[]);

    final base = _embyServerUrl!;
    final key = _apiKey!;
    return items
        .map((e) => Person.fromJson(_asMap(e)).withEmbyUrls(base, key))
        .toList();
  }

  // 人员作品：GET /Persons/{personId}/Items
  Future<PaginatedResponse<MediaItem>> getPersonItems(
    String personId, {
    int limit = 50,
    int offset = 0,
  }) async {
    _requireAuth();
    final params = <String, dynamic>{
      'IncludeItemTypes': 'Movie,Series,Episode,MusicVideo',
      'Recursive': true,
      'SortBy': 'ProductionYear,DateCreated',
      'SortOrder': 'Descending',
      'Limit': limit,
      'StartIndex': offset,
      'Fields': 'Overview,CommunityRating,ProductionYear,RuntimeTicks,'
          'UserData,ImageTags',
      if (_userId != null) 'UserId': _userId,
    };
    final resp = await _apiClient.get<dynamic>(
      '/Persons/$personId/Items',
      queryParameters: params,
    );
    return _parsePaginatedItems(resp.data, offset, limit);
  }

  // ========================================================================
  // 类型 / 工作室 / 标签
  // ========================================================================

  // 类型列表：GET /Genres?Recursive=true
  Future<List<Library>> getGenres({int limit = 100}) async {
    _requireAuth();
    final params = <String, dynamic>{
      'Recursive': true,
      'Limit': limit,
      'SortBy': 'SortName',
      'SortOrder': 'Ascending',
      if (_userId != null) 'UserId': _userId,
    };
    final resp = await _apiClient.get<dynamic>(
      '/Genres',
      queryParameters: params,
    );
    // Genres 的响应结构是 {Items:[{Name, Id, ...}], TotalRecordCount}
    // 我们把它转换为简化的 Library 对象（id = Id, name = Name, type = 'genre'）
    final list = _asList(_asMap(resp.data)['Items'] ?? resp.data);
    return list.map((e) {
      final m = _asMap(e);
      return Library(
        id: (m['Id'] as String?) ?? '',
        name: (m['Name'] as String?) ?? '',
        type: 'genre',
      );
    }).toList();
  }

  // 工作室列表：GET /Studios?Recursive=true
  Future<List<Library>> getStudios({int limit = 100}) async {
    _requireAuth();
    final params = <String, dynamic>{
      'Recursive': true,
      'Limit': limit,
      'SortBy': 'SortName',
      'SortOrder': 'Ascending',
      if (_userId != null) 'UserId': _userId,
    };
    final resp = await _apiClient.get<dynamic>(
      '/Studios',
      queryParameters: params,
    );
    final list = _asList(_asMap(resp.data)['Items'] ?? resp.data);
    return list.map((e) {
      final m = _asMap(e);
      return Library(
        id: (m['Id'] as String?) ?? '',
        name: (m['Name'] as String?) ?? '',
        type: 'studio',
      );
    }).toList();
  }

  // 按类型获取影片：GET /Items?Genres=<name>
  Future<PaginatedResponse<MediaItem>> getItemsByGenre(
    String genre, {
    int limit = 40,
    int offset = 0,
  }) async {
    _requireAuth();
    final params = <String, dynamic>{
      'Genres': genre,
      'IncludeItemTypes': 'Movie,Series',
      'Recursive': true,
      'SortBy': 'CommunityRating,ProductionYear',
      'SortOrder': 'Descending',
      'Limit': limit,
      'StartIndex': offset,
      'Fields': 'Overview,CommunityRating,ProductionYear,RuntimeTicks,'
          'UserData,ImageTags,Genres',
      if (_userId != null) 'UserId': _userId,
    };
    final resp = await _apiClient.get<dynamic>(
      '/Items',
      queryParameters: params,
    );
    return _parsePaginatedItems(resp.data, offset, limit);
  }

  // 按工作室获取影片：GET /Items?Studios=<name>
  Future<PaginatedResponse<MediaItem>> getItemsByStudio(
    String studio, {
    int limit = 40,
    int offset = 0,
  }) async {
    _requireAuth();
    final params = <String, dynamic>{
      'Studios': studio,
      'IncludeItemTypes': 'Movie,Series',
      'Recursive': true,
      'SortBy': 'ProductionYear,DateCreated',
      'SortOrder': 'Descending',
      'Limit': limit,
      'StartIndex': offset,
      'Fields': 'Overview,CommunityRating,ProductionYear,RuntimeTicks,'
          'UserData,ImageTags,Studios',
      if (_userId != null) 'UserId': _userId,
    };
    final resp = await _apiClient.get<dynamic>(
      '/Items',
      queryParameters: params,
    );
    return _parsePaginatedItems(resp.data, offset, limit);
  }

  // ========================================================================
  // 搜索 / 搜索提示
  // ========================================================================

  // 搜索：GET /Items?SearchTerm=...（已存在于原代码，这里仅增强参数）
  Future<PaginatedResponse<MediaItem>> search(
    String query, {
    int limit = 20,
    int offset = 0,
    // 可选过滤器
    List<String>? includeTypes, // 如 ['Movie', 'Series']
    int? minCommunityRating, // 7 表示评分 ≥ 7
    int? minProductionYear, // 2020 表示年份 ≥ 2020
    int? maxProductionYear,
  }) async {
    _requireAuth();

    final params = <String, dynamic>{
      'SearchTerm': query,
      'Recursive': true,
      'IncludeItemTypes': includeTypes?.join(',') ??
          'Movie,Series,Episode,MusicVideo',
      'Fields': 'Overview,Genres,CommunityRating,ProductionYear,'
          'RuntimeTicks,UserData,ImageTags',
      'SortBy': 'DateCreated',
      'SortOrder': 'Descending',
      'StartIndex': offset,
      'Limit': limit,
      if (_userId != null) 'UserId': _userId,
      if (minCommunityRating != null) 'MinCommunityRating': minCommunityRating,
      if (minProductionYear != null) 'MinProductionYear': minProductionYear,
      if (maxProductionYear != null) 'MaxProductionYear': maxProductionYear,
    };

    final resp = await _apiClient.get<dynamic>(
      '/Items',
      queryParameters: params,
    );
    return _parsePaginatedItems(resp.data, offset, limit);
  }

  // 搜索提示：GET /Search/Hints?SearchTerm=...
  Future<List<SearchHint>> getSearchHints(
    String query, {
    int limit = 10,
  }) async {
    _requireAuth();
    final params = <String, dynamic>{
      'SearchTerm': query,
      'IncludeItemTypes': 'Movie,Series,Episode,MusicVideo,Person',
      'Limit': limit,
      if (_userId != null) 'UserId': _userId,
    };
    final resp = await _apiClient.get<dynamic>(
      '/Search/Hints',
      queryParameters: params,
    );
    final data = _asMap(resp.data);
    final rawHints = data['SearchHints'] as List<dynamic>? ??
        data['Items'] as List<dynamic>? ??
        <dynamic>[];

    final base = _embyServerUrl!;
    final key = _apiKey!;
    return rawHints
        .map((e) => SearchHint.fromJson(_asMap(e)).withEmbyUrls(base, key))
        .toList();
  }

  // ========================================================================
  // 收藏
  // ========================================================================

  // 收藏列表：GET /Items?Filters=IsFavorite
  Future<PaginatedResponse<MediaItem>> getFavorites({
    int limit = 100,
    int offset = 0,
  }) async {
    _requireAuth();
    final params = <String, dynamic>{
      'Filters': 'IsFavorite',
      'Recursive': true,
      'IncludeItemTypes': 'Movie,Episode,Video,MusicVideo,Series',
      'Fields': 'Overview,Genres,CommunityRating,ProductionYear,'
          'RuntimeTicks,UserData,ImageTags',
      'SortBy': 'DateCreated',
      'SortOrder': 'Descending',
      'StartIndex': offset,
      'Limit': limit,
      if (_userId != null) 'UserId': _userId,
    };
    final resp = await _apiClient.get<dynamic>(
      '/Items',
      queryParameters: params,
    );
    return _parsePaginatedItems(resp.data, offset, limit);
  }

  // 切换收藏：POST/DELETE /Users/{userId}/FavoriteItems/{itemId}
  Future<void> toggleFavorite(String itemId, {required bool isFavorite}) async {
    _requireAuth();
    final uid = _userId!;
    final path = '/Users/$uid/FavoriteItems/$itemId';
    if (isFavorite) {
      await _apiClient.post<dynamic>(path);
    } else {
      await _apiClient.delete<dynamic>(path);
    }
  }

  // ========================================================================
  // 预告片
  // ========================================================================

  // 预告片：GET /Items?IncludeItemTypes=Trailer
  Future<PaginatedResponse<MediaItem>> getTrailers({
    int limit = 20,
    int offset = 0,
  }) async {
    _requireAuth();
    final params = <String, dynamic>{
      'IncludeItemTypes': 'Trailer',
      'Recursive': true,
      'SortBy': 'DateCreated',
      'SortOrder': 'Descending',
      'Limit': limit,
      'StartIndex': offset,
      'Fields': 'Overview,CommunityRating,ProductionYear,RuntimeTicks,'
          'UserData,ImageTags',
      if (_userId != null) 'UserId': _userId,
    };
    final resp = await _apiClient.get<dynamic>(
      '/Items',
      queryParameters: params,
    );
    return _parsePaginatedItems(resp.data, offset, limit);
  }

  // ========================================================================
  // 标记已看 / 未看
  // ========================================================================

  // 标记已看：POST /Users/{userId}/PlayedItems/{itemId}
  // 若传入 playedTicks，则同时记录播放进度（通常为 total ticks）
  Future<void> markAsPlayed(String itemId, {int? playedTicks}) async {
    _requireAuth();
    final uid = _userId!;
    final path = '/Users/$uid/PlayedItems/$itemId';
    final body = <String, dynamic>{
      if (playedTicks != null) 'PlaybackPositionTicks': playedTicks,
      if (playedTicks != null) 'Played': true,
    };
    await _apiClient.post<dynamic>(path, data: body);
  }

  // 标记未看：DELETE /Users/{userId}/PlayedItems/{itemId}
  Future<void> markAsUnplayed(String itemId) async {
    _requireAuth();
    final uid = _userId!;
    final path = '/Users/$uid/PlayedItems/$itemId';
    await _apiClient.delete<dynamic>(path);
  }

  // ========================================================================
  // 播放信息（音轨/字幕轨）
  // ========================================================================

  // 播放信息：GET /Items/{itemId}/PlaybackInfo?UserId=...
  Future<List<MediaSource>> getPlaybackInfo(String itemId) async {
    _requireAuth();
    final params = <String, dynamic>{
      if (_userId != null) 'UserId': _userId,
    };
    final resp = await _apiClient.get<dynamic>(
      '/Items/$itemId/PlaybackInfo',
      queryParameters: params,
    );
    final data = _asMap(resp.data);
    final list = data['MediaSources'] as List<dynamic>? ?? <dynamic>[];
    final base = _embyServerUrl!;
    final key = _apiKey!;
    return list
        .map((e) => MediaSource.fromJson(_asMap(e)).withEmbyUrls(base, key))
        .toList();
  }

  // ========================================================================
  // 剧集季 / 集
  // ========================================================================

  // 季列表：GET /Shows/{seriesId}/Seasons
  Future<List<MediaItem>> getSeasons(String seriesId) async {
    _requireAuth();
    final params = <String, dynamic>{
      'Fields': 'Overview,CommunityRating,ProductionYear,RuntimeTicks,'
          'UserData,ImageTags,IndexNumber',
      'SortBy': 'IndexNumber',
      'SortOrder': 'Ascending',
      if (_userId != null) 'UserId': _userId,
    };
    final resp = await _apiClient.get<dynamic>(
      '/Shows/$seriesId/Seasons',
      queryParameters: params,
    );
    // Seasons 响应格式：{Items:[...], TotalRecordCount:N}
    return _parseMediaItemList(resp.data);
  }

  // 集列表：GET /Shows/{seriesId}/Episodes
  Future<PaginatedResponse<MediaItem>> getEpisodes(
    String seriesId, {
    String? seasonId,
    int limit = 40,
    int offset = 0,
  }) async {
    _requireAuth();
    final params = <String, dynamic>{
      'Fields': 'Overview,CommunityRating,ProductionYear,RuntimeTicks,'
          'UserData,ImageTags,IndexNumber,ParentIndexNumber,'
          'SeriesName,SeasonName',
      'SortBy': 'ParentIndexNumber,IndexNumber',
      'SortOrder': 'Ascending',
      'Limit': limit,
      'StartIndex': offset,
      if (seasonId != null) 'SeasonId': seasonId,
      if (_userId != null) 'UserId': _userId,
    };
    final resp = await _apiClient.get<dynamic>(
      '/Shows/$seriesId/Episodes',
      queryParameters: params,
    );
    return _parsePaginatedItems(resp.data, offset, limit);
  }

  // ========================================================================
  // 播放进度上报（增强）
  // ========================================================================

  // 上报播放进度：POST /Users/{userId}/PlayingItems/{itemId}/Progress
  // 新增支持：MediaSourceId 和 PlaySessionId
  Future<void> reportPlaybackProgress({
    required String itemId,
    required int positionTicks,
    bool isPaused = false,
    String? mediaSourceId,
    String? playSessionId,
  }) async {
    _requireAuth();
    final uid = _userId!;
    final params = <String, dynamic>{
      'ItemId': itemId,
      'PositionTicks': positionTicks,
      'IsPaused': isPaused,
      'UserId': uid,
      'PlayMethod': 'DirectStream',
      if (mediaSourceId != null) 'MediaSourceId': mediaSourceId,
      if (playSessionId != null) 'PlaySessionId': playSessionId,
    };
    await _apiClient.post<dynamic>(
      '/Users/$uid/PlayingItems/$itemId/Progress',
      queryParameters: params,
    );
  }

  // 上报播放停止：POST /Users/{userId}/PlayingItems/{itemId}/Stopped
  Future<void> reportPlaybackStopped({
    required String itemId,
    required int positionTicks,
    String? mediaSourceId,
    String? playSessionId,
  }) async {
    _requireAuth();
    final uid = _userId!;
    final params = <String, dynamic>{
      'ItemId': itemId,
      'PositionTicks': positionTicks,
      'UserId': uid,
      if (mediaSourceId != null) 'MediaSourceId': mediaSourceId,
      if (playSessionId != null) 'PlaySessionId': playSessionId,
    };
    await _apiClient.post<dynamic>(
      '/Users/$uid/PlayingItems/$itemId/Stopped',
      queryParameters: params,
    );
  }

  // ========================================================================
  // 用户头像 URL 构造
  // ========================================================================

  // 用户头像：/Users/{userId}/Images/Primary?MaxWidth=200&api_key=...
  String? getUserAvatarUrl({String? userId, int maxWidth = 200}) {
    final uid = userId ?? _userId;
    if (_embyServerUrl == null || uid == null) return null;
    final key = _apiKey;
    return '$_embyServerUrl/Users/$uid/Images/Primary?'
        'MaxWidth=$maxWidth&api_key=$key';
  }

  // ========================================================================
  // 内部辅助方法
  // ========================================================================

  void _requireAuth() {
    if (_apiKey == null || _embyServerUrl == null || _userId == null) {
      throw '尚未登录，请先登录';
    }
  }

  _SortInfo _selectSortStrategy(String? libraryType) {
    switch (libraryType?.toLowerCase()) {
      case 'movies':
      case 'homevideos':
        return _SortInfo(
          sortBy: 'PremiereDate,ProductionYear,SortName',
          sortOrder: 'Descending',
        );
      case 'tvshows':
        return _SortInfo(sortBy: 'DateCreated', sortOrder: 'Descending');
      case 'music':
        return _SortInfo(
          sortBy: 'ProductionYear,Album,SortName',
          sortOrder: 'Descending',
        );
      default:
        return _SortInfo(sortBy: 'DateCreated', sortOrder: 'Descending');
    }
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String) {
      try {
        final decoded = jsonDecode(data) as dynamic;
        return _asMap(decoded);
      } catch (_) {}
    }
    return <String, dynamic>{};
  }

  List<dynamic> _asList(dynamic data) {
    if (data is List<dynamic>) return data;
    if (data is List) return data;
    if (data is String) {
      try {
        final decoded = jsonDecode(data) as dynamic;
        if (decoded is List) return decoded;
      } catch (_) {}
    }
    return <dynamic>[];
  }

  // 解析 {Items:[...], TotalRecordCount:N} 格式为 PaginatedResponse<MediaItem>
  PaginatedResponse<MediaItem> _parsePaginatedItems(
    dynamic data,
    int offset,
    int limit,
  ) {
    final map = _asMap(data);
    final items = _parseMediaItemList(data);
    final total = map['TotalRecordCount'] as int? ?? items.length;
    return PaginatedResponse<MediaItem>(
      items: items,
      total: total,
      offset: offset,
      limit: limit,
    );
  }

  // 从响应中解析 MediaItem 列表，并注入 Emby URL
  List<MediaItem> _parseMediaItemList(dynamic data) {
    final rawItems =
        (data is List<dynamic>) ? data : _asList(_asMap(data)['Items']);
    final base = _embyServerUrl!;
    final key = _apiKey!;
    return rawItems
        .map((e) => MediaItem.fromJson(_asMap(e)).withEmbyUrls(base, key))
        .toList();
  }

  // 生成稳定的播放会话 ID（用于上报进度时使用）
  String generatePlaySessionId() {
    final rand = math.Random.secure();
    String hex(int len) {
      final sb = StringBuffer();
      for (int i = 0; i < len; i++) {
        sb.write(rand.nextInt(16).toRadixString(16));
      }
      return sb.toString();
    }
    return 'tok${hex(8)}${hex(4)}${hex(4)}${hex(12)}';
  }
}

class _SortInfo {
  final String sortBy;
  final String sortOrder;
  _SortInfo({required this.sortBy, required this.sortOrder});
}
