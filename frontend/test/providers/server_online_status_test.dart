// 阶段 2：注册表条目在线判定 + 在线置顶排序 + 取消勾选登出隔离
//
// 覆盖：
// - sortServersByOnline：在线在前（最近使用倒序），未登录在后保持原序；
// - isRegistryServerOnline：视频按 id 槽命中 / host 兜底，群晖按 host+账号；
// - logoutRegistrySession：视频按槽登出不影响其他在线槽；群晖非当前条目不动。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:embytok_flutter/providers/auth_provider.dart';
import 'package:embytok_flutter/providers/server_registry_provider.dart';
import 'package:embytok_flutter/providers/synology_auth_provider.dart';
import 'package:embytok_flutter/views/server_switch_helpers.dart';

ServerProfile _p({
  required String id,
  required ServerKind kind,
  required String url,
  String username = 'user',
  DateTime? lastUsed,
}) {
  return ServerProfile(
    id: id,
    kind: kind,
    name: id,
    url: url,
    username: username,
    lastUsed: lastUsed ?? DateTime(2026, 1, 1),
  );
}

void main() {
  group('sortServersByOnline 在线置顶', () {
    test('在线在前且按最近使用倒序，未登录在后保持原相对顺序', () {
      final a = _p(id: 'off1', kind: ServerKind.emby, url: 'http://a:8096',
          lastUsed: DateTime(2026, 1, 3));
      final b = _p(id: 'on1', kind: ServerKind.emby, url: 'http://b:8096',
          lastUsed: DateTime(2026, 1, 1));
      final c = _p(id: 'off2', kind: ServerKind.emby, url: 'http://c:8096',
          lastUsed: DateTime(2026, 1, 2));
      final d = _p(id: 'on2', kind: ServerKind.emby, url: 'http://d:8096',
          lastUsed: DateTime(2026, 1, 5));

      bool online(ServerProfile s) => s.id == 'on1' || s.id == 'on2';
      final result = sortServersByOnline([a, b, c, d], online);

      // 在线组：on2（1/5）在前，on1（1/1）在后
      expect(result.map((s) => s.id).toList(), ['on2', 'on1', 'off1', 'off2']);
    });

    test('全部未登录时保持原顺序', () {
      final list = [
        _p(id: 'x', kind: ServerKind.emby, url: 'http://x:8096'),
        _p(id: 'y', kind: ServerKind.emby, url: 'http://y:8096'),
      ];
      final result = sortServersByOnline(list, (_) => false);
      expect(result.map((s) => s.id).toList(), ['x', 'y']);
    });
  });

  group('isRegistryServerOnline 视频类', () {
    const auth = AuthState(
      isAuthenticated: true,
      embyServerUrl: 'http://192.168.1.20:8096',
    );

    test('id 槽在线即判定在线（多槽命中）', () {
      final server =
          _p(id: 'srv_emby', kind: ServerKind.emby, url: 'http://x:8096');
      expect(
        isRegistryServerOnline(server, auth, (key) => key == 'srv_emby',
            const SynologyAuthState()),
        isTrue,
      );
    });

    test('id 槽未命中时按当前激活槽 host 兜底', () {
      final server = _p(
          id: 'srv_emby',
          kind: ServerKind.emby,
          url: 'http://192.168.1.20:8096');
      expect(
        isRegistryServerOnline(server, auth, (_) => false,
            const SynologyAuthState()),
        isTrue,
      );
    });

    test('host 不匹配判定未登录', () {
      final server = _p(
          id: 'srv_emby',
          kind: ServerKind.emby,
          url: 'http://192.168.1.99:8096');
      expect(
        isRegistryServerOnline(server, auth, (_) => false,
            const SynologyAuthState()),
        isFalse,
      );
    });
  });

  group('isRegistryServerOnline 群晖', () {
    test('id 槽在线即判定在线（多槽命中，优先于 host 兜底）', () {
      final server = _p(
        id: 'srv_nas',
        kind: ServerKind.synology,
        url: 'http://x:5000',
        username: 'nas-user',
      );
      const syno = SynologyAuthState();
      expect(
        isRegistryServerOnline(server, const AuthState(), (_) => false, syno,
            isSynoSessionOnline: (key) => key == 'srv_nas'),
        isTrue,
      );
    });

    test('host + 账号匹配判定在线', () {
      final server = _p(
        id: 'srv_nas',
        kind: ServerKind.synology,
        url: 'http://192.168.1.30:5000',
        username: 'nas-user',
      );
      const syno = SynologyAuthState(
        isLoggedIn: true,
        serverUrl: 'http://192.168.1.30:5000',
        account: 'nas-user',
      );
      expect(
        isRegistryServerOnline(
            server, const AuthState(), (_) => false, syno),
        isTrue,
      );
    });

    test('账号不符判定未登录', () {
      final server = _p(
        id: 'srv_nas',
        kind: ServerKind.synology,
        url: 'http://192.168.1.30:5000',
        username: 'other',
      );
      const syno = SynologyAuthState(
        isLoggedIn: true,
        serverUrl: 'http://192.168.1.30:5000',
        account: 'nas-user',
      );
      expect(
        isRegistryServerOnline(
            server, const AuthState(), (_) => false, syno),
        isFalse,
      );
    });
  });

  group('logoutRegistrySession 登出隔离', () {
    testWidgets('视频按槽登出不影响其他在线槽', (tester) async {
      final onlineKeys = {'srv_a', 'srv_b'};
      final removed = <String>[];
      await tester.pumpWidget(_host([
        authProvider
            .overrideWith((ref) => _FakeVideoAuth(ref, onlineKeys, removed)),
      ]));
      await tester.pumpAndSettle();

      final server =
          _p(id: 'srv_a', kind: ServerKind.emby, url: 'http://a:8096');
      await logoutRegistrySession(capturedRef, server);

      expect(removed, ['srv_a']);
      expect(onlineKeys, {'srv_b'}, reason: '登出 A 不应连带清掉 B 槽');
    });

    testWidgets('群晖非当前会话条目不触发登出', (tester) async {
      _FakeSynoAuth? fake;
      await tester.pumpWidget(_host([
        synologyAuthProvider.overrideWith((ref) => fake = _FakeSynoAuth(ref)),
      ]));
      await tester.pumpAndSettle();
      capturedRef.read(synologyAuthProvider); // 触发 override 闭包初始化桩
      fake!.state = const SynologyAuthState(
        isLoggedIn: true,
        serverUrl: 'http://192.168.1.30:5000',
        account: 'nas-user',
      );

      // host 不同的群晖条目
      final other = _p(
          id: 'srv_nas2',
          kind: ServerKind.synology,
          url: 'http://192.168.1.31:5000');
      await logoutRegistrySession(capturedRef, other);

      expect(fake!.logoutCalls, 0);
    });

    testWidgets('群晖同 host 但账号不符不触发登出', (tester) async {
      _FakeSynoAuth? fake;
      await tester.pumpWidget(_host([
        synologyAuthProvider.overrideWith((ref) => fake = _FakeSynoAuth(ref)),
      ]));
      await tester.pumpAndSettle();
      capturedRef.read(synologyAuthProvider);
      fake!.state = const SynologyAuthState(
        isLoggedIn: true,
        serverUrl: 'http://192.168.1.30:5000',
        account: 'nas-user',
      );

      // 同 host、不同账号的群晖条目
      final other = _p(
          id: 'srv_nas2',
          kind: ServerKind.synology,
          url: 'http://192.168.1.30:5000',
          username: 'other');
      await logoutRegistrySession(capturedRef, other);

      expect(fake!.logoutCalls, 0);
    });

    testWidgets('群晖 id 槽命中走按槽登出，不调全局 logout', (tester) async {
      _FakeSynoAuth? fake;
      await tester.pumpWidget(_host([
        synologyAuthProvider.overrideWith(
            (ref) => fake = _FakeSynoAuth(ref, onlineKeys: {'srv_nas'})),
      ]));
      await tester.pumpAndSettle();
      capturedRef.read(synologyAuthProvider);

      final server = _p(
          id: 'srv_nas',
          kind: ServerKind.synology,
          url: 'http://192.168.1.30:5000',
          username: 'nas-user');
      await logoutRegistrySession(capturedRef, server);

      expect(fake!.removed, ['srv_nas']);
      expect(fake!.logoutCalls, 0,
          reason: '按槽登出不应触发全局 logout 的模式回退副作用');
    });
  });
}

