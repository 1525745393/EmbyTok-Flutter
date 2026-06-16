// FavoritesNotifier 状态机测试：验证收藏列表加载、切换收藏状态等

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:embbytok_flutter/models/models.dart';
import 'package:embbytok_flutter/providers/auth_provider.dart';
import 'package:embbytok_flutter/providers/favorites_provider.dart';
import 'package:embbytok_flutter/services/embbytok_service.dart';

import '../mocks/mock_services.dart';

void main() {
  group('FavoritesState', () {
    test('初始状态正确', () {
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
      final movies = [
        MediaItem(id: '1', title: 'Favorite 1', type: 'Movie'),
        MediaItem(id: '2', title: 'Favorite 2', type: 'Movie'),
      ];
      final favoriteIds = {'1', '2'};

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
    late MockEmbytokService mockService;
    late ProviderContainer container;
    late AuthState testAuthState;

    setUp(() {
      mockService = MockEmbytokService();
      testAuthState = AuthState(
        isAuthenticated: true,
        user: User(id: 'user-1', name: 'test', accessToken: 'test-token'),
        embyServerUrl: 'http://emby.example.com',
        token: 'test-token',
      );
    });

    tearDown(() {
      container.dispose();
    });

    // 创建带认证状态的容器
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

    test('初始状态', () {
      container = createContainerWithAuth(testAuthState);

      final state = container.read(favoritesProvider);
      expect(state.movies, isEmpty);
      expect(state.isLoading, false);
      expect(state.error, isNull);
      expect(state.favoriteIds, isEmpty);
    });

    test('loadFavorites() 成功加载收藏列表', () async {
      final items = [
        MediaItem(id: 'fav-1', title: 'Favorite Movie 1', type: 'Movie'),
        MediaItem(id: 'fav-2', title: 'Favorite Movie 2', type: 'Movie'),
        MediaItem(id: 'fav-3', title: 'Favorite Series', type: 'Series'),
      ];

      when(mockService.getFavorites(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async => items);

      container = createContainerWithAuth(testAuthState);

      final notifier = container.read(favoritesProvider.notifier);
      await notifier.loadFavorites();

      final state = container.read(favoritesProvider);
      expect(state.movies.length, 3); // Movie, Movie, Series
      expect(state.isLoading, false);
      expect(state.error, isNull);
      expect(state.favoriteIds, {'fav-1', 'fav-2', 'fav-3'});

      verify(mockService.getFavorites(
        serverUrl: 'http://emby.example.com',
        token: 'test-token',
      )).called(1);
    });

    test('loadFavorites() 失败：error 包含错误信息', () async {
      when(mockService.getFavorites(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenThrow(Exception('网络错误'));

      container = createContainerWithAuth(testAuthState);

      final notifier = container.read(favoritesProvider.notifier);
      await notifier.loadFavorites();

      final state = container.read(favoritesProvider);
      expect(state.isLoading, false);
      expect(state.error, contains('加载收藏失败'));
      expect(state.movies, isEmpty);
    });

    test('未登录时 loadFavorites() 返回错误', () async {
      container = createContainerWithAuth(const AuthState());

      final notifier = container.read(favoritesProvider.notifier);
      await notifier.loadFavorites();

      final state = container.read(favoritesProvider);
      expect(state.error, '尚未登录');
      expect(state.isLoading, false);

      verifyNever(mockService.getFavorites(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      ));
    });

    test('toggleFavorite() 添加收藏：乐观更新 UI', () async {
      final existingItems = [
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

      container = createContainerWithAuth(testAuthState);

      final notifier = container.read(favoritesProvider.notifier);

      // 先加载现有收藏
      await notifier.loadFavorites();
      expect(container.read(favoritesProvider).favoriteIds, {'fav-1'});

      // 添加新收藏
      final newItem = MediaItem(id: 'fav-2', title: 'New Favorite', type: 'Movie');
      await notifier.toggleFavorite(newItem);

      final state = container.read(favoritesProvider);
      expect(state.favoriteIds.contains('fav-2'), true);
      expect(state.movies.any((e) => e.id == 'fav-2'), true);
      expect(state.error, isNull);

      verify(mockService.toggleFavorite(
        'fav-2',
        isFavorite: true,
        serverUrl: 'http://emby.example.com',
        token: 'test-token',
      )).called(1);
    });

    test('toggleFavorite() 取消收藏：乐观更新 UI', () async {
      final existingItems = [
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

      container = createContainerWithAuth(testAuthState);

      final notifier = container.read(favoritesProvider.notifier);

      // 先加载现有收藏
      await notifier.loadFavorites();
      expect(container.read(favoritesProvider).favoriteIds, {'fav-1', 'fav-2'});

      // 取消收藏
      final itemToRemove = MediaItem(id: 'fav-1', title: 'Favorite 1', type: 'Movie');
      await notifier.toggleFavorite(itemToRemove);

      final state = container.read(favoritesProvider);
      expect(state.favoriteIds.contains('fav-1'), false);
      expect(state.movies.any((e) => e.id == 'fav-1'), false);
      expect(state.movies.length, 1);
      expect(state.error, isNull);

      verify(mockService.toggleFavorite(
        'fav-1',
        isFavorite: false,
        serverUrl: 'http://emby.example.com',
        token: 'test-token',
      )).called(1);
    });

    test('isFavorite() 正确判断收藏状态', () async {
      final items = [
        MediaItem(id: 'fav-1', title: 'Favorite 1', type: 'Movie'),
      ];

      when(mockService.getFavorites(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async => items);

      container = createContainerWithAuth(testAuthState);

      final notifier = container.read(favoritesProvider.notifier);
      await notifier.loadFavorites();

      expect(notifier.isFavorite('fav-1'), true);
      expect(notifier.isFavorite('fav-2'), false);
      expect(notifier.isFavorite('unknown'), false);
    });

    test('未登录时 toggleFavorite() 直接返回', () async {
      container = createContainerWithAuth(const AuthState());

      final notifier = container.read(favoritesProvider.notifier);
      final item = MediaItem(id: 'fav-1', title: 'Test', type: 'Movie');
      await notifier.toggleFavorite(item);

      final state = container.read(favoritesProvider);
      // 未登录时不设置 error，只是直接返回

      verifyNever(mockService.toggleFavorite(
        any,
        isFavorite: anyNamed('isFavorite'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      ));
    });
  });
}

// 测试用 AuthNotifier：继承 AuthNotifier，直接返回预设状态
class TestAuthNotifier extends AuthNotifier {
  final AuthState _testState;

  TestAuthNotifier(this._testState, {EmbytokService? service})
      : super(service: service);

  @override
  AuthState get state => _testState;

  @override
  Future<void> login(
    String embyServerUrl,
    String username,
    String password,
  ) async {
    // 测试中不执行实际登录
  }

  @override
  Future<void> logout() async {
    // 测试中不执行实际登出
  }
}
