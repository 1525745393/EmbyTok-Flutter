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

import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:video_player/video_player.dart';
import 'package:embytok_flutter/utils/fullscreen_navigator.dart';

void main() {
  group('FullscreenNavigator.isControllerUsableForFullscreen', () {
    test('null controller 应返回 false', () {
      expect(
        FullscreenNavigator.isControllerUsableForFullscreen(null),
        isFalse,
        reason: 'null controller 不应进入全屏',
      );
    });

    test('已 disposed 的 controller（访问 value 抛异常）应返回 false', () {
      final mockController = MockVideoPlayerController();
      // 模拟 controller 已 disposed：访问 value 抛 StateError
      when(mockController.value).thenThrow(StateError('disposed'));

      expect(
        FullscreenNavigator.isControllerUsableForFullscreen(mockController),
        isFalse,
        reason: '已 disposed 的 controller 不应进入全屏，否则全屏页黑屏',
      );
    });

    test('有错误的 controller 应返回 false', () {
      final mockController = MockVideoPlayerController();
      when(mockController.value).thenReturn(
        const VideoPlayerValue(
          duration: Duration.zero,
          isInitialized: true,
          errorDescription: 'controller error',
        ),
      );

      expect(
        FullscreenNavigator.isControllerUsableForFullscreen(mockController),
        isFalse,
        reason: '有错误的 controller 不应进入全屏',
      );
    });

    test('未初始化的 controller 应返回 false', () {
      final mockController = MockVideoPlayerController();
      when(mockController.value).thenReturn(
        const VideoPlayerValue(
          duration: Duration.zero,
          isInitialized: false,
        ),
      );

      expect(
        FullscreenNavigator.isControllerUsableForFullscreen(mockController),
        isFalse,
        reason: '未初始化的 controller 不应进入全屏',
      );
    });

    test('已初始化且无错误的 controller 应返回 true', () {
      final mockController = MockVideoPlayerController();
      when(mockController.value).thenReturn(
        const VideoPlayerValue(
          duration: Duration.zero,
          isInitialized: true,
          isPlaying: true,
          // 实现要求 size 非空才允许进入全屏，避免初始化后尺寸未就绪导致黑屏
          size: Size(1920, 1080),
        ),
      );

      expect(
        FullscreenNavigator.isControllerUsableForFullscreen(mockController),
        isTrue,
        reason: '正常的 controller 应该可以进入全屏',
      );
    });
  });
}

/// Mock VideoPlayerController：拦截 value 调用
///
/// 必须显式 override [value] getter：
/// [VideoPlayerController] 继承自 [ValueNotifier]<[VideoPlayerValue]>，
/// `value` 为 non-nullable 类型。Mock 默认通过 [noSuchMethod] 返回 null，
/// 触发 `type 'Null' is not a subtype of type 'VideoPlayerValue'` 类型错误，
/// 进而污染 mockito 内部 stub response 状态，导致后续 `when` 调用抛出
/// `Bad state: Cannot call when within a stub response`。
/// 这里通过 [super.noSuchMethod] 提供有效的 [returnValue] 兜底，避免上述问题。
class MockVideoPlayerController extends Mock implements VideoPlayerController {
  @override
  VideoPlayerValue get value => super.noSuchMethod(
        Invocation.getter(#value),
        returnValue: const VideoPlayerValue(duration: Duration.zero),
        returnValueForMissingStub:
            const VideoPlayerValue(duration: Duration.zero),
      ) as VideoPlayerValue;
}
