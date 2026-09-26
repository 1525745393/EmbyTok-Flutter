// 日志查看器：复用 AppLogger 读取本地日志，按级别筛选、复制导出

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../utils/logger.dart';

/// 日志查看器子页面
class LogViewerPage extends StatefulWidget {
  const LogViewerPage({super.key});

  @override
  State<LogViewerPage> createState() => _LogViewerPageState();
}

class _LogViewerPageState extends State<LogViewerPage> {
  LogLevel? _filterLevel;
  List<String> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final lines = await AppLogger.readRecentLogs(limit: 500);
    if (!mounted) return;
    setState(() {
      _logs = lines.reversed.toList(); // 最新在前
      _loading = false;
    });
  }

  List<String> get _filtered {
    if (_filterLevel == null) return _logs;
    final tag = _levelTag(_filterLevel!);
    return _logs.where((l) => l.contains('[$tag]')).toList();
  }

  String _levelTag(LogLevel level) => switch (level) {
        LogLevel.debug => 'DEBUG',
        LogLevel.info => 'INFO',
        LogLevel.warn => 'WARN',
        LogLevel.error => 'ERROR',
      };

  Color _levelColor(String line) {
    if (line.contains('[ERROR]')) return Colors.red;
    if (line.contains('[WARN]')) return Colors.orange;
    if (line.contains('[INFO]')) return Colors.blue;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: const Text('日志查看器'),
        actions: [
          IconButton(
            tooltip: '复制全部',
            icon: const Icon(Icons.copy),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: filtered.join('\n')));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已复制到剪贴板')),
                );
              }
            },
          ),
          IconButton(
            tooltip: '导出文件',
            icon: const Icon(Icons.share),
            onPressed: () async {
              final path = await AppLogger.getLogFilePath();
              if (path != null) {
                await Share.shareXFiles([XFile(path)]);
              }
            },
          ),
          IconButton(
            tooltip: '清空日志',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('清空日志？'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('取消')),
                    TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('清空')),
                  ],
                ),
              );
              if (ok == true) {
                await AppLogger.clearLogs();
                _reload();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 级别筛选栏
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('全部'),
                  selected: _filterLevel == null,
                  onSelected: (_) => setState(() => _filterLevel = null),
                ),
                for (final l in LogLevel.values) ...[
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: Text(_levelTag(l)),
                    selected: _filterLevel == l,
                    onSelected: (_) => setState(() => _filterLevel = l),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? const Center(child: Text('暂无日志'))
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => Container(
                          color: _levelColor(filtered[i]).withValues(alpha: 0.05),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          child: Text(
                            filtered[i],
                            style: const TextStyle(
                                fontSize: 11, fontFamily: 'monospace'),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
