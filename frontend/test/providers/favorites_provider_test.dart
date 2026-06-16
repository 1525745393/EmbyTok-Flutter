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
      expect(state.isLoading, false);
      expect(state.error, isNull);
      expect(state.favoriteIds, isEmpty);
    });

    test('copyWith 正确更新字段', () {
      const original = FavoritesState();
      final items = [
        MediaItem(id: '1', title: 'Favorite 1', type: 'Movie'),
        MediaItem(id: '2', title: 'Favorite 2', type: 'Movie'),
      ];
      final favoriteIds = {'1', '2'};

      final updated = original.copyWith(
        items: items,
        isLoading: true,
        error: '加载失败',
        favoriteIds: favoriteIds,
      );

      expect(updated.items, items);
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
    ProviderContainer createContainerWithAuth() {
      return ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) => _TestAuthNotifier(testAuthState)),
          favoritesProvider.overrideWith(
            (ref) => FavoritesNotifier(ref, service: mockService),
          ),
        ],
      );
    }

    test('初始状态', () {
      container = createContainerWithAuth();

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

      container = createContainerWithAuth();

      final notifier = container.read(favoritesProvider.notifier);
      await notifier.loadFavorites();

      final state = container.read(favoritesProvider);
      expect(state.movies.length, 3);
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

      container = createContainerWithAuth();

      final notifier = container.read(favoritesProvider.notifier);
      await notifier.loadFavorites();

      final state = container.read(favoritesProvider);
      expect(state.isLoading, false);
      expect(state.error, contains('加载收藏失败'));
      expect(state.movies, isEmpty);
    });

    test('loadFavorites() 失败：字符串错误信息', () async {
      when(mockService.getFavorites(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenThrow('服务器维护中');

      container = createContainerWithAuth();

      final notifier = container.read(favoritesProvider.notifier);
      await notifier.loadFavorites();

      final state = container.read(favoritesProvider);
      expect(state.error, '服务器维护中');
    });

    test('未登录时 loadFavorites() 返回错误', () async {
      container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(
            (ref) => _TestAuthNotifier(const AuthState()),
          ),
          favoritesProvider.overrideWith(
            (ref) => FavoritesNotifier(ref, service: mockService),
          ),
        ],
      );

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
        any,
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async {});

      container = createContainerWithAuth();

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
      expect(state.movies.first.id, 'fav-2'); // 新收藏插入到列表头部
      expect(state.error, isNull);

      verify(mockService.toggleFavorite(
        'fav-2',
        true,
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
        any,
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async {});

      container = createContainerWithAuth();

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
        false,
        serverUrl: 'http://emby.example.com',
        token: 'test-token',
      )).called(1);
    });

    test('toggleFavorite() 添加失败：回滚状态', () async {
      final existingItems = [
        MediaItem(id: 'fav-1', title: 'Existing Favorite', type: 'Movie'),
      ];

      when(mockService.getFavorites(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async => existingItems);

      when(mockService.toggleFavorite(
        any,
        any,
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenThrow(Exception('添加失败'));

      container = createContainerWithAuth();

      final notifier = container.read(favoritesProvider.notifier);

      // 先加载现有收藏
      await notifier.loadFavorites();
      final originalState = container.read(favoritesProvider);
      expect(originalState.favoriteIds, {'fav-1'});

      // 尝试添加新收藏（会失败）
      final newItem = MediaItem(id: 'fav-2', title: 'New Favorite', type: 'Movie');
      await notifier.toggleFavorite(newItem);

      final state = container.read(favoritesProvider);
      // 应该回滚到原始状态
      expect(state.favoriteIds, {'fav-1'});
      expect(state.movies.length, 1);
      expect(state.error, contains('切换收藏失败'));
    });

    test('toggleFavorite() 取消失败：回滚状态', () async {
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
        any,
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenThrow(Exception('取消失败'));

      container = createContainerWithAuth();

      final notifier = container.read(favoritesProvider.notifier);

      // 先加载现有收藏
      await notifier.loadFavorites();
      expect(container.read(favoritesProvider).favoriteIds, {'fav-1', 'fav-2'});

      // 尝试取消收藏（会失败）
      final itemToRemove = MediaItem(id: 'fav-1', title: 'Favorite 1', type: 'Movie');
      await notifier.toggleFavorite(itemToRemove);

      final state = container.read(favoritesProvider);
      // 应该回滚到原始状态
      expect(state.favoriteIds, {'fav-1', 'fav-2'});
      expect(state.movies.length, 2);
      expect(state.error, contains('切换收藏失败'));
    });

    test('isFavorite() 正确判断收藏状态', () async {
      final items = [
        MediaItem(id: 'fav-1', title: 'Favorite 1', type: 'Movie'),
      ];

      when(mockService.getFavorites(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async => items);

      container = createContainerWithAuth();

      final notifier = container.read(favoritesProvider.notifier);
      await notifier.loadFavorites();

      expect(notifier.isFavorite('fav-1'), true);
      expect(notifier.isFavorite('fav-2'), false);
      expect(notifier.isFavorite('unknown'), false);
    });

    test('未登录时 toggleFavorite() 返回错误', () async {
      container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(
            (ref) => _TestAuthNotifier(const AuthState()),
          ),
          favoritesProvider.overrideWith(
            (ref) => FavoritesNotifier(ref, service: mockService),
          ),
        ],
      );

      final notifier = container.read(favoritesProvider.notifier);
      final item = MediaItem(id: 'fav-1', title: 'Test', type: 'Movie');
      await notifier.toggleFavorite(item);

      final state = container.read(favoritesProvider);
      expect(state.error, '尚未登录');

      verifyNever(mockService.toggleFavorite(
        any,
        any,
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      ));
    });

    test('toggleFavorite() 添加已存在的项目不重复插入', () async {
      final existingItems = [
        MediaItem(id: 'fav-1', title: 'Favorite 1', type: 'Movie'),
      ];

      when(mockService.getFavorites(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async => existingItems);

      when(mockService.toggleFavorite(
        any,
        any,
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async {});

      container = createContainerWithAuth();

      final notifier = container.read(favoritesProvider.notifier);
      await notifier.loadFavorites();

      // 再次添加已存在的项目
      final existingItem = MediaItem(id: 'fav-1', title: 'Favorite 1', type: 'Movie');
      await notifier.toggleFavorite(existingItem);

      final state = container.read(favoritesProvider);
      // 应该取消收藏
      expect(state.favoriteIds.contains('fav-1'), false);
    });
  });
}

// 测试用 AuthNotifier：直接返回预设状态
class _TestAuthNotifier extends StateNotifier<AuthState> {
  _TestAuthNotifier(AuthState initialState) : super(initialState);
}
