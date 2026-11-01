// 首页服务模式实时切换测试
//
// 覆盖：
// - 默认视频模式：'/' 首页显示 HomeScaffold（视频流）
// - 切到音乐模式：首页立即重建为 MainView（群晖音乐库），无需重启 App
// - 切回视频模式：首页立即恢复 HomeScaffold
//
// 回归背景：'/' 路由 builder 曾用 ref.read 一次性读取 serviceModeProvider
// （不建立监听），切换模式/退出群晖账号后首页不重建，需重启 App 才生效。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:embytok_flutter/app.dart';
import 'package:embytok_flutter/models/models.dart';
import 'package:embytok_flutter/providers/auth_provider.dart';
import 'package:embytok_flutter/providers/service_mode_provider.dart';
import 'package:embytok_flutter/providers/synology_auth_provider.dart';
import 'package:embytok_flutter/providers/synology_music_provider.dart';
import 'package:embytok_flutter/providers/synology_playback_provider.dart';
import 'package:embytok_flutter/views/home_scaffold.dart';
import 'package:embytok_flutter/views/main_view.dart';

/// 测试用 AuthNotifier：继承 AuthNotifier，跳过 _loadFromStorage 异步加载
/// 与 back_navigation_test.dart / home_scaffold_test.dart 中实现一致
class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(super.ref, AuthState initialState) {
    state = initialState;
  }
}

/// 假群晖认证 Notifier：跳过真实登录，构造后置为已登录
class _FakeSynoAuthNotifier extends SynologyAuthNotifier {
  _FakeSynoAuthNotifier(super.ref) : super() {
    state = const SynologyAuthState(
      isLoggedIn: true,
      serverUrl: 'http://192.168.1.6:5000',
      account: 'tester',
      sid: 'mock-sid',
    );
  }
}

/// 假音乐库 Notifier：不触发网络加载
class _FakeMusicNotifier extends SynologyMusicNotifier {
  _FakeMusicNotifier(super.ref) : super();
}

/// 假播放 Notifier：直接持有播放中的曲目，不触发播放器
class _FakePlaybackNotifier extends SynologyPlaybackNotifier {
  _FakePlaybackNotifier(super.ref) : super() {
    const song = AudioSong(
      id: 'music_1',
      title: '测试歌曲标题',
      tag: AudioSongTag(artist: '测试歌手'),
    );
    state = const SynologyPlaybackState(
      currentSong: song,
      queue: [song],
      currentIndex: 0,
      isPlaying: true,
      isLoading: false,
      position: Duration(seconds: 65),
      duration: Duration(minutes: 4, seconds: 20),
      coverUrl: null,
    );
  }
}

/// 构造已登录状态的 EmbyTokApp，进入首页（默认视频模式）
Widget _loggedInApp() {
  return ProviderScope(
    overrides: [
      authProvider.overrideWith(
        (ref) => _FakeAuthNotifier(
          ref,
          const AuthState(
            isAuthenticated: true,
            user: User(
              id: 'test-user',
              name: 'test',
              accessToken: 'test-token',
            ),
            embyServerUrl: 'http://emby.example.com',
            token: 'test-token',
          ),
        ),
      ),
      synologyAuthProvider.overrideWith((ref) => _FakeSynoAuthNotifier(ref)),
      synologyMusicProvider.overrideWith((ref) => _FakeMusicNotifier(ref)),
      synologyPlaybackProvider
          .overrideWith((ref) => _FakePlaybackNotifier(ref)),
    ],
    child: const EmbyTokApp(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('首页按服务模式实时切换', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('切音乐模式首页立即显示音乐库，无需重启', (tester) async {
      await tester.pumpWidget(_loggedInApp());
      await tester.pumpAndSettle();

      // 默认视频模式 → 视频流首页
      expect(find.byType(HomeScaffold), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeScaffold)),
      );
      expect(container.read(serviceModeProvider), AppServiceMode.video);

      // 切换到音乐模式 → 首页应实时重建为音乐库（watch 生效，非重启后）
      await container.read(serviceModeProvider.notifier)
          .setMode(AppServiceMode.music);
      await tester.pumpAndSettle();

      expect(find.byType(HomeScaffold), findsNothing);
      expect(find.byType(MainView), findsOneWidget);

      // 切回视频模式 → 首页立即恢复视频流
      await container.read(serviceModeProvider.notifier)
          .setMode(AppServiceMode.video);
      await tester.pumpAndSettle();

      expect(find.byType(HomeScaffold), findsOneWidget);
      expect(find.byType(MainView), findsNothing);

      // 清理后台 Timer：卸载 App + 推进虚拟时间（避免 !timersPending）
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 30));
      await tester.pump(const Duration(seconds: 30));
    });
  });
}
