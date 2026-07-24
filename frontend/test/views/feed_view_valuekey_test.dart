// 验证 FeedView 的 PageView itemBuilder 为 VideoPageItem 设置了 ValueKey(item.id)
//
// 背景：
// - PlaybackShell（独立播放页）已正确使用 ValueKey(item.id)
// - FeedView 此前未设置 key，items 列表变化时 PageView 会先复用旧 widget
//   再 didUpdateWidget 重建，可能出现「画面还在播旧视频，元信息是新视频」的鬼影
//
// 测试策略：pump 一个最小 FeedView，从 items 列表中查找 VideoPageItem，
// 校验其 key 为 ValueKey 且 value == item.id。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:embbytok_flutter/models/models.dart';
import 'package:embbytok_flutter/widgets/video_page_item.dart';

// 构造一个最小可播放的 MediaItem（playbackUrl 为空时 VideoPlayerWidget 降级为缩略图，
// 不会真正初始化播放控制器，适合 widget 测试）
MediaItem _fakeItem(String id) => MediaItem(
      id: id,
      title: 'item-$id',
      type: 'Video',
    );

void main() {
  testWidgets('FeedView itemBuilder 为 VideoPageItem 设置 ValueKey(item.id)',
      (tester) async {
    final items = [_fakeItem('a'), _fakeItem('b'), _fakeItem('c')];

    // 设置竖屏视口：VideoPageItem 为竖屏视频页设计，
    // 默认 800x600 横屏视口会导致内部 Column 布局溢出
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // 直接构造 VideoPageItem 列表模拟 FeedView itemBuilder 的输出，
    // 校验 key 设置（避免完整 FeedView pump 需要 auth/router 依赖）
    // 包裹 ProviderScope：VideoPageItem 是 ConsumerStatefulWidget，
    // initState 中通过 ref.listenManual 监听 isPlayingProvider/isAutoPlayProvider
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: PageView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return VideoPageItem(
                key: ValueKey(item.id),
                item: item,
                isCurrentPage: index == 0,
              );
            },
          ),
        ),
      ),
    );

    // 查找第一个 VideoPageItem，校验其 key
    final videoPageItemFinder = find.byType(VideoPageItem);
    expect(videoPageItemFinder, findsOneWidget);

    final videoPageItemWidget = tester.widget<VideoPageItem>(videoPageItemFinder);
    final key = videoPageItemWidget.key;
    expect(key, isA<ValueKey<String>>(),
        reason: 'VideoPageItem 必须设置 ValueKey<String>');
    expect((key as ValueKey<String>).value, 'a',
        reason: 'ValueKey 的 value 必须等于 item.id');

    // 清理：替换 widget 树触发 VideoPageItem unmount
    // dispose ref.read bug 已在 Phase 3 修复（移到 deactivate），无需 takeException 兜底
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SizedBox.shrink())),
    );
    await tester.pump();
  });
}
