// 日志查看器：复用 AppLogger 读取本地日志，按级别筛选、复制导出

import 'dart:async';

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
  String? _filterTag;
  String _search = '';
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
      _logs = lines.reversed.toList();
      _loading = false;
    });
  }

  List<String> get _filtered {
    return _logs.where((l) {
      if (_filterLevel != null && !l.contains('[${_levelTag(_filterLevel!)}]')) return false;
      if (_filterTag != null && !l.contains('[$_filterTag]')) return false;
      if (_search.isNotEmpty && !l.toLowerCase().contains(_search.toLowerCase())) return false;
      return true;
    }).toList();
  }

  /// 从日志行中提取所有出现过的模块 tag（[network]/[playback] 等）
  List<String> get _availableTags {
    final tags = <String>{};
    for (final l in _logs) {
      final matches = RegExp(r'\[(\w+)\]').allMatches(l);
      for (final m in matches) {
        final t = m.group(1)!;
        // 跳过级别标签
        if (!['DEBUG', 'INFO', 'WARN', 'ERROR', 'Breadcrumb'].contains(t)) {
          tags.add(t);
        }
      }
    }
    return tags.toList()..sort();
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
                await SharePlus.instance.share(ShareParams(files: [XFile(path)]));
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
          // 搜索框
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: TextField(
              decoration: const InputDecoration(
                hintText: '搜索日志内容...',
                prefixIcon: Icon(Icons.search, size: 20),
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          // 级别筛选栏
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
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
          // 模块 tag 筛选
          if (_availableTags.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Row(
                children: [
                  const Text('模块:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: const Text('全部'),
                    selected: _filterTag == null,
                    onSelected: (_) => setState(() => _filterTag = null),
                  ),
                  for (final t in _availableTags) ...[
                    const SizedBox(width: 4),
                    ChoiceChip(
                      label: Text(t),
                      selected: _filterTag == t,
                      onSelected: (_) => setState(() => _filterTag = t),
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
