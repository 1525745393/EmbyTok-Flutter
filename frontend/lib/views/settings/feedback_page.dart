// 一键反馈与日志上报
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../utils/logger.dart';

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final _controller = TextEditingController();
  bool _includeLogs = true;
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit(BuildContext context) async {
    if (_controller.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请描述遇到的问题')));
      return;
    }
    setState(() => _sending = true);
    try {
      final logs = _includeLogs
          ? await AppLogger.readRecentLogs(limit: 200)
          : const <String>[];
      final buffer = StringBuffer();
      buffer.writeln('=== EmbyTok 反馈 ===');
      buffer.writeln('问题描述：');
      buffer.writeln(_controller.text.trim());
      buffer.writeln('');
      if (logs.isNotEmpty) {
        buffer.writeln('=== 最近日志（已脱敏）===');
        buffer.writeln(logs.join('\n'));
      }

      await SharePlus.instance.share(ShareParams(
        text: buffer.toString(),
        subject: 'EmbyTok 反馈',
      ));

      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('已生成反馈内容，请通过邮件发送')));
        Navigator.pop(context);
      }
    } catch (e) {
      AppLogger.error('提交反馈失败', error: e);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('提交失败：$e')));
      }
    }
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('反馈与帮助')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '遇到播放失败、闪退或连接问题？请描述问题，我们会尽快修复。',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText: '请描述遇到的问题（如：播放某影片时闪退、无法连接服务器等）',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('附带最近日志'),
            subtitle: const Text('日志已自动脱敏，不含密码和 Token'),
            value: _includeLogs,
            onChanged: (v) => setState(() => _includeLogs = v),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _sending ? null : () => _submit(context),
              child: _sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('提交反馈'),
            ),
          ),
        ],
      ),
    );
  }
}
