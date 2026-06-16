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
        returnValue: Future.value(User(id: 'test', name: 'Test', accessToken: 'test')),
        returnValueForMissingStub: Future.value(User(id: 'test', name: 'Test', accessToken: 'test')),
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
        returnValue: Future.value(MediaItem(id: itemId, title: 'Test', type: 'Movie')),
        returnValueForMissingStub: Future.value(MediaItem(id: itemId, title: 'Test', type: 'Movie')),
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
}
