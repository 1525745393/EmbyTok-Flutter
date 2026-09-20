// 从 cached_media_repository.dart 拆分（part 文件，无行为变化）

part of '../cached_media_repository.dart';

// ==================== _CacheInvalidateApi ====================

mixin _CacheInvalidateApi on CachedMediaRepositoryBase {
  void invalidateLibraryItems({
    required String libraryId,
    required String serverUrl,
  }) {
    _libraryItemsCache.deleteWherePrefix('lib:$serverUrl:');
  }

  void invalidateFavorites({
    required String serverUrl,
    required String token,
    String? userId,
  }) {
    // 影片：按前缀删除所有分页
    _favoritesCache.deleteWherePrefix('fav:$serverUrl:$token:${userId ?? ''}:');
    // 合集：按前缀删除所有分页
    _boxSetsFavoritesCache
        .deleteWherePrefix('fav_boxsets:$serverUrl:$token:${userId ?? ''}:');
    // 人物：按前缀删除所有分页
    _favoritePeopleCache
        .deleteWherePrefix('fav_people:$serverUrl:$token:${userId ?? ''}:');
  }

  void invalidateResume({
    required String serverUrl,
    required String token,
  }) {
    _resumeCache.clear();
  }

  void invalidateItemDetail({
    required String itemId,
    required String serverUrl,
  }) {
    _itemDetailCache.deleteWherePrefix('detail:$serverUrl:');
  }

  void invalidateNextUp({required String serverUrl}) {
    _nextUpCache.deleteWherePrefix('nextup:$serverUrl:');
  }

  void invalidateSeries({
    required String seriesId,
    required String serverUrl,
  }) {
    _seasonsCache.deleteWherePrefix('seasons:$serverUrl:');
    _episodesCache.deleteWherePrefix('episodes:$serverUrl:');
  }

  void invalidatePersonItems({required String serverUrl}) {
    _personItemsCache.deleteWherePrefix('person_items:$serverUrl:');
  }

  void invalidateWatchHistory({required String serverUrl}) {
    _watchHistoryCache.deleteWherePrefix('history:$serverUrl:');
  }

  void invalidateChildren({required String serverUrl}) {
    _childrenCache.deleteWherePrefix('children:$serverUrl:');
  }

  void invalidateGenres({required String serverUrl}) {
    _genresCache.deleteWherePrefix('genres:$serverUrl:');
  }

  void invalidateGenreItems({required String serverUrl}) {
    _genreItemsCache.deleteWherePrefix('genre_items:$serverUrl:');
  }

  void invalidateTags({required String serverUrl}) {
    _tagsCache.deleteWherePrefix('tags:$serverUrl:');
  }

  void invalidateTagItems({required String serverUrl}) {
    _tagItemsCache.deleteWherePrefix('tag_items:$serverUrl:');
  }

  void invalidateStudios({required String serverUrl}) {
    _studiosCache.deleteWherePrefix('studios:$serverUrl:');
  }

  void invalidateStudioItems({required String serverUrl}) {
    _studioItemsCache.deleteWherePrefix('studio_items:$serverUrl:');
  }

  void clearAll() {
    _pendingRefreshes.clear();
    _libraryItemsCache.clear();
    _favoritesCache.clear();
    _boxSetsFavoritesCache.clear();
    _resumeCache.clear();
    _itemDetailCache.clear();
    _librariesCache.clear();
    _nextUpCache.clear();
    _seasonsCache.clear();
    _episodesCache.clear();
    _similarItemsCache.clear();
    _peopleCache.clear();
    _personDetailCache.clear();
    _personItemsCache.clear();
    _favoritePeopleCache.clear();
    _recommendationsCache.clear();
    _suggestionsCache.clear();
    _watchHistoryCache.clear();
    _childrenCache.clear();
    _collectionsCache.clear();
    _tagsCache.clear();
    _genresCache.clear();
    _genreItemsCache.clear();
    _studiosCache.clear();
    _studioItemsCache.clear();
  }
}
