// 缓存 Repository 装饰器测试：验证装饰器透明添加缓存能力

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:embbytok_flutter/models/models.dart';
import 'package:embbytok_flutter/repositories/media_repository.dart';
import 'package:embbytok_flutter/repositories/cached_media_repository.dart';

import '../mocks/mock_services.dart';

class _MockMediaRepository extends Mock implements MediaRepository {
  @override
  Future<PaginatedResponse<MediaItem>> getLibraryItems(
    MediaQueryParams params, {
    required String serverUrl,
    required String token,
    String? userId,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getLibraryItems, [params], {
          #serverUrl: serverUrl,
          #token: token,
          #userId: userId,
        }),
        returnValue: Future.value(PaginatedResponse<MediaItem>(
          items: [],
          total: 0,
          offset: 0,
          limit: params.limit,
        )),
        returnValueForMissingStub: Future.value(PaginatedResponse<MediaItem>(
          items: [],
          total: 0,
          offset: 0,
          limit: params.limit,
        )),
      ) as Future<PaginatedResponse<MediaItem>>;

  @override
  Future<FavoritesPageResult> getFavoriteMovies({
    int limit = 50,
    int offset = 0,
    required String serverUrl,
    required String token,
    String? userId,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getFavoriteMovies, [], {
          #limit: limit,
          #offset: offset,
          #serverUrl: serverUrl,
          #token: token,
          #userId: userId,
        }),
        returnValue: Future.value(FavoritesPageResult(
          movies: [],
          boxSets: [],
          people: [],
        )),
        returnValueForMissingStub: Future.value(FavoritesPageResult(
          movies: [],
          boxSets: [],
          people: [],
        )),
      ) as Future<FavoritesPageResult>;

  @override
  Future<FavoritesPageResult> getFavoriteBoxSets({
    int limit = 50,
    int offset = 0,
    required String serverUrl,
    required String token,
    String? userId,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getFavoriteBoxSets, [], {
          #limit: limit,
          #offset: offset,
          #serverUrl: serverUrl,
          #token: token,
          #userId: userId,
        }),
        returnValue: Future.value(FavoritesPageResult(
          movies: [],
          boxSets: [],
          people: [],
        )),
        returnValueForMissingStub: Future.value(FavoritesPageResult(
          movies: [],
          boxSets: [],
          people: [],
        )),
      ) as Future<FavoritesPageResult>;

