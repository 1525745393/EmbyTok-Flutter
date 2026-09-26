// 网络与弱网测试：超时模拟、错误码、重试

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

class NetworkWeakTestPage extends StatefulWidget {
  const NetworkWeakTestPage({super.key});

  @override
  State<NetworkWeakTestPage> createState() => _NetworkWeakTestPageState();
}

class _NetworkWeakTestPageState extends State<NetworkWeakTestPage> {
  String _result = '点击下方按钮开始测试';
  bool _loading = false;

  Future<void> _runTest({
    required String label,
    required Future<Response> Function() request,
  }) async {
    setState(() {
      _loading = true;
      _result = '$label 测试中...';
    });
    try {
      final resp = await request();
      setState(() => _result = '$label 成功：HTTP ${resp.statusCode}');
    } on TimeoutException {
      setState(() => _result = '$label 超时（符合预期）');
    } on DioException catch (e) {
      setState(() => _result =
          '$label 失败：${e.type} ${e.response?.statusCode ?? ''} ${e.message ?? ''}');
    } catch (e) {
      setState(() => _result = '$label 异常：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('网络与弱网测试')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _result,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_loading) const LinearProgressIndicator(),
            ElevatedButton(
              onPressed: _loading
                  ? null
                  : () => _runTest(
                      label: '正常请求',
                      request: () => Dio().get(
                        'https://httpbin.org/get',
                        options: Options(
                            receiveTimeout: const Duration(seconds: 5),
                            sendTimeout: const Duration(seconds: 5)),
                      ),
                    ),
              child: const Text('正常请求（httpbin）'),
            ),
            ElevatedButton(
              onPressed: _loading
                  ? null
                  : () => _runTest(
                      label: '超时模拟',
                      request: () => Dio().get(
                        'https://httpbin.org/delay/10',
                        options: Options(
                            receiveTimeout: const Duration(seconds: 2),
                            sendTimeout: const Duration(seconds: 2)),
                      ),
                    ),
              child: const Text('超时模拟（2s 超时 / 10s 延迟）'),
            ),
            ElevatedButton(
              onPressed: _loading
                  ? null
                  : () => _runTest(
                      label: '404 错误码',
                      request: () => Dio().get('https://httpbin.org/status/404'),
                    ),
              child: const Text('404 错误码'),
            ),
            ElevatedButton(
              onPressed: _loading
                  ? null
                  : () => _runTest(
                      label: '500 错误码',
                      request: () => Dio().get('https://httpbin.org/status/500'),
                    ),
              child: const Text('500 错误码'),
            ),
          ],
        ),
      ),
    );
  }
}
