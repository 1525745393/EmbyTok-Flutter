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
  });
}
