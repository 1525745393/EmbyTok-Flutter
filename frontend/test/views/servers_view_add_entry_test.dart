// 批次6（P3-1）服务器管理页添加入口去重回归测试
//
// 旧实现：AppBar 加号 IconButton 与右下角 FAB 两个入口都调 _showEditSheet，功能重复。
// 修复：保留 FAB（带文字的主操作），移除 AppBar 重复加号。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:embytok_flutter/providers/providers.dart';
import 'package:embytok_flutter/views/servers_view.dart';

import '../mocks/mock_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('仅保留 FAB 单一添加入口，AppBar 不再重复加号', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(ProviderScope(
      overrides: [
        secureStorageProvider.overrideWithValue(MockFlutterSecureStorage()),
      ],
      child: MaterialApp(
        theme: ThemeData(splashFactory: InkRipple.splashFactory),
        home: const ServersView(),
      ),
    ));
    await tester.pumpAndSettle();

    // 全局仅一个 add 图标（位于 FAB 内）
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.text('添加服务器'), findsOneWidget);

    // AppBar actions 内不应再有 add 按钮
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    final appBarAddButtons = appBar.actions
            ?.whereType<IconButton>()
            .where((b) => b.icon is Icon && (b.icon as Icon).icon == Icons.add)
            .length ??
        0;
    expect(appBarAddButtons, 0,
        reason: 'AppBar 加号入口已移除，添加入口统一由 FAB 承担');
  });
}
