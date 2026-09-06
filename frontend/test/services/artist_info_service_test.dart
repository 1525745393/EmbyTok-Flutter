// 歌手简介服务单元测试（Wikipedia REST API）
//
// 用 MockClient（package:http/testing.dart）模拟 Wikipedia 响应，验证：
// - 中文条目返回 extract 简介 + 缩略图
// - 无条目（404）/ 非 200 返回 null
// - extract 为空返回 null
// - 内存缓存：同歌手二次查询不重复请求
// - 超长简介截断到 200 字

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:embytok_flutter/services/artist_info_service.dart';

void main() {
  // AppLogger 初始化需要 binding（写日志文件路径）
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ArtistInfoService', () {
    test('中文条目返回简介与缩略图', () async {
      var requested = 0;
      final client = MockClient((request) async {
        requested++;
        expect(request.url.host, 'zh.wikipedia.org');
        return http.Response(
          jsonEncode({
            'title': '周杰伦',
            'extract': '周杰伦（Jay Chou），台湾华语流行歌手、音乐制作人。',
            'thumbnail': {'source': 'https://upload.wikimedia.org/thumb.jpg'},
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final service = ArtistInfoService(client: client);

      final info = await service.fetchArtistInfo('周杰伦');

      expect(info, isNotNull);
      expect(info!.bio, contains('周杰伦'));
      expect(info.thumbnailUrl, 'https://upload.wikimedia.org/thumb.jpg');
      expect(requested, 1);
    });

    test('中文无条目回退英文', () async {
      final client = MockClient((request) async {
        if (request.url.host == 'zh.wikipedia.org') {
          return http.Response('Not found', 404);
        }
        return http.Response(
          jsonEncode({'title': 'Adele', 'extract': 'Adele is a British singer.'}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final service = ArtistInfoService(client: client);

      final info = await service.fetchArtistInfo('Adele');

      expect(info, isNotNull);
      expect(info!.bio, contains('British singer'));
    });

    test('两种语言均无条目返回 null', () async {
      final client = MockClient((request) async => http.Response('', 404));
      final service = ArtistInfoService(client: client);

      final info = await service.fetchArtistInfo('不存在歌手XYZ');

      expect(info, isNull);
    });

    test('extract 为空返回 null', () async {
      final client = MockClient((request) async => http.Response(
            jsonEncode({'title': 'X', 'extract': ''}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ));
      final service = ArtistInfoService(client: client);

      expect(await service.fetchArtistInfo('X'), isNull);
    });

    test('内存缓存：二次查询不重复请求', () async {
      var requested = 0;
      final client = MockClient((request) async {
        requested++;
        return http.Response(
          jsonEncode({'title': '王菲', 'extract': '王菲，中国女歌手。'}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final service = ArtistInfoService(client: client);

      await service.fetchArtistInfo('王菲');
      await service.fetchArtistInfo('王菲');

      expect(requested, 1, reason: '缓存命中不应重复请求');
    });

    test('超长简介截断到 200 字', () async {
      final longBio = '长' * 500;
      final client = MockClient((request) async => http.Response(
            jsonEncode({'title': 'X', 'extract': longBio}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ));
      final service = ArtistInfoService(client: client);

      final info = await service.fetchArtistInfo('X');

      expect(info!.bio.length, lessThanOrEqualTo(201));
      expect(info.bio.endsWith('…'), isTrue);
    });

    test('空歌手名直接返回 null 且不请求', () async {
      var requested = 0;
      final client = MockClient((request) async {
        requested++;
        return http.Response('', 404);
      });
      final service = ArtistInfoService(client: client);

      expect(await service.fetchArtistInfo('  '), isNull);
      expect(requested, 0);
    });
  });
}
