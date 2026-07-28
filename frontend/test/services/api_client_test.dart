import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:embytok_flutter/models/app_error.dart';
import 'package:embytok_flutter/services/api_client.dart';

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

    group('setToken / clearToken', () {
      test('setToken 后请求头包含 Token', () async {
        apiClient.setToken('test-token-123');

        // 配置 mock 响应
        dioAdapter.onGet('/test', (server) => server.reply(200, {'success': true}));

        // 发送请求
        final response = await apiClient.get('/test');

        // 验证请求头中包含 Token
        // ApiClient 通过 X-Emby-Token 和 X-Emby-Authorization 头注入 Token
        // 不设置标准的 Authorization Bearer 头（Emby 规范）
        expect(response.requestOptions.headers['X-Emby-Token'], 'test-token-123');
        expect(response.requestOptions.headers['X-Emby-Authorization'],
            contains('Token="test-token-123"'));
      });

      test('clearToken 后请求头不包含 Token', () async {
        apiClient.setToken('test-token');
        apiClient.clearToken();

        // 配置 mock 响应
        dioAdapter.onGet('/test', (server) => server.reply(200, {'success': true}));

        // 发送请求
        final response = await apiClient.get('/test');

        // 验证请求头中不包含 Token
        expect(response.requestOptions.headers['X-Emby-Token'], isNull);
        // clearToken 后 X-Emby-Authorization 仍会发送客户端标识（不含 Token）
        expect(response.requestOptions.headers['X-Emby-Authorization'] ?? '', isNot(contains('Token=')));
      });
    });

    group('HTTP 方法', () {
      test('GET 请求成功', () async {
        dioAdapter.onGet('/users', (server) => server.reply(200, {'users': []}));

        final response = await apiClient.get('/users');

        expect(response.statusCode, 200);
        expect(response.data, {'users': []});
      });

      test('GET 请求带查询参数', () async {
        dioAdapter.onGet('/users', (server) => server.reply(200, {'users': [], 'page': 1}), queryParameters: {'page': 1});

        final response = await apiClient.get('/users', queryParameters: {'page': 1});

        expect(response.statusCode, 200);
        expect(response.data['page'], 1);
      });

      test('POST 请求成功', () async {
        dioAdapter.onPost('/users', (server) => server.reply(201, {'id': 1, 'name': 'test'}), data: {'name': 'test'});

        final response = await apiClient.post('/users', data: {'name': 'test'});

        expect(response.statusCode, 201);
        expect(response.data['id'], 1);
      });

      test('PUT 请求成功', () async {
        dioAdapter.onPut('/users/1', (server) => server.reply(200, {'id': 1, 'name': 'updated'}), data: {'name': 'updated'});

        final response = await apiClient.put('/users/1', data: {'name': 'updated'});

        expect(response.statusCode, 200);
        expect(response.data['name'], 'updated');
      });

      test('DELETE 请求成功', () async {
        dioAdapter.onDelete('/users/1', (server) => server.reply(204, null));

        final response = await apiClient.delete('/users/1');

        expect(response.statusCode, 204);
      });
    });

    group('错误处理', () {
      test('连接超时返回中文提示', () async {
        dioAdapter.onGet('/timeout', (server) => server.throws(
              500,
              DioException(
                requestOptions: RequestOptions(path: '/timeout'),
                type: DioExceptionType.connectionTimeout,
                message: 'Connecting timed out',
              ),
            ));

        Object? caught;
        try {
          await apiClient.get('/timeout');
          fail('Expected AppError to be thrown');
        } catch (e) {
          caught = e;
        }
        expect(caught, isA<AppError>());
        final err = caught as AppError;
        expect(err.type, ErrorType.timeout);
        expect(err.message, '请求超时，请检查网络连接');
      });

      test('发送超时返回中文提示', () async {
        dioAdapter.onGet('/send-timeout', (server) => server.throws(
              500,
              DioException(
                requestOptions: RequestOptions(path: '/send-timeout'),
                type: DioExceptionType.sendTimeout,
                message: 'Sending timed out',
              ),
            ));

        Object? caught;
        try {
          await apiClient.get('/send-timeout');
          fail('Expected AppError to be thrown');
        } catch (e) {
          caught = e;
        }
        expect(caught, isA<AppError>());
        final err = caught as AppError;
        expect(err.type, ErrorType.timeout);
        expect(err.message, '请求超时，请检查网络连接');
      });

      test('接收超时返回中文提示', () async {
        dioAdapter.onGet('/receive-timeout', (server) => server.throws(
              500,
              DioException(
                requestOptions: RequestOptions(path: '/receive-timeout'),
                type: DioExceptionType.receiveTimeout,
                message: 'Receiving timed out',
              ),
            ));

        Object? caught;
        try {
          await apiClient.get('/receive-timeout');
          fail('Expected AppError to be thrown');
        } catch (e) {
          caught = e;
        }
        expect(caught, isA<AppError>());
        final err = caught as AppError;
        expect(err.type, ErrorType.timeout);
        expect(err.message, '请求超时，请检查网络连接');
      });

      test('网络错误返回中文提示', () async {
        dioAdapter.onGet('/network-error', (server) => server.throws(
              500,
              DioException(
                requestOptions: RequestOptions(path: '/network-error'),
                type: DioExceptionType.connectionError,
                message: 'Connection failed',
              ),
            ));

        Object? caught;
        try {
          await apiClient.get('/network-error');
          fail('Expected AppError to be thrown');
        } catch (e) {
          caught = e;
        }
        expect(caught, isA<AppError>());
        final err = caught as AppError;
        expect(err.type, ErrorType.network);
        expect(err.message, '网络连接失败，请检查网络设置');
      });

      test('401 错误返回中文提示', () async {
        dioAdapter.onGet('/unauthorized', (server) => server.reply(401, {}));

        Object? caught;
        try {
          await apiClient.get('/unauthorized');
          fail('Expected AppError to be thrown');
        } catch (e) {
          caught = e;
        }
        expect(caught, isA<AppError>());
        final err = caught as AppError;
        expect(err.type, ErrorType.unauthorized);
        expect(err.message, '登录已失效，请重新登录');
      });

      test('401 错误带自定义消息', () async {
        dioAdapter.onGet('/unauthorized-custom', (server) => server.reply(401, {'detail': 'Token 已过期'}));

        Object? caught;
        try {
          await apiClient.get('/unauthorized-custom');
          fail('Expected AppError to be thrown');
        } catch (e) {
          caught = e;
        }
        expect(caught, isA<AppError>());
        final err = caught as AppError;
        expect(err.type, ErrorType.unauthorized);
        expect(err.message, 'Token 已过期');
      });

      test('403 错误返回中文提示', () async {
        dioAdapter.onGet('/forbidden', (server) => server.reply(403, {}));

        Object? caught;
        try {
          await apiClient.get('/forbidden');
          fail('Expected AppError to be thrown');
        } catch (e) {
          caught = e;
        }
        expect(caught, isA<AppError>());
        final err = caught as AppError;
        expect(err.type, ErrorType.forbidden);
        expect(err.message, '访问被拒绝');
      });

      test('403 错误带自定义消息', () async {
        dioAdapter.onGet('/forbidden-custom', (server) => server.reply(403, {'detail': '权限不足'}));

        Object? caught;
        try {
          await apiClient.get('/forbidden-custom');
          fail('Expected AppError to be thrown');
        } catch (e) {
          caught = e;
        }
        expect(caught, isA<AppError>());
        final err = caught as AppError;
        expect(err.type, ErrorType.forbidden);
        expect(err.message, '权限不足');
      });

      test('404 错误返回中文提示', () async {
        dioAdapter.onGet('/not-found', (server) => server.reply(404, {}));

        Object? caught;
        try {
          await apiClient.get('/not-found');
          fail('Expected AppError to be thrown');
        } catch (e) {
          caught = e;
        }
        expect(caught, isA<AppError>());
        final err = caught as AppError;
        expect(err.type, ErrorType.notFound);
        expect(err.message, '资源未找到');
      });

      test('404 错误带自定义消息', () async {
        dioAdapter.onGet('/not-found-custom', (server) => server.reply(404, {'detail': '用户不存在'}));

        Object? caught;
        try {
          await apiClient.get('/not-found-custom');
          fail('Expected AppError to be thrown');
        } catch (e) {
          caught = e;
        }
        expect(caught, isA<AppError>());
        final err = caught as AppError;
        expect(err.type, ErrorType.notFound);
        expect(err.message, '用户不存在');
      });

      test('500 错误返回中文提示', () async {
        dioAdapter.onGet('/server-error', (server) => server.reply(500, {}));

        Object? caught;
        try {
          await apiClient.get('/server-error');
          fail('Expected AppError to be thrown');
        } catch (e) {
          caught = e;
        }
        expect(caught, isA<AppError>());
        final err = caught as AppError;
        expect(err.type, ErrorType.serverError);
        expect(err.message, '服务器错误');
      });

      test('500 错误带自定义消息', () async {
        dioAdapter.onGet('/server-error-custom', (server) => server.reply(500, {'detail': '数据库连接失败'}));

        Object? caught;
        try {
          await apiClient.get('/server-error-custom');
          fail('Expected AppError to be thrown');
        } catch (e) {
          caught = e;
        }
        expect(caught, isA<AppError>());
        final err = caught as AppError;
        expect(err.type, ErrorType.serverError);
        expect(err.message, '服务器错误：数据库连接失败');
      });

      test('响应中包含 detail 字段时使用该信息', () async {
        dioAdapter.onGet('/validation-error', (server) => server.reply(400, {'detail': '用户名不能为空'}));

        Object? caught;
        try {
          await apiClient.get('/validation-error');
          fail('Expected AppError to be thrown');
        } catch (e) {
          caught = e;
        }
        expect(caught, isA<AppError>());
        final err = caught as AppError;
        expect(err.message, '用户名不能为空');
      });

      test('响应中包含 message 字段时使用该信息', () async {
        dioAdapter.onGet('/message-error', (server) => server.reply(400, {'message': '参数格式错误'}));

        Object? caught;
        try {
          await apiClient.get('/message-error');
          fail('Expected AppError to be thrown');
        } catch (e) {
          caught = e;
        }
        expect(caught, isA<AppError>());
        final err = caught as AppError;
        expect(err.message, '参数格式错误');
      });

      test('detail 优先于 message', () async {
        dioAdapter.onGet('/both-fields', (server) => server.reply(400, {
          'detail': '使用 detail',
          'message': '使用 message',
        }));

        Object? caught;
        try {
          await apiClient.get('/both-fields');
          fail('Expected AppError to be thrown');
        } catch (e) {
          caught = e;
        }
        expect(caught, isA<AppError>());
        final err = caught as AppError;
        expect(err.message, '使用 detail');
      });

      test('响应为字符串时使用该字符串', () async {
        dioAdapter.onGet('/string-error', (server) => server.reply(400, '错误信息字符串'));

        Object? caught;
        try {
          await apiClient.get('/string-error');
          fail('Expected AppError to be thrown');
        } catch (e) {
          caught = e;
        }
        expect(caught, isA<AppError>());
        final err = caught as AppError;
        expect(err.message, '错误信息字符串');
      });

      test('其他错误返回默认消息', () async {
        dioAdapter.onGet('/other-error', (server) => server.reply(418, {}));

        Object? caught;
        try {
          await apiClient.get('/other-error');
          fail('Expected AppError to be thrown');
        } catch (e) {
          caught = e;
        }
        expect(caught, isA<AppError>());
        final err = caught as AppError;
        expect(err.message, contains('请求失败'));
      });
    });
  });
}
