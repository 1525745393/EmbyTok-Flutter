// 从 embytok_service.dart 拆分（part 文件，无行为变化）

part of '../embytok_service.dart';

// ==================== EmbytokFavoritesApi ====================

mixin EmbytokFavoritesApi on EmbytokServiceBase {
  Future<List<MediaItem>> getFavorites({
    int limit = 100,
    int offset = 0,
    String? serverUrl,
    String? token,
  }) {
    return _api.getFavorites(
      limit: limit,
      offset: offset,
      serverUrl: serverUrl,
      token: token,
    );
  }

  Future<FavoritesPageResult> getFavoriteMovies({
    int limit = 50,
    int offset = 0,
    String? userId,
    String? serverUrl,
    String? token,
    CancelToken? cancelToken,
    List<String>? includeTypes,
    bool excludePlayed = false,
  }) {
    return _api.getFavoriteMovies(
      limit: limit,
      offset: offset,
      userId: userId,
      serverUrl: serverUrl,
      token: token,
      cancelToken: cancelToken,
      includeTypes: includeTypes,
      excludePlayed: excludePlayed,
    );
  }

  Future<FavoritesPageResult> getFavoriteBoxSets({
    int limit = 50,
    int offset = 0,
    String? userId,
    String? serverUrl,
    String? token,
  }) {
    return _api.getFavoriteBoxSets(
      limit: limit,
      offset: offset,
      userId: userId,
      serverUrl: serverUrl,
      token: token,
    );
  }

  Future<FavoritesPageResult> getFavoritePeople({
    int limit = 50,
    int offset = 0,
    String? userId,
    String? serverUrl,
    String? token,
  }) {
    return _api.getFavoritePeople(
      limit: limit,
      offset: offset,
      userId: userId,
      serverUrl: serverUrl,
      token: token,
    );
  }

  Future<Map<String, int>> getFavoriteCounts({
    String? userId,
    String? serverUrl,
    String? token,
  }) {
    return _api.getFavoriteCounts(
      userId: userId,
      serverUrl: serverUrl,
      token: token,
    );
  }

  Future<void> toggleFavorite({
    required String itemId,
    required bool isFavorite,
    String? userId,
    String? serverUrl,
    String? token,
  }) {
    return _api.toggleFavorite(
      itemId: itemId,
      isFavorite: isFavorite,
      userId: userId,
      serverUrl: serverUrl,
      token: token,
    );
  }

  Future<void> markAsPlayed(
    String itemId, {
    String? serverUrl,
    String? token,
  }) {
    return _api.markAsPlayed(
      itemId,
      serverUrl: serverUrl,
      token: token,
    );
  }

  Future<void> markAsUnplayed(
    String itemId, {
    String? serverUrl,
    String? token,
  }) {
    return _api.markAsUnplayed(
      itemId,
      serverUrl: serverUrl,
      token: token,
    );
  }

  Future<void> saveCloudSync({
    required String itemId,
    required String libraryId,
    String? libraryType,
    String? serverUrl,
    String? token,
  }) {
    return _api.saveCloudSync(
      itemId: itemId,
      libraryId: libraryId,
      libraryType: libraryType,
      serverUrl: serverUrl,
      token: token,
    );
  }

  Future<Map<String, dynamic>?> checkCloudSync({
    String? serverUrl,
    String? token,
  }) {
    return _api.checkCloudSync(
      serverUrl: serverUrl,
      token: token,
    );
  }
}
