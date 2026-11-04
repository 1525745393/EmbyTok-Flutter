// 回归测试：P2-5 群晖音乐加载对话框 PopScope 拦截系统返回键
//
// 场景：专辑歌曲加载框显示期间按系统返回键——
// 旧实现 showDialog 未 await，用户返回键关闭加载框后，await 完成时
// Navigator.pop(context) 会误 pop 底层音乐页。
// 修复：加载框 builder 包 PopScope(canPop: false)，系统返回键不再能关闭加载框，
// await 完成后的 pop 始终作用在仍在栈上的加载框上。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:embytok_flutter/models/audio_models.dart';
import 'package:embytok_flutter/providers/synology_auth_provider.dart';
import 'package:embytok_flutter/providers/synology_music_provider.dart';
import 'package:embytok_flutter/providers/synology_playback_provider.dart';
import 'package:embytok_flutter/views/synology_music_view.dart';

/// 假认证 Notifier：跳过真实登录，直接置为已登录
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

/// 假音乐库 Notifier：预置专辑数据；loadTab 不触发网络；
/// loadAlbumSongs 挂起在 gate 上，测试期间可精确控制「加载中」窗口
/// （验证系统返回键被 PopScope 拦截的时机）
class _GateMusicNotifier extends SynologyMusicNotifier {
  _GateMusicNotifier(super.ref) : super() {
    state = state.copyWith(
      albums: const [AudioAlbum(name: '测试专辑', artist: '测试歌手')],
    );
  }

  final Completer<void> gate = Completer<void>();

  @override
  Future<void> loadTab(SynologyMusicTab tab, {bool force = false}) async {
    // 不请求网络：albums 已在构造时预置
    if (tab == SynologyMusicTab.albums) {
      state = state.copyWith(
        isLoading: false,
        albums: state.albums,
        hasMoreAlbums: false,
      );
    }
  }

  @override
  Future<List<AudioSong>> loadAlbumSongs(AudioAlbum album) async {
    await gate.future;
    return const [
      AudioSong(
        id: 's1',
        title: '歌曲一',
        tag: AudioSongTag(artist: '测试歌手'),
      ),
    ];
  }
}

/// 假播放 Notifier：不触发播放器
class _FakePlaybackNotifier extends SynologyPlaybackNotifier {
  _FakePlaybackNotifier(super.ref) : super();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('加载框显示期间按系统返回键不关闭，完成后正常关闭并弹歌曲', (tester) async {
    late _GateMusicNotifier music;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        synologyAuthProvider.overrideWith((ref) => _FakeAuthNotifier(ref)),
        synologyMusicProvider.overrideWith((ref) {
          music = _GateMusicNotifier(ref);
          return music;
        }),
        synologyPlaybackProvider
            .overrideWith((ref) => _FakePlaybackNotifier(ref)),
      ],
      child: MaterialApp(
        // M2 涟漪规避 Flutter 3.47.2 shader 已知缺陷（与 service_mode_test 一致）
        theme: ThemeData(splashFactory: InkRipple.splashFactory),
        home: SynologyMusicView(
          showBackButton: true,
          initialTab: SynologyMusicTab.albums,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // 专辑 tab 渲染预置专辑（卡片可能部分在视口外，先滚动到可见）
    expect(find.text('测试专辑'), findsOneWidget);
    await tester.ensureVisible(find.text('测试专辑'));
    await tester.pumpAndSettle();

    // 点击专辑 → 加载框弹出（loadAlbumSongs 挂在 gate 上，保持加载中）
    await tester.tap(find.text('测试专辑'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // 系统返回键：PopScope(canPop:false) 应拦截，加载框仍在栈上
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    // 底层音乐页未被误 pop
    expect(find.byType(SynologyMusicView), findsOneWidget);

    // 放行加载 → 加载框正常关闭，歌曲 sheet 弹出
    music.gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('歌曲一'), findsOneWidget);
  });
}
