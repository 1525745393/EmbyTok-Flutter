// Mock implementations for provider tests
// 手动创建 mock 类，避免依赖 build_runner

import 'package:mockito/mockito.dart';
import 'package:embbytok_flutter/models/models.dart';
import 'package:embbytok_flutter/services/embbytok_service.dart';

/// EmbytokService 的 Mock 实现
/// 注意：只覆盖测试实际需要的方法，其他方法继承自 EmbytokService
class MockEmbytokService extends Mock implements EmbytokService {
  // ============================
  // 登录
  // ============================
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
      ) as Future<User>;

  // ============================
  // 媒体库
  // ============================
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
      ) as Future<List<Library>>;

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
      ) as Future<PaginatedResponse<MediaItem>>;

  // ============================
  // 详情
  // ============================
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
        returnValueForMissingStub:
            Future.value(MediaItem(id: '', title: '', type: '')),
      ) as Future<MediaItem>;

  // ============================
  // 搜索
  // ============================
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
      ) as Future<PaginatedResponse<MediaItem>>;

  // ============================
  // 收藏
  // ============================
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
      ) as Future<List<MediaItem>>;

  @override
  Future<void> toggleFavorite({
    required String itemId,
    required bool isFavorite,
    String? serverUrl,
    String? token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#toggleFavorite, [], {
          #itemId: itemId,
          #isFavorite: isFavorite,
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future.value(),
        returnValueForMissingStub: Future.value(),
      ) as Future<void>;

  // ============================
  // 继续观看 / 下一集
  // ============================
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
      ) as Future<PaginatedResponse<MediaItem>>;

  @override
  Future<PaginatedResponse<MediaItem>> getNextUp({
    int limit = 20,
    int offset = 0,
    String? serverUrl,
    String? token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getNextUp, [], {
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
      ) as Future<PaginatedResponse<MediaItem>>;

  // ============================
  // 标记观看状态
  // ============================
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
      ) as Future<void>;

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
      ) as Future<void>;
}
