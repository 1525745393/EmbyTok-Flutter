/// 视频流位置持久化单元测试
///
/// 覆盖：
/// - saveFeedVideoPosition：正常保存 index+itemId
/// - saveFeedVideoPosition：越界保护（PageView 末尾「加载更多」占位页
///   index == items.length 时不保存，避免恢复时 index 越界错位）
/// - saveFeedVideoPosition：index < 0 时不保存
/// - readFeedVideoPosition：无记录时返回 (index: 0, itemId: null)
/// - readFeedVideoPosition：读取已保存的 index+itemId
///
/// 背景：首页视频流「重新打开恢复上次位置」异常审查后的回归测试。
/// 修复前保存逻辑在 index 越界（占位页）时会写入越界 index 但丢弃 itemId，
/// 重启后 itemId 为空 → 按旧 index 近似恢复 → 列表变化后跳到错误视频。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:embytok_flutter/models/models.dart';
import 'package:embytok_flutter/utils/constants.dart';
import 'package:embytok_flutter/viewmodels/feed_view_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MediaItem item(String id) => MediaItem(
        id: id,
        title: 'video-$id',
        type: 'Movie',
      );

  group('saveFeedVideoPosition 越界保护', () {
    test('正常范围内保存 index + itemId', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final items = [item('a'), item('b'), item('c')];

      await FeedViewModel.saveFeedVideoPosition(prefs, 2, items);

      expect(prefs.getInt(kStorageKeyLastFeedVideoIndex), 2);
      expect(prefs.getString(kStorageKeyLastFeedVideoItemId), 'c');
    });

    test('index 越界（加载更多占位页）时不保存', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final items = [item('a'), item('b')];

      // PageView 末尾占位页：index == items.length
      await FeedViewModel.saveFeedVideoPosition(prefs, 2, items);

      expect(prefs.getInt(kStorageKeyLastFeedVideoIndex), isNull);
      expect(prefs.getString(kStorageKeyLastFeedVideoItemId), isNull);
    });

    test('index 为负数时不保存', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final items = [item('a')];

      await FeedViewModel.saveFeedVideoPosition(prefs, -1, items);

      expect(prefs.getInt(kStorageKeyLastFeedVideoIndex), isNull);
      expect(prefs.getString(kStorageKeyLastFeedVideoItemId), isNull);
    });

    test('空列表时不保存', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await FeedViewModel.saveFeedVideoPosition(prefs, 0, const []);

      expect(prefs.getInt(kStorageKeyLastFeedVideoIndex), isNull);
      expect(prefs.getString(kStorageKeyLastFeedVideoItemId), isNull);
    });

    test('保存会同时更新 index 与 itemId（覆盖旧值）', () async {
      SharedPreferences.setMockInitialValues({
        kStorageKeyLastFeedVideoIndex: 0,
        kStorageKeyLastFeedVideoItemId: 'old',
      });
      final prefs = await SharedPreferences.getInstance();
      final items = [item('a'), item('b')];

      await FeedViewModel.saveFeedVideoPosition(prefs, 1, items);

      expect(prefs.getInt(kStorageKeyLastFeedVideoIndex), 1);
      expect(prefs.getString(kStorageKeyLastFeedVideoItemId), 'b');
    });
  });

  group('网格滚动位置持久化（saveGridScrollOffsetNow / readGridScrollOffset）', () {
    test('保存后能读回', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await FeedViewModel.saveGridScrollOffsetNow(prefs, 12345.0);

      expect(await FeedViewModel.readGridScrollOffset(prefs), 12345.0);
    });

    test('无记录时返回 null', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      expect(await FeedViewModel.readGridScrollOffset(prefs), isNull);
    });

    test('写入 0 视为无效（恢复端 >0 才生效）', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await FeedViewModel.saveGridScrollOffsetNow(prefs, 0.0);

      expect(await FeedViewModel.readGridScrollOffset(prefs), isNull);
    });
  });

  group('readFeedVideoPosition', () {
    test('无记录时返回默认 (0, null)', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final pos = FeedViewModel.readFeedVideoPosition(prefs);

      expect(pos.index, 0);
      expect(pos.itemId, isNull);
    });

    test('读取已保存的 index + itemId', () async {
      SharedPreferences.setMockInitialValues({
        kStorageKeyLastFeedVideoIndex: 7,
        kStorageKeyLastFeedVideoItemId: 'video-7',
      });
      final prefs = await SharedPreferences.getInstance();

      final pos = FeedViewModel.readFeedVideoPosition(prefs);

      expect(pos.index, 7);
      expect(pos.itemId, 'video-7');
    });
  });
}
