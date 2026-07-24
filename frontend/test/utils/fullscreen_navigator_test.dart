// 验证 FullscreenNavigator 对已 disposed / 有错误 / 未初始化 controller 的防御
//
// 背景：
// - 修复前：FullscreenNavigator.open 只检查 controller == null，
//   不检查 controller 是否已 disposed 或有错误。
// - 场景：用户滑走再滑回，旧 controller 被 _backgroundReleaseTimer 释放，
//   但 currentVideoControllerProvider 仍指向已 disposed 的 controller。
//   用户点击"全屏观看"，FullscreenNavigator.open 拿到非 null 但已 disposed
//   的 controller，进入全屏页后 isControllerReady=false，黑屏。
// - 修复后：FullscreenNavigator.open 增加 isControllerUsableForFullscreen
//   防御性检查，已 disposed / 有错误 / 未初始化的 controller 不进入全屏。

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:embbytok_flutter/services/playback/i_playback_controller.dart';
import 'package:embbytok_flutter/utils/fullscreen_navigator.dart';

void main() {
  group('FullscreenNavigator.isControllerUsableForFullscreen', () {
    test('null controller 应返回 false', () {
      expect(
        FullscreenNavigator.isControllerUsableForFullscreen(null),
        isFalse,
        reason: 'null controller 不应进入全屏',
      );
    });

    test('已 disposed 的 controller（访问 getter 抛异常）应返回 false', () {
      final mockController = MockPlaybackController();
      when(mockController.hasError).thenThrow(StateError('disposed'));

      expect(
        FullscreenNavigator.isControllerUsableForFullscreen(mockController),
        isFalse,
        reason: '已 disposed 的 controller 不应进入全屏，否则全屏页黑屏',
      );
    });

    test('有错误的 controller 应返回 false', () {
      final mockController = MockPlaybackController();
      when(mockController.hasError).thenReturn(true);
      when(mockController.isInitialized).thenReturn(true);

      expect(
        FullscreenNavigator.isControllerUsableForFullscreen(mockController),
        isFalse,
        reason: '有错误的 controller 不应进入全屏',
      );
    });

    test('未初始化的 controller 应返回 false', () {
      final mockController = MockPlaybackController();
      when(mockController.isInitialized).thenReturn(false);

      expect(
        FullscreenNavigator.isControllerUsableForFullscreen(mockController),
        isFalse,
        reason: '未初始化的 controller 不应进入全屏',
      );
    });

    test('已初始化且无错误的 controller 应返回 true', () {
      final mockController = MockPlaybackController();
      when(mockController.hasError).thenReturn(false);
      when(mockController.isInitialized).thenReturn(true);
      when(mockController.duration).thenReturn(const Duration(seconds: 10));

      expect(
        FullscreenNavigator.isControllerUsableForFullscreen(mockController),
        isTrue,
        reason: '正常的 controller 应该可以进入全屏',
      );
    });
  });
}

/// Mock IPlaybackController：拦截 getter 调用
class MockPlaybackController extends Mock implements IPlaybackController {}
