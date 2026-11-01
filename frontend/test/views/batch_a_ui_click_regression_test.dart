// 批次A「点击按键 UI 实时变化」回归测试
//
// 覆盖（审查 findings 批次A）：
// - F1（P1）：搜索弹窗不订阅 provider——弹窗 builder 用打开瞬间捕获的
//   state 快照构建列表，输入关键词后结果列表停留在旧内容。
//   修复：弹窗内容包 Consumer watch localVideoProvider，实时重建。
//   本测试断言：输入关键词后弹窗列表立即过滤（修复前：快照列表不变化）。
// - F3/F5：多选底部栏「重刮/批量重命名」循环 await 无 busy，可重复点击并发。
//   修复：_batchBusy 守卫 + 按钮禁用。本测试断言：多选模式底部栏操作按钮
//   存在（busy 切换依赖真实异步清理流程，widget 测试环境无法完整模拟，
//   与 local_sources_delete_dialog_busy_regression_test 同一披露边界）。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:photo_manager/photo_manager.dart';

import 'package:embytok_flutter/models/local_video_item.dart';
import 'package:embytok_flutter/providers/file_sources_provider.dart';
import 'package:embytok_flutter/providers/local_video_provider.dart';
import 'package:embytok_flutter/views/local/local_video_view.dart';

class _FakeLocalVideoNotifier extends LocalVideoNotifier {
  _FakeLocalVideoNotifier(super.ref, List<LocalVideoItem> items,
      {bool selecting = false, Set<String>? selected}) {
    state = LocalVideoState(
      items: items,
      permission: PermissionState.authorized,
      selecting: selecting,
      selected: selected ?? const {},
    );
  }
}

class _FakeFileSourcesNotifier extends FileSourcesNotifier {
  _FakeFileSourcesNotifier() : super();
}

LocalVideoItem _item(String id, String name) => LocalVideoItem(
      id: id,
      name: name,
      path: '/sdcard/Movies/$name.mp4',
      sizeBytes: 1024,
      duration: const Duration(minutes: 1),
      width: 1920,
      height: 1080,
      mimeType: 'video/mp4',
      modifiedAt: DateTime(2026),
      isAppDirFile: false,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('F1 搜索弹窗：输入关键词后结果列表实时过滤', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localVideoProvider.overrideWith((ref) => _FakeLocalVideoNotifier(
              ref, [_item('a', '电影A'), _item('b', '剧集B')])),
          fileSourcesProvider.overrideWith((ref) => _FakeFileSourcesNotifier()),
        ],
        child: const MaterialApp(home: LocalVideoView()),
      ),
    );
    await tester.pump();

    // 打开搜索弹窗：初始应显示全部条目（限定在弹窗内，页面网格也有同名文本）
    await tester.tap(find.byIcon(Icons.search));
    await tester.pump();
    final sheet = find.byType(BottomSheet);
    expect(sheet, findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text('电影A')), findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text('剧集B')), findsOneWidget);

    // 输入关键词 '电影'：列表应实时只剩 电影A
    // 修复前：弹窗持有打开瞬间的 state 快照，列表仍显示 剧集B → 断言失败
    await tester.enterText(find.byType(TextField), '电影');
    await tester.pump();
    expect(find.descendant(of: sheet, matching: find.text('电影A')), findsOneWidget,
        reason: 'F1 修复后弹窗订阅 provider，输入关键词后匹配项仍可见');
    expect(find.descendant(of: sheet, matching: find.text('剧集B')), findsNothing,
        reason: 'F1 修复后弹窗订阅 provider，输入关键词后不匹配项应从列表消失');

    // 输入不存在的词：应显示「无结果」空态（同样实时）
    await tester.enterText(find.byType(TextField), '不存在的片名');
    await tester.pump();
    expect(find.descendant(of: sheet, matching: find.text('无结果')), findsOneWidget,
        reason: 'F1 修复后空态随输入实时切换');
  });

  testWidgets('F3/F5 多选底部栏：重刮与批量重命名按钮存在', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localVideoProvider.overrideWith((ref) => _FakeLocalVideoNotifier(
              ref,
              [_item('a', '电影A'), _item('b', '剧集B')],
              selecting: true,
              selected: {'a'})),
          fileSourcesProvider.overrideWith((ref) => _FakeFileSourcesNotifier()),
        ],
        child: const MaterialApp(home: LocalVideoView()),
      ),
    );
    await tester.pump();

    // 多选模式底部栏：重刮 / 批量重命名 / 取消 三个操作入口齐全
    expect(find.text('重刮'), findsOneWidget);
    expect(find.text('批量重命名'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);

    // busy 守卫依赖真实异步清理/重命名流程，widget 测试环境无法完整模拟；
    // 守卫正确性由代码审查保证（_batchBusy 置位 + finally 恢复 + 按钮禁用）。
  });
}
