// SynologyAudioApi.restoreSession 地址规范化测试
//
// 回归：restoreSession 曾未调用 _normalizeServerUrl，导致无协议地址
// （如 192.168.1.6）直接传入 Dio 报 "No host specified in URI"。

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:embytok_flutter/services/synology_audio_api.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SynologyAudioApi.restoreSession 地址规范化', () {
    test('无协议无端口 → 补 http:// + 群晖默认端口 5000', () {
      final api = SynologyAudioApi(dio: _MockDio());
      api.restoreSession(
          serverUrl: '192.168.1.6', sid: 'sid-1', account: 'admin');
      expect(api.serverUrl, 'http://192.168.1.6:5000');
      expect(api.sid, 'sid-1');
      expect(api.account, 'admin');
    });

    test('无协议有端口 → 仅补 http://', () {
      final api = SynologyAudioApi(dio: _MockDio());
      api.restoreSession(serverUrl: '192.168.1.6:5001', sid: 'x');
      expect(api.serverUrl, 'http://192.168.1.6:5001');
    });

    test('已有 http:// 无端口 → 保持不变（信任用户输入，避免破坏 80 端口反向代理）', () {
      final api = SynologyAudioApi(dio: _MockDio());
      api.restoreSession(serverUrl: 'http://192.168.1.6', sid: 'x');
      expect(api.serverUrl, 'http://192.168.1.6');
    });

    test('已有 https:// + 端口 → 保持不变', () {
      final api = SynologyAudioApi(dio: _MockDio());
      api.restoreSession(
          serverUrl: 'https://nas.example.com:5001', sid: 'x');
      expect(api.serverUrl, 'https://nas.example.com:5001');
    });

    test('末尾斜杠被移除', () {
      final api = SynologyAudioApi(dio: _MockDio());
      api.restoreSession(serverUrl: 'http://192.168.1.6:5000/', sid: 'x');
      expect(api.serverUrl, 'http://192.168.1.6:5000');
    });
  });
}
