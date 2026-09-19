// 发现数据源三源（类型/标签/合集）Emby API 对接测试
//
// 覆盖（审查修复项）：
// 1. getGenres / getTags / getItemsByGenre / getItemsByTag 请求必须携带
//    IncludeItemTypes=Movie,Series,Episode,Video,MusicVideo（视频发现场景，
//    避免混入音乐/照片条目）
// 2. getCollections 携带 IncludeItemTypes=BoxSet
// 3. getGenres 解析时过滤空 id/name 条目

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import 'package:embytok_flutter/services/api_client.dart';
import 'package:embytok_flutter/services/emby_server_api.dart';

const _kVideoTypes = 'Movie,Series,Episode,Video,MusicVideo';

void main() {
  late Dio dio;
  late DioAdapter dioAdapter;
  late EmbyServerApi api;

  setUp(() {
    dio = Dio();
    dioAdapter = DioAdapter(dio: dio);
    dio.httpClientAdapter = dioAdapter;
    api = EmbyServerApi.withClient(
      ApiClient.withDio(dio, baseUrl: 'http://emby.test'),
    );
    api.setupAuth(
      embyServerUrl: 'http://emby.test',
      apiKey: 'token-1',
      userId: 'user-1',
    );
  });

  void _json(dynamic server, Map<String, dynamic> body) =>
      server.reply(200, body);

  List<String> _types(dynamic v) => (v as String).split(',');

  group('发现三源 Emby API 对接', () {
    test('getGenres：携带视频类型过滤，并过滤空 id/name 条目', () async {
      List<String>? captured;
      dioAdapter.onGet('/Genres', (server) {
        server.replyCallback(200, (options) {
          captured = _types(options.queryParameters['IncludeItemTypes']);
          return {
            'Items': [
              {'Id': 'g1', 'Name': '动作'},
              {'Id': 'g2', 'Name': '科幻'},
              {'Id': '', 'Name': '无ID'},
              {'Name': '无名'},
            ],
            'TotalRecordCount': 4,
          };
        });
      });

      final genres = await api.getGenres(
        serverUrl: 'http://emby.test',
        token: 'token-1',
      );

      expect(captured, _kVideoTypes.split(','));
      // 空 id / 空 name 被过滤
      expect(genres.map((g) => g.id), ['g1', 'g2']);
      expect(genres.map((g) => g.name), ['动作', '科幻']);
    });

    test('getItemsByGenre：携带视频类型过滤', () async {
      List<String>? captured;
      dioAdapter.onGet('/Items', (server) {
        server.replyCallback(200, (options) {
          expect(options.queryParameters['Genres'], '动作');
          captured = _types(options.queryParameters['IncludeItemTypes']);
          return {
            'Items': [
              {'Id': 'm1', 'Name': '动作片', 'Type': 'Movie', 'ProductionYear': 2024},
            ],
            'TotalRecordCount': 1,
          };
        });
      });

      final page = await api.getItemsByGenre(
        '动作',
        serverUrl: 'http://emby.test',
        token: 'token-1',
      );

      expect(captured, _kVideoTypes.split(','));
      expect(page.items.single.id, 'm1');
    });

    test('getTags：携带视频类型过滤（字符串数组响应兼容）', () async {
      List<String>? captured;
      dioAdapter.onGet('/Tags', (server) {
        server.replyCallback(200, (options) {
          captured = _types(options.queryParameters['IncludeItemTypes']);
          // 兼容旧版字符串数组响应
          return {
            'Items': ['4K', '国配', '导演剪辑'],
            'TotalRecordCount': 3,
          };
        });
      });

      final tags = await api.getTags(
        serverUrl: 'http://emby.test',
        token: 'token-1',
      );

      expect(captured, _kVideoTypes.split(','));
      expect(tags.map((t) => t.name), ['4K', '国配', '导演剪辑']);
      expect(tags.every((t) => t.id.isNotEmpty), isTrue);
    });

    test('getTags：对象数组响应（TagItem {Id, Name}）兼容', () async {
      dioAdapter.onGet('/Tags', (server) => _json(server, {
            'Items': [
              {'Id': 't1', 'Name': '4K'},
              {'Id': 't2', 'Name': '国配'},
            ],
            'TotalRecordCount': 2,
          }));

      final tags = await api.getTags(
        serverUrl: 'http://emby.test',
        token: 'token-1',
      );

      expect(tags.map((t) => (t.id, t.name)), [('t1', '4K'), ('t2', '国配')]);
    });

    test('getItemsByTag：携带视频类型过滤与 Tags 参数', () async {
      List<String>? captured;
      dioAdapter.onGet('/Items', (server) {
        server.replyCallback(200, (options) {
          expect(options.queryParameters['Tags'], '4K');
          captured = _types(options.queryParameters['IncludeItemTypes']);
          return {
            'Items': [
              {'Id': 'm2', 'Name': '4K 大片', 'Type': 'Movie', 'ProductionYear': 2024},
            ],
            'TotalRecordCount': 1,
          };
        });
      });

      final page = await api.getItemsByTag(
        '4K',
        serverUrl: 'http://emby.test',
        token: 'token-1',
      );

      expect(captured, _kVideoTypes.split(','));
      expect(page.items.single.id, 'm2');
    });

    test('getCollections：携带 IncludeItemTypes=BoxSet 与 ChildCount', () async {
      List<String>? captured;
      dioAdapter.onGet('/Items', (server) {
        server.replyCallback(200, (options) {
          captured = _types(options.queryParameters['IncludeItemTypes']);
          return {
            'Items': [
              {'Id': 'c1', 'Name': '漫威系列', 'ChildCount': 30},
            ],
            'TotalRecordCount': 1,
          };
        });
      });

      final collections = await api.getCollections(
        serverUrl: 'http://emby.test',
        token: 'token-1',
      );

      expect(captured, ['BoxSet']);
      expect(collections.single.name, '漫威系列');
      expect(collections.single.itemCount, 30);
    });
  });
}
