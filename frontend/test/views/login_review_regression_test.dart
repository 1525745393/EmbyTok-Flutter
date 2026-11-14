// 登录界面复审（2026-11-09）修复回归测试
//
// 覆盖：
// - P2：未登录时 /servers 不再被登录守卫弹回登录页；其他受保护页面仍被拦截
// - P3：重新登录（registry.update 按键整体替换）保留已记忆的 libraryIds
// - P3：未勾选「记住密码」时群晖 sid 不写回注册表，并清除旧 sid

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:embytok_flutter/app.dart';
import 'package:embytok_flutter/models/models.dart';
import 'package:embytok_flutter/providers/auth_provider.dart';
import 'package:embytok_flutter/providers/providers.dart';
import 'package:embytok_flutter/providers/server_registry_provider.dart';
import 'package:embytok_flutter/providers/service_mode_provider.dart';
import 'package:embytok_flutter/providers/synology_auth_provider.dart';
import 'package:embytok_flutter/services/services.dart';
import 'package:embytok_flutter/views/login_view.dart';
import 'package:embytok_flutter/views/servers_view.dart';

import '../mocks/mock_secure_storage.dart';
import '../mocks/mock_services.dart';

/// 群晖 Audio Station 登录桩：固定返回 sid
class _FakeSynoLoginAudioApi extends SynologyAudioApi {
  @override
  Future<String> login({
    required String serverUrl,
    required String account,
    required String password,
    String? otpCode,
    String? deviceId,
  }) async {
    return 'fake-sid';
  }
}

/// 用给定容器挂载 LoginView（带 '/' 以便登录成功后 context.go('/')）
Future<void> _pumpLogin(ProviderContainer container, WidgetTester tester) async {
  final router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginView()),
      GoRoute(path: '/', builder: (_, __) => const Scaffold(body: Text('首页'))),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        // M2 涟漪规避 Flutter 3.47.2 shader 已知缺陷（与 login_view_test 一致）
        theme: ThemeData(splashFactory: InkRipple.splashFactory),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// 填充表单并通过密码框 done 提交（避免 tap 按钮叠加连接测试状态机）
Future<void> _fillAndSubmit(
  WidgetTester tester, {
  required String server,
  required String username,
  required String password,
}) async {
  await tester.enterText(find.byType(TextFormField).at(0), server);
  await tester.enterText(find.byType(TextFormField).at(1), username);
  await tester.enterText(find.byType(TextFormField).at(2), password);
  await tester.pump();
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('P2：未登录可直接进入 /servers，其他受保护页面仍回登录页', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(MockFlutterSecureStorage()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const EmbyTokApp(),
    ));
    await tester.pumpAndSettle();

    // 前置：未登录停在登录页
    expect(find.byType(LoginView), findsOneWidget);

    // 登录页「服务器与账户 → 服务器管理」走的就是 /servers
    GoRouter.of(tester.element(find.byType(LoginView))).go('/servers');
    await tester.pumpAndSettle();
    expect(find.byType(ServersView), findsOneWidget,
        reason: '未登录访问 /servers 不应被登录守卫弹回（否则服务器管理入口整段不可达）');
    expect(find.byType(LoginView), findsNothing);

    // 守卫未被放宽：未登录访问首页仍回登录页
    GoRouter.of(tester.element(find.byType(ServersView))).go('/');
    await tester.pumpAndSettle();
    expect(find.byType(LoginView), findsOneWidget,
        reason: '除 /login、/servers、/test-mode 外的页面未登录仍应回登录页');

    // 卸载清理后台 Timer
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('P3：重新登录保留 libraryIds', (tester) async {
    SharedPreferences.setMockInitialValues({
      kStorageKeyServerRegistry: jsonEncode([
        {
          'id': 'srv_emby',
          'kind': 'emby',
          'name': '家里 Emby',
          'url': 'http://emby.test:8096',
          'username': 'tester',
          'lastUsed': DateTime.now().toIso8601String(),
          'libraryIds': ['lib-1', 'lib-2'],
        }
      ]),
    });
    final mockService = MockEmbytokService();
    when(mockService.login(
      embyServerUrl: anyNamed('embyServerUrl'),
      username: anyNamed('username'),
      password: anyNamed('password'),
    )).thenAnswer((_) async =>
        const User(id: 'u1', name: 'tester', accessToken: 'tok'));
    final storage = MockFlutterSecureStorage();
    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(storage),
        embytokServiceProvider.overrideWithValue(mockService),
        authProvider.overrideWith((ref) => AuthNotifier(ref)),
        serviceModeProvider.overrideWith((ref) => ServiceModeNotifier()),
      ],
    );
    addTearDown(container.dispose);

    await _pumpLogin(container, tester);
    // 前置：注册表已从 SharedPreferences 恢复出带 libraryIds 的条目
    expect(container.read(serverRegistryProvider).single.libraryIds,
        ['lib-1', 'lib-2']);

    await _fillAndSubmit(tester,
        server: 'http://emby.test:8096', username: 'tester', password: 'pass');

    final servers = container.read(serverRegistryProvider);
    expect(servers.length, 1, reason: '同端点同账号应命中既有条目，不新增');
    expect(servers.single.id, 'srv_emby');
    expect(servers.single.libraryIds, ['lib-1', 'lib-2'],
        reason: 'update 按键整体替换，重新登录不得清空已记忆的媒体库');
    // 未勾选「记住密码」：密码不写回注册表
    expect(await storage.read(key: serverPasswordKey('srv_emby')), isNull,
        reason: '未勾选记住密码时不应持久化密码');
  });

  testWidgets('P3：未勾选记住密码时群晖 sid 不写回注册表，并清除旧 sid', (tester) async {
    SharedPreferences.setMockInitialValues({
      kStorageKeyServerRegistry: jsonEncode([
        {
          'id': 'srv_nas',
          'kind': 'synology',
          'name': 'NAS 音乐',
          'url': 'http://nas.test:5000',
          'username': 'tester',
          'lastUsed': DateTime.now().toIso8601String(),
          'libraryIds': ['music-1'],
        }
      ]),
    });
    final storage = MockFlutterSecureStorage();
    // 前置：注册表里存有旧 sid（上次勾选过记住密码）
    await storage.write(key: serverSynoSidKey('srv_nas'), value: 'old-sid');

    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(storage),
        synologyAudioApiProvider
            .overrideWith((ref) => _FakeSynoLoginAudioApi()),
        serviceModeProvider.overrideWith((ref) => ServiceModeNotifier()),
      ],
    );
    addTearDown(container.dispose);

    await _pumpLogin(container, tester);
    await tester.tap(find.text('群晖音乐'));
    await tester.pumpAndSettle();

    await _fillAndSubmit(tester,
        server: 'http://nas.test:5000', username: 'tester', password: 'pass');

    expect(await storage.read(key: serverSynoSidKey('srv_nas')), isNull,
        reason: 'sid 与密码同级，未勾选记住密码时不得持久化（旧 sid 也应清除）');
    expect(container.read(serverRegistryProvider).single.libraryIds,
        ['music-1'],
        reason: '群晖重新登录同样不得清空已记忆的媒体库');
  });
}
