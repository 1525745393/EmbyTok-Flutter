// 批次C「删除选中字幕后『关闭字幕』选中态不刷新」回归测试
//
// 根因：SubtitleSelector 的选中态此前用打开时的 selectedTrackId 参数快照，
// onDelete 删除当前选中字幕时只更新 selectedSubtitleProvider，参数快照不变，
// 「关闭字幕」行的 isSelected(selectedTrackId == null) 不刷新。
// 修复：选中态改为 ref.watch(selectedSubtitleProvider) 单一数据源，
// 删除选中字幕 → provider 置 null → watch 触发重建 → 「关闭字幕」即时选中。
// 本测试在修复前必失败（删除后关闭字幕行无 check）。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:embytok_flutter/models/subtitle_track.dart';
import 'package:embytok_flutter/providers/video_playback_controller.dart';
import 'package:embytok_flutter/widgets/video/subtitle_selector.dart';

/// 指定标题行（InkWell 祖先）内的选中 check 图标
Finder _optionSelected(WidgetTester tester, String title) {
  return find.descendant(
    of: find.ancestor(of: find.text(title), matching: find.byType(InkWell)),
    matching: find.byIcon(Icons.check),
  );
}

void main() {
  testWidgets('删除选中本地字幕后「关闭字幕」选中态即时刷新', (tester) async {
    // 菜单项多（关闭字幕+导入+服务器组+本地组），默认 600px 视口会把
    // 底部本地组渲染到屏幕外被判 offstage，调大视口保证全部 onstage 可点
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final local = SubtitleTrack(
      id: 'l1',
      name: '本地字幕.srt',
      language: 'zh',
      format: 'srt',
      localFilePath: '/tmp/local.srt',
    );
    final container = ProviderContainer(overrides: [
      localSubtitleTracksProvider.overrideWith(
        (ref) => LocalSubtitleTracksNotifier()..add(local),
      ),
    ]);
    addTearDown(container.dispose);
    // 当前选中本地字幕 l1；保留一条服务器字幕，保证删除本地字幕
    // 后菜单仍有轨道（hasAnySubtitle=true），「关闭字幕」行得以保留观察
    final serverTrack = SubtitleTrack(
      id: 's1',
      name: '服务器字幕',
      language: 'en',
      format: 'srt',
    );
    container.read(selectedSubtitleProvider.notifier).state = 'l1';

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: SubtitleSelector(tracks: [serverTrack], onClose: () {}),
        ),
      ),
    ));

    // 初始：l1 选中 → 「关闭字幕」无选中标记
    expect(_optionSelected(tester, '关闭字幕'), findsNothing);

    // 删除当前选中的本地字幕
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();

    // 「关闭字幕」选中态即时刷新（修复前此处为 findsNothing）
    expect(_optionSelected(tester, '关闭字幕'), findsOneWidget);
  });
}
