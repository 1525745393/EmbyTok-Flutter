// 统一指数退避重试工具
//
// 原实现曾重复存在于 EmbyServerApiBase._retry 与 EmbytokServiceBase._retry
// （同一算法两套代码，架构审查发现）。收敛为单一公共函数后，两层调用点共用此处，
// 避免同类问题各写一套（用户维护原则：单一实现）。
//
// - maxAttempts: 最多尝试次数（含首次），默认 3 次
// - initialDelayMs: 初始延迟毫秒数，每次翻倍，带 50% 抖动
// - operationName: 日志标识，便于按操作名检索失败重试记录

import 'dart:math';

import 'logger.dart';

Future<void> retryWithBackoff(
  Future<void> Function() fn, {
  int maxAttempts = 3,
  int initialDelayMs = 1000,
  String operationName = 'operation',
}) async {
  var attempt = 0;
  var delay = initialDelayMs;
  final random = Random();
  while (true) {
    attempt++;
    try {
      await fn();
      return; // 成功
    } catch (e) {
      if (attempt >= maxAttempts) {
        AppLogger.warn('$operationName 失败（$maxAttempts 次尝试均失败）',
            data: {'error': e.toString()});
        rethrow;
      }
      // 指数退避 + 50% 随机抖动，避免多设备同时重试产生雪崩
      final jitter = (delay * 0.5 * random.nextDouble()).toInt();
      final waitMs = delay + jitter;
      AppLogger.debug('$operationName 第 $attempt 次失败，${waitMs}ms 后重试',
          data: {'error': e.toString()});
      await Future<void>.delayed(Duration(milliseconds: waitMs));
      delay *= 2;
    }
  }
}
