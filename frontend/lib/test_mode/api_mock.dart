// API Mock 面板：按路径拦截请求并返回预设 Mock 响应
// 不引入 http_mock_adapter，直接用 Dio Interceptor 实现
//
// 用法：
// 1. 开启 Mock 开关
// 2. 添加路径规则（如 /Items/Latest → 返回固定 JSON）
// 3. 命中规则的请求不发网络，直接返回 Mock 数据

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/api_client.dart';

/// Mock 规则：path 前缀匹配 → 返回的状态码和 JSON body
class MockRule {
  final String pathPrefix;
  final int statusCode;
  final String body;

  MockRule({
    required this.pathPrefix,
    required this.statusCode,
    required this.body,
  });
}

/// 全局 Mock 规则列表
class MockRules extends ChangeNotifier {
  static final MockRules instance = MockRules._();
  MockRules._();

  final List<MockRule> _rules = [];
  bool _enabled = false;

  bool get enabled => _enabled;
  List<MockRule> get rules => List.unmodifiable(_rules);

  void setEnabled(bool v) {
    _enabled = v;
    notifyListeners();
  }

  void add(MockRule r) {
    _rules.add(r);
    notifyListeners();
  }

  void removeAt(int i) {
    _rules.removeAt(i);
    notifyListeners();
  }

  /// 检查路径是否命中规则，命中返回 Mock 响应
  /// 未命中返回 null（走真实网络）
  MockRule? match(String path) {
    if (!_enabled) return null;
    for (final r in _rules) {
      if (path.contains(r.pathPrefix)) return r;
    }
    return null;
  }
}

/// Dio 拦截器：命中 Mock 规则时短路返回
class MockInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final rule = MockRules.instance.match(options.path);
    if (rule != null) {
      handler.resolve(
        Response(
          requestOptions: options,
          statusCode: rule.statusCode,
          data: jsonDecode(rule.body),
        ),
      );
      return;
    }
    handler.next(options);
  }
}
