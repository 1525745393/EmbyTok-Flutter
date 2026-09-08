// 群晖认证 sid 安全存储迁移测试
//
// 覆盖：
// - 登录成功后 sid 写入安全存储（不再写明文 SharedPreferences）
// - 旧明文 sid 自动迁移到安全存储并清理明文
// - restoreSession 公开接口：切换服务器免密恢复 + 持久化
// - logout 清理安全存储 sid

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:embytok_flutter/providers/auth_provider.dart'
    show secureStorageProvider;
import 'package:embytok_flutter/providers/synology_auth_provider.dart';
import 'package:embytok_flutter/services/synology_audio_api.dart';

import '../mocks/mock_secure_storage.dart';

/// 最小 fake：仅实现认证相关成员，其余走 noSuchMethod 兜底
class _FakeSynologyApi implements SynologyAudioApi {
  String? serverUrl;
  String? sid;
  String? account;
  String? restoredSid;
  int logoutCount = 0;

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
    this.serverUrl = serverUrl;
    this.account = account;
    sid = 'fake-sid';
    return sid!;
  }

  @override
  void restoreSession({
    required String serverUrl,
    required String sid,
    String? account,
  }) {
    restoredSid = sid;
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
  late _FakeSynologyApi fakeApi;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockStorage = MockFlutterSecureStorage();
    fakeApi = _FakeSynologyApi();
  });

  ProviderContainer buildContainer() {
    return ProviderContainer(overrides: [
      secureStorageProvider.overrideWithValue(mockStorage),
      synologyAudioApiProvider.overrideWithValue(fakeApi),
    ]);
  }

  group('SynologyAuthNotifier sid 存储', () {
    test('登录成功后 sid 写入安全存储，SharedPreferences 无明文 sid', () async {
      final container = buildContainer();
      addTearDown(container.dispose);
      await container.read(synologyAuthProvider.notifier).login(
            serverUrl: 'http://192.168.1.6:5000',
            account: 'admin',
            password: 'pw',
          );

      final prefs = await SharedPreferences.getInstance();
      // 新：安全存储
      expect(await mockStorage.read(key: 'synology_sid_secure'), 'fake-sid');
      // 旧明文键已清理
      expect(prefs.getString('synology_sid'), isNull);
      // 服务器信息仍在 prefs（非敏感）
      expect(prefs.getString('synology_server_url'),
          'http://192.168.1.6:5000');
      expect(prefs.getString('synology_account'), 'admin');
    });

    test('旧明文 sid 自动迁移到安全存储并清理明文', () async {
      SharedPreferences.setMockInitialValues({
        'synology_server_url': 'http://192.168.1.6:5000',
        'synology_account': 'admin',
        'synology_sid': 'legacy-sid',
      });

      final container = buildContainer();
      addTearDown(container.dispose);
      // 构造内 _restore 为异步；显式 reload 保证就绪
      await container.read(synologyAuthProvider.notifier).reloadSid();

      expect(container.read(synologyAuthProvider).isLoggedIn, isTrue);
      expect(container.read(synologyAuthProvider).sid, 'legacy-sid');
      expect(fakeApi.restoredSid, 'legacy-sid');
      expect(await mockStorage.read(key: 'synology_sid_secure'), 'legacy-sid');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('synology_sid'), isNull);
    });

    test('restoreSession：免密恢复 + 持久化安全存储', () async {
      final container = buildContainer();
      addTearDown(container.dispose);
      await container.read(synologyAuthProvider.notifier).restoreSession(
            serverUrl: 'http://10.0.0.6:5000',
            account: 'music',
            sid: 'sid-restored',
          );

      final state = container.read(synologyAuthProvider);
      expect(state.isLoggedIn, isTrue);
      expect(state.serverUrl, 'http://10.0.0.6:5000');
      expect(state.sid, 'sid-restored');
      expect(fakeApi.restoredSid, 'sid-restored');
      expect(await mockStorage.read(key: 'synology_sid_secure'),
          'sid-restored');
    });

    test('logout 清理安全存储 sid', () async {
      SharedPreferences.setMockInitialValues({
        'synology_server_url': 'http://192.168.1.6:5000',
        'synology_account': 'admin',
      });
      mockStorage.setValue('synology_sid_secure', 'sid-1');

      final container = buildContainer();
      addTearDown(container.dispose);
      await container.read(synologyAuthProvider.notifier).logout();

      expect(container.read(synologyAuthProvider).isLoggedIn, isFalse);
      expect(fakeApi.logoutCount, 1);
      expect(await mockStorage.read(key: 'synology_sid_secure'), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('synology_server_url'), isNull);
    });
  });
}
