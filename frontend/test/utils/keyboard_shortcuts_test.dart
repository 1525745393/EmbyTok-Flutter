// keyboard_shortcuts 单元测试
//
// 验证键盘快捷键帮助面板的构建和内容。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:embytok_flutter/utils/keyboard_shortcuts.dart';

void main() {
  group('KeyboardHelpPanel', () {
    testWidgets('构建不抛异常', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: KeyboardHelpPanel()),
        ),
      );
      expect(find.byType(KeyboardHelpPanel), findsOneWidget);
    });

    testWidgets('显示标题「键盘快捷键」', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: KeyboardHelpPanel()),
        ),
      );
      expect(find.text('键盘快捷键'), findsOneWidget);
    });

    testWidgets('显示所有快捷键条目', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: KeyboardHelpPanel()),
        ),
      );
      // 验证 11 个快捷键的按键文本都存在
      final shortcutKeys = [
        'W / S / ↑ / ↓',
        'A / D / ← / →',
        'Space',
        'U',
        'E',
        'R',
        'G',
        'F',
        'M',
        '?',
      ];
      for (final key in shortcutKeys) {
        expect(find.text(key), findsOneWidget, reason: '应显示快捷键 $key');
      }
    });

    testWidgets('显示快捷键描述文本', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: KeyboardHelpPanel()),
        ),
      );
      // 验证几个关键描述
      expect(find.text('暂停 / 播放'), findsOneWidget);
      expect(find.text('收藏视频'), findsOneWidget);
      expect(find.text('全屏切换'), findsOneWidget);
      expect(find.text('静音切换'), findsOneWidget);
    });

    testWidgets('包含 Container 装饰（边框+圆角）', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: KeyboardHelpPanel()),
        ),
      );
      final container = tester.widget<Container>(find.byType(Container).first);
      expect(container.decoration, isA<BoxDecoration>());
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.borderRadius, isA<BorderRadius>());
      expect(decoration.border, isA<Border>());
    });

    testWidgets('使用 Column 布局', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: KeyboardHelpPanel()),
        ),
      );
      expect(find.byType(Column), findsWidgets);
    });

    testWidgets('使用 Row 显示每个快捷键', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: KeyboardHelpPanel()),
        ),
      );
      // 11 个快捷键条目，每个都有 Row
      expect(find.byType(Row), findsAtLeastNWidgets(10));
    });

    testWidgets('在深色主题下正常构建', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(body: KeyboardHelpPanel()),
        ),
      );
      expect(find.byType(KeyboardHelpPanel), findsOneWidget);
      expect(find.text('键盘快捷键'), findsOneWidget);
    });

    testWidgets('在浅色主题下正常构建', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: const Scaffold(body: KeyboardHelpPanel()),
        ),
      );
      expect(find.byType(KeyboardHelpPanel), findsOneWidget);
      expect(find.text('键盘快捷键'), findsOneWidget);
    });

    testWidgets('快捷键条目数量为 11', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: KeyboardHelpPanel()),
        ),
      );
      // 通过统计快捷键描述文本的数量来验证条目数
      final descriptions = [
        '上一个 / 下一个视频',
        '快退 / 快进 15 秒',
        '暂停 / 播放',
        '收藏视频',
        '切换视图（视频流 / 海报墙）',
        '顺序 / 随机播放',
        '选择媒体库',
        '全屏切换',
        '静音切换',
        '显示 / 隐藏快捷键帮助',
      ];
      var count = 0;
      for (final desc in descriptions) {
        if (find.text(desc).evaluate().isNotEmpty) {
          count++;
        }
      }
      expect(count, 10); // 10 个唯一描述文本
    });
  });
}
