// 环境切换：临时覆盖 ApiClient baseUrl，不写入正式服务器列表
// 退出测试模式或重启 App 后自动恢复原配置

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/api_client.dart';

const _kTestEnvKey = 'test_mode_override_base_url';

class EnvironmentSwitchPage extends StatefulWidget {
  const EnvironmentSwitchPage({super.key});

  @override
  State<EnvironmentSwitchPage> createState() => _EnvironmentSwitchPageState();
}

class _EnvironmentSwitchPageState extends State<EnvironmentSwitchPage> {
  static const _presets = [
    ['正式', ''],
    ['开发', 'http://192.168.1.100:8096'],
    ['测试', 'http://test.emby.example.com:8096'],
  ];

  late TextEditingController _customController;
  String _current = '';

  @override
  void initState() {
    super.initState();
    _customController = TextEditingController();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _current = prefs.getString(_kTestEnvKey) ?? '';
      _customController.text = _current;
    });
  }

  Future<void> _apply(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTestEnvKey, url);
    ApiClient().setBaseUrl(url);
    setState(() => _current = url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('环境切换')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '临时覆盖 ApiClient baseUrl，不写入正式服务器列表。\n'
              '重启 App 后自动恢复原配置。',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
          for (final p in _presets)
            RadioListTile<String>(
              title: Text(p[0]),
              subtitle: Text(p[1].isEmpty ? '（恢复默认）' : p[1]),
              value: p[1],
              groupValue: _current,
              onChanged: (v) => _apply(v ?? ''),
            ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _customController,
              decoration: const InputDecoration(
                labelText: '自定义地址',
                hintText: 'http://host:port',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton(
              onPressed: () => _apply(_customController.text.trim()),
              child: const Text('应用自定义地址'),
            ),
          ),
        ],
      ),
    );
  }
}
