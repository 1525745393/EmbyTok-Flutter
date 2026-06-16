// ApiClient 测试：验证 Dio 封装、Token 注入、错误处理
// 当前实现：X-Emby-Authorization 用于客户端标识，X-Emby-Token 用于用户认证

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:embbytok_flutter/services/api_client.dart';

void main() {
  late ApiClient apiClient;
  late Dio dio;
  late DioAdapter dioAdapter;

  setUp(() {
    dio = Dio();
    dioAdapter = DioAdapter(dio: dio);
    dio.httpClientAdapter = dioAdapter;
    apiClient = ApiClient.withDio(dio, baseUrl: 'http://test.example.com');
  });

  group('ApiClient', () {
    group('构造函数', () {
      test('使用默认 baseUrl 创建实例', () {
        final client = ApiClient();
        expect(client, isNotNull);
      });

      test('使用自定义 baseUrl 创建实例', () {
        final client = ApiClient(baseUrl: 'http://custom.example.com');
        expect(client, isNotNull);
        expect(client.dio.options.baseUrl, 'http://custom.example.com');
      });

      test('使用 withDio 构造函数创建实例', () {
        final customDio = Dio();
        final client = ApiClient.withDio(customDio, baseUrl: 'http://custom.example.com');
        expect(client, isNotNull);
        expect(client.dio, same(customDio));
      });
    });

    group('setBaseUrl', () {
      test('更新 baseUrl', () {
        apiClient.setBaseUrl('http://new.example.com');
        expect(apiClient.dio.options.baseUrl, 'http://new.example.com');
      });
    });

    // ============================
    // setToken / clearToken 测试
    // 注意：当前实现将 token 注入到 X-Emby-Token header（而非 Authorization: Bearer）
    // ============================
    group('setToken / clearToken', () {
      test('setToken 后请求头包含 X-Emby-Token', () async {
        apiClient.setToken('test-token-123');

        // 配置 mock 响应
        dioAdapter.onGet('/test').reply(200, <String, dynamic>{'success': true});

        // 发送请求
        final response = await apiClient.get<dynamic>('/test');

        // 验证请求头中包含 X-Emby-Token（当前实现的认证方式）
        expect(response.requestOptions.headers['X-Emby-Token'], 'test-token-123');
        // 同时验证包含客户端标识 header
        expect(response.requestOptions.headers['X-Emby-Authorization'], isNotNull);
      });

      test('clearToken 后请求头不包含 X-Emby-Token', () async {
        apiClient.setToken('test-token');
        apiClient.clearToken();

        // 配置 mock 响应
        dioAdapter.onGet('/test').reply(200, <String, dynamic>{'success': true});

        // 发送请求
        final response = await apiClient.get<dynamic>('/test');

        // 验证请求头中不包含 Token
        expect(response.requestOptions.headers['X-Emby-Token'], isNull);
        // 但客户端标识 header 应该仍然存在
        expect(response.requestOptions.headers['X-Emby-Authorization'], isNotNull);
      });
    });

    group('HTTP 方法', () {
      test('GET 请求成功', () async {
        dioAdapter.onGet('/users').reply(200, <String, dynamic>{'users': <dynamic>[]});

        final response = await apiClient.get<dynamic>('/users');

        expect(response.statusCode, 200);
        expect(response.data, <String, dynamic>{'users': <dynamic>[]});
      });

      test('GET 请求带查询参数', () async {
        dioAdapter.onGet('/users',
            queryParameters: <String, dynamic>{'page': 1}).reply(
              200,
              <String, dynamic>{'users': <dynamic>[], 'page': 1},
            );

        final response =
            await apiClient.get<dynamic>('/users', queryParameters: <String, dynamic>{'page': 1});

        expect(response.statusCode, 200);
        expect(response.data['page'], 1);
      });

      test('POST 请求成功', () async {
        dioAdapter.onPost('/users',
            data: <String, dynamic>{'name': 'test'}).reply(
              201,
              <String, dynamic>{'id': 1, 'name': 'test'},
            );

        final response = await apiClient
            .post<dynamic>('/users', data: <String, dynamic>{'name': 'test'});

        expect(response.statusCode, 201);
        expect(response.data['id'], 1);
      });

      test('PUT 请求成功', () async {
        dioAdapter.onPut('/users/1',
            data: <String, dynamic>{'name': 'updated'}).reply(
              200,
              <String, dynamic>{'id': 1, 'name': 'updated'},
            );

        final response = await apiClient
            .put<dynamic>('/users/1', data: <String, dynamic>{'name': 'updated'});

        expect(response.statusCode, 200);
        expect(response.data['name'], 'updated');
      });

      test('DELETE 请求成功', () async {
        dioAdapter.onDelete('/users/1').reply(204, null);

        final response = await apiClient.delete<dynamic>('/users/1');

        expect(response.statusCode, 204);
      });
    });

    // ============================
    // 错误处理测试
    // 当前 _handleError 返回中文消息
    // ============================
    group('错误处理', () {
      test('连接超时返回中文提示', () async {
        dioAdapter.onGet('/timeout').throws_(
              DioException(
                requestOptions: RequestOptions(path: '/timeout'),
                type: DioExceptionType.connectionTimeout,
              ),
            );

        await expectLater(
          apiClient.get<dynamic>('/timeout'),
          throwsA(equals('请求超时，请检查网络连接')),
        );
      });

      test('发送超时返回中文提示', () async {
        dioAdapter.onGet('/send-timeout').throws_(
              DioException(
                requestOptions: RequestOptions(path: '/send-timeout'),
                type: DioExceptionType.sendTimeout,
              ),
            );

        await expectLater(
          apiClient.get<dynamic>('/send-timeout'),
          throwsA(equals('请求超时，请检查网络连接')),
        );
      });

      test('接收超时返回中文提示', () async {
        dioAdapter.onGet('/receive-timeout').throws_(
              DioException(
                requestOptions: RequestOptions(path: '/receive-timeout'),
                type: DioExceptionType.receiveTimeout,
              ),
            );

        await expectLater(
          apiClient.get<dynamic>('/receive-timeout'),
          throwsA(equals('请求超时，请检查网络连接')),
        );
      });

      test('网络错误返回中文提示', () async {
        dioAdapter.onGet('/network-error').throws_(
              DioException(
                requestOptions: RequestOptions(path: '/network-error'),
                type: DioExceptionType.connectionError,
              ),
            );

        await expectLater(
          apiClient.get<dynamic>('/network-error'),
          throwsA(equals('网络连接失败，请检查服务器地址')),
        );
      });

      test('401 错误返回中文提示', () async {
        dioAdapter.onGet('/unauthorized').reply(401, <String, dynamic>{});

        await expectLater(
          apiClient.get<dynamic>('/unauthorized'),
          throwsA(equals('未授权，请重新登录')),
        );
      });

      test('401 错误带自定义消息', () async {
        dioAdapter.onGet('/unauthorized-custom').reply(
              401,
              <String, dynamic>{'detail': 'Token 已过期'},
            );

        await expectLater(
          apiClient.get<dynamic>('/unauthorized-custom'),
          throwsA(equals('Token 已过期')),
        );
      });

      test('403 错误返回中文提示', () async {
        dioAdapter.onGet('/forbidden').reply(403, <String, dynamic>{});

        await expectLater(
          apiClient.get<dynamic>('/forbidden'),
          throwsA(equals('访问被拒绝')),
        );
      });

      test('403 错误带自定义消息', () async {
        dioAdapter.onGet('/forbidden-custom').reply(
              403,
              <String, dynamic>{'detail': '权限不足'},
            );

        await expectLater(
          apiClient.get<dynamic>('/forbidden-custom'),
          throwsA(equals('权限不足')),
        );
      });

      test('404 错误返回中文提示', () async {
        dioAdapter.onGet('/not-found').reply(404, <String, dynamic>{});

        await expectLater(
          apiClient.get<dynamic>('/not-found'),
          throwsA(equals('资源未找到')),
        );
      });

      test('404 错误带自定义消息', () async {
        dioAdapter.onGet('/not-found-custom').reply(
              404,
              <String, dynamic>{'detail': '用户不存在'},
            );

        await expectLater(
          apiClient.get<dynamic>('/not-found-custom'),
          throwsA(equals('用户不存在')),
        );
      });

      test('500 错误返回中文提示', () async {
        dioAdapter.onGet('/server-error').reply(500, <String, dynamic>{});

        await expectLater(
          apiClient.get<dynamic>('/server-error'),
          throwsA(equals('服务器错误')),
        );
      });

      test('500 错误带自定义消息', () async {
        dioAdapter.onGet('/server-error-custom').reply(
              500,
              <String, dynamic>{'detail': '数据库连接失败'},
            );

        await expectLater(
          apiClient.get<dynamic>('/server-error-custom'),
          throwsA(equals('服务器错误：数据库连接失败')),
        );
      });

      test('响应中包含 detail 字段时使用该信息', () async {
        dioAdapter.onGet('/validation-error').reply(
              400,
              <String, dynamic>{'detail': '用户名不能为空'},
            );

        await expectLater(
          apiClient.get<dynamic>('/validation-error'),
          throwsA(equals('用户名不能为空')),
        );
      });

      test('响应为字符串时使用该字符串', () async {
        dioAdapter.onGet('/string-error').reply(400, '错误信息字符串');

        await expectLater(
          apiClient.get<dynamic>('/string-error'),
          throwsA(equals('错误信息字符串')),
        );
      });

      test('其他错误返回默认消息（包含请求失败）', () async {
        dioAdapter.onGet('/other-error').reply(418, <String, dynamic>{});

        await expectLater(
          apiClient.get<dynamic>('/other-error'),
          throwsA(contains('请求失败')),
        );
      });
    });
  });
}
