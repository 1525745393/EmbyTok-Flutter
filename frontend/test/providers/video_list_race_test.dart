// VideoListNotifier 竞态条件测试
//
// 覆盖场景：
// 1. 快速连续 refresh - 只保留最后一次结果
// 2. 快速连续 loadMore - 不会重复加载同一页
// 3. dispose 后请求完成 - 不崩溃、不更新状态
// 4. refresh + loadMore 并发 - refresh 取消 loadMore 效果
// 5. isLoading 状态正确性 - 连续调用时不乱跳

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:embytok_flutter/models/models.dart';
import 'package:embytok_flutter/providers/app_preferences_providers.dart';
import 'package:embytok_flutter/providers/auth_provider.dart';
import 'package:embytok_flutter/providers/cache_providers.dart';
import 'package:embytok_flutter/providers/library_provider.dart';
import 'package:embytok_flutter/providers/video_list_provider.dart';
import 'package:embytok_flutter/providers/video_playback_controller.dart';
import 'package:embytok_flutter/repositories/media_repository.dart';
import 'package:embytok_flutter/utils/app_preferences.dart';

// ============================
// Mock MediaRepository
// ============================

/// 可控制延迟和完成时机的 Mock MediaRepository
/// 使用 Completer 手动控制请求完成，模拟网络延迟和竞态
class _MockMediaRepository implements MediaRepository {
  final List<_PendingRequest> _pendingRequests = [];

  int get pendingRequestCount => _pendingRequests.length;

  /// 获取所有 pending 的请求
  List<_PendingRequest> get pendingRequests => List.unmodifiable(_pendingRequests);

  /// 创建一个新的 pending 请求，返回 Completer 用于手动完成
  _PendingRequest _createPendingRequest(String type, Map<String, dynamic> params) {
    final request = _PendingRequest(type, params, Completer<dynamic>());
    _pendingRequests.add(request);
    return request;
  }

  /// 完成指定索引的请求
  void completeRequest(int index, dynamic result) {
    if (index < 0 || index >= _pendingRequests.length) {
      throw RangeError.index(index, _pendingRequests, 'index');
    }
    final req = _pendingRequests[index];
    if (!req.completer.isCompleted) {
      req.completer.complete(result);
    }
  }

  /// 完成所有 pending 请求
  void completeAll(dynamic Function(int index) resultBuilder) {
    for (int i = 0; i < _pendingRequests.length; i++) {
      final req = _pendingRequests[i];
      if (!req.completer.isCompleted) {
        req.completer.complete(resultBuilder(i));
      }
    }
  }

  /// 使指定索引的请求失败
  void completeWithError(int index, Object error) {
    if (index < 0 || index >= _pendingRequests.length) {
      throw RangeError.index(index, _pendingRequests, 'index');
    }
    final req = _pendingRequests[index];
    if (!req.completer.isCompleted) {
      req.completer.completeError(error);
    }
  }

  @override
  Future<PaginatedResponse<MediaItem>> getLibraryItems(
    MediaQueryParams params, {
    required String serverUrl,
    required String token,
    String? userId,
    CancelToken? cancelToken,
  }) async {
    final req = _createPendingRequest('getLibraryItems', {
      'params': params,
      'serverUrl': serverUrl,
      'token': token,
      'userId': userId,
    });

    cancelToken?.whenCancel.then((_) {
      if (!req.completer.isCompleted) {
        req.completer.completeError(
          DioException(
            requestOptions: RequestOptions(path: ''),
            type: DioExceptionType.cancel,
          ),
        );
      }
    });

    return await req.completer.future as PaginatedResponse<MediaItem>;
  }

  @override
  PaginatedResponse<MediaItem>? peekLibraryItems(
    MediaQueryParams params, {
    required String serverUrl,
    required String token,
    String? userId,
  }) => null;

  // 以下 peek* 方法为空实现：测试不依赖缓存读取路径，统一返回 null
  @override
  FavoritesPageResult? peekFavoriteMovies({
    int limit = 50,
    int offset = 0,
    required String serverUrl,
    required String token,
    String? userId,
  }) => null;

  @override
  FavoritesPageResult? peekFavoriteBoxSets({
    int limit = 50,
    int offset = 0,
    required String serverUrl,
    required String token,
    String? userId,
  }) => null;

