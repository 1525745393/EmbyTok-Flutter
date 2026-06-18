// 核心业务服务：直接调用 Emby 原生 API（不再经过后端）
// 设计思路：每个方法都接受可选的 serverUrl / token 参数，调用方可以显式传入，
// 也可以先调用 setupAuth 后使用无参方法。这样既有灵活性又便于 Provider 使用。

import '../models/models.dart';
import 'api_client.dart';

class EmbytokService {
  final ApiClient _apiClient;
  String? _defaultServerUrl;
  String? _defaultToken;
  String? _defaultUserId;
  String? _defaultDeviceId;

  EmbytokService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

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

  // 设置设备ID
  void setDeviceId(String deviceId) {
    _defaultDeviceId = deviceId;
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
    final accessToken = (data['AccessToken'] as String?) ?? '';

    final user = User(
      id: (userInfo['Id'] as String?) ?? '',
      name: (userInfo['Name'] as String?) ?? username,
      accessToken: accessToken,
    );

    // 保存配置方便后续直接调用
    _defaultServerUrl = embyServerUrl;
    _defaultToken = accessToken;
    _defaultUserId = user.id;
    _apiClient.setToken(accessToken);

    return user;
  }

  // ============================
  // 媒体库列表：/Users/{userId}/Views
  // ============================
  Future<List<Library>> getLibraries({
    String? serverUrl,
    String? token,
  }) async {
    _ensureConfig(serverUrl, token);
    final userId = _defaultUserId;
    if (userId == null) throw '需要用户ID';

    final resp = await _apiClient.get<dynamic>(
      '/Users/$userId/Views',
      queryParameters: {},
    );

    final items = resp.data is List
        ? resp.data as List<dynamic>
        : (resp.data['Items'] as List<dynamic>?) ?? [];

    return items
        .whereType<Map<String, dynamic>>()
        .map((e) => Library(
              id: (e['Id'] as String?) ?? '',
              name: (e['Name'] as String?) ?? '',
              type: (e['CollectionType'] as String?) ?? 'movies',
            ))
        .toList();
  }

  // ============================
  // 获取某媒体库下的视频列表
  // ============================
  Future<PaginatedResponse<MediaItem>> getLibraryItems(
    String libraryId, {
    int limit = 20,
    int offset = 0,
    String? serverUrl,
    String? token,
  }) async {
    _ensureConfig(serverUrl, token);
    final params = <String, dynamic>{
      'ParentId': libraryId,
      'Limit': '$limit',
      'StartIndex': '$offset',
      'SortBy': 'DateCreated,SortName',
      'SortOrder': 'Descending',
      'Recursive': 'true',
      'Fields':
          'Overview,Genres,People,CommunityRating,RunTimeTicks,ProductionYear,ImageTags,UserData',
      'IncludeItemTypes': 'Movie,Series,MusicVideo,Episode',
    };

    final resp = await _apiClient.get<dynamic>(
      '/Items',
      queryParameters: params,
    );
    return _parsePaginatedResponse(resp.data, offset: offset, limit: limit);
  }

  // ============================
  // 获取项详情
  // ============================
  Future<MediaItem> getItemDetail(
    String itemId, {
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
    final resp = await _apiClient.get<dynamic>(
      '/Items/$itemId',
      queryParameters: params,
    );
    final data = resp.data is Map<String, dynamic> ? resp.data as Map<String, dynamic> : <String, dynamic>{};
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
          'Overview,Genres,CommunityRating,RunTimeTicks,ProductionYear,ImageTags,UserData',
    };
    final resp = await _apiClient.get<dynamic>(
      '/Items/Resume',
      queryParameters: params,
    );
    return _parsePaginatedResponse(resp.data, offset: offset, limit: limit);
  }

  // ============================
  // Next Up（下一步看什么）—— 剧集的下一集
  // ============================
  Future<PaginatedResponse<MediaItem>> getNextUp({
    int limit = 20,
    String? serverUrl,
    String? token,
  }) async {
    _ensureConfig(serverUrl, token);
    final params = <String, dynamic>{
      'Limit': '$limit',
      'Fields':
          'Overview,CommunityRating,RunTimeTicks,ProductionYear,ImageTags,UserData,SeriesName,ParentIndexNumber,IndexNumber',
    };
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
      'IncludeItemTypes': 'Movie,Series,MusicVideo',
    };
    final resp = await _apiClient.get<dynamic>(
      '/Items/Latest',
      queryParameters: params,
    );

