// ActorsNotifier 状态机测试：验证演员列表加载、搜索防抖、筛选切换、关注乐观更新等
//
// 测试模式参考 favorites_provider_test.dart：
// - 使用 ProviderContainer + overrides
// - 使用 MockEmbytokService（来自 ../mocks/mock_services.dart）
// - 使用 _TestAuthNotifier 设置认证状态
// - 使用 mockito 的 when/verify

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:embytok_flutter/models/models.dart';
import 'package:embytok_flutter/providers/actors_provider.dart';
import 'package:embytok_flutter/providers/auth_provider.dart';
import 'package:embytok_flutter/providers/cache_providers.dart';
import 'package:embytok_flutter/providers/embytok_service_provider.dart';
import 'package:embytok_flutter/repositories/cached_media_repository.dart';
import 'package:embytok_flutter/services/embytok_service.dart';

import '../mocks/mock_services.dart';

/// CachedMediaRepository 的 Mock 实现
///
/// ActorsNotifier 内部通过 cachedMediaRepositoryProvider 访问
/// getFavoritePeople / getPeople（搜索场景），需要 stub 这些方法。
/// invalidateFavorites 是 CachedMediaRepository 自身方法（非 MediaRepository 接口），
/// toggleFavorite 中通过 cacheControllerProvider 调用，stub 为 no-op 即可。
///
/// 覆写 getPeople / getPersonItems：将 required String / int 参数声明为可空，
/// 以便测试中能用 anyNamed 匹配非空具名参数（mockito 5.x 在 Dart 3 严格 null
/// 检查下，anyNamed 返回 Null 无法直接赋值给非空参数）。
/// 模式参考 test/views/favorites_view_test.dart。
class _MockCachedMediaRepository extends Mock implements CachedMediaRepository {
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
  Future<PaginatedResponse<MediaItem>> getPersonItems(
    String personId, {
    int? limit,
    int? offset,
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
        returnValue: Future<PaginatedResponse<MediaItem>>.value(
          PaginatedResponse<MediaItem>(items: const [], total: 0, offset: 0, limit: 0),
        ),
        returnValueForMissingStub: Future<PaginatedResponse<MediaItem>>.value(
          PaginatedResponse<MediaItem>(items: const [], total: 0, offset: 0, limit: 0),
        ),
      ) as Future<PaginatedResponse<MediaItem>>;

  @override
  Future<FavoritesPageResult> getFavoritePeople({
    int? limit,
    int? offset,
    String? serverUrl,
    String? token,
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
        returnValue: Future.value(
            const FavoritesPageResult(items: <MediaItem>[], totalCount: 0)),
        returnValueForMissingStub: Future.value(
            const FavoritesPageResult(items: <MediaItem>[], totalCount: 0)),
      ) as Future<FavoritesPageResult>;

  @override
  void invalidateFavorites({
    String? serverUrl,
    String? token,
    String? userId,
  }) =>
      super.noSuchMethod(
        Invocation.method(#invalidateFavorites, [], {
          #serverUrl: serverUrl,
          #token: token,
          #userId: userId,
        }),
        returnValue: null,
        returnValueForMissingStub: null,
      );
}

void main() {
  group('ActorsState', () {
    test('初始状态正确', () {
      const state = ActorsState();
      expect(state.actors, isEmpty);
      expect(state.loading, false);
      expect(state.isLoadingMore, false);
      expect(state.error, isNull);
      expect(state.favoritedIds, isEmpty);
      expect(state.selectedPersonType, isNull);
      expect(state.searchQuery, '');
      expect(state.searchResults, isEmpty);
      expect(state.isSearching, false);
      expect(state.total, 0);
      expect(state.hasLoaded, false);
    });

    test('copyWith 正确更新字段', () {
      const original = ActorsState();
      final actors = [
        const Person(name: 'Actor 1', id: 'p1', type: 'Actor'),
        const Person(name: 'Actor 2', id: 'p2', type: 'Actor'),
      ];
      final favoritedIds = {'p1'};

      final updated = original.copyWith(
        actors: actors,
        loading: true,
        isLoadingMore: true,
        error: '加载失败',
        favoritedIds: favoritedIds,
        selectedPersonType: 'Director',
        searchQuery: '张',
        searchResults: actors,
        isSearching: true,
        total: 2,
        hasLoaded: true,
      );

      expect(updated.actors, actors);
      expect(updated.loading, true);
      expect(updated.isLoadingMore, true);
      expect(updated.error, '加载失败');
      expect(updated.favoritedIds, favoritedIds);
      expect(updated.selectedPersonType, 'Director');
      expect(updated.searchQuery, '张');
      expect(updated.searchResults, actors);
      expect(updated.isSearching, true);
      expect(updated.total, 2);
      expect(updated.hasLoaded, true);
    });

    test('copyWith clearError 清除错误', () {
      const state = ActorsState(error: '加载失败');
      final cleared = state.copyWith(clearError: true);
      expect(cleared.error, isNull);
    });

    test('copyWith clearSelectedType 清空类型', () {
      const state = ActorsState(selectedPersonType: 'Director');
      final cleared = state.copyWith(clearSelectedType: true);
      expect(cleared.selectedPersonType, isNull);
    });
  });

  group('ActorsNotifier', () {
    late MockEmbytokService mockService;
    late _MockCachedMediaRepository mockCachedRepo;
    late ProviderContainer container;
    late AuthState testAuthState;

    setUp(() {
      mockService = MockEmbytokService();
      mockCachedRepo = _MockCachedMediaRepository();
      testAuthState = AuthState(
        isAuthenticated: true,
        user: User(id: 'user-1', name: 'test', accessToken: 'test-token'),
        embyServerUrl: 'http://emby.example.com',
        token: 'test-token',
      );

      // invalidateFavorites 在 toggleFavorite 中被调用，
      // 这里 stub 为 no-op 避免触发 MissingStubError（虽然有 try-catch 兜底）
      when(mockCachedRepo.invalidateFavorites(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        userId: anyNamed('userId'),
      )).thenReturn(null);
    });

    tearDown(() {
      container.dispose();
    });

    // 创建带认证状态的容器
    ProviderContainer createContainerWithAuth() {
      return ProviderContainer(
        overrides: [
          embytokServiceProvider.overrideWithValue(mockService),
          cachedMediaRepositoryProvider.overrideWithValue(mockCachedRepo),
          authProvider.overrideWith(
            (ref) => _TestAuthNotifier(ref, testAuthState),
          ),
          actorsProvider.overrideWith(
            (ref) => ActorsNotifier(ref),
          ),
        ],
      );
    }

    // 辅助：stub getPeople 返回单页数据（少于 pageSize 触发停止）
    void stubGetPeopleSinglePage(List<Person> items) {
      when(mockService.getPeople(
        limit: anyNamed('limit'),
        startIndex: anyNamed('startIndex'),
        personTypes: anyNamed('personTypes'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async => PaginatedResponse<Person>(
            items: items,
            total: items.length,
            offset: 0,
            limit: 50,
          ));
    }

    // 辅助：stub getFavoritePeople 返回空结果
    void stubGetFavoritePeopleEmpty() {
      when(mockCachedRepo.getFavoritePeople(
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        userId: anyNamed('userId'),
      )).thenAnswer((_) async =>
          const FavoritesPageResult(items: <MediaItem>[], totalCount: 0));
    }

    test('初始状态', () {
      container = createContainerWithAuth();
      final state = container.read(actorsProvider);
      expect(state.actors, isEmpty);
      expect(state.loading, false);
      expect(state.error, isNull);
      expect(state.hasLoaded, false);
    });

    test('loadActors 成功加载演员列表', () async {
      final actors = [
        const Person(name: '演员A', id: 'p1', type: 'Actor'),
        const Person(name: '演员B', id: 'p2', type: 'Actor'),
      ];
      stubGetPeopleSinglePage(actors);
      stubGetFavoritePeopleEmpty();

      container = createContainerWithAuth();
      final notifier = container.read(actorsProvider.notifier);

      await notifier.loadActors();
      // _loadFavoritesInBackground 是 fire-and-forget，等待微任务完成
      await Future.delayed(Duration.zero);

      final state = container.read(actorsProvider);
      expect(state.actors.length, 2);
      expect(state.actors.first.id, 'p1');
      expect(state.loading, false);
      expect(state.error, isNull);
      expect(state.hasLoaded, true);
      expect(state.total, 2);

      // 验证 getPeople 被调用一次（首批 < pageSize 即停止分页）
      verify(mockService.getPeople(
        limit: 50,
        startIndex: 0,
        personTypes: anyNamed('personTypes'),
        serverUrl: 'http://emby.example.com',
        token: 'test-token',
      )).called(1);
    });

    test('loadActors 失败时设置 error 状态', () async {
      when(mockService.getPeople(
        limit: anyNamed('limit'),
        startIndex: anyNamed('startIndex'),
        personTypes: anyNamed('personTypes'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenThrow(Exception('网络错误'));

      container = createContainerWithAuth();
      final notifier = container.read(actorsProvider.notifier);

      await notifier.loadActors();

      final state = container.read(actorsProvider);
      expect(state.loading, false);
      expect(state.error, '加载演员失败');
      expect(state.hasLoaded, false);
      expect(state.actors, isEmpty);
    });

    test('loadActors 已加载且非 forceRefresh 时不重复加载', () async {
      final actors = [
        const Person(name: '演员A', id: 'p1', type: 'Actor'),
      ];
      stubGetPeopleSinglePage(actors);
      stubGetFavoritePeopleEmpty();

      container = createContainerWithAuth();
      final notifier = container.read(actorsProvider.notifier);

      // 第一次加载
      await notifier.loadActors();
      expect(container.read(actorsProvider).hasLoaded, true);

      // 第二次加载（非 forceRefresh）：应直接 return，不调用 getPeople
      await notifier.loadActors();

      verify(mockService.getPeople(
        limit: 50,
        startIndex: 0,
        personTypes: anyNamed('personTypes'),
        serverUrl: 'http://emby.example.com',
        token: 'test-token',
      )).called(1);
    });

    test('searchActors 防抖 300ms 后触发搜索', () async {
      const query = '张';
      final results = [
        const Person(name: '张三', id: 'p1', type: 'Actor'),
      ];

      when(mockCachedRepo.getPeople(
        limit: anyNamed('limit'),
        startIndex: anyNamed('startIndex'),
        personTypes: anyNamed('personTypes'),
        searchTerm: query,
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async => PaginatedResponse<Person>(
            items: results,
            total: 1,
            offset: 0,
            limit: 50,
          ));

      container = createContainerWithAuth();
      final notifier = container.read(actorsProvider.notifier);

      // 触发搜索（防抖 300ms）
      notifier.searchActors(query);

      // 防抖未触发前，isSearching 应为 false（state 尚未变更）
      expect(container.read(actorsProvider).isSearching, false);

      // 等待 300ms 防抖 + 微任务
      await Future.delayed(const Duration(milliseconds: 400));

      final state = container.read(actorsProvider);
      expect(state.searchQuery, query);
      expect(state.isSearching, false);
      expect(state.searchResults.length, 1);
      expect(state.searchResults.first.name, '张三');

      verify(mockCachedRepo.getPeople(
        limit: anyNamed('limit'),
        startIndex: anyNamed('startIndex'),
        personTypes: anyNamed('personTypes'),
        searchTerm: query,
        serverUrl: 'http://emby.example.com',
        token: 'test-token',
      )).called(1);
    });

    test('searchActors 空查询清空搜索结果', () async {
      container = createContainerWithAuth();
      final notifier = container.read(actorsProvider.notifier);

      // 空查询：应立即清空搜索结果，不触发网络请求
      notifier.searchActors('');
      await Future.delayed(const Duration(milliseconds: 400));

      final state = container.read(actorsProvider);
      expect(state.searchQuery, '');
      expect(state.searchResults, isEmpty);
      expect(state.isSearching, false);

      verifyNever(mockCachedRepo.getPeople(
        limit: anyNamed('limit'),
        startIndex: anyNamed('startIndex'),
        personTypes: anyNamed('personTypes'),
        searchTerm: anyNamed('searchTerm'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      ));
    });

    test('setSelectedType 设置类型并触发重新加载', () async {
      final actors = [
        const Person(name: '导演A', id: 'p1', type: 'Director'),
      ];
      stubGetPeopleSinglePage(actors);
      stubGetFavoritePeopleEmpty();

      container = createContainerWithAuth();
      final notifier = container.read(actorsProvider.notifier);

      // 第一次加载
      await notifier.loadActors();
      expect(container.read(actorsProvider).hasLoaded, true);

      // 切换类型到 Director：setSelectedType 同步设置 state 并 fire-and-forget loadActors(forceRefresh: true)
      notifier.setSelectedType('Director');

      // 等待 fire-and-forget 的 loadActors 完成
      // mock 的 thenAnswer 立即返回 Future，微任务即可完成
      await Future.delayed(const Duration(milliseconds: 50));

      final state = container.read(actorsProvider);
      expect(state.selectedPersonType, 'Director');
      expect(state.hasLoaded, true);
      expect(state.loading, false);
      expect(state.actors.length, 1);

      // 应该被调用过 2 次（初始 + forceRefresh）
      verify(mockService.getPeople(
        limit: 50,
        startIndex: 0,
        personTypes: ['Director'],
        serverUrl: 'http://emby.example.com',
        token: 'test-token',
      )).called(1);
    });

    test('toggleFavorite 乐观更新关注状态', () async {
      stubGetPeopleSinglePage(const [
        Person(name: '演员A', id: 'p1', type: 'Actor'),
      ]);
      stubGetFavoritePeopleEmpty();

      when(mockService.toggleFavorite(
        itemId: anyNamed('itemId'),
        isFavorite: anyNamed('isFavorite'),
        userId: anyNamed('userId'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async {});

      container = createContainerWithAuth();
      final notifier = container.read(actorsProvider.notifier);

      await notifier.loadActors();
      await Future.delayed(Duration.zero);

      // 初始未关注
      expect(container.read(actorsProvider).favoritedIds.contains('p1'), false);

      // 切换关注
      const actor = Person(name: '演员A', id: 'p1', type: 'Actor');
      await notifier.toggleFavorite(actor);

      // 乐观更新后应已关注
      expect(container.read(actorsProvider).favoritedIds.contains('p1'), true);

      verify(mockService.toggleFavorite(
        itemId: 'p1',
        isFavorite: true,
        userId: 'user-1',
        serverUrl: 'http://emby.example.com',
        token: 'test-token',
      )).called(1);
    });

    test('toggleFavorite 失败时回滚关注状态', () async {
      stubGetPeopleSinglePage(const [
        Person(name: '演员A', id: 'p1', type: 'Actor'),
      ]);
      stubGetFavoritePeopleEmpty();

      when(mockService.toggleFavorite(
        itemId: anyNamed('itemId'),
        isFavorite: anyNamed('isFavorite'),
        userId: anyNamed('userId'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenThrow(Exception('网络错误'));

      container = createContainerWithAuth();
      final notifier = container.read(actorsProvider.notifier);

      await notifier.loadActors();
      await Future.delayed(Duration.zero);

      // 初始未关注
      expect(container.read(actorsProvider).favoritedIds.contains('p1'), false);

      // 尝试切换关注（会失败）
      const actor = Person(name: '演员A', id: 'p1', type: 'Actor');
      await notifier.toggleFavorite(actor);

      // 失败回滚：应仍为未关注
      expect(container.read(actorsProvider).favoritedIds.contains('p1'), false);
    });

    test('toggleFavorite 无 ID 的演员不操作', () async {
      container = createContainerWithAuth();
      final notifier = container.read(actorsProvider.notifier);

      // id 为 null 的 Person
      const actor = Person(name: '无ID演员', type: 'Actor');
      await notifier.toggleFavorite(actor);

      // 不应调用 toggleFavorite
      verifyNever(mockService.toggleFavorite(
        itemId: anyNamed('itemId'),
        isFavorite: anyNamed('isFavorite'),
        userId: anyNamed('userId'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      ));

      // favoritedIds 应保持空
      expect(container.read(actorsProvider).favoritedIds, isEmpty);
    });
  });
}

// 测试用 AuthNotifier：继承 AuthNotifier，在构造函数中直接设置预设状态
// 注意：AuthNotifier 构造函数会调用 _loadFromStorage()（异步），
// 但 _TestAuthNotifier 在构造函数中同步设置 state = initialState，
// 测试环境中 _loadFromStorage 会失败但不会崩溃（有 try-catch），不会覆盖预设状态。
class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(Ref ref, AuthState initialState) : super(ref) {
    state = initialState;
  }
}
