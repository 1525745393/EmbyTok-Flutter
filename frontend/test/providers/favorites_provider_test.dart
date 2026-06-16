// FavoritesNotifier 测试：验证收藏列表加载、切换收藏状态
// 设计：TestAuthNotifier 直接设置 state 跳过 _loadFromStorage，mock EmbytokService 返回测试数据

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:embbytok_flutter/models/models.dart';
import 'package:embbytok_flutter/providers/auth_provider.dart';
import 'package:embbytok_flutter/providers/favorites_provider.dart';
import 'package:embbytok_flutter/services/embbytok_service.dart';

import '../mocks/mock_services.dart';

// 测试用 AuthNotifier：在构造函数中直接设置状态，避免 _loadFromStorage 的副作用
class TestAuthNotifier extends AuthNotifier {
  TestAuthNotifier(AuthState initialState, {EmbytokService? service})
      : super(service: service) {
    // 直接设置 state，覆盖 _loadFromStorage 的结果
    state = initialState;
  }
}

void main() {
  late MockEmbytokService mockService;

  setUp(() {
    // 每个测试从干净的 SharedPreferences 状态开始
    SharedPreferences.setMockInitialValues(<String, Object>{});
    mockService = MockEmbytokService();
  });

  group('FavoritesState', () {
    test('初始状态正确（空列表、isLoading=false、isFavorite=空 set）', () {
      const state = FavoritesState();
      expect(state.movies, isEmpty);
      expect(state.boxSets, isEmpty);
      expect(state.people, isEmpty);
      expect(state.isLoading, false);
      expect(state.error, isNull);
      expect(state.favoriteIds, isEmpty);
    });

    test('copyWith 正确更新字段', () {
      const original = FavoritesState();
      final movies = <MediaItem>[
        MediaItem(id: '1', title: 'Favorite 1', type: 'Movie'),
        MediaItem(id: '2', title: 'Favorite 2', type: 'Movie'),
      ];
      final favoriteIds = <String>{'1', '2'};

      final updated = original.copyWith(
        movies: movies,
        isLoading: true,
        error: '加载失败',
        favoriteIds: favoriteIds,
      );

      expect(updated.movies, movies);
      expect(updated.isLoading, true);
      expect(updated.error, '加载失败');
      expect(updated.favoriteIds, favoriteIds);
    });
  });

  group('FavoritesNotifier', () {
    // 创建带测试认证状态的 ProviderContainer
    ProviderContainer createContainerWithAuth(AuthState authState) {
      return ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) => TestAuthNotifier(authState)),
          favoritesProvider.overrideWith(
            (ref) => FavoritesNotifier(ref, service: mockService),
          ),
        ],
      );
    }

    test('初始状态为空（movies/boxSets/people 都是空）', () {
      final testAuthState = AuthState(
        isAuthenticated: true,
        user: User(id: 'user-1', name: 'test', accessToken: 'test-token'),
        embyServerUrl: 'http://emby.example.com',
        token: 'test-token',
      );
      final container = createContainerWithAuth(testAuthState);

      final state = container.read(favoritesProvider);
      expect(state.movies, isEmpty);
      expect(state.boxSets, isEmpty);
      expect(state.people, isEmpty);
      expect(state.isLoading, false);
      expect(state.error, isNull);
      expect(state.favoriteIds, isEmpty);

      container.dispose();
    });

    test('loadFavorites 成功加载并按类型分组（movie/series/boxset/person）', () async {
      final testAuthState = AuthState(
        isAuthenticated: true,
        user: User(id: 'user-1', name: 'test', accessToken: 'test-token'),
        embyServerUrl: 'http://emby.example.com',
        token: 'test-token',
      );

      // 模拟 Emby API 返回的混合类型收藏
      final items = <MediaItem>[
        MediaItem(id: 'fav-1', title: 'Favorite Movie 1', type: 'Movie'),
        MediaItem(id: 'fav-2', title: 'Favorite Series 2', type: 'Series'),
        MediaItem(id: 'fav-3', title: 'Favorite Box', type: 'BoxSet'),
        MediaItem(id: 'fav-4', title: 'Favorite Person', type: 'Person'),
      ];

      when(mockService.getFavorites(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async => items);

      final container = createContainerWithAuth(testAuthState);

      final notifier = container.read(favoritesProvider.notifier);
      await notifier.loadFavorites();

      final state = container.read(favoritesProvider);

      // Movie + Series 应该被归类到 movies
      expect(state.movies.length, 2);
      // BoxSet 单独归类
      expect(state.boxSets.length, 1);
      // Person 单独归类
      expect(state.people.length, 1);
      expect(state.isLoading, false);
      expect(state.error, isNull);
      expect(state.favoriteIds, <String>{'fav-1', 'fav-2', 'fav-3', 'fav-4'});

      // 验证 mock 被正确调用（带 serverUrl 和 token）
      verify(mockService.getFavorites(
        serverUrl: 'http://emby.example.com',
        token: 'test-token',
      )).called(1);

      container.dispose();
    });

    test('loadFavorites 失败时设置 error 状态', () async {
      final testAuthState = AuthState(
        isAuthenticated: true,
        user: User(id: 'user-1', name: 'test', accessToken: 'test-token'),
        embyServerUrl: 'http://emby.example.com',
        token: 'test-token',
      );

      when(mockService.getFavorites(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenThrow(Exception('网络错误'));

      final container = createContainerWithAuth(testAuthState);

      final notifier = container.read(favoritesProvider.notifier);
      await notifier.loadFavorites();

      final state = container.read(favoritesProvider);
      expect(state.isLoading, false);
      expect(state.error, contains('加载收藏失败'));
      expect(state.movies, isEmpty);

      container.dispose();
    });

    test('未登录时 loadFavorites 设置错误信息但不调用 service', () async {
      final container = createContainerWithAuth(const AuthState());

      final notifier = container.read(favoritesProvider.notifier);
      await notifier.loadFavorites();

      final state = container.read(favoritesProvider);
      expect(state.error, isNotNull);
      expect(state.isLoading, false);

      // 未登录不应调用 service
      verifyNever(mockService.getFavorites(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      ));

      container.dispose();
    });

    test('toggleFavorite 添加收藏：乐观更新后调用 service', () async {
      final testAuthState = AuthState(
        isAuthenticated: true,
        user: User(id: 'user-1', name: 'test', accessToken: 'test-token'),
        embyServerUrl: 'http://emby.example.com',
        token: 'test-token',
      );

      // 先模拟加载一些现有收藏
      final existingItems = <MediaItem>[
        MediaItem(id: 'fav-1', title: 'Existing Favorite', type: 'Movie'),
      ];

      when(mockService.getFavorites(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async => existingItems);

      when(mockService.toggleFavorite(
        any,
        isFavorite: anyNamed('isFavorite'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async {});

      final container = createContainerWithAuth(testAuthState);

      final notifier = container.read(favoritesProvider.notifier);
      await notifier.loadFavorites();
      expect(container.read(favoritesProvider).favoriteIds, <String>{'fav-1'});

      // 添加新收藏
      final newItem = MediaItem(id: 'fav-2', title: 'New Favorite', type: 'Movie');
      await notifier.toggleFavorite(newItem);

      final state = container.read(favoritesProvider);
      expect(state.favoriteIds.contains('fav-2'), true);
      expect(state.movies.any((e) => e.id == 'fav-2'), true);
      expect(state.error, isNull);

      // 验证 service 被调用（isFavorite=true）
      verify(mockService.toggleFavorite(
        'fav-2',
        isFavorite: true,
        serverUrl: 'http://emby.example.com',
        token: 'test-token',
      )).called(1);

      container.dispose();
    });

    test('toggleFavorite 取消收藏：从列表中移除', () async {
      final testAuthState = AuthState(
        isAuthenticated: true,
        user: User(id: 'user-1', name: 'test', accessToken: 'test-token'),
        embyServerUrl: 'http://emby.example.com',
        token: 'test-token',
      );

      final existingItems = <MediaItem>[
        MediaItem(id: 'fav-1', title: 'Favorite 1', type: 'Movie'),
        MediaItem(id: 'fav-2', title: 'Favorite 2', type: 'Movie'),
      ];

      when(mockService.getFavorites(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async => existingItems);

      when(mockService.toggleFavorite(
        any,
        isFavorite: anyNamed('isFavorite'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async {});

      final container = createContainerWithAuth(testAuthState);

      final notifier = container.read(favoritesProvider.notifier);
      await notifier.loadFavorites();
      expect(container.read(favoritesProvider).favoriteIds,
          <String>{'fav-1', 'fav-2'});

      // 取消 fav-1 的收藏
      final itemToRemove = MediaItem(id: 'fav-1', title: 'Favorite 1', type: 'Movie');
      await notifier.toggleFavorite(itemToRemove);

      final state = container.read(favoritesProvider);
      expect(state.favoriteIds.contains('fav-1'), false);
      expect(state.movies.any((e) => e.id == 'fav-1'), false);
      expect(state.movies.length, 1);
      expect(state.error, isNull);

      // 验证 service 被调用（isFavorite=false）
      verify(mockService.toggleFavorite(
        'fav-1',
        isFavorite: false,
        serverUrl: 'http://emby.example.com',
        token: 'test-token',
      )).called(1);

      container.dispose();
    });

    test('isFavorite 正确判断是否已收藏', () async {
      final testAuthState = AuthState(
        isAuthenticated: true,
        user: User(id: 'user-1', name: 'test', accessToken: 'test-token'),
        embyServerUrl: 'http://emby.example.com',
        token: 'test-token',
      );

      final items = <MediaItem>[
        MediaItem(id: 'fav-1', title: 'Favorite 1', type: 'Movie'),
      ];

      when(mockService.getFavorites(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async => items);

      final container = createContainerWithAuth(testAuthState);

      final notifier = container.read(favoritesProvider.notifier);
      await notifier.loadFavorites();

      expect(notifier.isFavorite('fav-1'), true);
      expect(notifier.isFavorite('fav-2'), false);
      expect(notifier.isFavorite('unknown'), false);

      container.dispose();
    });

    test('未登录时 toggleFavorite 直接返回且不调用 service', () async {
      final container = createContainerWithAuth(const AuthState());

      final notifier = container.read(favoritesProvider.notifier);
      final item = MediaItem(id: 'fav-1', title: 'Test', type: 'Movie');
      await notifier.toggleFavorite(item);

      // 不调用 service
      verifyNever(mockService.toggleFavorite(
        any,
        isFavorite: anyNamed('isFavorite'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      ));

      container.dispose();
    });
  });
}
