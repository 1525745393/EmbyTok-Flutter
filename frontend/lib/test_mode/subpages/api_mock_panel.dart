// API Mock 面板 UI：管理 Mock 规则

import 'dart:convert';

import 'package:flutter/material.dart';

import '../api_mock.dart';

class ApiMockPanel extends StatefulWidget {
  const ApiMockPanel({super.key});

  @override
  State<ApiMockPanel> createState() => _ApiMockPanelState();
}

class _ApiMockPanelState extends State<ApiMockPanel> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MockRules.instance,
      builder: (context, _) {
        final rules = MockRules.instance.rules;
        return Scaffold(
          appBar: AppBar(title: const Text('API Mock')),
          body: Column(
            children: [
              SwitchListTile(
                title: const Text('启用 Mock'),
                subtitle: const Text('命中规则的请求直接返回 Mock 数据'),
                value: MockRules.instance.enabled,
                onChanged: (v) => MockRules.instance.setEnabled(v),
              ),
              Expanded(
                child: rules.isEmpty
                    ? const Center(child: Text('暂无 Mock 规则\n点击右下角添加', textAlign: TextAlign.center))
                    : ListView.separated(
                        itemCount: rules.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final r = rules[i];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: r.statusCode < 400
                                  ? Colors.green
                                  : Colors.red,
                              child: Text('${r.statusCode}',
                                  style: const TextStyle(fontSize: 10)),
                            ),
                            title: Text(r.pathPrefix,
                                style: const TextStyle(fontSize: 13)),
                            subtitle: Text(
                              r.body.length > 60
                                  ? '${r.body.substring(0, 60)}...'
                                  : r.body,
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.grey),
                              maxLines: 2,
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              onPressed: () => MockRules.instance.removeAt(i),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showAddDialog(context),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Future<void> _showAddDialog(BuildContext context) async {
    final pathCtrl = TextEditingController(text: '/Items/Latest');
    final codeCtrl = TextEditingController(text: '200');
    final bodyCtrl = TextEditingController(
        text: '[{"Name":"Mock 影片","Id":"mock-1"}]');

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('添加 Mock 规则'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: pathCtrl,
                decoration: const InputDecoration(labelText: '路径包含（如 /Items/Latest）'),
              ),
              TextField(
                controller: codeCtrl,
                decoration: const InputDecoration(labelText: '状态码'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: bodyCtrl,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'JSON 响应体'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              try {
                // 验证 JSON
                jsonDecode(bodyCtrl.text);
                MockRules.instance.add(MockRule(
                  pathPrefix: pathCtrl.text.trim(),
                  statusCode: int.parse(codeCtrl.text.trim()),
                  body: bodyCtrl.text.trim(),
                ));
                Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('JSON 格式错误: $e')),
                );
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }
}
