// 登录页 UI 打磨回归：2026-11-15 UI 审查 9 条 findings 的守门用例
//
// 覆盖：
// - F1 「记住密码 + HTTP 不安全」窄屏/大字体不再横向溢出
// - F2 主操作按钮固定在底部操作栏，任何视口首屏可见
// - F3 Logo 图标使用 onPrimary（深色主题不再白图标糊在同色方底上）
// - F4 成功态颜色在两种主题下对 surface 对比度 ≥3:1
// - F5 类型卡片带选中语义、点击仍能切换类型
// - F6 「记住密码」整行可点
// - F8 分区帮助按钮触控目标 ≥44×44

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:embytok_flutter/providers/providers.dart';
import 'package:embytok_flutter/theme/app_theme.dart';
import 'package:embytok_flutter/views/login_view.dart';

import '../mocks/mock_secure_storage.dart';

Widget _wrap(ProviderContainer container, ThemeData theme, {double scale = 1.0}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: theme,
      home: const LoginView(),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
    ),
  );
}

ProviderContainer _container() => ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(MockFlutterSecureStorage()),
      ],
    );

double _relativeLuminance(Color c) {
  double channel(double v) {
    final s = v / 255.0;
    return s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4) as double;
  }

  return 0.2126 * channel(c.r * 255) +
      0.7152 * channel(c.g * 255) +
      0.0722 * channel(c.b * 255);
}

