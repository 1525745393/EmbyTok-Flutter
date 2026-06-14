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

  /// 测试友好的构造函数，允许注入自定义 Dio 实例
  ApiClient.withDio(this._dio, {String? baseUrl}) {
    if (baseUrl != null) {
      _dio.options.baseUrl = baseUrl;
    }
    _setupInterceptors();
  }

  /// 暴露内部 Dio 实例，用于测试验证
  Dio get dio => _dio;

  /// 当前配置的 baseUrl（供 service 层判断是否需要切换）
  String? get optionsBaseUrl => _dio.options.baseUrl;

  // Emby 客户端标识（用于 Emby 原生 API 认证）
  static const _clientAuthorization =
      'MediaBrowser Client="EmbyTok", Device="Mobile", DeviceId="embbytok-client", Version="1.0.0"';

  // 注册拦截器：自动注入 X-Emby-Token + X-Emby-Authorization 头
  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.headers['X-Emby-Authorization'] = _clientAuthorization;
          options.headers['Accept'] = 'application/json';
          if (_token != null && _token!.isNotEmpty) {
            options.headers['X-Emby-Token'] = _token!;
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

  // 直接发起 GET 请求（用于加载字幕等已包含完整 URL 的资源）
  // 会自动注入已设置的 X-Emby-Token 请求头
  Future<Response<T>> directGet<T>(
    String fullUrl, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
  }) async {
    final extraHeaders = <String, dynamic>{};
    if (_token != null && _token!.isNotEmpty) {
      extraHeaders['X-Emby-Token'] = _token!;
    }
    extraHeaders['X-Emby-Authorization'] =
        'MediaBrowser Client="EmbyTok", Device="Mobile", DeviceId="embbytok-client", Version="1.0.0"';
    if (headers != null) extraHeaders.addAll(headers);
    try {
      final response = await Dio().get<T>(
        fullUrl,
        queryParameters: queryParameters,
        options: Options(headers: extraHeaders),
      );
      return response;
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      throw '请求异常：$e';
    }
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