  @override
  Future<PaginatedResponse<MediaItem>> getResumeItems({
    required String serverUrl,
    required String token,
    int limit = 50,
    int offset = 0,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getResumeItems, [], {
          #serverUrl: serverUrl,
          #token: token,
          #limit: limit,
          #offset: offset,
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
  Future<MediaItem> getItemDetail(
    String itemId, {
    required String serverUrl,
    required String token,
    String? userId,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getItemDetail, [itemId], {
          #serverUrl: serverUrl,
          #token: token,
          #userId: userId,
        }),
        returnValue: Future.value(MediaItem(id: '', title: '', type: '')),
        returnValueForMissingStub:
            Future.value(MediaItem(id: '', title: '', type: '')),
      ) as Future<MediaItem>;

  @override
  Future<List<MediaItem>> getSimilarItems(
    String itemId, {
    int limit = 12,
    required String serverUrl,
    required String token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getSimilarItems, [itemId], {
          #limit: limit,
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future.value(<MediaItem>[]),
        returnValueForMissingStub: Future.value(<MediaItem>[]),
      ) as Future<List<MediaItem>>;

  @override
  Future<PaginatedResponse<Person>> getPeople({
    int limit = 50,
    int startIndex = 0,
    List<String>? personTypes,
    String? searchTerm,
    required String serverUrl,
    required String token,
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
        returnValue: Future.value(PaginatedResponse<Person>(
          items: const <Person>[],
          total: 0,
          offset: startIndex,
          limit: limit,
        )),
        returnValueForMissingStub: Future.value(PaginatedResponse<Person>(
          items: const <Person>[],
          total: 0,
          offset: startIndex,
          limit: limit,
        )),
      ) as Future<PaginatedResponse<Person>>;

  @override
  Future<MediaItem?> getPersonDetail(
    String personId, {
    required String serverUrl,
    required String token,
    String? userId,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getPersonDetail, [personId], {
          #serverUrl: serverUrl,
          #token: token,
          #userId: userId,
        }),
        returnValue: Future.value(null),
        returnValueForMissingStub: Future.value(null),
      ) as Future<MediaItem?>;

  @override
  Future<PaginatedResponse<MediaItem>> getPersonItems(
    String personId, {
    int limit = 30,
    int offset = 0,
    required String serverUrl,
    required String token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getPersonItems, [personId], {
          #limit: limit,
          #offset: offset,
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future.value(PaginatedResponse<MediaItem>(
          items: const <MediaItem>[],
          total: 0,
          offset: offset,
          limit: limit,
        )),
        returnValueForMissingStub: Future.value(PaginatedResponse<MediaItem>(
          items: const <MediaItem>[],
          total: 0,
          offset: offset,
          limit: limit,
        )),
      ) as Future<PaginatedResponse<MediaItem>>;

  @override
  Future<FavoritesPageResult> getFavoritePeople({
    int limit = 50,
    int offset = 0,
    required String serverUrl,
    required String token,
    String? userId,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getFavoritePeople, [], {
          #limit: limit,
          #offset: offset,
          #serverUrl: serverUrl,
          #token: token,
          #userId: userId,
        }),
        returnValue: Future.value(FavoritesPageResult(
          movies: [],
          boxSets: [],
          people: [],
        )),
        returnValueForMissingStub: Future.value(FavoritesPageResult(
          movies: [],
          boxSets: [],
          people: [],
        )),
      ) as Future<FavoritesPageResult>;

  @override
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
  }) =>
      super.noSuchMethod(
        Invocation.method(#getRecommendations, [], {
          #limit: limit,
          #offset: offset,
          #libraryId: libraryId,
          #userId: userId,
          #serverUrl: serverUrl,
          #token: token,
          #minCommunityRating: minCommunityRating,
          #excludePlayed: excludePlayed,
          #includeItemTypes: includeItemTypes,
        }),
        returnValue: Future.value(PaginatedResponse<MediaItem>(
          items: const <MediaItem>[],
          total: 0,
          offset: offset,
          limit: limit,
        )),
        returnValueForMissingStub: Future.value(PaginatedResponse<MediaItem>(
          items: const <MediaItem>[],
          total: 0,
          offset: offset,
          limit: limit,
        )),
      ) as Future<PaginatedResponse<MediaItem>>;

  @override
  Future<List<MediaItem>> getSuggestions({
    int limit = 20,
    String? userId,
    required String serverUrl,
    required String token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getSuggestions, [], {
          #limit: limit,
          #userId: userId,
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future.value(<MediaItem>[]),
        returnValueForMissingStub: Future.value(<MediaItem>[]),
      ) as Future<List<MediaItem>>;

  @override
  Future<List<MediaItem>> getWatchHistory({
    int limit = 50,
    String? userId,
    required String serverUrl,
    required String token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getWatchHistory, [], {
          #limit: limit,
          #userId: userId,
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future.value(<MediaItem>[]),
        returnValueForMissingStub: Future.value(<MediaItem>[]),
      ) as Future<List<MediaItem>>;

  @override
  Future<List<MediaItem>> getChildren(
    String parentId, {
    int limit = 100,
    int offset = 0,
    required String serverUrl,
    required String token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getChildren, [parentId], {
          #limit: limit,
          #offset: offset,
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future.value(<MediaItem>[]),
        returnValueForMissingStub: Future.value(<MediaItem>[]),
      ) as Future<List<MediaItem>>;

  @override
  Future<List<Library>> getGenres({
    int limit = 100,
    required String serverUrl,
    required String token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getGenres, [], {
          #limit: limit,
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future.value(<Library>[]),
        returnValueForMissingStub: Future.value(<Library>[]),
      ) as Future<List<Library>>;

  @override
  Future<PaginatedResponse<MediaItem>> getItemsByGenre(
    String genre, {
    int limit = 30,
    int offset = 0,
    required String serverUrl,
    required String token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getItemsByGenre, [genre], {
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
  Future<List<Library>> getStudios({
    int limit = 100,
    required String serverUrl,
    required String token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getStudios, [], {
          #limit: limit,
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future.value(<Library>[]),
        returnValueForMissingStub: Future.value(<Library>[]),
      ) as Future<List<Library>>;

  @override
  Future<PaginatedResponse<MediaItem>> getItemsByStudio(
    String studio, {
    int limit = 30,
    int offset = 0,
    required String serverUrl,
    required String token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getItemsByStudio, [studio], {
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
}

void main() {
  group('CachedMediaRepository', () {
    late _MockMediaRepository mockRepo;
    late CachedMediaRepository cachedRepo;

    final testParams = MediaQueryParams(
      libraryId: 'lib-1',
      limit: 20,
      offset: 0,
    );
    const testServerUrl = 'http://test.emby.local';
    const testToken = 'test-token-123';

    final testItem = MediaItem(id: 'item-1', title: 'Test Video', type: 'Movie');
    final testResponse = PaginatedResponse<MediaItem>(
      items: [testItem],
      total: 1,
      offset: 0,
      limit: 20,
    );

    setUp(() {
      mockRepo = _MockMediaRepository();
      cachedRepo = CachedMediaRepository(
        mockRepo,
        ttl: const Duration(minutes: 5),
        maxCacheEntries: 50,
      );
    });

    test('首次请求：转发到底层 Repository', () async {
      when(mockRepo.getLibraryItems(
        testParams,
        serverUrl: testServerUrl,
        token: testToken,
      )).thenAnswer((_) async => testResponse);

      final result = await cachedRepo.getLibraryItems(
        testParams,
        serverUrl: testServerUrl,
        token: testToken,
      );

      expect(result.items.length, 1);
      expect(result.items.first.id, 'item-1');
      verify(mockRepo.getLibraryItems(
        testParams,
        serverUrl: testServerUrl,
        token: testToken,
      )).called(1);
    });

    test('相同参数第二次请求：使用缓存，不调用底层 Repository', () async {
      when(mockRepo.getLibraryItems(
        testParams,
        serverUrl: testServerUrl,
        token: testToken,
      )).thenAnswer((_) async => testResponse);

      // 第一次请求
      await cachedRepo.getLibraryItems(
        testParams,
        serverUrl: testServerUrl,
        token: testToken,
      );

      // 第二次请求（相同参数）
      final result = await cachedRepo.getLibraryItems(
        testParams,
        serverUrl: testServerUrl,
        token: testToken,
      );

      expect(result.items.length, 1);
      // 只调用了一次底层 Repository（第一次）
      verify(mockRepo.getLibraryItems(
        testParams,
        serverUrl: testServerUrl,
        token: testToken,
      )).called(1);
    });

    test('不同参数：不命中缓存，调用底层 Repository', () async {
      when(mockRepo.getLibraryItems(
        any,
        serverUrl: testServerUrl,
        token: testToken,
      )).thenAnswer((invocation) async {
        final params = invocation.positionalArguments[0] as MediaQueryParams;
        return PaginatedResponse<MediaItem>(
          items: [MediaItem(id: 'item-${params.libraryId}', title: '', type: '')],
          total: 1,
          offset: 0,
          limit: params.limit,
        );
      });

      // 第一次：lib-1
      await cachedRepo.getLibraryItems(
        testParams,
        serverUrl: testServerUrl,
        token: testToken,
      );

      // 第二次：lib-2（不同 libraryId）
      final params2 = MediaQueryParams(libraryId: 'lib-2', limit: 20, offset: 0);
      await cachedRepo.getLibraryItems(
        params2,
        serverUrl: testServerUrl,
        token: testToken,
      );

      // 两次都调用了底层 Repository
      verify(mockRepo.getLibraryItems(
        testParams,
        serverUrl: testServerUrl,
        token: testToken,
      )).called(1);
      verify(mockRepo.getLibraryItems(
        params2,
        serverUrl: testServerUrl,
        token: testToken,
      )).called(1);
    });

    test('invalidate：清除指定 key 的缓存后重新请求', () async {
      when(mockRepo.getLibraryItems(
        testParams,
        serverUrl: testServerUrl,
        token: testToken,
      )).thenAnswer((_) async => testResponse);

      // 第一次请求
      await cachedRepo.getLibraryItems(
        testParams,
        serverUrl: testServerUrl,
        token: testToken,
      );

      // 清除缓存
      cachedRepo.invalidateLibraryItems(
        libraryId: testParams.libraryId,
        serverUrl: testServerUrl,
      );

      // 第二次请求（应该重新调用底层）
      await cachedRepo.getLibraryItems(
        testParams,
        serverUrl: testServerUrl,
        token: testToken,
      );

      verify(mockRepo.getLibraryItems(
        testParams,
        serverUrl: testServerUrl,
        token: testToken,
      )).called(2);
    });

    test('clearAll：清除所有缓存', () async {
      when(mockRepo.getLibraryItems(
        any,
        serverUrl: testServerUrl,
        token: testToken,
      )).thenAnswer((invocation) async {
        final params = invocation.positionalArguments[0] as MediaQueryParams;
        return PaginatedResponse<MediaItem>(
          items: [MediaItem(id: 'item-${params.libraryId}', title: '', type: '')],
          total: 1,
          offset: 0,
          limit: params.limit,
        );
      });

      final params1 = MediaQueryParams(libraryId: 'lib-1', limit: 20, offset: 0);
      final params2 = MediaQueryParams(libraryId: 'lib-2', limit: 20, offset: 0);

      // 填充两个缓存
      await cachedRepo.getLibraryItems(params1, serverUrl: testServerUrl, token: testToken);
      await cachedRepo.getLibraryItems(params2, serverUrl: testServerUrl, token: testToken);

      // 清除全部
      cachedRepo.clearAll();

      // 再次请求都应该重新调用底层
      await cachedRepo.getLibraryItems(params1, serverUrl: testServerUrl, token: testToken);
      await cachedRepo.getLibraryItems(params2, serverUrl: testServerUrl, token: testToken);

      verify(mockRepo.getLibraryItems(params1, serverUrl: testServerUrl, token: testToken)).called(2);
      verify(mockRepo.getLibraryItems(params2, serverUrl: testServerUrl, token: testToken)).called(2);
    });

    test('不同 token：不共享缓存（账号隔离）', () async {
      when(mockRepo.getLibraryItems(
        testParams,
        serverUrl: testServerUrl,
        token: anyNamed('token'),
      )).thenAnswer((invocation) async {
        final token = invocation.namedArguments[#token] as String;
        return PaginatedResponse<MediaItem>(
          items: [MediaItem(id: 'item-$token', title: '', type: '')],
          total: 1,
          offset: 0,
          limit: 20,
        );
      });

      // 用户1
      await cachedRepo.getLibraryItems(
        testParams,
        serverUrl: testServerUrl,
        token: 'token-user1',
      );

      // 用户2（相同参数，不同 token）
      await cachedRepo.getLibraryItems(
        testParams,
        serverUrl: testServerUrl,
        token: 'token-user2',
      );

      // 两次都调用了底层（因为 token 不同）
      verify(mockRepo.getLibraryItems(
        testParams,
        serverUrl: testServerUrl,
        token: 'token-user1',
      )).called(1);
      verify(mockRepo.getLibraryItems(
        testParams,
        serverUrl: testServerUrl,
        token: 'token-user2',
      )).called(1);
    });

    test('不同 serverUrl：不共享缓存（多服务器隔离）', () async {
      when(mockRepo.getLibraryItems(
        testParams,
        serverUrl: anyNamed('serverUrl'),
        token: testToken,
      )).thenAnswer((invocation) async {
        final serverUrl = invocation.namedArguments[#serverUrl] as String;
        return PaginatedResponse<MediaItem>(
          items: [MediaItem(id: 'item-$serverUrl', title: '', type: '')],
          total: 1,
          offset: 0,
          limit: 20,
        );
      });

      // 服务器1
      await cachedRepo.getLibraryItems(
        testParams,
        serverUrl: 'http://server1.local',
        token: testToken,
      );

      // 服务器2（相同参数，不同 serverUrl）
      await cachedRepo.getLibraryItems(
        testParams,
        serverUrl: 'http://server2.local',
        token: testToken,
      );

      // 两次都调用了底层（因为 serverUrl 不同）
      verify(mockRepo.getLibraryItems(
        testParams,
        serverUrl: 'http://server1.local',
        token: testToken,
      )).called(1);
      verify(mockRepo.getLibraryItems(
        testParams,
        serverUrl: 'http://server2.local',
        token: testToken,
      )).called(1);
    });

    group('peekLibraryItems', () {
      test('缓存未命中返回 null', () {
        final result = cachedRepo.peekLibraryItems(
          testParams,
          serverUrl: testServerUrl,
          token: testToken,
        );

        expect(result, isNull);
      });

      test('缓存命中返回数据且不触发网络请求', () async {
        when(mockRepo.getLibraryItems(
          testParams,
          serverUrl: testServerUrl,
          token: testToken,
        )).thenAnswer((_) async => testResponse);

        await cachedRepo.getLibraryItems(
          testParams,
          serverUrl: testServerUrl,
          token: testToken,
        );

        final result = cachedRepo.peekLibraryItems(
          testParams,
          serverUrl: testServerUrl,
          token: testToken,
        );

        expect(result, isNotNull);
        expect(result!.items.length, 1);
        expect(result.items.first.id, 'item-1');
        verify(mockRepo.getLibraryItems(
          testParams,
          serverUrl: testServerUrl,
          token: testToken,
        )).called(1);
      });

      test('过期缓存返回 null', () async {
        final ttlZeroRepo = CachedMediaRepository(
          mockRepo,
          ttl: Duration.zero,
          maxCacheEntries: 50,
        );

        when(mockRepo.getLibraryItems(
          testParams,
          serverUrl: testServerUrl,
          token: testToken,
        )).thenAnswer((_) async => testResponse);

        await ttlZeroRepo.getLibraryItems(
          testParams,
          serverUrl: testServerUrl,
          token: testToken,
        );

        final result = ttlZeroRepo.peekLibraryItems(
          testParams,
          serverUrl: testServerUrl,
          token: testToken,
        );

        expect(result, isNull);
      });
    });

    group('getFavoriteMovies', () {
      final testFavResult = FavoritesPageResult(
        movies: [MediaItem(id: 'fav-1', title: 'Fav Movie', type: 'Movie')],
        boxSets: [],
        people: [],
      );

      test('首次请求：转发到底层 Repository', () async {
        when(mockRepo.getFavoriteMovies(
          serverUrl: testServerUrl,
          token: testToken,
          userId: 'user-1',
        )).thenAnswer((_) async => testFavResult);

        final result = await cachedRepo.getFavoriteMovies(
          serverUrl: testServerUrl,
          token: testToken,
          userId: 'user-1',
        );

        expect(result.movies.length, 1);
        expect(result.movies.first.id, 'fav-1');
        verify(mockRepo.getFavoriteMovies(
          serverUrl: testServerUrl,
          token: testToken,
          userId: 'user-1',
        )).called(1);
      });

      test('相同参数第二次请求：使用缓存', () async {
        when(mockRepo.getFavoriteMovies(
          serverUrl: testServerUrl,
          token: testToken,
          userId: 'user-1',
        )).thenAnswer((_) async => testFavResult);

        // 第一次
        await cachedRepo.getFavoriteMovies(
          serverUrl: testServerUrl,
          token: testToken,
          userId: 'user-1',
        );

        // 第二次
        final result = await cachedRepo.getFavoriteMovies(
          serverUrl: testServerUrl,
          token: testToken,
          userId: 'user-1',
        );

        expect(result.movies.length, 1);
        verify(mockRepo.getFavoriteMovies(
          serverUrl: testServerUrl,
          token: testToken,
          userId: 'user-1',
        )).called(1); // 只调用了一次
      });

      test('invalidateFavorites：清除收藏缓存后重新请求', () async {
        when(mockRepo.getFavoriteMovies(
          serverUrl: testServerUrl,
          token: testToken,
          userId: 'user-1',
        )).thenAnswer((_) async => testFavResult);

        // 第一次
        await cachedRepo.getFavoriteMovies(
          serverUrl: testServerUrl,
          token: testToken,
          userId: 'user-1',
        );

        // 清除收藏缓存
        cachedRepo.invalidateFavorites(
          serverUrl: testServerUrl,
          token: testToken,
          userId: 'user-1',
        );

        // 第二次（应该重新调用底层）
        await cachedRepo.getFavoriteMovies(
          serverUrl: testServerUrl,
          token: testToken,
          userId: 'user-1',
        );

        verify(mockRepo.getFavoriteMovies(
          serverUrl: testServerUrl,
          token: testToken,
          userId: 'user-1',
        )).called(2);
      });
    });

    group('getResumeItems', () {
      final testResumeResult = PaginatedResponse<MediaItem>(
        items: [MediaItem(id: 'resume-1', title: 'Resume Video', type: 'Movie')],
        total: 1,
        offset: 0,
        limit: 50,
      );

      test('首次请求：转发到底层 Repository', () async {
        when(mockRepo.getResumeItems(
          serverUrl: testServerUrl,
          token: testToken,
          limit: 50,
          offset: 0,
        )).thenAnswer((_) async => testResumeResult);

        final result = await cachedRepo.getResumeItems(
          serverUrl: testServerUrl,
          token: testToken,
          limit: 50,
          offset: 0,
        );

        expect(result.items.length, 1);
        expect(result.items.first.id, 'resume-1');
        verify(mockRepo.getResumeItems(
          serverUrl: testServerUrl,
          token: testToken,
          limit: 50,
          offset: 0,
        )).called(1);
      });

      test('相同参数第二次请求：使用缓存', () async {
        when(mockRepo.getResumeItems(
          serverUrl: testServerUrl,
          token: testToken,
          limit: 50,
          offset: 0,
        )).thenAnswer((_) async => testResumeResult);

        // 第一次
        await cachedRepo.getResumeItems(
          serverUrl: testServerUrl,
          token: testToken,
          limit: 50,
          offset: 0,
        );

        // 第二次
        final result = await cachedRepo.getResumeItems(
          serverUrl: testServerUrl,
          token: testToken,
          limit: 50,
          offset: 0,
        );

        expect(result.items.length, 1);
        verify(mockRepo.getResumeItems(
          serverUrl: testServerUrl,
          token: testToken,
          limit: 50,
          offset: 0,
        )).called(1); // 只调用了一次
      });

      test('不同 limit：不命中缓存', () async {
        when(mockRepo.getResumeItems(
          serverUrl: testServerUrl,
          token: testToken,
          limit: anyNamed('limit'),
          offset: 0,
        )).thenAnswer((invocation) async {
          final limit = invocation.namedArguments[#limit] as int;
          return PaginatedResponse<MediaItem>(
            items: [MediaItem(id: 'resume-limit-$limit', title: '', type: '')],
            total: 1,
            offset: 0,
            limit: limit,
          );
        });

        // limit=50
        await cachedRepo.getResumeItems(
          serverUrl: testServerUrl,
          token: testToken,
          limit: 50,
          offset: 0,
        );

        // limit=100（不同）
        await cachedRepo.getResumeItems(
          serverUrl: testServerUrl,
          token: testToken,
          limit: 100,
          offset: 0,
        );

        verify(mockRepo.getResumeItems(
          serverUrl: testServerUrl,
          token: testToken,
          limit: 50,
          offset: 0,
        )).called(1);
        verify(mockRepo.getResumeItems(
          serverUrl: testServerUrl,
          token: testToken,
          limit: 100,
          offset: 0,
        )).called(1);
      });

      test('invalidateResume：清除续播缓存后重新请求', () async {
        when(mockRepo.getResumeItems(
          serverUrl: testServerUrl,
          token: testToken,
          limit: 50,
          offset: 0,
        )).thenAnswer((_) async => testResumeResult);

        // 第一次
        await cachedRepo.getResumeItems(
          serverUrl: testServerUrl,
          token: testToken,
          limit: 50,
          offset: 0,
        );

        // 清除续播缓存
        cachedRepo.invalidateResume(
          serverUrl: testServerUrl,
          token: testToken,
        );

        // 第二次（应该重新调用底层）
        await cachedRepo.getResumeItems(
          serverUrl: testServerUrl,
          token: testToken,
          limit: 50,
          offset: 0,
        );

        verify(mockRepo.getResumeItems(
          serverUrl: testServerUrl,
          token: testToken,
          limit: 50,
          offset: 0,
        )).called(2);
      });
    });

    group('clearAll', () {
      test('清除所有类型的缓存', () async {
        when(mockRepo.getLibraryItems(
          any,
          serverUrl: testServerUrl,
          token: testToken,
        )).thenAnswer((_) async => testResponse);
        when(mockRepo.getFavoriteMovies(
          serverUrl: testServerUrl,
          token: testToken,
          userId: 'user-1',
        )).thenAnswer((_) async => FavoritesPageResult(movies: [], boxSets: [], people: []));
        when(mockRepo.getResumeItems(
          serverUrl: testServerUrl,
          token: testToken,
          limit: 50,
          offset: 0,
        )).thenAnswer((_) async => PaginatedResponse<MediaItem>(
          items: [], total: 0, offset: 0, limit: 50,
        ));

        // 填充各类缓存
        await cachedRepo.getLibraryItems(testParams, serverUrl: testServerUrl, token: testToken);
        await cachedRepo.getFavoriteMovies(serverUrl: testServerUrl, token: testToken, userId: 'user-1');
        await cachedRepo.getResumeItems(serverUrl: testServerUrl, token: testToken);

        // 清除全部
        cachedRepo.clearAll();

        // 再次请求都应该重新调用底层
        await cachedRepo.getLibraryItems(testParams, serverUrl: testServerUrl, token: testToken);
        await cachedRepo.getFavoriteMovies(serverUrl: testServerUrl, token: testToken, userId: 'user-1');
        await cachedRepo.getResumeItems(serverUrl: testServerUrl, token: testToken);

        verify(mockRepo.getLibraryItems(any, serverUrl: testServerUrl, token: testToken)).called(2);
        verify(mockRepo.getFavoriteMovies(serverUrl: testServerUrl, token: testToken, userId: 'user-1')).called(2);
        verify(mockRepo.getResumeItems(serverUrl: testServerUrl, token: testToken)).called(2);
      });
    });

    group('getItemDetail', () {
      final testDetailItem = MediaItem(
        id: 'detail-1',
        title: 'Detail Test Movie',
        type: 'Movie',
      );

      test('首次请求：转发到底层 Repository', () async {
        when(mockRepo.getItemDetail(
          'detail-1',
          serverUrl: testServerUrl,
          token: testToken,
          userId: 'user-1',
        )).thenAnswer((_) async => testDetailItem);

        final result = await cachedRepo.getItemDetail(
          'detail-1',
          serverUrl: testServerUrl,
          token: testToken,
          userId: 'user-1',
        );

        expect(result.id, 'detail-1');
        expect(result.title, 'Detail Test Movie');
        verify(mockRepo.getItemDetail(
          'detail-1',
          serverUrl: testServerUrl,
          token: testToken,
          userId: 'user-1',
        )).called(1);
      });

      test('相同参数第二次请求：使用缓存', () async {
        when(mockRepo.getItemDetail(
          'detail-1',
          serverUrl: testServerUrl,
          token: testToken,
          userId: 'user-1',
        )).thenAnswer((_) async => testDetailItem);

        // 第一次
        await cachedRepo.getItemDetail(
          'detail-1',
          serverUrl: testServerUrl,
          token: testToken,
          userId: 'user-1',
        );

        // 第二次（应命中缓存）
        final result = await cachedRepo.getItemDetail(
          'detail-1',
          serverUrl: testServerUrl,
          token: testToken,
          userId: 'user-1',
        );

        expect(result.id, 'detail-1');
        // 底层只调用了一次
        verify(mockRepo.getItemDetail(
          'detail-1',
          serverUrl: testServerUrl,
          token: testToken,
          userId: 'user-1',
        )).called(1);
      });

      test('不同 itemId：不命中缓存', () async {
        when(mockRepo.getItemDetail(
          any,
          serverUrl: testServerUrl,
          token: testToken,
          userId: 'user-1',
        )).thenAnswer((invocation) async {
          final itemId = invocation.positionalArguments[0] as String;
          return MediaItem(id: itemId, title: '', type: '');
        });

        await cachedRepo.getItemDetail('item-a', serverUrl: testServerUrl, token: testToken, userId: 'user-1');
        await cachedRepo.getItemDetail('item-b', serverUrl: testServerUrl, token: testToken, userId: 'user-1');

        verify(mockRepo.getItemDetail('item-a', serverUrl: testServerUrl, token: testToken, userId: 'user-1')).called(1);
        verify(mockRepo.getItemDetail('item-b', serverUrl: testServerUrl, token: testToken, userId: 'user-1')).called(1);
      });

      test('不同 token：不共享缓存（账号隔离）', () async {
        when(mockRepo.getItemDetail(
          'detail-1',
          serverUrl: testServerUrl,
          token: anyNamed('token'),
          userId: 'user-1',
        )).thenAnswer((invocation) async {
          final token = invocation.namedArguments[#token] as String;
          return MediaItem(id: 'detail-1-$token', title: '', type: '');
        });

        await cachedRepo.getItemDetail('detail-1', serverUrl: testServerUrl, token: 'token-a', userId: 'user-1');
        await cachedRepo.getItemDetail('detail-1', serverUrl: testServerUrl, token: 'token-b', userId: 'user-1');

        verify(mockRepo.getItemDetail('detail-1', serverUrl: testServerUrl, token: 'token-a', userId: 'user-1')).called(1);
        verify(mockRepo.getItemDetail('detail-1', serverUrl: testServerUrl, token: 'token-b', userId: 'user-1')).called(1);
      });

      test('invalidateItemDetail：清除指定条目缓存后重新请求', () async {
        when(mockRepo.getItemDetail(
          'detail-1',
          serverUrl: testServerUrl,
          token: testToken,
          userId: 'user-1',
        )).thenAnswer((_) async => testDetailItem);

        // 第一次
        await cachedRepo.getItemDetail('detail-1', serverUrl: testServerUrl, token: testToken, userId: 'user-1');

        // 失效单个条目
        cachedRepo.invalidateItemDetail(itemId: 'detail-1', serverUrl: testServerUrl);

        // 第二次（应重新调用底层）
        await cachedRepo.getItemDetail('detail-1', serverUrl: testServerUrl, token: testToken, userId: 'user-1');

        verify(mockRepo.getItemDetail('detail-1', serverUrl: testServerUrl, token: testToken, userId: 'user-1')).called(2);
      });
    });

    group('getSimilarItems', () {
      final testSimilarItems = <MediaItem>[
        MediaItem(id: 'sim-1', title: 'Similar Movie 1', type: 'Movie'),
        MediaItem(id: 'sim-2', title: 'Similar Movie 2', type: 'Movie'),
      ];

      test('首次请求：转发到底层 Repository', () async {
        when(mockRepo.getSimilarItems(
          'item-1',
          limit: 12,
          serverUrl: testServerUrl,
          token: testToken,
        )).thenAnswer((_) async => testSimilarItems);

        final result = await cachedRepo.getSimilarItems(
          'item-1',
          limit: 12,
          serverUrl: testServerUrl,
          token: testToken,
        );

        expect(result.length, 2);
        expect(result.first.id, 'sim-1');
        verify(mockRepo.getSimilarItems(
          'item-1',
          limit: 12,
          serverUrl: testServerUrl,
          token: testToken,
        )).called(1);
      });

      test('相同参数第二次请求：使用缓存', () async {
        when(mockRepo.getSimilarItems(
          'item-1',
          limit: 12,
          serverUrl: testServerUrl,
          token: testToken,
        )).thenAnswer((_) async => testSimilarItems);

        // 第一次
        await cachedRepo.getSimilarItems(
          'item-1',
          limit: 12,
          serverUrl: testServerUrl,
          token: testToken,
        );

        // 第二次（应命中缓存）
        final result = await cachedRepo.getSimilarItems(
          'item-1',
          limit: 12,
          serverUrl: testServerUrl,
          token: testToken,
        );

        expect(result.length, 2);
        // 底层只调用了一次
        verify(mockRepo.getSimilarItems(
          'item-1',
          limit: 12,
          serverUrl: testServerUrl,
          token: testToken,
        )).called(1);
      });

      test('不同 itemId：不命中缓存', () async {
        when(mockRepo.getSimilarItems(
          any,
          limit: 12,
          serverUrl: testServerUrl,
          token: testToken,
        )).thenAnswer((invocation) async {
          final itemId = invocation.positionalArguments[0] as String;
          return <MediaItem>[MediaItem(id: 'sim-for-$itemId', title: '', type: '')];
        });

        await cachedRepo.getSimilarItems('item-a', limit: 12, serverUrl: testServerUrl, token: testToken);
        await cachedRepo.getSimilarItems('item-b', limit: 12, serverUrl: testServerUrl, token: testToken);

        verify(mockRepo.getSimilarItems('item-a', limit: 12, serverUrl: testServerUrl, token: testToken)).called(1);
        verify(mockRepo.getSimilarItems('item-b', limit: 12, serverUrl: testServerUrl, token: testToken)).called(1);
      });

      test('不同 limit：不命中缓存', () async {
        when(mockRepo.getSimilarItems(
          'item-1',
          limit: anyNamed('limit'),
          serverUrl: testServerUrl,
          token: testToken,
        )).thenAnswer((invocation) async {
          final limit = invocation.namedArguments[#limit] as int;
          return <MediaItem>[MediaItem(id: 'sim-limit-$limit', title: '', type: '')];
        });

        await cachedRepo.getSimilarItems('item-1', limit: 12, serverUrl: testServerUrl, token: testToken);
        await cachedRepo.getSimilarItems('item-1', limit: 24, serverUrl: testServerUrl, token: testToken);

        verify(mockRepo.getSimilarItems('item-1', limit: 12, serverUrl: testServerUrl, token: testToken)).called(1);
        verify(mockRepo.getSimilarItems('item-1', limit: 24, serverUrl: testServerUrl, token: testToken)).called(1);
      });

      test('不同 token：不共享缓存（账号隔离）', () async {
        when(mockRepo.getSimilarItems(
          'item-1',
          limit: 12,
          serverUrl: testServerUrl,
          token: anyNamed('token'),
        )).thenAnswer((invocation) async {
          final token = invocation.namedArguments[#token] as String;
          return <MediaItem>[MediaItem(id: 'sim-$token', title: '', type: '')];
        });

        await cachedRepo.getSimilarItems('item-1', limit: 12, serverUrl: testServerUrl, token: 'token-a');
        await cachedRepo.getSimilarItems('item-1', limit: 12, serverUrl: testServerUrl, token: 'token-b');

        verify(mockRepo.getSimilarItems('item-1', limit: 12, serverUrl: testServerUrl, token: 'token-a')).called(1);
        verify(mockRepo.getSimilarItems('item-1', limit: 12, serverUrl: testServerUrl, token: 'token-b')).called(1);
      });

      test('clearAll：清除相似推荐缓存后重新请求', () async {
        when(mockRepo.getSimilarItems(
          'item-1',
          limit: 12,
          serverUrl: testServerUrl,
          token: testToken,
        )).thenAnswer((_) async => testSimilarItems);

        // 第一次
        await cachedRepo.getSimilarItems('item-1', limit: 12, serverUrl: testServerUrl, token: testToken);

        // 清除全部
        cachedRepo.clearAll();

        // 第二次（应重新调用底层）
        await cachedRepo.getSimilarItems('item-1', limit: 12, serverUrl: testServerUrl, token: testToken);

        verify(mockRepo.getSimilarItems('item-1', limit: 12, serverUrl: testServerUrl, token: testToken)).called(2);
      });
    });

    group('getPeople', () {
      final testPeople = <Person>[
        Person(id: 'person-1', name: 'Actor A', type: 'Actor'),
        Person(id: 'person-2', name: 'Actor B', type: 'Director'),
      ];
      final testPeopleResult = PaginatedResponse<Person>(
        items: testPeople,
        total: 2,
        offset: 0,
        limit: 50,
      );

      test('首次请求：转发到底层 Repository', () async {
        when(mockRepo.getPeople(
          limit: 50,
          startIndex: 0,
          personTypes: null,
          searchTerm: null,
          serverUrl: testServerUrl,
          token: testToken,
        )).thenAnswer((_) async => testPeopleResult);

        final result = await cachedRepo.getPeople(
          limit: 50,
          startIndex: 0,
          serverUrl: testServerUrl,
          token: testToken,
        );

        expect(result.items.length, 2);
        expect(result.items.first.id, 'person-1');
        verify(mockRepo.getPeople(
          limit: 50,
          startIndex: 0,
          personTypes: null,
          searchTerm: null,
          serverUrl: testServerUrl,
          token: testToken,
        )).called(1);
      });

      test('相同参数第二次请求：使用缓存', () async {
        when(mockRepo.getPeople(
          limit: 50,
          startIndex: 0,
          personTypes: null,
          searchTerm: null,
          serverUrl: testServerUrl,
          token: testToken,
        )).thenAnswer((_) async => testPeopleResult);

        await cachedRepo.getPeople(
          limit: 50,
          startIndex: 0,
          serverUrl: testServerUrl,
          token: testToken,
        );

        final result = await cachedRepo.getPeople(
          limit: 50,
          startIndex: 0,
          serverUrl: testServerUrl,
          token: testToken,
        );

        expect(result.items.length, 2);
        verify(mockRepo.getPeople(
          limit: 50,
          startIndex: 0,
          personTypes: null,
          searchTerm: null,
          serverUrl: testServerUrl,
          token: testToken,
        )).called(1);
      });

      test('不同 startIndex：不命中缓存（分页隔离）', () async {
        when(mockRepo.getPeople(
          limit: anyNamed('limit'),
          startIndex: anyNamed('startIndex'),
          personTypes: anyNamed('personTypes'),
          searchTerm: anyNamed('searchTerm'),
          serverUrl: testServerUrl,
          token: testToken,
        )).thenAnswer((invocation) async {
          final startIndex = invocation.namedArguments[#startIndex] as int;
          return PaginatedResponse<Person>(
            items: <Person>[Person(id: 'p-$startIndex', name: '', type: 'Actor')],
            total: 1,
            offset: startIndex,
            limit: 50,
          );
        });

        await cachedRepo.getPeople(limit: 50, startIndex: 0, serverUrl: testServerUrl, token: testToken);
        await cachedRepo.getPeople(limit: 50, startIndex: 50, serverUrl: testServerUrl, token: testToken);

        verify(mockRepo.getPeople(limit: 50, startIndex: 0, personTypes: null, searchTerm: null, serverUrl: testServerUrl, token: testToken)).called(1);
        verify(mockRepo.getPeople(limit: 50, startIndex: 50, personTypes: null, searchTerm: null, serverUrl: testServerUrl, token: testToken)).called(1);
      });

      test('不同 token：不共享缓存（账号隔离）', () async {
        when(mockRepo.getPeople(
          limit: 50,
          startIndex: 0,
          personTypes: null,
          searchTerm: null,
          serverUrl: testServerUrl,
          token: anyNamed('token'),
        )).thenAnswer((invocation) async {
          final token = invocation.namedArguments[#token] as String;
          return PaginatedResponse<Person>(
            items: <Person>[Person(id: 'p-$token', name: '', type: 'Actor')],
            total: 1,
            offset: 0,
            limit: 50,
          );
        });

        await cachedRepo.getPeople(limit: 50, startIndex: 0, serverUrl: testServerUrl, token: 'token-a');
        await cachedRepo.getPeople(limit: 50, startIndex: 0, serverUrl: testServerUrl, token: 'token-b');

        verify(mockRepo.getPeople(limit: 50, startIndex: 0, personTypes: null, searchTerm: null, serverUrl: testServerUrl, token: 'token-a')).called(1);
        verify(mockRepo.getPeople(limit: 50, startIndex: 0, personTypes: null, searchTerm: null, serverUrl: testServerUrl, token: 'token-b')).called(1);
      });

      test('clearAll：清除人员列表缓存后重新请求', () async {
        when(mockRepo.getPeople(
          limit: 50,
          startIndex: 0,
          personTypes: null,
          searchTerm: null,
          serverUrl: testServerUrl,
          token: testToken,
        )).thenAnswer((_) async => testPeopleResult);

        await cachedRepo.getPeople(limit: 50, startIndex: 0, serverUrl: testServerUrl, token: testToken);
        cachedRepo.clearAll();
        await cachedRepo.getPeople(limit: 50, startIndex: 0, serverUrl: testServerUrl, token: testToken);

        verify(mockRepo.getPeople(limit: 50, startIndex: 0, personTypes: null, searchTerm: null, serverUrl: testServerUrl, token: testToken)).called(2);
      });
    });

    group('getPersonDetail', () {
      final testPersonItem = MediaItem(id: 'person-1', title: 'Actor A', type: 'Person');

      test('首次请求：转发到底层 Repository', () async {
        when(mockRepo.getPersonDetail(
          'person-1',
          serverUrl: testServerUrl,
          token: testToken,
          userId: 'user-1',
        )).thenAnswer((_) async => testPersonItem);

        final result = await cachedRepo.getPersonDetail(
          'person-1',
          serverUrl: testServerUrl,
          token: testToken,
          userId: 'user-1',
        );

        expect(result?.id, 'person-1');
        verify(mockRepo.getPersonDetail(
          'person-1',
          serverUrl: testServerUrl,
          token: testToken,
          userId: 'user-1',
        )).called(1);
      });

      test('相同参数第二次请求：使用缓存', () async {
        when(mockRepo.getPersonDetail(
          'person-1',
          serverUrl: testServerUrl,
          token: testToken,
          userId: 'user-1',
        )).thenAnswer((_) async => testPersonItem);

        await cachedRepo.getPersonDetail('person-1', serverUrl: testServerUrl, token: testToken, userId: 'user-1');
        final result = await cachedRepo.getPersonDetail('person-1', serverUrl: testServerUrl, token: testToken, userId: 'user-1');

        expect(result?.id, 'person-1');
        verify(mockRepo.getPersonDetail(
          'person-1',
          serverUrl: testServerUrl,
          token: testToken,
          userId: 'user-1',
        )).called(1);
      });

      test('不同 personId：不命中缓存', () async {
        when(mockRepo.getPersonDetail(
          any,
          serverUrl: testServerUrl,
          token: testToken,
          userId: 'user-1',
        )).thenAnswer((invocation) async {
          final personId = invocation.positionalArguments[0] as String;
          return MediaItem(id: personId, title: '', type: 'Person');
        });

        await cachedRepo.getPersonDetail('p-a', serverUrl: testServerUrl, token: testToken, userId: 'user-1');
        await cachedRepo.getPersonDetail('p-b', serverUrl: testServerUrl, token: testToken, userId: 'user-1');

        verify(mockRepo.getPersonDetail('p-a', serverUrl: testServerUrl, token: testToken, userId: 'user-1')).called(1);
        verify(mockRepo.getPersonDetail('p-b', serverUrl: testServerUrl, token: testToken, userId: 'user-1')).called(1);
      });

      test('null 结果也能被缓存（避免重复请求不存在的演员）', () async {
        when(mockRepo.getPersonDetail(
          'missing',
          serverUrl: testServerUrl,
          token: testToken,
          userId: 'user-1',
        )).thenAnswer((_) async => null);

        await cachedRepo.getPersonDetail('missing', serverUrl: testServerUrl, token: testToken, userId: 'user-1');
        final result = await cachedRepo.getPersonDetail('missing', serverUrl: testServerUrl, token: testToken, userId: 'user-1');

        expect(result, isNull);
        // 底层只调用了一次（第二次命中缓存）
        verify(mockRepo.getPersonDetail(
          'missing',
          serverUrl: testServerUrl,
          token: testToken,
          userId: 'user-1',
        )).called(1);
      });
    });

    group('getPersonItems', () {
      final testPersonItems = PaginatedResponse<MediaItem>(
        items: <MediaItem>[
          MediaItem(id: 'movie-1', title: 'Movie A', type: 'Movie'),
          MediaItem(id: 'movie-2', title: 'Movie B', type: 'Movie'),
        ],
        total: 2,
        offset: 0,
        limit: 30,
      );

      test('首次请求：转发到底层 Repository', () async {
        when(mockRepo.getPersonItems(
          'person-1',
          limit: 30,
          offset: 0,
          serverUrl: testServerUrl,
          token: testToken,
        )).thenAnswer((_) async => testPersonItems);

        final result = await cachedRepo.getPersonItems(
          'person-1',
          limit: 30,
          offset: 0,
          serverUrl: testServerUrl,
          token: testToken,
        );

        expect(result.items.length, 2);
        expect(result.items.first.id, 'movie-1');
        verify(mockRepo.getPersonItems(
          'person-1',
          limit: 30,
          offset: 0,
          serverUrl: testServerUrl,
          token: testToken,
        )).called(1);
      });

      test('相同参数第二次请求：使用缓存', () async {
        when(mockRepo.getPersonItems(
          'person-1',
          limit: 30,
          offset: 0,
          serverUrl: testServerUrl,
          token: testToken,
        )).thenAnswer((_) async => testPersonItems);

        await cachedRepo.getPersonItems('person-1', limit: 30, offset: 0, serverUrl: testServerUrl, token: testToken);
        final result = await cachedRepo.getPersonItems('person-1', limit: 30, offset: 0, serverUrl: testServerUrl, token: testToken);

        expect(result.items.length, 2);
        verify(mockRepo.getPersonItems(
          'person-1',
          limit: 30,
          offset: 0,
          serverUrl: testServerUrl,
          token: testToken,
        )).called(1);
      });

      test('不同 offset：不命中缓存（分页隔离）', () async {
        when(mockRepo.getPersonItems(
          'person-1',
          limit: 30,
          offset: anyNamed('offset'),
          serverUrl: testServerUrl,
          token: testToken,
        )).thenAnswer((invocation) async {
          final offset = invocation.namedArguments[#offset] as int;
          return PaginatedResponse<MediaItem>(
            items: <MediaItem>[MediaItem(id: 'm-$offset', title: '', type: 'Movie')],
            total: 1,
            offset: offset,
            limit: 30,
          );
        });

        await cachedRepo.getPersonItems('person-1', limit: 30, offset: 0, serverUrl: testServerUrl, token: testToken);
        await cachedRepo.getPersonItems('person-1', limit: 30, offset: 30, serverUrl: testServerUrl, token: testToken);

        verify(mockRepo.getPersonItems('person-1', limit: 30, offset: 0, serverUrl: testServerUrl, token: testToken)).called(1);
        verify(mockRepo.getPersonItems('person-1', limit: 30, offset: 30, serverUrl: testServerUrl, token: testToken)).called(1);
      });

      test('invalidatePersonItems：清除演员作品缓存后重新请求', () async {
        when(mockRepo.getPersonItems(
          'person-1',
          limit: 30,
          offset: 0,
          serverUrl: testServerUrl,
          token: testToken,
        )).thenAnswer((_) async => testPersonItems);

        await cachedRepo.getPersonItems('person-1', limit: 30, offset: 0, serverUrl: testServerUrl, token: testToken);

        cachedRepo.invalidatePersonItems(serverUrl: testServerUrl);

        await cachedRepo.getPersonItems('person-1', limit: 30, offset: 0, serverUrl: testServerUrl, token: testToken);

        verify(mockRepo.getPersonItems('person-1', limit: 30, offset: 0, serverUrl: testServerUrl, token: testToken)).called(2);
      });
    });

    group('getFavoritePeople', () {
      final testFavPeopleResult = FavoritesPageResult(
        movies: [],
        boxSets: [],
        people: [MediaItem(id: 'fav-person-1', title: 'Fav Actor', type: 'Person')],
      );

      test('首次请求：转发到底层 Repository', () async {
        when(mockRepo.getFavoritePeople(
          serverUrl: testServerUrl,
          token: testToken,
          userId: 'user-1',
        )).thenAnswer((_) async => testFavPeopleResult);

        final result = await cachedRepo.getFavoritePeople(
          serverUrl: testServerUrl,
          token: testToken,
          userId: 'user-1',
        );

        expect(result.people.length, 1);
        expect(result.people.first.id, 'fav-person-1');
        verify(mockRepo.getFavoritePeople(
          serverUrl: testServerUrl,
          token: testToken,
          userId: 'user-1',
        )).called(1);
      });

      test('相同参数第二次请求：使用缓存', () async {
        when(mockRepo.getFavoritePeople(
          serverUrl: testServerUrl,
          token: testToken,
          userId: 'user-1',
        )).thenAnswer((_) async => testFavPeopleResult);

        await cachedRepo.getFavoritePeople(serverUrl: testServerUrl, token: testToken, userId: 'user-1');
        final result = await cachedRepo.getFavoritePeople(serverUrl: testServerUrl, token: testToken, userId: 'user-1');

        expect(result.people.length, 1);
        verify(mockRepo.getFavoritePeople(
          serverUrl: testServerUrl,
          token: testToken,
          userId: 'user-1',
        )).called(1);
      });

      test('invalidateFavorites：清除收藏人物缓存后重新请求', () async {
        when(mockRepo.getFavoritePeople(
          serverUrl: testServerUrl,
          token: testToken,
          userId: 'user-1',
        )).thenAnswer((_) async => testFavPeopleResult);

        await cachedRepo.getFavoritePeople(serverUrl: testServerUrl, token: testToken, userId: 'user-1');

        // invalidateFavorites 现在统一失效影片+合集+人物三类
        cachedRepo.invalidateFavorites(
          serverUrl: testServerUrl,
          token: testToken,
          userId: 'user-1',
        );

        await cachedRepo.getFavoritePeople(serverUrl: testServerUrl, token: testToken, userId: 'user-1');

        verify(mockRepo.getFavoritePeople(
          serverUrl: testServerUrl,
          token: testToken,
          userId: 'user-1',
        )).called(2);
      });

      test('不同 offset：不命中缓存（分页隔离）', () async {
        when(mockRepo.getFavoritePeople(
          limit: 50,
          offset: anyThat(isNonZero),
          serverUrl: testServerUrl,
          token: testToken,
          userId: 'user-1',
        )).thenAnswer((_) async => testFavPeopleResult);

        await cachedRepo.getFavoritePeople(serverUrl: testServerUrl, token: testToken, userId: 'user-1');
        await cachedRepo.getFavoritePeople(limit: 50, offset: 50, serverUrl: testServerUrl, token: testToken, userId: 'user-1');

        verify(mockRepo.getFavoritePeople(serverUrl: testServerUrl, token: testToken, userId: 'user-1')).called(1);
        verify(mockRepo.getFavoritePeople(limit: 50, offset: 50, serverUrl: testServerUrl, token: testToken, userId: 'user-1')).called(1);
      });
    });

    group('getFavoriteBoxSets', () {
      final testFavBoxSetsResult = FavoritesPageResult(
        movies: [],
        boxSets: [MediaItem(id: 'fav-boxset-1', title: 'Fav BoxSet', type: 'BoxSet')],
        people: [],
      );

      test('首次请求：转发到底层 Repository', () async {
        when(mockRepo.getFavoriteBoxSets(
          serverUrl: testServerUrl,
          token: testToken,
          userId: 'user-1',
        )).thenAnswer((_) async => testFavBoxSetsResult);

        final result = await cachedRepo.getFavoriteBoxSets(
          serverUrl: testServerUrl,
          token: testToken,
          userId: 'user-1',
        );

        expect(result.boxSets.length, 1);
        expect(result.boxSets.first.id, 'fav-boxset-1');
        verify(mockRepo.getFavoriteBoxSets(
          serverUrl: testServerUrl,
          token: testToken,
          userId: 'user-1',
        )).called(1);
      });

      test('相同参数第二次请求：使用缓存', () async {
        when(mockRepo.getFavoriteBoxSets(
          serverUrl: testServerUrl,
          token: testToken,
          userId: 'user-1',
        )).thenAnswer((_) async => testFavBoxSetsResult);

        await cachedRepo.getFavoriteBoxSets(serverUrl: testServerUrl, token: testToken, userId: 'user-1');
        final result = await cachedRepo.getFavoriteBoxSets(serverUrl: testServerUrl, token: testToken, userId: 'user-1');

        expect(result.boxSets.length, 1);
        verify(mockRepo.getFavoriteBoxSets(
          serverUrl: testServerUrl,
          token: testToken,
          userId: 'user-1',
        )).called(1);
      });

      test('不同 offset：不命中缓存（分页隔离）', () async {
        when(mockRepo.getFavoriteBoxSets(
          limit: 50,
          offset: anyThat(isNonZero),
          serverUrl: testServerUrl,
          token: testToken,
          userId: 'user-1',
        )).thenAnswer((_) async => testFavBoxSetsResult);

        await cachedRepo.getFavoriteBoxSets(serverUrl: testServerUrl, token: testToken, userId: 'user-1');
        await cachedRepo.getFavoriteBoxSets(limit: 50, offset: 50, serverUrl: testServerUrl, token: testToken, userId: 'user-1');

        verify(mockRepo.getFavoriteBoxSets(serverUrl: testServerUrl, token: testToken, userId: 'user-1')).called(1);
        verify(mockRepo.getFavoriteBoxSets(limit: 50, offset: 50, serverUrl: testServerUrl, token: testToken, userId: 'user-1')).called(1);
      });

      test('invalidateFavorites：清除合集收藏缓存后重新请求', () async {
        when(mockRepo.getFavoriteBoxSets(
          serverUrl: testServerUrl,
          token: testToken,
          userId: 'user-1',
        )).thenAnswer((_) async => testFavBoxSetsResult);

        await cachedRepo.getFavoriteBoxSets(serverUrl: testServerUrl, token: testToken, userId: 'user-1');

        cachedRepo.invalidateFavorites(
          serverUrl: testServerUrl,
          token: testToken,
          userId: 'user-1',
        );

        await cachedRepo.getFavoriteBoxSets(serverUrl: testServerUrl, token: testToken, userId: 'user-1');

        verify(mockRepo.getFavoriteBoxSets(
          serverUrl: testServerUrl,
          token: testToken,
          userId: 'user-1',
        )).called(2);
      });
    });

    group('peek 收藏三栏', () {
      group('peekFavoriteMovies', () {
        final testFavResult = FavoritesPageResult(
          movies: [MediaItem(id: 'fav-1', title: 'Fav Movie', type: 'Movie')],
          boxSets: [],
          people: [],
        );

        test('缓存未命中返回 null', () {
          final result = cachedRepo.peekFavoriteMovies(
            serverUrl: testServerUrl,
            token: testToken,
            userId: 'user-1',
          );

          expect(result, isNull);
        });

        test('缓存命中返回数据且不触发网络请求', () async {
          when(mockRepo.getFavoriteMovies(
            serverUrl: testServerUrl,
            token: testToken,
            userId: 'user-1',
          )).thenAnswer((_) async => testFavResult);

          await cachedRepo.getFavoriteMovies(
            serverUrl: testServerUrl,
            token: testToken,
            userId: 'user-1',
          );

          final result = cachedRepo.peekFavoriteMovies(
            serverUrl: testServerUrl,
            token: testToken,
            userId: 'user-1',
          );

          expect(result, isNotNull);
          expect(result!.movies.length, 1);
          expect(result.movies.first.id, 'fav-1');
          verify(mockRepo.getFavoriteMovies(
            serverUrl: testServerUrl,
            token: testToken,
            userId: 'user-1',
          )).called(1);
        });
      });

      group('peekFavoriteBoxSets', () {
        final testFavBoxSetsResult = FavoritesPageResult(
          movies: [],
          boxSets: [MediaItem(id: 'fav-boxset-1', title: 'Fav BoxSet', type: 'BoxSet')],
          people: [],
        );

        test('缓存未命中返回 null', () {
          final result = cachedRepo.peekFavoriteBoxSets(
            serverUrl: testServerUrl,
            token: testToken,
            userId: 'user-1',
          );

          expect(result, isNull);
        });

        test('缓存命中返回数据且不触发网络请求', () async {
          when(mockRepo.getFavoriteBoxSets(
            serverUrl: testServerUrl,
            token: testToken,
            userId: 'user-1',
          )).thenAnswer((_) async => testFavBoxSetsResult);

          await cachedRepo.getFavoriteBoxSets(
            serverUrl: testServerUrl,
            token: testToken,
            userId: 'user-1',
          );

          final result = cachedRepo.peekFavoriteBoxSets(
            serverUrl: testServerUrl,
            token: testToken,
            userId: 'user-1',
          );

          expect(result, isNotNull);
          expect(result!.boxSets.length, 1);
          expect(result.boxSets.first.id, 'fav-boxset-1');
          verify(mockRepo.getFavoriteBoxSets(
            serverUrl: testServerUrl,
            token: testToken,
            userId: 'user-1',
          )).called(1);
        });
      });

      group('peekFavoritePeople', () {
        final testFavPeopleResult = FavoritesPageResult(
          movies: [],
          boxSets: [],
          people: [MediaItem(id: 'fav-person-1', title: 'Fav Actor', type: 'Person')],
        );

        test('缓存未命中返回 null', () {
          final result = cachedRepo.peekFavoritePeople(
            serverUrl: testServerUrl,
            token: testToken,
            userId: 'user-1',
          );

          expect(result, isNull);
        });

        test('缓存命中返回数据且不触发网络请求', () async {
          when(mockRepo.getFavoritePeople(
            serverUrl: testServerUrl,
            token: testToken,
            userId: 'user-1',
          )).thenAnswer((_) async => testFavPeopleResult);

          await cachedRepo.getFavoritePeople(
            serverUrl: testServerUrl,
            token: testToken,
            userId: 'user-1',
          );

          final result = cachedRepo.peekFavoritePeople(
            serverUrl: testServerUrl,
            token: testToken,
            userId: 'user-1',
          );

          expect(result, isNotNull);
          expect(result!.people.length, 1);
          expect(result.people.first.id, 'fav-person-1');
          verify(mockRepo.getFavoritePeople(
            serverUrl: testServerUrl,
            token: testToken,
            userId: 'user-1',
          )).called(1);
        });
      });
    });

    group('getRecommendations', () {
      final testRecResponse = PaginatedResponse<MediaItem>(
        items: [MediaItem(id: 'rec-1', title: 'Recommended', type: 'Movie')],
        total: 1,
        offset: 0,
        limit: 20,
      );

      test('首次请求：转发到底层 Repository', () async {
        when(mockRepo.getRecommendations(
          serverUrl: testServerUrl,
          token: testToken,
        )).thenAnswer((_) async => testRecResponse);

        final result = await cachedRepo.getRecommendations(
          serverUrl: testServerUrl,
          token: testToken,
        );

        expect(result.items.length, 1);
        expect(result.items.first.id, 'rec-1');
        verify(mockRepo.getRecommendations(
          serverUrl: testServerUrl,
          token: testToken,
        )).called(1);
      });

      test('相同参数第二次请求：使用缓存', () async {
        when(mockRepo.getRecommendations(
          serverUrl: testServerUrl,
          token: testToken,
        )).thenAnswer((_) async => testRecResponse);

        await cachedRepo.getRecommendations(serverUrl: testServerUrl, token: testToken);
        final result = await cachedRepo.getRecommendations(serverUrl: testServerUrl, token: testToken);

        expect(result.items.length, 1);
        verify(mockRepo.getRecommendations(
          serverUrl: testServerUrl,
          token: testToken,
        )).called(1);
      });

      test('不同 libraryId：不命中缓存', () async {
        when(mockRepo.getRecommendations(
          libraryId: 'lib-1',
          serverUrl: testServerUrl,
          token: testToken,
        )).thenAnswer((_) async => testRecResponse);
        when(mockRepo.getRecommendations(
          libraryId: 'lib-2',
          serverUrl: testServerUrl,
          token: testToken,
        )).thenAnswer((_) async => testRecResponse);

        await cachedRepo.getRecommendations(libraryId: 'lib-1', serverUrl: testServerUrl, token: testToken);
        await cachedRepo.getRecommendations(libraryId: 'lib-2', serverUrl: testServerUrl, token: testToken);

        verify(mockRepo.getRecommendations(libraryId: 'lib-1', serverUrl: testServerUrl, token: testToken)).called(1);
        verify(mockRepo.getRecommendations(libraryId: 'lib-2', serverUrl: testServerUrl, token: testToken)).called(1);
      });

      test('不同 minCommunityRating：不命中缓存', () async {
        when(mockRepo.getRecommendations(
          minCommunityRating: 4.0,
          serverUrl: testServerUrl,
          token: testToken,
        )).thenAnswer((_) async => testRecResponse);
        when(mockRepo.getRecommendations(
          minCommunityRating: 6.0,
          serverUrl: testServerUrl,
          token: testToken,
        )).thenAnswer((_) async => testRecResponse);

        await cachedRepo.getRecommendations(minCommunityRating: 4.0, serverUrl: testServerUrl, token: testToken);
        await cachedRepo.getRecommendations(minCommunityRating: 6.0, serverUrl: testServerUrl, token: testToken);

        verify(mockRepo.getRecommendations(minCommunityRating: 4.0, serverUrl: testServerUrl, token: testToken)).called(1);
        verify(mockRepo.getRecommendations(minCommunityRating: 6.0, serverUrl: testServerUrl, token: testToken)).called(1);
      });
    });

    group('getSuggestions', () {
      final testSuggestions = <MediaItem>[
        MediaItem(id: 'sugg-1', title: 'Suggested', type: 'Movie'),
      ];

      test('首次请求：转发到底层 Repository', () async {
        when(mockRepo.getSuggestions(
          serverUrl: testServerUrl,
          token: testToken,
        )).thenAnswer((_) async => testSuggestions);

        final result = await cachedRepo.getSuggestions(
          serverUrl: testServerUrl,
          token: testToken,
        );

        expect(result.length, 1);
        expect(result.first.id, 'sugg-1');
        verify(mockRepo.getSuggestions(
          serverUrl: testServerUrl,
          token: testToken,
        )).called(1);
      });

      test('相同参数第二次请求：使用缓存', () async {
        when(mockRepo.getSuggestions(
          serverUrl: testServerUrl,
          token: testToken,
        )).thenAnswer((_) async => testSuggestions);

        await cachedRepo.getSuggestions(serverUrl: testServerUrl, token: testToken);
        final result = await cachedRepo.getSuggestions(serverUrl: testServerUrl, token: testToken);

        expect(result.length, 1);
        verify(mockRepo.getSuggestions(
          serverUrl: testServerUrl,
          token: testToken,
        )).called(1);
      });

      test('不同 limit：不命中缓存', () async {
        when(mockRepo.getSuggestions(
          limit: 20,
          serverUrl: testServerUrl,
          token: testToken,
        )).thenAnswer((_) async => testSuggestions);
        when(mockRepo.getSuggestions(
          limit: 50,
          serverUrl: testServerUrl,
          token: testToken,
        )).thenAnswer((_) async => testSuggestions);

        await cachedRepo.getSuggestions(limit: 20, serverUrl: testServerUrl, token: testToken);
        await cachedRepo.getSuggestions(limit: 50, serverUrl: testServerUrl, token: testToken);

        verify(mockRepo.getSuggestions(limit: 20, serverUrl: testServerUrl, token: testToken)).called(1);
        verify(mockRepo.getSuggestions(limit: 50, serverUrl: testServerUrl, token: testToken)).called(1);
      });
    });

    group('getWatchHistory', () {
      final testHistory = <MediaItem>[
        MediaItem(id: 'hist-1', title: 'Watched', type: 'Movie'),
      ];

      test('首次请求：转发到底层 Repository', () async {
        when(mockRepo.getWatchHistory(
          serverUrl: testServerUrl,
          token: testToken,
        )).thenAnswer((_) async => testHistory);

        final result = await cachedRepo.getWatchHistory(
          serverUrl: testServerUrl,
          token: testToken,
        );

        expect(result.length, 1);
        expect(result.first.id, 'hist-1');
        verify(mockRepo.getWatchHistory(
          serverUrl: testServerUrl,
          token: testToken,
        )).called(1);
      });

      test('相同参数第二次请求：使用缓存', () async {
        when(mockRepo.getWatchHistory(
          serverUrl: testServerUrl,
          token: testToken,
        )).thenAnswer((_) async => testHistory);

        await cachedRepo.getWatchHistory(serverUrl: testServerUrl, token: testToken);
        final result = await cachedRepo.getWatchHistory(serverUrl: testServerUrl, token: testToken);

        expect(result.length, 1);
        verify(mockRepo.getWatchHistory(
          serverUrl: testServerUrl,
          token: testToken,
        )).called(1);
      });

      test('不同 limit：不命中缓存', () async {
        when(mockRepo.getWatchHistory(
          limit: 50,
          serverUrl: testServerUrl,
          token: testToken,
        )).thenAnswer((_) async => testHistory);
        when(mockRepo.getWatchHistory(
          limit: 200,
          serverUrl: testServerUrl,
          token: testToken,
        )).thenAnswer((_) async => testHistory);

        await cachedRepo.getWatchHistory(limit: 50, serverUrl: testServerUrl, token: testToken);
        await cachedRepo.getWatchHistory(limit: 200, serverUrl: testServerUrl, token: testToken);

        verify(mockRepo.getWatchHistory(limit: 50, serverUrl: testServerUrl, token: testToken)).called(1);
        verify(mockRepo.getWatchHistory(limit: 200, serverUrl: testServerUrl, token: testToken)).called(1);
      });

      test('invalidateWatchHistory：清除观看历史缓存后重新请求', () async {
        when(mockRepo.getWatchHistory(
          serverUrl: testServerUrl,
          token: testToken,
        )).thenAnswer((_) async => testHistory);

        await cachedRepo.getWatchHistory(serverUrl: testServerUrl, token: testToken);

        cachedRepo.invalidateWatchHistory(serverUrl: testServerUrl);

        await cachedRepo.getWatchHistory(serverUrl: testServerUrl, token: testToken);

        verify(mockRepo.getWatchHistory(
          serverUrl: testServerUrl,
          token: testToken,
        )).called(2);
      });
    });

    group('getChildren', () {
      final testChildren = <MediaItem>[
        MediaItem(id: 'child-1', title: 'Child Item', type: 'Movie'),
      ];

      test('首次请求：转发到底层 Repository', () async {
        when(mockRepo.getChildren(
          'parent-1',
          serverUrl: testServerUrl,
          token: testToken,
        )).thenAnswer((_) async => testChildren);

        final result = await cachedRepo.getChildren(
          'parent-1',
          serverUrl: testServerUrl,
          token: testToken,
        );

        expect(result.length, 1);
        expect(result.first.id, 'child-1');
        verify(mockRepo.getChildren(
          'parent-1',
          serverUrl: testServerUrl,
          token: testToken,
        )).called(1);
      });

      test('相同参数第二次请求：使用缓存', () async {
        when(mockRepo.getChildren(
          'parent-1',
          serverUrl: testServerUrl,
          token: testToken,
        )).thenAnswer((_) async => testChildren);

        await cachedRepo.getChildren('parent-1', serverUrl: testServerUrl, token: testToken);
        final result = await cachedRepo.getChildren('parent-1', serverUrl: testServerUrl, token: testToken);

        expect(result.length, 1);
        verify(mockRepo.getChildren(
          'parent-1',
          serverUrl: testServerUrl,
          token: testToken,
        )).called(1);
      });

      test('不同 parentId：不命中缓存', () async {
        when(mockRepo.getChildren(
          'parent-1',
          serverUrl: testServerUrl,
          token: testToken,
        )).thenAnswer((_) async => testChildren);
        when(mockRepo.getChildren(
          'parent-2',
          serverUrl: testServerUrl,
          token: testToken,
        )).thenAnswer((_) async => testChildren);

        await cachedRepo.getChildren('parent-1', serverUrl: testServerUrl, token: testToken);
        await cachedRepo.getChildren('parent-2', serverUrl: testServerUrl, token: testToken);

        verify(mockRepo.getChildren('parent-1', serverUrl: testServerUrl, token: testToken)).called(1);
        verify(mockRepo.getChildren('parent-2', serverUrl: testServerUrl, token: testToken)).called(1);
      });

      test('不同 limit：不命中缓存', () async {
        when(mockRepo.getChildren(
          'parent-1',
          limit: 100,
          serverUrl: testServerUrl,
          token: testToken,
        )).thenAnswer((_) async => testChildren);
        when(mockRepo.getChildren(
          'parent-1',
          limit: 200,
          serverUrl: testServerUrl,
          token: testToken,
        )).thenAnswer((_) async => testChildren);

        await cachedRepo.getChildren('parent-1', limit: 100, serverUrl: testServerUrl, token: testToken);
        await cachedRepo.getChildren('parent-1', limit: 200, serverUrl: testServerUrl, token: testToken);

        verify(mockRepo.getChildren('parent-1', limit: 100, serverUrl: testServerUrl, token: testToken)).called(1);
        verify(mockRepo.getChildren('parent-1', limit: 200, serverUrl: testServerUrl, token: testToken)).called(1);
      });

      test('invalidateChildren：清除子项缓存后重新请求', () async {
        when(mockRepo.getChildren(
          'parent-1',
          serverUrl: testServerUrl,
          token: testToken,
        )).thenAnswer((_) async => testChildren);

        await cachedRepo.getChildren('parent-1', serverUrl: testServerUrl, token: testToken);

        cachedRepo.invalidateChildren(serverUrl: testServerUrl);

        await cachedRepo.getChildren('parent-1', serverUrl: testServerUrl, token: testToken);

        verify(mockRepo.getChildren(
          'parent-1',
          serverUrl: testServerUrl,
          token: testToken,
        )).called(2);
      });
    });

    group('缓存统计', () {
      test('stats 返回聚合统计信息', () async {
        when(mockRepo.getLibraryItems(
          testParams,
          serverUrl: testServerUrl,
          token: testToken,
        )).thenAnswer((_) async => testResponse);

        // 第一次：未命中
        await cachedRepo.getLibraryItems(testParams, serverUrl: testServerUrl, token: testToken);
        // 第二次：命中
        await cachedRepo.getLibraryItems(testParams, serverUrl: testServerUrl, token: testToken);
        // 第三次：命中
        await cachedRepo.getLibraryItems(testParams, serverUrl: testServerUrl, token: testToken);

        final stats = cachedRepo.stats;
        expect(stats.totalRequests, 3);
        expect(stats.hitCount, 2);
        expect(stats.missCount, 1);
        expect(stats.hitRate, closeTo(2 / 3, 0.001));
      });

      test('resetStats 重置所有统计', () async {
        when(mockRepo.getLibraryItems(
          testParams,
          serverUrl: testServerUrl,
          token: testToken,
        )).thenAnswer((_) async => testResponse);

        await cachedRepo.getLibraryItems(testParams, serverUrl: testServerUrl, token: testToken);
        await cachedRepo.getLibraryItems(testParams, serverUrl: testServerUrl, token: testToken);

        cachedRepo.resetStats();

        final stats = cachedRepo.stats;
        expect(stats.hitCount, 0);
        expect(stats.missCount, 0);
        expect(stats.totalRequests, 0);
      });
    });

    group('getGenres', () {
      final genres = [
        Library(id: 'g1', name: '动作', type: 'Genre'),
        Library(id: 'g2', name: '喜剧', type: 'Genre'),
      ];

      test('首次调用请求后端', () async {
        when(mockRepo.getGenres(
          serverUrl: testServerUrl,
          token: testToken,
        )).thenAnswer((_) async => genres);

        final result = await cachedRepo.getGenres(
          serverUrl: testServerUrl,
          token: testToken,
        );

        expect(result.length, 2);
        expect(result[0].name, '动作');
        verify(mockRepo.getGenres(
          serverUrl: testServerUrl,
          token: testToken,
        )).called(1);
      });

      test('二次调用命中缓存，不请求后端', () async {
        when(mockRepo.getGenres(
          serverUrl: testServerUrl,
          token: testToken,
        )).thenAnswer((_) async => genres);

        await cachedRepo.getGenres(serverUrl: testServerUrl, token: testToken);
        final result = await cachedRepo.getGenres(serverUrl: testServerUrl, token: testToken);

        expect(result.length, 2);
        verify(mockRepo.getGenres(
          serverUrl: testServerUrl,
          token: testToken,
        )).called(1);
      });

      test('不同 token 缓存隔离', () async {
        when(mockRepo.getGenres(
          serverUrl: testServerUrl,
          token: 'token-a',
        )).thenAnswer((_) async => [genres[0]]);
        when(mockRepo.getGenres(
          serverUrl: testServerUrl,
          token: 'token-b',
        )).thenAnswer((_) async => genres);

        await cachedRepo.getGenres(serverUrl: testServerUrl, token: 'token-a');
        await cachedRepo.getGenres(serverUrl: testServerUrl, token: 'token-b');

        verify(mockRepo.getGenres(serverUrl: testServerUrl, token: 'token-a')).called(1);
        verify(mockRepo.getGenres(serverUrl: testServerUrl, token: 'token-b')).called(1);
      });

      test('invalidateGenres 失效缓存', () async {
        when(mockRepo.getGenres(
          serverUrl: testServerUrl,
          token: testToken,
        )).thenAnswer((_) async => genres);

        await cachedRepo.getGenres(serverUrl: testServerUrl, token: testToken);
        cachedRepo.invalidateGenres(serverUrl: testServerUrl);
        await cachedRepo.getGenres(serverUrl: testServerUrl, token: testToken);

        verify(mockRepo.getGenres(
          serverUrl: testServerUrl,
          token: testToken,
        )).called(2);
      });
    });

    group('getItemsByGenre', () {
      final items = [
        MediaItem(id: 'm1', title: '电影1', type: 'Movie'),
        MediaItem(id: 'm2', title: '电影2', type: 'Movie'),
      ];
      final response = PaginatedResponse<MediaItem>(
        items: items,
        total: 2,
        offset: 0,
        limit: 30,
      );

      test('首次调用请求后端', () async {
        when(mockRepo.getItemsByGenre(
          '动作',
          serverUrl: testServerUrl,
          token: testToken,
        )).thenAnswer((_) async => response);

        final result = await cachedRepo.getItemsByGenre(
          '动作',
          serverUrl: testServerUrl,
          token: testToken,
        );

        expect(result.items.length, 2);
        verify(mockRepo.getItemsByGenre(
          '动作',
          serverUrl: testServerUrl,
          token: testToken,
        )).called(1);
      });

      test('二次调用命中缓存', () async {
        when(mockRepo.getItemsByGenre(
          '动作',
          serverUrl: testServerUrl,
          token: testToken,
        )).thenAnswer((_) async => response);

        await cachedRepo.getItemsByGenre('动作', serverUrl: testServerUrl, token: testToken);
        final result = await cachedRepo.getItemsByGenre('动作', serverUrl: testServerUrl, token: testToken);

        expect(result.items.length, 2);
        verify(mockRepo.getItemsByGenre(
          '动作',
          serverUrl: testServerUrl,
          token: testToken,
        )).called(1);
      });

      test('不同类型缓存隔离', () async {
        when(mockRepo.getItemsByGenre(
          '动作',
          serverUrl: testServerUrl,
          token: testToken,
        )).thenAnswer((_) async => response);
        when(mockRepo.getItemsByGenre(
          '喜剧',
          serverUrl: testServerUrl,
          token: testToken,
        )).thenAnswer((_) async => response);

        await cachedRepo.getItemsByGenre('动作', serverUrl: testServerUrl, token: testToken);
        await cachedRepo.getItemsByGenre('喜剧', serverUrl: testServerUrl, token: testToken);

        verify(mockRepo.getItemsByGenre('动作', serverUrl: testServerUrl, token: testToken)).called(1);
        verify(mockRepo.getItemsByGenre('喜剧', serverUrl: testServerUrl, token: testToken)).called(1);
      });

      test('分页参数缓存隔离', () async {
        when(mockRepo.getItemsByGenre(
          '动作',
          limit: 30,
          offset: 0,
          serverUrl: testServerUrl,
          token: testToken,
        )).thenAnswer((_) async => response);
        when(mockRepo.getItemsByGenre(
          '动作',
          limit: 30,
          offset: 30,
          serverUrl: testServerUrl,
          token: testToken,
        )).thenAnswer((_) async => response);

        await cachedRepo.getItemsByGenre('动作', limit: 30, offset: 0, serverUrl: testServerUrl, token: testToken);
        await cachedRepo.getItemsByGenre('动作', limit: 30, offset: 30, serverUrl: testServerUrl, token: testToken);

        verify(mockRepo.getItemsByGenre('动作', limit: 30, offset: 0, serverUrl: testServerUrl, token: testToken)).called(1);
        verify(mockRepo.getItemsByGenre('动作', limit: 30, offset: 30, serverUrl: testServerUrl, token: testToken)).called(1);
      });

      test('invalidateGenreItems 失效缓存', () async {
        when(mockRepo.getItemsByGenre(
          '动作',
          serverUrl: testServerUrl,
          token: testToken,
        )).thenAnswer((_) async => response);

        await cachedRepo.getItemsByGenre('动作', serverUrl: testServerUrl, token: testToken);
        cachedRepo.invalidateGenreItems(serverUrl: testServerUrl);
        await cachedRepo.getItemsByGenre('动作', serverUrl: testServerUrl, token: testToken);

        verify(mockRepo.getItemsByGenre(
          '动作',
          serverUrl: testServerUrl,
          token: testToken,
        )).called(2);
      });
    });

    group('getStudios', () {
      final studios = [
        Library(id: 's1', name: '迪士尼', type: 'Studio'),
        Library(id: 's2', name: '华纳', type: 'Studio'),
      ];

      test('首次调用请求后端', () async {
        when(mockRepo.getStudios(
          serverUrl: testServerUrl,
          token: testToken,
        )).thenAnswer((_) async => studios);

        final result = await cachedRepo.getStudios(
          serverUrl: testServerUrl,
          token: testToken,
        );

        expect(result.length, 2);
        expect(result[0].name, '迪士尼');
        verify(mockRepo.getStudios(
          serverUrl: testServerUrl,
          token: testToken,
        )).called(1);
      });

      test('二次调用命中缓存', () async {
        when(mockRepo.getStudios(
          serverUrl: testServerUrl,
          token: testToken,
        )).thenAnswer((_) async => studios);

        await cachedRepo.getStudios(serverUrl: testServerUrl, token: testToken);
        final result = await cachedRepo.getStudios(serverUrl: testServerUrl, token: testToken);

        expect(result.length, 2);
        verify(mockRepo.getStudios(
          serverUrl: testServerUrl,
          token: testToken,
        )).called(1);
      });

      test('invalidateStudios 失效缓存', () async {
        when(mockRepo.getStudios(
          serverUrl: testServerUrl,
          token: testToken,
        )).thenAnswer((_) async => studios);

        await cachedRepo.getStudios(serverUrl: testServerUrl, token: testToken);
        cachedRepo.invalidateStudios(serverUrl: testServerUrl);
        await cachedRepo.getStudios(serverUrl: testServerUrl, token: testToken);

        verify(mockRepo.getStudios(
          serverUrl: testServerUrl,
          token: testToken,
        )).called(2);
      });
    });

    group('getItemsByStudio', () {
      final items = [
        MediaItem(id: 'm1', title: '电影1', type: 'Movie'),
      ];
      final response = PaginatedResponse<MediaItem>(
        items: items,
        total: 1,
        offset: 0,
        limit: 30,
      );

      test('首次调用请求后端', () async {
        when(mockRepo.getItemsByStudio(
          '迪士尼',
          serverUrl: testServerUrl,
          token: testToken,
        )).thenAnswer((_) async => response);

        final result = await cachedRepo.getItemsByStudio(
          '迪士尼',
          serverUrl: testServerUrl,
          token: testToken,
        );

        expect(result.items.length, 1);
        verify(mockRepo.getItemsByStudio(
          '迪士尼',
          serverUrl: testServerUrl,
          token: testToken,
        )).called(1);
      });

      test('二次调用命中缓存', () async {
        when(mockRepo.getItemsByStudio(
          '迪士尼',
          serverUrl: testServerUrl,
          token: testToken,
        )).thenAnswer((_) async => response);

        await cachedRepo.getItemsByStudio('迪士尼', serverUrl: testServerUrl, token: testToken);
        final result = await cachedRepo.getItemsByStudio('迪士尼', serverUrl: testServerUrl, token: testToken);

        expect(result.items.length, 1);
        verify(mockRepo.getItemsByStudio(
          '迪士尼',
          serverUrl: testServerUrl,
          token: testToken,
        )).called(1);
      });

      test('不同工作室缓存隔离', () async {
        when(mockRepo.getItemsByStudio(
          '迪士尼',
          serverUrl: testServerUrl,
          token: testToken,
        )).thenAnswer((_) async => response);
        when(mockRepo.getItemsByStudio(
          '华纳',
          serverUrl: testServerUrl,
          token: testToken,
        )).thenAnswer((_) async => response);

        await cachedRepo.getItemsByStudio('迪士尼', serverUrl: testServerUrl, token: testToken);
        await cachedRepo.getItemsByStudio('华纳', serverUrl: testServerUrl, token: testToken);

        verify(mockRepo.getItemsByStudio('迪士尼', serverUrl: testServerUrl, token: testToken)).called(1);
        verify(mockRepo.getItemsByStudio('华纳', serverUrl: testServerUrl, token: testToken)).called(1);
      });

      test('invalidateStudioItems 失效缓存', () async {
        when(mockRepo.getItemsByStudio(
          '迪士尼',
          serverUrl: testServerUrl,
          token: testToken,
        )).thenAnswer((_) async => response);

        await cachedRepo.getItemsByStudio('迪士尼', serverUrl: testServerUrl, token: testToken);
        cachedRepo.invalidateStudioItems(serverUrl: testServerUrl);
        await cachedRepo.getItemsByStudio('迪士尼', serverUrl: testServerUrl, token: testToken);

        verify(mockRepo.getItemsByStudio(
          '迪士尼',
          serverUrl: testServerUrl,
          token: testToken,
        )).called(2);
      });
    });
  });
}
