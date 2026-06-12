// Mock implementations for provider tests
// 手动创建 mock 类，避免依赖 build_runner

import 'package:mockito/mockito.dart';
import 'package:embbytok_flutter/models/models.dart';
import 'package:embbytok_flutter/services/embbytok_service.dart';

/// EmbytokService 的 Mock 实现
class MockEmbytokService extends Mock implements EmbytokService {
  @override
  Future<User> login(
    String embyUrl,
    String backendUrl,
    String username,
    String password,
  ) =>
      super.noSuchMethod(
        Invocation.method(#login, [embyUrl, backendUrl, username, password]),
        returnValue: Future.value(User(id: '', name: '', accessToken: '')),
        returnValueForMissingStub: Future.value(User(id: '', name: '', accessToken: '')),
      );

  @override
  Future<List<Library>> getLibraries({
    required String serverUrl,
    required String token,
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
    required String serverUrl,
    required String token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getLibraryItems, [libraryId], {
          #limit: limit,
          #offset: offset,
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future.value(PaginatedResponse<MediaItem>(
          items: [],
          total: 0,
          offset: 0,
          limit: limit,
        )),
        returnValueForMissingStub: Future.value(PaginatedResponse<MediaItem>(
          items: [],
          total: 0,
          offset: 0,
          limit: limit,
        )),
      );

  @override
  Future<MediaItem> getItem(
    String itemId, {
    required String serverUrl,
    required String token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getItem, [itemId], {
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future.value(MediaItem(id: '', title: '', type: '')),
        returnValueForMissingStub: Future.value(MediaItem(id: '', title: '', type: '')),
      );

  @override
  Future<String> getPlaybackUrl(
    String itemId, {
    required String serverUrl,
    required String token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getPlaybackUrl, [itemId], {
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future.value(''),
        returnValueForMissingStub: Future.value(''),
      );

  @override
  Future<PaginatedResponse<MediaItem>> search(
    String query, {
    int limit = 20,
    int offset = 0,
    required String serverUrl,
    required String token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#search, [query], {
          #limit: limit,
          #offset: offset,
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future.value(PaginatedResponse<MediaItem>(
          items: [],
          total: 0,
          offset: 0,
          limit: limit,
        )),
        returnValueForMissingStub: Future.value(PaginatedResponse<MediaItem>(
          items: [],
          total: 0,
          offset: 0,
          limit: limit,
        )),
      );

  @override
  Future<void> toggleFavorite(
    String itemId,
    bool isFavorite, {
    required String serverUrl,
    required String token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#toggleFavorite, [itemId, isFavorite], {
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future.value(),
        returnValueForMissingStub: Future.value(),
      );

  @override
  Future<List<MediaItem>> getFavorites({
    required String serverUrl,
    required String token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getFavorites, [], {
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future.value(<MediaItem>[]),
        returnValueForMissingStub: Future.value(<MediaItem>[]),
      );

  @override
  Future<void> saveProgress(
    String itemId,
    int positionSeconds, {
    required String serverUrl,
    required String token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#saveProgress, [itemId, positionSeconds], {
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future.value(),
        returnValueForMissingStub: Future.value(),
      );

  @override
  Future<int?> getProgress(
    String itemId, {
    required String serverUrl,
    required String token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getProgress, [itemId], {
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future.value(null),
        returnValueForMissingStub: Future.value(null),
      );
}
