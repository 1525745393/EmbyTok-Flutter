// 回归测试（P2-3）：群晖双存储桥接同步
//
// 背景：注册表（serverRegistryProvider）与群晖账号列表（synoAccountsProvider）
// 此前各写一边，互不可见。本批次在 account_bridge 提供双向桥接，固定：
// - 注册表群晖条目写入 → 账号列表出现同端点+用户名账号；
// - 账号列表写入 → 注册表出现对应群晖条目；
// - 任一侧删除 → 另一侧对应条目消失；
// - 去重按 host+端口（协议差异视为同一端点）。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:embytok_flutter/providers/auth_provider.dart';
import 'package:embytok_flutter/providers/server_registry_provider.dart';
import 'package:embytok_flutter/providers/syno_accounts_provider.dart';
import 'package:embytok_flutter/views/account_bridge.dart';

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

ServerProfile _synoProfile({
  required String id,
  required String url,
  required String username,
}) {
  return ServerProfile(
    id: id,
    kind: ServerKind.synology,
    name: 'nas',
    url: url,
    username: username,
    lastUsed: DateTime(2026, 1, 1),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WidgetRef capturedRef;

  Widget buildHost(_FakeSecureStorage storage) {
    return ProviderScope(
      overrides: [secureStorageProvider.overrideWithValue(storage)],
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

  /// 触发两个 provider 构造并等待其异步 _load 落地，避免 fire-and-forget
  /// 恢复回调晚于写入、把 state 覆盖回空列表。
  Future<void> _warmUp(WidgetTester tester) async {
    capturedRef.read(serverRegistryProvider);
    capturedRef.read(synoAccountsProvider);
    await tester.pump(const Duration(milliseconds: 10));
  }

  testWidgets('注册表群晖条目桥接到账号列表', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = _FakeSecureStorage({});
    await tester.pumpWidget(buildHost(storage));
    await tester.pumpAndSettle();
    await _warmUp(tester);

    final profile = _synoProfile(
      id: 'srv_1',
      url: 'http://nas.test:5000',
      username: 'nas-user',
    );
    await bridgeRegistryToAccounts(capturedRef, profile, 'pwd');

    final accounts = capturedRef.read(synoAccountsProvider).accounts;
    expect(accounts, hasLength(1));
    expect(accounts.first.username, 'nas-user');
    expect(sameEndpoint(accounts.first.serverUrl, 'http://nas.test:5000'), isTrue);
  });

  testWidgets('群晖账号桥接到注册表', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = _FakeSecureStorage({});
    await tester.pumpWidget(buildHost(storage));
    await tester.pumpAndSettle();
    await _warmUp(tester);

    await bridgeAccountToRegistry(
      capturedRef,
      serverUrl: 'https://nas.test:5000',
      username: 'nas-user',
      password: 'pwd',
    );

    final servers = capturedRef.read(serverRegistryProvider);
    expect(servers, hasLength(1));
    expect(servers.first.kind, ServerKind.synology);
    expect(servers.first.username, 'nas-user');
    expect(sameEndpoint(servers.first.url, 'http://nas.test:5000'), isTrue);
  });

  testWidgets('删除注册表群晖条目 → 账号列表对应账号消失', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = _FakeSecureStorage({});
    await tester.pumpWidget(buildHost(storage));
    await tester.pumpAndSettle();
    await _warmUp(tester);

    final profile = _synoProfile(
      id: 'srv_1',
      url: 'http://nas.test:5000',
      username: 'nas-user',
    );
    await bridgeRegistryToAccounts(capturedRef, profile, 'pwd');
    expect(capturedRef.read(synoAccountsProvider).accounts, hasLength(1));

    await bridgeRemoveRegistryToAccounts(capturedRef, profile);

    expect(capturedRef.read(synoAccountsProvider).accounts, isEmpty);
  });

  testWidgets('删除群晖账号 → 注册表对应群晖条目消失', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = _FakeSecureStorage({});
    await tester.pumpWidget(buildHost(storage));
    await tester.pumpAndSettle();
    await _warmUp(tester);

    await bridgeAccountToRegistry(
      capturedRef,
      serverUrl: 'http://nas.test:5000',
      username: 'nas-user',
      password: 'pwd',
    );
    expect(capturedRef.read(serverRegistryProvider), hasLength(1));

    final account = SynoAccount(
      accountId: 'acct_x',
      serverUrl: 'http://nas.test:5000',
      username: 'nas-user',
    );
    await bridgeRemoveAccountToRegistry(capturedRef, account);

    expect(capturedRef.read(serverRegistryProvider), isEmpty);
  });

  test('sameEndpoint：协议差异视为同一端点；host/端口不同则不同', () {
    expect(sameEndpoint('http://nas.test:5000', 'https://nas.test:5000'), isTrue);
    expect(sameEndpoint('http://nas.test:5000', 'http://nas.test:5000/'), isTrue);
    expect(sameEndpoint('http://nas.test:5000', 'http://nas.test:5001'), isFalse);
    expect(sameEndpoint('http://nas.test:5000', 'http://other.test:5000'), isFalse);
  });
}
