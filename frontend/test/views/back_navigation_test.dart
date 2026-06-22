// 验证应用退出流程：所有路径最后都到首页，首页按返回键应弹退出确认
// 重点：根路由下的系统返回键必须被拦截（go_router 13.x 已知问题）

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:embbytok_flutter/app.dart';

void main() {
  group('退出确认对话框', () {
    testWidgets('首页按系统返回键应显示退出确认', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: EmbyTokApp()),
      );
      await tester.pumpAndSettle();

      await tester.binding.messageBack();
      await tester.pumpAndSettle();

      expect(find.text('退出应用？'), findsOneWidget);
      expect(find.text('确定要退出吗？'), findsOneWidget);
    });
  });
}
