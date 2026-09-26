// 网络诊断工具：检测连接问题并给出修复建议
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../utils/logger.dart';

class NetworkDiagnosticPage extends StatefulWidget {
  const NetworkDiagnosticPage({super.key, this.serverUrl});

  final String? serverUrl;

  @override
  State<NetworkDiagnosticPage> createState() => _NetworkDiagnosticPageState();
}

class _DiagResult {
  final String label;
  final String detail;
  final bool success;
  final Duration? elapsed;

  const _DiagResult({
    required this.label,
    required this.detail,
    required this.success,
    this.elapsed,
  });
}

class _NetworkDiagnosticPageState extends State<NetworkDiagnosticPage> {
  final List<_DiagResult> _results = [];
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _serverUrl = widget.serverUrl;
  }

  // 用全局方式获取 auth state
  String? _serverUrl;

  Future<void> _runDiagnostics() async {
    setState(() {
      _running = true;
      _results.clear();
    });

    // 1. 网络连接检测
    try {
      final dynamic rawResults = await Connectivity().checkConnectivity();
      final List<ConnectivityResult> results = rawResults is List
          ? rawResults.cast<ConnectivityResult>()
          : [rawResults as ConnectivityResult];
      final type = results.isEmpty ? ConnectivityResult.none : results.first;
      final typeStr = switch (type) {
        ConnectivityResult.wifi => 'WiFi',
        ConnectivityResult.mobile => '移动数据',
        ConnectivityResult.ethernet => '以太网',
        ConnectivityResult.vpn => 'VPN',
        ConnectivityResult.none => '无连接',
        _ => '未知',
      };
      _addResult(_DiagResult(
        label: '网络连接',
        detail: type == ConnectivityResult.none
            ? '无网络连接，请检查 WiFi 或移动数据'
            : '当前网络：$typeStr',
        success: type != ConnectivityResult.none,
      ));
    } catch (e) {
      _addResult(_DiagResult(
        label: '网络连接',
        detail: '检测失败：$e',
        success: false,
      ));
    }

    if (_serverUrl == null || _serverUrl!.isEmpty) {
      _addResult(const _DiagResult(
        label: '服务器连接',
        detail: '未配置服务器地址，请先登录',
        success: false,
      ));
      setState(() => _running = false);
      return;
    }

    // 2. 解析服务器地址
    Uri? uri;
    try {
      uri = Uri.parse(_serverUrl!);
      _addResult(_DiagResult(
        label: '地址解析',
        detail: '主机：${uri.host}，端口：${uri.port}',
        success: true,
      ));
    } catch (e) {
      _addResult(_DiagResult(
        label: '地址解析',
        detail: 'URL 格式错误：$e',
        success: false,
      ));
      setState(() => _running = false);
      return;
    }

    // 3. TCP 连接测试
    try {
      final sw = Stopwatch()..start();
      final socket = await Socket.connect(
        uri.host,
        uri.port,
        timeout: const Duration(seconds: 5),
      );
      sw.stop();
      socket.destroy();
      _addResult(_DiagResult(
        label: 'TCP 连接',
        detail: '连接成功，延迟 ${sw.elapsedMilliseconds}ms',
        success: true,
        elapsed: sw.elapsed,
      ));
    } catch (e) {
      _addResult(_DiagResult(
        label: 'TCP 连接',
        detail: '连接失败：$e\n建议：检查服务器是否在线、端口是否正确、防火墙是否放行',
        success: false,
      ));
    }

    // 4. HTTPS 握手测试
    if (uri.scheme == 'https') {
      try {
        final sw = Stopwatch()..start();
        final client = HttpClient()
          ..connectionTimeout = const Duration(seconds: 8);
        final request = await client.getUrl(uri);
        final response = await request.close().timeout(const Duration(seconds: 8));
        sw.stop();
        client.close();
        _addResult(_DiagResult(
          label: 'HTTPS 握手',
          detail: '握手成功，状态码 ${response.statusCode}，耗时 ${sw.elapsedMilliseconds}ms',
          success: response.statusCode > 0,
          elapsed: sw.elapsed,
        ));
      } catch (e) {
        _addResult(_DiagResult(
          label: 'HTTPS 握手',
          detail: '失败：$e\n建议：证书是否过期？是否需要开启"允许自签名证书"？',
          success: false,
        ));
      }
    } else {
      _addResult(const _DiagResult(
        label: 'HTTPS 握手',
        detail: 'HTTP 连接，跳过证书测试',
        success: true,
      ));
    }

    // 5. API 响应测试
    try {
      final sw = Stopwatch()..start();
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 10);
      final apiUri = Uri.parse('${_serverUrl!}/emby/System/Info/Public');
      final request = await client.getUrl(apiUri);
      final response = await request.close().timeout(const Duration(seconds: 10));
      sw.stop();
      client.close();
      _addResult(_DiagResult(
        label: 'API 响应',
        detail: response.statusCode == 200
            ? '服务器响应正常，耗时 ${sw.elapsedMilliseconds}ms'
            : 'HTTP ${response.statusCode}',
        success: response.statusCode == 200,
        elapsed: sw.elapsed,
      ));
    } catch (e) {
      _addResult(_DiagResult(
        label: 'API 响应',
        detail: '请求失败：$e\n建议：确认服务器路径正确（/emby）',
        success: false,
      ));
    }

    AppLogger.info('网络诊断完成', data: {'results': _results.length});
    if (mounted) setState(() => _running = false);
  }

  void _addResult(_DiagResult r) {
    if (mounted) setState(() => _results.add(r));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('网络诊断')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_serverUrl != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                '诊断目标：$_serverUrl',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _running ? null : _runDiagnostics,
              icon: _running
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.network_check),
              label: Text(_running ? '诊断中...' : '开始诊断'),
            ),
          ),
          const SizedBox(height: 24),
          if (_results.isEmpty && !_running)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('点击"开始诊断"检测服务器连接状态',
                    style: TextStyle(color: Colors.grey)),
              ),
            ),
          ..._results.map((r) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(
                    r.success ? Icons.check_circle : Icons.error,
                    color: r.success ? Colors.green : Colors.red,
                  ),
                  title: Text(r.label),
                  subtitle: Text(r.detail),
                  trailing: r.elapsed != null
                      ? Text('${r.elapsed!.inMilliseconds}ms')
                      : null,
                ),
              )),
        ],
      ),
    );
  }
}
