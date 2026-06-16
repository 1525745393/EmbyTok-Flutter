// EmbytokService 测试：验证 Emby 原生 API 调用与响应解析
// 注意：当前 EmbytokService 直接调用 Emby 原生 API（不再经过后端），
// 所以这里测试的方法签名与返回结构必须匹配 embbytok_service.dart

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

  const testEmbyUrl = 'http://emby.example.com';
  const testToken = 'test-access-token';

  setUp(() {
    dio = Dio();
    dioAdapter = DioAdapter(dio: dio);
    dio.httpClientAdapter = dioAdapter;
    apiClient = ApiClient.withDio(dio);
    service = EmbytokService(apiClient: apiClient);
  });

  group('EmbytokService', () {
    // ============================
    // login 方法测试
    // 签名：Future<User> login({
    //   required String embyServerUrl,
    //   required String username,
    //   required String password,
    // })
    // ============================
    group('login', () {
      test('登录成功返回 User 对象（Emby 原生响应字段）', () async {
        // Emby /Users/AuthenticateByName 响应
        final loginResponse = <String, dynamic>{
          'User': <String, dynamic>{
            'Id': 'user-123',
            'Name': 'testuser',
          },
          'AccessToken': 'token-abc-def',
        };

        dioAdapter.onPost(
          '/Users/AuthenticateByName',
          data: <String, dynamic>{
            'Username': 'testuser',
            'Pw': 'password123',
          },
        ).reply(200, loginResponse);

        final user = await service.login(
          embyServerUrl: testEmbyUrl,
          username: 'testuser',
          password: 'password123',
        );

        expect(user.id, 'user-123');
        expect(user.name, 'testuser');
        expect(user.accessToken, 'token-abc-def');
      });

      test('登录失败抛出异常（401）', () async {
        dioAdapter.onPost(
          '/Users/AuthenticateByName',
          data: <String, dynamic>{
            'Username': 'wronguser',
            'Pw': 'wrongpass',
          },
        ).reply(401, <String, dynamic>{'message': 'Unauthorized'});

        await expectLater(
          service.login(
            embyServerUrl: testEmbyUrl,
            username: 'wronguser',
            password: 'wrongpass',
          ),
          throwsA(anything),
        );
      });

      test('登录时设置默认 serverUrl 和 token', () async {
        final loginResponse = <String, dynamic>{
          'User': <String, dynamic>{'Id': 'user-1', 'Name': 'test'},
          'AccessToken': 'new-token',
        };

        dioAdapter.onPost('/Users/AuthenticateByName').reply(200, loginResponse);

        await service.login(
          embyServerUrl: testEmbyUrl,
          username: 'test',
          password: 'pass',
        );

        // 登录成功后，不提供 serverUrl / token 时应使用默认值
        dioAdapter.onGet('/Library/VirtualFolders').reply(200, <dynamic>[]);

        final libraries = await service.getLibraries();
        expect(libraries, isEmpty);
      });
    });

    // ============================
    // getLibraries 方法测试
    // 签名：Future<List<Library>> getLibraries({
    //   String? serverUrl,
    //   String? token,
    // })
    // ============================
    group('getLibraries', () {
      test('获取媒体库列表成功（Emby 原生 PascalCase 字段）', () async {
        final librariesResponse = <dynamic>[
          <String, dynamic>{
            'Id': 'lib-1',
            'Name': '电影',
            'CollectionType': 'movies',
          },
          <String, dynamic>{
            'Id': 'lib-2',
            'Name': '电视剧',
            'CollectionType': 'tvshows',
          },
        ];

        dioAdapter.onGet('/Library/VirtualFolders').reply(200, librariesResponse);

        final libraries = await service.getLibraries(
          serverUrl: testEmbyUrl,
          token: testToken,
        );

        expect(libraries.length, 2);
        expect(libraries[0].id, 'lib-1');
        expect(libraries[0].name, '电影');
        expect(libraries[0].type, 'movies');
        expect(libraries[1].id, 'lib-2');
        expect(libraries[1].name, '电视剧');
      });

      test('空媒体库返回空列表', () async {
        dioAdapter.onGet('/Library/VirtualFolders').reply(200, <dynamic>[]);

        final libraries = await service.getLibraries(
          serverUrl: testEmbyUrl,
          token: testToken,
        );
        expect(libraries, isEmpty);
      });

      test('网络错误抛出异常', () async {
        dioAdapter.onGet('/Library/VirtualFolders').throws_(
          DioException(
            requestOptions: RequestOptions(path: '/Library/VirtualFolders'),
            type: DioExceptionType.connectionError,
          ),
        );

        await expectLater(
          service.getLibraries(serverUrl: testEmbyUrl, token: testToken),
          throwsA(anything),
        );
      });
    });

    // ============================
    // getLibraryItems 方法测试
    // 签名：Future<PaginatedResponse<MediaItem>> getLibraryItems(
    //   String libraryId, {
    //   int limit = 20,
    //   int offset = 0,
    //   String? serverUrl,
    //   String? token,
    // })
    // ============================
    group('getLibraryItems', () {
      test('获取媒体库条目成功（Emby Items 响应）', () async {
        final response = <String, dynamic>{
          'Items': <dynamic>[
            <String, dynamic>{
              'Id': 'item-1',
              'Name': '测试电影',
              'Type': 'Movie',
              'RunTimeTicks': 72000000000,
            },
            <String, dynamic>{
              'Id': 'item-2',
              'Name': '测试剧集',
              'Type': 'Series',
              'ProductionYear': 2024,
            },
          ],
          'TotalRecordCount': 2,
        };

        dioAdapter.onGet(
          '/Items',
          queryParameters: <String, dynamic>{
            'ParentId': 'lib-1',
            'Limit': '20',
            'StartIndex': '0',
            'SortBy': 'DateCreated,SortName',
            'SortOrder': 'Descending',
            'Recursive': 'true',
            'Fields':
                'Overview,Genres,People,CommunityRating,RunTimeTicks,ProductionYear,ImageTags,UserData',
            'IncludeItemTypes': 'Movie,Series,MusicVideo,Episode',
          },
        ).reply(200, response);

        final result = await service.getLibraryItems(
          'lib-1',
          serverUrl: testEmbyUrl,
          token: testToken,
        );

        expect(result.items.length, 2);
        expect(result.total, 2);
        expect(result.items[0].id, 'item-1');
        expect(result.items[0].title, '测试电影');
        expect(result.items[0].type, 'Movie');
      });

      test('分页参数正确传递（limit/offset）', () async {
        final response = <String, dynamic>{
          'Items': <dynamic>[],
          'TotalRecordCount': 100,
        };

        dioAdapter.onGet(
          '/Items',
          queryParameters: <String, dynamic>{
            'ParentId': 'lib-1',
            'Limit': '10',
            'StartIndex': '40',
            'SortBy': 'DateCreated,SortName',
            'SortOrder': 'Descending',
            'Recursive': 'true',
            'Fields':
                'Overview,Genres,People,CommunityRating,RunTimeTicks,ProductionYear,ImageTags,UserData',
            'IncludeItemTypes': 'Movie,Series,MusicVideo,Episode',
          },
        ).reply(200, response);

        final result = await service.getLibraryItems(
          'lib-1',
          limit: 10,
          offset: 40,
          serverUrl: testEmbyUrl,
          token: testToken,
        );

        expect(result.offset, 40);
        expect(result.limit, 10);
        expect(result.total, 100);
        expect(result.items, isEmpty);
      });

      test('空列表返回 PaginatedResponse(items=[], total=0)', () async {
        final response = <String, dynamic>{
          'Items': <dynamic>[],
          'TotalRecordCount': 0,
        };

        dioAdapter.onGet('/Items', queryParameters: any).reply(200, response);

        final result = await service.getLibraryItems(
          'empty-lib',
          serverUrl: testEmbyUrl,
          token: testToken,
        );

        expect(result.items, isEmpty);
        expect(result.total, 0);
      });
    });

    // ============================
    // getFavorites 方法测试
    // 签名：Future<List<MediaItem>> getFavorites({
    //   int limit = 100,
    //   int offset = 0,
    //   String? serverUrl,
    //   String? token,
    // })
    // ============================
    group('getFavorites', () {
      test('获取收藏列表成功（Filters=IsFavorite）', () async {
        final response = <String, dynamic>{
          'Items': <dynamic>[
            <String, dynamic>{
              'Id': 'fav-1',
              'Name': '收藏的电影',
              'Type': 'Movie',
            },
            <String, dynamic>{
              'Id': 'fav-2',
              'Name': '收藏的剧集',
              'Type': 'Series',
            },
          ],
        };

        dioAdapter.onGet(
          '/Items',
          queryParameters: <String, dynamic>{
            'Limit': '100',
            'StartIndex': '0',
            'Recursive': 'true',
            'Filters': 'IsFavorite',
            'Fields':
                'Overview,Genres,CommunityRating,RunTimeTicks,ProductionYear,ImageTags,UserData',
            'SortBy': 'DateCreated',
            'SortOrder': 'Descending',
          },
        ).reply(200, response);

        final favorites = await service.getFavorites(
          serverUrl: testEmbyUrl,
          token: testToken,
        );

        expect(favorites.length, 2);
        expect(favorites[0].id, 'fav-1');
        expect(favorites[0].title, '收藏的电影');
      });

      test('无收藏返回空列表', () async {
        dioAdapter.onGet('/Items', queryParameters: any).reply(
              200,
              <String, dynamic>{'Items': <dynamic>[]},
            );

        final favorites = await service.getFavorites(
          serverUrl: testEmbyUrl,
          token: testToken,
        );
        expect(favorites, isEmpty);
      });
    });

    // ============================
    // toggleFavorite 方法测试
    // 签名：Future<void> toggleFavorite(
    //   String itemId, {
    //   required bool isFavorite,
    //   String? serverUrl,
    //   String? token,
    // })
    // ============================
    group('toggleFavorite', () {
      test('isFavorite=true 发送 POST 请求', () async {
        dioAdapter.onPost('/UserFavoriteItems/item-123').reply(200, <String, dynamic>{});

        await service.toggleFavorite(
          'item-123',
          isFavorite: true,
          serverUrl: testEmbyUrl,
          token: testToken,
        );
        // 成功无异常
      });

      test('isFavorite=false 发送 DELETE 请求', () async {
        dioAdapter.onDelete('/UserFavoriteItems/item-123').reply(200, <String, dynamic>{});

        await service.toggleFavorite(
          'item-123',
          isFavorite: false,
          serverUrl: testEmbyUrl,
          token: testToken,
        );
        // 成功无异常
      });

      test('添加收藏失败时抛出异常', () async {
        dioAdapter.onPost('/UserFavoriteItems/item-x').reply(404, <String, dynamic>{});

        await expectLater(
          service.toggleFavorite(
            'item-x',
            isFavorite: true,
            serverUrl: testEmbyUrl,
            token: testToken,
          ),
          throwsA(anything),
        );
      });
    });

    // ============================
    // getItemDetail 方法测试
    // 签名：Future<MediaItem> getItemDetail(
    //   String itemId, {
    //   String? serverUrl,
    //   String? token,
    // })
    // ============================
    group('getItemDetail', () {
      test('获取单个媒体项详情成功', () async {
        final response = <String, dynamic>{
          'Id': 'item-123',
          'Name': '详细电影',
          'Type': 'Movie',
          'Overview': '这是一部很好的电影',
          'ProductionYear': 2024,
          'CommunityRating': 8.5,
          'RunTimeTicks': 72000000000,
        };

        dioAdapter.onGet('/Items/item-123').reply(200, response);

        final item = await service.getItemDetail(
          'item-123',
          serverUrl: testEmbyUrl,
          token: testToken,
        );

        expect(item.id, 'item-123');
        expect(item.title, '详细电影');
        expect(item.type, 'Movie');
        expect(item.productionYear, 2024);
      });

      test('字段不存在时使用默认值', () async {
        // Emby 响应可能缺少某些字段
        final response = <String, dynamic>{
          'Id': 'minimal-item',
          'Name': '简单项',
          'Type': 'Movie',
        };

        dioAdapter.onGet('/Items/minimal-item').reply(200, response);

        final item = await service.getItemDetail(
          'minimal-item',
          serverUrl: testEmbyUrl,
          token: testToken,
        );

        expect(item.id, 'minimal-item');
        expect(item.title, '简单项');
        expect(item.overview, isNull);
        expect(item.productionYear, isNull);
      });
    });

    // ============================
    // searchHints / searchItems 方法测试
    // ============================
    group('searchItems', () {
      test('搜索成功返回分页结果', () async {
        final response = <String, dynamic>{
          'Items': <dynamic>[
            <String, dynamic>{'Id': 'r1', 'Name': '搜索结果1', 'Type': 'Movie'},
            <String, dynamic>{'Id': 'r2', 'Name': '搜索结果2', 'Type': 'Series'},
          ],
          'TotalRecordCount': 2,
        };

        dioAdapter.onGet(
          '/Items',
          queryParameters: <String, dynamic>{
            'SearchTerm': 'query',
            'Limit': '30',
            'StartIndex': '0',
            'Recursive': 'true',
            'Fields':
                'Overview,Genres,People,CommunityRating,RunTimeTicks,ProductionYear,ImageTags,UserData',
          },
        ).reply(200, response);

        final result = await service.searchItems(
          'query',
          serverUrl: testEmbyUrl,
          token: testToken,
        );

        expect(result.items.length, 2);
        expect(result.total, 2);
      });

      test('空查询返回空分页结果（不发请求）', () async {
        final result = await service.searchItems(
          '',
          serverUrl: testEmbyUrl,
          token: testToken,
        );

        expect(result.items, isEmpty);
        expect(result.total, 0);
      });
    });

    // ============================
    // 报告播放进度测试
    // reportPlaybackPosition / reportPlaybackStopped
    // ============================
    group('reportPlayback', () {
      test('reportPlaybackPosition 发送 POST 请求', () async {
        dioAdapter.onPost(
          '/Sessions/Playing/Progress',
          data: <String, dynamic>{
            'ItemId': 'item-1',
            'PositionTicks': 7200000000,
          },
        ).reply(200, <String, dynamic>{});

        await service.reportPlaybackPosition(
          itemId: 'item-1',
          positionTicks: 7200000000,
          serverUrl: testEmbyUrl,
          token: testToken,
        );
      });

      test('reportPlaybackStopped 发送 POST 请求', () async {
        dioAdapter.onPost(
          '/Sessions/Playing/Stopped',
          data: <String, dynamic>{
            'ItemId': 'item-1',
            'PositionTicks': 36000000000,
          },
        ).reply(200, <String, dynamic>{});

        await service.reportPlaybackStopped(
          itemId: 'item-1',
          positionTicks: 36000000000,
          serverUrl: testEmbyUrl,
          token: testToken,
        );
      });
    });
  });
}
