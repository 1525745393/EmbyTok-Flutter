/// Person 模型测试

import 'package:flutter_test/flutter_test.dart';
import 'package:embbytok_flutter/models/person.dart';

void main() {
  group('Person', () {
    group('fromJson', () {
      test('正确解析 Emby PascalCase 字段', () {
        final json = {
          'Name': 'John Doe',
          'Id': 'person-1',
          'Role': 'Director',
          'Type': 'Director',
        };
        final person = Person.fromJson(json);
        expect(person.name, 'John Doe');
        expect(person.id, 'person-1');
        expect(person.role, 'Director');
        expect(person.type, 'Director');
      });

      test('正确解析简化 snake_case 字段', () {
        final json = {
          'name': 'Jane Smith',
          'id': 'person-2',
          'role': '主角',
          'type': 'Actor',
        };
        final person = Person.fromJson(json);
        expect(person.name, 'Jane Smith');
        expect(person.id, 'person-2');
        expect(person.role, '主角');
        expect(person.type, 'Actor');
      });

      test('空 JSON 使用默认值', () {
        final person = Person.fromJson(<String, dynamic>{});
        expect(person.name, '');
        expect(person.id, isNull);
        expect(person.role, '');
        expect(person.type, 'Actor');
      });
    });

    group('toJson', () {
      test('正确序列化为 JSON', () {
        const person = Person(
          name: 'John Doe',
          id: 'p-1',
          role: 'Director',
          type: 'Director',
          imageUrl: 'http://example.com/image.jpg',
        );
        final json = person.toJson();
        expect(json['name'], 'John Doe');
        expect(json['id'], 'p-1');
        expect(json['role'], 'Director');
        expect(json['type'], 'Director');
        expect(json['image_url'], 'http://example.com/image.jpg');
      });
    });
  });
}
