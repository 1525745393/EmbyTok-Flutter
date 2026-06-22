import 'package:flutter_test/flutter_test.dart';
import 'package:embbytok_flutter/models/user.dart';

void main() {
  group('User', () {
    group('fromJson', () {
      test('正确解析完整 JSON', () {
        final json = {
          'user_id': 'user-123',
          'username': 'testuser',
          'access_token': 'token-abc',
        };
        final user = User.fromJson(json);
        expect(user.id, 'user-123');
        expect(user.name, 'testuser');
        expect(user.accessToken, 'token-abc');
      });

      test('处理缺失字段（使用默认值）', () {
        final json = <String, dynamic>{};
        final user = User.fromJson(json);
        expect(user.id, '');
        expect(user.name, '');
        expect(user.accessToken, '');
      });

      test('处理 null 值', () {
        final json = {
          'user_id': null,
          'username': null,
          'access_token': null,
        };
        final user = User.fromJson(json);
        expect(user.id, '');
        expect(user.name, '');
        expect(user.accessToken, '');
      });
    });

    group('toJson', () {
      test('正确序列化为 JSON', () {
        final user = User(
          id: 'user-123',
          name: 'testuser',
          accessToken: 'token-abc',
        );
        final json = user.toJson();
        expect(json['user_id'], 'user-123');
        expect(json['username'], 'testuser');
        expect(json['access_token'], 'token-abc');
      });

      test('fromJson -> toJson 往返一致性', () {
        final original = {
          'user_id': 'user-456',
          'username': 'another',
          'access_token': 'token-xyz',
        };
        final user = User.fromJson(original);
        final json = user.toJson();
        expect(json['user_id'], original['user_id']);
        expect(json['username'], original['username']);
        expect(json['access_token'], original['access_token']);
      });
    });
  });
}
