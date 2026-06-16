// EmbytokService 测试：验证 API 调用、数据解析和错误处理

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import 'package:embbytok_flutter/services/api_client.dart';
import 'package:embbytok_flutter/services/embbytok_service.dart';

void main() {
  late Dio dio;
  late DioAdapter dioAdapter;
  late EmbytokService service;

  const testEmbyUrl = 'https://emby.example.com';
  const testToken = 'test-token-123';

  setUp(() {
    dio = Dio();
    dioAdapter = DioAdapter(dio: dio);
    dio.httpClientAdapter = dioAdapter;
    final apiClient = ApiClient.withDio(dio);
    service = EmbytokService(apiClient: apiClient);
  });

  group('登录 API', () {
    test('登录成功返回 User 对象', () async {
      const username = 'testuser';
      const password = 'password123';

      final responseData = <String, dynamic>{
        'Id': 'user-123',
        'Name': username,
        'ServerId': 'server-1',
        'AccessToken': testToken,
      };

      dioAdapter.onPost(
        '/Users/AuthenticateByName',
        (request) => Reply(200, responseData),
        data: <String, dynamic>{'Username': username, 'Pw': password},
      );

      final user = await service.login(
        embyServerUrl: testEmbyUrl,
        username: username,
        password: password,
      );

      expect(user.id, 'user-123');
      expect(user.name, username);
      expect(user.accessToken, testToken);
    });

    test('登录失败抛出异常', () async {
      dioAdapter.onPost(
        '/Users/AuthenticateByName',
        (request) => Reply(401, <String, dynamic>{'message': 'Unauthorized'}),
        data: <String, dynamic>{'Username': 'wronguser', 'Pw': 'wrongpass'},
      );

      await expectLater(
        service.login(
          embyServerUrl: testEmbyUrl,
          username: 'wronguser',
          password: 'wrongpass',
        ),
        throwsA(anything),
      );
    });
  });

  group('媒体库 API', () {
    test('获取媒体库列表', () async {
      final responseData = <String, dynamic>{
        'Items': [
          <String, dynamic>{'Id': 'lib-1', 'Name': '电影', 'CollectionType': 'movies'},
          <String, dynamic>{'Id': 'lib-2', 'Name': '剧集', 'CollectionType': 'tvshows'},
          <String, dynamic>{'Id': 'lib-3', 'Name': '音乐', 'CollectionType': 'music'},
        ],
        'TotalRecordCount': 3,
      };

      dioAdapter.onGet(
        '/Library/VirtualFolders',
        (request) => Reply(200, responseData),
      );

      final libraries = await service.getLibraries(
        serverUrl: testEmbyUrl,
        token: testToken,
      );

      expect(libraries.length, 3);
      expect(libraries[0].id, 'lib-1');
      expect(libraries[0].name, '电影');
      expect(libraries[0].type, 'movies');
    });

    test('获取库中的项目列表（分页）', () async {
      final responseData = <String, dynamic>{
        'Items': List.generate(20, (i) => <String, dynamic>{
              'Id': 'item-$i',
              'Name': 'Item $i',
              'Type': 'Movie',
              'RunTimeTicks': 72000000000,
            }),
        'TotalRecordCount': 50,
        'StartIndex': 0,
        'Limit': 20,
      };

      dioAdapter.onGet(
        '/Items',
        (request) => Reply(200, responseData),
      );

      final response = await service.getLibraryItems(
        'lib-1',
        limit: 20,
        offset: 0,
        serverUrl: testEmbyUrl,
        token: testToken,
      );

      expect(response.items.length, 20);
      expect(response.total, 50);
      expect(response.offset, 0);
      expect(response.limit, 20);
    });

    test('获取继续观看的项目', () async {
      final responseData = <String, dynamic>{
        'Items': [
          <String, dynamic>{'Id': 'resume-1', 'Name': 'Resume 1', 'Type': 'Movie'},
          <String, dynamic>{'Id': 'resume-2', 'Name': 'Resume 2', 'Type': 'Episode'},
        ],
        'TotalRecordCount': 2,
      };

      dioAdapter.onGet(
        '/Items/Resume',
        (request) => Reply(200, responseData),
      );

      final response = await service.getResumeItems(
        limit: 20,
        offset: 0,
        serverUrl: testEmbyUrl,
        token: testToken,
      );

      expect(response.items.length, 2);
    });

    test('获取下一集', () async {
      final responseData = <String, dynamic>{
        'Items': [
          <String, dynamic>{'Id': 'next-1', 'Name': 'Next Episode', 'Type': 'Episode'},
        ],
        'TotalRecordCount': 1,
      };

      dioAdapter.onGet(
        '/Shows/NextUp',
        (request) => Reply(200, responseData),
      );

      final response = await service.getNextUp(
        limit: 20,
        serverUrl: testEmbyUrl,
        token: testToken,
      );

      expect(response.items.length, 1);
    });

    test('获取项目详情', () async {
      const itemId = 'item-42';
      final responseData = <String, dynamic>{
        'Id': itemId,
        'Name': 'Test Movie',
        'Type': 'Movie',
        'Overview': '这是一部测试电影',
        'CommunityRating': 8.5,
        'RunTimeTicks': 72000000000,
        'ProductionYear': 2024,
      };

      dioAdapter.onGet(
        '/Items/$itemId',
        (request) => Reply(200, responseData),
      );

      final item = await service.getItemDetail(
        itemId,
        serverUrl: testEmbyUrl,
        token: testToken,
      );

      expect(item.id, itemId);
      expect(item.title, 'Test Movie');
      expect(item.type, 'Movie');
    });

    test('获取相似项目', () async {
      const itemId = 'item-42';
      final responseData = <dynamic>[
        <String, dynamic>{'Id': 'similar-1', 'Name': 'Similar 1', 'Type': 'Movie'},
        <String, dynamic>{'Id': 'similar-2', 'Name': 'Similar 2', 'Type': 'Movie'},
      ];

      dioAdapter.onGet(
        '/Items/$itemId/Similar',
        (request) => Reply(200, responseData),
      );

      final items = await service.getSimilarItems(
        itemId,
        limit: 20,
        serverUrl: testEmbyUrl,
        token: testToken,
      );

      expect(items.length, 2);
    });
  });

  group('收藏 API', () {
    test('获取收藏列表', () async {
      final responseData = <String, dynamic>{
        'Items': [
          <String, dynamic>{'Id': 'fav-1', 'Name': 'Favorite 1', 'Type': 'Movie'},
          <String, dynamic>{'Id': 'fav-2', 'Name': 'Favorite 2', 'Type': 'Movie'},
        ],
        'TotalRecordCount': 2,
      };

      dioAdapter.onGet(
        '/Items',
        (request) => Reply(200, responseData),
      );

      final items = await service.getFavorites(
        limit: 100,
        offset: 0,
        serverUrl: testEmbyUrl,
        token: testToken,
      );

      expect(items.length, 2);
    });

    test('添加收藏', () async {
      const itemId = 'item-to-favorite';

      dioAdapter.onPost(
        '/UserFavoriteItems/$itemId',
        (request) => Reply(200, <String, dynamic>{'IsFavorite': true}),
      );

      await service.toggleFavorite(
        itemId,
        isFavorite: true,
        serverUrl: testEmbyUrl,
        token: testToken,
      );
    });

    test('取消收藏', () async {
      const itemId = 'item-to-unfavorite';

      dioAdapter.onDelete(
        '/UserFavoriteItems/$itemId',
        (request) => Reply(200, <String, dynamic>{'IsFavorite': false}),
      );

      await service.toggleFavorite(
        itemId,
        isFavorite: false,
        serverUrl: testEmbyUrl,
        token: testToken,
      );
    });
  });

  group('播放 API', () {
    test('报告播放进度', () async {
      const itemId = 'item-1';
      const positionTicks = 123456789;

      dioAdapter.onPost(
        '/Sessions/Playing/Progress',
        (request) => Reply(204, null),
      );

      await service.reportPlaybackPosition(
        itemId: itemId,
        positionTicks: positionTicks,
        serverUrl: testEmbyUrl,
        token: testToken,
      );
    });

    test('报告播放停止', () async {
      const itemId = 'item-1';
      const positionTicks = 123456789;

      dioAdapter.onPost(
        '/Sessions/Playing/Stopped',
        (request) => Reply(204, null),
      );

      await service.reportPlaybackStopped(
        itemId: itemId,
        positionTicks: positionTicks,
        serverUrl: testEmbyUrl,
        token: testToken,
      );
    });
  });

  group('搜索 API', () {
    test('搜索 Hints', () async {
      const query = 'test';
      final responseData = <String, dynamic>{
        'SearchHints': [
          <String, dynamic>{'ItemId': 'hint-1', 'Name': 'Result 1', 'Type': 'Movie'},
          <String, dynamic>{'ItemId': 'hint-2', 'Name': 'Result 2', 'Type': 'Series'},
        ],
      };

      dioAdapter.onGet(
        '/Search/Hints',
        (request) => Reply(200, responseData),
      );

      final hints = await service.searchHints(
        query,
        limit: 20,
        serverUrl: testEmbyUrl,
        token: testToken,
      );

      expect(hints.length, 2);
    });

    test('搜索 Items', () async {
      const query = 'movie';
      final responseData = <String, dynamic>{
        'Items': [
          <String, dynamic>{'Id': 'search-1', 'Name': 'Search Result 1', 'Type': 'Movie'},
          <String, dynamic>{'Id': 'search-2', 'Name': 'Search Result 2', 'Type': 'Movie'},
          <String, dynamic>{'Id': 'search-3', 'Name': 'Search Result 3', 'Type': 'Movie'},
        ],
        'TotalRecordCount': 3,
      };

      dioAdapter.onGet(
        '/Items',
        (request) => Reply(200, responseData),
      );

      final response = await service.searchItems(
        query,
        limit: 30,
        offset: 0,
        serverUrl: testEmbyUrl,
        token: testToken,
      );

      expect(response.items.length, 3);
      expect(response.total, 3);
    });
  });
}
