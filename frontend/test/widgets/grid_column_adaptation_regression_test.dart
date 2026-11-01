// 网格列数宽度自适应回归测试（锁定 2026-09-09 P2 历史项：
// 旧逻辑仅按方向竖屏2列/横屏4列，未适配平板；现为按宽度分桶 2/3/4/5）。
//
// 判定：不同屏幕宽度下，GridView 的 SliverGridDelegateWithFixedCrossAxisCount
// 跨列数符合预期，防止回退到方向硬编码。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:embytok_flutter/models/models.dart';
import 'package:embytok_flutter/providers/providers.dart';
import 'package:embytok_flutter/repositories/cached_media_repository.dart';
import 'package:embytok_flutter/views/video_grid_view.dart';

class _MockCachedMediaRepository extends Mock implements CachedMediaRepository {}

class _FakeVideoListNotifier extends VideoListNotifier {
  _FakeVideoListNotifier(super.ref, VideoListState initialState) {
    state = initialState;
  }
}

void main() {
  late _MockCachedMediaRepository mockCachedRepo;

  setUp(() {
    mockCachedRepo = _MockCachedMediaRepository();
    SharedPreferences.setMockInitialValues({});
  });

  List<MediaItem> makeItems(int n) => List.generate(
        n,
        (i) => MediaItem(id: 'v$i', title: '视频 $i', type: 'Movie'),
      );

  Widget buildApp(List<MediaItem> items) {
    return ProviderScope(
      overrides: [
        cachedMediaRepositoryProvider.overrideWithValue(mockCachedRepo),
        videoListProvider.overrideWith(
          (ref) => _FakeVideoListNotifier(
            ref,
            VideoListState(items: items, gridItems: items, isLoading: false),
          ),
        ),
        filteredVideoListProvider.overrideWith((ref) => items),
      ],
      child: const MaterialApp(home: VideoGridView()),
    );
  }

  int crossAxisCountOf(WidgetTester tester) {
    final grid = tester.widget<GridView>(find.byType(GridView).first);
    final delegate = grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    return delegate.crossAxisCount;
  }

  void setWidth(WidgetTester tester, double width) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(width, 800);
    addTearDown(tester.view.reset);
  }

  testWidgets('窄屏 360px（手机竖屏）→ 2 列', (tester) async {
    setWidth(tester, 360);
    await tester.pumpWidget(buildApp(makeItems(12)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(crossAxisCountOf(tester), 2);
  });

  testWidgets('中屏 560px（小平板竖屏）→ 3 列', (tester) async {
    setWidth(tester, 560);
    await tester.pumpWidget(buildApp(makeItems(12)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(crossAxisCountOf(tester), 3);
  });

  testWidgets('宽屏 1200px（平板横屏/桌面）→ 5 列', (tester) async {
    setWidth(tester, 1200);
    await tester.pumpWidget(buildApp(makeItems(30)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(crossAxisCountOf(tester), 5);
  });
}
