/// 退出登录(全部账号)回归测试
///
/// 背景：设置页退出登录曾按 serviceMode 二选一（music→只退群晖、video→只退
/// Emby），另一账号登录态残留，路由守卫判定「任一登录」不跳 /login，用户点
/// 退出后 App 仍在（半退出异常，用户实测「设置→群晖音乐→返回→设置页→退出
/// 登录无反应」）。个人中心退出也只退群晖后 go('/login')，Emby 仍登录时被
/// 守卫拦回首页。修复：统一走 utils/auth_actions.dart 的 logoutAllAccounts
/// 全退（群晖 + Emby + 服务模式回退 video），由路由守卫统一重定向 /login。
///
/// 本文件固定 logoutAllAccounts 的语义，防止回退成单账号退出。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:embytok_flutter/providers/auth_provider.dart';
import 'package:embytok_flutter/providers/providers.dart';
import 'package:embytok_flutter/providers/service_mode_provider.dart';
import 'package:embytok_flutter/providers/synology_auth_provider.dart';
import 'package:embytok_flutter/providers/synology_playback_provider.dart';
import 'package:embytok_flutter/services/synology_audio_api.dart';
import 'package:embytok_flutter/utils/auth_actions.dart';

/// 停止播放 no-op：避免真实 SynologyPlaybackNotifier.stop() 触发平台通道
/// (releaseFocus) 在测试环境抛 MissingPluginException。
class _NoopPlaybackNotifier extends SynologyPlaybackNotifier {
  _NoopPlaybackNotifier(super.ref);

  @override
  Future<void> stop() async {}
}

/// 群晖 API fake：不发网络请求，logout 立即完成。
class _FakeSynoAudioApi extends SynologyAudioApi {
  @override
  Future<void> logout() async {}
}

/// Emby 认证 fake：不触发网络/安全存储/缓存失效，仅同步重置状态。
class _FakeEmbyAuthNotifier extends AuthNotifier {
  _FakeEmbyAuthNotifier(super.ref) : super() {
    state = const AuthState(
      isAuthenticated: true,
      embyServerUrl: 'http://emby.test',
      token: 'mock-token',
    );
  }

  @override
  Future<void> logout() async {
    state = const AuthState();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<ProviderContainer> buildContainer() async {
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith((ref) => _FakeEmbyAuthNotifier(ref)),
        synologyAuthProvider.overrideWith(
          (ref) => SynologyAuthNotifier(ref)
            ..state = const SynologyAuthState(
              isLoggedIn: true,
              serverUrl: 'http://nas.test',
              account: 'tester',
              sid: 'mock-sid',
            ),
        ),
        synologyAudioApiProvider.overrideWith((ref) => _FakeSynoAudioApi()),
        serviceModeProvider.overrideWith((ref) => ServiceModeNotifier()),
        synologyPlaybackProvider
            .overrideWith((ref) => _NoopPlaybackNotifier(ref)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// 挂一棵带按钮的树并 tap，触发 logoutAllAccounts（与真实按钮回调同一入口）。
  Future<void> tapLogoutButton(
      WidgetTester tester, ProviderContainer container) async {
    late WidgetRef ref;
    await tester.pumpWidget(
      ProviderScope(
        parent: container,
        child: MaterialApp(
          home: Consumer(
            builder: (context, r, _) {
              ref = r;
              return ElevatedButton(
                onPressed: () async {
                  await logoutAllAccounts(ref);
                },
                child: const Text('go'),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
  }

  testWidgets('音乐模式双账号登录时,logoutAllAccounts 全退并回退视频模式',
      (tester) async {
    final container = await buildContainer();
    // 前置：双账号均登录、音乐模式（用 setMode 持久化，避免构造期异步
    // _loadFromStorage 把临时 state 覆盖回 video）
    await container.read(serviceModeProvider.notifier)
        .setMode(AppServiceMode.music);
    expect(container.read(authProvider).isAuthenticated, isTrue);
    expect(container.read(synologyAuthProvider).isLoggedIn, isTrue);
    expect(container.read(serviceModeProvider), AppServiceMode.music);

    await tapLogoutButton(tester, container);

    // 修复前：music 分支只退群晖，Emby 残留 isAuthenticated=true →
    // 守卫不跳 /login（半退出）。修复后：双账号全退 + 模式回退 video。
    expect(container.read(authProvider).isAuthenticated, isFalse);
    expect(container.read(synologyAuthProvider).isLoggedIn, isFalse);
    expect(container.read(serviceModeProvider), AppServiceMode.video);
  });

  testWidgets('仅 Emby 登录(video 模式)时 logoutAllAccounts 幂等安全',
      (tester) async {
    final container = await buildContainer();
    // 改为：仅 Emby 登录、视频模式（群晖未登录）
    await container.read(serviceModeProvider.notifier)
        .setMode(AppServiceMode.video);
    container.read(synologyAuthProvider.notifier).state =
        const SynologyAuthState();

    await tapLogoutButton(tester, container);

    expect(container.read(authProvider).isAuthenticated, isFalse);
    expect(container.read(synologyAuthProvider).isLoggedIn, isFalse);
  });
}
