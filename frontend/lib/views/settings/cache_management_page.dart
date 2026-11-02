// 缓存管理：查看和清理图片缓存、日志
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../utils/logger.dart';

class CacheManagementPage extends StatefulWidget {
  const CacheManagementPage({super.key});

  @override
  State<CacheManagementPage> createState() => _CacheManagementPageState();
}

class _CacheManagementPageState extends State<CacheManagementPage> {
  int _imageCacheSize = 0;
  int _tempCacheSize = 0;
  int _logSize = 0;
  bool _scanning = true;

  @override
  void initState() {
    super.initState();
    _scanCache();
  }

  Future<int> _dirSize(Directory dir) async {
    if (!dir.existsSync()) return 0;
    int total = 0;
    try {
      await for (final entity
          in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          try {
            total += await entity.length();
          } catch (_) {}
        }
      }
    } catch (_) {}
    return total;
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }

  Future<void> _scanCache() async {
    setState(() => _scanning = true);
    try {
      final tempDir = await getTemporaryDirectory();
      final appDocDir = await getApplicationDocumentsDirectory();
      _tempCacheSize = await _dirSize(tempDir);
      // 日志目录
      final logDir = Directory('${appDocDir.path}/logs');
      _logSize = await _dirSize(logDir);
      // 图片缓存通常在 temp 下
      _imageCacheSize = _tempCacheSize;
    } catch (e) {
      AppLogger.error('扫描缓存失败', error: e);
    }
    if (mounted) setState(() => _scanning = false);
  }

  /// 清理进行中：删除大量文件可能耗时数秒，禁用两个清理按钮并转圈，
  /// 避免重复点击并发清理（批次B-F4）
  bool _clearing = false;

  Future<void> _clearTempCache(BuildContext context) async {
    setState(() => _clearing = true);
    try {
      final tempDir = await getTemporaryDirectory();
      var fail = 0;
      if (tempDir.existsSync()) {
        await for (final entity in tempDir.list(recursive: false)) {
          try {
            entity.deleteSync(recursive: true);
          } catch (_) {
            fail++;
          }
        }
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(fail > 0 ? '部分缓存清理失败（$fail 项）' : '临时缓存已清理')));
      }
    } catch (e) {
      AppLogger.error('清理缓存失败', error: e);
    }
    await _scanCache();
    if (mounted) setState(() => _clearing = false);
  }

  Future<void> _clearLogs(BuildContext context) async {
    setState(() => _clearing = true);
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final logDir = Directory('${appDocDir.path}/logs');
      var fail = 0;
      if (logDir.existsSync()) {
        await for (final entity in logDir.list(recursive: false)) {
          try {
            entity.deleteSync();
          } catch (_) {
            fail++;
          }
        }
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(fail > 0 ? '部分日志清理失败（$fail 项）' : '日志已清理')));
      }
    } catch (e) {
      AppLogger.error('清理日志失败', error: e);
    }
    await _scanCache();
    if (mounted) setState(() => _clearing = false);
  }

  @override
  Widget build(BuildContext context) {
    final total = _imageCacheSize + _logSize;
    return Scaffold(
      appBar: AppBar(title: const Text('缓存管理')),
      body: _scanning
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '总占用：${_formatSize(total)}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.image, color: Colors.blue),
                  title: const Text('临时缓存（图片/缩略图/下载）'),
                  subtitle: Text(_formatSize(_imageCacheSize)),
                  trailing: TextButton(
                    onPressed:
                        _clearing ? null : () => _clearTempCache(context),
                    child: _clearing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('清理'),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.bug_report, color: Colors.orange),
                  title: const Text('日志文件'),
                  subtitle: Text(_formatSize(_logSize)),
                  trailing: TextButton(
                    onPressed: _clearing ? null : () => _clearLogs(context),
                    child: _clearing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('清理'),
                  ),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '清理缓存不会影响登录状态和播放记录。图片缓存清理后，下次浏览时会重新加载。',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
    );
  }
}
