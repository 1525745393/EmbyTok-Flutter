// 批次8（P3-8）注册表弹窗用户名校验回归测试
//
// 旧实现：新增/编辑服务器弹窗只校验名称与地址非空，用户名可留空；注册表保存的
// 均为远端服务（Emby/Jellyfin/Plex/群晖），空用户名无法用于快速切换/续期登录。
// 修复：非本地（注册表内全部为远端）类型下用户名纳入必填校验。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:embytok_flutter/providers/auth_provider.dart'
    show secureStorageProvider;
import 'package:embytok_flutter/providers/server_registry_provider.dart';
import 'package:embytok_flutter/views/servers_view.dart';

import '../mocks/mock_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('空用户名保存被拦截，注册表不写入条目', (tester) async {
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

    await tester.tap(find.text('添加服务器'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    // 字段顺序：名称(0)、地址(1)、用户名(2)、密码(3)、内网(4)、外网(5)
    await tester.enterText(fields.at(0), '家里的 Emby');
    await tester.enterText(fields.at(1), 'http://nas.test:8096');
    // 用户名（fields.at(2)）留空
    await tester.ensureVisible(find.text('添加'));
    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
          of: find.byType(SnackBar),
          matching: find.textContaining('用户名')),
      findsOneWidget,
      reason: '用户名为空时应被必填校验拦截并提示',
    );
    // 弹窗未关闭：保存按钮仍在
    expect(find.text('添加'), findsOneWidget);

    final container = ProviderScope.containerOf(
        tester.element(find.byType(ServersView)));
    expect(container.read(serverRegistryProvider), isEmpty,
        reason: '校验拦截后不应写入注册表条目');
  });

  testWidgets('填齐名称/地址/用户名可正常保存到注册表', (tester) async {
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

    await tester.tap(find.text('添加服务器'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '家里的 Emby');
    await tester.enterText(fields.at(1), 'http://nas.test:8096');
    await tester.enterText(fields.at(2), 'tester');
    await tester.ensureVisible(find.text('添加'));
    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
        tester.element(find.byType(ServersView)));
    expect(container.read(serverRegistryProvider), hasLength(1),
        reason: '用户名已填写时应正常写入注册表');
  });
}
