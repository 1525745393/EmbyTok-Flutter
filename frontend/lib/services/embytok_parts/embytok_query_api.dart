// 从 embytok_service.dart 拆分（part 文件，无行为变化）

part of '../embytok_service.dart';

// ==================== EmbytokQueryApi ====================

mixin EmbytokQueryApi on EmbytokServiceBase {
  Future<List<Library>> getLibraries({
    String? userId,
    String? serverUrl,
    String? token,
  }) {
    return _api.getLibraries(
      userId: userId,
      serverUrl: serverUrl,
      token: token,
    );
  }

  Future<List<Library>> getUserViews({
    String? userId,
    String? serverUrl,
    String? token,
  }) {
    return _api.getUserViews(
      userId: userId,
      serverUrl: serverUrl,
      token: token,
    );
  }

  Future<PaginatedResponse<MediaItem>> getLibraryItems(
    String libraryId, {
    int limit = 20,
    int offset = 0,
    String? userId,
    String? serverUrl,
    String? token,
    String sortBy = 'DateCreated,SortName',
    String sortOrder = 'Descending',
    String? searchTerm,
    bool excludePlayed = false,
    CancelToken? cancelToken,
  }) {
    return _api.getLibraryItems(
      libraryId,
      limit: limit,
      offset: offset,
      userId: userId,
      serverUrl: serverUrl,
      token: token,
      sortBy: sortBy,
      sortOrder: sortOrder,
      searchTerm: searchTerm,
      excludePlayed: excludePlayed,
      cancelToken: cancelToken,
    );
  }

  Future<MediaItem> getItemDetail(
    String itemId, {
    String? userId,
    String? serverUrl,
    String? token,
  }) {
    return _api.getItemDetail(
      itemId,
      userId: userId,
      serverUrl: serverUrl,
      token: token,
    );
  }

  Future<PaginatedResponse<MediaItem>> getResumeItems({
    int limit = 20,
    int offset = 0,
    String? serverUrl,
    String? token,
    CancelToken? cancelToken,
    String? userId,
  }) {
    return _api.getResumeItems(
      limit: limit,
      offset: offset,
      serverUrl: serverUrl,
      token: token,
      cancelToken: cancelToken,
      userId: userId,
    );
  }

  Future<PaginatedResponse<MediaItem>> getRecommendations({
    int limit = 20,
    int offset = 0,
    String? libraryId,
    String? userId,
    String? serverUrl,
    String? token,
    double minCommunityRating = 4.0,
    bool excludePlayed = true,
    Set<String>? includeItemTypes,
  }) {
    return _api.getRecommendations(
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

  Future<PaginatedResponse<MediaItem>> getLatestItems({
    int limit = 20,
    int offset = 0,
    String? libraryId,
    String? userId,
    String? serverUrl,
    String? token,
    Set<String>? includeItemTypes,
  }) {
    return _api.getLatestItems(
      limit: limit,
      offset: offset,
      libraryId: libraryId,
      userId: userId,
      serverUrl: serverUrl,
      token: token,
      includeItemTypes: includeItemTypes,
    );
  }

  Future<List<MediaItem>> getSuggestions({
    int limit = 20,
    String? userId,
    String? serverUrl,
    String? token,
  }) {
    return _api.getSuggestions(
      limit: limit,
      userId: userId,
      serverUrl: serverUrl,
      token: token,
    );
  }

  Future<List<MediaItem>> getMovieRecommendations({
    int categoryLimit = 6,
    int itemLimit = 10,
    String? userId,
    String? libraryId,
    String? serverUrl,
    String? token,
  }) {
    return _api.getMovieRecommendations(
      categoryLimit: categoryLimit,
      itemLimit: itemLimit,
      userId: userId,
      libraryId: libraryId,
      serverUrl: serverUrl,
      token: token,
    );
  }

  Future<List<NativeRecGroup>> getMovieRecommendationGroups({
    int categoryLimit = 6,
    int itemLimit = 10,
    String? userId,
    String? libraryId,
    String? serverUrl,
    String? token,
  }) {
    return _api.getMovieRecommendationGroups(
      categoryLimit: categoryLimit,
      itemLimit: itemLimit,
      userId: userId,
      libraryId: libraryId,
      serverUrl: serverUrl,
      token: token,
    );
  }

  Future<List<MediaItem>> getRecommendedShows({
    int limit = 30,
    String? userId,
    String? libraryId,
    String? serverUrl,
    String? token,
  }) {
    return _api.getRecommendedShows(
      limit: limit,
      userId: userId,
      libraryId: libraryId,
      serverUrl: serverUrl,
      token: token,
    );
  }

  Future<PaginatedResponse<MediaItem>> getNextUp({
    int limit = 20,
    String? seriesId,
    String? serverUrl,
    String? token,
  }) {
    return _api.getNextUp(
      limit: limit,
      seriesId: seriesId,
      serverUrl: serverUrl,
      token: token,
    );
  }

  Future<PaginatedResponse<MediaItem>> getRecentlyAdded({
    int limit = 20,
    int offset = 0,
    String? libraryId,
    String? userId,
    String? serverUrl,
    String? token,
  }) {
    return _api.getRecentlyAdded(
      limit: limit,
      offset: offset,
      libraryId: libraryId,
      userId: userId,
      serverUrl: serverUrl,
      token: token,
    );
  }

  Future<List<MediaItem>> getSimilarItems(
    String itemId, {
    int limit = 20,
    String? serverUrl,
    String? token,
    String? userId,
  }) {
    return _api.getSimilarItems(
      itemId,
      limit: limit,
      serverUrl: serverUrl,
      token: token,
      userId: userId,
    );
  }

  Future<PaginatedResponse<Person>> getPeople({
    int limit = 50,
    int startIndex = 0,
    List<String>? personTypes,
    String? searchTerm,
    String? serverUrl,
    String? token,
  }) {
    return _api.getPeople(
      limit: limit,
      startIndex: startIndex,
      personTypes: personTypes,
      searchTerm: searchTerm,
      serverUrl: serverUrl,
      token: token,
    );
  }

  Future<PaginatedResponse<MediaItem>> getPersonItems(
    String personId, {
    int limit = 30,
    int offset = 0,
    String? serverUrl,
    String? token,
  }) {
    return _api.getPersonItems(
      personId,
      limit: limit,
      offset: offset,
      serverUrl: serverUrl,
      token: token,
    );
  }

  Future<PaginatedResponse<MediaItem>> getItemsByPersonIds({
    required List<String> personIds,
    int limit = 30,
    int offset = 0,
    String? serverUrl,
    String? token,
    String? userId,
  }) {
    return _api.getItemsByPersonIds(
      personIds: personIds,
      limit: limit,
      offset: offset,
      serverUrl: serverUrl,
      token: token,
      userId: userId,
    );
  }

  Future<PaginatedResponse<MediaItem>> getBoxSetItems(
    String boxSetId, {
    int limit = 50,
    int offset = 0,
    bool excludePlayed = false,
    String? serverUrl,
    String? token,
  }) {
    return _api.getBoxSetItems(
      boxSetId,
      limit: limit,
      offset: offset,
      excludePlayed: excludePlayed,
      serverUrl: serverUrl,
      token: token,
    );
  }

  Future<MediaItem?> getPersonDetail(
    String personId, {
    String? personName,
    String? serverUrl,
    String? token,
    String? userId,
  }) {
    return _api.getPersonDetail(
      personId,
      personName: personName,
      serverUrl: serverUrl,
      token: token,
      userId: userId,
    );
  }

  Future<List<Library>> getGenres({
    int limit = 100,
    String? serverUrl,
    String? token,
  }) {
    return _api.getGenres(
      limit: limit,
      serverUrl: serverUrl,
      token: token,
    );
  }

  Future<List<Library>> getCollections({
    int limit = 100,
    String? serverUrl,
    String? token,
  }) {
    return _api.getCollections(
      limit: limit,
      serverUrl: serverUrl,
      token: token,
    );
  }

  Future<List<Library>> getTags({
    int limit = 100,
    String? serverUrl,
    String? token,
  }) {
    return _api.getTags(
      limit: limit,
      serverUrl: serverUrl,
      token: token,
    );
  }

  Future<PaginatedResponse<MediaItem>> getItemsByTag(
    String tag, {
    int limit = 30,
    int offset = 0,
    String? serverUrl,
    String? token,
  }) {
    return _api.getItemsByTag(
      tag,
      limit: limit,
      offset: offset,
      serverUrl: serverUrl,
      token: token,
    );
  }

  Future<PaginatedResponse<MediaItem>> getItemsByGenre(
    String genre, {
    int limit = 30,
    int offset = 0,
    String? serverUrl,
    String? token,
  }) {
    return _api.getItemsByGenre(
      genre,
      limit: limit,
      offset: offset,
      serverUrl: serverUrl,
      token: token,
    );
  }

  Future<List<Library>> getStudios({
    int limit = 100,
    String? serverUrl,
    String? token,
  }) {
    return _api.getStudios(
      limit: limit,
      serverUrl: serverUrl,
      token: token,
    );
  }

  Future<PaginatedResponse<MediaItem>> getItemsByStudio(
    String studio, {
    int limit = 30,
    int offset = 0,
    String? serverUrl,
    String? token,
  }) {
    return _api.getItemsByStudio(
      studio,
      limit: limit,
      offset: offset,
      serverUrl: serverUrl,
      token: token,
    );
  }

  Future<List<MediaItem>> getSeasons(
    String seriesId, {
    String? serverUrl,
    String? token,
  }) {
    return _api.getSeasons(
      seriesId,
      serverUrl: serverUrl,
      token: token,
    );
  }

  Future<PaginatedResponse<MediaItem>> getEpisodes(
    String seriesId, {
    String? seasonId,
    int limit = 100,
    int offset = 0,
    String? serverUrl,
    String? token,
  }) {
    return _api.getEpisodes(
      seriesId,
      seasonId: seasonId,
      limit: limit,
      offset: offset,
      serverUrl: serverUrl,
      token: token,
    );
  }

  Future<PaginatedResponse<MediaItem>> getTrailers({
    int limit = 30,
    int offset = 0,
    String? serverUrl,
    String? token,
  }) {
    return _api.getTrailers(
      limit: limit,
      offset: offset,
      serverUrl: serverUrl,
      token: token,
    );
  }

  Future<List<MediaItem>> getWatchHistory({
    int limit = 50,
    String? userId,
    String? serverUrl,
    String? token,
  }) {
    return _api.getWatchHistory(
      limit: limit,
      userId: userId,
      serverUrl: serverUrl,
      token: token,
    );
  }

  Future<List<SearchHint>> searchHints(
    String query, {
    int limit = 20,
    String? serverUrl,
    String? token,
  }) {
    return _api.searchHints(
      query,
      limit: limit,
      serverUrl: serverUrl,
      token: token,
    );
  }

  Future<PaginatedResponse<MediaItem>> searchItems(
    String query, {
    int limit = 30,
    int offset = 0,
    List<String>? includeTypes,
    String? userId,
    String? serverUrl,
    String? token,
  }) {
    return _api.searchItems(
      query,
      limit: limit,
      offset: offset,
      includeTypes: includeTypes,
      userId: userId,
      serverUrl: serverUrl,
      token: token,
    );
  }

  Future<List<Map<String, dynamic>>> searchPersons(
    String query, {
    int limit = 20,
    String? serverUrl,
    String? token,
  }) {
    return _api.searchPersons(
      query,
      limit: limit,
      serverUrl: serverUrl,
      token: token,
    );
  }

  Future<List<MediaItem>> getChildren(
    String parentId, {
    int limit = 100,
    int offset = 0,
    String? serverUrl,
    String? token,
  }) {
    return _api.getChildren(
      parentId,
      limit: limit,
      offset: offset,
      serverUrl: serverUrl,
      token: token,
    );
  }
}
