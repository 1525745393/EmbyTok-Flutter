// 注册表服务器切换编排回归测试（P1-1）
//
// 背景：登录页快速切换曾在登录目标之前先清理对端会话，目标登录失败时
// 当前可用会话已被销毁（用户被踢回登录页）。服务器管理页已修为「先登录
// 成功再清对端」，本批次把编排收敛到 server_switch_helpers.switchRegistryServer，
// 本文件固定顺序不变量：
// - 目标登录失败（无密码 / 抛错）→ 对端会话必须保留、对端 logout 不得被调用；
// - 目标登录成功 → 才清理对端会话、更新激活态与服务模式。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:embytok_flutter/models/models.dart';
import 'package:embytok_flutter/providers/auth_provider.dart';
import 'package:embytok_flutter/providers/embytok_service_provider.dart';
import 'package:embytok_flutter/providers/server_registry_provider.dart';
import 'package:embytok_flutter/providers/service_mode_provider.dart';
import 'package:embytok_flutter/providers/synology_auth_provider.dart';
import 'package:embytok_flutter/services/synology_audio_api.dart';
import 'package:embytok_flutter/views/server_switch_helpers.dart';

import '../mocks/mock_services.dart';

/// 只做内存读写的安全存储桩
class _FakeSecureStorage implements FlutterSecureStorage {
  _FakeSecureStorage(this._values);

  final Map<String, String> _values;

  @override
  Future<String?> read({required String key, dynamic iOptions, dynamic aOptions, dynamic lOptions, dynamic webOptions, dynamic mOptions, dynamic wOptions}) async =>
      _values[key];

  @override
  Future<void> write({required String key, String? value, dynamic iOptions, dynamic aOptions, dynamic lOptions, dynamic webOptions, dynamic mOptions, dynamic wOptions}) async {
    if (value == null) {
      _values.remove(key);
    } else {
      _values[key] = value;
    }
  }

