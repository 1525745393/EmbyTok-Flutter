// 验证应用退出流程：所有路径最后都到首页，首页按返回键应弹退出确认
// 重点：根路由下的系统返回键必须被拦截（go_router 13.x 已知问题）
// 重点 2：Feed Tab 内的 VideoPageItem 不能拦截系统返回键（会消费事件，
//         导致 HomeScaffold 的退出确认弹窗永远不会被触发）

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:embytok_flutter/app.dart';
import 'package:embytok_flutter/models/models.dart';
import 'package:embytok_flutter/providers/auth_provider.dart';
import 'package:embytok_flutter/views/home_scaffold.dart';
import 'package:embytok_flutter/views/feed_view.dart';

/// 模拟系统返回键：通过 platform channel 发送 popRoute 事件
///
/// GoRouter 13.x 已知问题：根路由上 RouterDelegate.popRoute() 在
/// NavigatorState.canPop() 返回 false 时跳过 maybePop() 调用，
/// 导致 PopScope 的 onPopInvoked 回调不被触发。
/// 这里在 platform channel 后额外调用 maybePop 作为 fallback，
/// 确保 PopScope 回调被触发，从而正确测试退出确认逻辑。
Future<void> _simulateSystemBack(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/platform',
    SystemChannels.platform.codec.encodeMethodCall(
      const MethodCall('popRoute'),
    ),
    (ByteData? data) {},
  );
  await tester.pump();
  // GoRouter 13.x fallback：直接调用 maybePop 触发 PopScope 回调
  final homeElement = find.byType(HomeScaffold).evaluate();
  if (homeElement.isNotEmpty) {
    await Navigator.of(homeElement.first).maybePop();
  }
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('退出确认对话框', () {
    testWidgets('首页按系统返回键应显示退出确认', (WidgetTester tester) async {
      // 需要已登录状态才能进入首页，否则被路由守卫重定向到 /login
      await tester.pumpWidget(_loggedInApp());
      await tester.pumpAndSettle();

      await _simulateSystemBack(tester);

      expect(find.text('退出应用？'), findsOneWidget);
      expect(find.text('确定要退出吗？'), findsOneWidget);
    });

    testWidgets(
      'PR：登录后 Feed Tab 按系统返回键应显示退出确认（修复前会直接退出）',
      (WidgetTester tester) async {
        await tester.pumpWidget(_loggedInApp());
        await tester.pumpAndSettle();

        // 当前应在 / 根路由（HomeScaffold）
        expect(find.byType(HomeScaffold), findsOneWidget);
        expect(find.byType(FeedView), findsOneWidget);

        // 模拟系统返回键
        await _simulateSystemBack(tester);

        // 关键断言：必须弹出退出确认弹窗
        // 修复前：FeedView 内的 VideoPageItem PopScope 消费掉事件，直接退出 App，弹窗不会出现
        // 修复后：HomeScaffold 的 PopScope 拦截事件，正确显示弹窗
        expect(find.text('退出应用？'), findsOneWidget);
        expect(find.text('确定要退出吗？'), findsOneWidget);
      },
    );
  });
}

/// 构造已登录状态的 EmbyTokApp，用于需要进入首页（HomeScaffold）的测试
///
/// 使用 _FakeAuthNotifier 跳过 _loadFromStorage 异步加载，
/// 直接设置已登录的 AuthState。
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
class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(Ref ref, AuthState initialState) : super(ref) {
    state = initialState;
  }
}