  @override
  FavoritesPageResult? peekFavoritePeople({
    int limit = 50,
    int offset = 0,
    required String serverUrl,
    required String token,
    String? userId,
  }) => null;

  @override
  Future<MediaItem> getItemDetail(
    String itemId, {
    required String serverUrl,
    required String token,
    String? userId,
  }) async {
    final req = _createPendingRequest('getItemDetail', {
      'itemId': itemId,
      'serverUrl': serverUrl,
      'token': token,
    });
    return await req.completer.future as MediaItem;
  }

  @override
  Future<FavoritesPageResult> getFavoriteMovies({
    int limit = 50,
    int offset = 0,
    required String serverUrl,
    required String token,
    String? userId,
    CancelToken? cancelToken,
  }) async {
    final req = _createPendingRequest('getFavoriteMovies', {
      'limit': limit,
      'offset': offset,
      'serverUrl': serverUrl,
      'token': token,
    });

    cancelToken?.whenCancel.then((_) {
      if (!req.completer.isCompleted) {
        req.completer.completeError(
          DioException(
            requestOptions: RequestOptions(path: ''),
            type: DioExceptionType.cancel,
          ),
        );
      }
    });

    return await req.completer.future as FavoritesPageResult;
  }

  @override
  Future<FavoritesPageResult> getFavoriteBoxSets({
    int limit = 50,
    int offset = 0,
    required String serverUrl,
    required String token,
    String? userId,
  }) async {
    final req = _createPendingRequest('getFavoriteBoxSets', {
      'limit': limit,
      'offset': offset,
      'serverUrl': serverUrl,
      'token': token,
    });
    return await req.completer.future as FavoritesPageResult;
  }

  @override
  Future<PaginatedResponse<MediaItem>> getResumeItems({
    required String serverUrl,
    required String token,
    int limit = 50,
    int offset = 0,
    CancelToken? cancelToken,
  }) async {
    final req = _createPendingRequest('getResumeItems', {
      'limit': limit,
      'offset': offset,
      'serverUrl': serverUrl,
      'token': token,
    });

    cancelToken?.whenCancel.then((_) {
      if (!req.completer.isCompleted) {
        req.completer.completeError(
          DioException(
            requestOptions: RequestOptions(path: ''),
            type: DioExceptionType.cancel,
          ),
        );
      }
    });

    return await req.completer.future as PaginatedResponse<MediaItem>;
  }

  @override
  Future<List<Library>> getLibraries({
    required String serverUrl,
    required String token,
    String? userId,
  }) async {
    final req = _createPendingRequest('getLibraries', {
      'serverUrl': serverUrl,
      'token': token,
    });
    return await req.completer.future as List<Library>;
  }

  @override
  Future<PaginatedResponse<MediaItem>> getNextUp({
    required String serverUrl,
    required String token,
    int limit = 20,
    String? seriesId,
  }) async {
    final req = _createPendingRequest('getNextUp', {
      'limit': limit,
      'seriesId': seriesId,
      'serverUrl': serverUrl,
      'token': token,
    });
    return await req.completer.future as PaginatedResponse<MediaItem>;
  }

  @override
  Future<List<MediaItem>> getSeasons(
    String seriesId, {
    required String serverUrl,
    required String token,
  }) async {
    final req = _createPendingRequest('getSeasons', {
      'seriesId': seriesId,
      'serverUrl': serverUrl,
      'token': token,
    });
    return await req.completer.future as List<MediaItem>;
  }

  @override
  Future<PaginatedResponse<MediaItem>> getEpisodes(
    String seriesId, {
    String? seasonId,
    int limit = 100,
    int offset = 0,
    required String serverUrl,
    required String token,
  }) async {
    final req = _createPendingRequest('getEpisodes', {
      'seriesId': seriesId,
      'seasonId': seasonId,
      'limit': limit,
      'offset': offset,
      'serverUrl': serverUrl,
      'token': token,
    });
    return await req.completer.future as PaginatedResponse<MediaItem>;
  }

