import 'package:flutter_test/flutter_test.dart';
import 'package:embbytok_flutter/models/media_item.dart';

void main() {
  group('MediaItem', () {
    group('fromJson', () {
      test('正确解析完整 JSON', () {
        final json = {
          'id': 'item-1',
          'title': '测试电影',
          'type': 'Movie',
          'duration_seconds': 7200.0,
          'thumbnail_url': 'http://example.com/thumb.jpg',
          'overview': '这是一部测试电影',
          'year': 2023,
          'rating': 8.5,
          'genres': ['动作', '科幻'],
          'playback_url': 'http://example.com/video.mp4',
        };
        final item = MediaItem.fromJson(json);
        expect(item.id, 'item-1');
        expect(item.title, '测试电影');
        expect(item.type, 'Movie');
        expect(item.durationSeconds, 7200.0);
        expect(item.thumbnailUrl, 'http://example.com/thumb.jpg');
        expect(item.overview, '这是一部测试电影');
        expect(item.year, 2023);
        expect(item.rating, 8.5);
        expect(item.genres, ['动作', '科幻']);
        expect(item.playbackUrl, 'http://example.com/video.mp4');
      });

      test('处理可选字段为 null', () {
        final json = {
          'id': 'item-2',
          'title': '简单视频',
          'type': 'Episode',
        };
        final item = MediaItem.fromJson(json);
        expect(item.id, 'item-2');
        expect(item.title, '简单视频');
        expect(item.type, 'Episode');
        expect(item.durationSeconds, isNull);
        expect(item.thumbnailUrl, isNull);
        expect(item.overview, isNull);
        expect(item.year, isNull);
        expect(item.rating, isNull);
        expect(item.genres, isNull);
        expect(item.playbackUrl, isNull);
      });

      test('处理空 JSON', () {
        final json = <String, dynamic>{};
        final item = MediaItem.fromJson(json);
        expect(item.id, '');
        expect(item.title, '');
        expect(item.type, '');
      });

      test('正确解析 genres 列表', () {
        final json = {
          'id': 'item-3',
          'title': '测试',
          'type': 'Movie',
          'genres': ['喜剧', '爱情', '动画'],
        };
        final item = MediaItem.fromJson(json);
        expect(item.genres, hasLength(3));
        expect(item.genres, containsAll(['喜剧', '爱情', '动画']));
      });
    });

    group('toJson', () {
      test('正确序列化为 JSON', () {
        final item = MediaItem(
          id: 'item-1',
          title: '测试',
          type: 'Movie',
          durationSeconds: 3600.0,
          year: 2024,
        );
        final json = item.toJson();
        expect(json['id'], 'item-1');
        expect(json['title'], '测试');
        expect(json['type'], 'Movie');
        expect(json['duration_seconds'], 3600.0);
        expect(json['year'], 2024);
        expect(json['thumbnail_url'], isNull);
      });
    });
  });
}
