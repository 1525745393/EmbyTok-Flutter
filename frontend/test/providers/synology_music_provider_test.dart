// 群晖音乐库 Provider 单元测试
//
// 覆盖（v2.401.76 修复）：
// - loadAlbumSongs：getSongs 按专辑过滤默认单页 200，大专辑（>200 首）必须
//   按 offset 循环拉全量（旧实现只取一页，专辑弹层列表与「播放全部」截断，
//   与已修 artistSongsProvider 同族）
// - loadTab(playlists)：歌单列表无触底加载，必须一次循环拉全量
//   （旧实现只取单页 200，歌单超过 200 个时静默截断）
// - 未登录：直接返回空，不发请求
// - loadTab(songs) 单页 200 分页语义回归（不误伤触底加载）

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:embytok_flutter/models/audio_models.dart';
import 'package:embytok_flutter/providers/auth_provider.dart'
    show secureStorageProvider;
import 'package:embytok_flutter/providers/synology_auth_provider.dart';
import 'package:embytok_flutter/providers/synology_music_provider.dart';
import 'package:embytok_flutter/services/synology_audio_api.dart';

import '../mocks/mock_secure_storage.dart';

/// 最小 fake：仅实现认证与分页查询成员，其余走 noSuchMethod 兜底
class _FakeSynologyApi implements SynologyAudioApi {
  _FakeSynologyApi({required this.songPages, required this.playlistPages});

  /// 每个元素代表一页（limit=200 语义）
  final List<List<AudioSong>> songPages;
  final List<List<AudioPlaylist>> playlistPages;

  final List<int> songOffsets = [];
  final List<int> playlistOffsets = [];

  @override
  String? serverUrl;
  @override
  String? sid;
  @override
  String? account;

  @override
  bool get isLoggedIn => sid != null && sid!.isNotEmpty;

  @override
  void restoreSession({
    required String serverUrl,
    required String sid,
    String? account,
  }) {
    this.serverUrl = serverUrl;
    this.sid = sid;
    this.account = account;
  }

  @override
  Future<List<AudioSong>> getSongs({
    String? album,
    String? artist,
    String? genre,
    int offset = 0,
    int limit = 200,
  }) async {
    songOffsets.add(offset);
    final idx = offset ~/ limit;
    return idx < songPages.length ? songPages[idx] : const [];
  }

