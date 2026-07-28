// FavoritesNotifier 状态机测试：验证收藏列表加载、切换收藏状态等

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:embytok_flutter/models/models.dart';
import 'package:embytok_flutter/providers/auth_provider.dart';
import 'package:embytok_flutter/providers/embytok_service_provider.dart';
import 'package:embytok_flutter/providers/favorites_provider.dart';
import 'package:embytok_flutter/services/embytok_service.dart';

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
        movies: items,
        isLoading: true,
        error: '加载失败',
        favoriteIds: favoriteIds,
      );

      expect(updated.movies, items);
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
          embytokServiceProvider.overrideWithValue(mockService),
          authProvider.overrideWith(
            (ref) => _TestAuthNotifier(ref, testAuthState),
          ),
          favoritesProvider.overrideWith(
            (ref) => FavoritesNotifier(ref),
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

      when(mockService.getFavoriteMovies(
        userId: anyNamed('userId'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async => FavoritesPageResult(
        items: items,
        totalCount: items.length,
      ));

      container = createContainerWithAuth();

      final notifier = container.read(favoritesProvider.notifier);
      await notifier.loadFavorites();

      final state = container.read(favoritesProvider);
      expect(state.movies.length, 3);
      expect(state.isLoading, false);
      expect(state.error, isNull);
      expect(state.favoriteIds, {'fav-1', 'fav-2', 'fav-3'});

      verify(mockService.getFavoriteMovies(
        userId: 'user-1',
        serverUrl: 'http://emby.example.com',
        token: 'test-token',
      )).called(1);
    });

    test('loadFavorites() 失败：error 包含错误信息', () async {
      when(mockService.getFavoriteMovies(
        userId: anyNamed('userId'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenThrow(Exception('网络错误'));
      when(mockService.getFavoriteBoxSets(
        userId: anyNamed('userId'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenThrow(Exception('网络错误'));
      when(mockService.getFavoritePeople(
        userId: anyNamed('userId'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenThrow(Exception('网络错误'));

      container = createContainerWithAuth();

      final notifier = container.read(favoritesProvider.notifier);
      await notifier.loadFavorites();

      final state = container.read(favoritesProvider);
      expect(state.isLoading, false);
      // 三栏全部失败时全局 error 为"全部收藏加载失败"
      expect(state.error, contains('加载失败'));
      expect(state.movies, isEmpty);
    });

    test('loadFavorites() 失败：字符串错误信息', () async {
      when(mockService.getFavoriteMovies(
        userId: anyNamed('userId'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenThrow('服务器维护中');
      when(mockService.getFavoriteBoxSets(
        userId: anyNamed('userId'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenThrow('服务器维护中');
      when(mockService.getFavoritePeople(
        userId: anyNamed('userId'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenThrow('服务器维护中');

      container = createContainerWithAuth();

      final notifier = container.read(favoritesProvider.notifier);
      await notifier.loadFavorites();

      final state = container.read(favoritesProvider);
      // 三栏全部失败时全局 error 为统一信息
      expect(state.error, '全部收藏加载失败');
      // 各栏错误信息保留原始字符串
      expect(state.moviesError, '服务器维护中');
    });

    test('未登录时 loadFavorites() 返回错误', () async {
      container = ProviderContainer(
        overrides: [
          embytokServiceProvider.overrideWithValue(mockService),
          authProvider.overrideWith(
            (ref) => _TestAuthNotifier(ref, const AuthState()),
          ),
          favoritesProvider.overrideWith(
            (ref) => FavoritesNotifier(ref),
          ),
        ],
      );

      final notifier = container.read(favoritesProvider.notifier);
      await notifier.loadFavorites();

      final state = container.read(favoritesProvider);
      expect(state.error, '尚未登录');
      expect(state.isLoading, false);

      verifyNever(mockService.getFavoriteMovies(
        userId: anyNamed('userId'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      ));
    });

    test('toggleFavorite() 添加收藏：乐观更新 UI', () async {
      final existingItems = [
        MediaItem(id: 'fav-1', title: 'Existing Favorite', type: 'Movie'),
      ];

      when(mockService.getFavoriteMovies(
        userId: anyNamed('userId'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async => FavoritesPageResult(
        items: existingItems,
        totalCount: existingItems.length,
      ));

      when(mockService.toggleFavorite(
        itemId: anyNamed('itemId'),
        isFavorite: anyNamed('isFavorite'),
        userId: anyNamed('userId'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async {});

      container = createContainerWithAuth();

      final notifier = container.read(favoritesProvider.notifier);

      // 先加载现有收藏
      await notifier.loadFavorites();
      expect(container.read(favoritesProvider).favoriteIds, {'fav-1'});

      // 添加新收藏
      final newItem = MediaItem(
        id: 'fav-2',
        title: 'New Favorite',
        type: 'Movie',
      );
      await notifier.toggleFavorite(newItem);

      final state = container.read(favoritesProvider);
      expect(state.favoriteIds.contains('fav-2'), true);
      expect(state.movies.any((e) => e.id == 'fav-2'), true);
      expect(state.movies.first.id, 'fav-2'); // 新收藏插入到列表头部
      expect(state.error, isNull);

      verify(mockService.toggleFavorite(
        itemId: 'fav-2',
        isFavorite: true,
        userId: 'user-1',
        serverUrl: 'http://emby.example.com',
        token: 'test-token',
      )).called(1);
    });

    test('toggleFavorite() 取消收藏：乐观更新 UI', () async {
      final existingItems = [
        MediaItem(id: 'fav-1', title: 'Favorite 1', type: 'Movie'),
        MediaItem(id: 'fav-2', title: 'Favorite 2', type: 'Movie'),
      ];

      when(mockService.getFavoriteMovies(
        userId: anyNamed('userId'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async => FavoritesPageResult(
        items: existingItems,
        totalCount: existingItems.length,
      ));

      when(mockService.toggleFavorite(
        itemId: anyNamed('itemId'),
        isFavorite: anyNamed('isFavorite'),
        userId: anyNamed('userId'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async {});

      container = createContainerWithAuth();

      final notifier = container.read(favoritesProvider.notifier);

      // 先加载现有收藏
      await notifier.loadFavorites();
      expect(container.read(favoritesProvider).favoriteIds, {'fav-1', 'fav-2'});

      // 取消收藏
      final itemToRemove = MediaItem(
        id: 'fav-1',
        title: 'Favorite 1',
        type: 'Movie',
      );
      await notifier.toggleFavorite(itemToRemove);

      final state = container.read(favoritesProvider);
      expect(state.favoriteIds.contains('fav-1'), false);
      expect(state.movies.any((e) => e.id == 'fav-1'), false);
      expect(state.movies.length, 1);
      expect(state.error, isNull);

      verify(mockService.toggleFavorite(
        itemId: 'fav-1',
        isFavorite: false,
        userId: 'user-1',
        serverUrl: 'http://emby.example.com',
        token: 'test-token',
      )).called(1);
    });

    test('toggleFavorite() 添加失败：回滚状态', () async {
      final existingItems = [
        MediaItem(id: 'fav-1', title: 'Existing Favorite', type: 'Movie'),
      ];

      when(mockService.getFavoriteMovies(
        userId: anyNamed('userId'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async => FavoritesPageResult(
        items: existingItems,
        totalCount: existingItems.length,
      ));

      when(mockService.toggleFavorite(
        itemId: anyNamed('itemId'),
        isFavorite: anyNamed('isFavorite'),
        userId: anyNamed('userId'),
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
      final newItem = MediaItem(
        id: 'fav-2',
        title: 'New Favorite',
        type: 'Movie',
      );
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

      when(mockService.getFavoriteMovies(
        userId: anyNamed('userId'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async => FavoritesPageResult(
        items: existingItems,
        totalCount: existingItems.length,
      ));

      when(mockService.toggleFavorite(
        itemId: anyNamed('itemId'),
        isFavorite: anyNamed('isFavorite'),
        userId: anyNamed('userId'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenThrow(Exception('取消失败'));

      container = createContainerWithAuth();

      final notifier = container.read(favoritesProvider.notifier);

      // 先加载现有收藏
      await notifier.loadFavorites();
      expect(container.read(favoritesProvider).favoriteIds, {'fav-1', 'fav-2'});

      // 尝试取消收藏（会失败）
      final itemToRemove = MediaItem(
        id: 'fav-1',
        title: 'Favorite 1',
        type: 'Movie',
      );
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

      when(mockService.getFavoriteMovies(
        userId: anyNamed('userId'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async => FavoritesPageResult(
        items: items,
        totalCount: items.length,
      ));

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
          embytokServiceProvider.overrideWithValue(mockService),
          authProvider.overrideWith(
            (ref) => _TestAuthNotifier(ref, const AuthState()),
          ),
          favoritesProvider.overrideWith(
            (ref) => FavoritesNotifier(ref),
          ),
        ],
      );

      final notifier = container.read(favoritesProvider.notifier);
      final item = MediaItem(id: 'fav-1', title: 'Test', type: 'Movie');
      await notifier.toggleFavorite(item);

      final state = container.read(favoritesProvider);
      expect(state.error, '尚未登录');

      verifyNever(mockService.toggleFavorite(
        itemId: anyNamed('itemId'),
        isFavorite: anyNamed('isFavorite'),
        userId: anyNamed('userId'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      ));
    });

    test('toggleFavorite() 添加已存在的项目不重复插入', () async {
      final existingItems = [
        MediaItem(id: 'fav-1', title: 'Favorite 1', type: 'Movie'),
      ];

      when(mockService.getFavoriteMovies(
        userId: anyNamed('userId'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async => FavoritesPageResult(
        items: existingItems,
        totalCount: existingItems.length,
      ));

      when(mockService.toggleFavorite(
        itemId: anyNamed('itemId'),
        isFavorite: anyNamed('isFavorite'),
        userId: anyNamed('userId'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async {});

      container = createContainerWithAuth();

      final notifier = container.read(favoritesProvider.notifier);
      await notifier.loadFavorites();

      // 再次添加已存在的项目
      final existingItem = MediaItem(
        id: 'fav-1',
        title: 'Favorite 1',
        type: 'Movie',
      );
      await notifier.toggleFavorite(existingItem);

      final state = container.read(favoritesProvider);
      // 应该取消收藏
      expect(state.favoriteIds.contains('fav-1'), false);
    });
  });

  group('FavoritesNotifier 并发测试', () {
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

    ProviderContainer createContainerWithAuth() {
      return ProviderContainer(
        overrides: [
          embytokServiceProvider.overrideWithValue(mockService),
          authProvider.overrideWith(
            (ref) => _TestAuthNotifier(ref, testAuthState),
          ),
          favoritesProvider.overrideWith(
            (ref) => FavoritesNotifier(ref),
          ),
        ],
      );
    }

    test('快速连续 toggleFavorite 只执行一次网络请求', () async {
      final existingItems = [
        MediaItem(id: 'fav-1', title: 'Favorite 1', type: 'Movie'),
      ];

      when(mockService.getFavoriteMovies(
        userId: anyNamed('userId'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async => FavoritesPageResult(
        items: existingItems,
        totalCount: existingItems.length,
      ));

      final completer = Completer<void>();
      var callCount = 0;

      when(mockService.toggleFavorite(
        itemId: anyNamed('itemId'),
        isFavorite: anyNamed('isFavorite'),
        userId: anyNamed('userId'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async {
        callCount++;
        await completer.future;
      });

      container = createContainerWithAuth();
      final notifier = container.read(favoritesProvider.notifier);
      await notifier.loadFavorites();

      final newItem = MediaItem(
        id: 'fav-2',
        title: 'New Favorite',
        type: 'Movie',
      );

      final futures = [
        notifier.toggleFavorite(newItem),
        notifier.toggleFavorite(newItem),
        notifier.toggleFavorite(newItem),
      ];

      completer.complete();
      await Future.wait(futures);

      expect(callCount, 1);

      final state = container.read(favoritesProvider);
      expect(state.favoriteIds.contains('fav-2'), true);
    });

    test('网络失败时回滚状态', () async {
      final existingItems = [
        MediaItem(id: 'fav-1', title: 'Favorite 1', type: 'Movie'),
      ];

      when(mockService.getFavoriteMovies(
        userId: anyNamed('userId'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async => FavoritesPageResult(
        items: existingItems,
        totalCount: existingItems.length,
      ));

      when(mockService.toggleFavorite(
        itemId: anyNamed('itemId'),
        isFavorite: anyNamed('isFavorite'),
        userId: anyNamed('userId'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenThrow(Exception('网络错误'));

      container = createContainerWithAuth();
      final notifier = container.read(favoritesProvider.notifier);
      await notifier.loadFavorites();

      final originalIds = container.read(favoritesProvider).favoriteIds;
      final newItem = MediaItem(
        id: 'fav-2',
        title: 'New Favorite',
        type: 'Movie',
      );

      await notifier.toggleFavorite(newItem);

      final state = container.read(favoritesProvider);
      expect(state.favoriteIds, originalIds);
      expect(state.error, isNotNull);
      expect(state.error, contains('切换收藏失败'));
    });

    test('不同 item 并发操作互不干扰', () async {
      when(mockService.getFavoriteMovies(
        userId: anyNamed('userId'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async =>
          const FavoritesPageResult(items: <MediaItem>[], totalCount: 0));

      final completer1 = Completer<void>();
      final completer2 = Completer<void>();
      var call1Count = 0;
      var call2Count = 0;

      when(mockService.toggleFavorite(
        itemId: anyNamed('itemId'),
        isFavorite: anyNamed('isFavorite'),
        userId: anyNamed('userId'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((invocation) async {
        // 命名参数方式：从 namedArguments 获取 itemId
        final itemId = invocation.namedArguments[#itemId] as String;
        if (itemId == 'item-1') {
          call1Count++;
          await completer1.future;
        } else if (itemId == 'item-2') {
          call2Count++;
          await completer2.future;
        }
      });

      container = createContainerWithAuth();
      final notifier = container.read(favoritesProvider.notifier);
      await notifier.loadFavorites();

      final item1 = MediaItem(id: 'item-1', title: 'Item 1', type: 'Movie');
      final item2 = MediaItem(id: 'item-2', title: 'Item 2', type: 'Movie');

      final future1 = notifier.toggleFavorite(item1);
      final future2 = notifier.toggleFavorite(item2);

      completer1.complete();
      completer2.complete();

      await Future.wait([future1, future2]);

      expect(call1Count, 1);
      expect(call2Count, 1);

      final state = container.read(favoritesProvider);
      expect(state.favoriteIds.contains('item-1'), true);
      expect(state.favoriteIds.contains('item-2'), true);
    });

    test('请求进行中再次调用同一 item 被忽略', () async {
      when(mockService.getFavoriteMovies(
        userId: anyNamed('userId'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async =>
          const FavoritesPageResult(items: <MediaItem>[], totalCount: 0));

      final completer = Completer<void>();
      var callCount = 0;

      when(mockService.toggleFavorite(
        itemId: anyNamed('itemId'),
        isFavorite: anyNamed('isFavorite'),
        userId: anyNamed('userId'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async {
        callCount++;
        await completer.future;
      });

      container = createContainerWithAuth();
      final notifier = container.read(favoritesProvider.notifier);
      await notifier.loadFavorites();

      final item = MediaItem(id: 'item-1', title: 'Item 1', type: 'Movie');

      final future1 = notifier.toggleFavorite(item);
      final future2 = notifier.toggleFavorite(item);
      final future3 = notifier.toggleFavorite(item);

      completer.complete();
      await Future.wait([future1, future2, future3]);

      expect(callCount, 1);

      final state = container.read(favoritesProvider);
      expect(state.favoriteIds.contains('item-1'), true);
    });

    test('多个 item 批量切换收藏并发操作', () async {
      when(mockService.getFavoriteMovies(
        userId: anyNamed('userId'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async =>
          const FavoritesPageResult(items: <MediaItem>[], totalCount: 0));

      final completers = <String, Completer<void>>{};
      final callCounts = <String, int>{};

      when(mockService.toggleFavorite(
        itemId: anyNamed('itemId'),
        isFavorite: anyNamed('isFavorite'),
        userId: anyNamed('userId'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((invocation) async {
        // 命名参数方式：从 namedArguments 获取 itemId
        final itemId = invocation.namedArguments[#itemId] as String;
        callCounts[itemId] = (callCounts[itemId] ?? 0) + 1;
        completers[itemId] ??= Completer<void>();
        await completers[itemId]!.future;
      });

      container = createContainerWithAuth();
      final notifier = container.read(favoritesProvider.notifier);
      await notifier.loadFavorites();

      final items = [
        MediaItem(id: 'batch-1', title: 'Batch 1', type: 'Movie'),
        MediaItem(id: 'batch-2', title: 'Batch 2', type: 'Movie'),
        MediaItem(id: 'batch-3', title: 'Batch 3', type: 'Movie'),
        MediaItem(id: 'batch-4', title: 'Batch 4', type: 'Movie'),
        MediaItem(id: 'batch-5', title: 'Batch 5', type: 'Movie'),
      ];

      final futures = items.map((item) => notifier.toggleFavorite(item)).toList();

      for (final completer in completers.values) {
        completer.complete();
      }

      await Future.wait(futures);

      for (final item in items) {
        expect(callCounts[item.id], 1);
      }

      final state = container.read(favoritesProvider);
      for (final item in items) {
        expect(state.favoriteIds.contains(item.id), true);
      }
      expect(state.favoriteIds.length, 5);
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
