import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/file_source.dart';
import '../../providers/file_sources_provider.dart';
import '../../services/smb_scanner.dart';

/// 文件源添加/编辑表单（P0 第二批）
///
/// WebDAV：URL / 用户名 / 密码。SMB：主机/端口/共享/用户名/密码。
class FileSourceEditView extends ConsumerStatefulWidget {

  const FileSourceEditView({super.key, this.type, this.existing});
  final FileSourceType? type;
  final FileSource? existing;

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
          // SMB 连接测试按钮
          if (!isWebdav)
            OutlinedButton.icon(
              onPressed: _testSmbConnection,
              icon: const Icon(Icons.wifi_tethering),
              label: const Text('测试连接'),
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _save,
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  /// 测试 SMB 连通性（P0 增强）
  Future<void> _testSmbConnection() async {
    final host = _host.text.trim();
    if (host.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先填写主机地址')),
      );
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    final err = await SmbScanner.testConnection(
      host: host,
      port: int.tryParse(_port.text.trim()) ?? 445,
      username: _user.text.trim(),
      password: _password.text,
      share: _share.text.trim(),
    );
    if (!mounted) return;
    Navigator.pop(context); // 关闭 loading
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(err == null ? '连接成功' : '连接失败: $err'),
        backgroundColor: err == null ? Colors.green : Colors.red,
      ),
    );
  }

  void _save() {
    // 校验必填字段
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入名称')));
      return;
    }
    if (_type == FileSourceType.webdav && _url.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入 WebDAV 地址')));
      return;
    }
    if (_type != FileSourceType.webdav && _host.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入主机地址')));
      return;
    }
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
