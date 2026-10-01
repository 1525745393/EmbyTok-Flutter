import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/file_source.dart';
import '../../models/local_video_item.dart';
import '../../services/webdav_scanner.dart';

/// 源内浏览页（P1 第三批）
///
/// 扫描文件源并列出视频，点击进入播放。
class FileSourceBrowseView extends ConsumerStatefulWidget {
  final FileSource source;
  const FileSourceBrowseView({super.key, required this.source});

  @override
  ConsumerState<FileSourceBrowseView> createState() => _FileSourceBrowseViewState();
}

class _FileSourceBrowseViewState extends ConsumerState<FileSourceBrowseView> {
  List<LocalVideoItem> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final scanner = WebdavScanner();
      final items = await scanner.scan(widget.source);
      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.source.name),
        actions: [
          IconButton(onPressed: _scan, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('扫描失败: $_error'))
              : _items.isEmpty
                  ? const Center(child: Text('未找到视频文件'))
                  : ListView.separated(
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) => ListTile(
                        leading: const Icon(Icons.movie_outlined),
                        title: Text(_items[i].name),
                        subtitle: Text(_items[i].sizeLabel),
                        onTap: () {
                          // TODO: P2 接入播放器
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('播放: ${_items[i].name}')),
                          );
                        },
                      ),
                    ),
    );
  }
}
