// 群晖 Audio Station API 客户端单元测试
//
// 使用 http_mock_adapter（0.6.1 回调式 API）模拟 DSM webapi 响应，验证：
// - 登录请求格式（entry.cgi / auth.cgi 回退）
// - sid 会话透传（_sid 参数）
// - 歌曲/专辑/歌单列表解析（含 additional 字段）
// - 流地址构造（整轨 transcode 分支）
// - 封面 URL 构造

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import 'package:embytok_flutter/services/synology_audio_api.dart';

void main() {
  const serverUrl = 'http://192.168.1.100:5000';
  const sid = 'test-sid-123';

  late Dio dio;
  late DioAdapter adapter;
  late SynologyAudioApi api;

  setUp(() {
    dio = Dio(BaseOptions());
    adapter = DioAdapter(dio: dio);
    dio.httpClientAdapter = adapter;
    api = SynologyAudioApi(dio: dio);
  });

  /// 登录 mock 的完整参数（与 login 的 POST body 一致）
  Map<String, dynamic> loginParams({String? otp}) => {
        'api': 'SYNO.API.Auth',
        'version': 6,
        'method': 'login',
        'session': 'audiostation',
        'account': 'user',
        'passwd': 'pass',
        'format': 'sid',
        'enable_device_token': 'yes',
        if (otp != null) 'otp_code': otp,
      };

  /// 登录是 POST form 请求，统一用 onPost + data 匹配
  void mockLogin(
    DioAdapter adapter,
    String path,
    Object Function() body, {
    Map<String, dynamic>? params,
  }) {
    adapter.onPost(
      '$serverUrl$path',
      (server) => server.reply(200, body()),
      data: params ?? loginParams(),
    );
  }

  group('login', () {
    test('登录成功返回 sid 并建立会话', () async {
      mockLogin(adapter, '/webapi/entry.cgi',
          () => {'success': true, 'data': {'sid': sid}});

      final result = await api.login(
        serverUrl: serverUrl,
        account: 'user',
        password: 'pass',
      );

      expect(result, sid);
      expect(api.isLoggedIn, isTrue);
      expect(api.sid, sid);
      expect(api.account, 'user');
    });

    test('登录失败（密码错误 401）抛出异常并携带错误码', () async {
      mockLogin(
        adapter,
        '/webapi/entry.cgi',
        () => {
          'success': false,
          'error': {'code': 401},
        },
      );

      await expectLater(
        api.login(serverUrl: serverUrl, account: 'user', password: 'pass'),
        throwsA(isA<SynologyAuthException>()
            .having((e) => e.errorCode, 'errorCode', 401)),
      );
      expect(api.isLoggedIn, isFalse);
    });

    test('两步验证开启（403）抛 SynologyOtpRequiredException 并携带 token', () async {
      mockLogin(
        adapter,
        '/webapi/entry.cgi',
        () => {
          'success': false,
          'error': {
            'code': 403,
            'errors': {'token': 'otp-token-123', 'types': [
              {'type': 'otp'}
            ]},
          },
        },
      );

      await expectLater(
        api.login(serverUrl: serverUrl, account: 'user', password: 'pass'),
        throwsA(isA<SynologyOtpRequiredException>()
            .having((e) => e.token, 'token', 'otp-token-123')),
      );
      expect(api.isLoggedIn, isFalse);
    });

    test('两步验证携带 otp_code 登录成功并保存 did', () async {
      mockLogin(
        adapter,
        '/webapi/entry.cgi',
        () => {
          'success': true,
          'data': {'sid': sid, 'did': 'device-456'},
        },
        params: loginParams(otp: '123456'),
      );

      final result = await api.login(
        serverUrl: serverUrl,
        account: 'user',
        password: 'pass',
        otpCode: '123456',
      );

      expect(result, sid);
      expect(api.isLoggedIn, isTrue);
    });

    test('两步验证 otp_code 错误（403）仍抛出认证异常', () async {
      mockLogin(
        adapter,
        '/webapi/entry.cgi',
        () => {
          'success': false,
          'error': {'code': 403},
        },
        params: loginParams(otp: '999999'),
      );

      await expectLater(
        api.login(
            serverUrl: serverUrl,
            account: 'user',
            password: 'pass',
            otpCode: '999999'),
        throwsA(isA<SynologyAuthException>()),
      );
    });

    test('entry.cgi 404 时回退 auth.cgi（DSM 6）', () async {
      adapter.onPost(
        '$serverUrl/webapi/entry.cgi',
        (server) => server.reply(404, 'Not Found'),
        data: loginParams(),
      );
      adapter.onPost(
        '$serverUrl/webapi/auth.cgi',
        (server) => server.reply(
          200,
          {'success': true, 'data': {'sid': sid}},
        ),
        data: loginParams(),
      );

      final result = await api.login(
        serverUrl: serverUrl,
        account: 'user',
        password: 'pass',
      );

      expect(result, sid);
    });

    test('服务器地址去除尾部斜杠', () async {
      mockLogin(
        adapter,
        '/webapi/entry.cgi',
        () => {'success': true, 'data': {'sid': sid}},
      );

      await api.login(
        serverUrl: '$serverUrl/',
        account: 'user',
        password: 'pass',
      );
      expect(api.serverUrl, serverUrl);
    });

    test('服务器地址无协议前缀时自动补 http://', () async {
      adapter.onPost(
        'http://192.168.1.100:5000/webapi/entry.cgi',
        (server) => server.reply(
          200,
          {'success': true, 'data': {'sid': sid}},
        ),
        data: loginParams(),
      );

      await api.login(
        serverUrl: '192.168.1.100:5000',
        account: 'user',
        password: 'pass',
      );
      expect(api.serverUrl, 'http://192.168.1.100:5000');
    });

    test('纯 IP 输入（无协议无端口）自动补 http:// 和默认端口 5000', () async {
      adapter.onPost(
        'http://192.168.1.6:5000/webapi/entry.cgi',
        (server) => server.reply(
          200,
          {'success': true, 'data': {'sid': sid}},
        ),
        data: loginParams(),
      );

      await api.login(
        serverUrl: '192.168.1.6',
        account: 'user',
        password: 'pass',
      );
      expect(api.serverUrl, 'http://192.168.1.6:5000');
    });
  });

  group('音乐库', () {
    setUp(() {
      api.restoreSession(serverUrl: serverUrl, sid: sid, account: 'user');
    });

    test('未登录时请求抛出异常', () async {
      final notLoggedIn = SynologyAudioApi(dio: dio);
      await expectLater(
        notLoggedIn.getSongs(),
        throwsA(isA<SynologyAuthException>()),
      );
    });

    test('getSongs 解析歌曲列表（含 additional）', () async {
      adapter.onGet(
        '$serverUrl/webapi/AudioStation/song.cgi',
        (server) => server.reply(
          200,
          {
            'success': true,
            'data': {
              'songs': [
                {
                  'id': 'music_1',
                  'title': '晴天',
                  'path': '/music/晴天.mp3',
                  'type': 'file',
                  'additional': {
                    'song_tag': {
                      'album': '叶惠美',
                      'artist': '周杰伦',
                      'album_artist': '周杰伦',
                      'track': 3,
                      'year': 2003,
                      'genre': '流行',
                    },
                    'song_audio': {
                      'duration': 269,
                      'codec': 'mp3',
                      'bitrate': 320,
                    },
                  },
                },
                {
                  'id': 'music_2',
                  'title': '夜曲',
                  'additional': {
                    'song_tag': {'artist': '周杰伦'},
                    'song_audio': {'duration': 186},
                  },
                },
              ],
            },
          },
        ),
        queryParameters: {
          'api': 'SYNO.AudioStation.Song',
          'version': 3,
          'method': 'list',
          'library': 'all',
          'offset': 0,
          'limit': 200,
          'additional': 'song_tag,song_audio,song_rating',
          '_sid': sid,
        },
      );

      final songs = await api.getSongs();

      expect(songs, hasLength(2));
      expect(songs[0].id, 'music_1');
      expect(songs[0].title, '晴天');
      expect(songs[0].tag?.album, '叶惠美');
      expect(songs[0].tag?.artist, '周杰伦');
      expect(songs[0].audio?.duration, 269);
      expect(songs[0].durationText, '4:29');
      expect(songs[0].artistDisplay, '周杰伦');
      expect(songs[0].isCueTrack, isFalse);
    });

    test('getSongs 解析整轨音轨（id 含 _v_）', () async {
      adapter.onGet(
        '$serverUrl/webapi/AudioStation/song.cgi',
        (server) => server.reply(
          200,
          {
            'success': true,
            'data': {
              'songs': [
                {
                  'id': 'music_v_100_1',
                  'title': '音轨 1',
                  'additional': {'song_audio': {'duration': 100}},
                },
              ],
            },
          },
        ),
        queryParameters: {
          'api': 'SYNO.AudioStation.Song',
          'version': 3,
          'method': 'list',
          'library': 'all',
          'offset': 0,
          'limit': 200,
          'additional': 'song_tag,song_audio,song_rating',
          '_sid': sid,
        },
      );

      final songs = await api.getSongs();
      expect(songs[0].isCueTrack, isTrue);
    });

    test('getAlbums 解析专辑列表', () async {
      adapter.onGet(
        '$serverUrl/webapi/AudioStation/album.cgi',
        (server) => server.reply(
          200,
          {
            'success': true,
            'data': {
              'albums': [
                {
                  'name': '叶惠美',
                  'album_artist': '周杰伦',
                  'display_artist': '周杰伦',
                  'year': 2003,
                },
              ],
            },
          },
        ),
        queryParameters: {
          'api': 'SYNO.AudioStation.Album',
          'version': 3,
          'method': 'list',
          'library': 'all',
          'offset': 0,
          'limit': 200,
          'additional': 'avg_rating',
          '_sid': sid,
        },
      );

      final albums = await api.getAlbums();
      expect(albums, hasLength(1));
      expect(albums[0].name, '叶惠美');
      expect(albums[0].year, 2003);
      expect(albums[0].artistDisplay, '周杰伦');
    });

    test('响应为 JSON 字符串时仍能解析（兼容 DSM 部分节点）', () async {
      adapter.onGet(
        '$serverUrl/webapi/AudioStation/song.cgi',
        (server) => server.reply(
          200,
          '{"success":true,"data":{"songs":[{"id":"music_1","title":"串行","additional":{}}]}}',
        ),
        queryParameters: {
          'api': 'SYNO.AudioStation.Song',
          'version': 3,
          'method': 'list',
          'library': 'all',
          'offset': 0,
          'limit': 200,
          'additional': 'song_tag,song_audio,song_rating',
          '_sid': sid,
        },
      );

      final songs = await api.getSongs();
      expect(songs, hasLength(1));
      expect(songs[0].title, '串行');
    });
  });

  group('流与封面 URL', () {
    setUp(() {
      api.restoreSession(serverUrl: serverUrl, sid: sid, account: 'user');
    });

    test('普通歌曲使用 stream 方法', () {
      final url = api.getStreamUrl('music_1');
      expect(url, contains('/webapi/AudioStation/stream.cgi'));
      expect(url, contains('api=SYNO.AudioStation.Stream'));
      expect(url, contains('method=stream'));
      expect(url, contains('id=music_1'));
      expect(url, contains('_sid=$sid'));
      expect(url, isNot(contains('transcode')));
    });

    test('整轨音轨强制 transcode 并追加 /0.mp3', () {
      final url = api.getStreamUrl('music_v_100_1');
      expect(url, contains('/webapi/AudioStation/stream.cgi/0.mp3'));
      expect(url, contains('method=transcode'));
      expect(url, contains('format=mp3'));
    });

    test('歌曲封面 URL 包含歌曲 ID 与会话', () {
      final url = api.getSongCoverUrl('music_1');
      expect(url, contains('method=getsongcover'));
      expect(url, contains('id=music_1'));
      expect(url, contains('_sid=$sid'));
    });

    test('专辑封面 URL 包含专辑名与艺术家', () {
      final url = api.getAlbumCoverUrl(
        albumName: '叶惠美',
        albumArtistName: '周杰伦',
      );
      expect(url, contains('method=getcover'));
      expect(url, contains(Uri.encodeQueryComponent('叶惠美')));
      expect(url, contains(Uri.encodeQueryComponent('周杰伦')));
    });

    test('未登录时流地址返回 null', () {
      final notLoggedIn = SynologyAudioApi(dio: dio);
      expect(notLoggedIn.getStreamUrl('music_1'), isNull);
      expect(notLoggedIn.getSongCoverUrl('music_1'), isNull);
    });
  });

  group('歌词', () {
    setUp(() {
      api.restoreSession(serverUrl: serverUrl, sid: sid, account: 'user');
    });

    test('getLyrics 返回 LRC 文本', () async {
      adapter.onGet(
        '$serverUrl/webapi/AudioStation/lyrics.cgi',
        (server) => server.reply(
          200,
          {
            'success': true,
            'data': {'lyrics': '[00:01.00]歌词内容'},
          },
        ),
        queryParameters: {
          'api': 'SYNO.AudioStation.Lyrics',
          'method': 'getlyrics',
          'version': 2,
          'id': 'music_1',
          '_sid': sid,
        },
      );

      final lyrics = await api.getLyrics('music_1');
      expect(lyrics, '[00:01.00]歌词内容');
    });

    test('getLyrics 空歌词返回 null', () async {
      adapter.onGet(
        '$serverUrl/webapi/AudioStation/lyrics.cgi',
        (server) => server.reply(
          200,
          {'success': true, 'data': {'lyrics': ''}},
        ),
      );

      expect(await api.getLyrics('music_1'), isNull);
    });

    test('getLyrics 请求失败返回 null（不抛异常）', () async {
      adapter.onGet(
        '$serverUrl/webapi/AudioStation/lyrics.cgi',
        (server) => server.reply(
          200,
          {'success': false, 'error': {'code': 106}},
        ),
      );

      expect(await api.getLyrics('music_1'), isNull);
    });
  });

  group('logout', () {
    test('登出后清除会话', () async {
      api.restoreSession(serverUrl: serverUrl, sid: sid, account: 'user');
      adapter.onGet(
        '$serverUrl/webapi/entry.cgi',
        (server) => server.reply(200, {'success': true}),
        queryParameters: {
          'api': 'SYNO.API.Auth',
          'version': 6,
          'method': 'logout',
          'session': 'audiostation',
          '_sid': sid,
        },
      );

      await api.logout();

      expect(api.isLoggedIn, isFalse);
      expect(api.serverUrl, isNull);
    });

    test('未登录时登出不抛异常', () async {
      await api.logout();
      expect(api.isLoggedIn, isFalse);
    });
  });
}
