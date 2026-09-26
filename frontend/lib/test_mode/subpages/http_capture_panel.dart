// 网络请求抓包面板：查看 App 发出的所有 HTTP 请求

import 'package:flutter/material.dart';

import '../http_capture_log.dart';

class HttpCapturePanel extends StatefulWidget {
  const HttpCapturePanel({super.key});

  @override
  State<HttpCapturePanel> createState() => _HttpCapturePanelState();
}

class _HttpCapturePanelState extends State<HttpCapturePanel> {
  String? _filter;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('网络抓包'),
        actions: [
          IconButton(
            tooltip: '清空',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => HttpRequestLog.instance.clear(),
          ),
        ],
      ),
      body: Column(
        children: [
          SwitchListTile(
            title: const Text('启用抓包'),
            subtitle: const Text('记录最近 200 条请求'),
            value: HttpRequestLog.instance.enabled,
            onChanged: (v) => setState(() {
              HttpRequestLog.instance.setEnabled(v);
            }),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: const InputDecoration(
                hintText: '按路径筛选...',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _filter = v),
            ),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: HttpRequestLog.instance,
              builder: (context, _) {
                final log = HttpRequestLog.instance;
                final records = _filter == null || _filter!.isEmpty
                    ? log.records
                    : log.records
                        .where((r) => r.path.contains(_filter!))
                        .toList();
                if (records.isEmpty) {
                  return const Center(child: Text('暂无请求记录'));
                }
                return ListView.builder(
                  itemCount: records.length,
                  itemBuilder: (_, i) {
                    final r = records[i];
                    final ok = r.statusCode != null && r.statusCode! < 400;
                    return ListTile(
                      dense: true,
                      leading: Text(
                        r.method,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: ok ? Colors.green : Colors.red,
                        ),
                      ),
                      title:
                          Text(r.path, style: const TextStyle(fontSize: 12)),
                      subtitle: Text(
                        '${r.statusCode ?? 'ERR'} · ${r.durationMs}ms · '
                        '${r.time.hour}:${r.time.minute}:${r.time.second}'
                        '${r.error != null ? ' · ${r.error}' : ''}',
                        style: const TextStyle(fontSize: 10),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
