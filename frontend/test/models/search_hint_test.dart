/// SearchHint 模型测试

import 'package:flutter_test/flutter_test.dart';
import 'package:embbytok_flutter/models/search_hint.dart';

void main() {
  group('SearchHint', () {
    test('fromJson 正确解析 Emby PascalCase 字段', () {
      final json = {
        'Id': 'item-1',
        'Name': '测试电影',
        'Type': 'Movie',
        'ThumbnailUrl': 'http://example.com/thumb.jpg',
        'ProductionYear': 2023,
        'SeriesName': null,
      };
      final hint = SearchHint.fromJson(json);
      expect(hint.id, 'item-1');
      expect(hint.name, '测试电影');
      expect(hint.type, 'Movie');
      expect(hint.thumbnailUrl, 'http://example.com/thumb.jpg');
      expect(hint.year, 2023);
      expect(hint.seriesName, isNull);
    });

    test('fromJson 正确解析简化 snake_case 字段', () {
      final json = {
        'id': 'item-2',
        'name': '剧集名称',
        'type': 'Series',
        'thumbnail_url': 'http://example.com/thumb.jpg',
        'year': 2024,
        'series_name': '剧集名称',
      };
      final hint = SearchHint.fromJson(json);
      expect(hint.id, 'item-2');
      expect(hint.name, '剧集名称');
      expect(hint.type, 'Series');
      expect(hint.year, 2024);
      expect(hint.seriesName, '剧集名称');
    });

    test('空 JSON 使用默认值', () {
      final hint = SearchHint.fromJson(<String, dynamic>{});
      expect(hint.id, '');
      expect(hint.name, '');
      expect(hint.type, isNull);
      expect(hint.year, isNull);
      expect(hint.seriesName, isNull);
    });
  });
}
