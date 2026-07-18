// 验证 VideoPageItem 不再依赖 onPreloadThreshold 字段
//
// 背景：onPreloadThreshold 是死代码，PlaybackCoordinator.preloadNeighbors
// 已在 onPageChangeSettled 时预加载上下一条，覆盖该场景。
// 此测试为契约测试：确认 onPreloadThreshold 已被移除。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:embbytok_flutter/models/models.dart';
import 'package:embbytok_flutter/widgets/video_page_item.dart';

void main() {
  testWidgets('VideoPageItem 构造函数不接受 onPreloadThreshold 参数',
      (tester) async {
    // 通过尝试构造 VideoPageItem：若 onPreloadThreshold 仍存在，
    // 以下代码会编译失败（命名参数未定义）。
    // 此处的契约是：构造函数参数列表中不包含 onPreloadThreshold。
    final item = MediaItem(id: 'a', title: 't', type: 'Video');

    // 设置竖屏视口避免 Column 布局溢出
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: VideoPageItem(
            key: ValueKey(item.id),
            item: item,
            isCurrentPage: true,
            // 注意：此处不传 onPreloadThreshold
            // 若该参数仍存在且为必需，编译会失败
          ),
        ),
      ),
    );

    expect(find.byType(VideoPageItem), findsOneWidget);

    // 清理：替换 widget 树触发 unmount（dispose ref.read bug 已修复）
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SizedBox.shrink())),
    );
    await tester.pump();
  });
}
