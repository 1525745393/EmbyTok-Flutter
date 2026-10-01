import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/file_source.dart';
import '../../providers/file_sources_provider.dart';

/// 文件源添加/编辑表单（P0 第二批）
///
/// WebDAV：URL / 用户名 / 密码。SMB：主机/端口/共享/用户名/密码。
class FileSourceEditView extends ConsumerStatefulWidget {
  final FileSourceType? type;
  final FileSource? existing;

  const FileSourceEditView({super.key, this.type, this.existing});

  @override
  ConsumerState<FileSourceEditView> createState() => _FileSourceEditViewState();
}

class _FileSourceEditViewState extends ConsumerState<FileSourceEditView> {
  late final TextEditingController _name;
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _share;
  late final TextEditingController _url;
  late final TextEditingController _user;
  late final TextEditingController _password;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _host = TextEditingController(text: e?.config['host'] ?? '');
    _port = TextEditingController(text: e?.config['port'] ?? '445');
    _share = TextEditingController(text: e?.config['share'] ?? '');
    _url = TextEditingController(text: e?.config['url'] ?? '');
    _user = TextEditingController(text: e?.config['username'] ?? '');
    _password = TextEditingController(text: e?.config['password'] ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _host.dispose();
    _port.dispose();
    _share.dispose();
    _url.dispose();
    _user.dispose();
    _password.dispose();
    super.dispose();
  }

  FileSourceType get _type => widget.existing?.type ?? widget.type!;

  @override
  Widget build(BuildContext context) {
    final isWebdav = _type == FileSourceType.webdav;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? '添加文件源' : '编辑文件源'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: '名称',
              hintText: '如：家里 NAS',
            ),
          ),
          const SizedBox(height: 12),
          if (isWebdav)
            TextField(
              controller: _url,
              decoration: const InputDecoration(
                labelText: 'WebDAV 地址',
                hintText: 'https://dav.example.com/dav/',
              ),
            )
          else ...[
            TextField(
              controller: _host,
              decoration: const InputDecoration(
                labelText: '主机地址',
                hintText: '192.168.1.10',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _port,
              decoration: const InputDecoration(labelText: '端口'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _share,
              decoration: const InputDecoration(
                labelText: '共享名',
                hintText: 'video',
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _user,
            decoration: const InputDecoration(labelText: '用户名'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            decoration: const InputDecoration(labelText: '密码'),
            obscureText: true,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _save,
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _save() {
    final cfg = <String, String>{};
    if (_type == FileSourceType.webdav) {
      cfg['url'] = _url.text.trim();
    } else {
      cfg['host'] = _host.text.trim();
      cfg['port'] = _port.text.trim();
      cfg['share'] = _share.text.trim();
    }
    cfg['username'] = _user.text.trim();
    cfg['password'] = _password.text;

    final notifier = ref.read(fileSourcesProvider.notifier);
    if (widget.existing != null) {
      notifier.update(widget.existing!.copyWith(
        name: _name.text.trim().isEmpty ? widget.existing!.name : _name.text.trim(),
        config: cfg,
      ));
    } else {
      notifier.add(FileSource(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        type: _type,
        name: _name.text.trim().isEmpty ? '未命名源' : _name.text.trim(),
        config: cfg,
      ));
    }
    Navigator.pop(context);
  }
}