  @override
  Future<List<MediaItem>> getSimilarItems(
    String itemId, {
    int limit = 12,
    required String serverUrl,
    required String token,
  }) async {
    final req = _createPendingRequest('getSimilarItems', {
      'itemId': itemId,
      'limit': limit,
      'serverUrl': serverUrl,
      'token': token,
    });
    return await req.completer.future as List<MediaItem>;
  }

  @override
  Future<PaginatedResponse<Person>> getPeople({
    int limit = 50,
    int startIndex = 0,
    List<String>? personTypes,
    String? searchTerm,
    required String serverUrl,
    required String token,
  }) async {
    final req = _createPendingRequest('getPeople', {
      'limit': limit,
      'startIndex': startIndex,
      'serverUrl': serverUrl,
      'token': token,
    });
    return await req.completer.future as PaginatedResponse<Person>;
  }

  @override
  Future<MediaItem?> getPersonDetail(
    String personId, {
    required String serverUrl,
    required String token,
    String? userId,
  }) async {
    final req = _createPendingRequest('getPersonDetail', {
      'personId': personId,
      'serverUrl': serverUrl,
      'token': token,
    });
    return await req.completer.future as MediaItem?;
  }

  @override
  Future<PaginatedResponse<MediaItem>> getPersonItems(
    String personId, {
    int limit = 30,
    int offset = 0,
    required String serverUrl,
    required String token,
  }) async {
    final req = _createPendingRequest('getPersonItems', {
      'personId': personId,
      'limit': limit,
      'offset': offset,
      'serverUrl': serverUrl,
      'token': token,
    });
    return await req.completer.future as PaginatedResponse<MediaItem>;
  }

  @override
  Future<FavoritesPageResult> getFavoritePeople({
    int limit = 50,
    int offset = 0,
    required String serverUrl,
    required String token,
    String? userId,
  }) async {
    final req = _createPendingRequest('getFavoritePeople', {
      'limit': limit,
      'offset': offset,
      'serverUrl': serverUrl,
      'token': token,
    });
    return await req.completer.future as FavoritesPageResult;
  }

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
  }) async {
    final req = _createPendingRequest('getRecommendations', {
      'limit': limit,
      'offset': offset,
      'libraryId': libraryId,
      'serverUrl': serverUrl,
      'token': token,
    });
    return await req.completer.future as PaginatedResponse<MediaItem>;
  }

  @override
  Future<List<MediaItem>> getSuggestions({
    int limit = 20,
    String? userId,
    required String serverUrl,
    required String token,
  }) async {
    final req = _createPendingRequest('getSuggestions', {
      'limit': limit,
      'serverUrl': serverUrl,
      'token': token,
    });
    return await req.completer.future as List<MediaItem>;
  }

  @override
  Future<List<MediaItem>> getWatchHistory({
    int limit = 50,
    String? userId,
    required String serverUrl,
    required String token,
  }) async {
    final req = _createPendingRequest('getWatchHistory', {
      'limit': limit,
      'serverUrl': serverUrl,
      'token': token,
    });
    return await req.completer.future as List<MediaItem>;
  }

  @override
  Future<List<MediaItem>> getChildren(
    String parentId, {
    int limit = 100,
    int? offset,
    required String serverUrl,
    required String token,
  }) async {
    final req = _createPendingRequest('getChildren', {
      'parentId': parentId,
    });
    return await req.completer.future as List<MediaItem>;
  }

  @override
  Future<List<Library>> getGenres({
    int limit = 100,
    required String serverUrl,
    required String token,
  }) async {
    final req = _createPendingRequest('getGenres', {
      'serverUrl': serverUrl,
      'token': token,
    });
    return await req.completer.future as List<Library>;
  }

  @override
  Future<PaginatedResponse<MediaItem>> getItemsByGenre(
    String genre, {
    int limit = 30,
    int offset = 0,
    required String serverUrl,
    required String token,
  }) async {
    final req = _createPendingRequest('getItemsByGenre', {
      'genre': genre,
      'limit': limit,
      'offset': offset,
      'serverUrl': serverUrl,
      'token': token,
    });
    return await req.completer.future as PaginatedResponse<MediaItem>;
  }

  @override
  Future<List<Library>> getStudios({
    int limit = 100,
    required String serverUrl,
    required String token,
  }) async {
    final req = _createPendingRequest('getStudios', {
      'serverUrl': serverUrl,
      'token': token,
    });
    return await req.completer.future as List<Library>;
  }

  @override
  Future<PaginatedResponse<MediaItem>> getItemsByStudio(
    String studio, {
    int limit = 30,
    int offset = 0,
    required String serverUrl,
    required String token,
  }) async {
    final req = _createPendingRequest('getItemsByStudio', {
      'studio': studio,
      'limit': limit,
      'offset': offset,
      'serverUrl': serverUrl,
      'token': token,
    });
    return await req.completer.future as PaginatedResponse<MediaItem>;
  }
}

