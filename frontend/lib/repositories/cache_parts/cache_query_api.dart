// 从 cached_media_repository.dart 拆分（part 文件，无行为变化）

part of '../cached_media_repository.dart';

// ==================== _CacheQueryApi ====================

mixin _CacheQueryApi on CachedMediaRepositoryBase {
  Future<MediaItem> getItemDetail(
    String itemId, {
    required String serverUrl,
    required String token,
    String? userId,
  }) {
    final key = _itemDetailKey(itemId, serverUrl, token);
    return _withCache(
        _itemDetailCache,
        key,
        () => _inner.getItemDetail(
              itemId,
              serverUrl: serverUrl,
              token: token,
              userId: userId,
            ));
  }

  Future<PaginatedResponse<MediaItem>> getLibraryItems(
    MediaQueryParams params, {
    required String serverUrl,
    required String token,
    String? userId,
    CancelToken? cancelToken,
  }) {
    final key = _libraryItemsKey(params, serverUrl, token);
    return _withCache(
        _libraryItemsCache,
        key,
        () => _inner.getLibraryItems(
              params,
              serverUrl: serverUrl,
              token: token,
              userId: userId,
              cancelToken: cancelToken,
            ));
  }

  PaginatedResponse<MediaItem>? peekLibraryItems(
    MediaQueryParams params, {
    required String serverUrl,
    required String token,
    String? userId,
  }) {
    final key = _libraryItemsKey(params, serverUrl, token);
    return _libraryItemsCache.get(key);
  }

  Future<FavoritesPageResult> getFavoriteMovies({
    int limit = 50,
    int offset = 0,
    required String serverUrl,
    required String token,
    String? userId,
    CancelToken? cancelToken,
    List<String>? includeTypes,
    bool excludePlayed = false,
  }) {
    final key = _favoritesKey(serverUrl, token, userId, limit, offset);
    return _withCache(
        _favoritesCache,
        key,
        () => _inner.getFavoriteMovies(
              limit: limit,
              offset: offset,
              serverUrl: serverUrl,
              token: token,
              userId: userId,
              cancelToken: cancelToken,
              includeTypes: includeTypes,
              excludePlayed: excludePlayed,
            ));
  }

  FavoritesPageResult? peekFavoriteMovies({
    int limit = 50,
    int offset = 0,
    required String serverUrl,
    required String token,
    String? userId,
  }) {
    final key = _favoritesKey(serverUrl, token, userId, limit, offset);
    return _favoritesCache.get(key);
  }

  Future<FavoritesPageResult> getFavoriteBoxSets({
    int limit = 50,
    int offset = 0,
    required String serverUrl,
    required String token,
    String? userId,
  }) {
    final key = _boxSetsFavoritesKey(serverUrl, token, userId, limit, offset);
    return _withCache(
        _boxSetsFavoritesCache,
        key,
        () => _inner.getFavoriteBoxSets(
              limit: limit,
              offset: offset,
              serverUrl: serverUrl,
              token: token,
              userId: userId,
            ));
  }

  FavoritesPageResult? peekFavoriteBoxSets({
    int limit = 50,
    int offset = 0,
    required String serverUrl,
    required String token,
    String? userId,
  }) {
    final key = _boxSetsFavoritesKey(serverUrl, token, userId, limit, offset);
    return _boxSetsFavoritesCache.get(key);
  }

  Future<PaginatedResponse<MediaItem>> getResumeItems({
    required String serverUrl,
    required String token,
    int limit = 50,
    int offset = 0,
    CancelToken? cancelToken,
    String? userId,
  }) {
    final key = _resumeKey(serverUrl, token, limit, offset, userId);
    return _withCache(
        _resumeCache,
        key,
        () => _inner.getResumeItems(
              serverUrl: serverUrl,
              token: token,
              limit: limit,
              offset: offset,
              userId: userId,
              cancelToken: cancelToken,
            ));
  }

  Future<List<Library>> getLibraries({
    required String serverUrl,
    required String token,
    String? userId,
  }) {
    final key = _librariesKey(serverUrl, token, userId);
    return _withCache(
        _librariesCache,
        key,
        () => _inner.getLibraries(
              serverUrl: serverUrl,
              token: token,
              userId: userId,
            ),
        ttl: const Duration(minutes: 30));
  }

  Future<PaginatedResponse<MediaItem>> getNextUp({
    required String serverUrl,
    required String token,
    int limit = 20,
    String? seriesId,
  }) {
    final key = _nextUpKey(serverUrl, token, limit, seriesId);
    return _withCache(
        _nextUpCache,
        key,
        () => _inner.getNextUp(
              serverUrl: serverUrl,
              token: token,
              limit: limit,
              seriesId: seriesId,
            ),
        ttl: const Duration(minutes: 1));
  }

  Future<List<MediaItem>> getSeasons(
    String seriesId, {
    required String serverUrl,
    required String token,
  }) {
    final key = _seasonsKey(seriesId, serverUrl, token);
    return _withCache(
        _seasonsCache,
        key,
        () => _inner.getSeasons(
              seriesId,
              serverUrl: serverUrl,
              token: token,
            ));
  }

  Future<PaginatedResponse<MediaItem>> getEpisodes(
    String seriesId, {
    String? seasonId,
    int limit = 100,
    int offset = 0,
    required String serverUrl,
    required String token,
  }) {
    final key =
        _episodesKey(seriesId, seasonId, limit, offset, serverUrl, token);
    return _withCache(
        _episodesCache,
        key,
        () => _inner.getEpisodes(
              seriesId,
              seasonId: seasonId,
              limit: limit,
              offset: offset,
              serverUrl: serverUrl,
              token: token,
            ));
  }

  Future<List<MediaItem>> getSimilarItems(
    String itemId, {
    int limit = 12,
    required String serverUrl,
    required String token,
    String? userId,
  }) {
    final key = _similarItemsKey(itemId, limit, serverUrl, token, userId);
    return _withCache(
        _similarItemsCache,
        key,
        () => _inner.getSimilarItems(
              itemId,
              limit: limit,
              serverUrl: serverUrl,
              token: token,
              userId: userId,
            ));
  }

  Future<PaginatedResponse<Person>> getPeople({
    int limit = 50,
    int startIndex = 0,
    List<String>? personTypes,
    String? searchTerm,
    required String serverUrl,
    required String token,
  }) {
    final key = _peopleKey(
        limit, startIndex, personTypes, searchTerm, serverUrl, token);
    final ttl = (searchTerm != null && searchTerm.isNotEmpty)
        ? const Duration(seconds: 30)
        : _ttl;
    return _withCache(
        _peopleCache,
        key,
        () => _inner.getPeople(
              limit: limit,
              startIndex: startIndex,
              personTypes: personTypes,
              searchTerm: searchTerm,
              serverUrl: serverUrl,
              token: token,
            ),
        ttl: ttl);
  }

  Future<MediaItem?> getPersonDetail(
    String personId, {
    String? personName,
    required String serverUrl,
    required String token,
    String? userId,
  }) {
    final key = _personDetailKey(personId, serverUrl, token);
    return _withCache(
        _personDetailCache,
        key,
        () => _inner.getPersonDetail(
              personId,
              personName: personName,
              serverUrl: serverUrl,
              token: token,
              userId: userId,
            ),
        ttl: const Duration(minutes: 30));
  }

  Future<PaginatedResponse<MediaItem>> getPersonItems(
    String personId, {
    int limit = 30,
    int offset = 0,
    required String serverUrl,
    required String token,
  }) {
    final key = _personItemsKey(personId, limit, offset, serverUrl, token);
    return _withCache(
        _personItemsCache,
        key,
        () => _inner.getPersonItems(
              personId,
              limit: limit,
              offset: offset,
              serverUrl: serverUrl,
              token: token,
            ));
  }

  Future<PaginatedResponse<MediaItem>> getItemsByPersonIds({
    required List<String> personIds,
    int limit = 30,
    int offset = 0,
    required String serverUrl,
    required String token,
    String? userId,
  }) {
    // 收藏演员会变化，直接转发不缓存
    return _inner.getItemsByPersonIds(
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
    required String serverUrl,
    required String token,
  }) {
    return _inner.getBoxSetItems(
      boxSetId,
      limit: limit,
      offset: offset,
      excludePlayed: excludePlayed,
      serverUrl: serverUrl,
      token: token,
    );
  }

  Future<FavoritesPageResult> getFavoritePeople({
    int limit = 50,
    int offset = 0,
    required String serverUrl,
    required String token,
    String? userId,
  }) {
    final key = _favoritePeopleKey(serverUrl, token, userId, limit, offset);
    return _withCache(
        _favoritePeopleCache,
        key,
        () => _inner.getFavoritePeople(
              limit: limit,
              offset: offset,
              serverUrl: serverUrl,
              token: token,
              userId: userId,
            ));
  }

  FavoritesPageResult? peekFavoritePeople({
    int limit = 50,
    int offset = 0,
    required String serverUrl,
    required String token,
    String? userId,
  }) {
    final key = _favoritePeopleKey(serverUrl, token, userId, limit, offset);
    return _favoritePeopleCache.get(key);
  }

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
    final key = _recommendationsKey(
      limit,
      offset,
      libraryId,
      userId,
      serverUrl,
      token,
      minCommunityRating,
      excludePlayed,
      includeItemTypes,
    );
    return _withCache(
        _recommendationsCache,
        key,
        () => _inner.getRecommendations(
              limit: limit,
              offset: offset,
              libraryId: libraryId,
              userId: userId,
              serverUrl: serverUrl,
              token: token,
              minCommunityRating: minCommunityRating,
              excludePlayed: excludePlayed,
              includeItemTypes: includeItemTypes,
            ));
  }

  Future<PaginatedResponse<MediaItem>> getLatestItems({
    int limit = 20,
    int offset = 0,
    String? libraryId,
    String? userId,
    required String serverUrl,
    required String token,
    Set<String>? includeItemTypes,
  }) {
    // 最新影片随入库实时变化，直接转发不缓存
    return _inner.getLatestItems(
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
    required String serverUrl,
    required String token,
  }) {
    final key = _suggestionsKey(limit, userId, serverUrl, token);
    return _withCache(
        _suggestionsCache,
        key,
        () => _inner.getSuggestions(
              limit: limit,
              userId: userId,
              serverUrl: serverUrl,
              token: token,
            ));
  }

  Future<List<MediaItem>> getNativeRecommendations({
    String? userId,
    String? libraryId,
    required String serverUrl,
    required String token,
  }) {
    // 复用 suggestions 缓存容器，以独立前缀 native: 区分
    final key = 'native:$serverUrl:$token:${userId ?? ''}:${libraryId ?? ''}';
    return _withCache(
        _suggestionsCache,
        key,
        () => _inner.getNativeRecommendations(
              userId: userId,
              libraryId: libraryId,
              serverUrl: serverUrl,
              token: token,
            ),
        ttl: const Duration(minutes: 5));
  }

  Future<List<NativeRecGroup>> getMovieRecommendationGroups({
    String? userId,
    String? libraryId,
    required String serverUrl,
    required String token,
  }) {
    // 分组横幅首屏拉取一次、随 refresh 刷新；类型为 List<NativeRecGroup>，
    // 不复用 List<MediaItem> 的 suggestions 缓存容器，直接转发。
    return _inner.getMovieRecommendationGroups(
      userId: userId,
      libraryId: libraryId,
      serverUrl: serverUrl,
      token: token,
    );
  }

  Future<List<MediaItem>> getWatchHistory({
    int limit = 50,
    String? userId,
    required String serverUrl,
    required String token,
  }) {
    final key = _watchHistoryKey(limit, userId, serverUrl, token);
    return _withCache(
        _watchHistoryCache,
        key,
        () => _inner.getWatchHistory(
              limit: limit,
              userId: userId,
              serverUrl: serverUrl,
              token: token,
            ),
        ttl: const Duration(minutes: 1));
  }

  Future<List<MediaItem>> getChildren(
    String parentId, {
    int limit = 100,
    int offset = 0,
    required String serverUrl,
    required String token,
  }) {
    final key = _childrenKey(parentId, limit, offset, serverUrl, token);
    return _withCache(
        _childrenCache,
        key,
        () => _inner.getChildren(
              parentId,
              limit: limit,
              offset: offset,
              serverUrl: serverUrl,
              token: token,
            ));
  }

  Future<List<Library>> getGenres({
    int limit = 100,
    required String serverUrl,
    required String token,
  }) {
    final key = _genresKey(limit, serverUrl, token);
    return _withCache(
        _genresCache,
        key,
        () => _inner.getGenres(
              limit: limit,
              serverUrl: serverUrl,
              token: token,
            ),
        ttl: const Duration(minutes: 30));
  }

  Future<List<Library>> getCollections({
    int limit = 100,
    required String serverUrl,
    required String token,
  }) {
    final key = _collectionsKey(limit, serverUrl, token);
    return _withCache(
        _collectionsCache,
        key,
        () => _inner.getCollections(
              limit: limit,
              serverUrl: serverUrl,
              token: token,
            ),
        ttl: const Duration(minutes: 30));
  }

  Future<List<Library>> getTags({
    int limit = 100,
    required String serverUrl,
    required String token,
  }) {
    final key = _tagsKey(limit, serverUrl, token);
    return _withCache(
        _tagsCache,
        key,
        () => _inner.getTags(
              limit: limit,
              serverUrl: serverUrl,
              token: token,
            ),
        ttl: const Duration(minutes: 30));
  }

  Future<PaginatedResponse<MediaItem>> getItemsByTag(
    String tag, {
    int limit = 30,
    int offset = 0,
    required String serverUrl,
    required String token,
  }) {
    final key = _tagItemsKey(tag, limit, offset, serverUrl, token);
    return _withCache(
        _tagItemsCache,
        key,
        () => _inner.getItemsByTag(
              tag,
              limit: limit,
              offset: offset,
              serverUrl: serverUrl,
              token: token,
            ));
  }

  Future<PaginatedResponse<MediaItem>> getItemsByGenre(
    String genre, {
    int limit = 30,
    int offset = 0,
    required String serverUrl,
    required String token,
  }) {
    final key = _genreItemsKey(genre, limit, offset, serverUrl, token);
    return _withCache(
        _genreItemsCache,
        key,
        () => _inner.getItemsByGenre(
              genre,
              limit: limit,
              offset: offset,
              serverUrl: serverUrl,
              token: token,
            ));
  }

  Future<List<Library>> getStudios({
    int limit = 100,
    required String serverUrl,
    required String token,
  }) {
    final key = _studiosKey(limit, serverUrl, token);
    return _withCache(
        _studiosCache,
        key,
        () => _inner.getStudios(
              limit: limit,
              serverUrl: serverUrl,
              token: token,
            ),
        ttl: const Duration(minutes: 30));
  }

  Future<PaginatedResponse<MediaItem>> getItemsByStudio(
    String studio, {
    int limit = 30,
    int offset = 0,
    required String serverUrl,
    required String token,
  }) {
    final key = _studioItemsKey(studio, limit, offset, serverUrl, token);
    return _withCache(
        _studioItemsCache,
        key,
        () => _inner.getItemsByStudio(
              studio,
              limit: limit,
              offset: offset,
              serverUrl: serverUrl,
              token: token,
            ));
  }
}
