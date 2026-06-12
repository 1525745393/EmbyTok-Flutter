import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:embbytok_flutter/services/api_client.dart';
import 'package:embbytok_flutter/services/embbytok_service.dart';
import 'package:embbytok_flutter/models/models.dart';

void main() {
  late Dio dio;
  late DioAdapter dioAdapter;
  late ApiClient apiClient;
  late EmbytokService service;

  const testBackendUrl = 'http://localhost:8000';
  const testEmbyUrl = 'http://emby.example.com';
  const testToken = 'test-access-token';

  setUp(() {
    dio = Dio();
    dioAdapter = DioAdapter(dio: dio);
    apiClient = ApiClient.withDio(dio);
    service = EmbytokService(apiClient: apiClient);
  });

  group('EmbytokService', () {
    group('login', () {
      test('登录成功返回 User 对象', () async {
        final loginResponse = {
          'user_id': 'user-123',
          'username': 'testuser',
          'access_token': 'token-abc',
        };

        dioAdapter.onPost('/api/auth/login', body: {
          'emby_url': testEmbyUrl,
          'username': 'testuser',
          'password': 'password123',
        }).reply(200, loginResponse);

        final user = await service.login(
          testEmbyUrl,
          testBackendUrl,
          'testuser',
          'password123',
        );

        expect(user.id, 'user-123');
        expect(user.name, 'testuser');
        expect(user.accessToken, 'token-abc');
      });

      test('登录失败抛出异常', () async {
        dioAdapter.onPost('/api/auth/login').reply(401, {
          'detail': '用户名或密码错误',
        });

        expect(
          () => service.login(
            testEmbyUrl,
            testBackendUrl,
            'wronguser',
            'wrongpass',
          ),
          throwsA(equals('用户名或密码错误')),
        );
      });
    });

    group('getLibraries', () {
      test('获取媒体库列表成功', () async {
        final librariesResponse = [
          {'id': 'lib-1', 'name': '电影', 'type': 'movies', 'item_count': 100},
          {'id': 'lib-2', 'name': '电视剧', 'type': 'tvshows', 'item_count': 50},
        ];

        dioAdapter.onGet('/api/libraries').reply(200, librariesResponse);

        final libraries = await service.getLibraries(
          serverUrl: testBackendUrl,
          token: testToken,
        );

        expect(libraries.length, 2);
        expect(libraries[0].id, 'lib-1');
        expect(libraries[0].name, '电影');
        expect(libraries[0].type, 'movies');
        expect(libraries[1].id, 'lib-2');
        expect(libraries[1].name, '电视剧');
      });

      test('获取媒体库列表失败', () async {
        dioAdapter.onGet('/api/libraries').reply(500, {
          'detail': '服务器内部错误',
        });

        expect(
          () => service.getLibraries(
            serverUrl: testBackendUrl,
            token: testToken,
          ),
          throwsA(contains('服务器错误')),
        );
      });
    });

    group('getLibraryItems', () {
      test('获取媒体库条目成功', () async {
        final response = {
          'items': [
            {
              'id': 'item-1',
              'title': '测试电影',
              'type': 'Movie',
              'duration_seconds': 7200.0,
            },
          ],
          'total': 1,
          'offset': 0,
          'limit': 20,
        };

        dioAdapter.onGet('/api/libraries/lib-1/items',
            query: {'limit': 20, 'offset': 0}).reply(200, response);

        final result = await service.getLibraryItems(
          'lib-1',
          serverUrl: testBackendUrl,
          token: testToken,
        );

        expect(result.items.length, 1);
        expect(result.total, 1);
        expect(result.items[0].id, 'item-1');
        expect(result.items[0].title, '测试电影');
      });

      test('获取媒体库条目带分页参数', () async {
        final response = {
          'items': [],
          'total': 100,
          'offset': 40,
          'limit': 20,
        };

        dioAdapter.onGet('/api/libraries/lib-1/items',
            query: {'limit': 20, 'offset': 40}).reply(200, response);

        final result = await service.getLibraryItems(
          'lib-1',
          limit: 20,
          offset: 40,
          serverUrl: testBackendUrl,
          token: testToken,
        );

        expect(result.offset, 40);
        expect(result.limit, 20);
        expect(result.total, 100);
      });

      test('获取媒体库条目失败', () async {
        dioAdapter.onGet('/api/libraries/invalid-lib/items').reply(404, {
          'detail': '媒体库不存在',
        });

        expect(
          () => service.getLibraryItems(
            'invalid-lib',
            serverUrl: testBackendUrl,
            token: testToken,
          ),
          throwsA(equals('媒体库不存在')),
        );
      });
    });

    group('getItem', () {
      test('获取单个媒体项成功', () async {
        final response = {
          'id': 'item-123',
          'title': '测试电影',
          'type': 'Movie',
          'duration_seconds': 5400.0,
          'overview': '这是一部测试电影',
          'year': 2024,
        };

        dioAdapter.onGet('/api/items/item-123').reply(200, response);

        final item = await service.getItem(
          'item-123',
          serverUrl: testBackendUrl,
          token: testToken,
        );

        expect(item.id, 'item-123');
        expect(item.title, '测试电影');
        expect(item.type, 'Movie');
        expect(item.durationSeconds, 5400.0);
        expect(item.overview, '这是一部测试电影');
        expect(item.year, 2024);
      });

      test('获取媒体项失败', () async {
        dioAdapter.onGet('/api/items/not-found').reply(404, {
          'detail': '媒体项不存在',
        });

        expect(
          () => service.getItem(
            'not-found',
            serverUrl: testBackendUrl,
            token: testToken,
          ),
          throwsA(equals('媒体项不存在')),
        );
      });
    });

    group('getPlaybackUrl', () {
      test('获取播放 URL 成功', () async {
        dioAdapter.onGet('/api/items/item-123/playback').reply(200, {
          'playback_url': 'http://emby.example.com/video/item-123/stream',
        });

        final url = await service.getPlaybackUrl(
          'item-123',
          serverUrl: testBackendUrl,
          token: testToken,
        );

        expect(url, 'http://emby.example.com/video/item-123/stream');
      });

      test('播放 URL 为空时返回空字符串', () async {
        dioAdapter.onGet('/api/items/item-123/playback').reply(200, {});

        final url = await service.getPlaybackUrl(
          'item-123',
          serverUrl: testBackendUrl,
          token: testToken,
        );

        expect(url, '');
      });

      test('获取播放 URL 失败', () async {
        dioAdapter.onGet('/api/items/item-123/playback').reply(403, {
          'detail': '无播放权限',
        });

        expect(
          () => service.getPlaybackUrl(
            'item-123',
            serverUrl: testBackendUrl,
            token: testToken,
          ),
          throwsA(equals('无播放权限')),
        );
      });
    });

    group('search', () {
      test('搜索成功返回结果', () async {
        final response = {
          'items': [
            {'id': 'item-1', 'title': '测试电影', 'type': 'Movie'},
            {'id': 'item-2', 'title': '测试剧集', 'type': 'Series'},
          ],
          'total': 2,
          'offset': 0,
          'limit': 20,
        };

        dioAdapter.onGet('/api/search',
            query: {'q': '测试', 'limit': 20, 'offset': 0}).reply(200, response);

        final result = await service.search(
          '测试',
          serverUrl: testBackendUrl,
          token: testToken,
        );

        expect(result.items.length, 2);
        expect(result.total, 2);
        expect(result.items[0].title, '测试电影');
        expect(result.items[1].title, '测试剧集');
      });

      test('搜索带分页参数', () async {
        final response = {
          'items': [],
          'total': 50,
          'offset': 20,
          'limit': 10,
        };

        dioAdapter.onGet('/api/search',
            query: {'q': 'test', 'limit': 10, 'offset': 20}).reply(200, response);

        final result = await service.search(
          'test',
          limit: 10,
          offset: 20,
          serverUrl: testBackendUrl,
          token: testToken,
        );

        expect(result.offset, 20);
        expect(result.limit, 10);
        expect(result.total, 50);
      });

      test('搜索失败', () async {
        dioAdapter.onGet('/api/search').reply(400, {
          'detail': '搜索关键词不能为空',
        });

        expect(
          () => service.search(
            '',
            serverUrl: testBackendUrl,
            token: testToken,
          ),
          throwsA(equals('搜索关键词不能为空')),
        );
      });
    });

    group('toggleFavorite', () {
      test('添加收藏调用 POST', () async {
        dioAdapter.onPost('/api/favorites/item-123').reply(200, {});

        await service.toggleFavorite(
          'item-123',
          true,
          serverUrl: testBackendUrl,
          token: testToken,
        );

        // 成功则不抛出异常
      });

      test('移除收藏调用 DELETE', () async {
        dioAdapter.onDelete('/api/favorites/item-123').reply(200, {});

        await service.toggleFavorite(
          'item-123',
          false,
          serverUrl: testBackendUrl,
          token: testToken,
        );

        // 成功则不抛出异常
      });

      test('添加收藏失败', () async {
        dioAdapter.onPost('/api/favorites/item-123').reply(404, {
          'detail': '媒体项不存在',
        });

        expect(
          () => service.toggleFavorite(
            'item-123',
            true,
            serverUrl: testBackendUrl,
            token: testToken,
          ),
          throwsA(equals('媒体项不存在')),
        );
      });

      test('移除收藏失败', () async {
        dioAdapter.onDelete('/api/favorites/item-123').reply(403, {
          'detail': '无权限操作',
        });

        expect(
          () => service.toggleFavorite(
            'item-123',
            false,
            serverUrl: testBackendUrl,
            token: testToken,
          ),
          throwsA(equals('无权限操作')),
        );
      });
    });

    group('getFavorites', () {
      test('获取收藏列表成功', () async {
        final response = [
          {'id': 'item-1', 'title': '收藏电影1', 'type': 'Movie'},
          {'id': 'item-2', 'title': '收藏剧集1', 'type': 'Series'},
        ];

        dioAdapter.onGet('/api/favorites').reply(200, response);

        final favorites = await service.getFavorites(
          serverUrl: testBackendUrl,
          token: testToken,
        );

        expect(favorites.length, 2);
        expect(favorites[0].title, '收藏电影1');
        expect(favorites[1].title, '收藏剧集1');
      });

      test('获取收藏列表失败', () async {
        dioAdapter.onGet('/api/favorites').reply(401, {
          'detail': 'Token 已过期',
        });

        expect(
          () => service.getFavorites(
            serverUrl: testBackendUrl,
            token: testToken,
          ),
          throwsA(equals('Token 已过期')),
        );
      });
    });

    group('saveProgress', () {
      test('保存播放进度成功', () async {
        dioAdapter.onPost('/api/progress/item-123', body: {
          'position_seconds': 3600,
        }).reply(200, {});

        await service.saveProgress(
          'item-123',
          3600,
          serverUrl: testBackendUrl,
          token: testToken,
        );

        // 成功则不抛出异常
      });

      test('保存播放进度失败', () async {
        dioAdapter.onPost('/api/progress/item-123').reply(500, {
          'detail': '数据库写入失败',
        });

        expect(
          () => service.saveProgress(
            'item-123',
            3600,
            serverUrl: testBackendUrl,
            token: testToken,
          ),
          throwsA(contains('服务器错误')),
        );
      });
    });

    group('getProgress', () {
      test('获取播放进度成功', () async {
        dioAdapter.onGet('/api/progress/item-123').reply(200, {
          'position_seconds': 1800,
        });

        final progress = await service.getProgress(
          'item-123',
          serverUrl: testBackendUrl,
          token: testToken,
        );

        expect(progress, 1800);
      });

      test('播放进度不存在返回 null', () async {
        dioAdapter.onGet('/api/progress/item-123').reply(200, {});

        final progress = await service.getProgress(
          'item-123',
          serverUrl: testBackendUrl,
          token: testToken,
        );

        expect(progress, isNull);
      });

      test('获取播放进度失败', () async {
        dioAdapter.onGet('/api/progress/item-123').reply(404, {
          'detail': '媒体项不存在',
        });

        expect(
          () => service.getProgress(
            'item-123',
            serverUrl: testBackendUrl,
            token: testToken,
          ),
          throwsA(equals('媒体项不存在')),
        );
      });
    });
  });
}
