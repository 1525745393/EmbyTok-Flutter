/// 网络诊断页「dispose 后 setState」回归测试
///
/// 背景（本分片 UI 审查发现）：
/// - 修复前：`_runDiagnostics()` 在 `await Connectivity().checkConnectivity()` 之后，
///   三个提前 return 分支（未配置服务器 / local:// 本地库 / 地址解析失败）都直接
///   `setState(() => _running = false)` 收尾，未先判断 mounted。
/// - 复现：用户点「开始诊断」后、连接检测异步结果回来前按返回键离开页面，
///   continuation 在已 dispose 的 State 上调用 setState → FlutterError。
/// - 修复后：连接检测 await 之后统一 `if (!mounted) return;`，与方法末尾
///   已有的 `if (mounted) setState(...)` 收尾保持一致。
///
/// 测试策略：用受控 mock 让 connectivity_plus 的「check」方法返回一个 pending
/// Completer，从而精确控制时序——先触发诊断（await 挂起），再卸载页面，最后才
/// 完成 Completer，使 continuation 必然运行在已 dispose 的 State 上。
/// 若修复缺失，pump 会抛出 "setState() called after dispose()"。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:embytok_flutter/views/settings/network_diagnostic_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const connectivityChannel =
      MethodChannel('dev.fluttercommunity.plus/connectivity');

  testWidgets('诊断进行中离开页面：不在已 dispose 的 State 上 setState',
      (tester) async {
    // 受控 mock：「check」挂起在我们的 Completer 上，不立即返回。
    final connectivityResult = Completer<String>();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      connectivityChannel,
      (call) {
        if (call.method == 'check') return connectivityResult.future;
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(connectivityChannel, null));

    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: NetworkDiagnosticPage(serverUrl: '')),
    ));
    await tester.pump(); // 首帧

    // 触发诊断：内部 await Connectivity().checkConnectivity() 正挂在 Completer 上。
    await tester.tap(find.text('开始诊断'));
    await tester.pump();

    // 连接检测仍 pending 时卸载页面（模拟用户按返回）。
    await tester.pumpWidget(const SizedBox());
    await tester.pump();

    // 连接检测结果返回：continuation 在已 dispose 的 State 上运行。
    // 旧实现会在未配置服务器分支里 setState(_running=false) 而抛异常；
    // 修复后连接 await 之后直接 if (!mounted) return。
    connectivityResult.complete('wifi');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 走到这里未抛出即通过。
  });
}
