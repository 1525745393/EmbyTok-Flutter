// 为 HomeScaffold 底部导航栏补充单元测试。
//
// 测试范围：
// 1. Tab 切换（NavigationBar 交互）：点击底部导航栏切换 Feed/Favorites/Actors/Settings
// 2. 覆盖层显隐（Provider 层）：goToSearch/goToHistory/backToFeed/goToPage 对
//    isOverlayPage 和 currentIndex 的影响
//
// 已由其他测试文件覆盖、本文件不重复的场景：
// - 退出确认对话框：见 test/views/back_navigation_test.dart
// - applyFeedVisibilityChange / applyLifecyclePlaybackChange 顶层纯函数：
//   见 test/views/feed_autopause_test.dart 和 test/views/lifecycle_autopause_test.dart
//   （两者已用 mockito MockVideoPlayerController 完整覆盖 pause/play 决策、
//   controller=null/未初始化/已暂停、prev=null、中间过渡态、完整往返等场景）
// - PageNavigationState.isFeedVisible 判定（含覆盖层 currentIndex=search/history
//   时 isFeedVisible=false 的已知实现逻辑）：见 test/views/feed_autopause_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:embytok_flutter/app.dart';
import 'package:embytok_flutter/models/models.dart';
import 'package:embytok_flutter/providers/auth_provider.dart';
import 'package:embytok_flutter/providers/page_navigation_provider.dart';
import 'package:embytok_flutter/views/home_scaffold.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ============================================================
  // 测试组 1: Tab 切换（NavigationBar 交互）
  //
  // 通过点击底部导航栏的 NavigationDestination label，验证
  // pageNavigationProvider 的 currentIndex 正确更新。这是 widget
  // 级别的集成测试，覆盖 onDestinationSelected → goToPage → state
  // 更新的完整链路（纯函数测试不覆盖此链路）。
  // ============================================================
  group('Tab 切换', () {
    testWidgets('点击收藏 Tab 应切换到收藏页', (tester) async {
      await tester.pumpWidget(_loggedInApp());
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeScaffold)),
      );
      // 初始应在 Feed Tab（PageNavigationNotifier 构造后 _load 在测试环境
      // 因 SharedPreferences 不可用而失败，state 保持默认值 feed）
      expect(
        container.read(pageNavigationProvider).currentIndex,
        PageIndices.feed,
      );

      await tester.tap(_navLabel('收藏'));
      await tester.pumpAndSettle();

      expect(
        container.read(pageNavigationProvider).currentIndex,
        PageIndices.favorites,
      );
      expect(
        container.read(pageNavigationProvider).isOverlayPage,
        isFalse,
      );
    });

    testWidgets('点击演员 Tab 应切换到演员页', (tester) async {
      await tester.pumpWidget(_loggedInApp());
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeScaffold)),
      );

      await tester.tap(_navLabel('演员'));
      await tester.pumpAndSettle();

      expect(
        container.read(pageNavigationProvider).currentIndex,
        PageIndices.actors,
      );
      expect(
        container.read(pageNavigationProvider).isOverlayPage,
        isFalse,
      );
    });

    testWidgets('点击设置 Tab 应切换到设置页', (tester) async {
      await tester.pumpWidget(_loggedInApp());
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeScaffold)),
      );

      await tester.tap(_navLabel('设置'));
      await tester.pumpAndSettle();

      expect(
        container.read(pageNavigationProvider).currentIndex,
        PageIndices.settings,
      );
      expect(
        container.read(pageNavigationProvider).isOverlayPage,
        isFalse,
      );
    });

    testWidgets('从收藏 Tab 点击首页应切回 Feed', (tester) async {
      await tester.pumpWidget(_loggedInApp());
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeScaffold)),
      );

      // 先切到收藏
      await tester.tap(_navLabel('收藏'));
      await tester.pumpAndSettle();
      expect(
        container.read(pageNavigationProvider).currentIndex,
        PageIndices.favorites,
      );

      // 再点首页，应切回 Feed
      await tester.tap(_navLabel('首页'));
      await tester.pumpAndSettle();
      expect(
        container.read(pageNavigationProvider).currentIndex,
        PageIndices.feed,
      );
      expect(
        container.read(pageNavigationProvider).isOverlayPage,
        isFalse,
      );
    });
  });

  // ============================================================
  // 测试组 2: 覆盖层显隐（Provider 层）
  //
  // 直接通过 ProviderContainer 测试 PageNavigationNotifier 的
  // goToSearch/goToHistory/backToFeed/goToPage 方法对 isOverlayPage
  // 和 currentIndex 的影响。
  //
  // 现有测试只验证了 PageNavigationState.isFeedVisible 的判定（构造
  // 固定 state 直接断言），未覆盖 Notifier 方法本身的状态迁移行为，
  // 本组补充这一缺口。
  // ============================================================
  group('覆盖层显隐', () {
    test('goToSearch 应设置 currentIndex=search 且 isOverlayPage=true', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // 触发 PageNavigationNotifier 构造（构造函数会异步调用 _load）
      container.read(pageNavigationNotifierProvider);
      // 让出 microtask：_load 内部 await SharedPreferences.getInstance()
      // 在测试环境无 mock 会抛 MissingPluginException，被 try-catch 吞掉，
      // state 保持初始值 (feed, false)。等待其完成避免与后续断言竞态。
      await Future.delayed(Duration.zero);

      final notifier = container.read(pageNavigationNotifierProvider);
      notifier.goToSearch();

      final state = container.read(pageNavigationProvider);
      expect(state.currentIndex, PageIndices.search);
      expect(state.isOverlayPage, isTrue);
    });

    test('goToHistory 应设置 currentIndex=history 且 isOverlayPage=true', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(pageNavigationNotifierProvider);
      await Future.delayed(Duration.zero);

      final notifier = container.read(pageNavigationNotifierProvider);
      notifier.goToHistory();

      final state = container.read(pageNavigationProvider);
      expect(state.currentIndex, PageIndices.history);
      expect(state.isOverlayPage, isTrue);
    });

    test('backToFeed 应从覆盖层回到 currentIndex=feed 且 isOverlayPage=false', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(pageNavigationNotifierProvider);
      await Future.delayed(Duration.zero);

      final notifier = container.read(pageNavigationNotifierProvider);
      // 先进入覆盖层
      notifier.goToSearch();
      expect(container.read(pageNavigationProvider).isOverlayPage, isTrue);

      // 再回到 Feed
      notifier.backToFeed();

      final state = container.read(pageNavigationProvider);
      expect(state.currentIndex, PageIndices.feed);
      expect(state.isOverlayPage, isFalse);
    });

    test('goToPage 应从覆盖层切回主 Tab 且 isOverlayPage=false', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(pageNavigationNotifierProvider);
      await Future.delayed(Duration.zero);

      final notifier = container.read(pageNavigationNotifierProvider);
      // 先进入搜索覆盖层
      notifier.goToSearch();
      expect(container.read(pageNavigationProvider).isOverlayPage, isTrue);

      // 再切到收藏主 Tab
      notifier.goToPage(PageIndices.favorites);

      final state = container.read(pageNavigationProvider);
      expect(state.currentIndex, PageIndices.favorites);
      expect(state.isOverlayPage, isFalse);
    });
  });
}

