// 本地视频页搜索弹窗：关闭后清空关键词回归测试
//
// 背景：
// - 搜索底部弹窗里的 TextField 无 controller，输入时 onChanged 直接
//   notifier.setKeyword 写入 provider。
// - 弹窗关闭时没有任何地方重置 keyword：下次再打开弹窗时输入框是空的，
//   但 provider 里残留旧 keyword，结果列表仍按旧词过滤，出现
//   "空输入框却展示上一次搜索结果"的状态不一致。
// - 修复：showModalBottomSheet(...).whenComplete(() => notifier.setKeyword(''))。
//
// 本测试断言：输入关键词 → 弹窗关闭后，provider 里 keyword 被清空。

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
  _FakeLocalVideoNotifier(super.ref, List<LocalVideoItem> items) {
    state = LocalVideoState(
      items: items,
      permission: PermissionState.authorized,
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

  testWidgets('搜索弹窗关闭后 provider keyword 被清空', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localVideoProvider.overrideWith(
              (ref) => _FakeLocalVideoNotifier(ref, [_item('a', '电影A')])),
          fileSourcesProvider.overrideWith((ref) => _FakeFileSourcesNotifier()),
        ],
        child: const MaterialApp(home: LocalVideoView()),
      ),
    );
    await tester.pump();

    // 打开搜索弹窗
    await tester.tap(find.byIcon(Icons.search));
    await tester.pump();

    // 输入关键词
    await tester.enterText(find.byType(TextField), '电影');
    await tester.pump();

    // 输入后 keyword 应为 电影
    final container = ProviderScope.containerOf(
        tester.element(find.byType(LocalVideoView)));
    expect(container.read(localVideoProvider).keyword, '电影');

    // 点 barrier 关闭弹窗
    await tester.tapAt(const Offset(20, 20));
    await tester.pump();

    // 修复后：弹窗关闭 → keyword 清空；修复前：仍为 '电影'
    expect(container.read(localVideoProvider).keyword, '',
        reason: '弹窗关闭后应清空关键词，避免下次打开空输入框却按旧词过滤');
  });
}
