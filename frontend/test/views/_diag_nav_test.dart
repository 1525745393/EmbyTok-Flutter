// 临时诊断测试：定位 HomeScaffold 缺失根因（定位后删除）
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:embytok_flutter/app.dart';
import 'package:embytok_flutter/models/models.dart';
import 'package:embytok_flutter/providers/app_preferences_providers.dart';
import 'package:embytok_flutter/providers/auth_provider.dart';
import 'package:embytok_flutter/providers/service_mode_provider.dart';
import 'package:embytok_flutter/views/home_scaffold.dart';
import 'package:embytok_flutter/views/login_view.dart';
import 'package:embytok_flutter/views/main_view.dart';
import 'package:embytok_flutter/views/pin_lock_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('diag: dump render tree', (WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
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
    ));
    await tester.pumpAndSettle();

    debugPrint('DIAG hasHome=${find.byType(HomeScaffold).evaluate().length}');
    debugPrint('DIAG hasLogin=${find.byType(LoginView).evaluate().length}');
    debugPrint('DIAG hasMain=${find.byType(MainView).evaluate().length}');
    debugPrint('DIAG hasPin=${find.byType(PinLockScreen).evaluate().length}');

    final types = tester.allWidgets.map((w) => w.runtimeType.toString()).take(50).toList();
    debugPrint('DIAG tree=$types');

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp).first),
    );
    debugPrint('DIAG auth=${container.read(authProvider).isAuthenticated}');
    debugPrint('DIAG mode=${container.read(serviceModeProvider)}');
    debugPrint('DIAG pin=${container.read(pinLockProvider)}');

    // 实验 1：ensureLoaded 是否挂起
    final pinN = container.read(pinLockProvider.notifier);
    try {
      await pinN.ensureLoaded().timeout(const Duration(seconds: 5));
      debugPrint('DIAG ensureLoaded=done');
    } on TimeoutException {
      debugPrint('DIAG ensureLoaded=TIMEOUT');
    }

    // 实验 2：tree 中是否有 Router/Navigator
    final all = tester.allWidgets
        .map((w) => w.runtimeType.toString())
        .where((t) =>
            t.contains('Router') ||
            t.contains('Navigator') ||
            t.contains('Page') ||
            t.contains('Loading') ||
            t.contains('Error'))
        .take(20)
        .toList();
    debugPrint('DIAG routerParts=$all');

    expect(true, isTrue);
  });
}

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(super.ref, AuthState initialState) {
    state = initialState;
  }
}
