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

import 'package:go_router/go_router.dart';

import 'package:embytok_flutter/providers/providers.dart';
import 'package:embytok_flutter/providers/service_mode_provider.dart';
import 'package:embytok_flutter/services/services.dart';
import 'package:embytok_flutter/views/login_view.dart';

import 'package:mockito/mockito.dart';

import 'package:embytok_flutter/models/models.dart';
import 'package:embytok_flutter/providers/auth_provider.dart';
import 'package:embytok_flutter/providers/server_registry_provider.dart';

import '../mocks/mock_services.dart';
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
    expect(find.text('Emby 视频流'), findsOneWidget);
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

  testWidgets('HTTP 不安全警告：公网 HTTP 显示，内网/HTTPS 不显示', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(buildLogin());
    await tester.pumpAndSettle();

    final serverField = find.byType(TextFormField).first;

    // 公网 HTTP → 显示警告
    await tester.enterText(serverField, 'http://example.com');
    await tester.pump();
    expect(find.text('HTTP 不安全'), findsOneWidget);

    // 10.x 内网 → 不显示
    await tester.enterText(serverField, 'http://10.0.0.5:8096');
    await tester.pump();
    expect(find.text('HTTP 不安全'), findsNothing);

    // 172.16.x 内网（172.16/12 段）→ 不显示
    await tester.enterText(serverField, 'http://172.16.0.5:5000');
    await tester.pump();
    expect(find.text('HTTP 不安全'), findsNothing);

    // 172.31.x 内网（172.16/12 段末）→ 不显示
    await tester.enterText(serverField, 'http://172.31.255.1:5000');
    await tester.pump();
    expect(find.text('HTTP 不安全'), findsNothing);

    // 172.32.x 公网（超出 172.16/12）→ 显示
    await tester.enterText(serverField, 'http://172.32.0.1:5000');
    await tester.pump();
    expect(find.text('HTTP 不安全'), findsOneWidget);

    // 192.168.x 内网 → 不显示
    await tester.enterText(serverField, 'http://192.168.1.100:5000');
    await tester.pump();
    expect(find.text('HTTP 不安全'), findsNothing);

    // HTTPS → 不显示
    await tester.enterText(serverField, 'https://example.com');
    await tester.pump();
    expect(find.text('HTTP 不安全'), findsNothing);

    // localhost → 不显示
    await tester.enterText(serverField, 'http://localhost:8096');
    await tester.pump();
    expect(find.text('HTTP 不安全'), findsNothing);
  });

  testWidgets('URL 尾部斜杠输入不崩溃，表单可正常交互', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(buildLogin());
    await tester.pumpAndSettle();

    final serverField = find.byType(TextFormField).first;
    // 输入带尾部斜杠的地址（_submit 时会清理，此处验证输入与 UI 不崩溃）
    await tester.enterText(serverField, 'http://192.168.1.6:5000/');
    await tester.pump();
    expect(find.text('http://192.168.1.6:5000/'), findsOneWidget);
    expect(tester.takeException(), isNull,
        reason: '带尾部斜杠的 URL 输入不应导致崩溃');
  });

  testWidgets('U25 键盘弹出：表单输入框可滚动到键盘上方不被遮挡', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(buildLogin());
    await tester.pumpAndSettle();

    // 模拟键盘弹出：底部 inset 300（视口 800×600，键盘顶在 y=300）
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);
    await tester.pumpAndSettle();

    // 聚焦第一个输入框并滚动到可见，断言其底部位于键盘顶部上方
    final field = find.byType(TextFormField).first;
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    final keyboardTop = 600 - 300;
    expect(tester.getRect(field).bottom, lessThanOrEqualTo(keyboardTop + 1),
        reason: 'Scaffold 默认 resizeToAvoidBottomInset=true，输入框不应被键盘遮挡');
  });

  // ==================== F2 回归：群晖登录成功后联动音乐服务模式 ====================
  testWidgets('群晖登录成功后联动切换音乐服务模式', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(MockFlutterSecureStorage()),
        synologyAudioApiProvider
            .overrideWith((ref) => _FakeSynoLoginAudioApi()),
        serviceModeProvider.overrideWith((ref) => ServiceModeNotifier()),
      ],
    );
    addTearDown(container.dispose);
    // 前置：视频模式（验证群晖登录会联动切到 music）
    await container
        .read(serviceModeProvider.notifier)
        .setMode(AppServiceMode.video);

    final router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(path: '/login', builder: (_, __) => const LoginView()),
        GoRoute(
            path: '/', builder: (_, __) => const Scaffold(body: Text('首页'))),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          // M2 涟漪规避 Flutter 3.47.2 shader 已知缺陷（与 buildLogin 一致）
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 选群晖卡片并填写表单
    await tester.tap(find.text('群晖音乐'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextFormField).at(0), 'http://nas.test:5000');
    await tester.enterText(find.byType(TextFormField).at(1), 'tester');
    await tester.enterText(find.byType(TextFormField).at(2), 'pass');
    await tester.pump();

    // 通过密码框键盘 done 触发提交（登录按钮可能被连接测试指示器/表单
    // 布局遮挡；且避免 tap 按钮引起地址框失焦叠加连接测试状态机干扰）
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 断言：服务模式联动为 music，且已回到首页
    expect(container.read(serviceModeProvider), AppServiceMode.music,
        reason: '群晖登录成功应联动切换音乐服务模式（与退出回退 video 对称）');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('首页'), findsOneWidget,
        reason: '登录成功应重定向回首页');
  });

  testWidgets('音乐模式下 Emby 登录成功联动切回视频服务模式', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final mockService = MockEmbytokService();
    when(mockService.login(
      embyServerUrl: anyNamed('embyServerUrl'),
      username: anyNamed('username'),
      password: anyNamed('password'),
    )).thenAnswer((_) async =>
        const User(id: 'u1', name: 'tester', accessToken: 'tok'));
    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(MockFlutterSecureStorage()),
        embytokServiceProvider.overrideWithValue(mockService),
        authProvider.overrideWith((ref) => AuthNotifier(ref)),
        serviceModeProvider.overrideWith((ref) => ServiceModeNotifier()),
      ],
    );
    addTearDown(container.dispose);
    // 前置：音乐模式（验证 Emby 登录会联动切回 video，与群晖→music 对称）
    await container
        .read(serviceModeProvider.notifier)
        .setMode(AppServiceMode.music);

    final router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(path: '/login', builder: (_, __) => const LoginView()),
        GoRoute(
            path: '/', builder: (_, __) => const Scaffold(body: Text('首页'))),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 默认 Emby 卡片已选中，填写表单并提交
    await tester.enterText(
        find.byType(TextFormField).at(0), 'http://emby.test:8096');
    await tester.enterText(find.byType(TextFormField).at(1), 'tester');
    await tester.enterText(find.byType(TextFormField).at(2), 'pass');
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(container.read(serviceModeProvider), AppServiceMode.video,
        reason: 'Emby 登录成功应联动切回视频服务模式（与群晖→music 对称）');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('首页'), findsOneWidget,
        reason: '登录成功应重定向回首页');
  });

  testWidgets('快速切换群晖服务器联动音乐服务模式', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final mockStorage = MockFlutterSecureStorage();
    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(mockStorage),
        synologyAudioApiProvider
            .overrideWith((ref) => _FakeSynoLoginAudioApi()),
        serviceModeProvider.overrideWith((ref) => ServiceModeNotifier()),
        serverRegistryProvider
            .overrideWith((ref) => ServerRegistryNotifier(ref)),
      ],
    );
    addTearDown(container.dispose);
    // 前置：视频模式（验证快速切换到群晖会联动 music）
    await container
        .read(serviceModeProvider.notifier)
        .setMode(AppServiceMode.video);
    // 预置一个群晖服务器，密码写入安全存储（走登录路径）
    final profile = ServerProfile(
      id: 's1',
      kind: ServerKind.synology,
      name: 'NAS',
      url: 'http://nas.test:5000',
      username: 'tester',
      lastUsed: DateTime.now(),
    );
    await container.read(serverRegistryProvider.notifier).add(profile);
    await mockStorage.write(key: 'server_password_s1', value: 'pass');

    final router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(path: '/login', builder: (_, __) => const LoginView()),
        GoRoute(
            path: '/', builder: (_, __) => const Scaffold(body: Text('首页'))),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 滚动到「账户」tile 并点击，弹出服务器切换列表
    await tester.ensureVisible(find.text('未登录'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('未登录'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('NAS'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 300));

    expect(container.read(activeServerIdProvider), 's1',
        reason: '群晖服务器应切换为激活服务器');
    expect(container.read(serviceModeProvider), AppServiceMode.music,
        reason: '快速切换到群晖服务器成功应联动音乐服务模式（与登录表单提交对称）');
  });

}


/// 群晖 Audio API 假实现：login 直接返回固定 sid，避免测试环境走真实网络
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
