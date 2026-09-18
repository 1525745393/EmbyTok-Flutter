/// 视频流位置「生命周期兜底写盘」回归测试
///
/// 背景（P2 审查发现）：
/// - 修复前：AppLifecycleListener 在 inactive/paused/detached 时无条件调用
///   _saveFeedPositionOnBackground，启动恢复跳转完成前（_currentIndex 仍为 0）
///   退后台会用 index 0 覆盖已持久化的上次位置，导致下次启动从第一个视频开始。
/// - 修复后：新增 _feedPositionReady 标记，只有「恢复跳转完成」或「用户主动
///   翻过页」（onPageChanged 触发）后才允许生命周期写盘。
///
/// 测试策略：pump FeedView（未认证 → ErrorStateCard，不构建播放器/PageView），
/// 注入非空 videoListProvider + 预置上次位置 (index:5, itemId:'f')。
/// 触发 inactive 后断言持久化位置未被覆盖。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:embytok_flutter/models/models.dart';
import 'package:embytok_flutter/providers/providers.dart';
import 'package:embytok_flutter/utils/constants.dart';
import 'package:embytok_flutter/views/feed_view.dart';

/// 测试用 VideoListNotifier：继承真实 Notifier，构造后直接注入预设状态
class _FakeVideoListNotifier extends VideoListNotifier {
  _FakeVideoListNotifier(super.ref, VideoListState initialState) {
    state = initialState;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildFeed() {
    return ProviderScope(
      overrides: [
        videoListProvider.overrideWith(
          (ref) => _FakeVideoListNotifier(
            ref,
            VideoListState(
              items: const [MediaItem(id: 'a', title: 'a', type: 'Movie')],
              hasMore: false,
              isLoading: false,
            ),
          ),
        ),
      ],
      child: const MaterialApp(home: FeedView()),
    );
  }

  testWidgets('恢复完成前退后台：不覆盖已持久化的上次位置', (tester) async {
    // 预置上次位置：index 5 + itemId 'f'（当前列表中没有该 id）
    SharedPreferences.setMockInitialValues({
      kStorageKeyLastFeedVideoIndex: 5,
      kStorageKeyLastFeedVideoItemId: 'f',
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(buildFeed());
    // 推进恢复循环：_restoreFeedVideoIndex 每次迭代 await 500ms（最多 20 次）。
    // 这里推进 600ms 使第一次迭代 break（items 非空且未加载中），并清空 pending Timer。
    await tester.pump(const Duration(milliseconds: 600));
    // 等待 postFrame 恢复逻辑执行完毕（_restoreFeedVideoIndex 因列表不含 'f' 返回 false）
    await tester.pumpAndSettle();

    // 触发退后台（inactive → AppLifecycleListener 回调 → _saveFeedPositionOnBackground）
    tester.binding
        .handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    tester.binding
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed);

    // 未恢复/未翻页 → _feedPositionReady == false → 不应写盘
    expect(prefs.getInt(kStorageKeyLastFeedVideoIndex), 5,
        reason: '恢复完成前退后台不得用默认 index 覆盖已保存位置');
    expect(prefs.getString(kStorageKeyLastFeedVideoItemId), 'f');
  });
}
