// 群晖会话多槽隔离测试（#170 批次 A1：内存多槽化）
//
// 固定视频侧对称模型的多会话隔离行为：
// - 登录第二台/第二账号不覆盖第一台内存会话，在线槽并存
// - switchTo 切回已在线槽，对外 state 与 API 单例回填目标槽 sid/url/account
// - logoutSession 仅移除目标槽，其他在线槽保留
// - 持久化旧单槽过渡契约不回退（login/restore 仍写旧单槽 key）

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:embytok_flutter/providers/auth_provider.dart'
    show secureStorageProvider;
import 'package:embytok_flutter/providers/synology_auth_provider.dart';
import 'package:embytok_flutter/services/synology_audio_api.dart';

import '../mocks/mock_secure_storage.dart';

/// fake API：login 按账号返回不同 sid；记录最近一次 restoreSession 回填。
class _FakeSynoApi implements SynologyAudioApi {
  String? serverUrl;
  String? sid;
  String? account;
  String? lastRestoredSid;
  String? lastRestoredUrl;
  String? lastRestoredAccount;
  int logoutCount = 0;
  bool failNextLogin = false;

  @override
  bool get isLoggedIn => sid != null && sid!.isNotEmpty;

  @override
  Future<String> login({
    required String serverUrl,
    required String account,
    required String password,
    String? otpCode,
    String? deviceId,
  }) async {
    if (failNextLogin) {
      failNextLogin = false;
      throw Exception('登录失败');
    }
    this.serverUrl = serverUrl;
    this.account = account;
    sid = 'sid-$account';
    return sid!;
  }

  @override
  void restoreSession({
    required String serverUrl,
    required String sid,
    String? account,
  }) {
    lastRestoredUrl = serverUrl;
    lastRestoredSid = sid;
    lastRestoredAccount = account;
    this.serverUrl = serverUrl;
    this.sid = sid;
    this.account = account;
  }

  @override
  Future<void> logout() async {
    logoutCount++;
    sid = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockFlutterSecureStorage mockStorage;
  late _FakeSynoApi fakeApi;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockStorage = MockFlutterSecureStorage();
    fakeApi = _FakeSynoApi();
  });

  ProviderContainer buildContainer() => ProviderContainer(overrides: [
        secureStorageProvider.overrideWithValue(mockStorage),
        synologyAudioApiProvider.overrideWithValue(fakeApi),
      ]);

  group('群晖多槽隔离', () {
    test('登录两台/两账号：在线槽并存，state 指向最后登录者', () async {
      final container = buildContainer();
      addTearDown(container.dispose);
      final auth = container.read(synologyAuthProvider.notifier);

      await auth.login(
        serverUrl: 'http://192.168.1.6:5000',
        account: 'admin',
        password: 'pw',
      );
      await auth.login(
        serverUrl: 'http://10.0.0.8:5000',
        account: 'music',
        password: 'pw',
      );

      expect(auth.onlineSessionIds().length, 2);
      expect(auth.isSessionOnline(auth.onlineSessionIds().first), isTrue);
      final state = container.read(synologyAuthProvider);
      expect(state.account, 'music');
      expect(state.sid, 'sid-music');
    });

    test('switchTo 切回已在线槽：state 与 API 单例回填目标会话', () async {
      final container = buildContainer();
      addTearDown(container.dispose);
      final auth = container.read(synologyAuthProvider.notifier);

      await auth.login(
        serverUrl: 'http://192.168.1.6:5000',
        account: 'admin',
        password: 'pw',
      );
      await auth.login(
        serverUrl: 'http://10.0.0.8:5000',
        account: 'music',
        password: 'pw',
      );

      final firstKey = auth.onlineSessionIds().firstWhere(
          (k) => k.contains('192.168.1.6') || k.contains('admin'));
      auth.switchTo(firstKey);

      final state = container.read(synologyAuthProvider);
      expect(state.account, 'admin');
      expect(state.sid, 'sid-admin');
      expect(fakeApi.lastRestoredUrl, 'http://192.168.1.6:5000');
      expect(fakeApi.lastRestoredSid, 'sid-admin');
      expect(fakeApi.lastRestoredAccount, 'admin');
    });

    test('logoutSession 仅移除目标槽，其他在线槽保留', () async {
      final container = buildContainer();
      addTearDown(container.dispose);
      final auth = container.read(synologyAuthProvider.notifier);

      await auth.login(
        serverUrl: 'http://192.168.1.6:5000',
        account: 'admin',
        password: 'pw',
      );
      await auth.login(
        serverUrl: 'http://10.0.0.8:5000',
        account: 'music',
        password: 'pw',
      );
      final keys = auth.onlineSessionIds();
      final adminKey =
          keys.firstWhere((k) => k.contains('admin') || k.contains('192.168.1.6'));

      await auth.logoutSession(adminKey);

      expect(auth.onlineSessionIds().length, 1);
      expect(auth.isSessionOnline(adminKey), isFalse);
      // 当前激活槽（music）不受连带影响，仍处于登录态。
      expect(container.read(synologyAuthProvider).isLoggedIn, isTrue);
      expect(container.read(synologyAuthProvider).account, 'music');
    });

    test('restoreSession 落槽并仍写旧单槽过渡持久化', () async {
      final container = buildContainer();
      addTearDown(container.dispose);
      final auth = container.read(synologyAuthProvider.notifier);

      await auth.restoreSession(
        serverUrl: 'http://10.0.0.6:5000',
        account: 'guest',
        sid: 'sid-restored',
      );

      expect(auth.onlineSessionIds().length, 1);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('synology_server_url'), 'http://10.0.0.6:5000');
      expect(prefs.getString('synology_account'), 'guest');
      expect(await mockStorage.read(key: 'synology_sid_secure'),
          'sid-restored');
    });

    test('登录失败不覆盖已有在线槽', () async {
      final container = buildContainer();
      addTearDown(container.dispose);
      final auth = container.read(synologyAuthProvider.notifier);

      await auth.login(
        serverUrl: 'http://192.168.1.6:5000',
        account: 'admin',
        password: 'pw',
      );
      fakeApi.failNextLogin = true;

      await expectLater(
        () => auth.login(
          serverUrl: 'http://10.0.0.8:5000',
          account: 'music',
          password: 'bad',
        ),
        throwsA(isA<Exception>()),
      );

      expect(auth.onlineSessionIds().length, 1);
      expect(container.read(synologyAuthProvider).account, 'admin');
    });
  });
}
