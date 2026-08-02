// Mock implementations for provider tests
// 手动创建 mock 类，避免依赖 build_runner

import 'package:dio/dio.dart';
import 'package:mockito/mockito.dart';
import 'package:embytok_flutter/models/models.dart';
import 'package:embytok_flutter/services/embytok_service.dart';

/// EmbytokService 的 Mock 实现
/// 注意：只覆盖测试实际需要的方法，其他方法继承自 EmbytokService
class MockEmbytokService extends Mock implements EmbytokService {
  // ============================
  // 登录
  // ============================
  @override
  Future<User> login({
    // 使用可空类型以便测试中能用 anyNamed 匹配 required 参数
    String? embyServerUrl,
    String? username,
    String? password,
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
    String? userId,
    String? serverUrl,
    String? token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getLibraries, [], {
          #userId: userId,
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future.value(<Library>[]),
        returnValueForMissingStub: Future.value(<Library>[]),
      ) as Future<List<Library>>;

  @override
  Future<PaginatedResponse<MediaItem>> getLibraryItems(
    String? libraryId, {
    int? limit,
    int? offset,
    String? userId,
    String? serverUrl,
    String? token,
    String? sortBy,
    String? sortOrder,
    String? searchTerm,
    bool? excludePlayed,
    CancelToken? cancelToken,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getLibraryItems, [libraryId], {
          #limit: limit,
          #offset: offset,
          #userId: userId,
          #serverUrl: serverUrl,
          #token: token,
          #sortBy: sortBy,
          #sortOrder: sortOrder,
          #searchTerm: searchTerm,
          #excludePlayed: excludePlayed,
          #cancelToken: cancelToken,
        }),
        returnValue: Future.value(PaginatedResponse<MediaItem>(
          items: [],
          total: 0,
          offset: 0,
          limit: limit ?? 20,
        )),
        returnValueForMissingStub: Future.value(PaginatedResponse<MediaItem>(
          items: [],
          total: 0,
          offset: 0,
          limit: limit ?? 20,
        )),
      ) as Future<PaginatedResponse<MediaItem>>;

  // ============================
  // 详情
  // ============================
  @override
  Future<MediaItem> getItemDetail(
    String? itemId, {
    String? userId,
    String? serverUrl,
    String? token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getItemDetail, [itemId], {
          #userId: userId,
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
    String? query, {
    int? limit,
    int? offset,
    List<String>? includeTypes,
    String? userId,
    String? serverUrl,
    String? token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#searchItems, [query], {
          #limit: limit,
          #offset: offset,
          #includeTypes: includeTypes,
          #userId: userId,
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future.value(PaginatedResponse<MediaItem>(
          items: [],
          total: 0,
          offset: 0,
          limit: limit ?? 30,
        )),
        returnValueForMissingStub: Future.value(PaginatedResponse<MediaItem>(
          items: [],
          total: 0,
          offset: 0,
          limit: limit ?? 30,
        )),
      ) as Future<PaginatedResponse<MediaItem>>;

  // ============================
  // 收藏
  // ============================
  @override
  Future<List<MediaItem>> getFavorites({
    int? limit,
    int? offset,
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

  // 收藏影片（按类型分栏）
  @override
  Future<FavoritesPageResult> getFavoriteMovies({
    int? limit,
    int? offset,
    String? userId,
    String? serverUrl,
    String? token,
    CancelToken? cancelToken,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getFavoriteMovies, [], {
          #limit: limit,
          #offset: offset,
          #userId: userId,
          #serverUrl: serverUrl,
          #token: token,
          #cancelToken: cancelToken,
        }),
        returnValue: Future.value(
            const FavoritesPageResult(items: <MediaItem>[], totalCount: 0)),
        returnValueForMissingStub: Future.value(
            const FavoritesPageResult(items: <MediaItem>[], totalCount: 0)),
      ) as Future<FavoritesPageResult>;

  // 收藏合集（BoxSet）
  @override
  Future<FavoritesPageResult> getFavoriteBoxSets({
    int? limit,
    int? offset,
    String? userId,
    String? serverUrl,
    String? token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getFavoriteBoxSets, [], {
          #limit: limit,
          #offset: offset,
          #userId: userId,
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future.value(
            const FavoritesPageResult(items: <MediaItem>[], totalCount: 0)),
        returnValueForMissingStub: Future.value(
            const FavoritesPageResult(items: <MediaItem>[], totalCount: 0)),
      ) as Future<FavoritesPageResult>;

  // 收藏人物（Person）
  @override
  Future<FavoritesPageResult> getFavoritePeople({
    int? limit,
    int? offset,
    String? userId,
    String? serverUrl,
    String? token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getFavoritePeople, [], {
          #limit: limit,
          #offset: offset,
          #userId: userId,
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future.value(
            const FavoritesPageResult(items: <MediaItem>[], totalCount: 0)),
        returnValueForMissingStub: Future.value(
            const FavoritesPageResult(items: <MediaItem>[], totalCount: 0)),
      ) as Future<FavoritesPageResult>;

  // 演员列表（getPeople）：参数声明为可空以便测试用 anyNamed 匹配
  // （mockito 5.x 在 Dart 3 严格 null 检查下，anyNamed 返回 Null 无法赋值给非空参数）
  @override
  Future<PaginatedResponse<Person>> getPeople({
    int? limit,
    int? startIndex,
    List<String>? personTypes,
    String? searchTerm,
    String? serverUrl,
    String? token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getPeople, [], {
          #limit: limit,
          #startIndex: startIndex,
          #personTypes: personTypes,
          #searchTerm: searchTerm,
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future<PaginatedResponse<Person>>.value(
          PaginatedResponse<Person>(items: const [], total: 0, offset: 0, limit: 0),
        ),
        returnValueForMissingStub: Future<PaginatedResponse<Person>>.value(
          PaginatedResponse<Person>(items: const [], total: 0, offset: 0, limit: 0),
        ),
      ) as Future<PaginatedResponse<Person>>;

  @override
  Future<void> toggleFavorite({
    // 使用可空类型以便测试中能用 anyNamed 匹配 required 参数
    String? itemId,
    bool? isFavorite,
    String? userId,
    String? serverUrl,
    String? token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#toggleFavorite, [], {
          #itemId: itemId,
          #isFavorite: isFavorite,
          #userId: userId,
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
    int? limit,
    int? offset,
    String? serverUrl,
    String? token,
    CancelToken? cancelToken,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getResumeItems, [], {
          #limit: limit,
          #offset: offset,
          #serverUrl: serverUrl,
          #token: token,
          #cancelToken: cancelToken,
        }),
        returnValue: Future.value(PaginatedResponse<MediaItem>(
          items: [],
          total: 0,
          offset: 0,
          limit: limit ?? 20,
        )),
        returnValueForMissingStub: Future.value(PaginatedResponse<MediaItem>(
          items: [],
          total: 0,
          offset: 0,
          limit: limit ?? 20,
        )),
      ) as Future<PaginatedResponse<MediaItem>>;

  @override
  Future<PaginatedResponse<MediaItem>> getNextUp({
    int? limit,
    String? seriesId,
    String? serverUrl,
    String? token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getNextUp, [], {
          #limit: limit,
          #seriesId: seriesId,
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future.value(PaginatedResponse<MediaItem>(
          items: [],
          total: 0,
          offset: 0,
          limit: limit ?? 20,
        )),
        returnValueForMissingStub: Future.value(PaginatedResponse<MediaItem>(
          items: [],
          total: 0,
          offset: 0,
          limit: limit ?? 20,
        )),
      ) as Future<PaginatedResponse<MediaItem>>;

  // ============================
  // 标记观看状态
  // ============================
  @override
  Future<void> markAsPlayed(
    String? itemId, {
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
    String? itemId, {
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

  // ============================
  // 搜索建议
  // ============================
  @override
  Future<List<SearchHint>> searchHints(
    // 测试中用 any 匹配位置参数，需要可空类型
    String? query, {
    int? limit,
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
      ) as Future<List<SearchHint>>;
}
