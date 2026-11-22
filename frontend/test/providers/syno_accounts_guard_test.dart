/// 批次7（P3-3 / P3-4）群晖账号 Provider 守卫与登出清桶回归测试
///
/// - P3-3：remove 不能删除当前登录账号——Provider 层自我守卫（纵深防御），
///   拒绝删除并返回 false，列表与密码键均不被破坏。
/// - P3-4：群晖登出需同时解除「当前账号指针」（currentAccountId 与持久化
///   current key），否则 accountScopedKey 仍按旧账号分桶，新登录会话落到陈旧桶。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:embytok_flutter/providers/auth_provider.dart';
import 'package:embytok_flutter/providers/service_mode_provider.dart';
import 'package:embytok_flutter/providers/syno_accounts_provider.dart';
import 'package:embytok_flutter/providers/synology_auth_provider.dart';
import 'package:embytok_flutter/providers/synology_playback_provider.dart';
import 'package:embytok_flutter/services/synology_audio_api.dart';

import '../mocks/mock_secure_storage.dart';

/// 与 syno_accounts_provider 内 `_kCurrentKey` 一致，用于断言持久化指针被清除。
const _kCurrentKey = 'syno_account_current_v1';

class _FakeSynoAudioApi extends SynologyAudioApi {
  @override
  Future<void> logout() async {}
}

class _NoopPlaybackNotifier extends SynologyPlaybackNotifier {
  _NoopPlaybackNotifier(super.ref);

  @override
  Future<void> stop() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// 让构造期异步 `_load()` 落定，避免其回填空 prefs 覆盖测试写入的 state。
  Future<void> warmUp(ProviderContainer container) async {
    container.read(synoAccountsProvider);
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }

  ProviderContainer buildContainer(MockFlutterSecureStorage storage) {
    final container = ProviderContainer(overrides: [
      secureStorageProvider.overrideWithValue(storage),
      synologyAudioApiProvider.overrideWith((ref) => _FakeSynoAudioApi()),
      serviceModeProvider.overrideWith((ref) => ServiceModeNotifier()),
      synologyPlaybackProvider
          .overrideWith((ref) => _NoopPlaybackNotifier(ref)),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  test('P3-3：remove 当前登录账号被守卫拒绝，列表与密码键保留', () async {
    final storage = MockFlutterSecureStorage();
    final container = buildContainer(storage);
    await warmUp(container);
    final notifier = container.read(synoAccountsProvider.notifier);

    final a1 = await notifier.addAccount(
        serverUrl: 'http://nas1.test:5000', username: 'alice', password: 'p1');
    await notifier.addAccount(
        serverUrl: 'http://nas2.test:5000', username: 'bob', password: 'p2');
    await notifier.setCurrent(a1.accountId);

    expect(container.read(synoAccountsProvider).currentAccountId,
        a1.accountId);

    final removedCurrent = await notifier.remove(a1.accountId);

    expect(removedCurrent, isFalse, reason: '当前账号不应被 remove 守卫放行');
    final state = container.read(synoAccountsProvider);
    expect(
        state.accounts.map((a) => a.accountId), contains(a1.accountId),
        reason: '被守卫拒绝后当前账号仍应留在列表');
    expect(state.currentAccountId, a1.accountId);
    expect(await storage.read(key: 'syno_pwd_${a1.accountId}'), 'p1',
        reason: '被拒绝删除时密码键不应被清除');
  });

  test('P3-3：remove 非当前账号正常删除并返回 true', () async {
    final storage = MockFlutterSecureStorage();
    final container = buildContainer(storage);
    await warmUp(container);
    final notifier = container.read(synoAccountsProvider.notifier);

    final a1 = await notifier.addAccount(
        serverUrl: 'http://nas1.test:5000', username: 'alice', password: 'p1');
    final a2 = await notifier.addAccount(
        serverUrl: 'http://nas2.test:5000', username: 'bob', password: 'p2');
    await notifier.setCurrent(a1.accountId);

    final removedOther = await notifier.remove(a2.accountId);

    expect(removedOther, isTrue);
    final state = container.read(synoAccountsProvider);
    expect(state.accounts.map((a) => a.accountId), [a1.accountId]);
    expect(await storage.read(key: 'syno_pwd_${a2.accountId}'), isNull);
  });

  test('P3-4：群晖 logout 解除当前账号指针并清除持久化 current key', () async {
    final storage = MockFlutterSecureStorage();
    final container = buildContainer(storage);
    await warmUp(container);
    final accounts = container.read(synoAccountsProvider.notifier);

    final a1 = await accounts.addAccount(
        serverUrl: 'http://nas1.test:5000', username: 'alice', password: 'p1');
    await accounts.setCurrent(a1.accountId);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_kCurrentKey), a1.accountId);
    expect(container.read(synoAccountsProvider).currentAccountId, a1.accountId);

    await container.read(synologyAuthProvider.notifier).logout();

    final after = container.read(synoAccountsProvider);
    expect(after.currentAccountId, isNull,
        reason: '登出后不应再绑定任何群晖账号');
    expect(prefs.getString(_kCurrentKey), isNull,
        reason: '持久化 current key 需一并清除，避免 accountScopedKey 落到陈旧桶');
    expect(after.accounts, isNotEmpty,
        reason: '登出仅解除当前指针，已保存的账号列表保留');
  });
}
