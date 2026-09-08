// 服务器注册表测试
//
// 覆盖：
// - CRUD：添加 / 更新 / 删除（含密码清理）
// - 默认服务器唯一性 / 激活状态持久化
// - resolveUrl 网络模式解析（auto 内网优先 / internal / external）
// - 持久化：重启后恢复列表与激活 id
// - 密码与 sid 写入安全存储（不落 SharedPreferences）

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:embytok_flutter/providers/auth_provider.dart'
    show secureStorageProvider;
import 'package:embytok_flutter/providers/server_registry_provider.dart';

import '../mocks/mock_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockFlutterSecureStorage mockStorage;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockStorage = MockFlutterSecureStorage();
  });

  ServerProfile profile({
    String id = 'srv_1',
    ServerKind kind = ServerKind.emby,
    String name = '家里的 Emby',
    String url = 'http://192.168.1.10:8096',
    String? internalUrl,
    String? externalUrl,
    String username = 'user',
    NetworkMode networkMode = NetworkMode.auto,
    bool isDefault = false,
  }) {
    return ServerProfile(
      id: id,
      kind: kind,
      name: name,
      url: url,
      internalUrl: internalUrl,
      externalUrl: externalUrl,
      username: username,
      networkMode: networkMode,
      isDefault: isDefault,
      lastUsed: DateTime(2026, 1, 1),
    );
  }

  ProviderContainer buildContainer() {
    return ProviderContainer(overrides: [
      secureStorageProvider.overrideWithValue(mockStorage),
    ]);
  }

  group('ServerProfile.resolveUrl', () {
    test('auto：内网地址优先，无内网地址用主地址', () {
      expect(
        profile(internalUrl: 'http://192.168.1.10:5000').resolveUrl(),
        'http://192.168.1.10:5000',
      );
      expect(profile().resolveUrl(), 'http://192.168.1.10:8096');
    });

    test('internal / external 模式取对应地址，缺失回退主地址', () {
      expect(
        profile(
          internalUrl: 'http://10.0.0.5:8096',
          networkMode: NetworkMode.internal,
        ).resolveUrl(),
        'http://10.0.0.5:8096',
      );
      expect(
        profile(
          externalUrl: 'https://emby.example.com',
          networkMode: NetworkMode.external,
        ).resolveUrl(),
        'https://emby.example.com',
      );
      // internal 模式但无内网地址 → 主地址
      expect(profile(networkMode: NetworkMode.internal).resolveUrl(),
          'http://192.168.1.10:8096');
    });
  });

  group('ServerRegistryNotifier', () {
    test('添加服务器并持久化，密码写入安全存储', () async {
      final container = buildContainer();
      addTearDown(container.dispose);
      final notifier = container.read(serverRegistryProvider.notifier);

      await notifier.add(
        profile(),
        password: 'secret-pw',
      );
      expect(container.read(serverRegistryProvider), hasLength(1));

      // 密码进安全存储，SharedPreferences 无密码明文
      final stored = await mockStorage.read(key: 'server_password_srv_1');
      expect(stored, 'secret-pw');
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('server_registry_v1')!;
      expect(raw.contains('secret-pw'), isFalse);
      expect(raw.contains('srv_1'), isTrue);
    });

    test('更新服务器保留 id，密码可选更新', () async {
      final container = buildContainer();
      addTearDown(container.dispose);
      final notifier = container.read(serverRegistryProvider.notifier);
      await notifier.add(profile(), password: 'old');

      await notifier.update(
        profile(name: '新名字', url: 'http://10.0.0.9:8096'),
        password: 'new-pw',
      );
      final servers = container.read(serverRegistryProvider);
      expect(servers.single.name, '新名字');
      expect(servers.single.url, 'http://10.0.0.9:8096');
      expect(servers.single.id, 'srv_1');
      expect(await mockStorage.read(key: 'server_password_srv_1'), 'new-pw');
    });

    test('删除服务器清理密码、sid 与激活状态', () async {
      final container = buildContainer();
      addTearDown(container.dispose);
      final notifier = container.read(serverRegistryProvider.notifier);
      await notifier.add(profile(), password: 'pw', synoSid: 'sid-1');
      await container
          .read(activeServerIdProvider.notifier)
          .setActive('srv_1');

      await notifier.remove('srv_1');
      expect(container.read(serverRegistryProvider), isEmpty);
      expect(await mockStorage.read(key: 'server_password_srv_1'), isNull);
      expect(await mockStorage.read(key: 'server_syno_sid_srv_1'), isNull);
      expect(container.read(activeServerIdProvider), isNull);
    });

    test('setDefault 保证唯一默认', () async {
      final container = buildContainer();
      addTearDown(container.dispose);
      final notifier = container.read(serverRegistryProvider.notifier);
      await notifier.add(profile());
      await notifier.add(profile(
          id: 'srv_2', name: '二', url: 'http://10.0.0.2:8096'));
      await notifier.add(profile(
          id: 'srv_3', name: '三', url: 'http://10.0.0.3:8096'));

      await notifier.setDefault('srv_2');
      final defaults =
          container.read(serverRegistryProvider).where((s) => s.isDefault);
      expect(defaults.single.id, 'srv_2');

      await notifier.setDefault('srv_3');
      final defaults2 =
          container.read(serverRegistryProvider).where((s) => s.isDefault);
      expect(defaults2.single.id, 'srv_3');
    });

    test('激活 id 持久化：重启后恢复', () async {
      final container = buildContainer();
      await container.read(serverRegistryProvider.notifier).add(profile());
      await container
          .read(activeServerIdProvider.notifier)
          .setActive('srv_1');
      container.dispose();

      final restarted = buildContainer();
      addTearDown(restarted.dispose);
      await restarted.read(serverRegistryProvider.notifier).reload();
      await restarted.read(activeServerIdProvider.notifier).reload();      expect(restarted.read(serverRegistryProvider), hasLength(1));
      expect(restarted.read(activeServerIdProvider), 'srv_1');
      expect(restarted.read(activeServerProvider)?.name, '家里的 Emby');
    });

    test('activeServerProvider：未激活或 id 不存在时返回 null', () async {
      final container = buildContainer();
      addTearDown(container.dispose);
      expect(container.read(activeServerProvider), isNull);
      await container.read(serverRegistryProvider.notifier).add(profile());
      expect(container.read(activeServerProvider), isNull);
      await container
          .read(activeServerIdProvider.notifier)
          .setActive('not-exist');
      expect(container.read(activeServerProvider), isNull);
    });
  });
}

