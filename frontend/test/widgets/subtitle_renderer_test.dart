// SubtitleRenderer 测试：验证字幕渲染和 SRT 解析
// 注意：不重写私有方法 _load / _persist，改为在 setUp 中设置 SharedPreferences mock

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:embbytok_flutter/widgets/subtitle_renderer.dart';
import 'package:embbytok_flutter/providers/subtitle_settings_provider.dart';
import 'package:embbytok_flutter/utils/constants.dart';

void main() {
  setUp(() {
    // 清空 SharedPreferences mock，每个测试从干净状态开始
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('SubtitleRenderer Widget', () {
    /// 创建测试用 ProviderContainer（使用真实的 SubtitleSettingsNotifier）
    /// 通过 SharedPreferences mock 控制初始化状态
    Future<ProviderContainer> createContainer({
      required bool enabled,
      String language = 'zh',
    }) async {
      if (enabled) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          kStorageKeySubtitle,
          '{"language":"$language","size":"medium","color":"white","position":"bottom"}',
        );
      }
      return ProviderContainer();
    }

    testWidgets('空字幕列表时不显示任何文本', (WidgetTester tester) async {
      final container = await createContainer(enabled: true);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SubtitleRenderer(
                position: Duration.zero,
                cues: <SubtitleCue>[],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(SizedBox), findsAtLeastNWidgets(1));
      expect(find.byType(Text), findsNothing);

      container.dispose();
    });

    testWidgets('enabled=false 时不显示字幕', (WidgetTester tester) async {
      final container = await createContainer(enabled: true);
      final cues = <SubtitleCue>[
        const SubtitleCue(Duration.zero, Duration(seconds: 5), '测试字幕'),
      ];

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SubtitleRenderer(
                position: const Duration(seconds: 2),
                cues: cues,
                enabled: false,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(SizedBox), findsAtLeastNWidgets(1));
      expect(find.text('测试字幕'), findsNothing);

      container.dispose();
    });

    testWidgets('字幕设置禁用（language 为空）时不显示', (WidgetTester tester) async {
      // language 为空 => SubtitleSettings.enabled 返回 false
      final container = ProviderContainer();

      final cues = <SubtitleCue>[
        const SubtitleCue(Duration.zero, Duration(seconds: 5), '测试字幕'),
      ];

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SubtitleRenderer(
                position: const Duration(seconds: 2),
                cues: cues,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(SizedBox), findsAtLeastNWidgets(1));
      expect(find.text('测试字幕'), findsNothing);

      container.dispose();
    });

    testWidgets('当前时间的字幕正确显示', (WidgetTester tester) async {
      final container = await createContainer(enabled: true);

      final cues = <SubtitleCue>[
        const SubtitleCue(Duration.zero, Duration(seconds: 5), '这是第一句字幕'),
        const SubtitleCue(Duration(seconds: 5), Duration(seconds: 10), '这是第二句字幕'),
      ];

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SubtitleRenderer(
                position: const Duration(seconds: 2),
                cues: cues,
              ),
            ),
          ),
        ),
      );

      expect(find.text('这是第一句字幕'), findsOneWidget);
      expect(find.text('这是第二句字幕'), findsNothing);

      container.dispose();
    });

    testWidgets('不同时间点显示对应字幕', (WidgetTester tester) async {
      final container = await createContainer(enabled: true);

      final cues = <SubtitleCue>[
        const SubtitleCue(Duration.zero, Duration(seconds: 5), '字幕A'),
        const SubtitleCue(Duration(seconds: 5), Duration(seconds: 10), '字幕B'),
        const SubtitleCue(Duration(seconds: 10), Duration(seconds: 15), '字幕C'),
      ];

      // 时间点 1：显示字幕A
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SubtitleRenderer(
                position: const Duration(seconds: 3),
                cues: cues,
              ),
            ),
          ),
        ),
      );
      expect(find.text('字幕A'), findsOneWidget);

      // 时间点 2：显示字幕B
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SubtitleRenderer(
                position: const Duration(seconds: 7),
                cues: cues,
              ),
            ),
          ),
        ),
      );
      expect(find.text('字幕B'), findsOneWidget);

      // 时间点 3：显示字幕C
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SubtitleRenderer(
                position: const Duration(seconds: 12),
                cues: cues,
              ),
            ),
          ),
        ),
      );
      expect(find.text('字幕C'), findsOneWidget);

      container.dispose();
    });

    testWidgets('当前时间没有匹配字幕时不显示任何文本', (WidgetTester tester) async {
      final container = await createContainer(enabled: true);

      final cues = <SubtitleCue>[
        const SubtitleCue(Duration.zero, Duration(seconds: 5), '早期字幕'),
        const SubtitleCue(Duration(seconds: 20), Duration(seconds: 25), '后期字幕'),
      ];

      // 时间点在两段字幕之间的空白期
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SubtitleRenderer(
                position: const Duration(seconds: 10),
                cues: cues,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(SizedBox), findsAtLeastNWidgets(1));
      expect(find.text('早期字幕'), findsNothing);
      expect(find.text('后期字幕'), findsNothing);

      container.dispose();
    });

    testWidgets('字幕有正确的容器样式（Container + IgnorePointer）', (WidgetTester tester) async {
      final container = await createContainer(enabled: true);

      final cues = <SubtitleCue>[
        const SubtitleCue(Duration.zero, Duration(seconds: 5), '样式测试'),
      ];

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SubtitleRenderer(
                position: const Duration(seconds: 2),
                cues: cues,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Container), findsWidgets);
      expect(find.byType(IgnorePointer), findsOneWidget);

      container.dispose();
    });

    testWidgets('字幕使用设置的颜色（黄色）', (WidgetTester tester) async {
      // 通过 SharedPreferences 设置黄色字幕
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        kStorageKeySubtitle,
        '{"language":"zh","size":"medium","color":"yellow","position":"bottom"}',
      );

      final container = ProviderContainer();

      final cues = <SubtitleCue>[
        const SubtitleCue(Duration.zero, Duration(seconds: 5), '颜色测试'),
      ];

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SubtitleRenderer(
                position: const Duration(seconds: 2),
                cues: cues,
              ),
            ),
          ),
        ),
      );

      final textWidget = tester.widget<Text>(find.text('颜色测试'));
      expect(textWidget.style?.color, const Color(0xFFFFFF00));

      container.dispose();
    });

    testWidgets('字幕使用设置的字号（large）', (WidgetTester tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        kStorageKeySubtitle,
        '{"language":"zh","size":"large","color":"white","position":"bottom"}',
      );
      final container = ProviderContainer();

      final cues = <SubtitleCue>[
        const SubtitleCue(Duration.zero, Duration(seconds: 5), '字号测试'),
      ];

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SubtitleRenderer(
                position: const Duration(seconds: 2),
                cues: cues,
              ),
            ),
          ),
        ),
      );

      final textWidget = tester.widget<Text>(find.text('字号测试'));
      expect(textWidget.style?.fontSize, 24.0);

      container.dispose();
    });
  });

  // ============================
  // parseSrt 函数测试
  // ============================
  group('parseSrt 函数', () {
    test('正确解析 SRT 格式字幕', () {
      const srtContent = '''1
00:00:01,000 --> 00:00:04,000
第一句字幕

2
00:00:05,000 --> 00:00:08,000
第二句字幕
''';

      final cues = parseSrt(srtContent);

      expect(cues.length, 2);
      expect(cues[0].start, const Duration(seconds: 1));
      expect(cues[0].end, const Duration(seconds: 4));
      expect(cues[0].text, '第一句字幕');
      expect(cues[1].start, const Duration(seconds: 5));
      expect(cues[1].end, const Duration(seconds: 8));
      expect(cues[1].text, '第二句字幕');
    });

    test('空内容返回空列表', () {
      expect(parseSrt(''), isEmpty);
    });

    test('正确解析多行字幕文本', () {
      const srtContent = '''1
00:00:01,000 --> 00:00:04,000
第一行
第二行
''';

      final cues = parseSrt(srtContent);

      expect(cues.length, 1);
      expect(cues[0].text, '第一行\n第二行');
    });

    test('正确解析毫秒级时间', () {
      const srtContent = '''1
00:01:23,456 --> 00:01:26,789
测试字幕
''';

      final cues = parseSrt(srtContent);

      expect(cues.length, 1);
      expect(cues[0].start, const Duration(minutes: 1, seconds: 23, milliseconds: 456));
      expect(cues[0].end, const Duration(minutes: 1, seconds: 26, milliseconds: 789));
    });
  });
}
