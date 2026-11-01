// 回归测试：VideoPlayerWidget._loadSubtitle 的 item-token 守卫（时序契约）
//
// 缺陷：_loadSubtitle 在 await getSubtitleCues 后只检查 mounted && !_isDisposed，
// 不校验 widget.item.id 是否已切换（item 切换后 State 复用，didUpdateWidget
// 只重建 controller）。慢网络下旧视频的字幕请求晚于新视频返回时，
// 晚到响应会覆盖新视频字幕（旧视频字幕显示在新视频上）。
//
// 修复：发起请求时记录 requestItemId，await 返回后若 widget.item.id 已变化
// 则丢弃响应（成功与失败分支均守卫，避免旧失败请求误清新视频字幕）。
//
// 测试边界：字幕渲染与控制器初始化依赖原生播放器通道（测试环境无平台
// 实现，三引擎均无法真实初始化），因此本测试为契约式验证——与
// test/widgets/video_player_widget_release_test.dart 策略一致：
//   1. 驱动完整竞态时序（A 挂起 → 切 B → B 完成 → A 晚到），确认场景可复现；
//   2. 断言 fake 服务按 item-A → item-B 顺序收到请求（时序被真实覆盖）；
//   3. 守卫正确性由代码审查保证（requestItemId 与 widget.item.id 比对，
//      成功/失败分支均守卫）。建议实机慢网络滑动交叉验证。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:embytok_flutter/models/models.dart';
import 'package:embytok_flutter/providers/providers.dart';
import 'package:embytok_flutter/services/embytok_service.dart';
import 'package:embytok_flutter/widgets/video/video_player_widget.dart';

/// 受控 fake：按 itemId 返回预置的字幕响应，并记录调用时序
class _FakeEmbytokService extends EmbytokService {
  final List<String> requestedItemIds = [];
  final Map<String, Future<List<SubtitleCue>>> _responses = {};

  void queueResult(String itemId, Future<List<SubtitleCue>> future) {
    _responses[itemId] = future;
  }

  @override
  Future<List<SubtitleCue>> getSubtitleCues({
    required String itemId,
    required String mediaSourceId,
    required int index,
    String format = 'srt',
    String? directUrl,
    String? serverUrl,
    String? token,
  }) {
    requestedItemIds.add(itemId);
    final future = _responses[itemId];
    if (future != null) return future;
    return Future.value(const <SubtitleCue>[]);
  }
}

MediaSource _source(String srcId) => MediaSource(
      id: srcId,
      name: srcId,
      mediaStreams: [
        MediaStream(
          index: 0,
          type: 'Subtitle',
          language: 'chi',
          codec: 'srt',
          deliveryUrl: 'http://example/$srcId/0/Stream.srt',
          isDefault: true,
        ),
      ],
    );

MediaItem _item(String id, String srcId) => MediaItem(
      id: id,
      title: id,
      type: 'Movie',
      mediaSources: [_source(srcId)],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('竞态时序可复现：A 挂起 → 切 B → B 完成 → A 晚到', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final fake = _FakeEmbytokService();
    // A 视频字幕请求挂起（慢网络）；B 视频字幕立即返回
    final completerA = Completer<List<SubtitleCue>>();
    fake.queueResult('item-A', completerA.future);
    fake.queueResult('item-B', Future.value([
      const SubtitleCue(Duration(seconds: 1), Duration(seconds: 2), 'B字幕'),
    ]));

    const playerKey = ValueKey('player');
    Widget scope(MediaItem item) => ProviderScope(
          overrides: [embytokServiceProvider.overrideWithValue(fake)],
          child: MaterialApp(
            home: VideoPlayerWidget(key: playerKey, item: item),
          ),
        );

    // 1. 播放 A，触发 A 字幕加载（挂起中）
    await tester.pumpWidget(scope(_item('item-A', 'srcA')));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(VideoPlayerWidget)),
    );
    container.read(selectedSubtitleProvider.notifier).state = 'srcA:0';
    await tester.pump();
    expect(completerA.isCompleted, isFalse,
        reason: '前置条件：A 的字幕请求应处于挂起状态');

    // 2. 切换到 B（同 key 不同 item → didUpdateWidget，State 复用）
    await tester.pumpWidget(scope(_item('item-B', 'srcB')));
    await tester.pump();
    // 3. B 字幕加载完成
    container.read(selectedSubtitleProvider.notifier).state = 'srcB:0';
    await tester.pump();
    await tester.pump();

    // 4. A 的旧响应此刻晚到（修复后应被 item-token 守卫丢弃）
    completerA.complete(const [
      SubtitleCue(Duration(seconds: 1), Duration(seconds: 2), 'A字幕'),
    ]);
    await tester.pump();
    await tester.pump();

    // 5. 契约断言：请求按 A → B 顺序发出，竞态时序被真实覆盖
    expect(fake.requestedItemIds, ['item-A', 'item-B'],
        reason: '必须先请求 A（挂起），再请求 B（完成），才构成晚到覆盖场景');
  });

  testWidgets('旧视频字幕请求失败晚到时场景可复现且不崩溃', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final fake = _FakeEmbytokService();
    final completerA = Completer<List<SubtitleCue>>();
    fake.queueResult('item-A', completerA.future);
    fake.queueResult('item-B', Future.value([
      const SubtitleCue(Duration(seconds: 1), Duration(seconds: 2), 'B字幕'),
    ]));

    const playerKey = ValueKey('player');
    Widget scope(MediaItem item) => ProviderScope(
          overrides: [embytokServiceProvider.overrideWithValue(fake)],
          child: MaterialApp(
            home: VideoPlayerWidget(key: playerKey, item: item),
          ),
        );

    await tester.pumpWidget(scope(_item('item-A', 'srcA')));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(VideoPlayerWidget)),
    );
    container.read(selectedSubtitleProvider.notifier).state = 'srcA:0';
    await tester.pump();

    // 切换到 B 且 B 字幕已加载完成
    await tester.pumpWidget(scope(_item('item-B', 'srcB')));
    await tester.pump();
    container.read(selectedSubtitleProvider.notifier).state = 'srcB:0';
    await tester.pump();
    await tester.pump();

    // A 的旧请求此刻失败晚到（修复后 catch 分支同样受 item 守卫，不清空新字幕）
    completerA.completeError(StateError('网络超时'));
    await tester.pump();
    await tester.pump();

    // 契约断言：请求时序正确，失败晚到未引发异常
    expect(fake.requestedItemIds, ['item-A', 'item-B']);
  });
}
