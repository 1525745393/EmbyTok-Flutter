// 验证 VideoPoolService 智能释放契约
//
// 由于 VideoPlayerWidget._releaseCurrentController 是私有方法且依赖 native controller，
// 此测试采用契约式验证：确认 video_pool_service.dart 暴露 returnSession 方法，
// 且 VideoPoolService 实例可调用 returnSession。
//
// 真正的回归保护来自 VideoPoolService.returnSession 的单元测试
// 和人工来回滑动验证。

import 'package:flutter_test/flutter_test.dart';
import 'package:embbytok_flutter/services/video_pool_service.dart';

void main() {
  group('VideoPoolService 智能释放契约', () {
    test('VideoPoolService 暴露 returnSession 方法', () {
      // 契约：returnSession 方法必须存在且可调用
      final pool = VideoPoolService(maxSize: 2);
      expect(pool.returnSession, isA<Function>(),
          reason: 'VideoPoolService 必须暴露 returnSession 方法供释放路径调用');
    });
  });
}