    // Latest 接口有些返回 flat array 而不是 { Items, TotalRecordCount }
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
  Future<List<Person>> getPeople({
    int limit = 50,
    List<String>? personTypes,
    String? serverUrl,
    String? token,
  }) async {
    _ensureConfig(serverUrl, token);
    final params = <String, dynamic>{
      'Limit': '$limit',
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
    final baseUrl = _defaultServerUrl ?? serverUrl ?? '';
    return items
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
                '${_defaultToken != null ? '&api_key=$_defaultToken' : ''}';
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
          'Overview,Genres,CommunityRating,RunTimeTicks,ProductionYear,ImageTags,UserData',
    };
    final resp = await _apiClient.get<dynamic>(
      '/Items',
      queryParameters: params,
    );
    return _parsePaginatedResponse(resp.data, offset: offset, limit: limit);
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
  // 收藏影片
  // ============================
  Future<List<MediaItem>> getFavoriteMovies({
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
      'IncludeItemTypes': 'Movie,Series,MusicVideo,Episode',
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
  // 收藏合集（BoxSet）
  // ============================
  Future<List<MediaItem>> getFavoriteBoxSets({
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
      'IncludeItemTypes': 'BoxSet',
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
  // 收藏人物
  // ============================
  Future<List<MediaItem>> getFavoritePeople({
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
      'Fields': 'Overview,PrimaryImageTag',
      'IncludeItemTypes': 'Person',
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
  // 切换收藏状态
  // ============================
  Future<void> toggleFavorite(
    String itemId, {
    required bool isFavorite,
    String? serverUrl,
    String? token,
  }) async {
    _ensureConfig(serverUrl, token);
    if (isFavorite) {
      await _apiClient.post<dynamic>('/UserFavoriteItems/$itemId');
    } else {
      await _apiClient.delete<dynamic>('/UserFavoriteItems/$itemId');
    }
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
  // 上报播放进度 / 停止位置
  // ============================
  Future<void> reportPlaybackPosition({
    required String itemId,
    required int positionTicks,
    String? mediaSourceId,
    String? playSessionId,
    String? serverUrl,
    String? token,
  }) async {
    _ensureConfig(serverUrl, token);
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
    String? serverUrl,
    String? token,
  }) async {
    _ensureConfig(serverUrl, token);
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
  // 上报客户端播放能力，提升 Direct Play 兼容性
  // ============================
  Future<void> reportCapabilities({
    String? serverUrl,
    String? token,
  }) async {
    _ensureConfig(serverUrl, token);
    await _apiClient.post<dynamic>(
      '/Sessions/Capabilities/Full',
      data: {
        'PlayableMediaTypes': ['Video', 'Audio'],
        'SupportedCommands': [
          'Play',
          'Pause',
          'Seek',
          'SetVolume',
          'Mute',
          'Unmute',
          'ToggleMute',
          'SetAudioStreamIndex',
          'SetSubtitleStreamIndex',
          'SetMaxStreamingBitrate',
          'DisplayContent',
          'SetRepeatMode'
        ],
        'SupportsMediaControl': true,
      },
    );
  }

  // ============================
  // 构建视频流 URL（支持 Direct Play）
  // ============================
  String buildStreamUrl(
    String itemId, {
    String? serverUrl,
    String? token,
    String? deviceId,
    String? mediaSourceId,
  }) {
    final server = serverUrl ?? _defaultServerUrl;
    final tk = token ?? _defaultToken;
    final device = deviceId ?? 'EmbyTok-Flutter';

    if (server == null || server.isEmpty || tk == null || tk.isEmpty) {
      throw '请先登录或提供服务器地址和令牌';
    }

    final params = <String, String>{
      'api_key': tk,
      'DeviceId': device,
      // 支持主流编码格式
      'VideoCodec': 'h264,hevc,av1',
      'AudioCodec': 'aac,mp3,ac3,eac3,flac',
      // 允许直接复制流，避免不必要的转码
      'AllowVideoStreamCopy': 'true',
      'AllowAudioStreamCopy': 'true',
      // 传输比特率限制（0 表示不限制）
      'MaxStreamingBitrate': '0',
    };

    if (mediaSourceId != null && mediaSourceId.isNotEmpty) {
      params['MediaSourceId'] = mediaSourceId;
    }

    // 优先使用直接流（.mp4），不支持时回退到 HLS
    return '$server/emby/Videos/$itemId/stream.mp4?${Uri(queryParameters: params).query}';
  }

  // ============================
  // 构建 HLS 流 URL（备选）
  // ============================
  String buildHlsStreamUrl(
    String itemId, {
    String? serverUrl,
    String? token,
    String? deviceId,
  }) {
    final server = serverUrl ?? _defaultServerUrl;
    final tk = token ?? _defaultToken;
    final device = deviceId ?? 'EmbyTok-Flutter';

    if (server == null || server.isEmpty || tk == null || tk.isEmpty) {
      throw '请先登录或提供服务器地址和令牌';
    }

    final params = <String, String>{
      'api_key': tk,
      'DeviceId': device,
      'VideoCodec': 'h264,hevc,av1',
      'AudioCodec': 'aac,mp3,ac3,eac3',
      'AllowVideoStreamCopy': 'true',
      'AllowAudioStreamCopy': 'true',
    };

    return '$server/emby/Videos/$itemId/master.m3u8?${Uri(queryParameters: params).query}';
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
  // 通用搜索（获取完整 MediaItem 对象）
  // ============================
  Future<PaginatedResponse<MediaItem>> searchItems(
    String query, {
    int limit = 30,
    int offset = 0,
    List<String>? includeTypes,
    String? serverUrl,
    String? token,
  }) async {
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
      if (includeTypes != null) 'IncludeItemTypes': includeTypes.join(','),
    };
    final resp = await _apiClient.get<dynamic>(
      '/Items',
      queryParameters: params,
    );
    return _parsePaginatedResponse(resp.data, offset: offset, limit: limit);
  }

  // ============================
  // 内部辅助方法
  // ============================

  // 确保 API client 已配置 serverUrl 和 token
  void _ensureConfig(String? serverUrl, String? token) {
    final url = serverUrl ?? _defaultServerUrl;
    final tk = token ?? _defaultToken;
    if (url == null || url.isEmpty) {
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
      return PaginatedResponse(
        items: const [],
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