/// 待处理请求封装
class _PendingRequest {
  final String type;
  final Map<String, dynamic> params;
  final Completer<dynamic> completer;

  _PendingRequest(this.type, this.params, this.completer);

  MediaQueryParams get queryParams => params['params'] as MediaQueryParams;
}

// ============================
// 测试辅助函数
// ============================

/// 创建测试用 MediaItem
MediaItem _testItem(String id, {String title = ''}) =>
    MediaItem(id: id, title: title.isEmpty ? '视频-$id' : title, type: 'Movie');

/// 创建分页响应
PaginatedResponse<MediaItem> _paginatedResponse(
  List<MediaItem> items, {
  required int total,
  int offset = 0,
  int limit = 20,
}) =>
    PaginatedResponse<MediaItem>(
      items: items,
      total: total,
      offset: offset,
      limit: limit,
    );

/// 测试用 AuthNotifier：直接返回预设状态
///
/// 继承 AuthNotifier 以满足 authProvider 的类型约束，
/// 调用 super(ref) 后再用预设状态覆盖 state，避免触发 _loadFromStorage 的副作用影响断言。
class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(Ref ref, AuthState initialState) : super(ref) {
    state = initialState;
  }
}

/// 测试用 SelectedLibraryIdsNotifier：直接返回预设状态
///
/// 继承 SelectedLibraryNotifier 以满足 selectedLibraryIdsProvider 的类型约束。
class _TestSelectedLibraryIdsNotifier extends SelectedLibraryNotifier {
  _TestSelectedLibraryIdsNotifier(Ref ref, List<String> initialState)
      : super(ref) {
    state = initialState;
  }

  @override
  void setLibraries(List<String> ids) => state = ids;
}

/// 测试用 FeedTypeNotifier
///
/// 继承 FeedTypeNotifier 以满足 feedTypeProvider 的类型约束。
class _TestFeedTypeNotifier extends FeedTypeNotifier {
  _TestFeedTypeNotifier(FeedType initialState) : super() {
    state = initialState;
  }
}

/// 测试用 ExcludePlayedNotifier
class _TestExcludePlayedNotifier extends FeedExcludePlayedNotifier {
  _TestExcludePlayedNotifier(bool initialState) : super() {
    state = initialState;
  }
}

/// 测试用 ViewModeNotifier
class _TestViewModeNotifier extends ViewModeNotifier {
  _TestViewModeNotifier(ViewMode initialState) : super() {
    state = initialState;
  }
}

// ============================
// 测试主体
// ============================

