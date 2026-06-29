// 验证应用退出流程：所有路径最后都到首页，首页按返回键应弹退出确认
// 重点：根路由下的系统返回键必须被拦截（go_router 13.x 已知问题）
// 重点 2：Feed Tab 内的 VideoPageItem 不能拦截系统返回键（会消费事件，
//         导致 HomeScaffold 的退出确认弹窗永远不会被触发）

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:embbytok_flutter/app.dart';
import 'package:embbytok_flutter/models/models.dart';
import 'package:embbytok_flutter/providers/auth_provider.dart';
import 'package:embbytok_flutter/views/home_scaffold.dart';
import 'package:embbytok_flutter/views/feed_view.dart';

void main() {
  group('退出确认对话框', () {
    testWidgets('首页按系统返回键应显示退出确认', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: EmbyTokApp()),
      );
      await tester.pumpAndSettle();

      await tester.binding.messageBack();
      await tester.pumpAndSettle();

      expect(find.text('退出应用？'), findsOneWidget);
      expect(find.text('确定要退出吗？'), findsOneWidget);
    });

    testWidgets(
      'PR：登录后 Feed Tab 按系统返回键应显示退出确认（修复前会直接退出）',
      (WidgetTester tester) async {
        // 模拟已登录状态：使用一个返回已登录 AuthState 的测试 Notifier
        // （不能直接写 authProvider.notifier.state = ...，因为 StateNotifier.state 是 protected）
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith(
                (ref) => _FakeAuthNotifier(
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
          ),
        );
        await tester.pumpAndSettle();

        // 当前应在 / 根路由（HomeScaffold）
        expect(find.byType(HomeScaffold), findsOneWidget);
        expect(find.byType(FeedView), findsOneWidget);

        // 模拟系统返回键
        await tester.binding.messageBack();
        await tester.pumpAndSettle();

        // 关键断言：必须弹出退出确认弹窗
        // 修复前：FeedView 内的 VideoPageItem PopScope 消费掉事件，直接退出 App，弹窗不会出现
        // 修复后：HomeScaffold 的 PopScope 拦截事件，正确显示弹窗
        expect(find.text('退出应用？'), findsOneWidget);
        expect(find.text('确定要退出吗？'), findsOneWidget);
      },
    );
  });
}

// 测试用 AuthNotifier：直接返回预设的已登录状态，跳过 SharedPreferences 读取
class _FakeAuthNotifier extends StateNotifier<AuthState> {
  _FakeAuthNotifier(AuthState initialState) : super(initialState);
}
