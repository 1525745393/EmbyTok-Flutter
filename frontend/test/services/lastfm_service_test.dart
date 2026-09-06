// Last.fm 服务单元测试
//
// 用 MockClient 模拟 ws.audioscrobbler.com 响应，验证：
// - artist.getinfo：解析简介 + 最大尺寸头像
// - 无记录（Last.fm error 字段）返回 null
// - HTML 标签清洗
// - 内存缓存：同歌手二次查询不重复请求
// - album.getinfo：解析专辑封面

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:embytok_flutter/services/lastfm_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const apiKey = 'test-lastfm-key';

  /// 构造 artist.getinfo 成功响应
  http.Response artistOkResponse({String? imageUrl, String? summary}) {
    return http.Response(
      jsonEncode({
        'artist': {
          'name': '周杰伦',
          'image': [
            {'#text': '', 'size': 'small'},
            {'#text': imageUrl ?? '', 'size': 'large'},
            {
              '#text': imageUrl ?? 'https://lastfm.example/artist_300.png',
              'size': 'extralarge'
            },
          ],
          'bio': {
            'summary':
                summary ?? '周杰伦（Jay Chou），台湾华语流行歌手。<a href="x">更多</a>',
            'content': '完整内容',
          },
        },
      }),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }

  group('LastFmService', () {
    test('artist.getinfo 返回简介与最大尺寸头像', () async {
      var requested = 0;
      final client = MockClient((request) async {
        requested++;
        expect(request.url.queryParameters['method'], 'artist.getinfo');
        expect(request.url.queryParameters['api_key'], apiKey);
        expect(request.url.queryParameters['artist'], '周杰伦');
        return artistOkResponse();
      });
      final service = LastFmService(apiKey: apiKey, client: client);

      final info = await service.fetchArtistInfo('周杰伦');

      expect(info, isNotNull);
      expect(info!.bio, contains('周杰伦'));
      // HTML 标签被清除
      expect(info.bio, isNot(contains('<a')));
      // 取最大尺寸图片（extralarge）
      expect(info.imageUrl, 'https://lastfm.example/artist_300.png');
      expect(requested, 1);
    });

    test('Last.fm 无记录（error 字段）返回 null', () async {
      final client = MockClient((request) async => http.Response(
            jsonEncode({'error': 6, 'message': 'The artist you supplied could not be found'}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ));
      final service = LastFmService(apiKey: apiKey, client: client);

      expect(await service.fetchArtistInfo('不存在歌手XYZ'), isNull);
    });

    test('HTTP 非 200 返回 null', () async {
      final client = MockClient((request) async => http.Response('', 500));
      final service = LastFmService(apiKey: apiKey, client: client);

      expect(await service.fetchArtistInfo('X'), isNull);
    });

    test('简介为空（无 bio）返回 null', () async {
      final client = MockClient((request) async => http.Response(
            jsonEncode({'artist': {'name': 'X', 'image': []}}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ));
      final service = LastFmService(apiKey: apiKey, client: client);

      expect(await service.fetchArtistInfo('X'), isNull);
    });

    test('内存缓存：同歌手二次查询不重复请求', () async {
      var requested = 0;
      final client = MockClient((request) async {
        requested++;
        return artistOkResponse(summary: '王菲，中国女歌手。');
      });
      final service = LastFmService(apiKey: apiKey, client: client);

      await service.fetchArtistInfo('王菲');
      await service.fetchArtistInfo('王菲');

      expect(requested, 1, reason: '缓存命中不应重复请求');
    });

    test('album.getinfo 返回专辑封面大图', () async {
      final client = MockClient((request) async {
        expect(request.url.queryParameters['method'], 'album.getinfo');
        return http.Response(
          jsonEncode({
            'album': {
              'name': '叶惠美',
              'image': [
                {'#text': '', 'size': 'small'},
                {
                  '#text': 'https://lastfm.example/album_300.png',
                  'size': 'extralarge'
                },
              ],
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final service = LastFmService(apiKey: apiKey, client: client);

      final cover = await service.fetchAlbumCover(artist: '周杰伦', album: '叶惠美');

      expect(cover, 'https://lastfm.example/album_300.png');
    });

    test('空歌手名直接返回 null 不请求', () async {
      var requested = 0;
      final client = MockClient((request) async {
        requested++;
        return artistOkResponse();
      });
      final service = LastFmService(apiKey: apiKey, client: client);

      expect(await service.fetchArtistInfo('  '), isNull);
      expect(requested, 0);
    });
  });
}
