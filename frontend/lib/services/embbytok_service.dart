// EmbytokService：直接与 Emby 服务器通信
// 不再需要 FastAPI 中间层

import 'dart:convert';

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

  // ——— 设置鉴权信息 ———
  // 在所有查询类 API 调用前必须调用一次
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

  // ——— 登录：POST /Users/AuthenticateByName ———
  // 返回 { User: {...}, AccessToken: "...", ... }
  Future<Map<String, dynamic>> login({
    required String embyServerUrl,
    required String username,
    required String password,
  }) async {
    // 临时设置 baseUrl 进行登录（登录后通过 AccessToken 鉴权）
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

    // 保存返回的 AccessToken，后续请求全部通过此 token 鉴权
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

  // ——— 获取媒体库列表：GET /Library/VirtualFolders ———
  // 返回 [{ Id, Name, CollectionType, ... }, ...]
  Future<List<Library>> getLibraries() async {
    _requireAuth();
    final resp = await _apiClient.get<dynamic>('/Library/VirtualFolders');
    final list = _asList(resp.data);
    return list.map((e) => Library.fromJson(_asMap(e))).toList();
  }

  // ——— 获取某媒体库下的视频：GET /Items ———
  // 查询参数：ParentId, Recursive=true, IncludeItemTypes=...
  Future<PaginatedResponse<MediaItem>> getItems({
    String? libraryId,
    int limit = 20,
    int offset = 0,
  }) async {
    _requireAuth();

    final params = <String, dynamic>{
      'Recursive': true,
      'IncludeItemTypes': 'Movie,Episode,Video,MusicVideo',
      'Fields': 'Overview,Genres,CommunityRating,ProductionYear,'
          'RuntimeTicks,UserData',
      'SortBy': 'DateCreated',
      'SortOrder': 'Descending',
      'StartIndex': offset,
      'Limit': limit,
      if (_userId != null) 'UserId': _userId,
    };
    if (libraryId != null && libraryId.isNotEmpty) {
      params['ParentId'] = libraryId;
    }

    final resp = await _apiClient.get<dynamic>('/Items', queryParameters: params);
    final data = _asMap(resp.data);

    final items = _parseItemsList(data);
    final total = data['TotalRecordCount'] as int? ?? items.length;

    return PaginatedResponse<MediaItem>(
      items: items,
      total: total,
      offset: offset,
      limit: limit,
    );
  }

  // ——— 搜索：GET /Items?SearchTerm=... ———
  Future<PaginatedResponse<MediaItem>> search(
    String query, {
    int limit = 20,
    int offset = 0,
  }) async {
    _requireAuth();

    final params = <String, dynamic>{
      'SearchTerm': query,
      'Recursive': true,
      'IncludeItemTypes': 'Movie,Episode,Video,MusicVideo,Series',
      'Fields': 'Overview,Genres,CommunityRating,ProductionYear,'
          'RuntimeTicks,UserData',
      'StartIndex': offset,
      'Limit': limit,
      if (_userId != null) 'UserId': _userId,
    };

    final resp = await _apiClient.get<dynamic>('/Items', queryParameters: params);
    final data = _asMap(resp.data);

    final items = _parseItemsList(data);
    final total = data['TotalRecordCount'] as int? ?? items.length;

    return PaginatedResponse<MediaItem>(
      items: items,
      total: total,
      offset: offset,
      limit: limit,
    );
  }

  // ——— 获取收藏列表：GET /Items?Filters=IsFavorite ———
  Future<PaginatedResponse<MediaItem>> getFavorites({
    int limit = 100,
    int offset = 0,
  }) async {
    _requireAuth();

    final params = <String, dynamic>{
      'Filters': 'IsFavorite',
      'Recursive': true,
      'IncludeItemTypes': 'Movie,Episode,Video,MusicVideo',
      'Fields': 'Overview,Genres,CommunityRating,ProductionYear,'
          'RuntimeTicks,UserData',
      'StartIndex': offset,
      'Limit': limit,
      if (_userId != null) 'UserId': _userId,
    };

    final resp = await _apiClient.get<dynamic>('/Items', queryParameters: params);
    final data = _asMap(resp.data);

    final items = _parseItemsList(data);
    final total = data['TotalRecordCount'] as int? ?? items.length;

    return PaginatedResponse<MediaItem>(
      items: items,
      total: total,
      offset: offset,
      limit: limit,
    );
  }

  // ——— 添加/移除收藏：POST /Users/{userId}/FavoriteItems/{itemId}
  //     或 DELETE /Users/{userId}/FavoriteItems/{itemId} ———
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

  // ——— 内部工具方法 ———

  // 确保已登录
  void _requireAuth() {
    if (_apiKey == null || _embyServerUrl == null || _userId == null) {
      throw '尚未登录，请先登录';
    }
  }

  // 将 dynamic 视为 Map<String, dynamic>
  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    if (data is String) {
      try {
        final decoded = jsonDecode(data) as dynamic;
        return _asMap(decoded);
      } catch (_) {}
    }
    return <String, dynamic>{};
  }

  // 将 dynamic 视为 List
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

  // 解析 Emby /Items 响应，并为每条记录生成缩略图与播放地址
  List<MediaItem> _parseItemsList(Map<String, dynamic> data) {
    final rawItems = data['Items'] as List<dynamic>? ?? <dynamic>[];
    final base = _embyServerUrl!;
    final key = _apiKey!;
    return rawItems
        .map((e) => MediaItem.fromJson(_asMap(e))
            .withEmbyUrls(base, key)) // 注入完整 URL
        .toList();
  }
}
