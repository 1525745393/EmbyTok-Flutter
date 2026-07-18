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
    required String serverUrl,
    required String token,
    String? userId,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getFavoriteMovies, [], {
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
  });
}
