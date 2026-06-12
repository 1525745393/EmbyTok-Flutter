import 'package:flutter_test/flutter_test.dart';
import 'package:embbytok_flutter/models/paginated_response.dart';
import 'package:embbytok_flutter/models/media_item.dart';

void main() {
  group('PaginatedResponse', () {
    group('fromJson', () {
      test('正确解析分页响应', () {
        final json = {
          'items': [
            {'id': 'item-1', 'title': '视频1', 'type': 'Movie'},
            {'id': 'item-2', 'title': '视频2', 'type': 'Episode'},
          ],
          'total': 100,
          'offset': 0,
          'limit': 20,
        };
        final response = PaginatedResponse<MediaItem>.fromJson(
          json,
          (e) => MediaItem.fromJson(e as Map<String, dynamic>),
        );
        expect(response.items, hasLength(2));
        expect(response.items[0].id, 'item-1');
        expect(response.items[1].title, '视频2');
        expect(response.total, 100);
        expect(response.offset, 0);
        expect(response.limit, 20);
      });

      test('处理空列表', () {
        final json = {
          'items': <dynamic>[],
          'total': 0,
          'offset': 0,
          'limit': 20,
        };
        final response = PaginatedResponse<MediaItem>.fromJson(
          json,
          (e) => MediaItem.fromJson(e as Map<String, dynamic>),
        );
        expect(response.items, isEmpty);
        expect(response.total, 0);
      });

      test('处理缺失 items 字段', () {
        final json = <String, dynamic>{
          'total': 50,
        };
        final response = PaginatedResponse<MediaItem>.fromJson(
          json,
          (e) => MediaItem.fromJson(e as Map<String, dynamic>),
        );
        expect(response.items, isEmpty);
        expect(response.total, 50);
        expect(response.offset, 0);
        expect(response.limit, 20);
      });

      test('处理分页参数默认值', () {
        final json = {
          'items': <dynamic>[],
        };
        final response = PaginatedResponse<MediaItem>.fromJson(
          json,
          (e) => MediaItem.fromJson(e as Map<String, dynamic>),
        );
        expect(response.total, 0);
        expect(response.offset, 0);
        expect(response.limit, 20);
      });
    });

    group('toJson', () {
      test('正确序列化', () {
        final response = PaginatedResponse<MediaItem>(
          items: [
            MediaItem(id: '1', title: 'A', type: 'Movie'),
          ],
          total: 1,
          offset: 0,
          limit: 20,
        );
        final json = response.toJson();
        expect(json['total'], 1);
        expect(json['offset'], 0);
        expect(json['limit'], 20);
      });
    });
  });
}
