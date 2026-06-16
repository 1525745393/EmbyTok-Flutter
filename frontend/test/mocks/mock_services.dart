// Mock implementations for provider tests（与当前 EmbytokService API 完全匹配）

import 'package:mockito/mockito.dart';

import 'package:embbytok_flutter/models/models.dart';
import 'package:embbytok_flutter/services/embbytok_service.dart';

/// EmbytokService 的 Mock 实现：所有方法签名与真实服务一致。
/// 使用 mockito 的 Mock 基类 + noSuchMethod 处理调用记录与返回值。
class MockEmbytokService extends Mock implements EmbytokService {
  // ============================
  // 认证 / 媒体库
  // ============================

  @override
  Future<User> login({
    required String embyServerUrl,
    required String username,
    required String password,
  }) =>
      super.noSuchMethod(
        Invocation.method(#login, <Object>[], {
          #embyServerUrl: embyServerUrl,
          #username: username,
          #password: password,
        }),
        returnValue: Future<User>.value(
          User(id: 'test', name: 'Test', accessToken: 'test'),
        ),
        returnValueForMissingStub: Future<User>.value(
          User(id: 'test', name: 'Test', accessToken: 'test'),
        ),
      );

  @override
  Future<List<Library>> getLibraries({
    String? serverUrl,
    String? token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getLibraries, <Object>[], {
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future<List<Library>>.value(<Library>[]),
        returnValueForMissingStub: Future<List<Library>>.value(<Library>[]),
      );

  // ============================
  // 视频列表 / 详情
  // ============================

  @override
  Future<PaginatedResponse<MediaItem>> getLibraryItems(
    String libraryId, {
    int limit = 20,
    int offset = 0,
    String? serverUrl,
    String? token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getLibraryItems, <Object>[libraryId], {
          #limit: limit,
          #offset: offset,
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future<PaginatedResponse<MediaItem>>.value(
          PaginatedResponse<MediaItem>(
            items: const <MediaItem>[],
            total: 0,
            offset: 0,
            limit: limit,
          ),
        ),
        returnValueForMissingStub: Future<PaginatedResponse<MediaItem>>.value(
          PaginatedResponse<MediaItem>(
            items: const <MediaItem>[],
            total: 0,
            offset: 0,
            limit: limit,
          ),
        ),
      );

  @override
  Future<MediaItem> getItemDetail(
    String itemId, {
    String? serverUrl,
    String? token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getItemDetail, <Object>[itemId], {
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future<MediaItem>.value(
          MediaItem(id: itemId, title: 'Test', type: 'Movie'),
        ),
        returnValueForMissingStub: Future<MediaItem>.value(
          MediaItem(id: itemId, title: 'Test', type: 'Movie'),
        ),
      );

  // ============================
  // 继续观看 / 下一步 / 最近添加
  // ============================

  @override
  Future<PaginatedResponse<MediaItem>> getResumeItems({
    int limit = 20,
    int offset = 0,
    String? serverUrl,
    String? token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getResumeItems, <Object>[], {
          #limit: limit,
          #offset: offset,
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future<PaginatedResponse<MediaItem>>.value(
          PaginatedResponse<MediaItem>(
            items: const <MediaItem>[],
            total: 0,
            offset: 0,
            limit: limit,
          ),
        ),
        returnValueForMissingStub: Future<PaginatedResponse<MediaItem>>.value(
          PaginatedResponse<MediaItem>(
            items: const <MediaItem>[],
            total: 0,
            offset: 0,
            limit: limit,
          ),
        ),
      );

  @override
  Future<PaginatedResponse<MediaItem>> getNextUp({
    int limit = 20,
    String? serverUrl,
    String? token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getNextUp, <Object>[], {
          #limit: limit,
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future<PaginatedResponse<MediaItem>>.value(
          PaginatedResponse<MediaItem>(
            items: const <MediaItem>[],
            total: 0,
            offset: 0,
            limit: limit,
          ),
        ),
        returnValueForMissingStub: Future<PaginatedResponse<MediaItem>>.value(
          PaginatedResponse<MediaItem>(
            items: const <MediaItem>[],
            total: 0,
            offset: 0,
            limit: limit,
          ),
        ),
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
        Invocation.method(#getRecentlyAdded, <Object>[], {
          #limit: limit,
          #offset: offset,
          #libraryId: libraryId,
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future<PaginatedResponse<MediaItem>>.value(
          PaginatedResponse<MediaItem>(
            items: const <MediaItem>[],
            total: 0,
            offset: 0,
            limit: limit,
          ),
        ),
        returnValueForMissingStub: Future<PaginatedResponse<MediaItem>>.value(
          PaginatedResponse<MediaItem>(
            items: const <MediaItem>[],
            total: 0,
            offset: 0,
            limit: limit,
          ),
        ),
      );

  // ============================
  // 相似影片 / 搜索
  // ============================

  @override
  Future<List<MediaItem>> getSimilarItems(
    String itemId, {
    int limit = 20,
    String? serverUrl,
    String? token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getSimilarItems, <Object>[itemId], {
          #limit: limit,
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future<List<MediaItem>>.value(<MediaItem>[]),
        returnValueForMissingStub: Future<List<MediaItem>>.value(<MediaItem>[]),
      );

  @override
  Future<List<SearchHint>> searchHints(
    String query, {
    int limit = 20,
    String? serverUrl,
    String? token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#searchHints, <Object>[query], {
          #limit: limit,
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future<List<SearchHint>>.value(<SearchHint>[]),
        returnValueForMissingStub: Future<List<SearchHint>>.value(<SearchHint>[]),
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
        Invocation.method(#searchItems, <Object>[query], {
          #limit: limit,
          #offset: offset,
          #includeTypes: includeTypes,
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future<PaginatedResponse<MediaItem>>.value(
          PaginatedResponse<MediaItem>(
            items: const <MediaItem>[],
            total: 0,
            offset: 0,
            limit: limit,
          ),
        ),
        returnValueForMissingStub: Future<PaginatedResponse<MediaItem>>.value(
          PaginatedResponse<MediaItem>(
            items: const <MediaItem>[],
            total: 0,
            offset: 0,
            limit: limit,
          ),
        ),
      );

  // ============================
  // 收藏 / 播放进度上报
  // ============================

  @override
  Future<List<MediaItem>> getFavorites({
    int limit = 100,
    int offset = 0,
    String? serverUrl,
    String? token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getFavorites, <Object>[], {
          #limit: limit,
          #offset: offset,
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future<List<MediaItem>>.value(<MediaItem>[]),
        returnValueForMissingStub: Future<List<MediaItem>>.value(<MediaItem>[]),
      );

  @override
  Future<void> toggleFavorite(
    String itemId, {
    required bool isFavorite,
    String? serverUrl,
    String? token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#toggleFavorite, <Object>[itemId], {
          #isFavorite: isFavorite,
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future<void>.value(),
        returnValueForMissingStub: Future<void>.value(),
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
        Invocation.method(#reportPlaybackPosition, <Object>[], {
          #itemId: itemId,
          #positionTicks: positionTicks,
          #mediaSourceId: mediaSourceId,
          #playSessionId: playSessionId,
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future<void>.value(),
        returnValueForMissingStub: Future<void>.value(),
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
        Invocation.method(#reportPlaybackStopped, <Object>[], {
          #itemId: itemId,
          #positionTicks: positionTicks,
          #mediaSourceId: mediaSourceId,
          #playSessionId: playSessionId,
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future<void>.value(),
        returnValueForMissingStub: Future<void>.value(),
      );
}
