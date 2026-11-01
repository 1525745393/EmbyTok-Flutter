// 本地媒体库设置页「日志级别」选择后副标题刷新回归测试
//
// 背景：
// - ListTile 点击处原写法：`_showLogLevelPicker(context); setLocal(() {});`
//   未 await。setLocal 在弹窗刚打开时就用旧级别重建，用户在底部弹窗选定
//   级别弹窗关闭后，没有任何重建，"当前: xxx" 一直停留在旧值。
// - 修复：_showLogLevelPicker 返回弹窗 Future，onTap await 后再 setLocal。
//
// 本测试断言：打开日志级别弹窗 → 选「调试（最详细）」→ 弹窗关闭后，
// 设置页副标题显示 "当前: debug"。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:embytok_flutter/views/local/local_library_settings_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('选定日志级别后副标题立即刷新为当前级别', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: LocalLibrarySettingsPage()),
      ),
    );
    await tester.pump();

    // 列表懒加载，先滚动到「日志级别」再点
    await tester.dragUntilVisible(
      find.text('日志级别'),
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.pump();
    await tester.tap(find.text('日志级别'));
    await tester.pump();

    // 弹窗中选定「调试（最详细）」
    await tester.tap(find.text('调试（最详细）'));
    await tester.pump(); // 弹窗关闭

    // 修复前：副标题仍停留在打开弹窗前的旧值；修复后应显示 debug
    expect(find.text('当前: debug'), findsOneWidget,
        reason: '选定调试级别后，设置页副标题应立即刷新');
  });
}