  @override
  Future<void> delete({required String key, dynamic iOptions, dynamic aOptions, dynamic lOptions, dynamic webOptions, dynamic mOptions, dynamic wOptions}) async {
    _values.remove(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 记录 logout 调用的 Emby 认证桩，可预置已登录态
class _FakeEmbyAuth extends AuthNotifier {
  _FakeEmbyAuth(super.ref);

  int logoutCalls = 0;

  @override
  Future<void> logout() async {
    logoutCalls++;
    state = const AuthState();
  }
}

/// 记录 logout 调用的群晖认证桩，可预置已登录态
class _FakeSynoAuth extends SynologyAuthNotifier {
  _FakeSynoAuth(super.ref);

  int logoutCalls = 0;

  @override
  Future<void> logout() async {
    logoutCalls++;
    state = const SynologyAuthState();
  }
}

ServerProfile _profile({
  required String id,
  required ServerKind kind,
  required String url,
  required String username,
}) {
  return ServerProfile(
    id: id,
    kind: kind,
    name: id,
    url: url,
    username: username,
    lastUsed: DateTime(2026, 1, 1),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WidgetRef capturedRef;
  _FakeEmbyAuth? embyAuth;
  _FakeSynoAuth? synoAuth;

  Widget buildHost({
    required _FakeSecureStorage storage,
    bool withEmby = false,
    bool withSyno = false,
    MockEmbytokService? mockService,
  }) {
    return ProviderScope(
      overrides: [
        secureStorageProvider.overrideWithValue(storage),
        if (withEmby)
          authProvider.overrideWith((ref) => embyAuth = _FakeEmbyAuth(ref)),
        if (withSyno)
          synologyAuthProvider
              .overrideWith((ref) => synoAuth = _FakeSynoAuth(ref)),
        if (mockService != null)
          embytokServiceProvider.overrideWithValue(mockService),
        serviceModeProvider.overrideWith((ref) => ServiceModeNotifier()),
      ],
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) {
            capturedRef = ref;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  testWidgets('跨类型切群晖失败（无保存密码）：对端 Emby 会话保留、logout 不被调用',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = _FakeSecureStorage({});

    await tester.pumpWidget(buildHost(storage: storage, withEmby: true));
    await tester.pumpAndSettle();
    capturedRef.read(authProvider);
    embyAuth!.state = const AuthState(
      isAuthenticated: true,
      embyServerUrl: 'http://emby.test:8096',
      token: 'tok',
    );

    await capturedRef.read(serverRegistryProvider.notifier).add(
          _profile(
            id: 'srv_nas',
            kind: ServerKind.synology,
            url: 'http://nas.test:5000',
            username: 'nas-user',
          ),
        );
    final nas = capturedRef.read(serverRegistryProvider).single;

    // 目标登录失败：无保存密码抛 MissingSavedPasswordException
    await expectLater(
      switchRegistryServer(capturedRef, nas, storage),
      throwsA(isA<MissingSavedPasswordException>()),
    );

    // 顺序不变量：对端 Emby 会话不得被清理
    expect(embyAuth!.logoutCalls, 0,
        reason: '目标登录失败时不得先 purge 对端会话');
    expect(capturedRef.read(authProvider).isAuthenticated, isTrue);
  });

  testWidgets('跨类型切视频失败（无保存密码）：对端群晖会话保留', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = _FakeSecureStorage({});

    await tester.pumpWidget(buildHost(storage: storage, withSyno: true));
    await tester.pumpAndSettle();
    capturedRef.read(synologyAuthProvider);
    synoAuth!.state = const SynologyAuthState(
      isLoggedIn: true,
      serverUrl: 'http://nas.test:5000',
      account: 'nas-user',
      sid: 'sid',
    );

    await capturedRef.read(serverRegistryProvider.notifier).add(
          _profile(
            id: 'srv_emby2',
            kind: ServerKind.emby,
            url: 'http://emby2.test:8096',
            username: 'emby-user2',
          ),
        );
    final emby2 = capturedRef.read(serverRegistryProvider).single;

    final outcome = await switchRegistryServer(capturedRef, emby2, storage);

    expect(outcome, ServerSwitchOutcome.missingPassword);
    expect(synoAuth!.logoutCalls, 0,
        reason: '无保存密码返回前不得清理对端群晖会话');
    expect(capturedRef.read(synologyAuthProvider).isLoggedIn, isTrue);
  });

  testWidgets('成功跨类型切换：清对端群晖会话、更新激活态并联动视频模式',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = _FakeSecureStorage({
      serverPasswordKey('srv_emby2'): 'emby-pass',
    });
    final mockService = MockEmbytokService();
    when(mockService.login(
      embyServerUrl: anyNamed('embyServerUrl'),
      username: anyNamed('username'),
      password: anyNamed('password'),
    )).thenAnswer((_) async =>
        const User(id: 'u1', name: 'emby-user2', accessToken: 'tok'));

    await tester.pumpWidget(buildHost(
      storage: storage,
      withSyno: true,
      mockService: mockService,
    ));
    await tester.pumpAndSettle();
    capturedRef.read(synologyAuthProvider);
    synoAuth!.state = const SynologyAuthState(
      isLoggedIn: true,
      serverUrl: 'http://nas.test:5000',
      account: 'nas-user',
      sid: 'sid',
    );
    await capturedRef
        .read(serviceModeProvider.notifier)
        .setMode(AppServiceMode.music);

    await capturedRef.read(serverRegistryProvider.notifier).add(
          _profile(
            id: 'srv_emby2',
            kind: ServerKind.emby,
            url: 'http://emby2.test:8096',
            username: 'emby-user2',
          ),
          password: 'emby-pass',
        );
    final emby2 = capturedRef.read(serverRegistryProvider).single;

    final outcome = await switchRegistryServer(capturedRef, emby2, storage);

    expect(outcome, ServerSwitchOutcome.switched);
    // 成功后才清理对端群晖会话
    expect(synoAuth!.logoutCalls, 1);
    expect(capturedRef.read(synologyAuthProvider).isLoggedIn, isFalse);
    // 激活态切到目标
    expect(capturedRef.read(activeServerIdProvider), 'srv_emby2');
    // 模式联动到视频
    expect(capturedRef.read(serviceModeProvider), AppServiceMode.video);
  });

  // ---- P1-2：删除注册表服务器时清掉匹配的活会话 ----

  testWidgets('删除当前已登录的 Emby 服务器：登出视频会话', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = _FakeSecureStorage({});

    await tester.pumpWidget(buildHost(storage: storage, withEmby: true));
    await tester.pumpAndSettle();
    capturedRef.read(authProvider);
    embyAuth!.state = const AuthState(
      isAuthenticated: true,
      embyServerUrl: 'http://emby.test:8096',
      token: 'tok',
    );

    final server = _profile(
      id: 'srv_emby',
      kind: ServerKind.emby,
      url: 'http://emby.test:8096',
      username: 'emby-user',
    );

    await logoutMatchingSession(capturedRef, server);

    expect(embyAuth!.logoutCalls, 1, reason: '删除匹配的已登录服务器必须登出视频会话');
    expect(capturedRef.read(authProvider).isAuthenticated, isFalse);
  });

  testWidgets('删除当前已登录的群晖服务器：登出群晖会话', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = _FakeSecureStorage({});

    await tester.pumpWidget(buildHost(storage: storage, withSyno: true));
    await tester.pumpAndSettle();
    capturedRef.read(synologyAuthProvider);
    synoAuth!.state = const SynologyAuthState(
      isLoggedIn: true,
      serverUrl: 'http://nas.test:5000',
      account: 'nas-user',
      sid: 'sid',
    );

    final server = _profile(
      id: 'srv_nas',
      kind: ServerKind.synology,
      url: 'http://nas.test:5000',
      username: 'nas-user',
    );

    await logoutMatchingSession(capturedRef, server);

    expect(synoAuth!.logoutCalls, 1, reason: '删除匹配的已登录群晖服务器必须登出群晖会话');
    expect(capturedRef.read(synologyAuthProvider).isLoggedIn, isFalse);
  });

  testWidgets('删除 host 不匹配的服务器：现有会话保留、不登出', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = _FakeSecureStorage({});

    await tester.pumpWidget(
      buildHost(storage: storage, withEmby: true, withSyno: true),
    );
    await tester.pumpAndSettle();
    capturedRef.read(authProvider);
    capturedRef.read(synologyAuthProvider);
    embyAuth!.state = const AuthState(
      isAuthenticated: true,
      embyServerUrl: 'http://other.test:8096',
      token: 'tok',
    );
    synoAuth!.state = const SynologyAuthState(
      isLoggedIn: true,
      serverUrl: 'http://other-nas.test:5000',
      account: 'u',
      sid: 'sid',
    );

    final server = _profile(
      id: 'srv_emby2',
      kind: ServerKind.emby,
      url: 'http://emby2.test:8096',
      username: 'emby-user2',
    );

    await logoutMatchingSession(capturedRef, server);

    expect(embyAuth!.logoutCalls, 0, reason: 'host 不匹配不得登出现有视频会话');
    expect(synoAuth!.logoutCalls, 0, reason: '视频类删除不得登出群晖会话');
    expect(capturedRef.read(authProvider).isAuthenticated, isTrue);
  });

  testWidgets('删除未登录状态下的服务器：不触发登出', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = _FakeSecureStorage({});

    await tester.pumpWidget(
      buildHost(storage: storage, withEmby: true, withSyno: true),
    );
    await tester.pumpAndSettle();
    capturedRef.read(authProvider);
    capturedRef.read(synologyAuthProvider);

    final server = _profile(
      id: 'srv_emby',
      kind: ServerKind.emby,
      url: 'http://emby.test:8096',
      username: 'emby-user',
    );

    await logoutMatchingSession(capturedRef, server);

    expect(embyAuth!.logoutCalls, 0);
    expect(synoAuth!.logoutCalls, 0);
  });
}
