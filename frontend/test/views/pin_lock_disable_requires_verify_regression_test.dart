/// PIN 锁关闭必须校验当前 PIN 回归测试
///
/// 缺陷（全仓 UI 审查 P1-1）：设置→安全→PIN 锁对话框，「关闭锁」按钮
/// 直接 `setPin('')`，不校验输入；同框「验证」按钮却有 currentPin 校验，
/// 两条路径不一致 → 任何能进入设置页的人无需当前 PIN 即可关闭 PIN 锁，
/// 家长控制/隐私守卫失效。
/// 修复：「关闭锁」先校验 controller.text == currentPin，不一致提示
/// 「PIN 不正确」并保持启用；一致才关闭。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:embytok_flutter/providers/app_preferences_providers.dart';
import 'package:embytok_flutter/views/settings_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pinChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  /// 预置 PIN 存储：secureStorage.read('app_pin_code') 返回 [storedPin]
  void mockSecureStorage(String? storedPin) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pinChannel, (call) async {
      if (call.method == 'read' && call.arguments is Map) {
        if ((call.arguments as Map)['key'] == 'app_pin_code') {
          return storedPin;
        }
      }
      return null;
    });
  }

  late ProviderContainer container;
  Widget wrap() {
    container = ProviderContainer();
    addTearDown(container.dispose);
    return UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: SettingsView()),
    );
  }

  /// 「应用 PIN 锁」位于「家长控制」二级页内：主列表滚动到分组入口
  /// 点击进入二级页，再点 PIN 锁 tile 打开对话框
  Future<void> openPinDialog(WidgetTester tester) async {
    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('家长控制'), 300,
        scrollable: scrollable);
    await tester.tap(find.text('家长控制'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('应用 PIN 锁'), findsOneWidget,
        reason: '家长控制二级页应含「应用 PIN 锁」');
    await tester.tap(find.text('应用 PIN 锁'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('关闭锁'), findsOneWidget,
        reason: '已启用 PIN 时应显示「关闭锁」按钮');
  }

  testWidgets('关闭锁：输入错误 PIN 被拒绝，PIN 保持启用', (tester) async {
    SharedPreferences.setMockInitialValues({});
    mockSecureStorage('1234');
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await openPinDialog(tester);

    await tester.enterText(find.byType(TextField), '0000');
    await tester.tap(find.text('关闭锁'));
    await tester.pumpAndSettle();

    expect(find.text('PIN 不正确'), findsOneWidget,
        reason: '错误 PIN 关闭锁应被拒绝并提示');
    expect(container.read(pinLockProvider), '1234',
        reason: '错误 PIN 下 PIN 锁不能被关闭');
  });

  testWidgets('关闭锁：输入正确 PIN 后关闭成功', (tester) async {
    SharedPreferences.setMockInitialValues({});
    mockSecureStorage('1234');
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await openPinDialog(tester);

    await tester.enterText(find.byType(TextField), '1234');
    await tester.tap(find.text('关闭锁'));
    await tester.pumpAndSettle();

    expect(find.text('PIN 锁已关闭'), findsOneWidget);
    expect(container.read(pinLockProvider), isEmpty,
        reason: '正确 PIN 校验通过后 PIN 锁才可关闭');
  });
}
