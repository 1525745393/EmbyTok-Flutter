// 测试模式自身单元测试
// 覆盖：开关常量、请求抓包环形缓冲、环境覆盖 provider

import 'package:embytok_flutter/test_mode/http_capture_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HttpRequestLog 环形缓冲', () {
    late HttpRequestLog log;

    setUp(() {
      log = HttpRequestLog.instance;
      log.clear();
      log.setEnabled(true);
    });

    tearDown(() {
      log.setEnabled(false);
      log.clear();
    });

    test('初始状态为空', () {
      expect(log.records, isEmpty);
    });

    test('添加单条记录后可见', () {
      log.add(HttpRequestRecord(
        method: 'GET',
        path: '/Items/Latest',
        statusCode: 200,
        durationMs: 45,
      ));
      expect(log.records.length, 1);
      expect(log.records.first.method, 'GET');
      expect(log.records.first.statusCode, 200);
    });

    test('超过 200 条后旧记录被淘汰', () {
      for (var i = 0; i < 250; i++) {
        log.add(HttpRequestRecord(
          method: 'GET',
          path: '/test/$i',
          statusCode: 200,
          durationMs: 1,
        ));
      }
      expect(log.records.length, 200);
      // 最新记录在前面（reversed）
      expect(log.records.first.path, '/test/249');
      expect(log.records.last.path, '/test/50');
    });

    test('关闭后不记录新请求', () {
      log.setEnabled(false);
      log.add(HttpRequestRecord(
        method: 'GET',
        path: '/after',
        statusCode: 200,
        durationMs: 1,
      ));
      expect(log.records, isEmpty);
    });

    test('clear 清空所有记录', () {
      log.add(HttpRequestRecord(
        method: 'GET',
        path: '/x',
        statusCode: 200,
        durationMs: 1,
      ));
      log.clear();
      expect(log.records, isEmpty);
    });

    test('错误记录保留 error 字段', () {
      log.add(HttpRequestRecord(
        method: 'POST',
        path: '/Users/x/FavoriteItems',
        statusCode: 403,
        durationMs: 100,
        error: 'Forbidden',
      ));
      expect(log.records.first.error, 'Forbidden');
      expect(log.records.first.statusCode, 403);
    });
  });

  group('HttpRequestRecord 模型', () {
    test('time 字段自动填充为当前时间', () {
      final before = DateTime.now();
      final r = HttpRequestRecord(
        method: 'GET',
        path: '/test',
        statusCode: 200,
        durationMs: 10,
      );
      final after = DateTime.now();
      expect(r.time.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
      expect(r.time.isBefore(after.add(const Duration(seconds: 1))), isTrue);
    });
  });
}
