// 网络请求抓包：环形缓冲记录所有 HTTP 请求/响应，供测试模式查看

import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// 单条请求记录
class HttpRequestRecord {
  final String method;
  final String path;
  final int? statusCode;
  final int durationMs;
  final String? error;
  final DateTime time;

  HttpRequestRecord({
    required this.method,
    required this.path,
    required this.statusCode,
    required this.durationMs,
    this.error,
  }) : time = DateTime.now();
}

/// 全局抓包环形缓冲（最多 200 条）
class HttpRequestLog extends ChangeNotifier {
  static final HttpRequestLog instance = HttpRequestLog._();
  HttpRequestLog._();

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
  final _stopwatch = Stopwatch();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _stopwatch.reset();
    _stopwatch.start();
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _stopwatch.stop();
    HttpRequestLog.instance.add(HttpRequestRecord(
      method: response.requestOptions.method,
      path: response.requestOptions.uri.path,
      statusCode: response.statusCode,
      durationMs: _stopwatch.elapsedMilliseconds,
    ));
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _stopwatch.stop();
    HttpRequestLog.instance.add(HttpRequestRecord(
      method: err.requestOptions.method,
      path: err.requestOptions.uri.path,
      statusCode: err.response?.statusCode,
      durationMs: _stopwatch.elapsedMilliseconds,
      error: err.message,
    ));
    handler.next(err);
  }
}