late WidgetRef capturedRef;

Widget _host(List<Override> overrides) => ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) {
            capturedRef = ref;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

/// 视频认证桩：模拟多槽在线，记录按槽登出。
class _FakeVideoAuth extends AuthNotifier {
  _FakeVideoAuth(super.ref, this._onlineKeys, this._removed);

  final Set<String> _onlineKeys;
  final List<String> _removed;

  @override
  bool isSessionOnline(String key) => _onlineKeys.contains(key);

  @override
  String? get activeSessionId =>
      _onlineKeys.isEmpty ? null : _onlineKeys.first;

  @override
  Future<void> logoutSession(String key) async {
    _onlineKeys.remove(key);
    _removed.add(key);
  }
}

/// 群晖认证桩：记录登出调用，可模拟多槽在线。
class _FakeSynoAuth extends SynologyAuthNotifier {
  _FakeSynoAuth(super.ref, {Set<String>? onlineKeys})
      : _onlineKeys = onlineKeys ?? {};

  final Set<String> _onlineKeys;
  final List<String> removed = [];
  int logoutCalls = 0;

  @override
  bool isSessionOnline(String key) => _onlineKeys.contains(key);

  @override
  Future<void> logoutSession(String key) async {
    _onlineKeys.remove(key);
    removed.add(key);
  }

  @override
  Future<void> logout() async {
    logoutCalls++;
    state = const SynologyAuthState();
  }
}
