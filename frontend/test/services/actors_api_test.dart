/// 演员 API 对接测试 (TDD)
/// 测试 getPeople 和 getFavoritePeople 与 Emby API 的正确对接

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

  setUp(() {
    dio = Dio();
    dioAdapter = DioAdapter(dio: dio);
    dio.httpClientAdapter = dioAdapter;
    apiClient = ApiClient.withDio(dio);
    service = EmbytokService(apiClient: apiClient);
  });

  group('演员 API 对接测试', () {
    group('getPeople - 演员列表', () {
      // 构造 Emby /Persons 响应
      Map<String, dynamic> buildPersonJson({
        required String id,
        required String name,
        String type = 'Actor',
        String? primaryImageTag,
      }) {
        return <String, dynamic>{
          'Id': id,
          'Name': name,
          'Type': type,
          if (primaryImageTag != null) 'PrimaryImageTag': primaryImageTag,
        };
      }

      // 构造期望的查询参数
      Map<String, dynamic> buildPeopleQuery({
        int limit = 50,
        int startIndex = 0,
        List<String>? personTypes,
      }) {
        final params = <String, dynamic>{
          'Limit': '$limit',
          'StartIndex': '$startIndex',
          'Recursive': 'true',
          'Fields': 'PrimaryImageTag,Overview',
        };
        if (personTypes != null && personTypes.isNotEmpty) {
          params['PersonTypes'] = personTypes.join(',');
        }
        return params;
      }

      test('成功获取演员列表并正确解析', () async {
        final response = <String, dynamic>{
          'Items': [
            buildPersonJson(
              id: 'person-1',
              name: '演员A',
              type: 'Actor',
              primaryImageTag: 'image-tag-1',
            ),
            buildPersonJson(
              id: 'person-2',
              name: '导演B',
              type: 'Director',
              primaryImageTag: 'image-tag-2',
            ),
          ],
          'TotalRecordCount': 2,
        };

        dioAdapter
            .onGet(
              '/Persons',
              query: buildPeopleQuery(),
            )
            .reply(200, response);

        final result = await service.getPeople(
          serverUrl: testEmbyUrl,
          token: testToken,
        );

        expect(result.items.length, 2);
        expect(result.total, 2);
        expect(result.items[0].id, 'person-1');
        expect(result.items[0].name, '演员A');
        expect(result.items[0].type, 'Actor');
        // 图片URL应包含认证token
        expect(result.items[0].imageUrl, contains('api_key=$testToken'));
        expect(result.items[1].name, '导演B');
        expect(result.items[1].type, 'Director');
      });

      test('分页参数正确传递', () async {
        dioAdapter
            .onGet(
              '/Persons',
              query: buildPeopleQuery(limit: 20, startIndex: 40),
            )
            .reply(200, <String, dynamic>{
              'Items': [],
              'TotalRecordCount': 100,
            });

        final result = await service.getPeople(
          limit: 20,
          startIndex: 40,
          serverUrl: testEmbyUrl,
          token: testToken,
        );

        expect(result.offset, 40);
        expect(result.limit, 20);
        expect(result.total, 100);
      });

      test('PersonTypes 筛选参数正确传递', () async {
        dioAdapter
            .onGet(
              '/Persons',
              query: buildPeopleQuery(personTypes: ['Director']),
            )
            .reply(200, <String, dynamic>{
              'Items': [
                buildPersonJson(id: 'dir-1', name: '导演X', type: 'Director'),
              ],
              'TotalRecordCount': 1,
            });

        final result = await service.getPeople(
          personTypes: ['Director'],
          serverUrl: testEmbyUrl,
          token: testToken,
        );

        expect(result.items.length, 1);
        expect(result.items[0].type, 'Director');
      });

      test('图片URL使用传入的token而非默认token', () async {
        final customToken = 'custom-token-xyz';
        final response = <String, dynamic>{
          'Items': [
            buildPersonJson(
              id: 'person-3',
              name: '演员C',
              primaryImageTag: 'tag-3',
            ),
          ],
          'TotalRecordCount': 1,
        };

        dioAdapter
            .onGet('/Persons')
            .reply(200, response);

        final result = await service.getPeople(
          serverUrl: testEmbyUrl,
          token: customToken,
        );

        // 图片URL应使用传入的token
        expect(result.items[0].imageUrl, contains('api_key=$customToken'));
      });

      test('空演员列表返回空结果', () async {
        dioAdapter
            .onGet('/Persons')
            .reply(200, <String, dynamic>{
              'Items': [],
              'TotalRecordCount': 0,
            });

        final result = await service.getPeople(
          serverUrl: testEmbyUrl,
          token: testToken,
        );

        expect(result.items, isEmpty);
        expect(result.total, 0);
      });

      test('API错误时抛出异常', () async {
        dioAdapter.onGet('/Persons').reply(500, {
          'detail': '服务器内部错误',
        });

        expect(
          () => service.getPeople(
            serverUrl: testEmbyUrl,
            token: testToken,
          ),
          throwsA(contains('服务器错误')),
        );
      });
    });

    group('getFavoritePeople - 已关注演员', () {
      Map<String, dynamic> buildFavoritePersonJson({
        required String id,
        required String name,
      }) {
        return <String, dynamic>{
          'Id': id,
          'Name': name,
          'Type': 'Person',
          'UserData': <String, dynamic>{
            'IsFavorite': true,
          },
        };
      }

      Map<String, dynamic> buildFavoritePeopleQuery({
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
          'IncludeItemTypes': 'Person',
          'SortBy': 'DateCreated',
          'SortOrder': 'Descending',
        };
      }

      test('传入userId时使用正确路径 /Users/{userId}/Items', () async {
        final response = <String, dynamic>{
          'Items': [
            buildFavoritePersonJson(id: 'fav-1', name: '已关注演员A'),
          ],
          'TotalRecordCount': 1,
        };

        dioAdapter
            .onGet(
              '/Users/$testUserId/Items',
              query: buildFavoritePeopleQuery(),
            )
            .reply(200, response);

        final result = await service.getFavoritePeople(
          userId: testUserId,
          serverUrl: testEmbyUrl,
          token: testToken,
        );

        expect(result.length, 1);
        expect(result[0].id, 'fav-1');
        expect(result[0].title, '已关注演员A');
      });

      test('无userId时降级到 /Items 路径', () async {
        dioAdapter
            .onGet(
              '/Items',
              query: buildFavoritePeopleQuery(),
            )
            .reply(200, <String, dynamic>{
              'Items': [],
              'TotalRecordCount': 0,
            });

        final result = await service.getFavoritePeople(
          serverUrl: testEmbyUrl,
          token: testToken,
        );

        expect(result, isEmpty);
      });

      test('API错误时抛出异常', () async {
        dioAdapter.onGet('/Users/$testUserId/Items').reply(401, {
          'detail': 'Token已过期',
        });

        expect(
          () => service.getFavoritePeople(
            userId: testUserId,
            serverUrl: testEmbyUrl,
            token: testToken,
          ),
          throwsA(equals('Token已过期')),
        );
      });
    });

    group('getPersonItems - 演员作品', () {
      const personId = 'person-abc';

      Map<String, dynamic> buildPersonItemsQuery({
        int limit = 30,
        int offset = 0,
      }) {
        return <String, dynamic>{
          'Limit': '$limit',
          'StartIndex': '$offset',
          'Recursive': 'true',
          'PersonIds': personId,
          'Fields':
              'Overview,Genres,CommunityRating,RunTimeTicks,ProductionYear,ImageTags,UserData',
        };
      }

      test('成功获取演员作品列表', () async {
        final response = <String, dynamic>{
          'Items': [
            <String, dynamic>{
              'Id': 'movie-1',
              'Name': '电影A',
              'Type': 'Movie',
              'ProductionYear': 2024,
            },
            <String, dynamic>{
              'Id': 'movie-2',
              'Name': '电影B',
              'Type': 'Movie',
              'ProductionYear': 2023,
            },
          ],
          'TotalRecordCount': 2,
        };

        dioAdapter
            .onGet(
              '/Items',
              query: buildPersonItemsQuery(),
            )
            .reply(200, response);

        final result = await service.getPersonItems(
          personId,
          serverUrl: testEmbyUrl,
          token: testToken,
        );

        expect(result.items.length, 2);
        expect(result.total, 2);
        expect(result.items[0].id, 'movie-1');
        expect(result.items[0].title, '电影A');
        expect(result.items[0].productionYear, 2024);
      });

      test('演员无作品返回空列表', () async {
        dioAdapter
            .onGet('/Items')
            .reply(200, <String, dynamic>{
              'Items': [],
              'TotalRecordCount': 0,
            });

        final result = await service.getPersonItems(
          'unknown-person',
          serverUrl: testEmbyUrl,
          token: testToken,
        );

        expect(result.items, isEmpty);
      });
    });
  });
}