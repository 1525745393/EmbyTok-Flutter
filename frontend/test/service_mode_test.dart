// 服务模式（视频/音乐）测试
//
// 覆盖：
// - serviceModeProvider：默认视频模式 / setMode 持久化 / 非法存储值回退
// - SynologyMusicView.showBackButton：作为音乐模式首页时隐藏返回按钮，
//   独立路由（/music）进入时保留返回按钮

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:embytok_flutter/models/audio_models.dart';
import 'package:embytok_flutter/providers/service_mode_provider.dart';
import 'package:embytok_flutter/providers/synology_auth_provider.dart';
import 'package:embytok_flutter/providers/synology_music_provider.dart';
import 'package:embytok_flutter/providers/synology_playback_provider.dart';
import 'package:embytok_flutter/views/synology_music_view.dart';

/// 假认证 Notifier：跳过真实登录，构造后可手动置为已登录
class _FakeAuthNotifier extends SynologyAuthNotifier {
  _FakeAuthNotifier(super.ref) : super() {
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
    final song = AudioSong(
      id: 'music_1',
      title: '测试歌曲标题',
      tag: const AudioSongTag(artist: '测试歌手'),
    );
    state = SynologyPlaybackState(
      currentSong: song,
      queue: [song],
      currentIndex: 0,
      isPlaying: true,
      isLoading: false,
      position: const Duration(seconds: 65),
      duration: const Duration(minutes: 4, seconds: 20),
      coverUrl: null,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('serviceModeProvider', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('默认视频服务模式', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(serviceModeProvider), AppServiceMode.video);
    });

    test('setMode(music) 立即更新状态', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(serviceModeProvider.notifier).setMode(AppServiceMode.music);
      expect(container.read(serviceModeProvider), AppServiceMode.music);
    });

    test('模式切换持久化：新容器恢复音乐模式', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      await container
          .read(serviceModeProvider.notifier)
          .setMode(AppServiceMode.music);
      container.dispose();

      // 模拟重启：新容器从存储恢复
      final restarted = ProviderContainer();
      addTearDown(restarted.dispose);
      await restarted.read(serviceModeProvider.notifier).reload();
      expect(restarted.read(serviceModeProvider), AppServiceMode.music);
    });

    test('非法/未知存储值回退视频模式', () async {
      SharedPreferences.setMockInitialValues({'app_service_mode': 'tv'});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(serviceModeProvider.notifier).reload();
      expect(container.read(serviceModeProvider), AppServiceMode.video);
    });
  });

  group('SynologyMusicView.showBackButton', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    Widget buildView({required bool showBackButton}) {
      return ProviderScope(
        overrides: [
          synologyAuthProvider.overrideWith((ref) => _FakeAuthNotifier(ref)),
          synologyMusicProvider.overrideWith((ref) => _FakeMusicNotifier(ref)),
          synologyPlaybackProvider
              .overrideWith((ref) => _FakePlaybackNotifier(ref)),
        ],
        child: MaterialApp(
          // M2 涟漪规避 Flutter 3.47.2 shader 已知缺陷（见 README）
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: SynologyMusicView(showBackButton: showBackButton),
        ),
      );
    }

    testWidgets('showBackButton=true（独立路由）→ 显示返回按钮', (tester) async {
      await tester.pumpWidget(buildView(showBackButton: true));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('showBackButton=false（音乐模式首页）→ 隐藏返回按钮', (tester) async {
      await tester.pumpWidget(buildView(showBackButton: false));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.arrow_back), findsNothing);
      // 标题仍在
      expect(find.text('群晖音乐'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
