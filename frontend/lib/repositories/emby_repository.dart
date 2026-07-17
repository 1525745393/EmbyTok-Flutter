// Emby 媒体仓库实现：基于 EmbytokService 实现 MediaRepository 接口
//
// 设计原则：
// - 薄封装层：将 MediaQueryParams 转换为 EmbytokService 方法调用
// - 不包含业务逻辑（去重、分页合并等在上层处理）
// - 便于未来替换为 Plex/Jellyfin 等其他实现

import '../models/models.dart';
import '../services/embbytok_service.dart';
import 'media_repository.dart';

/// Emby 媒体仓库实现
///
/// 将 EmbytokService 封装为标准的 MediaRepository 接口。
/// 上层业务（VideoListNotifier 等）只依赖 MediaRepository 接口，
/// 未来切换数据源时只需替换实现类。
class EmbyRepository implements MediaRepository {
  final EmbytokService _service;

  EmbyRepository({EmbytokService? service})
      : _service = service ?? EmbytokService();

  @override
  Future<PaginatedResponse<MediaItem>> getLibraryItems(
    MediaQueryParams params, {
    required String serverUrl,
    required String token,
    String? userId,
  }) {
    return _service.getLibraryItems(
      params.libraryId,
      limit: params.limit,
      offset: params.offset,
      serverUrl: serverUrl,
      token: token,
      userId: userId,
      // null 时回退到 EmbytokService 的默认排序（与 service 签名默认值保持一致）
      sortBy: params.sortBy ?? 'DateCreated,SortName',
      sortOrder: params.sortOrder ?? 'Descending',
      searchTerm: params.searchTerm,
      excludePlayed: params.excludePlayed,
    );
  }

  @override
  Future<FavoritesPageResult> getFavoriteMovies({
    required String serverUrl,
    required String token,
    String? userId,
  }) {
    return _service.getFavoriteMovies(
      serverUrl: serverUrl,
      token: token,
      userId: userId,
    );
  }

  @override
  Future<PaginatedResponse<MediaItem>> getResumeItems({
    required String serverUrl,
    required String token,
    int limit = 50,
    int offset = 0,
  }) {
    return _service.getResumeItems(
      limit: limit,
      offset: offset,
      serverUrl: serverUrl,
      token: token,
    );
  }
}
