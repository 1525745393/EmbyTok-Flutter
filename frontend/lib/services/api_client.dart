// 轻量 HTTP 客户端：基于 Dio，将请求发送到 Emby 服务器
// 并自动在请求头注入 X-Emby-Token 进行鉴权
// 完整遵循 Emby 官方 API 规范：
//   X-Emby-Authorization: MediaBrowser Client="...", Device="...", DeviceId="...", Version="...", UserId="..."
//   X-Emby-Token: <access_token> (登录后)
//   X-Emby-Client / X-Emby-Device-Name / X-Emby-Device-Id / X-Emby-Client-Version (独立头，兼容部分服务器)

import 'dart:math' as math;

import 'package:dio/dio.dart';

class ApiClient {
  final Dio _dio;
  String? _token;
  String? _userId;
  String? _baseUrl;

  // Emby 标准客户端标识（静态部分）
  static const _clientName = 'EmbyTok';
  static const _clientVersion = '1.0.0';
  static const _deviceName = 'Mobile';

  // 稳定设备 ID（存储在内存中，由外部初始化后传入）
  // 初始值：随机 UUID（在应用启动时会从 shared_preferences 读取并替换）
  static String _deviceId = _generateDefaultDeviceId();

  // 生成一个默认 UUID（格式：xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx）
  static String _generateDefaultDeviceId() {
    final rand = math.Random.secure();
    String hex(int len) {
      final sb = StringBuffer();
      for (int i = 0; i < len; i++) {
        sb.write(rand.nextInt(16).toRadixString(16));
      }
      return sb.toString();
    }
    // 格式：8-4-4-4-12
    return '${hex(8)}-${hex(4)}-4${hex(3)}-${['8', '9', 'a', 'b'][rand.nextInt(4)]}${hex(3)}-${hex(12)}';
  }

  // 供外部设置稳定 DeviceId（从 shared_preferences 读取后调用）
  static void setDeviceId(String id) {
    if (id.isNotEmpty) {
      _deviceId = id;
    }
  }

  static String get deviceId => _deviceId;

  // 构建 X-Emby-Authorization 头（符合 Emby 官方 API 规范）
  // 当有 UserId 时也加入，让服务器能正确关联到用户
  String _buildAuthorizationHeader() {
    final parts = <String>[
      'Client="$_clientName"',
      'Device="$_deviceName"',
      'DeviceId="$_deviceId"',
      'Version="$_clientVersion"',
    ];
    if (_userId != null && _userId!.isNotEmpty) {
      parts.add('UserId="$_userId"');
    }
    return 'MediaBrowser ${parts.join(', ')}';
  }

  ApiClient({Dio? dio}) : _dio = dio ?? Dio() {
    _setupInterceptors();
    // 默认配置
    _dio.options.connectTimeout = const Duration(seconds: 15);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    // 默认 JSON content type（dio 会自动添加 JSON 编码）
    _dio.options.contentType = 'application/json';
    _dio.options.headers['Accept'] = 'application/json';
  }

  // 核心配置：统一注入 Emby 所需的请求头
  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // 1. Emby 标准：X-Emby-Authorization（主认证头）
          options.headers['X-Emby-Authorization'] = _buildAuthorizationHeader();

          // 2. 独立的 X-Emby-* 头（某些服务器/插件会读取）
          options.headers['X-Emby-Client'] = _clientName;
          options.headers['X-Emby-Device-Name'] = _deviceName;
          options.headers['X-Emby-Device-Id'] = _deviceId;
          options.headers['X-Emby-Client-Version'] = _clientVersion;

          // 3. Emby 标准：Token 鉴权头（登录后注入）
          if (_token != null && _token!.isNotEmpty) {
            options.headers['X-Emby-Token'] = _token!;
          }

          // 4. 内容协商
          options.headers['Accept'] = 'application/json';

          // 注意：contentType 由 Dio 根据 request options 的 contentType 字段决定，
          // 这里不强制覆盖，避免与 POST 请求的 data 编码方式冲突

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

    // 401: 未授权 / token 过期
    if (status == 401) {
      return '认证失败：${serverMsg ?? "请检查用户名或密码，或重新登录"}';
    }
    // 403: 禁止访问
    if (status == 403) {
      return '没有权限访问此内容（403）${serverMsg != null ? '：$serverMsg' : ''}';
    }
    // 404: 资源不存在
    if (status == 404) {
      return '请求的地址不存在（404），请检查服务器地址和端口是否正确';
    }
    // 5xx: 服务器错误
    if (status != null && status >= 500) {
      return '服务器错误（$status）${serverMsg != null ? '：$serverMsg' : '，请稍后重试'}';
    }
    // 连接超时
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return '请求超时，请检查网络或服务器地址';
    }
    // 连接错误（无法到达服务器）
    if (error.type == DioExceptionType.connectionError) {
      return '无法连接到服务器：请检查地址、端口是否正确，以及手机是否在同一局域网';
    }
    // 优先返回服务器信息（如果有）
    if (serverMsg != null && serverMsg.isNotEmpty) {
      return serverMsg;
    }
    // 其他：返回 dio 原始信息（调试友好）
    if (error.message != null && error.message!.isNotEmpty) {
      return error.message!;
    }
    // 最终兜底
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
      // 重新抛出更友好的错误（已在拦截器中处理过的 message）
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

  // ——— 便捷方法：获取当前请求头（用于 video_player 等需要传递头的场景） ———
  Map<String, String> get currentHttpHeaders {
    final headers = <String, String>{
      'X-Emby-Authorization': _buildAuthorizationHeader(),
      'X-Emby-Client': _clientName,
      'X-Emby-Device-Name': _deviceName,
      'X-Emby-Device-Id': _deviceId,
      'X-Emby-Client-Version': _clientVersion,
      'Accept': '*/*',
    };
    if (_token != null && _token!.isNotEmpty) {
      headers['X-Emby-Token'] = _token!;
    }
    return headers;
  }
}
