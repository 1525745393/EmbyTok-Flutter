// 测试配置导入导出：导出/导入 SharedPreferences 快照，便于复现 bug

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

class TestConfigTransferPage extends StatefulWidget {
  const TestConfigTransferPage({super.key});

  @override
  State<TestConfigTransferPage> createState() => _TestConfigTransferPageState();
}

class _TestConfigTransferPageState extends State<TestConfigTransferPage> {
  bool _exporting = false;
  bool _importing = false;

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final data = <String, dynamic>{};
      for (final k in keys) {
        data[k] = prefs.get(k);
      }
      // 脱敏：隐藏 token/password
      final sanitized = data.map((k, v) {
        if (k.toLowerCase().contains('token') ||
            k.toLowerCase().contains('password') ||
            k.toLowerCase().contains('secret')) {
          return MapEntry(k, '***REDACTED***');
        }
        return MapEntry(k, v);
      });
      final json = const JsonEncoder.withIndent('  ').convert({
        'exportedAt': DateTime.now().toIso8601String(),
        'version': '1.0',
        'prefs': sanitized,
      });
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/embytok_test_config.json');
      await file.writeAsString(json);
      await Share.shareXFiles([XFile(file.path)],
          subject: 'EmbyTok 测试配置');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('导出失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _import() async {
    setState(() => _importing = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null) return;
      final file = File(result.files.single.path!);
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final prefs = json['prefs'] as Map<String, dynamic>;
      final prefsInstance = await SharedPreferences.getInstance();
      var count = 0;
      for (final entry in prefs.entries) {
        final v = entry.value;
        if (v is String) {
          await prefsInstance.setString(entry.key, v);
          count++;
        } else if (v is bool) {
          await prefsInstance.setBool(entry.key, v);
          count++;
        } else if (v is int) {
          await prefsInstance.setInt(entry.key, v);
          count++;
        } else if (v is double) {
          await prefsInstance.setDouble(entry.key, v);
          count++;
        } else if (v is List) {
          await prefsInstance.setStringList(
              entry.key, v.cast<String>());
          count++;
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已导入 $count 个配置项，重启 App 生效')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('导入失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('测试配置导入导出')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '导出当前 App 的 SharedPreferences 快照（自动脱敏 token/密码），\n'
            '通过系统分享发送给其他设备复现 bug。\n\n'
            '导入会覆盖同名配置项，不影响其他项。',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: _exporting
                ? const CircularProgressIndicator()
                : const Icon(Icons.upload),
            label: const Text('导出配置并分享'),
            onPressed: _exporting ? null : _export,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: _importing
                ? const CircularProgressIndicator()
                : const Icon(Icons.download),
            label: const Text('从 JSON 文件导入'),
            onPressed: _importing ? null : _import,
          ),
        ],
      ),
    );
  }
}
