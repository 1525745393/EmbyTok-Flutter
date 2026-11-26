// 回归测试（P2-5）：群晖两步验证（OTP）在账号切换 / 添加 / 自动续期路径的回退契约
//
// 背景：账号切换 sheet 的「切换账号」「添加账号」此前直接裸调 login，2FA 账号首次
// 登录抛 SynologyOtpRequiredException 后被当成普通失败，用户没有输入验证码的机会。
// 本批次把 OTP 回退收敛到 helper.loginSynoWithOtp，固定以下不变量：
// - 首次抛 OTP → 取码回调拿到验证码 → 第二次 login 带 otpCode 重试成功；
// - 用户取消取码 → 原始 OTP 异常上抛，不伪造成功；
// - 非 OTP 异常（网络/密码错误）→ 直接上抛，不触发取码；
// - 自动续期遇 OTP → 返回 false（不抛错），由上层引导手动登录。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:embytok_flutter/providers/auth_provider.dart';
import 'package:embytok_flutter/providers/syno_accounts_provider.dart';
import 'package:embytok_flutter/providers/synology_auth_provider.dart';
import 'package:embytok_flutter/services/synology_audio_api.dart';
import 'package:embytok_flutter/views/server_switch_helpers.dart';

/// 内存安全存储桩
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

/// 可编排首次行为的群晖认证桩：记录 login 调用与最后一次 otpCode。
class _OtpFakeAuth extends SynologyAuthNotifier {
  _OtpFakeAuth(super.ref);

  int loginCalls = 0;
  String? lastOtpCode;
  String? lastAccount;
  bool throwOtp = false;
  Object? nonOtpError;

  @override
  Future<void> login({
    required String serverUrl,
    required String account,
    required String password,
    String? otpCode,
    String? serverId,
  }) async {
    loginCalls++;
    lastOtpCode = otpCode;
    lastAccount = account;
    if (nonOtpError != null) throw nonOtpError!;
    if (throwOtp) {
      throwOtp = false; // 仅首次要求 OTP，带码重试应成功
      throw SynologyOtpRequiredException('otp-token');
    }
    state = SynologyAuthState(
      isLoggedIn: true,
      serverUrl: serverUrl,
      account: account,
      sid: 'sid',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WidgetRef capturedRef;
  _OtpFakeAuth? auth;

  Widget buildHost(_FakeSecureStorage storage) {
    return ProviderScope(
      overrides: [
        secureStorageProvider.overrideWithValue(storage),
        synologyAuthProvider.overrideWith((ref) => auth = _OtpFakeAuth(ref)),
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

  testWidgets('OTP 回退：首次要求验证码，取码后带 otpCode 重试成功', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = _FakeSecureStorage({});
    await tester.pumpWidget(buildHost(storage));
    await tester.pumpAndSettle();
    capturedRef.read(synologyAuthProvider);
    auth!.throwOtp = true;

    await loginSynoWithOtp(
      auth!,
      serverUrl: 'http://nas.test:5000',
      account: 'nas-user',
      password: 'pwd',
      requestOtp: () async => '123456',
    );

    expect(auth!.loginCalls, 2, reason: '首次 OTP + 带码重试共两次 login');
    expect(auth!.lastOtpCode, '123456');
    expect(auth!.state.isLoggedIn, isTrue);
  });

  testWidgets('取消 OTP：原始异常上抛，不伪造登录成功', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = _FakeSecureStorage({});
    await tester.pumpWidget(buildHost(storage));
    await tester.pumpAndSettle();
    capturedRef.read(synologyAuthProvider);
    auth!.throwOtp = true;

    await expectLater(
      loginSynoWithOtp(
        auth!,
        serverUrl: 'http://nas.test:5000',
        account: 'nas-user',
        password: 'pwd',
        requestOtp: () async => null,
      ),
      throwsA(isA<SynologyOtpRequiredException>()),
    );

    expect(auth!.loginCalls, 1, reason: '取消取码后不应重试 login');
    expect(auth!.lastOtpCode, isNull);
    expect(auth!.state.isLoggedIn, isFalse);
  });

  testWidgets('非 OTP 异常：直接上抛，不触发取码', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = _FakeSecureStorage({});
    await tester.pumpWidget(buildHost(storage));
    await tester.pumpAndSettle();
    capturedRef.read(synologyAuthProvider);
    auth!.nonOtpError = Exception('network down');
    var otpRequested = false;

    await expectLater(
      loginSynoWithOtp(
        auth!,
        serverUrl: 'http://nas.test:5000',
        account: 'nas-user',
        password: 'pwd',
        requestOtp: () async {
          otpRequested = true;
          return '123456';
        },
      ),
      throwsA(isA<Exception>()),
    );

    expect(auth!.loginCalls, 1);
    expect(otpRequested, isFalse, reason: '非 OTP 异常不应弹出验证码');
  });

  testWidgets('自动续期遇 OTP：返回 false 而非抛错（上层引导手动登录）',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = _FakeSecureStorage({});
    await tester.pumpWidget(buildHost(storage));
    await tester.pumpAndSettle();
    capturedRef.read(synologyAuthProvider);
    auth!.throwOtp = true;

    // 预置当前账号 + 保存密码，供 renewSession 读取
    final accounts = capturedRef.read(synoAccountsProvider.notifier);
    final account = await accounts.addAccount(
      serverUrl: 'http://nas.test:5000',
      username: 'nas-user',
      password: 'pwd',
    );
    await accounts.setCurrent(account.accountId);

    final renewed = await auth!.renewSession();

    expect(renewed, isFalse, reason: '2FA 账号无法免密续期，应返回 false');
    expect(auth!.state.isLoggedIn, isFalse);
  });
}
