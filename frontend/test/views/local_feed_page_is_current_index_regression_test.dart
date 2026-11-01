// 本地视频流（/local-feed）isCurrentPage 滑动切换回归测试
//
// 背景：
// - LocalFeedPage 原先 itemBuilder 里写死 `isCurrentPage: i == 0`，
//   onPageChanged 只更新无人监听的 localFeedPlayingIndexProvider。
// - VideoPageItem 只在 widget.isCurrentPage 发生变化时才暂停/恢复
//   （didUpdateWidget），并不监听该 provider。
// - 后果：用户上下滑到第 2 个视频后，新页 isCurrentPage 恒 false 不自动播放，
//   而第 1 页因 isCurrentPage 仍为 true 音频继续在后台响。
// - 修复：onPageChanged 后 setState 更新 _currentIndex，itemBuilder 传
//   `i == _currentIndex`（与 feed_view 同一模式）。
//
// 本测试断言：滑到第二页后，第二页的 VideoPageItem 收到 isCurrentPage=true，
// 第一页收到 false。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:embytok_flutter/models/local_video_item.dart';
import 'package:embytok_flutter/providers/local_video_provider.dart';
import 'package:embytok_flutter/views/local/local_feed_page.dart';
import 'package:embytok_flutter/widgets/video/video_page_item.dart';

/// 注入测试数据的假 Notifier：父类构造会触发 _init（photo_manager 等
/// 平台通道），这里立即用测试数据覆盖 state，让页面渲染不依赖真实扫描。
class _FakeLocalVideoNotifier extends LocalVideoNotifier {
  _FakeLocalVideoNotifier(super.ref, List<LocalVideoItem> items) {
    state = LocalVideoState(items: items);
  }
}

LocalVideoItem _item(String id, String name) => LocalVideoItem(
      id: id,
      name: name,
      path: '/sdcard/Movies/$name.mp4',
      sizeBytes: 1024 * 1024,
      duration: const Duration(minutes: 1),
      width: 1920,
      height: 1080,
      mimeType: 'video/mp4',
      modifiedAt: DateTime(2026),
      isAppDirFile: false,
    );

Widget _buildApp(List<LocalVideoItem> items) {
  return ProviderScope(
    overrides: [
      localVideoProvider.overrideWith(
          (ref) => _FakeLocalVideoNotifier(ref, items)),
    ],
    child: const MaterialApp(
      home: LocalFeedPage(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('滑到第二页后：第二页 isCurrentPage=true、第一页=false',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    // 竖屏视口，与真实刷视频场景一致
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildApp([_item('a', '电影A'), _item('b', '电影B')]));
    await tester.pump();

    // 初始：第一页 isCurrentPage=true
    var items = tester
        .widgetList<VideoPageItem>(find.byType(VideoPageItem))
        .toList();
    expect(items, isNotEmpty, reason: '应至少渲染第一页 VideoPageItem');
    expect(items.first.isCurrentPage, isTrue, reason: '初始页应为当前页');

    // 上滑切到第二页。VideoPageItem 内部有常驻动画/定时器，
    // 不能用 pumpAndSettle（永不收敛），改为逐帧 pump 到 PageView 吸附完成。
    await tester.fling(find.byType(PageView), const Offset(0, -600), 1200);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    items = tester
        .widgetList<VideoPageItem>(find.byType(VideoPageItem))
        .toList();
    expect(items, hasLength(2),
        reason: '两页都应在树中（PageView 保留相邻页）');

    // adapter 会给 id 加 local_ 前缀
    final byId = {for (final w in items) w.item.id: w};
    expect(byId['local_b']?.isCurrentPage, isTrue,
        reason: '修复后：第二页（电影B）应为当前页并自动播放');
    expect(byId['local_a']?.isCurrentPage, isFalse,
        reason: '修复后：第一页（电影A）应暂停，不再继续播音频');
  });
}
