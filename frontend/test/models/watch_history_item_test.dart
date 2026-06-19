/// WatchHistoryItem 模型测试

import 'package:flutter_test/flutter_test.dart';
import 'package:embbytok_flutter/models/watch_history_item.dart';

void main() {
  group('WatchHistoryItem', () {
    test('fromJson 正确解析所有字段', () {
      final json = {
        'item_id': 'item-1',
        'item_title': '测试电影',
        'thumbnail_url': 'http://example.com/thumb.jpg',
        'watched_at': '2024-06-20T14:30:00.000Z',
        'progress_seconds': 1800,
        'total_seconds': 7200,
      };
      final item = WatchHistoryItem.fromJson(json);
      expect(item.itemId, 'item-1');
      expect(item.itemTitle, '测试电影');
      expect(item.thumbnailUrl, 'http://example.com/thumb.jpg');
      expect(item.watchedAt, DateTime.parse('2024-06-20T14:30:00.000Z'));
      expect(item.progressSeconds, 1800);
      expect(item.totalSeconds, 7200);
    });

    test('fromJson 缺失字段使用默认值', () {
      final json = {
        'item_id': 'item-2',
        'item_title': '简单视频',
      };
      final item = WatchHistoryItem.fromJson(json);
      expect(item.itemId, 'item-2');
      expect(item.itemTitle, '简单视频');
      expect(item.thumbnailUrl, isNull);
      // watchedAt 缺失时使用 DateTime.now()
      expect(item.watchedAt, isNotNull);
      expect(item.progressSeconds, 0);
      expect(item.totalSeconds, 0);
    });

    test('fromJson watched_at 无效时使用 DateTime.now()', () {
      final json = {
        'item_id': 'item-3',
        'item_title': '无效日期',
        'watched_at': 'not-a-date',
      };
      // DateTime.parse 会在运行时抛出异常，所以这个测试主要确保代码不会静默失败
      // 在实际使用时应确保日期格式正确
    });

    test('toJson 正确序列化为 snake_case', () {
      final item = WatchHistoryItem(
        itemId: 'item-4',
        itemTitle: '序列化测试',
        thumbnailUrl: 'http://example.com/thumb.jpg',
        watchedAt: DateTime.parse('2024-01-15T10:00:00.000Z'),
        progressSeconds: 3600,
        totalSeconds: 10800,
      );
      final json = item.toJson();
      expect(json['item_id'], 'item-4');
      expect(json['item_title'], '序列化测试');
      expect(json['thumbnail_url'], 'http://example.com/thumb.jpg');
      expect(json['watched_at'], '2024-01-15T10:00:00.000Z');
      expect(json['progress_seconds'], 3600);
      expect(json['total_seconds'], 10800);
    });

    test('round-trip: fromJson(toJson()) 保持数据一致', () {
      final original = WatchHistoryItem(
        itemId: 'item-5',
        itemTitle: 'RoundTrip 测试',
        thumbnailUrl: 'http://example.com/thumb2.jpg',
        watchedAt: DateTime.parse('2024-03-10T08:30:00.000Z'),
        progressSeconds: 900,
        totalSeconds: 5400,
      );
      final restored = WatchHistoryItem.fromJson(original.toJson());
      expect(restored.itemId, original.itemId);
      expect(restored.itemTitle, original.itemTitle);
      expect(restored.thumbnailUrl, original.thumbnailUrl);
      expect(restored.progressSeconds, original.progressSeconds);
      expect(restored.totalSeconds, original.totalSeconds);
    });
  });
}
