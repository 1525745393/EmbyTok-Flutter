// 性能调试工具：内存读数、PerformanceOverlay 开关

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class PerformanceDebugPage extends StatefulWidget {
  const PerformanceDebugPage({super.key});

  @override
  State<PerformanceDebugPage> createState() => _PerformanceDebugPageState();
}

class _PerformanceDebugPageState extends State<PerformanceDebugPage> {
  bool _showOverlay = false;
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
          SwitchListTile(
            secondary: const Icon(Icons.speed),
            title: const Text('PerformanceOverlay'),
            subtitle: const Text('开启渲染性能浮层（FPS/绘制）'),
            value: _showOverlay,
            onChanged: (v) => setState(() => _showOverlay = v),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '提示：开启 PerformanceOverlay 后返回上一页即可看到浮层。\n'
              '网格线表示耗时（绿色=正常，红色=掉帧）。',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ],
      ),
      floatingActionButton: _showOverlay
          ? null
          : FloatingActionButton(
              onPressed: _refresh,
              child: const Icon(Icons.refresh),
            ),
    );
  }
}

class FlutterMemory {
  final double rssMB;
  FlutterMemory({required this.rssMB});
}
