// FavoritesNotifier 状态机测试：验证三栏收藏列表加载、切换收藏状态等

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
        MediaItem(id: '1', title: 'Movie 1', type: 'Movie'),
        MediaItem(id: '2', title: 'Movie 2', type: 'Movie'),
      ];
      final boxSets = [MediaItem(id: '3', title: 'BoxSet 1', type: 'BoxSet')];
      final people = [MediaItem(id: '4', title: 'Person 1', type: 'Person')];
      final favoriteIds = {'1', '2', '3', '4'};

      final updated = original.copyWith(
        movies: movies,
        boxSets: boxSets,
        people: people,
        isLoading: true,
        error: '加载失败',
        favoriteIds: favoriteIds,
      );

      expect(updated.movies, movies);
      expect(updated.boxSets, boxSets);
      expect(updated.people, people);
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
      expect(state.boxSets, isEmpty);
      expect(state.people, isEmpty);
      expect(state.isLoading, false);
      expect(state.error, isNull);
      expect(state.favoriteIds, isEmpty);
    });

    test('loadFavorites() 成功加载三栏收藏列表', () async {
      final movies = [
        MediaItem(id: 'mov-1', title: 'Favorite Movie 1', type: 'Movie'),
        MediaItem(id: 'mov-2', title: 'Favorite Movie 2', type: 'Movie'),
      ];
      final boxSets = [
        MediaItem(id: 'box-1', title: 'Favorite BoxSet', type: 'BoxSet'),
      ];
      final people = [
        MediaItem(id: 'per-1', title: 'Favorite Person', type: 'Person'),
      ];

      // 使用具体值 stub（null-safe mockito 要求）
      when(mockService.getFavoriteMovies(
        serverUrl: 'http://emby.example.com',
        token: 'test-token',
      )).thenAnswer((_) async => movies);

      when(mockService.getFavoriteBoxSets(
        serverUrl: 'http://emby.example.com',
        token: 'test-token',
      )).thenAnswer((_) async => boxSets);

      when(mockService.getFavoritePeople(
        serverUrl: 'http://emby.example.com',
        token: 'test-token',
      )).thenAnswer((_) async => people);

      container = createContainerWithAuth();

      final notifier = container.read(favoritesProvider.notifier);
      await notifier.loadFavorites();

      final state = container.read(favoritesProvider);
      expect(state.movies.length, 2);
      expect(state.boxSets.length, 1);
      expect(state.people.length, 1);
      expect(state.isLoading, false);
      expect(state.error, isNull);
      expect(state.favoriteIds, {'mov-1', 'mov-2', 'box-1', 'per-1'});

      verify(mockService.getFavoriteMovies(
        serverUrl: 'http://emby.example.com',
        token: 'test-token',
      )).called(1);
      verify(mockService.getFavoriteBoxSets(
        serverUrl: 'http://emby.example.com',
        token: 'test-token',
      )).called(1);
      verify(mockService.getFavoritePeople(
        serverUrl: 'http://emby.example.com',
        token: 'test-token',
      )).called(1);
    });

    test('loadFavorites() 失败：error 包含错误信息', () async {
      when(mockService.getFavoriteMovies(
        serverUrl: 'http://emby.example.com',
        token: 'test-token',
      )).thenThrow(Exception('网络错误'));

      when(mockService.getFavoriteBoxSets(
        serverUrl: 'http://emby.example.com',
        token: 'test-token',
      )).thenAnswer((_) async => <MediaItem>[]);

      when(mockService.getFavoritePeople(
        serverUrl: 'http://emby.example.com',
        token: 'test-token',
      )).thenAnswer((_) async => <MediaItem>[]);

      container = createContainerWithAuth();

      final notifier = container.read(favoritesProvider.notifier);
      await notifier.loadFavorites();

      final state = container.read(favoritesProvider);
      expect(state.isLoading, false);
      expect(state.error, contains('加载收藏失败'));
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

      verifyNever(mockService.getFavoriteMovies(
        serverUrl: 'http://emby.example.com',
        token: 'test-token',
      ));
    });

    test('toggleFavorite() 添加影片收藏：乐观更新 UI', () async {
      // stub 空的初始列表
      when(mockService.getFavoriteMovies(
        serverUrl: 'http://emby.example.com',
        token: 'test-token',
      )).thenAnswer((_) async => <MediaItem>[]);
      when(mockService.getFavoriteBoxSets(
        serverUrl: 'http://emby.example.com',
        token: 'test-token',
      )).thenAnswer((_) async => <MediaItem>[]);
      when(mockService.getFavoritePeople(
        serverUrl: 'http://emby.example.com',
        token: 'test-token',
      )).thenAnswer((_) async => <MediaItem>[]);

      // stub toggleFavorite 调用
      when(mockService.toggleFavorite(
        'new-1',
        isFavorite: true,
        serverUrl: 'http://emby.example.com',
        token: 'test-token',
      )).thenAnswer((_) async {});

      container = createContainerWithAuth();

      final notifier = container.read(favoritesProvider.notifier);

      // 先加载空列表
      await notifier.loadFavorites();
      expect(container.read(favoritesProvider).favoriteIds, isEmpty);

      // 添加新收藏（类型为 Movie）
      final newItem = MediaItem(id: 'new-1', title: 'New Favorite', type: 'Movie');
      await notifier.toggleFavorite(newItem);

      final state = container.read(favoritesProvider);
      expect(state.favoriteIds.contains('new-1'), true);
      expect(state.movies.any((e) => e.id == 'new-1'), true);
      expect(state.error, isNull);

      verify(mockService.toggleFavorite(
        'new-1',
        isFavorite: true,
        serverUrl: 'http://emby.example.com',
        token: 'test-token',
      )).called(1);
    });

    test('toggleFavorite() 取消影片收藏：乐观更新 UI', () async {
      final existingMovies = [
        MediaItem(id: 'mov-1', title: 'Movie 1', type: 'Movie'),
        MediaItem(id: 'mov-2', title: 'Movie 2', type: 'Movie'),
      ];

      when(mockService.getFavoriteMovies(
        serverUrl: 'http://emby.example.com',
        token: 'test-token',
      )).thenAnswer((_) async => existingMovies);
      when(mockService.getFavoriteBoxSets(
        serverUrl: 'http://emby.example.com',
        token: 'test-token',
      )).thenAnswer((_) async => <MediaItem>[]);
      when(mockService.getFavoritePeople(
        serverUrl: 'http://emby.example.com',
        token: 'test-token',
      )).thenAnswer((_) async => <MediaItem>[]);

      when(mockService.toggleFavorite(
        'mov-1',
        isFavorite: false,
        serverUrl: 'http://emby.example.com',
        token: 'test-token',
      )).thenAnswer((_) async {});

      container = createContainerWithAuth();

      final notifier = container.read(favoritesProvider.notifier);

      // 先加载现有收藏
      await notifier.loadFavorites();
      expect(container.read(favoritesProvider).favoriteIds, {'mov-1', 'mov-2'});

      // 取消收藏 mov-1
      final itemToRemove = MediaItem(id: 'mov-1', title: 'Movie 1', type: 'Movie');
      await notifier.toggleFavorite(itemToRemove);

      final state = container.read(favoritesProvider);
      expect(state.favoriteIds.contains('mov-1'), false);
      expect(state.movies.any((e) => e.id == 'mov-1'), false);
      expect(state.movies.length, 1);
      expect(state.error, isNull);

      verify(mockService.toggleFavorite(
        'mov-1',
        isFavorite: false,
        serverUrl: 'http://emby.example.com',
        token: 'test-token',
      )).called(1);
    });

    test('isFavorite() 正确判断收藏状态', () async {
      final movies = [
        MediaItem(id: 'mov-1', title: 'Movie 1', type: 'Movie'),
      ];

      when(mockService.getFavoriteMovies(
        serverUrl: 'http://emby.example.com',
        token: 'test-token',
      )).thenAnswer((_) async => movies);
      when(mockService.getFavoriteBoxSets(
        serverUrl: 'http://emby.example.com',
        token: 'test-token',
      )).thenAnswer((_) async => <MediaItem>[]);
      when(mockService.getFavoritePeople(
        serverUrl: 'http://emby.example.com',
        token: 'test-token',
      )).thenAnswer((_) async => <MediaItem>[]);

      container = createContainerWithAuth();

      final notifier = container.read(favoritesProvider.notifier);
      await notifier.loadFavorites();

      expect(notifier.isFavorite('mov-1'), true);
      expect(notifier.isFavorite('mov-2'), false);
      expect(notifier.isFavorite('unknown'), false);
    });

    test('未登录时 toggleFavorite() 不执行', () async {
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

      // 未登录时应直接 return，不修改状态，也不调用服务
      verifyNever(mockService.toggleFavorite(
        'fav-1',
        isFavorite: true,
        serverUrl: 'http://emby.example.com',
        token: 'test-token',
      ));
    });
  });
}

// 测试用 AuthNotifier：直接返回预设状态
class _TestAuthNotifier extends StateNotifier<AuthState> {
  _TestAuthNotifier(AuthState initialState) : super(initialState);
}
