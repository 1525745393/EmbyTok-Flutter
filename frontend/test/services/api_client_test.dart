// ApiClient 测试：验证 HTTP 请求、认证 Token 和错误处理

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import 'package:embbytok_flutter/services/api_client.dart';

void main() {
  late Dio dio;
  late DioAdapter dioAdapter;

  setUp(() {
    dio = Dio();
    dioAdapter = DioAdapter(dio: dio);
    dio.httpClientAdapter = dioAdapter;
  });

  group('ApiClient', () {
    group('构造函数', () {
      test('使用默认 baseUrl 创建实例', () {
        final apiClient = ApiClient();
        expect(apiClient, isNotNull);
      });

      test('使用自定义 baseUrl 创建实例', () {
        final apiClient = ApiClient(baseUrl: 'https://custom.api.com');
        expect(apiClient, isNotNull);
      });

      test('使用 withDio 构造函数创建实例', () {
        final testDio = Dio();
        final apiClient = ApiClient.withDio(testDio);
        expect(apiClient, isNotNull);
      });
    });

    group('setBaseUrl', () {
      test('更新 baseUrl', () {
        final apiClient = ApiClient.withDio(dio);
        apiClient.setBaseUrl('https://new.api.com');
        expect(dio.options.baseUrl, 'https://new.api.com');
      });
    });

    group('setToken / clearToken', () {
      test('setToken 后请求头包含 Token', () async {
        final apiClient = ApiClient.withDio(dio);
        apiClient.setToken('test-token-123');

        dioAdapter.onGet(
          '/test',
          (request) => Reply(200, <String, dynamic>{'success': true}),
        );

        await apiClient.get<dynamic>('/test');
        expect(dio.options.headers['X-Emby-Token'], 'test-token-123');
      });

      test('clearToken 后请求头不包含 Token', () async {
        final apiClient = ApiClient.withDio(dio);
        apiClient.setToken('test-token-123');
        apiClient.clearToken();

        dioAdapter.onGet(
          '/test',
          (request) => Reply(200, <String, dynamic>{'success': true}),
        );

        await apiClient.get<dynamic>('/test');
        expect(dio.options.headers.containsKey('X-Emby-Token'), false);
      });
    });

    group('HTTP 方法', () {
      test('GET 请求成功', () async {
        final apiClient = ApiClient.withDio(dio);
        final responseData = <String, dynamic>{
          'users': <Map<String, dynamic>>[]
        };

        dioAdapter.onGet(
          '/users',
          (request) => Reply(200, responseData),
        );

        final resp = await apiClient.get<dynamic>('/users');
        expect(resp.statusCode, 200);
      });

      test('POST 请求成功', () async {
        final apiClient = ApiClient.withDio(dio);
        final requestData = <String, dynamic>{'name': 'test'};
        final responseData = <String, dynamic>{'id': 1, 'name': 'test'};

        dioAdapter.onPost(
          '/users',
          (request) => Reply(201, responseData),
          data: requestData,
        );

        final resp = await apiClient.post<dynamic>('/users', data: requestData);
        expect(resp.statusCode, 201);
      });

      test('PUT 请求成功', () async {
        final apiClient = ApiClient.withDio(dio);
        final requestData = <String, dynamic>{'name': 'updated'};
        final responseData = <String, dynamic>{'id': 1, 'name': 'updated'};

        dioAdapter.onPut(
          '/users/1',
          (request) => Reply(200, responseData),
          data: requestData,
        );

        final resp = await apiClient.put<dynamic>('/users/1', data: requestData);
        expect(resp.statusCode, 200);
      });

      test('DELETE 请求成功', () async {
        final apiClient = ApiClient.withDio(dio);

        dioAdapter.onDelete(
          '/users/1',
          (request) => Reply(204, null),
        );

        final resp = await apiClient.delete<dynamic>('/users/1');
        expect(resp.statusCode, 204);
      });
    });

    group('错误处理', () {
      test('连接超时返回中文提示', () async {
        final apiClient = ApiClient.withDio(dio);

        dioAdapter.onGet(
          '/timeout',
          (request) => throwsA(
            DioException(
              requestOptions: RequestOptions(path: '/timeout'),
              type: DioExceptionType.connectionTimeout,
            ),
          ),
        );

        await expectLater(
          apiClient.get<dynamic>('/timeout'),
          throwsA(contains('请求超时')),
        );
      });

      test('发送超时返回中文提示', () async {
        final apiClient = ApiClient.withDio(dio);

        dioAdapter.onGet(
          '/send-timeout',
          (request) => throwsA(
            DioException(
              requestOptions: RequestOptions(path: '/send-timeout'),
              type: DioExceptionType.sendTimeout,
            ),
          ),
        );

        await expectLater(
          apiClient.get<dynamic>('/send-timeout'),
          throwsA(contains('请求超时')),
        );
      });

      test('接收超时返回中文提示', () async {
        final apiClient = ApiClient.withDio(dio);

        dioAdapter.onGet(
          '/receive-timeout',
          (request) => throwsA(
            DioException(
              requestOptions: RequestOptions(path: '/receive-timeout'),
              type: DioExceptionType.receiveTimeout,
            ),
          ),
        );

        await expectLater(
          apiClient.get<dynamic>('/receive-timeout'),
          throwsA(contains('请求超时')),
        );
      });

      test('网络错误返回中文提示', () async {
        final apiClient = ApiClient.withDio(dio);

        dioAdapter.onGet(
          '/network-error',
          (request) => throwsA(
            DioException(
              requestOptions: RequestOptions(path: '/network-error'),
              type: DioExceptionType.connectionError,
            ),
          ),
        );

        await expectLater(
          apiClient.get<dynamic>('/network-error'),
          throwsA(contains('网络连接失败')),
        );
      });

      test('401 错误返回中文提示', () async {
        final apiClient = ApiClient.withDio(dio);

        dioAdapter.onGet(
          '/unauthorized',
          (request) => Reply(401, <String, dynamic>{}),
        );

        await expectLater(
          apiClient.get<dynamic>('/unauthorized'),
          throwsA(contains('未授权')),
        );
      });

      test('401 错误带自定义消息', () async {
        final apiClient = ApiClient.withDio(dio);

        dioAdapter.onGet(
          '/unauthorized-custom',
          (request) => Reply(401, <String, dynamic>{'detail': 'Token 已过期'}),
        );

        await expectLater(
          apiClient.get<dynamic>('/unauthorized-custom'),
          throwsA('Token 已过期'),
        );
      });

      test('403 错误返回中文提示', () async {
        final apiClient = ApiClient.withDio(dio);

        dioAdapter.onGet(
          '/forbidden',
          (request) => Reply(403, <String, dynamic>{}),
        );

        await expectLater(
          apiClient.get<dynamic>('/forbidden'),
          throwsA(contains('访问被拒绝')),
        );
      });

      test('403 错误带自定义消息', () async {
        final apiClient = ApiClient.withDio(dio);

        dioAdapter.onGet(
          '/forbidden-custom',
          (request) => Reply(403, <String, dynamic>{'detail': '权限不足'}),
        );

        await expectLater(
          apiClient.get<dynamic>('/forbidden-custom'),
          throwsA('权限不足'),
        );
      });

      test('404 错误返回中文提示', () async {
        final apiClient = ApiClient.withDio(dio);

        dioAdapter.onGet(
          '/not-found',
          (request) => Reply(404, <String, dynamic>{}),
        );

        await expectLater(
          apiClient.get<dynamic>('/not-found'),
          throwsA(contains('资源未找到')),
        );
      });

      test('404 错误带自定义消息', () async {
        final apiClient = ApiClient.withDio(dio);

        dioAdapter.onGet(
          '/not-found-custom',
          (request) => Reply(404, <String, dynamic>{'detail': '用户不存在'}),
        );

        await expectLater(
          apiClient.get<dynamic>('/not-found-custom'),
          throwsA('用户不存在'),
        );
      });

      test('500 错误返回中文提示', () async {
        final apiClient = ApiClient.withDio(dio);

        dioAdapter.onGet(
          '/server-error',
          (request) => Reply(500, <String, dynamic>{}),
        );

        await expectLater(
          apiClient.get<dynamic>('/server-error'),
          throwsA(contains('服务器错误')),
        );
      });

      test('500 错误带自定义消息', () async {
        final apiClient = ApiClient.withDio(dio);

        dioAdapter.onGet(
          '/server-error-custom',
          (request) => Reply(500, <String, dynamic>{'detail': '数据库连接失败'}),
        );

        await expectLater(
          apiClient.get<dynamic>('/server-error-custom'),
          throwsA(contains('服务器错误')),
        );
      });

      test('响应中包含 detail 字段时使用该信息', () async {
        final apiClient = ApiClient.withDio(dio);

        dioAdapter.onGet(
          '/validation-error',
          (request) => Reply(400, <String, dynamic>{'detail': '用户名不能为空'}),
        );

        await expectLater(
          apiClient.get<dynamic>('/validation-error'),
          throwsA('用户名不能为空'),
        );
      });

      test('响应为字符串时使用该字符串', () async {
        final apiClient = ApiClient.withDio(dio);

        dioAdapter.onGet(
          '/string-error',
          (request) => Reply(400, '错误信息字符串'),
        );

        await expectLater(
          apiClient.get<dynamic>('/string-error'),
          throwsA('错误信息字符串'),
        );
      });

      test('其他错误返回默认消息', () async {
        final apiClient = ApiClient.withDio(dio);

        dioAdapter.onGet(
          '/other-error',
          (request) => Reply(418, <String, dynamic>{}),
        );

        await expectLater(
          apiClient.get<dynamic>('/other-error'),
          throwsA(contains('请求失败')),
        );
      });
    });
  });
}
