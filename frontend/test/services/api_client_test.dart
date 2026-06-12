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
        dioAdapter.onGet('/test').reply(200, {'success': true});

        // 发送请求
        final response = await apiClient.get('/test');

        // 验证请求头中包含 Token
        expect(response.requestOptions.headers['X-Emby-Token'], 'test-token-123');
        expect(response.requestOptions.headers['Authorization'], 'Bearer test-token-123');
      });

      test('clearToken 后请求头不包含 Token', () async {
        apiClient.setToken('test-token');
        apiClient.clearToken();

        // 配置 mock 响应
        dioAdapter.onGet('/test').reply(200, {'success': true});

        // 发送请求
        final response = await apiClient.get('/test');

        // 验证请求头中不包含 Token
        expect(response.requestOptions.headers['X-Emby-Token'], isNull);
        expect(response.requestOptions.headers['Authorization'], isNull);
      });
    });

    group('HTTP 方法', () {
      test('GET 请求成功', () async {
        dioAdapter.onGet('/users').reply(200, {'users': []});

        final response = await apiClient.get('/users');

        expect(response.statusCode, 200);
        expect(response.data, {'users': []});
      });

      test('GET 请求带查询参数', () async {
        dioAdapter.onGet('/users', query: {'page': 1}).reply(200, {'users': [], 'page': 1});

        final response = await apiClient.get('/users', queryParameters: {'page': 1});

        expect(response.statusCode, 200);
        expect(response.data['page'], 1);
      });

      test('POST 请求成功', () async {
        dioAdapter.onPost('/users', body: {'name': 'test'}).reply(201, {'id': 1, 'name': 'test'});

        final response = await apiClient.post('/users', data: {'name': 'test'});

        expect(response.statusCode, 201);
        expect(response.data['id'], 1);
      });

      test('PUT 请求成功', () async {
        dioAdapter.onPut('/users/1', body: {'name': 'updated'}).reply(200, {'id': 1, 'name': 'updated'});

        final response = await apiClient.put('/users/1', data: {'name': 'updated'});

        expect(response.statusCode, 200);
        expect(response.data['name'], 'updated');
      });

      test('DELETE 请求成功', () async {
        dioAdapter.onDelete('/users/1').reply(204);

        final response = await apiClient.delete('/users/1');

        expect(response.statusCode, 204);
      });
    });

    group('错误处理', () {
      test('连接超时返回中文提示', () async {
        dioAdapter.onGet('/timeout').throwDioError(
              DioException.connectionTimeout(
                requestOptions: RequestOptions(path: '/timeout'),
              ),
            );

        expect(
          () => apiClient.get('/timeout'),
          throwsA(equals('请求超时，请检查网络连接')),
        );
      });

      test('发送超时返回中文提示', () async {
        dioAdapter.onGet('/send-timeout').throwDioError(
              DioException.sendTimeout(
                requestOptions: RequestOptions(path: '/send-timeout'),
              ),
            );

        expect(
          () => apiClient.get('/send-timeout'),
          throwsA(equals('请求超时，请检查网络连接')),
        );
      });

      test('接收超时返回中文提示', () async {
        dioAdapter.onGet('/receive-timeout').throwDioError(
              DioException.receiveTimeout(
                requestOptions: RequestOptions(path: '/receive-timeout'),
              ),
            );

        expect(
          () => apiClient.get('/receive-timeout'),
          throwsA(equals('请求超时，请检查网络连接')),
        );
      });

      test('网络错误返回中文提示', () async {
        dioAdapter.onGet('/network-error').throwDioError(
              DioException.connectionError(
                requestOptions: RequestOptions(path: '/network-error'),
              ),
            );

        expect(
          () => apiClient.get('/network-error'),
          throwsA(equals('网络连接失败，请检查服务器地址')),
        );
      });

      test('401 错误返回中文提示', () async {
        dioAdapter.onGet('/unauthorized').reply(401, {});

        expect(
          () => apiClient.get('/unauthorized'),
          throwsA(equals('未授权，请重新登录')),
        );
      });

      test('401 错误带自定义消息', () async {
        dioAdapter.onGet('/unauthorized-custom').reply(401, {'detail': 'Token 已过期'});

        expect(
          () => apiClient.get('/unauthorized-custom'),
          throwsA(equals('Token 已过期')),
        );
      });

      test('403 错误返回中文提示', () async {
        dioAdapter.onGet('/forbidden').reply(403, {});

        expect(
          () => apiClient.get('/forbidden'),
          throwsA(equals('访问被拒绝')),
        );
      });

      test('403 错误带自定义消息', () async {
        dioAdapter.onGet('/forbidden-custom').reply(403, {'detail': '权限不足'});

        expect(
          () => apiClient.get('/forbidden-custom'),
          throwsA(equals('权限不足')),
        );
      });

      test('404 错误返回中文提示', () async {
        dioAdapter.onGet('/not-found').reply(404, {});

        expect(
          () => apiClient.get('/not-found'),
          throwsA(equals('资源未找到')),
        );
      });

      test('404 错误带自定义消息', () async {
        dioAdapter.onGet('/not-found-custom').reply(404, {'detail': '用户不存在'});

        expect(
          () => apiClient.get('/not-found-custom'),
          throwsA(equals('用户不存在')),
        );
      });

      test('500 错误返回中文提示', () async {
        dioAdapter.onGet('/server-error').reply(500, {});

        expect(
          () => apiClient.get('/server-error'),
          throwsA(equals('服务器错误')),
        );
      });

      test('500 错误带自定义消息', () async {
        dioAdapter.onGet('/server-error-custom').reply(500, {'detail': '数据库连接失败'});

        expect(
          () => apiClient.get('/server-error-custom'),
          throwsA(equals('服务器错误：数据库连接失败')),
        );
      });

      test('响应中包含 detail 字段时使用该信息', () async {
        dioAdapter.onGet('/validation-error').reply(400, {'detail': '用户名不能为空'});

        expect(
          () => apiClient.get('/validation-error'),
          throwsA(equals('用户名不能为空')),
        );
      });

      test('响应中包含 message 字段时使用该信息', () async {
        dioAdapter.onGet('/message-error').reply(400, {'message': '参数格式错误'});

        expect(
          () => apiClient.get('/message-error'),
          throwsA(equals('参数格式错误')),
        );
      });

      test('detail 优先于 message', () async {
        dioAdapter.onGet('/both-fields').reply(400, {
          'detail': '使用 detail',
          'message': '使用 message',
        });

        expect(
          () => apiClient.get('/both-fields'),
          throwsA(equals('使用 detail')),
        );
      });

      test('响应为字符串时使用该字符串', () async {
        dioAdapter.onGet('/string-error').reply(400, '错误信息字符串');

        expect(
          () => apiClient.get('/string-error'),
          throwsA(equals('错误信息字符串')),
        );
      });

      test('其他错误返回默认消息', () async {
        dioAdapter.onGet('/other-error').reply(418, {});

        expect(
          () => apiClient.get('/other-error'),
          throwsA(contains('请求失败')),
        );
      });
    });
  });
}
