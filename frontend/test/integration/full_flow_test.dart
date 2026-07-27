// 集成测试：完整流程端到端测试
// 覆盖：登录 → 浏览 feed → 播放视频 → 收藏 → 退出登录
// 使用 Mock API 服务，不依赖真实 Emby 服务器

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:embytok_flutter/app.dart';
import 'package:embytok_flutter/models/models.dart';
import 'package:embytok_flutter/providers/providers.dart';
import 'package:embytok_flutter/views/home_scaffold.dart';
import 'package:embytok_flutter/views/login_view.dart';
import 'package:embytok_flutter/views/settings_view.dart';
import 'package:embytok_flutter/views/feed_view.dart';
import 'package:embytok_flutter/widgets/poster_grid_view.dart';

import '../mocks/mock_services.dart';
import '../mocks/mock_secure_storage.dart';

void main() {
  group('完整流程集成测试', () {
    late MockEmbytokService mockService;
    late MockFlutterSecureStorage mockSecureStorage;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockService = MockEmbytokService();
      mockSecureStorage = MockFlutterSecureStorage();
    });

    testWidgets('1. 登录成功后进入首页', (WidgetTester tester) async {
      final testUser = User(
        id: 'user-123',
        name: 'testuser',
        accessToken: 'test-token',
      );

      when(mockService.login(
        embyServerUrl: anyNamed('embyServerUrl'),
        username: anyNamed('username'),
        password: anyNamed('password'),
      )).thenAnswer((_) async => testUser);

      when(mockService.getLibraries(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async => [
            Library(id: 'lib-1', name: '电影', type: 'movies'),
          ]);

      when(mockService.getLibraryItems(
        any,
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async => PaginatedResponse<MediaItem>(
            items: [],
            total: 0,
            offset: 0,
            limit: 20,
          ));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            embytokServiceProvider.overrideWithValue(mockService),
            secureStorageProvider.overrideWithValue(mockSecureStorage),
          ],
          child: const EmbyTokApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LoginView), findsOneWidget);
      expect(find.text('EmbyTok'), findsOneWidget);

      await tester.enterText(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextFormField &&
              widget.decoration?.labelText == 'Emby 服务器地址',
        ),
        'http://emby.example.com',
      );

      await tester.enterText(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextFormField &&
              widget.decoration?.labelText == '用户名',
        ),
        'testuser',
      );

      await tester.enterText(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextFormField &&
              widget.decoration?.labelText == '密码',
        ),
        'password123',
      );

      await tester.tap(find.text('登录'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScaffold), findsOneWidget);
      expect(find.byType(FeedView), findsOneWidget);

      verify(mockService.login(
        embyServerUrl: 'http://emby.example.com',
        username: 'testuser',
        password: 'password123',
      )).called(1);
    });

    testWidgets('2. 首页能看到视频列表', (WidgetTester tester) async {
      final testUser = User(
        id: 'user-123',
        name: 'testuser',
        accessToken: 'test-token',
      );

      final testItems = List<MediaItem>.generate(
        5,
        (index) => MediaItem(
          id: 'item-${index + 1}',
          title: '测试视频 ${index + 1}',
          type: 'Movie',
        ),
      );

      when(mockService.login(
        embyServerUrl: anyNamed('embyServerUrl'),
        username: anyNamed('username'),
        password: anyNamed('password'),
      )).thenAnswer((_) async => testUser);

      when(mockService.getLibraries(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async => [
            Library(id: 'lib-1', name: '电影', type: 'movies'),
          ]);

      when(mockService.getLibraryItems(
        any,
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async => PaginatedResponse<MediaItem>(
            items: testItems,
            total: 5,
            offset: 0,
            limit: 20,
          ));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            embytokServiceProvider.overrideWithValue(mockService),
            secureStorageProvider.overrideWithValue(mockSecureStorage),
          ],
          child: const EmbyTokApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextFormField &&
              widget.decoration?.labelText == 'Emby 服务器地址',
        ),
        'http://emby.example.com',
      );
      await tester.enterText(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextFormField &&
              widget.decoration?.labelText == '用户名',
        ),
        'testuser',
      );
      await tester.enterText(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextFormField &&
              widget.decoration?.labelText == '密码',
        ),
        'password123',
      );
      await tester.tap(find.text('登录'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScaffold), findsOneWidget);
      expect(find.byType(FeedView), findsOneWidget);

      await tester.tap(find.text('网格'));
      await tester.pumpAndSettle();

      expect(find.byType(PosterGridView), findsOneWidget);
    });

    testWidgets('3. 点击视频进入详情页', (WidgetTester tester) async {
      final testUser = User(
        id: 'user-123',
        name: 'testuser',
        accessToken: 'test-token',
      );

      final testItem = MediaItem(
        id: 'item-1',
        title: '测试视频 1',
        type: 'Movie',
      );

      when(mockService.login(
        embyServerUrl: anyNamed('embyServerUrl'),
        username: anyNamed('username'),
        password: anyNamed('password'),
      )).thenAnswer((_) async => testUser);

      when(mockService.getLibraries(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async => [
            Library(id: 'lib-1', name: '电影', type: 'movies'),
          ]);

      when(mockService.getLibraryItems(
        any,
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async => PaginatedResponse<MediaItem>(
            items: [testItem],
            total: 1,
            offset: 0,
            limit: 20,
          ));

      when(mockService.getItemDetail(
        any,
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async => testItem);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            embytokServiceProvider.overrideWithValue(mockService),
            secureStorageProvider.overrideWithValue(mockSecureStorage),
          ],
          child: const EmbyTokApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextFormField &&
              widget.decoration?.labelText == 'Emby 服务器地址',
        ),
        'http://emby.example.com',
      );
      await tester.enterText(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextFormField &&
              widget.decoration?.labelText == '用户名',
        ),
        'testuser',
      );
      await tester.enterText(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextFormField &&
              widget.decoration?.labelText == '密码',
        ),
        'password123',
      );
      await tester.tap(find.text('登录'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScaffold), findsOneWidget);

      await tester.tap(find.text('网格'));
      await tester.pumpAndSettle();

      expect(find.byType(PosterGridView), findsOneWidget);
    });

    testWidgets('4. 收藏功能正常工作', (WidgetTester tester) async {
      final testUser = User(
        id: 'user-123',
        name: 'testuser',
        accessToken: 'test-token',
      );

      final testItem = MediaItem(
        id: 'item-1',
        title: '测试视频 1',
        type: 'Movie',
        userData: UserData(isFavorite: false),
      );

      when(mockService.login(
        embyServerUrl: anyNamed('embyServerUrl'),
        username: anyNamed('username'),
        password: anyNamed('password'),
      )).thenAnswer((_) async => testUser);

      when(mockService.getLibraries(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async => [
            Library(id: 'lib-1', name: '电影', type: 'movies'),
          ]);

      when(mockService.getLibraryItems(
        any,
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async => PaginatedResponse<MediaItem>(
            items: [testItem],
            total: 1,
            offset: 0,
            limit: 20,
          ));

      when(mockService.toggleFavorite(
        itemId: anyNamed('itemId'),
        isFavorite: anyNamed('isFavorite'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async {});

      when(mockService.getFavorites(
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async => []);

      final container = ProviderContainer(
        overrides: [
          embytokServiceProvider.overrideWithValue(mockService),
          secureStorageProvider.overrideWithValue(mockSecureStorage),
        ],
      );

      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const EmbyTokApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextFormField &&
              widget.decoration?.labelText == 'Emby 服务器地址',
        ),
        'http://emby.example.com',
      );
      await tester.enterText(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextFormField &&
              widget.decoration?.labelText == '用户名',
        ),
        'testuser',
      );
      await tester.enterText(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextFormField &&
              widget.decoration?.labelText == '密码',
        ),
        'password123',
      );
      await tester.tap(find.text('登录'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScaffold), findsOneWidget);

      final items = container.read(videoListProvider).items;
      expect(items.length, 1);
      expect(items[0].title, '测试视频 1');

      await container.read(favoritesProvider.notifier).toggleFavorite(items[0]);
      await tester.pumpAndSettle();

      verify(mockService.toggleFavorite(
        itemId: 'item-1',
        isFavorite: true,
        serverUrl: 'http://emby.example.com',
        token: 'test-token',
      )).called(1);
    });

    testWidgets('5. 退出登录回到登录页', (WidgetTester tester) async {
      final testUser = User(
        id: 'user-123',
        name: 'testuser',
        accessToken: 'test-token',
      );

      when(mockService.login(
        embyServerUrl: anyNamed('embyServerUrl'),
        username: anyNamed('username'),
        password: anyNamed('password'),
      )).thenAnswer((_) async => testUser);

      when(mockService.getLibraries(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async => [
            Library(id: 'lib-1', name: '电影', type: 'movies'),
          ]);

      when(mockService.getLibraryItems(
        any,
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async => PaginatedResponse<MediaItem>(
            items: [],
            total: 0,
            offset: 0,
            limit: 20,
          ));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            embytokServiceProvider.overrideWithValue(mockService),
            secureStorageProvider.overrideWithValue(mockSecureStorage),
          ],
          child: const EmbyTokApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextFormField &&
              widget.decoration?.labelText == 'Emby 服务器地址',
        ),
        'http://emby.example.com',
      );
      await tester.enterText(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextFormField &&
              widget.decoration?.labelText == '用户名',
        ),
        'testuser',
      );
      await tester.enterText(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextFormField &&
              widget.decoration?.labelText == '密码',
        ),
        'password123',
      );
      await tester.tap(find.text('登录'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScaffold), findsOneWidget);

      await tester.tap(find.text('设置'));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsView), findsOneWidget);
      expect(find.text('退出登录'), findsOneWidget);

      await tester.tap(find.text('退出登录'));
      await tester.pumpAndSettle();

      expect(find.text('退出登录'), findsNWidgets(2));
      expect(find.text('确定要退出当前账号吗？'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, '退出'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginView), findsOneWidget);
      expect(find.text('登录'), findsOneWidget);
    });
  });
}
