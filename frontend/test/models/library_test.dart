import 'package:flutter_test/flutter_test.dart';
import 'package:embbytok_flutter/models/library.dart';

void main() {
  group('Library', () {
    group('fromJson', () {
      test('正确解析完整 JSON', () {
        final json = {
          'id': 'lib-1',
          'name': '电影',
          'type': 'movies',
          'item_count': 150,
          'cover_image_url': 'http://example.com/cover.jpg',
        };
        final library = Library.fromJson(json);
        expect(library.id, 'lib-1');
        expect(library.name, '电影');
        expect(library.type, 'movies');
        expect(library.itemCount, 150);
        expect(library.coverImageUrl, 'http://example.com/cover.jpg');
      });

      test('处理可选字段为 null', () {
        final json = {
          'id': 'lib-2',
          'name': '剧集',
          'type': 'tvshows',
        };
        final library = Library.fromJson(json);
        expect(library.id, 'lib-2');
        expect(library.name, '剧集');
        expect(library.type, 'tvshows');
        expect(library.itemCount, isNull);
        expect(library.coverImageUrl, isNull);
      });

      test('处理空 JSON', () {
        final json = <String, dynamic>{};
        final library = Library.fromJson(json);
        expect(library.id, '');
        expect(library.name, '');
        expect(library.type, '');
      });
    });

    group('toJson', () {
      test('正确序列化为 JSON', () {
        final library = Library(
          id: 'lib-1',
          name: '电影',
          type: 'movies',
          itemCount: 100,
        );
        final json = library.toJson();
        expect(json['id'], 'lib-1');
        expect(json['name'], '电影');
        expect(json['type'], 'movies');
        expect(json['item_count'], 100);
        expect(json['cover_image_url'], isNull);
      });
    });
  });
}
