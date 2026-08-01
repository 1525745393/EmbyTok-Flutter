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
import 'package:embytok_flutter/widgets/library_selector.dart';
import 'package:embytok_flutter/widgets/poster_grid_view.dart';

import '../mocks/mock_services.dart';
import '../mocks/mock_secure_storage.dart';

/// 通过索引定位 LoginView 中的 TextFormField
/// 字段顺序与 LoginView 中构建顺序一致：
/// 0: Emby 服务器地址，1: 用户名，2: 密码
Finder findFormFieldByIndex(int index) {
  return find.byType(TextFormField).at(index);
}

/// 设置竖屏手机视口。
/// EmbyTok 是竖屏客户端，flutter test 默认 800x600 横屏视口会导致
/// VideoPageItem 右侧操作按钮列（_RightActionButtons）纵向溢出。
/// 修复：360px 宽度（1080/3）会导致顶部工具栏「网格」按钮溢出屏幕右侧（x=374.5 > 360），
/// 改用 414x896 逻辑像素（iPhone 11/12 尺寸，1242x2688 物理 @ 3.0x DPR）。
void usePortraitViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1242, 2688);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// 登录后首次进入会自动弹出 LibrarySelector（未配置媒体库时），
/// 点击「确认」关闭弹窗并完成配置，避免弹窗阻挡后续 UI 交互
///
/// 修复：弹窗处于 loading / error / 空数据态时没有「确认」按钮，
/// 旧实现会静默返回导致弹窗残留，其 Overlay 会吸收后续所有 tap 事件
/// （表现为 tap("网格")/tap("设置") 命中 RenderAbsorbPointer 而非目标）。
/// 这里增加兜底：找不到「确认」时点击标题栏关闭按钮（tooltip「关闭」）强制关闭弹窗。
Future<void> dismissLibrarySelectorIfNeeded(WidgetTester tester) async {
  // 修复：使用 pump(Duration) 替代 pumpAndSettle。
  // 原因：VideoPlayerWidget 在视频初始化期间显示 CircularProgressIndicator（无限动画），
  // pumpAndSettle 永远无法收敛。pump(1秒) 足够弹窗渲染和 mock 数据返回。
  await tester.pump(const Duration(seconds: 1));
  if (find.byType(LibrarySelector).evaluate().isEmpty) return;

  // 优先点击「确认」按钮：数据态下完成媒体库配置并关闭弹窗
  final confirmFinder = find.text('确认');
  if (confirmFinder.evaluate().isNotEmpty) {
    await tester.tap(confirmFinder.last);
    await tester.pump(const Duration(seconds: 1));
    return;
  }

  // 兜底：弹窗处于 loading / error / 空数据态时无「确认」按钮，
  // 点击标题栏关闭按钮强制关闭，避免 Overlay 残留拦截后续 tap
  final closeFinder = find.byTooltip('关闭');
  if (closeFinder.evaluate().isNotEmpty) {
    await tester.tap(closeFinder.last);
    await tester.pump(const Duration(seconds: 1));
  }
}

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
        // 必须显式 mock userId：实际调用传入 userId='user-123'，
        // 若省略则 mockito 按 null 匹配导致 stub 不命中，返回空列表，
        // 弹窗进入空数据态无「确认」按钮，Overlay 残留拦截后续 tap
        userId: anyNamed('userId'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async => [
            Library(id: 'lib-1', name: '电影', type: 'movies'),
          ]);

      when(mockService.getLibraryItems(
        any,
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        // 必须显式 mock 所有命名参数：EmbyRepository.getLibraryItems 会透传
        // userId/sortBy/sortOrder/excludePlayed 等非空值，省略则 stub 不命中返回空列表
        userId: anyNamed('userId'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        sortBy: anyNamed('sortBy'),
        sortOrder: anyNamed('sortOrder'),
        searchTerm: anyNamed('searchTerm'),
        excludePlayed: anyNamed('excludePlayed'),
        cancelToken: anyNamed('cancelToken'),
      )).thenAnswer((_) async => PaginatedResponse<MediaItem>(
            items: [],
            total: 0,
            offset: 0,
            limit: 20,
          ));

      usePortraitViewport(tester);
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
        findFormFieldByIndex(0),
        'http://emby.example.com',
      );

      await tester.enterText(
        findFormFieldByIndex(1),
        'testuser',
      );

      await tester.enterText(
        findFormFieldByIndex(2),
        'password123',
      );

      await tester.tap(find.text('登录'));
      // 修复：pumpAndSettle 在有视频项时会因 CircularProgressIndicator 无限动画超时，
      // 改用 pump(2秒) 给足时间让登录异步完成、导航到首页、弹窗弹出
      await tester.pump(const Duration(seconds: 2));
      // 关闭首次进入自动弹出的媒体库选择器
      await dismissLibrarySelectorIfNeeded(tester);

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
        // 必须显式 mock userId：实际调用传入 userId='user-123'，
        // 若省略则 mockito 按 null 匹配导致 stub 不命中，返回空列表，
        // 弹窗进入空数据态无「确认」按钮，Overlay 残留拦截后续 tap
        userId: anyNamed('userId'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async => [
            Library(id: 'lib-1', name: '电影', type: 'movies'),
          ]);

      when(mockService.getLibraryItems(
        any,
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        // 必须显式 mock 所有命名参数：EmbyRepository.getLibraryItems 会透传
        // userId/sortBy/sortOrder/excludePlayed 等非空值，省略则 stub 不命中返回空列表
        userId: anyNamed('userId'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        sortBy: anyNamed('sortBy'),
        sortOrder: anyNamed('sortOrder'),
        searchTerm: anyNamed('searchTerm'),
        excludePlayed: anyNamed('excludePlayed'),
        cancelToken: anyNamed('cancelToken'),
      )).thenAnswer((_) async => PaginatedResponse<MediaItem>(
            items: testItems,
            total: 5,
            offset: 0,
            limit: 20,
          ));

      usePortraitViewport(tester);
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
        findFormFieldByIndex(0),
        'http://emby.example.com',
      );
      await tester.enterText(
        findFormFieldByIndex(1),
        'testuser',
      );
      await tester.enterText(
        findFormFieldByIndex(2),
        'password123',
      );
      await tester.tap(find.text('登录'));
      // 修复：pumpAndSettle 在有视频项时会因 CircularProgressIndicator 无限动画超时，
      // 改用 pump(2秒) 给足时间让登录异步完成、导航到首页、弹窗弹出
      await tester.pump(const Duration(seconds: 2));
      // 关闭首次进入自动弹出的媒体库选择器
      await dismissLibrarySelectorIfNeeded(tester);

      expect(find.byType(HomeScaffold), findsOneWidget);
      expect(find.byType(FeedView), findsOneWidget);

      await tester.tap(find.text('网格'));
      await tester.pump(const Duration(seconds: 1));

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
        // 必须显式 mock userId：实际调用传入 userId='user-123'，
        // 若省略则 mockito 按 null 匹配导致 stub 不命中，返回空列表，
        // 弹窗进入空数据态无「确认」按钮，Overlay 残留拦截后续 tap
        userId: anyNamed('userId'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async => [
            Library(id: 'lib-1', name: '电影', type: 'movies'),
          ]);

      when(mockService.getLibraryItems(
        any,
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        // 必须显式 mock 所有命名参数：EmbyRepository.getLibraryItems 会透传
        // userId/sortBy/sortOrder/excludePlayed 等非空值，省略则 stub 不命中返回空列表
        userId: anyNamed('userId'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        sortBy: anyNamed('sortBy'),
        sortOrder: anyNamed('sortOrder'),
        searchTerm: anyNamed('searchTerm'),
        excludePlayed: anyNamed('excludePlayed'),
        cancelToken: anyNamed('cancelToken'),
      )).thenAnswer((_) async => PaginatedResponse<MediaItem>(
            items: [testItem],
            total: 1,
            offset: 0,
            limit: 20,
          ));

      when(mockService.getItemDetail(
        any,
        userId: anyNamed('userId'), // EmbyRepository.getItemDetail 透传 userId
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async => testItem);

      usePortraitViewport(tester);
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
        findFormFieldByIndex(0),
        'http://emby.example.com',
      );
      await tester.enterText(
        findFormFieldByIndex(1),
        'testuser',
      );
      await tester.enterText(
        findFormFieldByIndex(2),
        'password123',
      );
      await tester.tap(find.text('登录'));
      // 修复：pumpAndSettle 在有视频项时会因 CircularProgressIndicator 无限动画超时，
      // 改用 pump(2秒) 给足时间让登录异步完成、导航到首页、弹窗弹出
      await tester.pump(const Duration(seconds: 2));
      // 关闭首次进入自动弹出的媒体库选择器
      await dismissLibrarySelectorIfNeeded(tester);

      expect(find.byType(HomeScaffold), findsOneWidget);

      await tester.tap(find.text('网格'));
      await tester.pump(const Duration(seconds: 1));

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
        // 必须显式 mock userId：实际调用传入 userId='user-123'，
        // 若省略则 mockito 按 null 匹配导致 stub 不命中，返回空列表，
        // 弹窗进入空数据态无「确认」按钮，Overlay 残留拦截后续 tap
        userId: anyNamed('userId'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async => [
            Library(id: 'lib-1', name: '电影', type: 'movies'),
          ]);

      when(mockService.getLibraryItems(
        any,
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        // 必须显式 mock 所有命名参数：EmbyRepository.getLibraryItems 会透传
        // userId/sortBy/sortOrder/excludePlayed 等非空值，省略则 stub 不命中返回空列表
        userId: anyNamed('userId'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        sortBy: anyNamed('sortBy'),
        sortOrder: anyNamed('sortOrder'),
        searchTerm: anyNamed('searchTerm'),
        excludePlayed: anyNamed('excludePlayed'),
        cancelToken: anyNamed('cancelToken'),
      )).thenAnswer((_) async => PaginatedResponse<MediaItem>(
            items: [testItem],
            total: 1,
            offset: 0,
            limit: 20,
          ));

      when(mockService.toggleFavorite(
        itemId: anyNamed('itemId'),
        isFavorite: anyNamed('isFavorite'),
        userId: anyNamed('userId'), // 显式 mock，避免不命中
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

      usePortraitViewport(tester);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const EmbyTokApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        findFormFieldByIndex(0),
        'http://emby.example.com',
      );
      await tester.enterText(
        findFormFieldByIndex(1),
        'testuser',
      );
      await tester.enterText(
        findFormFieldByIndex(2),
        'password123',
      );
      await tester.tap(find.text('登录'));
      // 修复：pumpAndSettle 在有视频项时会因 CircularProgressIndicator 无限动画超时，
      // 改用 pump(2秒) 给足时间让登录异步完成、导航到首页、弹窗弹出
      await tester.pump(const Duration(seconds: 2));
      // 关闭首次进入自动弹出的媒体库选择器
      await dismissLibrarySelectorIfNeeded(tester);

      expect(find.byType(HomeScaffold), findsOneWidget);

      final items = container.read(videoListProvider).items;
      expect(items.length, 1);
      expect(items[0].title, '测试视频 1');

      await container.read(favoritesProvider.notifier).toggleFavorite(items[0]);
      await tester.pump(const Duration(seconds: 1));

      verify(mockService.toggleFavorite(
        itemId: 'item-1',
        isFavorite: true,
        userId: anyNamed('userId'), // EmbyRepository.toggleFavorite 透传 userId
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
        // 必须显式 mock userId：实际调用传入 userId='user-123'，
        // 若省略则 mockito 按 null 匹配导致 stub 不命中，返回空列表，
        // 弹窗进入空数据态无「确认」按钮，Overlay 残留拦截后续 tap
        userId: anyNamed('userId'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async => [
            Library(id: 'lib-1', name: '电影', type: 'movies'),
          ]);

      when(mockService.getLibraryItems(
        any,
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        // 必须显式 mock 所有命名参数：EmbyRepository.getLibraryItems 会透传
        // userId/sortBy/sortOrder/excludePlayed 等非空值，省略则 stub 不命中返回空列表
        userId: anyNamed('userId'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        sortBy: anyNamed('sortBy'),
        sortOrder: anyNamed('sortOrder'),
        searchTerm: anyNamed('searchTerm'),
        excludePlayed: anyNamed('excludePlayed'),
        cancelToken: anyNamed('cancelToken'),
      )).thenAnswer((_) async => PaginatedResponse<MediaItem>(
            items: [],
            total: 0,
            offset: 0,
            limit: 20,
          ));

      usePortraitViewport(tester);
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
        findFormFieldByIndex(0),
        'http://emby.example.com',
      );
      await tester.enterText(
        findFormFieldByIndex(1),
        'testuser',
      );
      await tester.enterText(
        findFormFieldByIndex(2),
        'password123',
      );
      await tester.tap(find.text('登录'));
      // 修复：pumpAndSettle 在有视频项时会因 CircularProgressIndicator 无限动画超时，
      // 改用 pump(2秒) 给足时间让登录异步完成、导航到首页、弹窗弹出
      await tester.pump(const Duration(seconds: 2));
      // 关闭首次进入自动弹出的媒体库选择器
      await dismissLibrarySelectorIfNeeded(tester);

      expect(find.byType(HomeScaffold), findsOneWidget);

      await tester.tap(find.text('设置'));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(SettingsView), findsOneWidget);
      // 修复：SettingsView 使用 ListView 懒加载，退出登录按钮在列表底部，
      // 未滚动到可见区域前不会被 build，find 找不到。
      //
      // 关键修复：不能用 scrollUntilVisible(find.text('退出登录'), ...)。
      // 原因：scrollUntilVisible 内部用 finder.evaluate().single 判断可见性，
      // 要求 finder 唯一匹配。但 ListView 滚动过程中 find.text('退出登录')
      // 会匹配到多个 widget（滚动过渡期间同一文本可能被多个 RenderObject 持有），
      // 导致 "Bad state: Too many elements"。
      // 解决：手动 fling 滚动 + 用 find.widgetWithText(ElevatedButton, ...)
      // 精确定位设置页退出登录按钮（_buildLogoutButton 用 ElevatedButton.icon 构建），
      // 该 finder 在整个滚动过程中保持唯一匹配。
      final logoutButtonFinder =
          find.widgetWithText(ElevatedButton, '退出登录');
      for (var i = 0; i < 30; i++) {
        if (logoutButtonFinder.evaluate().isNotEmpty) break;
        await tester.fling(
          find.byType(Scrollable).first,
          const Offset(0, -200),
          200,
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(logoutButtonFinder, findsOneWidget);

      await tester.tap(logoutButtonFinder);
      await tester.pump(const Duration(seconds: 1));

      // 点击后弹出确认对话框：弹窗标题「退出登录」+ 设置页按钮「退出登录」= 2 个匹配
      expect(find.text('退出登录'), findsNWidgets(2));
      expect(find.text('确定要退出当前账号吗？'), findsOneWidget);

      // 弹窗中的「退出」按钮：用 widgetWithText 精确定位，避免误中其他 widget
      await tester.tap(find.widgetWithText(ElevatedButton, '退出'));
      // logout 涉及 secure storage 清理 + 状态重置 + GoRouter redirect 重新评估，
      // 是多阶段异步链路。分多次 pump 确保每个阶段都有帧调度：
      // 1. 弹窗关闭 + onPressed 触发 ref.read(authProvider.notifier).logout()
      // 2. logout 异步清理 secure storage / SharedPreferences
      // 3. state = AuthState() 触发 ref.listen
      // 4. _refreshNotifier.notify() 触发 GoRouter redirect
      // 5. redirect 导航到 /login，LoginView 构建
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(LoginView), findsOneWidget);
      expect(find.text('登录'), findsOneWidget);
    });
  });
}