/// 在 NavigationBar 范围内查找指定 label 的 widget
///
/// 限制查找范围避免误匹配页面内容中的同名文本（IndexedStack 同时
/// 存活 Feed/Favorites/Actors/Settings 四个 Tab 视图，FavoritesView
/// 等内部可能包含"收藏"字样）。
Finder _navLabel(String label) {
  return find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text(label),
  );
}

/// 构造已登录状态的 EmbyTokApp，用于需要进入首页（HomeScaffold）的测试
///
/// 使用 _FakeAuthNotifier 跳过 _loadFromStorage 异步加载，
/// 直接设置已登录的 AuthState。模式参考 back_navigation_test.dart。
Widget _loggedInApp() {
  return ProviderScope(
    overrides: [
      authProvider.overrideWith(
        (ref) => _FakeAuthNotifier(
          ref,
          const AuthState(
            isAuthenticated: true,
            user: User(
              id: 'test-user',
              name: 'test',
              accessToken: 'test-token',
            ),
            embyServerUrl: 'http://emby.example.com',
            token: 'test-token',
          ),
        ),
      ),
    ],
    child: const EmbyTokApp(),
  );
}

// 测试用 AuthNotifier：继承 AuthNotifier，跳过 _loadFromStorage 异步加载
// 与 back_navigation_test.dart 中的 _FakeAuthNotifier 实现一致
class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(Ref ref, AuthState initialState) : super(ref) {
    state = initialState;
  }
}
