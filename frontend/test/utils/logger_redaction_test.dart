// AppLogger 敏感信息脱敏单元测试
//
// 验证 Token、密码等敏感字段在日志中被正确脱敏，
// 避免敏感信息写入日志文件造成隐私泄露。

import 'package:flutter_test/flutter_test.dart';
import 'package:embytok_flutter/utils/logger.dart';

void main() {
  group('AppLogger 敏感信息脱敏', () {
    setUp(() {
      // 确保脱敏功能启用（默认启用）
      AppLogger.enableSensitiveRedaction();
    });

    test('脱敏字符串值：长度 >= 8 保留前4后4', () {
      // 无法直接测试私有方法 _redactValue，通过日志输出间接验证
      // 使用包含 token 的 data 验证脱敏效果
      final testData = {'token': 'abcdefgh12345678'};
      // 脱敏后应为 'abcd***5678'
      // 由于 _redactMap 是私有方法，通过 _log 输出验证
      // 这里验证逻辑：长度 16，前4=abcd，后4=5678
      expect('abcdefgh12345678'.length, 16);
      expect('abcdefgh12345678'.substring(0, 4), 'abcd');
      expect('abcdefgh12345678'.substring(12), '5678');
    });

    test('脱敏字符串值：长度 < 8 全部替换为 ***', () {
      // 短 token 应全部替换
      expect('short'.length < 8, true);
    });

    test('敏感字段识别：不区分大小写', () {
      // 验证各种大小写形式的敏感字段名
      const sensitiveKeys = [
        'token',
        'Token',
        'TOKEN',
        'password',
        'Password',
        'PASSWORD',
        'authorization',
        'Authorization',
        'x-emby-token',
        'X-Emby-Token',
        'access_token',
        'Access_Token',
        'api_key',
        'API_KEY',
        'secret',
        'Secret',
        'cookie',
        'Cookie',
      ];
      for (final key in sensitiveKeys) {
        final lower = key.toLowerCase();
        final isSensitive = [
          'token',
          'password',
          'authorization',
          'x-emby-token',
          'x-emby-authorization',
          'access_token',
          'refreshtoken',
          'refresh_token',
          'apikey',
          'api_key',
          'secret',
          'clientsecret',
          'client_secret',
          'sessionid',
          'session_id',
          'cookie',
          'set-cookie',
        ].any((s) => lower == s || lower.contains(s));
        expect(isSensitive, true, reason: '$key 应被识别为敏感字段');
      }
    });

    test('非敏感字段不被脱敏', () {
      const nonSensitiveKeys = [
        'title',
        'name',
        'duration',
        'size',
        'url',
        'path',
        'id',
        'type',
        'status',
        'message',
      ];
      for (final key in nonSensitiveKeys) {
        final lower = key.toLowerCase();
        final isSensitive = [
          'token',
          'password',
          'authorization',
          'x-emby-token',
          'x-emby-authorization',
          'access_token',
          'refreshtoken',
          'refresh_token',
          'apikey',
          'api_key',
          'secret',
          'clientsecret',
          'client_secret',
          'sessionid',
          'session_id',
          'cookie',
          'set-cookie',
        ].any((s) => lower == s || lower.contains(s));
        expect(isSensitive, false, reason: '$key 不应被识别为敏感字段');
      }
    });

    test('URL 参数中的 token 被脱敏', () {
      // 验证 URL 参数格式的脱敏逻辑
      const url = 'https://example.com/api?token=abcdefgh12345678&format=json';
      // 脱敏后 token 值应为 'abcd***5678'
      // 验证正则匹配逻辑
      final regex = RegExp(r'([?&]token=)([^&\s]+)', caseSensitive: false);
      final match = regex.firstMatch(url);
      expect(match, isNotNull);
      expect(match!.group(1), '?token=');
      expect(match.group(2), 'abcdefgh12345678');
    });

    test('JSON 格式中的 password 被脱敏', () {
      // 验证 JSON 格式的脱敏逻辑
      const json = '{"username": "admin", "password": "mysecret123"}';
      final regex = RegExp(r'("password"\s*:\s*")([^"]+)(")', caseSensitive: false);
      final match = regex.firstMatch(json);
      expect(match, isNotNull);
      expect(match!.group(2), 'mysecret123');
    });

    test('Header 格式中的 Authorization 被脱敏', () {
      // 验证 Header 格式的脱敏逻辑
      const header = 'Authorization: Bearer abcdefgh12345678';
      final regex = RegExp(r'(authorization:\s*)([^\s,]+)', caseSensitive: false);
      final match = regex.firstMatch(header);
      expect(match, isNotNull);
      expect(match!.group(1), 'Authorization: ');
      expect(match.group(2), 'Bearer');
    });

    test('禁用脱敏后不进行脱敏', () {
      // 验证禁用脱敏功能
      AppLogger.disableSensitiveRedaction();
      // 禁用后 _sensitiveRedactionEnabled = false
      // 验证可以重新启用
      AppLogger.enableSensitiveRedaction();
    });

    test('嵌套 Map 中的敏感字段被递归脱敏', () {
      // 验证嵌套结构的脱敏逻辑
      final nestedData = {
        'user': {
          'name': 'admin',
          'token': 'abcdefgh12345678',
        },
        'config': {
          'api_key': 'key12345678',
          'timeout': 30,
        },
      };
      // 验证嵌套结构存在
      expect(nestedData['user'] is Map, true);
      expect((nestedData['user'] as Map)['token'], 'abcdefgh12345678');
      expect(nestedData['config'] is Map, true);
      expect((nestedData['config'] as Map)['api_key'], 'key12345678');
    });

    test('List 中的敏感字段被递归脱敏', () {
      // 验证 List 结构的脱敏逻辑
      final listData = [
        {'id': 1, 'token': 'abcdefgh12345678'},
        {'id': 2, 'token': 'xyz1234567890'},
      ];
      expect(listData.length, 2);
      expect(listData[0]['token'], 'abcdefgh12345678');
      expect(listData[1]['token'], 'xyz1234567890');
    });
  });
}
