// 批次8（P3-7）群晖账号「默认」标记移除回归测试
//
// 旧实现：账号切换 sheet 对 isDefault 账号显示「默认」角标，非当前账号提供
// 星形「设为默认」按钮；但启动恢复（_restore）只按 url/account/sid 登录，
// 并不读取默认账号，标记与实际启动行为脱节、具误导性。
// 修复（D2）：移除默认角标与「设为默认」入口，不做启动回退默认账号登录。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:embytok_flutter/providers/auth_provider.dart'
    show secureStorageProvider;
import 'package:embytok_flutter/providers/syno_accounts_provider.dart';
import 'package:embytok_flutter/views/account_switch_sheet.dart';

import '../mocks/mock_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('账号切换 sheet 不展示默认角标与设为默认入口', (tester) async {
    SharedPreferences.setMockInitialValues({});
    late WidgetRef capturedRef;

    await tester.pumpWidget(ProviderScope(
      overrides: [
        secureStorageProvider.overrideWithValue(MockFlutterSecureStorage()),
      ],
      child: MaterialApp(
        theme: ThemeData(splashFactory: InkRipple.splashFactory),
        home: Consumer(
          builder: (context, ref, _) {
            capturedRef = ref;
            return ElevatedButton(
              onPressed: () => showAccountSwitchSheet(context, ref),
              child: const Text('open'),
            );
          },
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // 让构造期异步 _load() 落定，再写入两个账号（a1 为当前，a2 非当前）
    capturedRef.read(synoAccountsProvider);
    await tester.pump(const Duration(milliseconds: 10));
    final accounts = capturedRef.read(synoAccountsProvider.notifier);
    final a1 = await accounts.addAccount(
        serverUrl: 'http://nas1.test:5000', username: 'alice', password: 'p1');
    await accounts.addAccount(
        serverUrl: 'http://nas2.test:5000', username: 'bob', password: 'p2');
    await accounts.setCurrent(a1.accountId);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('alice'), findsOneWidget);
    expect(find.text('bob'), findsOneWidget);
    // 不再有「默认」角标文本
    expect(find.text('默认'), findsNothing);
    // 非当前账号行不再提供「设为默认」星形入口
    expect(find.byTooltip('设为默认'), findsNothing);
  });
}
