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
  Future<MediaItem> getItemDetail(
    String itemId, {
    required String serverUrl,
    required String token,
    String? userId,
  }) {
    return _service.getItemDetail(
      itemId,
      userId: userId,
      serverUrl: serverUrl,
      token: token,
    );
  }

  @override
  Future<FavoritesPageResult> getFavoriteMovies({
    int limit = 50,
    int offset = 0,
    required String serverUrl,
    required String token,
    String? userId,
  }) {
    return _service.getFavoriteMovies(
      limit: limit,
      offset: offset,
      serverUrl: serverUrl,
      token: token,
      userId: userId,
    );
  }

  @override
  Future<FavoritesPageResult> getFavoriteBoxSets({
    int limit = 50,
    int offset = 0,
    required String serverUrl,
    required String token,
    String? userId,
  }) {
    return _service.getFavoriteBoxSets(
      limit: limit,
      offset: offset,
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

  @override
  Future<List<Library>> getLibraries({
    required String serverUrl,
    required String token,
    String? userId,
  }) {
    return _service.getLibraries(
      userId: userId,
      serverUrl: serverUrl,
      token: token,
    );
  }

  @override
  Future<PaginatedResponse<MediaItem>> getNextUp({
    required String serverUrl,
    required String token,
    int limit = 20,
    String? seriesId,
  }) {
    return _service.getNextUp(
      limit: limit,
      seriesId: seriesId,
      serverUrl: serverUrl,
      token: token,
    );
  }

  @override
  Future<List<MediaItem>> getSeasons(
    String seriesId, {
    required String serverUrl,
    required String token,
  }) {
    return _service.getSeasons(
      seriesId,
      serverUrl: serverUrl,
      token: token,
    );
  }

  @override
  Future<PaginatedResponse<MediaItem>> getEpisodes(
    String seriesId, {
    String? seasonId,
    int limit = 100,
    int offset = 0,
    required String serverUrl,
    required String token,
  }) {
    return _service.getEpisodes(
      seriesId,
      seasonId: seasonId,
      limit: limit,
      offset: offset,
      serverUrl: serverUrl,
      token: token,
    );
  }

  @override
  Future<List<MediaItem>> getSimilarItems(
    String itemId, {
    int limit = 12,
    required String serverUrl,
    required String token,
  }) {
    return _service.getSimilarItems(
      itemId,
      limit: limit,
      serverUrl: serverUrl,
      token: token,
    );
  }

  @override
  Future<PaginatedResponse<Person>> getPeople({
    int limit = 50,
    int startIndex = 0,
    List<String>? personTypes,
    String? searchTerm,
    required String serverUrl,
    required String token,
  }) {
    return _service.getPeople(
      limit: limit,
      startIndex: startIndex,
      personTypes: personTypes,
      searchTerm: searchTerm,
      serverUrl: serverUrl,
      token: token,
    );
  }

  @override
  Future<MediaItem?> getPersonDetail(
    String personId, {
    required String serverUrl,
    required String token,
    String? userId,
  }) {
    return _service.getPersonDetail(
      personId,
      serverUrl: serverUrl,
      token: token,
      userId: userId,
    );
  }

  @override
  Future<PaginatedResponse<MediaItem>> getPersonItems(
    String personId, {
    int limit = 30,
    int offset = 0,
    required String serverUrl,
    required String token,
  }) {
    return _service.getPersonItems(
      personId,
      limit: limit,
      offset: offset,
      serverUrl: serverUrl,
      token: token,
    );
  }

  @override
  Future<FavoritesPageResult> getFavoritePeople({
    int limit = 50,
    int offset = 0,
    required String serverUrl,
    required String token,
    String? userId,
  }) {
    return _service.getFavoritePeople(
      limit: limit,
      offset: offset,
      serverUrl: serverUrl,
      token: token,
      userId: userId,
    );
  }

  @override
  Future<PaginatedResponse<MediaItem>> getRecommendations({
    int limit = 20,
    int offset = 0,
    String? libraryId,
    String? userId,
    required String serverUrl,
    required String token,
    double minCommunityRating = 4.0,
    bool excludePlayed = true,
    Set<String>? includeItemTypes,
  }) {
    return _service.getRecommendations(
      limit: limit,
      offset: offset,
      libraryId: libraryId,
      userId: userId,
      serverUrl: serverUrl,
      token: token,
      minCommunityRating: minCommunityRating,
      excludePlayed: excludePlayed,
      includeItemTypes: includeItemTypes,
    );
  }

  @override
  Future<List<MediaItem>> getSuggestions({
    int limit = 20,
    String? userId,
    required String serverUrl,
    required String token,
  }) {
    return _service.getSuggestions(
      limit: limit,
      userId: userId,
      serverUrl: serverUrl,
      token: token,
    );
  }

  @override
  Future<List<MediaItem>> getWatchHistory({
    int limit = 50,
    String? userId,
    required String serverUrl,
    required String token,
  }) {
    return _service.getWatchHistory(
      limit: limit,
      userId: userId,
      serverUrl: serverUrl,
      token: token,
    );
  }

  @override
  Future<List<MediaItem>> getChildren(
    String parentId, {
    int limit = 100,
    int offset = 0,
    required String serverUrl,
    required String token,
  }) {
    return _service.getChildren(
      parentId,
      limit: limit,
      offset: offset,
      serverUrl: serverUrl,
      token: token,
    );
  }

  @override
  Future<List<Library>> getGenres({
    int limit = 100,
    required String serverUrl,
    required String token,
  }) {
    return _service.getGenres(
      limit: limit,
      serverUrl: serverUrl,
      token: token,
    );
  }

  @override
  Future<PaginatedResponse<MediaItem>> getItemsByGenre(
    String genre, {
    int limit = 30,
    int offset = 0,
    required String serverUrl,
    required String token,
  }) {
    return _service.getItemsByGenre(
      genre,
      limit: limit,
      offset: offset,
      serverUrl: serverUrl,
      token: token,
    );
  }

  @override
  Future<List<Library>> getStudios({
    int limit = 100,
    required String serverUrl,
    required String token,
  }) {
    return _service.getStudios(
      limit: limit,
      serverUrl: serverUrl,
      token: token,
    );
  }

  @override
  Future<PaginatedResponse<MediaItem>> getItemsByStudio(
    String studio, {
    int limit = 30,
    int offset = 0,
    required String serverUrl,
    required String token,
  }) {
    return _service.getItemsByStudio(
      studio,
      limit: limit,
      offset: offset,
      serverUrl: serverUrl,
      token: token,
    );
  }
}
