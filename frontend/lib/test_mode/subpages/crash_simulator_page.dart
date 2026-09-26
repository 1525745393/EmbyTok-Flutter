// 崩溃模拟面板：主动触发各类异常，验证 AppLogger 捕获与 App 不白屏

import 'dart:async';

import 'package:flutter/material.dart';

class CrashSimulatorPage extends StatelessWidget {
  const CrashSimulatorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('崩溃模拟面板')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '主动触发各类异常，验证 FlutterError.onError / runZonedGuarded '
              '是否正确记录到 AppLogger 且 App 不白屏。\n'
              '触发后可在日志查看器中查看 ERROR 级日志。',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.bug_report, color: Colors.red),
            title: const Text('Dart 空指针异常'),
            subtitle: const Text('throw on null'),
            onTap: () {
              try {
                String? nullStr;
                // ignore: unnecessary_null_comparison
                if (nullStr.length == 0) {}
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('已捕获: $e')),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.bug_report, color: Colors.red),
            title: const Text('异步异常（Future.error）'),
            onTap: () {
              Future<void>.error(Exception('测试异步异常'));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已触发异步异常，查看日志')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.bug_report, color: Colors.red),
            title: const Text('Timer 异步异常'),
            onTap: () {
              Timer(const Duration(milliseconds: 100), () {
                throw Exception('Timer 内测试异常');
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('100ms 后触发 Timer 异常')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.bug_report, color: Colors.red),
            title: const Text('同步 throw（不捕获）'),
            subtitle: const Text('验证 FlutterError.onError 捕获'),
            onTap: () {
              throw Exception('同步未捕获异常测试');
            },
          ),
          ListTile(
            leading: const Icon(Icons.memory, color: Colors.orange),
            title: const Text('内存压力模拟'),
            subtitle: const Text('分配大列表后释放'),
            onTap: () {
              final big = List.generate(
                  100000, (i) => 'test string padding $i'.codeUnits);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('已分配 ${big.length} 个列表，即将释放')),
              );
            },
          ),
        ],
      ),
    );
  }
}
