// Mock implementations for provider tests
// 手动创建 mock 类，避免依赖 build_runner

import 'package:mockito/mockito.dart';
import 'package:embbytok_flutter/models/models.dart';
import 'package:embbytok_flutter/services/embbytok_service.dart';

/// EmbytokService 的 Mock 实现
class MockEmbytokService extends Mock implements EmbytokService {
  @override
  Future<User> login({
    required String embyServerUrl,
    required String username,
    required String password,
  }) =>
      super.noSuchMethod(
        Invocation.method(#login, [], {
          #embyServerUrl: embyServerUrl,
          #username: username,
          #password: password,
        }),
        returnValue: Future.value(User(id: '', name: '', accessToken: '')),
        returnValueForMissingStub:
            Future.value(User(id: '', name: '', accessToken: '')),
      );

  @override
  Future<List<Library>> getLibraries({
    String? serverUrl,
    String? token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getLibraries, [], {
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future.value(<Library>[]),
        returnValueForMissingStub: Future.value(<Library>[]),
      );

  @override
  Future<PaginatedResponse<MediaItem>> getLibraryItems(
    String libraryId, {
    int limit = 20,
    int offset = 0,
    String? serverUrl,
    String? token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getLibraryItems, [libraryId], {
          #limit: limit,
          #offset: offset,
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future.value(PaginatedResponse<MediaItem>(
          items: const [],
          total: 0,
          offset: offset,
          limit: limit,
        )),
        returnValueForMissingStub: Future.value(PaginatedResponse<MediaItem>(
          items: const [],
          total: 0,
          offset: offset,
          limit: limit,
        )),
      );

  @override
  Future<MediaItem> getItemDetail(
    String itemId, {
    String? serverUrl,
    String? token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getItemDetail, [itemId], {
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future.value(MediaItem(id: '', title: '', type: '')),
        returnValueForMissingStub: Future.value(MediaItem(id: '', title: '', type: '')),
      );

  @override
  Future<PaginatedResponse<MediaItem>> getResumeItems({
    int limit = 20,
    int offset = 0,
    String? serverUrl,
    String? token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getResumeItems, [], {
          #limit: limit,
          #offset: offset,
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future.value(PaginatedResponse<MediaItem>(
          items: const [],
          total: 0,
          offset: offset,
          limit: limit,
        )),
        returnValueForMissingStub: Future.value(PaginatedResponse<MediaItem>(
          items: const [],
          total: 0,
          offset: offset,
          limit: limit,
        )),
      );

  @override
  Future<PaginatedResponse<MediaItem>> getNextUp({
    int limit = 20,
    String? serverUrl,
    String? token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getNextUp, [], {
          #limit: limit,
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future.value(PaginatedResponse<MediaItem>(
          items: const [],
          total: 0,
          offset: 0,
          limit: limit,
        )),
        returnValueForMissingStub: Future.value(PaginatedResponse<MediaItem>(
          items: const [],
          total: 0,
          offset: 0,
          limit: limit,
        )),
      );

  @override
  Future<PaginatedResponse<MediaItem>> getRecentlyAdded({
    int limit = 20,
    int offset = 0,
    String? libraryId,
    String? serverUrl,
    String? token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getRecentlyAdded, [], {
          #limit: limit,
          #offset: offset,
          #libraryId: libraryId,
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future.value(PaginatedResponse<MediaItem>(
          items: const [],
          total: 0,
          offset: offset,
          limit: limit,
        )),
        returnValueForMissingStub: Future.value(PaginatedResponse<MediaItem>(
          items: const [],
          total: 0,
          offset: offset,
          limit: limit,
        )),
      );

  @override
  Future<List<MediaItem>> getSimilarItems(
    String itemId, {
    int limit = 20,
    String? serverUrl,
    String? token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getSimilarItems, [itemId], {
          #limit: limit,
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future.value(<MediaItem>[]),
        returnValueForMissingStub: Future.value(<MediaItem>[]),
      );

  @override
  Future<List<Person>> getPeople({
    int limit = 50,
    List<String>? personTypes,
    String? serverUrl,
    String? token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getPeople, [], {
          #limit: limit,
          #personTypes: personTypes,
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future.value(<Person>[]),
        returnValueForMissingStub: Future.value(<Person>[]),
      );

  @override
  Future<PaginatedResponse<MediaItem>> getPersonItems(
    String personId, {
    int limit = 30,
    int offset = 0,
    String? serverUrl,
    String? token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getPersonItems, [personId], {
          #limit: limit,
          #offset: offset,
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future.value(PaginatedResponse<MediaItem>(
          items: const [],
          total: 0,
          offset: offset,
          limit: limit,
        )),
        returnValueForMissingStub: Future.value(PaginatedResponse<MediaItem>(
          items: const [],
          total: 0,
          offset: offset,
          limit: limit,
        )),
      );

  @override
  Future<List<Library>> getGenres({
    int limit = 100,
    String? serverUrl,
    String? token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getGenres, [], {
          #limit: limit,
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future.value(<Library>[]),
        returnValueForMissingStub: Future.value(<Library>[]),
      );

  @override
  Future<PaginatedResponse<MediaItem>> getItemsByGenre(
    String genre, {
    int limit = 30,
    int offset = 0,
    String? serverUrl,
    String? token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getItemsByGenre, [genre], {
          #limit: limit,
          #offset: offset,
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future.value(PaginatedResponse<MediaItem>(
          items: const [],
          total: 0,
          offset: offset,
          limit: limit,
        )),
        returnValueForMissingStub: Future.value(PaginatedResponse<MediaItem>(
          items: const [],
          total: 0,
          offset: offset,
          limit: limit,
        )),
      );

  @override
  Future<List<Library>> getStudios({
    int limit = 100,
    String? serverUrl,
    String? token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getStudios, [], {
          #limit: limit,
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future.value(<Library>[]),
        returnValueForMissingStub: Future.value(<Library>[]),
      );

  @override
  Future<PaginatedResponse<MediaItem>> getItemsByStudio(
    String studio, {
    int limit = 30,
    int offset = 0,
    String? serverUrl,
    String? token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getItemsByStudio, [studio], {
          #limit: limit,
          #offset: offset,
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future.value(PaginatedResponse<MediaItem>(
          items: const [],
          total: 0,
          offset: offset,
          limit: limit,
        )),
        returnValueForMissingStub: Future.value(PaginatedResponse<MediaItem>(
          items: const [],
          total: 0,
          offset: offset,
          limit: limit,
        )),
      );

  @override
  Future<List<MediaItem>> getFavorites({
    int limit = 100,
    int offset = 0,
    String? serverUrl,
    String? token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getFavorites, [], {
          #limit: limit,
          #offset: offset,
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future.value(<MediaItem>[]),
        returnValueForMissingStub: Future.value(<MediaItem>[]),
      );

  @override
  Future<void> toggleFavorite(
    String itemId, {
    required bool isFavorite,
    String? serverUrl,
    String? token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#toggleFavorite, [itemId], {
          #isFavorite: isFavorite,
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future.value(),
        returnValueForMissingStub: Future.value(),
      );

  @override
  Future<void> markAsPlayed(
    String itemId, {
    String? serverUrl,
    String? token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#markAsPlayed, [itemId], {
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future.value(),
        returnValueForMissingStub: Future.value(),
      );

  @override
  Future<void> markAsUnplayed(
    String itemId, {
    String? serverUrl,
    String? token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#markAsUnplayed, [itemId], {
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future.value(),
        returnValueForMissingStub: Future.value(),
      );

  @override
  Future<List<MediaItem>> getSeasons(
    String seriesId, {
    String? serverUrl,
    String? token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getSeasons, [seriesId], {
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future.value(<MediaItem>[]),
        returnValueForMissingStub: Future.value(<MediaItem>[]),
      );

  @override
  Future<PaginatedResponse<MediaItem>> getEpisodes(
    String seriesId, {
    String? seasonId,
    int limit = 100,
    int offset = 0,
    String? serverUrl,
    String? token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getEpisodes, [seriesId], {
          #seasonId: seasonId,
          #limit: limit,
          #offset: offset,
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future.value(PaginatedResponse<MediaItem>(
          items: const [],
          total: 0,
          offset: offset,
          limit: limit,
        )),
        returnValueForMissingStub: Future.value(PaginatedResponse<MediaItem>(
          items: const [],
          total: 0,
          offset: offset,
          limit: limit,
        )),
      );

  @override
  Future<PaginatedResponse<MediaItem>> getTrailers({
    int limit = 30,
    int offset = 0,
    String? serverUrl,
    String? token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getTrailers, [], {
          #limit: limit,
          #offset: offset,
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future.value(PaginatedResponse<MediaItem>(
          items: const [],
          total: 0,
          offset: offset,
          limit: limit,
        )),
        returnValueForMissingStub: Future.value(PaginatedResponse<MediaItem>(
          items: const [],
          total: 0,
          offset: offset,
          limit: limit,
        )),
      );

  @override
  Future<MediaItem?> getPlaybackInfo(
    String itemId, {
    String? serverUrl,
    String? token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getPlaybackInfo, [itemId], {
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future.value(null),
        returnValueForMissingStub: Future.value(null),
      );

  @override
  Future<void> reportPlaybackPosition({
    required String itemId,
    required int positionTicks,
    String? mediaSourceId,
    String? playSessionId,
    String? serverUrl,
    String? token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#reportPlaybackPosition, [], {
          #itemId: itemId,
          #positionTicks: positionTicks,
          #mediaSourceId: mediaSourceId,
          #playSessionId: playSessionId,
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future.value(),
        returnValueForMissingStub: Future.value(),
      );

  @override
  Future<void> reportPlaybackStopped({
    required String itemId,
    required int positionTicks,
    String? mediaSourceId,
    String? playSessionId,
    String? serverUrl,
    String? token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#reportPlaybackStopped, [], {
          #itemId: itemId,
          #positionTicks: positionTicks,
          #mediaSourceId: mediaSourceId,
          #playSessionId: playSessionId,
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future.value(),
        returnValueForMissingStub: Future.value(),
      );

  @override
  Future<List<SearchHint>> searchHints(
    String query, {
    int limit = 20,
    String? serverUrl,
    String? token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#searchHints, [query], {
          #limit: limit,
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future.value(<SearchHint>[]),
        returnValueForMissingStub: Future.value(<SearchHint>[]),
      );

  @override
  Future<PaginatedResponse<MediaItem>> searchItems(
    String query, {
    int limit = 30,
    int offset = 0,
    List<String>? includeTypes,
    String? serverUrl,
    String? token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#searchItems, [query], {
          #limit: limit,
          #offset: offset,
          #includeTypes: includeTypes,
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future.value(PaginatedResponse<MediaItem>(
          items: const [],
          total: 0,
          offset: offset,
          limit: limit,
        )),
        returnValueForMissingStub: Future.value(PaginatedResponse<MediaItem>(
          items: const [],
          total: 0,
          offset: offset,
          limit: limit,
        )),
      );
}
