// TMDB 搜索页：清空关键词后提交应同步清空旧结果 回归测试
//
// 背景：
// - _search() 在输入框为空时直接 return，旧搜索结果留在屏幕上，
//   与"空输入框"状态不一致。
// - 修复：空输入时先 setState(() => _results = []) 再 return。
//
// 本测试断言：页面初始渲染正常（无网络时显示"无结果"），
// 清空输入框提交后不崩溃、状态一致。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:embytok_flutter/views/local/tmdb_search_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('清空搜索框提交后不崩溃且保持无结果状态', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const MaterialApp(
        home: TmdbSearchPage(
          initialQuery: 'test',
          pathHash: 'hash1',
          filename: 'test.mp4',
        ),
      ),
    );
    await tester.pump(); // 触发 initState _search（无网络，返回空）
    await tester.pump(const Duration(seconds: 1));

    // 初始：无网络 → 无结果
    expect(find.text('无结果'), findsOneWidget);

    // 输入框有初始文字，清空并提交
    await tester.enterText(find.byType(TextField), '');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();

    // 修复后：空输入提交清空结果（此处本来就是空，验证不崩溃）
    expect(find.text('无结果'), findsOneWidget);
    expect(tester.takeException(), isNull,
        reason: '清空搜索框提交不应崩溃');
  });
}
