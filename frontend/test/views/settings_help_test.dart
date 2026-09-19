/// 设置页帮助按钮测试
///
/// 验证：
/// - 设置项渲染帮助按钮（Icons.help_outline）
/// - 点击帮助按钮弹出帮助弹层（标题 + 详细说明）
/// - 帮助弹层可关闭
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:embytok_flutter/views/settings_view.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  Widget wrap() {
    // 使用 Material 2 主题：规避 Flutter 3.47.2 已知的
    // M3 InkSparkle shader（ink_sparkle.frag）测试环境解码缺陷
    return ProviderScope(
      child: MaterialApp(
        theme: ThemeData(useMaterial3: false),
        home: const SettingsView(),
      ),
    );
  }

  /// 滚动到目标文本可见
  Future<void> scrollToText(WidgetTester tester, String target) async {
    final scrollable = find.byType(Scrollable).first;
    await tester.drag(scrollable, const Offset(0, 5000));
    await tester.pumpAndSettle();
    for (int i = 0; i < 80 && find.text(target).evaluate().isEmpty; i++) {
      await tester.drag(scrollable, const Offset(0, -400));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('设置项显示帮助按钮，点击弹出帮助并关闭', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // 定位「重置设置」设置项
    await scrollToText(tester, '重置设置');
    expect(find.text('重置设置'), findsWidgets);

    // 该 tile 上应存在帮助按钮
    final resetTile = find.ancestor(
      of: find.text('重置设置').first,
      matching: find.byType(ListTile),
    );
    final helpBtn = find.descendant(
      of: resetTile,
      matching: find.byIcon(Icons.help_outline),
    );
    expect(helpBtn, findsOneWidget);

    // 确保可点击并点击
    await tester.ensureVisible(helpBtn);
    await tester.pumpAndSettle();
    await tester.tap(helpBtn, warnIfMissed: false);
    await tester.pumpAndSettle();

    // 弹层出现：包含详细帮助内容
    expect(find.textContaining('恢复为默认值'), findsWidgets);

    // 关闭按钮可关闭弹层
    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('恢复为默认值'), findsNothing);
  });

  testWidgets('开关型设置项也带帮助按钮', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // 定位「排除已观看」开关项（视频流分区第一个）
    await scrollToText(tester, '排除已观看');
    final tiles = find.ancestor(
      of: find.text('排除已观看').first,
      matching: find.byType(ListTile),
    );
    final helpBtn = find.descendant(
      of: tiles.first,
      matching: find.byIcon(Icons.help_outline),
    );
    expect(helpBtn, findsOneWidget);

    await tester.ensureVisible(helpBtn);
    await tester.pumpAndSettle();
    await tester.tap(helpBtn, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.textContaining('已观看'), findsWidgets);

    // 关闭
    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();
  });
}
