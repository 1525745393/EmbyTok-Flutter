import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:embbytok_flutter/app.dart';

void main() {
  group('Back navigation behavior', () {
    testWidgets('首页按返回键应显示退出确认对话框', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: EmbyTokApp()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MaterialApp), findsOneWidget);

      await tester.binding.messageBack();
      await tester.pumpAndSettle();

      expect(find.text('退出应用？'), findsOneWidget);
      expect(find.text('确定要退出吗？'), findsOneWidget);
    });

    testWidgets('首页从搜索页(底部导航)按返回键应回到首页Feed而非直接退出', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: EmbyTokApp()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('搜索'));
      await tester.pumpAndSettle();

      await tester.binding.messageBack();
      await tester.pumpAndSettle();

      expect(find.text('退出应用？'), findsNothing);
    });
  });
}
