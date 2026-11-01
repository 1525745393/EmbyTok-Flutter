// 文件源删除弹窗：打开后同时显示"取消"与"删除"按钮
//
// 背景：
// - 删除文件源时会批量清理该源下视频的刮削缓存，可能耗时数秒。
// - 旧实现中"取消"按钮在整个 await 期间一直可点：用户中途点取消关闭弹窗后，
//   await 完成处的 Navigator.pop(context) 会误弹底层"文件源"页面本身
//   （此时栈顶路由是页面，不是弹窗）。
// - 修复：StatefulBuilder 包弹窗，点击删除即 setDialog(busy=true)：
//   隐藏取消按钮、删除按钮换 CircularProgressIndicator，并用 dialogCtx pop。
//
// 本测试断言：弹窗能正常打开，"取消"与"删除"按钮都存在。
// （busy 态切换依赖真实异步清理流程，widget 测试环境无法完整模拟，故只验证弹窗结构。）

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:embytok_flutter/models/file_source.dart';
import 'package:embytok_flutter/views/local/file_sources_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('删除文件源：弹窗打开后同时显示取消与删除按钮', (tester) async {
    // 预置一个可删除的 SMB 源（local_default 不可删，故用 smb）
    const src = FileSource(
      id: 'test_smb',
      type: FileSourceType.smb,
      name: '测试SMB',
      config: {'host': '1.2.3.4'},
    );
    SharedPreferences.setMockInitialValues({
      'file_sources_v1': json.encode([src.toJson()]),
    });

    // 防 flutter_secure_storage MissingPluginException
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: FileSourcesView()),
      ),
    );
    await tester.pump();

    // 打开第二张卡（第一行是 local_default，无删除项；第二张是测试 SMB 源）
    final popup = find.byType(PopupMenuButton<String>).at(1);
    await tester.tap(popup, warnIfMissed: false);
    await tester.pumpAndSettle();

    // 点"删除"菜单项
    await tester.tap(find.text('删除'), warnIfMissed: false);
    await tester.pumpAndSettle();

    // 弹窗打开：AlertDialog 存在，同时有"取消"与"删除"按钮
    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    expect(
      find.descendant(of: dialog, matching: find.text('取消')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('删除')),
      findsOneWidget,
    );
  });
}
