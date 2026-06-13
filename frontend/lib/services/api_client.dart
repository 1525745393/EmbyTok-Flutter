// 轻量 HTTP 客户端：基于 Dio，将请求发送到 Emby 服务器
// 并自动在请求头注入 X-Emby-Token 进行鉴权

import 'package:dio/dio.dart';

class ApiClient {
  final Dio _dio;
  String? _token;
  String? _userId;
  String? _baseUrl;

  ApiClient({Dio? dio}) : _dio = dio ?? Dio() {
    _setupInterceptors();
  }

  // 核心配置：所有请求统一注入 X-Emby-Token
  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // X-Emby-Token: Emby 标准的鉴权头
          if (_token != null && _token!.isNotEmpty) {
            options.headers['X-Emby-Token'] = _token!;
          }
          // Emby 要求的客户端标识头（可选，但推荐）
          options.headers['Accept'] = 'application/json';
          return handler.next(options);
        },
        onError: (error, handler) {
          // 将 Dio 错误统一成可读的错误信息
          final message = _humanReadableError(error);
          return handler.next(
            DioException(
              requestOptions: error.requestOptions,
              response: error.response,
              error: message,
              type: error.type,
            ),
          );
        },
      ),
    );
    // 默认超时
    _dio.options.connectTimeout = const Duration(seconds: 15);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
  }

  // 友好的错误信息
  String _humanReadableError(DioException error) {
    final status = error.response?.statusCode;
    if (status == 401) return '认证失败，请重新登录';
    if (status == 403) return '没有权限访问此内容';
    if (status == 404) return '内容不存在';
    if (status != null && status >= 500) return '服务器错误（$status）';
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return '请求超时，请检查网络';
    }
    if (error.type == DioExceptionType.connectionError) {
      return '无法连接到服务器';
    }
    if (error.message != null) return error.message!;
    return '请求失败';
  }

  // ——— setter ———
  void setBaseUrl(String url) {
    _baseUrl = url.endsWith('/')
        ? url.substring(0, url.length - 1)
        : url;
    _dio.options.baseUrl = _baseUrl!;
  }

  void setToken(String token) {
    _token = token;
  }

  void setUserId(String userId) {
    _userId = userId;
  }

  // ——— 统一的请求方法 ———
  Future<Response<T>> _request<T>(
    String method,
    String path, {
    Map<String, dynamic>? queryParameters,
    dynamic data,
  }) async {
    try {
      return await _dio.request<T>(
        path,
        queryParameters: queryParameters,
        data: data,
        options: Options(method: method),
      );
    } on DioException catch (e) {
      // 重新抛出更友好的错误
      throw _humanReadableError(e);
    } catch (e) {
      rethrow;
    }
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) =>
      _request<T>('GET', path, queryParameters: queryParameters);

  Future<Response<T>> post<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    dynamic data,
  }) =>
      _request<T>('POST', path, queryParameters: queryParameters, data: data);

  Future<Response<T>> delete<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) =>
      _request<T>('DELETE', path, queryParameters: queryParameters);
}
