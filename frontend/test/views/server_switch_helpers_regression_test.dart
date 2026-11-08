// 回归测试：登录界面审查 F3 / F7 的公共切换逻辑（server_switch_helpers）
//
// F3：群晖路径曾只做本地乐观置位的 restoreSession，不校验 sid 有效性，
//     sid 过期时会提示「已切换」实际未登录。修复后用一次轻量 API
//     （getGenres）验证，失败则 clearInvalidSession + 回退密码登录。
// F7：开启两步验证的群晖账号在切换路径会抛 SynologyOtpRequiredException，
//     修复后经 requestOtp 取码并重试一次。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:embytok_flutter/models/models.dart';
import 'package:embytok_flutter/providers/auth_provider.dart';
import 'package:embytok_flutter/providers/server_registry_provider.dart';
import 'package:embytok_flutter/providers/synology_auth_provider.dart';
import 'package:embytok_flutter/services/synology_audio_api.dart';
import 'package:embytok_flutter/views/server_switch_helpers.dart';

/// 可控的 Audio Station 桩：getGenres 成功/抛 105 会话失效
class _FakeSynologyApi extends SynologyAudioApi {
  _FakeSynologyApi({required this.genresFails});

  final bool genresFails;

  @override
  Future<List<AudioGenre>> getGenres({int offset = 0, int limit = 200}) async {
    if (genresFails) throw SynologySessionExpiredException();
    return const <AudioGenre>[];
  }
}

/// 记录调用的假认证 Notifier：restoreSession / clearInvalidSession / login
class _RecordingSynologyAuth extends SynologyAuthNotifier {
  _RecordingSynologyAuth(super.ref) : super();

  bool genresFails = true;
  int restoreCalls = 0;
  int clearInvalidCalls = 0;
  int loginCalls = 0;
  final List<String?> otpCodes = <String?>[];
  bool throwOtpOnFirstLogin = false;

  @override
  SynologyAudioApi get api => _FakeSynologyApi(genresFails: genresFails);

  @override
  Future<void> restoreSession({
    required String serverUrl,
    required String account,
    required String sid,
  }) async {
    restoreCalls++;
    state = SynologyAuthState(
        isLoggedIn: true, serverUrl: serverUrl, account: account, sid: sid);
  }

  @override
  Future<void> clearInvalidSession() async {
    clearInvalidCalls++;
    state = const SynologyAuthState();
  }

  @override
  Future<void> login({
    required String serverUrl,
    required String account,
    required String password,
    String? otpCode,
  }) async {
    loginCalls++;
    otpCodes.add(otpCode);
    if (throwOtpOnFirstLogin && otpCode == null) {
      throw SynologyOtpRequiredException('token-123');
    }
    state = SynologyAuthState(
      isLoggedIn: true,
      serverUrl: serverUrl,
      account: account,
      sid: 'sid-after-login-$loginCalls',
    );
  }
}

/// 只做内存读写的安全存储桩（sid / 密码）
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final server = ServerProfile(
    id: 'srv-nas',
    kind: ServerKind.synology,
    name: 'NAS',
    url: 'http://nas.local:5000',
    username: 'alice',
    lastUsed: DateTime(2026, 1, 1),
  );

  late _RecordingSynologyAuth fakeAuth;

  Widget buildHost({
    required _FakeSecureStorage storage,
    required void Function(WidgetRef ref) onRef,
  }) {
    return ProviderScope(
      overrides: [
        secureStorageProvider.overrideWithValue(storage),
        synologyAuthProvider.overrideWith((ref) {
          fakeAuth = _RecordingSynologyAuth(ref);
          return fakeAuth;
        }),
      ],
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) {
            onRef(ref);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  testWidgets('sid 失效时清除假登录态并回退密码登录（F3）', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = _FakeSecureStorage({
      serverSynoSidKey(server.id): 'stale-sid',
      serverPasswordKey(server.id): 'saved-password',
    });
    late WidgetRef capturedRef;

    await tester.pumpWidget(buildHost(storage: storage, onRef: (ref) => capturedRef = ref));
    await tester.pumpAndSettle();
    // 触发 override 创建 notifier，拿到可配置的假实现
    capturedRef.read(synologyAuthProvider);
    fakeAuth.genresFails = true;

    await loginSynologyTarget(capturedRef, server, storage);

    expect(fakeAuth.restoreCalls, 1, reason: '先尝试用保存的 sid 恢复会话');
    expect(fakeAuth.clearInvalidCalls, 1, reason: 'sid 校验失败必须清除假登录态');
    expect(fakeAuth.loginCalls, 1, reason: 'sid 失效后回退密码登录');
    expect(fakeAuth.otpCodes.single, isNull);
    // 新 sid 已回写注册表（供下次免密恢复）：registry 需可写，这里只验证登录态
    expect(capturedRef.read(synologyAuthProvider).isLoggedIn, isTrue);
  });

  testWidgets('sid 有效时不再重复输入密码（F3 对照）', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = _FakeSecureStorage({
      serverSynoSidKey(server.id): 'valid-sid',
      serverPasswordKey(server.id): 'saved-password',
    });
    late WidgetRef capturedRef;

    await tester.pumpWidget(buildHost(storage: storage, onRef: (ref) => capturedRef = ref));
    await tester.pumpAndSettle();
    // 触发 override 创建 notifier，拿到可配置的假实现
    capturedRef.read(synologyAuthProvider);
    fakeAuth.genresFails = false;

    await loginSynologyTarget(capturedRef, server, storage);

    expect(fakeAuth.restoreCalls, 1);
    expect(fakeAuth.clearInvalidCalls, 0);
    expect(fakeAuth.loginCalls, 0, reason: 'sid 有效时不应触发密码登录');
  });

  testWidgets('两步验证：首次抛 OTP 异常后取码重试一次（F7）', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = _FakeSecureStorage({
      serverPasswordKey(server.id): 'saved-password',
    });
    late WidgetRef capturedRef;

    await tester.pumpWidget(buildHost(storage: storage, onRef: (ref) => capturedRef = ref));
    await tester.pumpAndSettle();
    // 触发 override 创建 notifier，拿到可配置的假实现
    capturedRef.read(synologyAuthProvider);
    fakeAuth.throwOtpOnFirstLogin = true;

    await loginSynologyTarget(
      capturedRef,
      server,
      storage,
      requestOtp: () async => '123456',
    );

    expect(fakeAuth.loginCalls, 2, reason: '首次失败后带验证码重试一次');
    expect(fakeAuth.otpCodes, <String?>[null, '123456']);
    expect(capturedRef.read(synologyAuthProvider).isLoggedIn, isTrue);
  });

  testWidgets('用户取消验证码输入时不再重试并抛出 OTP 异常（F7 取消路径）', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = _FakeSecureStorage({
      serverPasswordKey(server.id): 'saved-password',
    });
    late WidgetRef capturedRef;

    await tester.pumpWidget(buildHost(storage: storage, onRef: (ref) => capturedRef = ref));
    await tester.pumpAndSettle();
    // 触发 override 创建 notifier，拿到可配置的假实现
    capturedRef.read(synologyAuthProvider);
    fakeAuth.throwOtpOnFirstLogin = true;

    await expectLater(
      loginSynologyTarget(
        capturedRef,
        server,
        storage,
        requestOtp: () async => null,
      ),
      throwsA(isA<SynologyOtpRequiredException>()),
    );
    expect(fakeAuth.loginCalls, 1, reason: '取消输入不应带着空验证码重试');
  });
}
