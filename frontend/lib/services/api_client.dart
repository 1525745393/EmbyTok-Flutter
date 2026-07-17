// 基于 Dio 的 API 客户端封装：统一配置、Token 注入、错误处理与日志
// 改造说明：
// - 错误处理统一返回 AppError，替代裸 String
// - GET 请求支持按需指数退避重试（retry: true）
// - 去重 key 加入 baseUrl + token，修复跨账号错误复用问题

import 'dart:async';

import 'package:dio/dio.dart';

import '../models/app_error.dart';
import '../utils/formatters.dart';

class ApiClient {
  final Dio _dio;
  String? _token;

  // GET 请求去重：相同 path + queryParameters 的并发请求复用同一个 Future
  final Map<String, Completer<Response<dynamic>>> _pendingGets = {};

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
          final token = _token;
          if (token != null && token.isNotEmpty) {
            options.headers['X-Emby-Token'] = token;
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

  // 统一错误处理：将 DioException 转换为 AppError
  //
  // 返回 AppError 而非 String，让上层能根据 type 做差异化处理
  // （如 401 跳登录、网络错误自动重试等）
  AppError _handleError(DioException e, {StackTrace? stackTrace}) {
    final st = stackTrace ?? e.stackTrace;
    // 超时类
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return AppError.timeout(debugMessage: e.toString(), stackTrace: st);
    }
    // 连接错误（DNS、握手、连接被拒绝等）
    if (e.type == DioExceptionType.connectionError || e.response == null) {
      return AppError.network(debugMessage: e.toString(), stackTrace: st);
    }
    // 有 HTTP 响应的错误，按状态码分类
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
    // HTML 解码错误信息（服务器可能返回 HTML 编码的错误）
    detail = htmlDecode(detail);

    if (status == 401) {
      return AppError(
        type: ErrorType.unauthorized,
        message: detail.isNotEmpty ? detail : '登录已失效，请重新登录',
        debugMessage: e.toString(),
        statusCode: status,
        stackTrace: st,
      );
    }
    if (status == 403) {
      return AppError(
        type: ErrorType.forbidden,
        message: detail.isNotEmpty ? detail : '访问被拒绝',
        debugMessage: e.toString(),
        statusCode: status,
        stackTrace: st,
      );
    }
    if (status == 404) {
      return AppError(
        type: ErrorType.notFound,
        message: detail.isNotEmpty ? detail : '资源未找到',
        debugMessage: e.toString(),
        statusCode: status,
        stackTrace: st,
      );
    }
    if (status != null && status >= 500) {
      return AppError.serverError(
        statusCode: status,
        message: detail.isNotEmpty ? '服务器错误：$detail' : '服务器错误',
        debugMessage: e.toString(),
        stackTrace: st,
      );
    }
    return AppError.unknown(
      message: detail.isNotEmpty ? detail : '请求失败：${e.message}',
      debugMessage: e.toString(),
      stackTrace: st,
    );
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
    } on DioException catch (e, st) {
      // 统一转换为 AppError 抛出，上层 catch AppError 即可
      throw _handleError(e, stackTrace: st);
    } catch (e, st) {
      // 非 DioException（如序列化错误），统一包装为未知错误
      throw AppError.unknown(
        message: '请求异常：$e',
        debugMessage: e.toString(),
        stackTrace: st,
      );
    }
  }

  /// GET 请求：支持去重和按需指数退避重试
  ///
  /// 参数：
  /// - [retry] 是否启用指数退避重试，默认 false
  ///   启用后对可重试错误（网络错误/超时/5xx）自动重试，最多 2 次
  ///   初始延迟 500ms，退避因子 2.0（500ms → 1000ms）
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    bool retry = false,
  }) async {
    // 生成请求去重 key：baseUrl + token + path + 排序后的 queryParameters
    // 加入 baseUrl 和 token 防止跨账号请求错误复用
    final key = _buildDedupeKey(path, queryParameters);
    // 如果已有相同 key 的请求在进行中，等待其完成并复用结果
    final existing = _pendingGets[key];
    if (existing != null) {
      final response = await existing.future;
      return response as Response<T>;
    }
    // 创建新的 Completer 并发起新请求
    final completer = Completer<Response<dynamic>>();
    _pendingGets[key] = completer;
    try {
      final response = retry
          ? await _requestWithRetry<T>(
              path,
              queryParameters: queryParameters,
              headers: headers,
            )
          : await _request<T>(path, method: 'GET', queryParameters: queryParameters, headers: headers);
      completer.complete(response);
      return response;
    } catch (e) {
      completer.completeError(e);
      rethrow;
    } finally {
      // 无论成功或失败，都从 map 中移除 key，确保下次请求可以正常发送
      _pendingGets.remove(key);
    }
  }

  /// 指数退避重试：仅用于 GET 请求
  ///
  /// 重试策略：
  /// - 最多重试 2 次（共 3 次请求）
  /// - 初始延迟 500ms，退避因子 2.0（500ms → 1000ms）
  /// - 仅对可重试错误重试（网络错误、超时、5xx 服务器错误）
  /// - 4xx 错误（401/403/404）不重试，重试无意义
  Future<Response<T>> _requestWithRetry<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
  }) async {
    const maxRetries = 2;

    Object? lastError;
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        return await _request<T>(
          path,
          method: 'GET',
          queryParameters: queryParameters,
          headers: headers,
        );
      } on AppError catch (e) {
        lastError = e;
        // 不可重试的错误直接抛出
        if (!e.isRetryable) rethrow;
        // 已达最大重试次数，抛出最后一次错误
        if (attempt == maxRetries) rethrow;
        // 计算退避延迟：500ms * 2^attempt（500, 1000, 2000...）
        // 使用整数乘法避免 double.pow 的导入
        final delayMs = 500 * (1 << attempt); // 1<<0=1, 1<<1=2, 1<<2=4
        await Future<void>.delayed(Duration(milliseconds: delayMs));
      } catch (e) {
        // 非 AppError 错误直接抛出（理论上不会走到这里，_request 已统一转换）
        rethrow;
      }
    }
    // 理论上不会走到这里，但为了让分析器满意
    throw lastError ?? AppError.unknown(message: '重试失败');
  }

  /// 生成 GET 请求去重 key：baseUrl + token + path + 排序后的 queryParameters
  ///
  /// 加入 baseUrl 和 token 的原因：
  /// 防止多账号/多服务器场景下，相同 path 的请求错误复用结果
  /// （如用户A的 /Users/Me/Views 和用户B的同路径请求不应共享）
  String _buildDedupeKey(String path, Map<String, dynamic>? queryParameters) {
    final baseUrl = _dio.options.baseUrl;
    final token = _token ?? '';
    final prefix = '$baseUrl|$token|';
    if (queryParameters == null || queryParameters.isEmpty) {
      return '$prefix$path';
    }
    final sortedKeys = queryParameters.keys.toList()..sort();
    final parts = <String>[];
    for (final k in sortedKeys) {
      parts.add('$k=${queryParameters[k]}');
    }
    return '$prefix$path?${parts.join('&')}';
  }

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
