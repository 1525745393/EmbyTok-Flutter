// 全面屏手势适配：系统栏样式（SystemUiOverlayStyle）随主题切换的测试
//
// 验证：
// 1. buildLightTheme / buildDarkTheme 返回的 ThemeData 中包含正确的 overlay style
// 2. systemOverlayStyleOf 工具函数能从 ThemeData 提取 overlay style
// 3. 暗色主题 → 浅色状态栏图标（避免白底白字不可见）
// 4. 亮色主题 → 深色状态栏图标（避免黑底黑字不可见）
// 5. 状态栏 / 导航栏背景均为透明（配合 enableEdgeToEdge）

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:embbytok_flutter/theme/app_theme.dart';

void main() {
  group('全面屏手势适配：系统栏样式', () {
    test('亮色主题：状态栏 / 导航栏图标为深色，背景透明', () {
      final theme = buildLightTheme();
      final overlay = theme.appBarTheme.systemOverlayStyle;
      expect(overlay, isNotNull);
      expect(overlay!.statusBarIconBrightness, Brightness.dark);
      expect(overlay.systemNavigationBarIconBrightness, Brightness.dark);
      expect(overlay.statusBarColor, Colors.transparent);
      expect(overlay.systemNavigationBarColor, Colors.transparent);
    });

    test('暗色主题：状态栏 / 导航栏图标为浅色，背景透明', () {
      final theme = buildDarkTheme();
      final overlay = theme.appBarTheme.systemOverlayStyle;
      expect(overlay, isNotNull);
      expect(overlay!.statusBarIconBrightness, Brightness.light);
      expect(overlay.systemNavigationBarIconBrightness, Brightness.light);
      expect(overlay.statusBarColor, Colors.transparent);
      expect(overlay.systemNavigationBarColor, Colors.transparent);
    });

    testWidgets(
      'systemOverlayStyleOf：能在 BuildContext 中取出当前主题对应的 overlay style',
      (tester) async {
        SystemUiOverlayStyle? captured;

        await tester.pumpWidget(
          MaterialApp(
            theme: buildLightTheme(),
            darkTheme: buildDarkTheme(),
            themeMode: ThemeMode.light,
            home: Builder(
              builder: (context) {
                captured = systemOverlayStyleOf(context);
                return const SizedBox();
              },
            ),
          ),
        );
        expect(captured, isNotNull);
        expect(captured!.statusBarIconBrightness, Brightness.dark);
        expect(captured.systemNavigationBarIconBrightness, Brightness.dark);
      },
    );

    testWidgets(
      'systemOverlayStyleOf：ThemeMode.dark 切到暗色主题时取到浅色图标',
      (tester) async {
        SystemUiOverlayStyle? captured;

        await tester.pumpWidget(
          MaterialApp(
            theme: buildLightTheme(),
            darkTheme: buildDarkTheme(),
            themeMode: ThemeMode.dark,
            home: Builder(
              builder: (context) {
                captured = systemOverlayStyleOf(context);
                return const SizedBox();
              },
            ),
          ),
        );
        expect(captured, isNotNull);
        expect(captured!.statusBarIconBrightness, Brightness.light);
        expect(captured.systemNavigationBarIconBrightness, Brightness.light);
      },
    );
  });
}
