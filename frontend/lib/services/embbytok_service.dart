// EmbytokService：直接与 Emby 服务器通信
// 不再需要 FastAPI 中间层
//
// 核心 API 映射：
//   登录      → POST /Users/AuthenticateByName
//   媒体库列表 → GET  /Library/VirtualFolders
//   视频列表   → GET  /Items?ParentId=...&Recursive=true
//   搜索      → GET  /Items?SearchTerm=...
//   收藏列表   → GET  /Items?Filters=IsFavorite
//   切换收藏   → POST/DELETE /Users/{userId}/FavoriteItems/{itemId}

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
    _apiClient.setUserId(userId); // 设置 UserId 以包含在 X-Emby-Authorization 中
  }

  // ——— 登录：POST /Users/AuthenticateByName ———
  // 正文：{ "Username": "...", "Pw": "..." }
  // 返回（关键字段）：
  //   {
  //     "User": { "Id": "...", "Name": "...", ... },
  //     "AccessToken": "...",
  //     "ServerId": "..."
  //   }
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

  // ——— 服务器可达性验证：GET /System/Info/Public ———
  // 用于登录前验证服务器地址是否正确
  // 返回：{ "ServerName": "...", "Version": "...", ... }
  Future<Map<String, dynamic>> pingServer(String embyServerUrl) async {
    final base = embyServerUrl.endsWith('/')
        ? embyServerUrl.substring(0, embyServerUrl.length - 1)
        : embyServerUrl;
    _apiClient.setBaseUrl(base);
    final resp = await _apiClient.get<dynamic>('/System/Info/Public');
    return _asMap(resp.data);
  }

  // ——— 获取媒体库列表：GET /Library/VirtualFolders ———
  // 返回：[{ "Id": "...", "Name": "...", "CollectionType": "movies" | ... }, ...]
  Future<List<Library>> getLibraries() async {
    _requireAuth();
    final resp = await _apiClient.get<dynamic>('/Library/VirtualFolders');
    final list = _asList(resp.data);
    final libraries = list.map((e) => Library.fromJson(_asMap(e))).toList();
    // 过滤：只保留有用的媒体库类型
    // Emby CollectionType: "movies", "tvshows", "music", "homevideos",
    //                      "books", "boxsets", "mixed" 等
    // 我们关注的是有视频内容的类型
    const usefulTypes = <String>{
      'movies',
      'tvshows',
      'homevideos',
      'mixed',
      'boxsets',
      '', // 某些版本返回空字符串表示 "混合内容"
    };
    return libraries.where((lib) {
      final type = lib.type.toLowerCase();
      // 如果 CollectionType 为空，也视为有用（某些 Emby 配置）
      return usefulTypes.contains(type) ||
          usefulTypes.contains(lib.collectionType?.toLowerCase() ?? '');
    }).toList();
  }

  // ——— 获取某媒体库下的视频：GET /Items ———
  // 根据媒体库类型选择合适的排序方式：
  //   movies/homevideos → 按首映日期降序
  //   tvshows           → 按创建日期降序
  //   mixed/其他        → 按添加日期降序
  Future<PaginatedResponse<MediaItem>> getItems({
    String? libraryId,
    String? libraryType,
    int limit = 20,
    int offset = 0,
  }) async {
    _requireAuth();

    // 智能选择 SortBy + SortOrder
    final sortInfo = _selectSortStrategy(libraryType);

    final params = <String, dynamic>{
      'Recursive': true,
      'IncludeItemTypes': 'Movie,Episode,Video,MusicVideo',
      'Fields': 'Overview,Genres,CommunityRating,ProductionYear,'
          'RuntimeTicks,UserData,DateCreated,PremiereDate',
      'SortBy': sortInfo.sortBy,
      'SortOrder': sortInfo.sortOrder,
      'StartIndex': offset,
      'Limit': limit,
      if (_userId != null) 'UserId': _userId,
    };
    if (libraryId != null && libraryId.isNotEmpty) {
      params['ParentId'] = libraryId;
    }

    final resp = await _apiClient.get<dynamic>(
      '/Items',
      queryParameters: params,
    );
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

    final resp = await _apiClient.get<dynamic>(
      '/Items',
      queryParameters: params,
    );
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

  // ——— 报告播放进度（可选调用）———
  Future<void> reportPlaybackProgress({
    required String itemId,
    required int positionTicks,
    bool isPaused = false,
  }) async {
    _requireAuth();
    final uid = _userId!;
    final params = <String, dynamic>{
      'ItemId': itemId,
      'PositionTicks': positionTicks,
      'IsPaused': isPaused,
      'UserId': uid,
      'PlayMethod': 'DirectStream',
    };
    await _apiClient.post<dynamic>(
      '/Users/$uid/PlayingItems/$itemId/Progress',
      queryParameters: params,
    );
  }

  // ——— 报告播放停止 ———
  Future<void> reportPlaybackStopped({
    required String itemId,
    required int positionTicks,
  }) async {
    _requireAuth();
    final uid = _userId!;
    final params = <String, dynamic>{
      'ItemId': itemId,
      'PositionTicks': positionTicks,
      'UserId': uid,
    };
    await _apiClient.post<dynamic>(
      '/Users/$uid/PlayingItems/$itemId/Stopped',
      queryParameters: params,
    );
  }

  // ——— 内部工具方法 ———

  // 确保已登录
  void _requireAuth() {
    if (_apiKey == null || _embyServerUrl == null || _userId == null) {
      throw '尚未登录，请先登录';
    }
  }

  // 根据媒体库类型选择排序策略
  _SortInfo _selectSortStrategy(String? libraryType) {
    switch (libraryType?.toLowerCase()) {
      case 'movies':
      case 'homevideos':
        // 电影：按首映日期优先，其次是制作年份
        return _SortInfo(
          sortBy: 'PremiereDate,ProductionYear,SortName',
          sortOrder: 'Descending',
        );
      case 'tvshows':
        // 剧集：按创建时间（最新添加的在前）
        return _SortInfo(
          sortBy: 'DateCreated',
          sortOrder: 'Descending',
        );
      case 'music':
        // 音乐：按专辑名排序（此客户端以视频为主，音乐作为次要）
        return _SortInfo(
          sortBy: 'ProductionYear,Album,SortName',
          sortOrder: 'Descending',
        );
      default:
        // mixed / 其他：按添加时间降序
        return _SortInfo(
          sortBy: 'DateCreated',
          sortOrder: 'Descending',
        );
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
            .withEmbyUrls(base, key)) // 注入完整 URL + 认证头
        .toList();
  }
}

// 排序策略的内部数据结构
class _SortInfo {
  final String sortBy;
  final String sortOrder;
  _SortInfo({required this.sortBy, required this.sortOrder});
}
