// 沙盒文件浏览器：从应用文档目录开始遍历，查看缓存/日志文件

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class SandboxBrowserPage extends StatefulWidget {
  const SandboxBrowserPage({super.key});

  @override
  State<SandboxBrowserPage> createState() => _SandboxBrowserPageState();
}

class _SandboxBrowserPageState extends State<SandboxBrowserPage> {
  List<FileSystemEntity> _entries = [];
  Directory? _currentDir;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _openDir(null);
  }

  Future<void> _openDir(Directory? dir) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _currentDir = dir ?? await getApplicationDocumentsDirectory();
      final list = await _currentDir!.list().toList();
      list.sort((a, b) {
        final aIsDir = a is Directory ? 0 : 1;
        final bIsDir = b is Directory ? 0 : 1;
        if (aIsDir != bIsDir) return aIsDir - bIsDir;
        return a.path.split('/').last.compareTo(b.path.split('/').last);
      });
      if (mounted) {
        setState(() {
          _entries = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentDir?.path.split('/').last ?? '沙盒浏览器'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('错误: $_error'))
              : ListView.builder(
                  itemCount: _entries.length,
                  itemBuilder: (_, i) {
                    final e = _entries[i];
                    final name = e.path.split('/').last;
                    final isDir = e is Directory;
                    return ListTile(
                      leading: Icon(isDir ? Icons.folder : Icons.insert_drive_file),
                      title: Text(name, style: const TextStyle(fontSize: 13)),
                      subtitle: isDir
                          ? null
                          : FutureBuilder<int>(
                              future: (e as File).length(),
                              builder: (_, s) => Text(
                                s.hasData ? _formatSize(s.data!) : '...',
                                style: const TextStyle(fontSize: 10),
                              ),
                            ),
                      onTap: isDir ? () => _openDir(e) : null,
                    );
                  },
                ),
    );
  }
}
