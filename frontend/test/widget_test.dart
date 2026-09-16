import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:embytok_flutter/app.dart';

void main() {
  testWidgets('app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: EmbyTokApp()));
    expect(find.byType(MaterialApp), findsOneWidget);

    // 卸载 App，触发组件链 dispose，清理后台 Timer
    // 再推进虚拟时间让一次性 Timer 全部到期
    // （否则测试结束时的 !timersPending 断言会失败）
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}
