// 登录页服务器类型卡片选择器测试
//
// 覆盖：
// - 卡片网格渲染（Emby 视频 / 群晖音乐）
// - 默认选中 Emby，表单 label 为 Emby 服务器地址
// - 点击群晖卡片后表单动态切换为群晖服务器地址
// - 小屏 320×568 卡片选择器不溢出

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:embytok_flutter/providers/providers.dart';
import 'package:embytok_flutter/views/login_view.dart';

import '../mocks/mock_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildLogin() {
    return ProviderScope(
      overrides: [
        secureStorageProvider.overrideWithValue(MockFlutterSecureStorage()),
      ],
      child: MaterialApp(
        // M2 涟漪规避 Flutter 3.47.2 shader 已知缺陷（见 README）
        theme: ThemeData(splashFactory: InkRipple.splashFactory),
        home: const LoginView(),
      ),
    );
  }

  testWidgets('渲染两张服务器类型卡片，默认选中 Emby', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(buildLogin());
    await tester.pumpAndSettle();

    expect(find.text('Emby 视频'), findsOneWidget);
    expect(find.text('群晖音乐'), findsOneWidget);
    expect(find.text('Emby / Plex 视频流'), findsOneWidget);
    expect(find.text('Audio Station 音乐库'), findsOneWidget);
    // 默认选中 Emby：表单 label 为 Emby 服务器地址
    expect(find.text('Emby 服务器地址'), findsOneWidget);
    expect(find.text('群晖服务器地址'), findsNothing);
  });

  testWidgets('点击群晖卡片 → 表单动态切换为群晖服务器地址', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(buildLogin());
    await tester.pumpAndSettle();

    await tester.tap(find.text('群晖音乐'));
    await tester.pumpAndSettle();

    expect(find.text('群晖服务器地址'), findsOneWidget);
    expect(find.text('Emby 服务器地址'), findsNothing);
    // 提示也切换为群晖地址格式
    expect(find.text('http://192.168.1.100:5000'), findsOneWidget);
  });

  testWidgets('小屏 320×568：卡片选择器不溢出', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildLogin());
    await tester.pumpAndSettle();

    expect(find.text('Emby 视频'), findsOneWidget);
    expect(find.text('群晖音乐'), findsOneWidget);
    expect(tester.takeException(), isNull,
        reason: '小屏下服务器类型卡片不应布局溢出');
  });
}
