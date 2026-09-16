// 「上次看到」角标组件渲染测试
//
// 覆盖：默认渲染「上次看到」文案 + 历史图标，样式为红色渐变胶囊。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:embytok_flutter/widgets/last_watched_badge.dart';

void main() {
  testWidgets('渲染「上次看到」角标文案与图标', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LastWatchedBadge(),
        ),
      ),
    );

    expect(find.text('上次看到'), findsOneWidget);
    expect(find.byIcon(Icons.history), findsOneWidget);
  });

  testWidgets('角标使用红色渐变背景（醒目样式）', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LastWatchedBadge(),
        ),
      ),
    );

    final container = tester.widget<Container>(
      find.ancestor(
        of: find.text('上次看到'),
        matching: find.byType(Container),
      ).first,
    );
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.gradient, isNotNull);
    final gradient = decoration.gradient! as LinearGradient;
    expect(gradient.colors.first, const Color(0xFFFF3B30));
  });

  testWidgets('传入进度百分比时显示「上次看到 N%」', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LastWatchedBadge(progressPercent: 45),
        ),
      ),
    );

    expect(find.text('上次看到 45%'), findsOneWidget);
    expect(find.text('上次看到'), findsNothing);
  });
}
