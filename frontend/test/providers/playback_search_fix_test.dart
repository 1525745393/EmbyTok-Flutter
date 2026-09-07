// 音乐播放/搜索修复回归测试
//
// 覆盖：
// - P2 修复：isNaturalFinish 区分「自然播完」与「用户暂停在末尾」
//   （暂停在末尾不切歌；播放中自然播完才切歌）
// - P3 修复：search 请求序号，过期响应被丢弃（快速连续搜索不乱序）

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:embytok_flutter/models/audio_models.dart';
import 'package:embytok_flutter/providers/synology_auth_provider.dart';
import 'package:embytok_flutter/providers/synology_music_provider.dart';
import 'package:embytok_flutter/providers/synology_playback_provider.dart';
import 'package:embytok_flutter/services/synology_audio_api.dart';

/// 可控延迟的假认证 Notifier：跳过真实登录，api 换为可控 stub
class _FakeAuthNotifier extends SynologyAuthNotifier {
  _FakeAuthNotifier(super.ref, this.stubApi) : super() {
    state = const SynologyAuthState(
      isLoggedIn: true,
      serverUrl: 'http://192.168.1.6:5000',
      account: 'tester',
      sid: 'mock-sid',
    );
  }

  final _StubApi stubApi;

  @override
  SynologyAudioApi get api => stubApi;
}

/// 可控搜索延迟的假 API：search 挂起直到手动 complete
class _StubApi extends SynologyAudioApi {
  final Map<String, Completer<AudioSearchResult>> _gates = {};

  @override
  Future<AudioSearchResult> search(String keyword) {
    final c = Completer<AudioSearchResult>();
    _gates[keyword] = c;
    return c.future;
  }

  /// 让指定关键词的请求返回结果
  void complete(String keyword, String songTitle) {
    _gates[keyword]!.complete(AudioSearchResult(
      songs: [AudioSong(id: 's_$keyword', title: songTitle)],
    ));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('isNaturalFinish（播完判定）', () {
    const dur = Duration(minutes: 4); // 4:00

    test('播放中自然播完（播放器停止 + 应用层仍在播放）→ 切歌', () {
      expect(
        SynologyPlaybackNotifier.isNaturalFinish(
          controllerPlaying: false,
          statePlaying: true,
          position: dur - const Duration(milliseconds: 100),
          duration: dur,
        ),
        isTrue,
        reason: '到达结尾、播放器停、应用层认为在播放 = 自然播完',
      );
    });

    test('用户暂停在末尾（应用层已暂停）→ 不切歌', () {
      expect(
        SynologyPlaybackNotifier.isNaturalFinish(
          controllerPlaying: false,
          statePlaying: false,
          position: dur - const Duration(milliseconds: 100),
          duration: dur,
        ),
        isFalse,
        reason: '用户 pause() 后 state.isPlaying=false，不应判为播完',
      );
    });

    test('暂停在中间 → 不切歌', () {
      expect(
        SynologyPlaybackNotifier.isNaturalFinish(
          controllerPlaying: false,
          statePlaying: false,
          position: const Duration(minutes: 1),
          duration: dur,
        ),
        isFalse,
      );
    });

    test('仍在播放（未到结尾）→ 不切歌', () {
      expect(
        SynologyPlaybackNotifier.isNaturalFinish(
          controllerPlaying: true,
          statePlaying: true,
          position: const Duration(minutes: 1),
          duration: dur,
        ),
        isFalse,
      );
    });

    test('duration 为 0（未知时长）→ 不切歌', () {
      expect(
        SynologyPlaybackNotifier.isNaturalFinish(
          controllerPlaying: false,
          statePlaying: true,
          position: Duration.zero,
          duration: Duration.zero,
        ),
        isFalse,
      );
      expect(
        SynologyPlaybackNotifier.isNaturalFinish(
          controllerPlaying: false,
          statePlaying: true,
          position: const Duration(seconds: 1),
          duration: Duration.zero,
        ),
        isFalse,
      );
    });
  });

  group('search 请求序号（防乱序覆盖）', () {
    test('先发起的慢响应（过期）不会覆盖新搜索结果', () async {
      final stubApi = _StubApi();
      final container = ProviderContainer(overrides: [
        synologyAuthProvider.overrideWith((ref) => _FakeAuthNotifier(ref, stubApi)),
      ]);
      addTearDown(container.dispose);
      final notifier = container.read(synologyMusicProvider.notifier);

      // A 先发出（挂起），B 后发出（挂起）
      final futureA = notifier.search('周杰');
      final futureB = notifier.search('周杰伦');

      // B 先返回：新关键词结果上屏
      stubApi.complete('周杰伦', '七里香');
      await futureB;
      expect(container.read(synologyMusicProvider).searchKeyword, '周杰伦');
      expect(container.read(synologyMusicProvider).searchResult?.songs.single.title,
          '七里香');

      // A 后返回（过期响应）：必须被丢弃，不能覆盖 B 的结果
      stubApi.complete('周杰', '半岛铁盒');
      await futureA;
      expect(container.read(synologyMusicProvider).searchKeyword, '周杰伦');
      expect(container.read(synologyMusicProvider).searchResult?.songs.single.title,
          '七里香',
          reason: '过期响应应被丢弃，搜索词与结果保持一致');
    });

    test('清空关键词退出搜索态后，过期响应不复活结果', () async {
      final stubApi = _StubApi();
      final container = ProviderContainer(overrides: [
        synologyAuthProvider.overrideWith((ref) => _FakeAuthNotifier(ref, stubApi)),
      ]);
      addTearDown(container.dispose);
      final notifier = container.read(synologyMusicProvider.notifier);

      final futureA = notifier.search('周杰伦');
      // 用户清空搜索框 → 退出搜索态
      await notifier.search('');
      expect(container.read(synologyMusicProvider).isSearching, isFalse);

      // 旧请求才返回 → 应被丢弃，不复活搜索态
      stubApi.complete('周杰伦', '七里香');
      await futureA;
      final state = container.read(synologyMusicProvider);
      expect(state.isSearching, isFalse);
      expect(state.searchKeyword, isEmpty);
      expect(state.searchResult, isNull);
    });
  });
}
