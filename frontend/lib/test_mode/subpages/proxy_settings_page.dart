// HTTP 代理设置：配置 Dio 走 Charles/mitmproxy 抓包代理

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/api_client.dart';

const _kProxyKey = 'test_mode_proxy';

class ProxySettingsPage extends StatefulWidget {
  const ProxySettingsPage({super.key});

  @override
  State<ProxySettingsPage> createState() => _ProxySettingsPageState();
}

class _ProxySettingsPageState extends State<ProxySettingsPage> {
  late TextEditingController _hostController;
  late TextEditingController _portController;
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    _hostController = TextEditingController(text: '192.168.1.100');
    _portController = TextEditingController(text: '8888');
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kProxyKey);
    if (saved != null && saved.isNotEmpty) {
      final parts = saved.split(':');
      _hostController.text = parts[0];
      _portController.text = parts.length > 1 ? parts[1] : '8888';
      setState(() => _enabled = true);
    }
  }

  Future<void> _apply() async {
    final prefs = await SharedPreferences.getInstance();
    if (_enabled) {
      final proxy = '${_hostController.text.trim()}:${_portController.text.trim()}';
      await prefs.setString(_kProxyKey, proxy);
      // Dio 设置代理
      final adapter = ApiClient().dio.httpClientAdapter;
      if (adapter is IOHttpClientAdapter) {
        adapter.createHttpClient = () {
          final client = HttpClient();
          client.findProxy = (uri) => 'PROXY $proxy';
          return client;
        };
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('代理已设置: $proxy（重启后生效）')),
        );
      }
    } else {
      await prefs.remove(_kProxyKey);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('代理已关闭')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('HTTP 代理设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '配置 Dio 走外部代理（Charles / mitmproxy）。\n'
            '设置后需重启 App 生效。\n\n'
            '注意：代理需在同一局域网，手机需信任代理证书才能抓 HTTPS。',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('启用代理'),
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _hostController,
            decoration: const InputDecoration(
              labelText: '代理主机',
              hintText: '如 192.168.1.100',
              border: OutlineInputBorder(),
            ),
            enabled: _enabled,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _portController,
            decoration: const InputDecoration(
              labelText: '代理端口',
              hintText: '如 8888',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            enabled: _enabled,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _apply,
            child: const Text('应用设置'),
          ),
        ],
      ),
    );
  }
}
