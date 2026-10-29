// 性能调试工具：内存读数、PerformanceOverlay 开关

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

class PerformanceDebugPage extends StatefulWidget {
  const PerformanceDebugPage({super.key});

  @override
  State<PerformanceDebugPage> createState() => _PerformanceDebugPageState();
}

class _PerformanceDebugPageState extends State<PerformanceDebugPage> {
  // 性能浮层由主界面 AppPerformanceOverlay 的右下角悬浮按钮控制（batch153-F4）
  FlutterMemory? _mem;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    final info = ProcessInfo.currentRss;
    setState(() {
      _mem = FlutterMemory(
        rssMB: info / (1024 * 1024),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('性能调试工具')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.memory),
            title: const Text('当前 RSS 内存占用'),
            subtitle: Text(_mem == null
                ? '读取中...'
                : '${_mem!.rssMB.toStringAsFixed(1)} MB'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.speed),
            title: const Text('性能监控浮层'),
            subtitle: const Text('由主界面右下角悬浮按钮切换显示'),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '返回主界面后点击右下角悬浮按钮可显示/隐藏性能浮层\n'
              '（内存/FPS/重建次数/API 请求），可拖拽移动。',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _refresh,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}

class FlutterMemory {
  FlutterMemory({required this.rssMB});
  final double rssMB;
}
