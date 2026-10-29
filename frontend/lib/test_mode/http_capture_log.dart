// 网络请求抓包：环形缓冲记录所有 HTTP 请求/响应，供测试模式查看

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// 单条请求记录
class HttpRequestRecord {

  HttpRequestRecord({
    required this.method,
    required this.path,
    required this.statusCode,
    required this.durationMs,
    this.error,
  }) : time = DateTime.now();
  final String method;
  final String path;
  final int? statusCode;
  final int durationMs;
  final String? error;
  final DateTime time;
}

/// 全局抓包环形缓冲（最多 200 条）
class HttpRequestLog extends ChangeNotifier {
  HttpRequestLog._();
  static final HttpRequestLog instance = HttpRequestLog._();

  final List<HttpRequestRecord> _records = [];
  bool _enabled = false;

  bool get enabled => _enabled;
  List<HttpRequestRecord> get records => List.unmodifiable(_records.reversed);

  void setEnabled(bool v) {
    _enabled = v;
    if (!v) _records.clear();
    notifyListeners();
  }

  void add(HttpRequestRecord r) {
    if (!_enabled) return;
    _records.add(r);
    while (_records.length > 200) {
      _records.removeAt(0);
    }
    notifyListeners();
  }

  void clear() {
    _records.clear();
    notifyListeners();
  }
}

/// Dio 拦截器：记录请求到环形缓冲
class CaptureLogInterceptor extends Interceptor {
  static const _kCaptureStartKey = 'capture_start_ms';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // 并发安全：起点写入请求级 extra，禁止用拦截器实例字段共享 Stopwatch
    // （此前单实例 Stopwatch 被并发 onRequest 互相 reset，durationMs 错乱，batch153-F2）
    options.extra[_kCaptureStartKey] =
        DateTime.now().millisecondsSinceEpoch;
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    HttpRequestLog.instance.add(HttpRequestRecord(
      method: response.requestOptions.method,
      path: response.requestOptions.uri.path,
      statusCode: response.statusCode,
      durationMs: _elapsedOf(response.requestOptions),
    ));
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    HttpRequestLog.instance.add(HttpRequestRecord(
      method: err.requestOptions.method,
      path: err.requestOptions.uri.path,
      statusCode: err.response?.statusCode,
      durationMs: _elapsedOf(err.requestOptions),
      error: err.message,
    ));
    handler.next(err);
  }

  int _elapsedOf(RequestOptions options) {
    final start = options.extra[_kCaptureStartKey] as int?;
    if (start == null) return 0;
    return DateTime.now().millisecondsSinceEpoch - start;
  }
}
