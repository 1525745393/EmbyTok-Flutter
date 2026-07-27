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
      expect(state.items, isEmpty);
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
          embytokServiceProvider.overrideWithValue(mockService),
          authProvider.overrideWith((ref) => _TestAuthNotifier(testAuthState)),
          favoritesProvider.overrideWith(
            (ref) => FavoritesNotifier(ref),
          ),
        ],
      );
    }

    test('初始状态', () {
      container = createContainerWithAuth();

      final state = container.read(favoritesProvider);
      expect(state.items, isEmpty);
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
      expect(state.items.length, 3);
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
      expect(state.items, isEmpty);
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
          embytokServiceProvider.overrideWithValue(mockService),
          authProvider.overrideWith(
            (ref) => _TestAuthNotifier(const AuthState()),
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
      expect(state.items.any((e) => e.id == 'fav-2'), true);
      expect(state.items.first.id, 'fav-2'); // 新收藏插入到列表头部
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
      expect(state.items.any((e) => e.id == 'fav-1'), false);
      expect(state.items.length, 1);
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
      expect(state.items.length, 1);
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
      expect(state.items.length, 2);
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
          embytokServiceProvider.overrideWithValue(mockService),
          authProvider.overrideWith(
            (ref) => _TestAuthNotifier(const AuthState()),
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
          authProvider.overrideWith((ref) => _TestAuthNotifier(testAuthState)),
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

      when(mockService.getFavorites(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async => existingItems);

      final completer = Completer<void>();
      var callCount = 0;

      when(mockService.toggleFavorite(
        any,
        any,
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async {
        callCount++;
        await completer.future;
      });

      container = createContainerWithAuth();
      final notifier = container.read(favoritesProvider.notifier);
      await notifier.loadFavorites();

      final newItem = MediaItem(id: 'fav-2', title: 'New Favorite', type: 'Movie');

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

      when(mockService.getFavorites(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async => existingItems);

      when(mockService.toggleFavorite(
        any,
        any,
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenThrow(Exception('网络错误'));

      container = createContainerWithAuth();
      final notifier = container.read(favoritesProvider.notifier);
      await notifier.loadFavorites();

      final originalIds = container.read(favoritesProvider).favoriteIds;
      final newItem = MediaItem(id: 'fav-2', title: 'New Favorite', type: 'Movie');

      await notifier.toggleFavorite(newItem);

      final state = container.read(favoritesProvider);
      expect(state.favoriteIds, originalIds);
      expect(state.error, isNotNull);
      expect(state.error, contains('切换收藏失败'));
    });

    test('不同 item 并发操作互不干扰', () async {
      when(mockService.getFavorites(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async => []);

      final completer1 = Completer<void>();
      final completer2 = Completer<void>();
      var call1Count = 0;
      var call2Count = 0;

      when(mockService.toggleFavorite(
        any,
        any,
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((invocation) async {
        final itemId = invocation.positionalArguments.isNotEmpty
            ? invocation.positionalArguments[0] as String
            : invocation.namedArguments[#itemId] as String;
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
      when(mockService.getFavorites(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async => []);

      final completer = Completer<void>();
      var callCount = 0;

      when(mockService.toggleFavorite(
        any,
        any,
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
      when(mockService.getFavorites(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async => []);

      final completers = <String, Completer<void>>{};
      final callCounts = <String, int>{};

      when(mockService.toggleFavorite(
        any,
        any,
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((invocation) async {
        final itemId = invocation.positionalArguments.isNotEmpty
            ? invocation.positionalArguments[0] as String
            : invocation.namedArguments[#itemId] as String;
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

// 测试用 AuthNotifier：直接返回预设状态
class _TestAuthNotifier extends StateNotifier<AuthState> {
  _TestAuthNotifier(AuthState initialState) : super(initialState);
}