  @override
  Future<List<AudioPlaylist>> getPlaylists({
    int offset = 0,
    int limit = 200,
    String? type,
  }) async {
    playlistOffsets.add(offset);
    final idx = offset ~/ limit;
    return idx < playlistPages.length ? playlistPages[idx] : const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

AudioSong _song(int id) => AudioSong(id: 'song-$id', title: '歌曲 $id');

AudioAlbum _album(int id) => AudioAlbum(name: '专辑 $id', albumArtist: '周杰伦');

AudioPlaylist _playlist(int id) =>
    AudioPlaylist(id: 'playlist_personal_normal/$id', name: '歌单 $id');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockFlutterSecureStorage mockStorage;
  late _FakeSynologyApi fakeApi;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockStorage = MockFlutterSecureStorage();
  });

  ProviderContainer buildContainer() {
    return ProviderContainer(overrides: [
      secureStorageProvider.overrideWithValue(mockStorage),
      synologyAudioApiProvider.overrideWithValue(fakeApi),
    ]);
  }

  /// 通过真实认证链路恢复会话（走 restoreSession，不触发网络）
  Future<void> login(ProviderContainer container) async {
    await container.read(synologyAuthProvider.notifier).restoreSession(
          serverUrl: 'http://192.168.1.100:5000',
          account: 'music',
          sid: 'sid-paged',
        );
    expect(container.read(synologyAuthProvider).isLoggedIn, isTrue);
  }

  group('loadAlbumSongs 分页', () {
    test('专辑歌曲 ≤ 单页上限：只发一次请求', () async {
      fakeApi = _FakeSynologyApi(
        songPages: [List.generate(150, (i) => _song(i))],
        playlistPages: const [],
      );
      final container = buildContainer();
      addTearDown(container.dispose);
      await login(container);

      final songs = await container
          .read(synologyMusicProvider.notifier)
          .loadAlbumSongs(_album(1));

      expect(songs, hasLength(150));
      expect(fakeApi.songOffsets, [0], reason: '一页足够不应翻页');
    });

    test('专辑歌曲超过 200 首：按 offset 循环拉全量，不截断', () async {
      fakeApi = _FakeSynologyApi(
        songPages: [
          List.generate(200, (i) => _song(i)),
          List.generate(200, (i) => _song(200 + i)),
          List.generate(37, (i) => _song(400 + i)),
        ],
        playlistPages: const [],
      );
      final container = buildContainer();
      addTearDown(container.dispose);
      await login(container);

      final songs = await container
          .read(synologyMusicProvider.notifier)
          .loadAlbumSongs(_album(1));

      expect(songs, hasLength(437), reason: '200+200+37 全部拉取');
      expect(fakeApi.songOffsets, [0, 200, 400],
          reason: 'offset 应按页递增');
      expect(fakeApi.songOffsets, hasLength(3),
          reason: '尾页不满 200 即停止，不发多余请求');
    });

    test('未登录：直接返回空列表，不发请求', () async {
      fakeApi = _FakeSynologyApi(songPages: const [], playlistPages: const []);
      final container = buildContainer();
      addTearDown(container.dispose);

      final songs = await container
          .read(synologyMusicProvider.notifier)
          .loadAlbumSongs(_album(1));

      expect(songs, isEmpty);
      expect(fakeApi.songOffsets, isEmpty);
    });
  });

  group('loadTab(playlists) 拉全量', () {
    test('歌单超过单页 200：一次循环拉全量，不截断', () async {
      fakeApi = _FakeSynologyApi(
        songPages: const [],
        playlistPages: [
          List.generate(200, (i) => _playlist(i)),
          List.generate(200, (i) => _playlist(200 + i)),
          List.generate(30, (i) => _playlist(400 + i)),
        ],
      );
      final container = buildContainer();
      addTearDown(container.dispose);
      await login(container);

      await container
          .read(synologyMusicProvider.notifier)
          .loadTab(SynologyMusicTab.playlists);

      final state = container.read(synologyMusicProvider);
      expect(state.playlists, hasLength(430), reason: '200+200+30 全部拉取');
      expect(fakeApi.playlistOffsets, [0, 200, 400],
          reason: 'offset 应按页递增');
      expect(fakeApi.playlistOffsets, hasLength(3),
          reason: '尾页不满 200 即停止');
    });

    test('歌单 ≤ 单页：只发一次请求', () async {
      fakeApi = _FakeSynologyApi(
        songPages: const [],
        playlistPages: [List.generate(120, (i) => _playlist(i))],
      );
      final container = buildContainer();
      addTearDown(container.dispose);
      await login(container);

      await container
          .read(synologyMusicProvider.notifier)
          .loadTab(SynologyMusicTab.playlists);

      expect(container.read(synologyMusicProvider).playlists, hasLength(120));
      expect(fakeApi.playlistOffsets, [0], reason: '一页足够不应翻页');
    });

    test('未登录：直接返回空列表，不发请求', () async {
      fakeApi =
          _FakeSynologyApi(songPages: const [], playlistPages: const []);
      final container = buildContainer();
      addTearDown(container.dispose);

      await container
          .read(synologyMusicProvider.notifier)
          .loadTab(SynologyMusicTab.playlists);

      expect(container.read(synologyMusicProvider).playlists, isEmpty);
      expect(fakeApi.playlistOffsets, isEmpty);
    });
  });

  group('loadTab(songs) 分页语义回归', () {
    test('单页 200：hasMoreSongs 为 true，不多发请求', () async {
      fakeApi = _FakeSynologyApi(
        songPages: [List.generate(200, (i) => _song(i))],
        playlistPages: const [],
      );
      final container = buildContainer();
      addTearDown(container.dispose);
      await login(container);

      await container
          .read(synologyMusicProvider.notifier)
          .loadTab(SynologyMusicTab.songs);

      final state = container.read(synologyMusicProvider);
      expect(state.songs, hasLength(200));
      expect(state.hasMoreSongs, isTrue, reason: '满页应允许触底加载更多');
      expect(fakeApi.songOffsets, [0], reason: '首屏只应请求一次');
    });
  });
}
