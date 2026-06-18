import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:embbytok_flutter/widgets/subtitle_renderer.dart';
import 'package:embbytok_flutter/providers/subtitle_settings_provider.dart';

void main() {
  group('SubtitleRenderer Widget', () {
    /// 创建测试用的 ProviderContainer
    ProviderContainer createContainer({
      SubtitleSettings settings = const SubtitleSettings(),
    }) {
      return ProviderContainer(
        overrides: [
          subtitleSettingsProvider.overrideWith(
            (ref) => TestSubtitleSettingsNotifier(settings),
          ),
        ],
      );
    }

    /// 测试空字幕时不显示
    testWidgets('空字幕列表时不显示任何内容', (WidgetTester tester) async {
      final container = createContainer(
        settings: const SubtitleSettings(language: 'zh'),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SubtitleRenderer(
                position: Duration.zero,
                cues: [],
              ),
            ),
          ),
        ),
      );

      // 应该返回 SizedBox.shrink
      expect(find.byType(SizedBox), findsOneWidget);
      expect(find.byType(Text), findsNothing);

      container.dispose();
    });

    /// 测试 enabled=false 时不显示
    testWidgets('enabled=false 时不显示字幕', (WidgetTester tester) async {
      final container = createContainer(
        settings: const SubtitleSettings(language: 'zh'),
      );

      final cues = [
        const SubtitleCue(
          Duration(seconds: 0),
          Duration(seconds: 5),
          '测试字幕',
        ),
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

      // 应该返回 SizedBox.shrink
      expect(find.byType(SizedBox), findsOneWidget);
      expect(find.text('测试字幕'), findsNothing);

      container.dispose();
    });

    /// 测试字幕设置禁用时不显示
    testWidgets('字幕设置禁用（language为空）时不显示', (WidgetTester tester) async {
      final container = createContainer(
        settings: const SubtitleSettings(language: ''), // 空语言表示禁用
      );

      final cues = [
        const SubtitleCue(
          Duration(seconds: 0),
          Duration(seconds: 5),
          '测试字幕',
        ),
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

      // 应该返回 SizedBox.shrink
      expect(find.byType(SizedBox), findsOneWidget);
      expect(find.text('测试字幕'), findsNothing);

      container.dispose();
    });

    /// 测试字幕文本正确显示
    testWidgets('当前时间的字幕正确显示', (WidgetTester tester) async {
      final container = createContainer(
        settings: const SubtitleSettings(language: 'zh'),
      );

      final cues = [
        const SubtitleCue(
          Duration(seconds: 0),
          Duration(seconds: 5),
          '这是第一句字幕',
        ),
        const SubtitleCue(
          Duration(seconds: 5),
          Duration(seconds: 10),
          '这是第二句字幕',
        ),
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

      // 应该显示第一句字幕
      expect(find.text('这是第一句字幕'), findsOneWidget);
      expect(find.text('这是第二句字幕'), findsNothing);

      container.dispose();
    });

    /// 测试不同时间点显示不同字幕
    testWidgets('不同时间点显示对应字幕', (WidgetTester tester) async {
      final container = createContainer(
        settings: const SubtitleSettings(language: 'zh'),
      );

      final cues = [
        const SubtitleCue(
          Duration(seconds: 0),
          Duration(seconds: 5),
          '字幕A',
        ),
        const SubtitleCue(
          Duration(seconds: 5),
          Duration(seconds: 10),
          '字幕B',
        ),
        const SubtitleCue(
          Duration(seconds: 10),
          Duration(seconds: 15),
          '字幕C',
        ),
      ];

      // 测试时间点 1：应该显示字幕A
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

      // 测试时间点 2：应该显示字幕B
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

      // 测试时间点 3：应该显示字幕C
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

    /// 测试没有匹配的字幕时不显示
    testWidgets('当前时间没有匹配字幕时不显示', (WidgetTester tester) async {
      final container = createContainer(
        settings: const SubtitleSettings(language: 'zh'),
      );

      final cues = [
        const SubtitleCue(
          Duration(seconds: 0),
          Duration(seconds: 5),
          '早期字幕',
        ),
        const SubtitleCue(
          Duration(seconds: 20),
          Duration(seconds: 25),
          '后期字幕',
        ),
      ];

      // 时间点在两个字幕之间的空白期
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

      // 应该返回 SizedBox.shrink
      expect(find.byType(SizedBox), findsOneWidget);
      expect(find.text('早期字幕'), findsNothing);
      expect(find.text('后期字幕'), findsNothing);

      container.dispose();
    });

    /// 测试字幕容器样式
    testWidgets('字幕有正确的容器样式', (WidgetTester tester) async {
      final container = createContainer(
        settings: const SubtitleSettings(language: 'zh'),
      );

      final cues = [
        const SubtitleCue(
          Duration(seconds: 0),
          Duration(seconds: 5),
          '样式测试',
        ),
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

      // 验证 Container 存在
      expect(find.byType(Container), findsWidgets);

      // 验证 IgnorePointer 存在（字幕不应拦截触摸）
      expect(find.byType(IgnorePointer), findsWidgets); // 可能有多个

      container.dispose();
    });

    /// 测试字幕设置颜色
    testWidgets('字幕使用设置的颜色', (WidgetTester tester) async {
      final container = createContainer(
        settings: const SubtitleSettings(
          language: 'zh',
          color: 'yellow',
        ),
      );

      final cues = [
        const SubtitleCue(
          Duration(seconds: 0),
          Duration(seconds: 5),
          '颜色测试',
        ),
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

    /// 测试字幕设置字号
    testWidgets('字幕使用设置的字号', (WidgetTester tester) async {
      final container = createContainer(
        settings: const SubtitleSettings(
          language: 'zh',
          size: 'large',
        ),
      );

      final cues = [
        const SubtitleCue(
          Duration(seconds: 0),
          Duration(seconds: 5),
          '字号测试',
        ),
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

  group('parseSrt 函数', () {
    /// 测试 SRT 解析
    test('正确解析 SRT 格式字幕', () {
      const srtContent = '''
1
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

    /// 测试空内容
    test('空内容返回空列表', () {
      expect(parseSrt(''), isEmpty);
    });

    /// 测试多行字幕
    test('正确解析多行字幕文本', () {
      const srtContent = '''
1
00:00:01,000 --> 00:00:04,000
第一行
第二行
''';

      final cues = parseSrt(srtContent);

      expect(cues.length, 1);
      expect(cues[0].text, '第一行\n第二行');
    });

    /// 测试时间格式解析（毫秒）
    test('正确解析毫秒级时间', () {
      const srtContent = '''
1
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

/// 测试用的字幕设置 Notifier（扩展自 SubtitleSettingsNotifier）
class TestSubtitleSettingsNotifier extends SubtitleSettingsNotifier {
  TestSubtitleSettingsNotifier(SubtitleSettings initialSettings) {
    state = initialSettings;
  }
}
