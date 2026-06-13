// 轻量 HTTP 客户端：基于 Dio，将请求发送到 Emby 服务器
// 并自动在请求头注入 X-Emby-Token 进行鉴权

import 'package:dio/dio.dart';

class ApiClient {
  final Dio _dio;
  String? _token;
  String? _userId;
  String? _baseUrl;

  // Emby 客户端标识 —— Emby 服务器会校验此头
  static const _clientAuthorization =
      'MediaBrowser Client="EmbyTok", Device="Mobile", DeviceId="embbytok-client", Version="1.0.0"';

  ApiClient({Dio? dio}) : _dio = dio ?? Dio() {
    _setupInterceptors();
    // 默认配置
    _dio.options.contentType = 'application/json';
    _dio.options.connectTimeout = const Duration(seconds: 15);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
  }

  // 核心配置：统一注入 Emby 所需的请求头
  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // Emby 标准：客户端标识头（必须）
          options.headers['X-Emby-Authorization'] = _clientAuthorization;
          // Emby 标准：Token 鉴权头（登录后才有）
          if (_token != null && _token!.isNotEmpty) {
            options.headers['X-Emby-Token'] = _token!;
          }
          // 确保请求体以 JSON 格式发送
          options.headers['Accept'] = 'application/json';
          options.headers['Content-Type'] = 'application/json';
          return handler.next(options);
        },
        onError: (error, handler) {
          // 将 Dio 错误统一成可读的错误信息，并附原始响应体信息
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
  }

  // 友好的错误信息 —— 尽量带上服务器返回的原始错误
  String _humanReadableError(DioException error) {
    final status = error.response?.statusCode;
    final respData = error.response?.data;

    // 尝试提取 Emby 服务器返回的错误信息
    String? serverMsg;
    if (respData is Map<String, dynamic>) {
      serverMsg = (respData['Message'] as String?) ??
          (respData['message'] as String?) ??
          (respData['errorMessage'] as String?) ??
          (respData['error_description'] as String?);
    } else if (respData is String && respData.isNotEmpty) {
      serverMsg = respData;
    }

    if (status == 401) {
      return '认证失败：${serverMsg ?? "请检查用户名或密码"}';
    }
    if (status == 403) return '没有权限访问此内容（403）';
    if (status == 404) return '请求的地址不存在（404），请检查服务器地址是否正确';
    if (status != null && status >= 500) {
      return '服务器错误（$status）${serverMsg != null ? '：$serverMsg' : ''}';
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return '请求超时，请检查网络或服务器地址';
    }
    if (error.type == DioExceptionType.connectionError) {
      return '无法连接到服务器：请检查地址和端口是否正确，以及手机是否在同一局域网';
    }
    if (serverMsg != null && serverMsg.isNotEmpty) {
      return serverMsg;
    }
    if (error.message != null && error.message!.isNotEmpty) {
      return error.message!;
    }
    return '请求失败，请检查网络后重试';
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
        options: Options(
          method: method,
          contentType: 'application/json',
        ),
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
