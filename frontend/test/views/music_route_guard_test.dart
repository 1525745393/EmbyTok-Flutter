// /music 路由模式/登录守卫测试
//
// 修复背景：设置页「音乐服务」分组与 /music 路由原本无模式/登录区分，
// 视频模式下设置页可见音乐入口、且可直接访问音乐浏览页。修复后：
// - 设置页音乐服务分组仅音乐模式显示（见 settings_mode_filter_test.dart）
// - /music 路由要求「群晖已登录且音乐模式」，否则重定向回首页
//   （与登录页账号类型↔模式对称联动一致）

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:embytok_flutter/app.dart';
import 'package:embytok_flutter/models/models.dart';
import 'package:embytok_flutter/providers/auth_provider.dart';
import 'package:embytok_flutter/providers/synology_auth_provider.dart';
import 'package:embytok_flutter/providers/synology_music_provider.dart';
import 'package:embytok_flutter/providers/synology_playback_provider.dart';
import 'package:embytok_flutter/views/home_scaffold.dart';
import 'package:embytok_flutter/views/main_view.dart';
import 'package:embytok_flutter/views/music/artist_detail_page.dart';
import 'package:embytok_flutter/views/synology_music_view.dart';

/// Emby 已登录（默认视频模式）
class _FakeEmbyAuth extends AuthNotifier {
  _FakeEmbyAuth(super.ref, AuthState initialState) {
    state = initialState;
  }
}

/// 群晖已登录（与 mode_root_test 同构，跳过真实登录）
class _FakeSynoAuthLoggedIn extends SynologyAuthNotifier {
  _FakeSynoAuthLoggedIn(super.ref) : super() {
    state = const SynologyAuthState(
      isLoggedIn: true,
      serverUrl: 'http://192.168.1.6:5000',
      account: 'tester',
      sid: 'mock-sid',
    );
  }
}

/// 群晖未登录（显式保持默认未登录态）
class _FakeSynoAuthLoggedOut extends SynologyAuthNotifier {
  _FakeSynoAuthLoggedOut(super.ref) : super();
}

/// 假音乐库 Notifier：不触发网络加载
class _FakeMusicNotifier extends SynologyMusicNotifier {
  _FakeMusicNotifier(super.ref) : super();
}

/// 假播放 Notifier：不触发播放器
class _FakePlaybackNotifier extends SynologyPlaybackNotifier {
  _FakePlaybackNotifier(super.ref) : super();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Emby 登录（视频模式、群晖未登录）访问 /music 重定向回首页', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(
            (ref) => _FakeEmbyAuth(
              ref,
              const AuthState(
                isAuthenticated: true,
                user: User(id: 'u1', name: 'tester', accessToken: 'tok'),
                embyServerUrl: 'http://emby.example.com',
                token: 'tok',
              ),
            ),
          ),
          synologyAuthProvider
              .overrideWith((ref) => _FakeSynoAuthLoggedOut(ref)),
          synologyMusicProvider.overrideWith((ref) => _FakeMusicNotifier(ref)),
          synologyPlaybackProvider
              .overrideWith((ref) => _FakePlaybackNotifier(ref)),
        ],
        child: const EmbyTokApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(HomeScaffold), findsOneWidget);

    final router = GoRouter.of(tester.element(find.byType(HomeScaffold)));
    router.go('/music');
    await tester.pumpAndSettle();

    expect(find.byType(SynologyMusicView), findsNothing,
        reason: '视频模式/群晖未登录不应进入音乐浏览页');
    expect(find.byType(HomeScaffold), findsOneWidget,
        reason: '守卫应重定向回首页');

    // 清理后台 Timer：卸载 App + 推进虚拟时间（避免 !timersPending）
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('群晖已登录且音乐模式访问 /music 正常渲染', (tester) async {
    SharedPreferences.setMockInitialValues({'app_service_mode': 'music'});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          synologyAuthProvider
              .overrideWith((ref) => _FakeSynoAuthLoggedIn(ref)),
          synologyMusicProvider.overrideWith((ref) => _FakeMusicNotifier(ref)),
          synologyPlaybackProvider
              .overrideWith((ref) => _FakePlaybackNotifier(ref)),
        ],
        child: const EmbyTokApp(),
      ),
    );
    await tester.pumpAndSettle();
    // 音乐模式首页应为群晖音乐库（MainView）
    expect(find.byType(MainView), findsOneWidget);

    final router = GoRouter.of(tester.element(find.byType(MainView)));
    router.go('/music');
    await tester.pumpAndSettle();

    expect(find.byType(SynologyMusicView), findsOneWidget,
        reason: '群晖已登录且音乐模式应正常渲染音乐浏览页');

    // 清理后台 Timer：卸载 App + 推进虚拟时间（避免 !timersPending）；
    // 音乐模式 Timer 周期较长，与 mode_root_test 一致推进 30s×2
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('Emby 登录（视频模式）深链访问歌手详情 /music/artist 重定向回首页',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(
            (ref) => _FakeEmbyAuth(
              ref,
              const AuthState(
                isAuthenticated: true,
                user: User(id: 'u1', name: 'tester', accessToken: 'tok'),
                embyServerUrl: 'http://emby.example.com',
                token: 'tok',
              ),
            ),
          ),
          synologyAuthProvider
              .overrideWith((ref) => _FakeSynoAuthLoggedOut(ref)),
          synologyMusicProvider.overrideWith((ref) => _FakeMusicNotifier(ref)),
          synologyPlaybackProvider
              .overrideWith((ref) => _FakePlaybackNotifier(ref)),
        ],
        child: const EmbyTokApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(HomeScaffold), findsOneWidget);

    final router = GoRouter.of(tester.element(find.byType(HomeScaffold)));
    router.go('/music/artist/周杰伦');
    await tester.pumpAndSettle();

    expect(find.byType(ArtistDetailPage), findsNothing,
        reason: '视频模式/群晖未登录不应进入歌手详情页');
    expect(find.byType(HomeScaffold), findsOneWidget,
        reason: '守卫应重定向回首页');

    // 清理后台 Timer：卸载 App + 推进虚拟时间（避免 !timersPending）
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}