void main() {
  // 初始化 Flutter binding，供 SharedPreferences 等插件使用
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoListNotifier 竞态测试', () {
    late _MockMediaRepository mockRepo;
    late ProviderContainer container;

    AuthState _testAuthState() => AuthState(
          isAuthenticated: true,
          user: User(id: 'user-1', name: 'test', accessToken: 'test-token'),
          embyServerUrl: 'http://emby.example.com',
          token: 'test-token',
        );

    setUp(() {
      mockRepo = _MockMediaRepository();
    });

    tearDown(() {
      container.dispose();
    });

    /// 创建带 mock 的 ProviderContainer
    ProviderContainer _createContainer({
      List<String> libraryIds = const ['lib-1'],
      FeedType feedType = FeedType.latest,
      bool excludePlayed = false,
      ViewMode viewMode = ViewMode.feed,
    }) {
      return ProviderContainer(
        overrides: [
          mediaRepositoryProvider.overrideWithValue(mockRepo),
          authProvider.overrideWith(
            (ref) => _TestAuthNotifier(ref, _testAuthState()),
          ),
          selectedLibraryIdsProvider.overrideWith(
            (ref) => _TestSelectedLibraryIdsNotifier(ref, libraryIds),
          ),
          feedTypeProvider.overrideWith(
            (ref) => _TestFeedTypeNotifier(feedType),
          ),
          feedExcludePlayedProvider.overrideWith(
            (ref) => _TestExcludePlayedNotifier(excludePlayed),
          ),
          viewModeProvider.overrideWith(
            (ref) => _TestViewModeNotifier(viewMode),
          ),
          videoListProvider.overrideWith(
            (ref) => VideoListNotifier(ref, repo: mockRepo),
          ),
        ],
      );
    }

    // ========================================
    // 3.1 快速连续 refresh 测试
    // ========================================

    group('快速连续 refresh', () {
      test('连续调用 refresh 只保留最后一次结果，不会被旧请求覆盖', () async {
        container = _createContainer();

        final notifier = container.read(videoListProvider.notifier);

        final refreshFuture1 = notifier.refresh();
        await Future<void>.delayed(Duration.zero);

        expect(mockRepo.pendingRequestCount, greaterThanOrEqualTo(1));

        final refreshFuture2 = notifier.refresh();
        await Future<void>.delayed(Duration.zero);

        expect(mockRepo.pendingRequestCount, greaterThanOrEqualTo(2));

        final firstPageItems = List.generate(5, (i) => _testItem('first-${i + 1}'));
        final secondPageItems = List.generate(5, (i) => _testItem('second-${i + 1}'));

        final secondReqIndex = mockRepo.pendingRequestCount - 1;
        mockRepo.completeRequest(
          secondReqIndex,
          _paginatedResponse(secondPageItems, total: 100),
        );

        await Future<void>.delayed(Duration.zero);

        mockRepo.completeRequest(
          0,
          _paginatedResponse(firstPageItems, total: 100),
        );

        await Future.wait([refreshFuture1, refreshFuture2]);

        final state = container.read(videoListProvider);
        expect(state.items.length, 5);
        expect(state.items[0].id, startsWith('second-'));
        expect(state.isLoading, false);
      });

      test('连续调用 refresh 只更新状态一次，最终数据正确', () async {
        container = _createContainer();

        final notifier = container.read(videoListProvider.notifier);

        final futures = [
          notifier.refresh(),
          notifier.refresh(),
          notifier.refresh(),
        ];

        await Future<void>.delayed(Duration.zero);

        expect(mockRepo.pendingRequestCount, greaterThanOrEqualTo(3));

        final page3Items = List.generate(3, (i) => _testItem('third-${i + 1}'));
        final page2Items = List.generate(3, (i) => _testItem('second-${i + 1}'));
        final page1Items = List.generate(3, (i) => _testItem('first-${i + 1}'));

        for (int i = mockRepo.pendingRequestCount - 1; i >= 0; i--) {
          final items = i == mockRepo.pendingRequestCount - 1
              ? page3Items
              : i == 1
                  ? page2Items
                  : page1Items;
          mockRepo.completeRequest(i, _paginatedResponse(items, total: 50));
        }

        await Future.wait(futures);

        final state = container.read(videoListProvider);
        expect(state.items.length, 3);
        expect(state.items.every((item) => item.id.startsWith('third-')), isTrue);
        expect(state.isLoading, false);
      });

      test('快速连续 refresh 期间 isLoading 始终为 true', () async {
        container = _createContainer();

        final notifier = container.read(videoListProvider.notifier);

        notifier.refresh();
        await Future<void>.delayed(Duration.zero);
        expect(container.read(videoListProvider).isLoading, true);

        notifier.refresh();
        await Future<void>.delayed(Duration.zero);
        expect(container.read(videoListProvider).isLoading, true);

        notifier.refresh();
        await Future<void>.delayed(Duration.zero);
        expect(container.read(videoListProvider).isLoading, true);

        for (int i = 0; i < mockRepo.pendingRequestCount; i++) {
          mockRepo.completeRequest(
            i,
            _paginatedResponse([_testItem('item-$i')], total: 10),
          );
        }

        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(container.read(videoListProvider).isLoading, false);
      });
    });

    // ========================================
    // 3.2 快速连续 loadMore 测试
    // ========================================

    group('快速连续 loadMore', () {
      test('快速连续调用 loadMore 不会重复加载同一页', () async {
        container = _createContainer();

        final notifier = container.read(videoListProvider.notifier);

        final refreshFuture = notifier.refresh();
        await Future<void>.delayed(Duration.zero);

        expect(mockRepo.pendingRequestCount, greaterThanOrEqualTo(1));
        mockRepo.completeRequest(
          0,
          _paginatedResponse(
            List.generate(5, (i) => _testItem('page1-${i + 1}')),
            total: 20,
          ),
        );
        await refreshFuture;

        var state = container.read(videoListProvider);
        expect(state.items.length, 5);
        expect(state.hasMore, true);
        expect(state.isLoading, false);

        final loadMoreFuture1 = notifier.loadMore();
        final loadMoreFuture2 = notifier.loadMore();

        await Future<void>.delayed(Duration.zero);

        final loadMoreRequests = mockRepo.pendingRequests
            .where((r) => r.type == 'getLibraryItems')
            .skip(1)
            .toList();

        expect(loadMoreRequests.length, 1);

        final lastReqIndex = mockRepo.pendingRequestCount - 1;
        mockRepo.completeRequest(
          lastReqIndex,
          _paginatedResponse(
            List.generate(5, (i) => _testItem('page2-${i + 1}')),
            total: 20,
          ),
        );

        await Future.wait([loadMoreFuture1, loadMoreFuture2]);

        state = container.read(videoListProvider);
        expect(state.items.length, 10);
        expect(state.items.first.id, 'page1-1');
        expect(state.items.last.id, 'page2-5');
        expect(state.isLoading, false);
      });

      test('loadMore 数据按顺序追加', () async {
        container = _createContainer();

        final notifier = container.read(videoListProvider.notifier);

        final refreshFuture = notifier.refresh();
        await Future<void>.delayed(Duration.zero);
        mockRepo.completeRequest(
          0,
          _paginatedResponse(
            [_testItem('a'), _testItem('b')],
            total: 6,
          ),
        );
        await refreshFuture;

        var state = container.read(videoListProvider);
        expect(state.items.map((e) => e.id).toList(), ['a', 'b']);

        final loadMore1 = notifier.loadMore();
        await Future<void>.delayed(Duration.zero);
        mockRepo.completeRequest(
          mockRepo.pendingRequestCount - 1,
          _paginatedResponse(
            [_testItem('c'), _testItem('d')],
            total: 6,
          ),
        );
        await loadMore1;

        state = container.read(videoListProvider);
        expect(state.items.map((e) => e.id).toList(), ['a', 'b', 'c', 'd']);

        final loadMore2 = notifier.loadMore();
        await Future<void>.delayed(Duration.zero);
        mockRepo.completeRequest(
          mockRepo.pendingRequestCount - 1,
          _paginatedResponse(
            [_testItem('e'), _testItem('f')],
            total: 6,
          ),
        );
        await loadMore2;

        state = container.read(videoListProvider);
        expect(state.items.map((e) => e.id).toList(), ['a', 'b', 'c', 'd', 'e', 'f']);
      });

      test('所有页加载完后不再请求（hasMore=false 时 loadMore 直接返回）', () async {
        container = _createContainer();

        final notifier = container.read(videoListProvider.notifier);

        final refreshFuture = notifier.refresh();
        await Future<void>.delayed(Duration.zero);
        mockRepo.completeRequest(
          0,
          _paginatedResponse(
            List.generate(5, (i) => _testItem('item-${i + 1}')),
            total: 5,
          ),
        );
        await refreshFuture;

        var state = container.read(videoListProvider);
        expect(state.hasMore, false);
        expect(state.items.length, 5);

        final requestCountBefore = mockRepo.pendingRequestCount;

        await notifier.loadMore();

        expect(mockRepo.pendingRequestCount, requestCountBefore);

        state = container.read(videoListProvider);
        expect(state.items.length, 5);
        expect(state.hasMore, false);
      });
    });

    // ========================================
    // 3.3 dispose 后请求完成不崩溃
    // ========================================

    group('dispose 竞态', () {
      test('dispose 后请求完成不抛出异常', () async {
        container = _createContainer();

        final notifier = container.read(videoListProvider.notifier);

        final refreshFuture = notifier.refresh();
        await Future<void>.delayed(Duration.zero);

        expect(mockRepo.pendingRequestCount, greaterThanOrEqualTo(1));

        container.dispose();

        expect(
          () => mockRepo.completeRequest(
            0,
            _paginatedResponse([_testItem('item-1')], total: 10),
          ),
          returnsNormally,
        );

        expect(refreshFuture, completes);
      });

      test('dispose 后 loadMore 请求完成不崩溃', () async {
        container = _createContainer();

        final notifier = container.read(videoListProvider.notifier);

        final refreshFuture = notifier.refresh();
        await Future<void>.delayed(Duration.zero);
        mockRepo.completeRequest(
          0,
          _paginatedResponse(
            List.generate(3, (i) => _testItem('item-${i + 1}')),
            total: 10,
          ),
        );
        await refreshFuture;

        final loadMoreFuture = notifier.loadMore();
        await Future<void>.delayed(Duration.zero);

        expect(mockRepo.pendingRequestCount, greaterThanOrEqualTo(2));

        container.dispose();

        expect(
          () => mockRepo.completeRequest(
            mockRepo.pendingRequestCount - 1,
            _paginatedResponse(
              List.generate(3, (i) => _testItem('more-${i + 1}')),
              total: 10,
            ),
          ),
          returnsNormally,
        );

        expect(loadMoreFuture, completes);
      });
    });

    // ========================================
    // 3.4 refresh 和 loadMore 并发测试
    // ========================================

    group('refresh 与 loadMore 并发', () {
      test('loadMore 进行中调用 refresh，最终状态是 refresh 的结果', () async {
        container = _createContainer();

        final notifier = container.read(videoListProvider.notifier);

        final refreshFuture1 = notifier.refresh();
        await Future<void>.delayed(Duration.zero);
        mockRepo.completeRequest(
          0,
          _paginatedResponse(
            List.generate(3, (i) => _testItem('initial-${i + 1}')),
            total: 20,
          ),
        );
        await refreshFuture1;

        var state = container.read(videoListProvider);
        expect(state.items.length, 3);
        expect(state.hasMore, true);

        final loadMoreFuture = notifier.loadMore();
        await Future<void>.delayed(Duration.zero);

        expect(mockRepo.pendingRequestCount, greaterThanOrEqualTo(2));

        final refreshFuture2 = notifier.refresh();
        await Future<void>.delayed(Duration.zero);

        expect(mockRepo.pendingRequestCount, greaterThanOrEqualTo(3));

        final refreshItems = List.generate(5, (i) => _testItem('refreshed-${i + 1}'));
        final lastReqIndex = mockRepo.pendingRequestCount - 1;
        mockRepo.completeRequest(
          lastReqIndex,
          _paginatedResponse(refreshItems, total: 50),
        );

        await Future<void>.delayed(Duration.zero);

        mockRepo.completeRequest(
          1,
          _paginatedResponse(
            List.generate(3, (i) => _testItem('loadmore-${i + 1}')),
            total: 20,
          ),
        );

        await Future.wait([loadMoreFuture, refreshFuture2]);

        state = container.read(videoListProvider);
        expect(state.items.length, 5);
        expect(state.items.every((item) => item.id.startsWith('refreshed-')), isTrue);
        expect(state.isLoading, false);
      });

      test('refresh 会重置分页状态（offset、hasMore）', () async {
        container = _createContainer();

        final notifier = container.read(videoListProvider.notifier);

        final refresh1 = notifier.refresh();
        await Future<void>.delayed(Duration.zero);
        mockRepo.completeRequest(
          0,
          _paginatedResponse(
            List.generate(3, (i) => _testItem('p1-${i + 1}')),
            total: 9,
          ),
        );
        await refresh1;

        final loadMore1 = notifier.loadMore();
        await Future<void>.delayed(Duration.zero);
        mockRepo.completeRequest(
          mockRepo.pendingRequestCount - 1,
          _paginatedResponse(
            List.generate(3, (i) => _testItem('p2-${i + 1}')),
            total: 9,
          ),
        );
        await loadMore1;

        var state = container.read(videoListProvider);
        expect(state.items.length, 6);
        expect(state.offset, 6);
        expect(state.hasMore, true);

        final refresh2 = notifier.refresh();
        await Future<void>.delayed(Duration.zero);

        state = container.read(videoListProvider);
        expect(state.isLoading, true);
        expect(state.items, isEmpty);

        mockRepo.completeRequest(
          mockRepo.pendingRequestCount - 1,
          _paginatedResponse(
            List.generate(4, (i) => _testItem('new-${i + 1}')),
            total: 4,
          ),
        );
        await refresh2;

        state = container.read(videoListProvider);
        expect(state.items.length, 4);
        expect(state.offset, 4);
        expect(state.hasMore, false);
      });
    });

    // ========================================
    // 3.5 isLoading 状态正确性
    // ========================================

    group('isLoading 状态正确性', () {
      test('初始状态 isLoading 为 false', () {
        container = _createContainer();

        final state = container.read(videoListProvider);
        expect(state.isLoading, false);
      });

      test('调用 refresh 后 isLoading 变为 true', () async {
        container = _createContainer();

        final notifier = container.read(videoListProvider.notifier);

        final future = notifier.refresh();
        await Future<void>.delayed(Duration.zero);

        expect(container.read(videoListProvider).isLoading, true);

        mockRepo.completeRequest(
          0,
          _paginatedResponse([_testItem('item-1')], total: 10),
        );
        await future;

        expect(container.read(videoListProvider).isLoading, false);
      });

      test('请求完成后 isLoading 变为 false', () async {
        container = _createContainer();

        final notifier = container.read(videoListProvider.notifier);

        final future = notifier.refresh();
        await Future<void>.delayed(Duration.zero);
        expect(container.read(videoListProvider).isLoading, true);

        mockRepo.completeRequest(
          0,
          _paginatedResponse([], total: 0),
        );
        await future;

        expect(container.read(videoListProvider).isLoading, false);
      });

      test('loadMore 期间 isLoading 为 true', () async {
        container = _createContainer();

        final notifier = container.read(videoListProvider.notifier);

        final refreshFuture = notifier.refresh();
        await Future<void>.delayed(Duration.zero);
        mockRepo.completeRequest(
          0,
          _paginatedResponse(
            List.generate(3, (i) => _testItem('item-${i + 1}')),
            total: 10,
          ),
        );
        await refreshFuture;

        expect(container.read(videoListProvider).isLoading, false);

        final loadMoreFuture = notifier.loadMore();
        await Future<void>.delayed(Duration.zero);

        expect(container.read(videoListProvider).isLoading, true);

        mockRepo.completeRequest(
          mockRepo.pendingRequestCount - 1,
          _paginatedResponse(
            List.generate(3, (i) => _testItem('more-${i + 1}')),
            total: 10,
          ),
        );
        await loadMoreFuture;

        expect(container.read(videoListProvider).isLoading, false);
      });

      test('连续 refresh 时 isLoading 不会乱跳（始终为 true 直到最后完成）',
          () async {
        container = _createContainer();

        final notifier = container.read(videoListProvider.notifier);

        notifier.refresh();
        await Future<void>.delayed(Duration.zero);
        expect(container.read(videoListProvider).isLoading, true);

        notifier.refresh();
        await Future<void>.delayed(Duration.zero);
        expect(container.read(videoListProvider).isLoading, true);

        notifier.refresh();
        await Future<void>.delayed(Duration.zero);
        expect(container.read(videoListProvider).isLoading, true);

        for (int i = 0; i < mockRepo.pendingRequestCount; i++) {
          mockRepo.completeRequest(
            i,
            _paginatedResponse([_testItem('data-$i')], total: 10),
          );
        }

        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(container.read(videoListProvider).isLoading, false);
      });

      test('refresh 失败时 isLoading 也会变为 false', () async {
        container = _createContainer();

        final notifier = container.read(videoListProvider.notifier);

        final future = notifier.refresh();
        await Future<void>.delayed(Duration.zero);
        expect(container.read(videoListProvider).isLoading, true);

        mockRepo.completeWithError(0, Exception('网络错误'));
        await future;

        final state = container.read(videoListProvider);
        expect(state.isLoading, false);
        expect(state.error, isNotNull);
      });
    });
  });
}
