// 歌手元数据 Provider 单元测试
//
// 覆盖（v2.401.75 修复）：
// - artistSongsProvider：单次 getSongs 上限 200，歌手歌曲超过 200 首时
//   必须按 offset 循环拉全量（旧实现只取一页，详情页列表与「播放全部」截断）
// - artistAlbumsProvider：单次 getAlbums 上限 200，NAS 专辑总数超过单页时
//   必须按 offset 循环拉全量再本地按歌手过滤（旧实现只取 500，靠后的专辑缺失）
// - 未登录：两个 provider 直接返回空列表，不发请求

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:embytok_flutter/models/audio_models.dart';
import 'package:embytok_flutter/providers/artist_metadata_provider.dart';
import 'package:embytok_flutter/providers/auth_provider.dart'
    show secureStorageProvider;
import 'package:embytok_flutter/providers/synology_auth_provider.dart';
import 'package:embytok_flutter/services/synology_audio_api.dart';

import '../mocks/mock_secure_storage.dart';

/// 最小 fake：仅实现认证与分页查询成员，其余走 noSuchMethod 兜底
class _FakeSynologyApi implements SynologyAudioApi {
  _FakeSynologyApi({
    required this.songPages,
    required this.albumPages,
  });

  /// 每个元素代表一页（getSongs 的 limit=200 语义）
  final List<List<AudioSong>> songPages;
  final List<List<AudioAlbum>> albumPages;

  final List<int> songOffsets = [];
  final List<int> albumOffsets = [];

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
  Future<List<AudioAlbum>> getAlbums({
    int offset = 0,
    int limit = 200,
    String? sort,
    String direction = 'asc',
  }) async {
    albumOffsets.add(offset);
    final idx = offset ~/ limit;
    return idx < albumPages.length ? albumPages[idx] : const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

AudioSong _song(int id) => AudioSong(
      id: 'song-$id',
      title: '歌曲 $id',
    );

AudioAlbum _album(int id, {String artist = '周杰伦'}) => AudioAlbum(
      name: '专辑 $id',
      albumArtist: artist,
    );

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

  group('artistSongsProvider 分页', () {
    test('歌曲数 ≤ 单页上限：只发一次请求', () async {
      fakeApi = _FakeSynologyApi(
        songPages: [
          List.generate(150, (i) => _song(i)),
        ],
        albumPages: const [],
      );
      final container = buildContainer();
      addTearDown(container.dispose);
      await login(container);

      final songs = await container.read(artistSongsProvider('周杰伦').future);

      expect(songs, hasLength(150));
      expect(fakeApi.songOffsets, [0], reason: '一页足够不应翻页');
    });

    test('歌曲超过 200 首：按 offset 循环拉全量，不截断', () async {
      fakeApi = _FakeSynologyApi(
        songPages: [
          List.generate(200, (i) => _song(i)),
          List.generate(200, (i) => _song(200 + i)),
          List.generate(37, (i) => _song(400 + i)),
        ],
        albumPages: const [],
      );
      final container = buildContainer();
      addTearDown(container.dispose);
      await login(container);

      final songs = await container.read(artistSongsProvider('周杰伦').future);

      expect(songs, hasLength(437), reason: '200+200+37 全部拉取');
      expect(fakeApi.songOffsets, [0, 200, 400],
          reason: 'offset 应按页递增');
      // 尾页不满 200 即停止，不发多余请求
      expect(fakeApi.songOffsets, hasLength(3));
    });

    test('未登录：直接返回空列表，不发请求', () async {
      fakeApi = _FakeSynologyApi(songPages: [], albumPages: const []);
      final container = buildContainer();
      addTearDown(container.dispose);

      final songs = await container.read(artistSongsProvider('周杰伦').future);

      expect(songs, isEmpty);
      expect(fakeApi.songOffsets, isEmpty);
    });
  });

  group('artistAlbumsProvider 分页', () {
    test('专辑总数超过单页：循环拉全量后按歌手过滤', () async {
      // 3 页：200 + 200 + 120 = 520 张专辑；其中歌手「林俊杰」的专辑
      // 分布在第 3 页末尾（旧实现 limit=500 时会被截断丢失）
      final pages = <List<AudioAlbum>>[
        List.generate(200, (i) => _album(i, artist: '其他歌手')),
        List.generate(200, (i) => _album(200 + i, artist: '其他歌手')),
        [
          ...List.generate(119, (i) => _album(400 + i, artist: '其他歌手')),
          _album(519, artist: '林俊杰'),
        ],
      ];
      fakeApi = _FakeSynologyApi(songPages: const [], albumPages: pages);
      final container = buildContainer();
      addTearDown(container.dispose);
      await login(container);

      final albums = await container.read(artistAlbumsProvider('林俊杰').future);

      expect(albums, hasLength(1), reason: '第 520 张（第 3 页末尾）不应缺失');
      expect(albums.single.name, '专辑 519');
      expect(fakeApi.albumOffsets, [0, 200, 400],
          reason: 'offset 应按页递增到全量');
    });

    test('未登录：直接返回空列表，不发请求', () async {
      fakeApi = _FakeSynologyApi(songPages: const [], albumPages: const []);
      final container = buildContainer();
      addTearDown(container.dispose);

      final albums = await container.read(artistAlbumsProvider('周杰伦').future);

      expect(albums, isEmpty);
      expect(fakeApi.albumOffsets, isEmpty);
    });
  });
}
