/// PaginatedResponse 模型测试

import 'package:flutter_test/flutter_test.dart';
import 'package:embbytok_flutter/models/paginated_response.dart';
import 'package:embbytok_flutter/models/media_item.dart';

void main() {
  group('PaginatedResponse', () {
    test('fromJson 正确解析包含多个 item 的分页响应', () {
      final json = {
        'items': [
          {'Id': 'item-1', 'Name': '电影 A', 'Type': 'Movie'},
          {'Id': 'item-2', 'Name': '电影 B', 'Type': 'Movie'},
          {'Id': 'item-3', 'Name': '电影 C', 'Type': 'Movie'},
        ],
        'total': 100,
        'offset': 0,
        'limit': 20,
      };

      final response = PaginatedResponse.fromJson(
        json,
        (e) => MediaItem.fromJson(e as Map<String, dynamic>),
      );

      expect(response.items, hasLength(3));
      expect(response.total, 100);
      expect(response.offset, 0);
      expect(response.limit, 20);
      expect(response.items[0].id, 'item-1');
      expect(response.items[1].title, '电影 B');
      expect(response.items[2].type, 'Movie');
    });

    test('fromJson items 为空时返回空列表', () {
      final json = {
        'items': <Map<String, dynamic>>[],
        'total': 0,
        'offset': 10,
        'limit': 20,
      };
      final response = PaginatedResponse.fromJson(
        json,
        (e) => MediaItem.fromJson(e as Map<String, dynamic>),
      );
      expect(response.items, isEmpty);
      expect(response.total, 0);
      expect(response.offset, 10);
      expect(response.limit, 20);
    });

    test('fromJson items 为 null 时返回空列表', () {
      final json = {
        'items': null,
        'total': 50,
      };
      final response = PaginatedResponse.fromJson(
        json,
        (e) => MediaItem.fromJson(e as Map<String, dynamic>),
      );
      expect(response.items, isEmpty);
      expect(response.total, 50);
    });

    test('fromJson 缺失字段使用默认值', () {
      final json = <String, dynamic>{};
      final response = PaginatedResponse.fromJson(
        json,
        (e) => MediaItem.fromJson(e as Map<String, dynamic>),
      );
      expect(response.items, isEmpty);
      expect(response.total, 0);
      expect(response.offset, 0);
      expect(response.limit, 20); // 常量默认值
    });

    test('toJson 正确序列化', () {
      final item1 = MediaItem(id: 'a', title: 'A', type: 'Movie');
      final item2 = MediaItem(id: 'b', title: 'B', type: 'Movie');
      final response = PaginatedResponse<MediaItem>(
        items: [item1, item2],
        total: 200,
        offset: 40,
        limit: 20,
      );
      final json = response.toJson();
      expect(json['items'], hasLength(2));
      expect(json['total'], 200);
      expect(json['offset'], 40);
      expect(json['limit'], 20);
    });
  });
}
