// 存储查看器：展示 shared_preferences 所有 key-value，支持删除单个 key

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageViewerPage extends StatefulWidget {
  const StorageViewerPage({super.key});

  @override
  State<StorageViewerPage> createState() => _StorageViewerPageState();
}

class _StorageViewerPageState extends State<StorageViewerPage> {
  Map<String, Object?> _prefs = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _prefs = Map<String, Object?>.from(prefs.getKeys().fold<Map<String, Object?>>(
        {}, (m, k) {
          m[k] = prefs.get(k);
          return m;
        },
      ));
      _loading = false;
    });
  }

  Future<void> _deleteKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final keys = _prefs.keys.toList()..sort();
    return Scaffold(
      appBar: AppBar(
        title: Text('存储查看器 (${keys.length})'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: keys.length,
              itemBuilder: (_, i) {
                final key = keys[i];
                final value = _prefs[key];
                final str = value == null
                    ? 'null'
                    : value.toString();
                final display =
                    str.length > 120 ? '${str.substring(0, 120)}...' : str;
                return ExpansionTile(
                  title: Text(key, style: const TextStyle(fontSize: 13)),
                  subtitle: Text(
                    value.runtimeType.toString(),
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () => _deleteKey(key),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: SelectableText(
                        str,
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 11),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
