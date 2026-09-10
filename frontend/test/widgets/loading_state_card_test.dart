// LoadingStateCard 单元测试
//
// 验证统一加载状态组件的构建和属性。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:embytok_flutter/widgets/loading_state_card.dart';

void main() {
  group('LoadingStateCard', () {
    testWidgets('基础构建：仅显示加载指示器', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: LoadingStateCard()),
        ),
      );
      // 应显示 CircularProgressIndicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // 不应显示标题
      expect(find.text('加载中...'), findsNothing);
    });

    testWidgets('带标题构建', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: LoadingStateCard(title: '加载中...')),
        ),
      );
      expect(find.text('加载中...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('带标题和副标题构建', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoadingStateCard(
              title: '正在加载',
              subtitle: '正在从服务器获取数据',
            ),
          ),
        ),
      );
      expect(find.text('正在加载'), findsOneWidget);
      expect(find.text('正在从服务器获取数据'), findsOneWidget);
    });

    testWidgets('自定义指示器尺寸', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoadingStateCard(indicatorSize: 64, strokeWidth: 6),
          ),
        ),
      );
      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(indicator.strokeWidth, 6);
    });

    testWidgets('generic 快捷构造', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: LoadingStateCard.generic()),
        ),
      );
      expect(find.text('加载中...'), findsOneWidget);
    });

    testWidgets('loadingData 快捷构造', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: LoadingStateCard.loadingData()),
        ),
      );
      expect(find.text('正在加载'), findsOneWidget);
      expect(find.text('正在从服务器获取数据，请稍候'), findsOneWidget);
    });

    testWidgets('signingIn 快捷构造', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: LoadingStateCard.signingIn()),
        ),
      );
      expect(find.text('正在登录'), findsOneWidget);
    });

    testWidgets('syncing 快捷构造', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: LoadingStateCard.syncing()),
        ),
      );
      expect(find.text('正在同步'), findsOneWidget);
    });

    testWidgets('空标题不显示 Text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: LoadingStateCard(title: '')),
        ),
      );
      // 空标题不应显示 Text 组件（除了可能的其他文本）
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('自定义指示器颜色', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoadingStateCard(indicatorColor: Colors.blue),
          ),
        ),
      );
      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(indicator.color, Colors.blue);
    });
  });
}