double _contrast(Color a, Color b) {
  final la = _relativeLuminance(a);
  final lb = _relativeLuminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

Semantics _cardSemantics(WidgetTester tester, String title) {
  final finder =
      find.ancestor(of: find.text(title), matching: find.byType(Semantics));
  return tester.widget<Semantics>(finder.first);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('F1 记住密码行不再溢出', () {
    for (final size in [const Size(320, 568), const Size(360, 640)]) {
      for (final scale in [1.3, 2.0]) {
        testWidgets('${size.width}dp@${scale}x + HTTP 地址', (tester) async {
          SharedPreferences.setMockInitialValues({});
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);
          final container = _container();
          addTearDown(container.dispose);

          await tester.pumpWidget(
              _wrap(container, buildLightTheme(), scale: scale));
          await tester.pumpAndSettle();

          await tester.enterText(find.byType(TextFormField).at(0),
              'http://example.com:8096');
          await tester.pumpAndSettle();

          expect(find.text('HTTP 不安全'), findsOneWidget);
          // RenderFlex 溢出会被 Flutter 记为异常，takeException 能取到
          expect(tester.takeException(), isNull,
              reason: '窄屏 + 大字体下「记住密码/HTTP 不安全」行不得横向溢出');

          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 2));
        });
      }
    }
  });

  group('F2 主操作按钮首屏可见', () {
    for (final size in [const Size(360, 640), const Size(411, 915)]) {
      testWidgets('${size.width}x${size.height} 按钮完全落在视口内',
          (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        final container = _container();
        addTearDown(container.dispose);

        await tester.pumpWidget(_wrap(container, buildLightTheme()));
        await tester.pumpAndSettle();

        final rect = tester.getRect(find.byType(ElevatedButton));
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(size.height),
            reason: '登录按钮固定在底部操作栏，不得掉到首屏之外');

        // 能直接点（旧实现会触发 "would not hit test" 警告且不提交）
        await tester.enterText(find.byType(TextFormField).at(0), 'ftp://x');
        await tester.tap(find.byType(ElevatedButton));
        await tester.pumpAndSettle();
        expect(find.textContaining('http://'), findsWidgets,
            reason: '点击按钮应触发地址校验并给出提示');

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 2));
      });
    }
  });

  group('F3 Logo 图标跟随语义色', () {
    testWidgets('浅色/深色都使用 onPrimary', (tester) async {
      for (final theme in [buildLightTheme(), buildDarkTheme()]) {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        final container = _container();
        addTearDown(container.dispose);

        await tester.pumpWidget(_wrap(container, theme));
        await tester.pumpAndSettle();

        final icon = tester.widget<Icon>(
            find.byIcon(Icons.play_circle_filled));
        expect(icon.color, theme.colorScheme.onPrimary);
        // 对比度必须满足图形元素 3:1
        expect(_contrast(icon.color!, theme.colorScheme.primary),
            greaterThanOrEqualTo(3.0));

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 2));
      }
    });
  });

  group('F4 成功态颜色对比度', () {
    test('浅色深绿 / 深色浅绿对 surface 均 ≥3:1', () {
      const lightSuccess = Color(0xFF2E7D32);
      const darkSuccess = Color(0xFF81C784);
      final light = buildLightTheme().colorScheme;
      final dark = buildDarkTheme().colorScheme;
      expect(_contrast(lightSuccess, light.surface), greaterThanOrEqualTo(3.0));
      expect(_contrast(darkSuccess, dark.surface), greaterThanOrEqualTo(3.0));
    });
  });

  group('F5 类型卡片选中语义 + 点击仍生效', () {
    testWidgets('选中态进入语义树，且点击可切换类型', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(360, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final container = _container();
      addTearDown(container.dispose);

      await tester.pumpWidget(_wrap(container, buildLightTheme()));
      await tester.pumpAndSettle();

      // 默认选中 Emby
      var emby = _cardSemantics(tester, 'Emby 视频');
      expect(emby.properties.selected, isTrue);
      expect(emby.properties.button, isTrue);
      expect(emby.properties.label, contains('Emby 视频'));
      expect(emby.properties.onTap, isNotNull);
      expect(_cardSemantics(tester, '群晖音乐').properties.selected, isFalse);

      await tester.tap(find.text('群晖音乐'));
      await tester.pumpAndSettle();

      expect(_cardSemantics(tester, '群晖音乐').properties.selected, isTrue);
      emby = _cardSemantics(tester, 'Emby 视频');
      expect(emby.properties.selected, isFalse);
      // 表单联动：地址字段标签切到群晖
      expect(find.text('群晖服务器地址'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    });
  });

  group('F6 记住密码整行可点', () {
    testWidgets('点击文字即可切换勾选', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final container = _container();
      addTearDown(container.dispose);

      await tester.pumpWidget(_wrap(container, buildLightTheme()));
      await tester.pumpAndSettle();

      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
      // 「记住密码」行在首屏之外（表单本身高于一屏），先滚动到可见位置
      await tester.ensureVisible(find.text('记住密码'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('记住密码'));
      await tester.pumpAndSettle();
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    });
  });

  group('F8 帮助按钮触控目标', () {
    testWidgets('登录页两处帮助按钮均 ≥44×44', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(411, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final container = _container();
      addTearDown(container.dispose);

      await tester.pumpWidget(_wrap(container, buildLightTheme()));
      await tester.pumpAndSettle();

      final helpIcons = find.byIcon(Icons.help_outline);
      expect(helpIcons, findsWidgets);
      for (var i = 0; i < helpIcons.evaluate().length; i++) {
        final box = tester.getRect(
            find.ancestor(of: helpIcons.at(i), matching: find.byType(IconButton))
                .first);
        expect(box.width, greaterThanOrEqualTo(44.0));
        expect(box.height, greaterThanOrEqualTo(44.0));
      }

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    });
  });

  // ===== 渲染级验证第二轮（2026-11-15）V1–V4 守门 =====
  //
  // V1[P2] 键盘弹起时底部操作栏被键盘完全遮挡（F2 搬到 bottomNavigationBar 引入）
  // V2[P3] 2.0x 大字号下类型卡片标题被省略号吃掉
  // V3[P3] 「整宽卡」按内容宽度居中，未铺满可用宽度、左边缘不对齐
  // V4[P3] 「服务器管理」tile 大字号下标题列被 leading + trailing 压窄

  Future<void> pumpLogin(
    WidgetTester tester,
    ProviderContainer container, {
    required Size size,
    double scale = 1.0,
    double keyboard = 0,
  }) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    tester.view.viewInsets = keyboard > 0
        ? FakeViewPadding(bottom: keyboard)
        : FakeViewPadding.zero;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(scale),
          viewInsets: EdgeInsets.only(bottom: keyboard),
        ),
        child: MaterialApp(theme: buildLightTheme(), home: const LoginView()),
      ),
    ));
    await tester.pumpAndSettle();
  }

  group('V1 键盘弹起时操作栏可见', () {
    testWidgets('360×800 + 键盘 300dp：按钮整体位于键盘上方', (tester) async {
      final container = _container();
      addTearDown(container.dispose);
      await pumpLogin(tester, container,
          size: const Size(360, 800), keyboard: 300);

      final button = tester.getRect(find.byType(ElevatedButton));
      // 键盘顶 = 800 - 300 = 500
      expect(button.bottom, lessThanOrEqualTo(500.5),
          reason: '键盘弹起时必须把底部操作栏抬到键盘上方，否则输完密码点不到登录');
      expect(button.top, greaterThan(0));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    });
  });

  group('V3 类型卡片铺满可用宽度', () {
    testWidgets('360 下整宽卡与两列网格同宽同左边缘', (tester) async {
      final container = _container();
      addTearDown(container.dispose);
      await pumpLogin(tester, container, size: const Size(360, 800));

      Rect cardOf(String label) => tester.getRect(find
          .ancestor(
              of: find.text(label), matching: find.byType(AnimatedContainer))
          .first);

      final emby = cardOf('Emby 视频');
      final synology = cardOf('群晖音乐');
      final local = cardOf('本地媒体库');

      // Column(stretch) 后整宽卡 = 可用宽度（360 - 32*2）
      expect(synology.width, closeTo(296.0, 0.5));
      expect(local.width, closeTo(296.0, 0.5));
      // 左边缘与两列网格第一格对齐（不再居中缩进）
      expect(synology.left, closeTo(emby.left, 0.5));
      expect(local.left, closeTo(emby.left, 0.5));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    });
  });

  group('V2 大字号改单列且标题不只剩省略号', () {
    testWidgets('2.0x 下双卡竖排、标题允许 2 行', (tester) async {
      final container = _container();
      addTearDown(container.dispose);
      await pumpLogin(tester, container,
          size: const Size(360, 800), scale: 2.0);

      final emby = tester.getRect(find.text('Emby 视频'));
      final jelly = tester.getRect(find.text('Jellyfin 视频'));
      // 单列：两卡水平方向同中心，且 Jellyfin 在 Emby 下方
      expect((emby.center.dx - jelly.center.dx).abs(), lessThan(1.0),
          reason: '大字号必须单列，双列会把标题挤成「Emby ⋯」');
      expect(jelly.top, greaterThan(emby.bottom));

      // 标题/副标题在单列模式下允许折到 2 行
      final title = tester.widget<Text>(find.text('Jellyfin 视频'));
      expect(title.maxLines, 2);
      final subtitle =
          tester.widget<Text>(find.text('直接管理手机视频，无需服务器'));
      expect(subtitle.maxLines, 2);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    });
  });

  group('V4 大字号下 tile 不再被压成四行', () {
    testWidgets('320×568 @1.3x：tile 高度收敛、副标题不超过 2 行', (tester) async {
      final container = _container();
      addTearDown(container.dispose);
      await pumpLogin(tester, container,
          size: const Size(320, 568), scale: 1.3);

      await tester.scrollUntilVisible(
          find.text('服务器管理'), 120,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();

      final tile = find
          .ancestor(of: find.text('服务器管理'), matching: find.byType(ListTile))
          .first;
      // 修复前实测 170.0（标题 2 行 + 副标题 4 行）
      expect(tester.getSize(tile).height, lessThan(120.0));
      final subtitle =
          tester.getRect(find.text('添加、编辑、切换媒体服务器'));
      // 13sp×1.3 ≈ 17px/行，2 行 ≈ 48；4 行会接近 90
      expect(subtitle.height, lessThan(60.0));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
