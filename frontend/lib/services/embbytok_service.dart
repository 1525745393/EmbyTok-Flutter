// 核心业务服务：封装与后端 FastAPI 的交互，对应 /api/* 路由

import '../models/models.dart';
import 'api_client.dart';

class EmbytokService {
  final ApiClient _apiClient;

  EmbytokService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  // 一次性设置所有认证信息（baseUrl + embyServerUrl + userId + token）
  // 每个 provider 创建的独立 service 都需要调用此方法
  void setupAuth({
    required String backendUrl,
    required String embyServerUrl,
    required String userId,
    required String token,
  }) {
    _apiClient.setBaseUrl(backendUrl);
    _apiClient.setEmbyServerUrl(embyServerUrl);
    _apiClient.setUserId(userId);
    _apiClient.setToken(token);
  }

  // 登录：调用后端 /api/auth/login，返回 User
  // 注意：登录时设置 baseUrl 为 FastAPI 后端地址，同时注入 Emby 服务器地址和用户 ID
  Future<User> login(
    String embyUrl,
    String backendUrl,
    String username,
    String password,
  ) async {
    // 关键：baseUrl 始终是 FastAPI 后端地址（如 http://192.168.1.100:8000）
    // 绝不能设置为 Emby 服务器地址！
    _apiClient.setBaseUrl(backendUrl);

    final response = await _apiClient.post<Map<String, dynamic>>(
      '/api/auth/login',
      data: {
        'emby_url': embyUrl,
        'username': username,
        'password': password,
      },
    );
    final data = response.data as Map<String, dynamic>;
    final user = User.fromJson(data);

    // 登录后：一次性设置 Token、Emby 服务器地址、用户 ID
    // 后续所有请求都会通过拦截器自动注入这些头
    _apiClient.setToken(user.accessToken);
    _apiClient.setEmbyServerUrl(embyUrl);
    _apiClient.setUserId(user.id);

    return user;
  }

  // 获取媒体库列表：对应 /api/libraries
  Future<List<Library>> getLibraries() async {
    final response = await _apiClient.get<List<dynamic>>(
      '/api/libraries',
    );
    final items = response.data as List<dynamic>;
    return items
        .map((e) => Library.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // 获取媒体库下的条目列表（分页）
  Future<PaginatedResponse<MediaItem>> getLibraryItems(
    String libraryId, {
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/libraries/$libraryId/items',
      queryParameters: <String, dynamic>{
        'limit': limit,
        'offset': offset,
      },
    );
    return PaginatedResponse<MediaItem>.fromJson(
      response.data as Map<String, dynamic>,
      (e) => MediaItem.fromJson(e as Map<String, dynamic>),
    );
  }

  // 获取单个媒体项详情
  Future<MediaItem> getItem(String itemId) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/items/$itemId',
    );
    return MediaItem.fromJson(response.data as Map<String, dynamic>);
  }

  // 获取播放 URL
  Future<String> getPlaybackUrl(String itemId) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/items/$itemId/playback',
    );
    final data = response.data as Map<String, dynamic>;
    return (data['playback_url'] as String?) ?? '';
  }

  // 搜索：对应 /api/search
  Future<PaginatedResponse<MediaItem>> search(
    String query, {
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/search',
      queryParameters: <String, dynamic>{
        'q': query,
        'limit': limit,
        'offset': offset,
      },
    );
    return PaginatedResponse<MediaItem>.fromJson(
      response.data as Map<String, dynamic>,
      (e) => MediaItem.fromJson(e as Map<String, dynamic>),
    );
  }

  // 切换收藏：POST /api/favorites/{itemId}，isFavorite 为 true 表示添加
  Future<void> toggleFavorite(
    String itemId,
    bool isFavorite,
  ) async {
    if (isFavorite) {
      await _apiClient.post<void>('/api/favorites/$itemId');
    } else {
      await _apiClient.delete<void>('/api/favorites/$itemId');
    }
  }

  // 获取收藏列表
  Future<List<MediaItem>> getFavorites() async {
    final response = await _apiClient.get<List<dynamic>>(
      '/api/favorites',
    );
    final items = response.data as List<dynamic>;
    return items
        .map((e) => MediaItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // 保存播放进度
  Future<void> saveProgress(
    String itemId,
    int positionSeconds,
  ) async {
    await _apiClient.post<void>(
      '/api/progress/$itemId',
      data: <String, dynamic>{'position_seconds': positionSeconds},
    );
  }

  // 获取播放进度（秒）
  Future<int?> getProgress(String itemId) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/progress/$itemId',
    );
    final data = response.data as Map<String, dynamic>;
    return data['position_seconds'] as int?;
  }
}
