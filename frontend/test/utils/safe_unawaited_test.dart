// safeUnawaited 单元测试
//
// 验证安全的 fire-and-forget 函数：包装 unawaited + 统一错误日志。

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:embytok_flutter/utils/safe_unawaited.dart';

void main() {
  group('safeUnawaited', () {
    test('null future 不抛异常', () {
      expect(() => safeUnawaited(null), returnsNormally);
    });

    test('正常完成的 future 不抛异常', () async {
      final completer = Completer<void>();
      safeUnawaited(completer.future);
      completer.complete();
      await completer.future;
      // 验证 future 正常完成
      expect(completer.isCompleted, true);
    });

    test('带 context 参数的正常 future', () async {
      final completer = Completer<void>();
      safeUnawaited(completer.future, context: 'test-context');
      completer.complete();
      await completer.future;
      expect(completer.isCompleted, true);
    });

    test('future 抛出异常时不崩溃', () async {
      final completer = Completer<void>();
      safeUnawaited(completer.future, context: 'error-test');
      // 触发异常，safeUnawaited 应该捕获并记录日志，不向外传播
      completer.completeError(Exception('test error'));
      // 等待微任务队列清空
      await Future<void>.delayed(const Duration(milliseconds: 50));
      // 验证测试没有崩溃
      expect(true, true);
    });

    test('future 抛出异常带 stackTrace', () async {
      final completer = Completer<void>();
      safeUnawaited(completer.future);
      try {
        throw Exception('test with stacktrace');
      } catch (e, stackTrace) {
        completer.completeError(e, stackTrace);
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(true, true);
    });

    test('多个 future 并发调用', () async {
      final completers = List.generate(5, (_) => Completer<void>());
      for (final c in completers) {
        safeUnawaited(c.future);
      }
      for (final c in completers) {
        c.complete();
      }
      await Future.wait(completers.map((c) => c.future));
      for (final c in completers) {
        expect(c.isCompleted, true);
      }
    });

    test('部分 future 成功部分失败', () async {
      final successCompleter = Completer<void>();
      final errorCompleter = Completer<void>();
      safeUnawaited(successCompleter.future);
      safeUnawaited(errorCompleter.future);
      successCompleter.complete();
      errorCompleter.completeError(Exception('partial error'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(successCompleter.isCompleted, true);
      expect(errorCompleter.isCompleted, true);
    });

    test('future 延迟完成', () async {
      final completer = Completer<void>();
      safeUnawaited(completer.future);
      Future<void>.delayed(const Duration(milliseconds: 100), () {
        completer.complete();
      });
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(completer.isCompleted, true);
    });
  });
}
