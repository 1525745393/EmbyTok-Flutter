/// AppConfig 模型测试

import 'package:flutter_test/flutter_test.dart';
import 'package:embbytok_flutter/models/app_config.dart';

void main() {
  group('AppConfig', () {
    test('fromJson 正确解析所有字段', () {
      final json = {
        'backend_url': 'http://backend.example.com',
        'emby_server_url': 'http://emby.example.com',
        'user_id': 'user-123',
        'user_name': 'testuser',
        'theme_mode': 'dark',
        'subtitle_enabled': true,
      };
      final config = AppConfig.fromJson(json);
      expect(config.backendUrl, 'http://backend.example.com');
      expect(config.embyServerUrl, 'http://emby.example.com');
      expect(config.userId, 'user-123');
      expect(config.userName, 'testuser');
      expect(config.themeMode, 'dark');
      expect(config.subtitleEnabled, true);
    });

    test('fromJson 缺失字段使用默认值', () {
      final config = AppConfig.fromJson(<String, dynamic>{});
      expect(config.backendUrl, '');
      expect(config.embyServerUrl, '');
      expect(config.userId, '');
      expect(config.userName, '');
      expect(config.themeMode, 'system');
      expect(config.subtitleEnabled, false);
    });

    test('toJson 正确序列化为 snake_case', () {
      final config = AppConfig(
        backendUrl: 'http://backend.example.com',
        embyServerUrl: 'http://emby.example.com',
        userId: 'user-456',
        userName: 'anotheruser',
        themeMode: 'light',
        subtitleEnabled: true,
      );
      final json = config.toJson();
      expect(json['backend_url'], 'http://backend.example.com');
      expect(json['emby_server_url'], 'http://emby.example.com');
      expect(json['user_id'], 'user-456');
      expect(json['user_name'], 'anotheruser');
      expect(json['theme_mode'], 'light');
      expect(json['subtitle_enabled'], true);
    });

    test('round-trip: fromJson(toJson()) 保持数据一致', () {
      final original = AppConfig(
        backendUrl: 'http://backend.example.com',
        embyServerUrl: 'http://emby.example.com',
        userId: 'user-789',
        userName: 'roundtrip',
        themeMode: 'dark',
        subtitleEnabled: false,
      );
      final restored = AppConfig.fromJson(original.toJson());
      expect(restored.backendUrl, original.backendUrl);
      expect(restored.embyServerUrl, original.embyServerUrl);
      expect(restored.userId, original.userId);
      expect(restored.userName, original.userName);
      expect(restored.themeMode, original.themeMode);
      expect(restored.subtitleEnabled, original.subtitleEnabled);
    });
  });
}
