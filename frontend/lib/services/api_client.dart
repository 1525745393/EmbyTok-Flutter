// 基于 Dio 的 API 客户端封装：统一配置、Token 注入、错误处理与日志

import 'package:dio/dio.dart';

class ApiClient {
  final Dio _dio;
  String? _token;

  ApiClient({String? baseUrl})
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl ?? '',
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
          contentType: Headers.jsonContentType,
        )) {
    _setupInterceptors();
  }

  // 注册拦截器：自动注入 Token、请求日志、错误日志
  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_token != null && _token!.isNotEmpty) {
            options.headers['X-Emby-Token'] = _token!;
            options.headers['Authorization'] = 'Bearer $_token';
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          return handler.next(response);
        },
        onError: (error, handler) {
          return handler.next(error);
        },
      ),
    );
  }

  // 更新 baseUrl
  void setBaseUrl(String url) {
    _dio.options.baseUrl = url;
  }

  // 设置 Token（会被拦截器注入到请求头）
  void setToken(String token) {
    _token = token;
  }

  // 清除 Token
  void clearToken() {
    _token = null;
  }

  // 统一错误处理：将 DioException 转换为可读字符串
  String _handleError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return '请求超时，请检查网络连接';
    }
    if (e.type == DioExceptionType.connectionError ||
        e.response == null) {
      return '网络连接失败，请检查服务器地址';
    }
    final status = e.response?.statusCode;
    final data = e.response?.data;
    String detail = '';
    if (data is Map<String, dynamic>) {
      detail = (data['detail'] as String?) ??
          (data['message'] as String?) ??
          '';
    } else if (data is String) {
      detail = data;
    }
    if (status == 401) return detail.isNotEmpty ? detail : '未授权，请重新登录';
    if (status == 403) return detail.isNotEmpty ? detail : '访问被拒绝';
    if (status == 404) return detail.isNotEmpty ? detail : '资源未找到';
    if (status != null && status >= 500) {
      return detail.isNotEmpty ? '服务器错误：$detail' : '服务器错误';
    }
    return detail.isNotEmpty ? detail : '请求失败：${e.message}';
  }

  Future<Response<T>> _request<T>(
    String path, {
    required String method,
    Map<String, dynamic>? queryParameters,
    dynamic data,
    Map<String, dynamic>? headers,
  }) async {
    try {
      final response = await _dio.request<T>(
        path,
        options: Options(
          method: method,
          headers: headers,
        ),
        queryParameters: queryParameters,
        data: data,
      );
      return response;
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      throw '请求异常：$e';
    }
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
  }) =>
      _request<T>(path, method: 'GET', queryParameters: queryParameters, headers: headers);

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
  }) =>
      _request<T>(path, method: 'POST', data: data, queryParameters: queryParameters, headers: headers);

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
  }) =>
      _request<T>(path, method: 'PUT', data: data, queryParameters: queryParameters, headers: headers);

  Future<Response<T>> delete<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    dynamic data,
  }) =>
      _request<T>(path, method: 'DELETE', queryParameters: queryParameters, headers: headers, data: data);
}
