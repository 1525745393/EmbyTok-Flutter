import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:embbytok_flutter/models/models.dart';
import 'package:embbytok_flutter/services/api_client.dart';
import 'package:embbytok_flutter/services/embbytok_service.dart';

void main() {
  late Dio dio;
  late DioAdapter dioAdapter;
  late ApiClient apiClient;
  late EmbytokService service;

  const testEmbyUrl = 'http://emby.example.com';
  const testToken = 'test-access-token';
  const testUserId = 'user-abc-123';
  const testItemId = 'item-123';
  const testLibraryId = 'lib-1';

  const itemDetailFields =
      'Overview,Genres,People,CommunityRating,CriticRating,OfficialRating,'
      'RunTimeTicks,ProductionYear,PremiereDate,DateCreated,Studios,'
      'MediaSources,UserData,ParentIndexNumber,IndexNumber,SeriesName,'
      'SeasonName,SeriesId,SeasonId,ImageTags,BackdropImageTags';

  setUp(() {
    dio = Dio();
    dioAdapter = DioAdapter(dio: dio);
    dio.httpClientAdapter = dioAdapter;
    apiClient = ApiClient.withDio(dio);
    service = EmbytokService(apiClient: apiClient);
  });

  // 构造 Emby 原生 PascalCase 的单个媒体项响应
  Map<String, dynamic> buildMediaItemJson({
    required String id,
    required String name,
    required String type,
    int? runTimeTicks,
    int? productionYear,
    String? overview,
    Map<String, dynamic>? userData,
  }) {
    return <String, dynamic>{
      'Id': id,
      'Name': name,
      'Type': type,
      if (runTimeTicks != null) 'RunTimeTicks': runTimeTicks,
      if (productionYear != null) 'ProductionYear': productionYear,
      if (overview != null) 'Overview': overview,
      if (userData != null) 'UserData': userData,
    };
  }

  // 构造 getLibraryItems 期望的查询参数
  Map<String, dynamic> buildLibraryItemsQuery({
    required String libraryId,
    int limit = 20,
    int offset = 0,
  }) {
    return <String, dynamic>{
      'ParentId': libraryId,
      'Limit': '$limit',
      'StartIndex': '$offset',
      'SortBy': 'DateCreated,SortName',
      'SortOrder': 'Descending',
      'Recursive': 'true',
      'Fields':
          'Overview,Genres,People,CommunityRating,RunTimeTicks,ProductionYear,ImageTags,UserData,MediaSources,Path',
      'IncludeItemTypes': 'Movie,Episode,Video,MusicVideo,Series',
    };
  }

  // 构造 getFavorites 期望的查询参数
  Map<String, dynamic> buildFavoritesQuery({
    int limit = 100,
    int offset = 0,
  }) {
    return <String, dynamic>{
      'Limit': '$limit',
      'StartIndex': '$offset',
      'Recursive': 'true',
      'Filters': 'IsFavorite',
      'Fields':
          'Overview,Genres,CommunityRating,RunTimeTicks,ProductionYear,ImageTags,UserData',
      'SortBy': 'DateCreated',
      'SortOrder': 'Descending',
    };
  }

  // 构造 searchItems 期望的查询参数
  Map<String, dynamic> buildSearchItemsQuery({
    required String query,
    int limit = 30,
    int offset = 0,
    List<String>? includeTypes,
  }) {
    final params = <String, dynamic>{
      'SearchTerm': query,
      'Limit': '$limit',
      'StartIndex': '$offset',
      'Recursive': 'true',
      'Fields':
          'Overview,Genres,People,CommunityRating,RunTimeTicks,ProductionYear,ImageTags,UserData',
    };
    if (includeTypes != null && includeTypes.isNotEmpty) {
      params['IncludeItemTypes'] = includeTypes.join(',');
    }
    return params;
  }

  // 构造 searchHints 期望的查询参数
  Map<String, dynamic> buildSearchHintsQuery({
    required String query,
    int limit = 20,
  }) {
    return <String, dynamic>{
      'SearchTerm': query,
      'Limit': '$limit',
      'Recursive': 'true',
    };
  }

  group('EmbytokService', () {
    group('login', () {
      test('登录成功返回 User 对象并保存默认认证信息', () async {
        final loginResponse = <String, dynamic>{
          'User': <String, dynamic>{
            'Id': 'user-123',
            'Name': 'testuser',
          },
          'AccessToken': 'token-abc',
        };

        dioAdapter
            .onPost(
              '/Users/AuthenticateByName',
              body: <String, dynamic>{
                'Username': 'testuser',
                'Pw': 'password123',
              },
            )
            .reply(200, loginResponse);

        final user = await service.login(
          embyServerUrl: testEmbyUrl,
          username: 'testuser',
          password: 'password123',
        );

        expect(user.id, 'user-123');
        expect(user.name, 'testuser');
        expect(user.accessToken, 'token-abc');
      });

      test('登录失败抛出异常', () async {
        dioAdapter.onPost('/Users/AuthenticateByName').reply(401, {
          'detail': '用户名或密码错误',
        });

        expect(
          () => service.login(
            embyServerUrl: testEmbyUrl,
            username: 'wronguser',
            password: 'wrongpass',
          ),
          throwsA(equals('用户名或密码错误')),
        );
      });
    });

    group('getLibraries', () {
      test('传入 userId 时使用 /Users/{userId}/Views 并解析 Items', () async {
        final librariesResponse = <String, dynamic>{
          'Items': [
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
          ],
        };

        dioAdapter
            .onGet(
              '/Users/$testUserId/Views',
              query: <String, dynamic>{},
            )
            .reply(200, librariesResponse);

        final libraries = await service.getLibraries(
          userId: testUserId,
          serverUrl: testEmbyUrl,
          token: testToken,
        );

        expect(libraries.length, 2);
        expect(libraries[0].id, 'lib-1');
        expect(libraries[0].name, '电影');
        expect(libraries[0].type, 'movies');
        expect(libraries[1].id, 'lib-2');
        expect(libraries[1].type, 'tvshows');
      });

      test('无 userId 时降级到 /Library/VirtualFolders 并解析数组', () async {
        final librariesResponse = [
          <String, dynamic>{
            'Id': 'lib-3',
            'Name': '音乐',
            'CollectionType': 'music',
          },
        ];

        dioAdapter
            .onGet(
              '/Library/VirtualFolders',
              query: <String, dynamic>{},
            )
            .reply(200, librariesResponse);

        final libraries = await service.getLibraries(
          serverUrl: testEmbyUrl,
          token: testToken,
        );

        expect(libraries.length, 1);
        expect(libraries[0].id, 'lib-3');
        expect(libraries[0].type, 'music');
      });

      test('获取媒体库列表失败', () async {
        dioAdapter.onGet('/Library/VirtualFolders').reply(500, {
          'detail': '服务器内部错误',
        });

        expect(
          () => service.getLibraries(
            serverUrl: testEmbyUrl,
            token: testToken,
          ),
          throwsA(contains('服务器错误')),
        );
      });
    });

    group('getLibraryItems', () {
      test('传入 userId 时请求用户视图路径并解析分页结果', () async {
        final response = <String, dynamic>{
          'Items': [
            buildMediaItemJson(
              id: 'item-1',
              name: '测试电影',
              type: 'Movie',
              runTimeTicks: 72000000000,
            ),
          ],
          'TotalRecordCount': 1,
        };

        dioAdapter
            .onGet(
              '/Users/$testUserId/Items',
              query: buildLibraryItemsQuery(libraryId: testLibraryId),
            )
            .reply(200, response);

        final result = await service.getLibraryItems(
          testLibraryId,
          userId: testUserId,
          serverUrl: testEmbyUrl,
          token: testToken,
        );

        expect(result.items.length, 1);
        expect(result.total, 1);
        expect(result.items[0].id, 'item-1');
        expect(result.items[0].title, '测试电影');
        expect(result.items[0].type, 'Movie');
      });

      test('无 userId 时降级到 /Items 路径', () async {
        dioAdapter
            .onGet(
              '/Items',
              query: buildLibraryItemsQuery(libraryId: testLibraryId),
            )
            .reply(200, <String, dynamic>{
              'Items': [],
              'TotalRecordCount': 0,
            });

        final result = await service.getLibraryItems(
          testLibraryId,
          serverUrl: testEmbyUrl,
          token: testToken,
        );

        expect(result.items, isEmpty);
        expect(result.total, 0);
      });

      test('分页参数正确传递', () async {
        dioAdapter
            .onGet(
              '/Users/$testUserId/Items',
              query: buildLibraryItemsQuery(
                libraryId: testLibraryId,
                limit: 10,
                offset: 20,
              ),
            )
            .reply(200, <String, dynamic>{
              'Items': [],
              'TotalRecordCount': 100,
            });

        final result = await service.getLibraryItems(
          testLibraryId,
          userId: testUserId,
          limit: 10,
          offset: 20,
          serverUrl: testEmbyUrl,
          token: testToken,
        );

        expect(result.offset, 20);
        expect(result.limit, 10);
        expect(result.total, 100);
      });

      test('获取媒体库条目失败', () async {
        dioAdapter.onGet('/Items').reply(404, {
          'detail': '媒体库不存在',
        });

        expect(
          () => service.getLibraryItems(
            'invalid-lib',
            serverUrl: testEmbyUrl,
            token: testToken,
          ),
          throwsA(equals('媒体库不存在')),
        );
      });
    });

    group('getItemDetail', () {
      test('传入 userId 时请求 /Users/{userId}/Items/{id}', () async {
        final response = buildMediaItemJson(
          id: testItemId,
          name: '测试电影',
          type: 'Movie',
          runTimeTicks: 54000000000,
          productionYear: 2024,
          overview: '这是一部测试电影',
        );

        dioAdapter
            .onGet(
              '/Users/$testUserId/Items/$testItemId',
              query: <String, dynamic>{'Fields': itemDetailFields},
            )
            .reply(200, response);

        final item = await service.getItemDetail(
          testItemId,
          userId: testUserId,
          serverUrl: testEmbyUrl,
          token: testToken,
        );

        expect(item.id, testItemId);
        expect(item.title, '测试电影');
        expect(item.type, 'Movie');
        expect(item.durationSeconds, closeTo(5400.0, 0.01));
        expect(item.overview, '这是一部测试电影');
        expect(item.year, 2024);
      });

      test('无 userId 时降级到 /Items/{id}', () async {
        dioAdapter
            .onGet(
              '/Items/$testItemId',
              query: <String, dynamic>{'Fields': itemDetailFields},
            )
            .reply(200, buildMediaItemJson(
              id: testItemId,
              name: '测试电影',
              type: 'Movie',
            ));

        final item = await service.getItemDetail(
          testItemId,
          serverUrl: testEmbyUrl,
          token: testToken,
        );

        expect(item.id, testItemId);
      });

      test('获取媒体项失败', () async {
        dioAdapter
            .onGet(
              '/Items/not-found',
              query: <String, dynamic>{'Fields': itemDetailFields},
            )
            .reply(404, {
              'detail': '媒体项不存在',
            });

        expect(
          () => service.getItemDetail(
            'not-found',
            serverUrl: testEmbyUrl,
            token: testToken,
          ),
          throwsA(equals('媒体项不存在')),
        );
      });
    });

    group('searchItems', () {
      test('搜索成功返回分页结果', () async {
        final response = <String, dynamic>{
          'Items': [
            buildMediaItemJson(
              id: 'item-1',
              name: '测试电影',
              type: 'Movie',
            ),
            buildMediaItemJson(
              id: 'item-2',
              name: '测试剧集',
              type: 'Series',
            ),
          ],
          'TotalRecordCount': 2,
        };

        dioAdapter
            .onGet(
              '/Users/$testUserId/Items',
              query: buildSearchItemsQuery(query: '测试'),
            )
            .reply(200, response);

        final result = await service.searchItems(
          '测试',
          userId: testUserId,
          serverUrl: testEmbyUrl,
          token: testToken,
        );

        expect(result.items.length, 2);
        expect(result.total, 2);
        expect(result.items[0].title, '测试电影');
        expect(result.items[1].title, '测试剧集');
      });

      test('带 IncludeItemTypes 参数', () async {
        dioAdapter
            .onGet(
              '/Users/$testUserId/Items',
              query: buildSearchItemsQuery(
                query: 'test',
                includeTypes: <String>['Movie', 'Series'],
              ),
            )
            .reply(200, <String, dynamic>{
              'Items': [],
              'TotalRecordCount': 0,
            });

        final result = await service.searchItems(
          'test',
          userId: testUserId,
          includeTypes: <String>['Movie', 'Series'],
          serverUrl: testEmbyUrl,
          token: testToken,
        );

        expect(result.items, isEmpty);
      });

      test('空关键词直接返回空结果，不发起网络请求', () async {
        final result = await service.searchItems(
          '',
          userId: testUserId,
          serverUrl: testEmbyUrl,
          token: testToken,
        );

        expect(result.items, isEmpty);
        expect(result.total, 0);
      });

      test('搜索失败', () async {
        dioAdapter.onGet('/Users/$testUserId/Items').reply(400, {
          'detail': '搜索关键词不能为空',
        });

        expect(
          () => service.searchItems(
            'error',
            userId: testUserId,
            serverUrl: testEmbyUrl,
            token: testToken,
          ),
          throwsA(equals('搜索关键词不能为空')),
        );
      });
    });

    group('searchHints', () {
      test('搜索提示成功返回列表', () async {
        final response = <String, dynamic>{
          'SearchHints': [
            <String, dynamic>{
              'Id': 'hint-1',
              'Name': '提示电影',
              'Type': 'Movie',
              'ProductionYear': 2023,
            },
          ],
        };

        dioAdapter
            .onGet(
              '/Search/Hints',
              query: buildSearchHintsQuery(query: '提示'),
            )
            .reply(200, response);

        final hints = await service.searchHints(
          '提示',
          serverUrl: testEmbyUrl,
          token: testToken,
        );

        expect(hints.length, 1);
        expect(hints[0].id, 'hint-1');
        expect(hints[0].name, '提示电影');
        expect(hints[0].type, 'Movie');
        expect(hints[0].year, 2023);
      });

      test('空关键词直接返回空列表', () async {
        final hints = await service.searchHints(
          '',
          serverUrl: testEmbyUrl,
          token: testToken,
        );

        expect(hints, isEmpty);
      });

      test('搜索提示失败', () async {
        dioAdapter.onGet('/Search/Hints').reply(500, {
          'detail': '服务器内部错误',
        });

        expect(
          () => service.searchHints(
            'error',
            serverUrl: testEmbyUrl,
            token: testToken,
          ),
          throwsA(contains('服务器错误')),
        );
      });
    });

    group('toggleFavorite', () {
      test('传入 userId 时添加收藏调用 POST', () async {
        dioAdapter
            .onPost('/Users/$testUserId/FavoriteItems/$testItemId')
            .reply(200, {});

        await service.toggleFavorite(
          itemId: testItemId,
          isFavorite: true,
          userId: testUserId,
          serverUrl: testEmbyUrl,
          token: testToken,
        );
      });

      test('传入 userId 时移除收藏调用 DELETE', () async {
        dioAdapter
            .onDelete('/Users/$testUserId/FavoriteItems/$testItemId')
            .reply(200, {});

        await service.toggleFavorite(
          itemId: testItemId,
          isFavorite: false,
          userId: testUserId,
          serverUrl: testEmbyUrl,
          token: testToken,
        );
      });

      test('无 userId 时回退到 /UserFavoriteItems/{id}', () async {
        dioAdapter
            .onPost('/UserFavoriteItems/$testItemId')
            .reply(200, {});

        await service.toggleFavorite(
          itemId: testItemId,
          isFavorite: true,
          serverUrl: testEmbyUrl,
          token: testToken,
        );
      });

      test('添加收藏失败', () async {
        dioAdapter
            .onPost('/Users/$testUserId/FavoriteItems/$testItemId')
            .reply(404, {
              'detail': '媒体项不存在',
            });

        expect(
          () => service.toggleFavorite(
            itemId: testItemId,
            isFavorite: true,
            userId: testUserId,
            serverUrl: testEmbyUrl,
            token: testToken,
          ),
          throwsA(equals('媒体项不存在')),
        );
      });
    });

    group('getFavorites', () {
      test('获取收藏列表成功', () async {
        final response = <String, dynamic>{
          'Items': [
            buildMediaItemJson(
              id: 'item-1',
              name: '收藏电影1',
              type: 'Movie',
            ),
            buildMediaItemJson(
              id: 'item-2',
              name: '收藏剧集1',
              type: 'Series',
            ),
          ],
        };

        dioAdapter
            .onGet(
              '/Items',
              query: buildFavoritesQuery(),
            )
            .reply(200, response);

        final favorites = await service.getFavorites(
          serverUrl: testEmbyUrl,
          token: testToken,
        );

        expect(favorites.length, 2);
        expect(favorites[0].title, '收藏电影1');
        expect(favorites[1].title, '收藏剧集1');
      });

      test('获取收藏列表失败', () async {
        dioAdapter.onGet('/Items').reply(401, {
          'detail': 'Token 已过期',
        });

        expect(
          () => service.getFavorites(
            serverUrl: testEmbyUrl,
            token: testToken,
          ),
          throwsA(equals('Token 已过期')),
        );
      });
    });

    group('markAsPlayed', () {
      test('标记已看成功调用 POST', () async {
        dioAdapter
            .onPost('/UserPlayedItems/$testItemId')
            .reply(200, {});

        await service.markAsPlayed(
          testItemId,
          serverUrl: testEmbyUrl,
          token: testToken,
        );
      });

      test('标记已看失败', () async {
        dioAdapter.onPost('/UserPlayedItems/$testItemId').reply(500, {
          'detail': '数据库写入失败',
        });

        expect(
          () => service.markAsPlayed(
            testItemId,
            serverUrl: testEmbyUrl,
            token: testToken,
          ),
          throwsA(contains('服务器错误')),
        );
      });
    });

    group('markAsUnplayed', () {
      test('标记未看成功调用 DELETE', () async {
        dioAdapter
            .onDelete('/UserPlayedItems/$testItemId')
            .reply(200, {});

        await service.markAsUnplayed(
          testItemId,
          serverUrl: testEmbyUrl,
          token: testToken,
        );
      });

      test('标记未看失败', () async {
        dioAdapter.onDelete('/UserPlayedItems/$testItemId').reply(403, {
          'detail': '无权限操作',
        });

        expect(
          () => service.markAsUnplayed(
            testItemId,
            serverUrl: testEmbyUrl,
            token: testToken,
          ),
          throwsA(equals('无权限操作')),
        );
      });
    });

    group('getWatchHistory', () {
      const testUserId = 'user-abc-123';

      // 构造 Emby 原生 PascalCase 的单个媒体项响应
      Map<String, dynamic> buildWatchHistoryItem({
        required String id,
        required String name,
        required String type,
        int? runTimeTicks,
        Map<String, dynamic>? userData,
      }) {
        return {
          'Id': id,
          'Name': name,
          'Type': type,
          if (runTimeTicks != null) 'RunTimeTicks': runTimeTicks,
          if (userData != null) 'UserData': userData,
        };
      }

      // 构造 getWatchHistory 期望的查询参数
      Map<String, dynamic> buildExpectedQueryParams({
        int limit = 50,
        String? userId,
      }) {
        final params = <String, dynamic>{
          'Limit': '$limit',
          'Recursive': 'true',
          'SortBy': 'DatePlayed',
          'SortOrder': 'Descending',
          'Fields':
              'Overview,Genres,CommunityRating,RunTimeTicks,ProductionYear,ImageTags,UserData',
        };
        if (userId != null && userId.isNotEmpty) {
          params['UserId'] = userId;
        }
        return params;
      }

      test('正常加载：传入 userId 时请求用户视图路径并正确解析', () async {
        final embyResponse = {
          'Items': [
            buildWatchHistoryItem(
              id: 'item-watch-1',
              name: '测试电影',
              type: 'Movie',
              runTimeTicks: 6000000000,
              userData: {
                'PlaybackPositionTicks': 1200000000,
                'IsFavorite': false,
                'Played': false,
              },
            ),
            buildWatchHistoryItem(
              id: 'item-watch-2',
              name: '测试剧集 S01E02',
              type: 'Episode',
              runTimeTicks: 3000000000,
              userData: {
                'PlaybackPositionTicks': 1500000000,
                'IsFavorite': true,
                'Played': false,
              },
            ),
          ],
          'TotalRecordCount': 2,
        };

        dioAdapter.onGet(
          '/Users/$testUserId/Items',
          query: buildExpectedQueryParams(userId: testUserId),
        ).reply(200, embyResponse);

        final history = await service.getWatchHistory(
          userId: testUserId,
          serverUrl: testEmbyUrl,
          token: testToken,
        );

        expect(history.length, 2);
        expect(history[0].id, 'item-watch-1');
        expect(history[0].title, '测试电影');
        expect(history[0].type, 'Movie');
        expect(history[0].runtimeTicks, 6000000000);
        expect(history[0].durationSeconds, closeTo(600.0, 0.01));
        expect(history[0].userData, isNotNull);
        expect(history[0].userData!.playbackPositionTicks, 1200000000.0);
        expect(history[1].id, 'item-watch-2');
        expect(history[1].title, '测试剧集 S01E02');
        expect(history[1].type, 'Episode');
        expect(history[1].userData!.isFavorite, true);
      });

      test('空历史：Emby 返回空 Items 列表时返回空列表', () async {
        dioAdapter.onGet(
          '/Users/$testUserId/Items',
          query: buildExpectedQueryParams(userId: testUserId),
        ).reply(200, {'Items': []});

        final history = await service.getWatchHistory(
          userId: testUserId,
          serverUrl: testEmbyUrl,
          token: testToken,
        );

        expect(history, isEmpty);
      });

      test('userId 为空时降级到 /Items 路径', () async {
        dioAdapter.onGet(
          '/Items',
          query: buildExpectedQueryParams(),
        ).reply(200, {'Items': []});

        final history = await service.getWatchHistory(
          serverUrl: testEmbyUrl,
          token: testToken,
        );

        expect(history, isEmpty);
      });

      test('网络错误时抛出异常', () async {
        dioAdapter.onGet(
          '/Users/$testUserId/Items',
          query: buildExpectedQueryParams(userId: testUserId),
        ).throwDioError(
          DioException.connectionError(
            requestOptions: RequestOptions(path: '/Users/$testUserId/Items'),
          ),
        );

        expect(
          () => service.getWatchHistory(
            userId: testUserId,
            serverUrl: testEmbyUrl,
            token: testToken,
          ),
          throwsA(equals('网络连接失败，请检查服务器地址')),
        );
      });

      test('401 未授权时抛出异常', () async {
        dioAdapter.onGet(
          '/Users/$testUserId/Items',
          query: buildExpectedQueryParams(userId: testUserId),
        ).reply(401, {'detail': 'Token 已过期'});

        expect(
          () => service.getWatchHistory(
            userId: testUserId,
            serverUrl: testEmbyUrl,
            token: testToken,
          ),
          throwsA(equals('Token 已过期')),
        );
      });

      test('500 服务器错误时抛出异常', () async {
        dioAdapter.onGet(
          '/Users/$testUserId/Items',
          query: buildExpectedQueryParams(userId: testUserId),
        ).reply(500, {'detail': '服务器内部错误'});

        expect(
          () => service.getWatchHistory(
            userId: testUserId,
            serverUrl: testEmbyUrl,
            token: testToken,
          ),
          throwsA(contains('服务器错误')),
        );
      });
    });
  });
}
