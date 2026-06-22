import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:embbytok_flutter/widgets/heart_animation.dart';

void main() {
  group('HeartAnimation Widget', () {
    /// 测试动画组件正确渲染
    testWidgets('应该正确渲染子组件', (WidgetTester tester) async {
      // 创建测试子组件
      const testChild = Text('测试内容');

      // 构建 widget
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HeartAnimation(
              visible: false,
              child: testChild,
            ),
          ),
        ),
      );

      // 验证子组件被渲染
      expect(find.text('测试内容'), findsOneWidget);
    });

    /// 测试 visible=false 时不显示心形图标
    testWidgets('visible=false 时不显示心形图标', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HeartAnimation(
              visible: false,
              child: Text('子组件'),
            ),
          ),
        ),
      );

      // 不应该找到心形图标
      expect(find.byIcon(Icons.favorite), findsNothing);
    });

    /// 测试 visible=true 时显示心形图标
    testWidgets('visible=true 时显示心形图标并播放动画', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HeartAnimation(
              visible: true,
              child: Text('子组件'),
            ),
          ),
        ),
      );

      // 应该找到心形图标
      expect(find.byIcon(Icons.favorite), findsOneWidget);

      // 验证图标颜色
      final iconWidget = tester.widget<Icon>(find.byIcon(Icons.favorite));
      expect(iconWidget.color, const Color(0xFFFF5983));
      expect(iconWidget.size, 96);
    });

    /// 测试动画从 visible=false 变为 visible=true 时触发
    testWidgets('从不可见变为可见时触发动画', (WidgetTester tester) async {
      // 初始状态：不可见
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HeartAnimation(
              visible: false,
              child: Text('子组件'),
            ),
          ),
        ),
      );

      // 初始状态没有心形图标
      expect(find.byIcon(Icons.favorite), findsNothing);

      // 更新为可见
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HeartAnimation(
              visible: true,
              child: Text('子组件'),
            ),
          ),
        ),
      );

      // 现在应该有心形图标
      expect(find.byIcon(Icons.favorite), findsOneWidget);
    });

    /// 测试动画渐隐效果
    testWidgets('动画播放时透明度从1渐变到0', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HeartAnimation(
              visible: true,
              child: Text('子组件'),
            ),
          ),
        ),
      );

      // 初始状态：opacity 应该是 1.0
      final opacityFinder = find.byType(Opacity);
      expect(opacityFinder, findsOneWidget);

      Opacity opacityWidget = tester.widget<Opacity>(opacityFinder);
      expect(opacityWidget.opacity, 1.0);

      // 推进动画一段时间
      await tester.pump(const Duration(milliseconds: 350));

      // 中间状态：opacity 应该在 0 和 1 之间
      opacityWidget = tester.widget<Opacity>(opacityFinder);
      expect(opacityWidget.opacity, lessThan(1.0));
      expect(opacityWidget.opacity, greaterThan(0.0));

      // 完成动画
      await tester.pump(const Duration(milliseconds: 350));

      // 最终状态：opacity 应该是 0.0
      opacityWidget = tester.widget<Opacity>(opacityFinder);
      expect(opacityWidget.opacity, 0.0);
    });

    /// 测试缩放动画效果
    testWidgets('动画播放时缩放从1渐变到目标值', (WidgetTester tester) async {
      const targetScale = 2.5;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HeartAnimation(
              visible: true,
              scale: targetScale,
              child: Text('子组件'),
            ),
          ),
        ),
      );

      // 初始状态：scale 应该是 1.0
      final transformFinder = find.byType(Transform);
      Transform transformWidget = tester.widget<Transform>(transformFinder);
      expect(transformWidget.transform.getMaxScaleOnAxis(), 1.0);

      // 完成动画
      await tester.pump(const Duration(milliseconds: 700));

      // 最终状态：scale 应该是目标值
      transformWidget = tester.widget<Transform>(transformFinder);
      expect(transformWidget.transform.getMaxScaleOnAxis(), closeTo(targetScale, 0.01));
    });

    /// 测试自定义动画时长
    testWidgets('支持自定义动画时长', (WidgetTester tester) async {
      const customDuration = Duration(milliseconds: 500);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HeartAnimation(
              visible: true,
              duration: customDuration,
              child: Text('子组件'),
            ),
          ),
        ),
      );

      // 推进动画一半时间
      await tester.pump(const Duration(milliseconds: 250));

      // 验证动画正在进行（opacity 应该在中间值）
      final opacityWidget = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacityWidget.opacity, lessThan(1.0));
      expect(opacityWidget.opacity, greaterThan(0.0));
    });

    /// 测试心形图标有阴影效果
    testWidgets('心形图标有阴影效果', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HeartAnimation(
              visible: true,
              child: Text('子组件'),
            ),
          ),
        ),
      );

      final iconWidget = tester.widget<Icon>(find.byIcon(Icons.favorite));
      expect(iconWidget.shadows, isNotNull);
      expect(iconWidget.shadows!.length, greaterThan(0));
    });

    /// 测试使用 IgnorePointer 防止交互
    testWidgets('心形图标使用 IgnorePointer 防止交互', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HeartAnimation(
              visible: true,
              child: Text('子组件'),
            ),
          ),
        ),
      );

      // 验证 IgnorePointer 存在
      expect(find.byType(IgnorePointer), findsOneWidget);
    });
  });
}
