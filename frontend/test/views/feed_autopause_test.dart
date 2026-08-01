// 验证 Feed Tab 可见性判定 + HomeScaffold 切 Tab 时视频自动暂停
//
// 背景：
// - HomeScaffold 用 IndexedStack 同时保持 Feed / Favorites / Actors / Settings
//   四个 Tab 视图存活，切换 Tab 不会触发 deactivate/activate。
// - 修复前：切到非 Feed Tab 时 VideoPlayerController 仍处于 playing，
//   视频在后台继续播放/消耗流量/发热。
// - 修复后：HomeScaffold 监听 pageNavigationProvider 变化，
//   当 Feed 刚被隐藏时主动 controller.pause()，重新可见时如果用户
//   原本"想播放"（isPlayingProvider=true）则 controller.play()。
//
// 测试策略：核心逻辑已抽到顶层纯函数 applyFeedVisibilityChange，
// 用 mockito mock VideoPlayerController 验证 pause/play 调用。

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:video_player/video_player.dart';
import 'package:embytok_flutter/providers/providers.dart';
import 'package:embytok_flutter/views/home_scaffold.dart';

void main() {
  group('PageNavigationState.isFeedVisible：Feed Tab 可见性判定', () {
    test('默认（首页）: 可见', () {
      const state = PageNavigationState();
      expect(state.isFeedVisible, isTrue);
    });

    test('切到收藏 Tab: 不可见', () {
      const state = PageNavigationState(currentIndex: PageIndices.favorites);
      expect(state.isFeedVisible, isFalse);
    });

    test('切到演员 Tab: 不可见', () {
      const state = PageNavigationState(currentIndex: PageIndices.actors);
      expect(state.isFeedVisible, isFalse);
    });

    test('切到设置 Tab: 不可见', () {
      const state = PageNavigationState(currentIndex: PageIndices.settings);
      expect(state.isFeedVisible, isFalse);
    });

    test('搜索覆盖层（isOverlayPage=true, currentIndex=search）: 不可见', () {
      // 实现中 isFeedVisible 仅判断 currentIndex == PageIndices.feed，
      // 覆盖层 currentIndex=search(4) ≠ feed(0)，故视为不可见。
      // 注：与"覆盖层显示在 Feed 之上"的 UI 直觉不同，此处以实现逻辑为准。
      const state = PageNavigationState(
        currentIndex: PageIndices.search,
        isOverlayPage: true,
      );
      expect(state.isFeedVisible, isFalse);
    });

    test('历史覆盖层（isOverlayPage=true, currentIndex=history）: 不可见', () {
      // 同上：currentIndex=history(5) ≠ feed(0)，isFeedVisible=false
      const state = PageNavigationState(
        currentIndex: PageIndices.history,
        isOverlayPage: true,
      );
      expect(state.isFeedVisible, isFalse);
    });
  });

  group('applyFeedVisibilityChange：核心 pause/play 决策', () {
    // 用 mockito 拦截 pause()/play() 调用，验证决策正确性

    late MockVideoPlayerController mockController;

    /// 设置一个"已初始化且正在播放"的 mock controller
    void stubPlaying(MockVideoPlayerController ctrl) {
      when(ctrl.value).thenReturn(
        const VideoPlayerValue(
          duration: Duration.zero,
          isInitialized: true,
          isPlaying: true,
        ),
      );
    }

    /// 设置一个"已初始化但已暂停"的 mock controller
    void stubPaused(MockVideoPlayerController ctrl) {
      when(ctrl.value).thenReturn(
        const VideoPlayerValue(
          duration: Duration.zero,
          isInitialized: true,
          isPlaying: false,
        ),
      );
    }

    setUp(() {
      mockController = MockVideoPlayerController();
    });

    test('Feed 切到收藏 Tab：controller.pause() 被调用', () {
      stubPlaying(mockController);

      const prev = PageNavigationState(); // Feed
      const next = PageNavigationState(currentIndex: PageIndices.favorites);

      applyFeedVisibilityChange(
        prev: prev,
        next: next,
        controller: mockController,
        userWantsToPlay: true,
      );

      verify(mockController.pause()).called(1);
      verifyNever(mockController.play());
    });

    test('Feed 切到演员 Tab：controller.pause() 被调用', () {
      stubPlaying(mockController);

      const prev = PageNavigationState();
      const next = PageNavigationState(currentIndex: PageIndices.actors);

      applyFeedVisibilityChange(
        prev: prev,
        next: next,
        controller: mockController,
        userWantsToPlay: true,
      );

      verify(mockController.pause()).called(1);
    });

    test('Feed 切到设置 Tab：controller.pause() 被调用', () {
      stubPlaying(mockController);

      const prev = PageNavigationState();
      const next = PageNavigationState(currentIndex: PageIndices.settings);

      applyFeedVisibilityChange(
        prev: prev,
        next: next,
        controller: mockController,
        userWantsToPlay: true,
      );

      verify(mockController.pause()).called(1);
    });

    test('从其他 Tab 切回 Feed 且用户想播放：controller.play() 被调用', () {
      // 模拟 controller 已暂停（切到其他 Tab 时被 pause 了）
      stubPaused(mockController);

      const prev = PageNavigationState(currentIndex: PageIndices.favorites);
      const next = PageNavigationState(); // back to Feed

      applyFeedVisibilityChange(
        prev: prev,
        next: next,
        controller: mockController,
        userWantsToPlay: true, // 用户原本想播放
      );

      verify(mockController.play()).called(1);
      verifyNever(mockController.pause());
    });

    test('从其他 Tab 切回 Feed 但用户已主动暂停：不调用 play()', () {
      // 关键场景：用户主动暂停后切到其他 Tab 再切回
      // 不应覆盖用户的"暂停意图"自动恢复播放
      stubPaused(mockController);

      const prev = PageNavigationState(currentIndex: PageIndices.favorites);
      const next = PageNavigationState();

      applyFeedVisibilityChange(
        prev: prev,
        next: next,
        controller: mockController,
        userWantsToPlay: false, // 用户已主动暂停
      );

      verifyNever(mockController.play());
      verifyNever(mockController.pause());
    });

    test('Feed → 搜索覆盖层：isFeedVisible 变化 → 调用 pause', () {
      // 实现中 isFeedVisible 仅判断 currentIndex == feed，
      // 覆盖层 currentIndex=search 视为不可见，故从 Feed 切到搜索覆盖层
      // 会被 applyFeedVisibilityChange 当作"Feed 被隐藏"而触发 pause。
      stubPlaying(mockController);

      const prev = PageNavigationState(); // Feed
      const next = PageNavigationState(
        currentIndex: PageIndices.search,
        isOverlayPage: true,
      );

      applyFeedVisibilityChange(
        prev: prev,
        next: next,
        controller: mockController,
        userWantsToPlay: true,
      );

      verify(mockController.pause()).called(1);
      verifyNever(mockController.play());
    });

    test('Feed → 历史覆盖层：isFeedVisible 变化 → 调用 pause', () {
      // 同上：覆盖层 currentIndex=history 视为不可见，触发 pause
      stubPlaying(mockController);

      const prev = PageNavigationState();
      const next = PageNavigationState(
        currentIndex: PageIndices.history,
        isOverlayPage: true,
      );

      applyFeedVisibilityChange(
        prev: prev,
        next: next,
        controller: mockController,
        userWantsToPlay: true,
      );

      verify(mockController.pause()).called(1);
      verifyNever(mockController.play());
    });

    test('controller 为 null：不抛异常，不调用任何方法', () {
      const prev = PageNavigationState();
      const next = PageNavigationState(currentIndex: PageIndices.favorites);

      expect(
        () => applyFeedVisibilityChange(
          prev: prev,
          next: next,
          controller: null,
          userWantsToPlay: true,
        ),
        returnsNormally,
      );
    });

    test('controller 未初始化：不调用任何方法', () {
      // 模拟 controller 存在但 value.isInitialized=false
      when(mockController.value).thenReturn(
        const VideoPlayerValue(
          duration: Duration.zero,
          isInitialized: false,
          isPlaying: false,
        ),
      );

      const prev = PageNavigationState();
      const next = PageNavigationState(currentIndex: PageIndices.favorites);

      applyFeedVisibilityChange(
        prev: prev,
        next: next,
        controller: mockController,
        userWantsToPlay: true,
      );

      verifyNever(mockController.pause());
      verifyNever(mockController.play());
    });

    test('controller 已暂停时切到其他 Tab：不重复调用 pause()', () {
      // 防御性：避免重复 pause 引起 controller 内部状态异常
      stubPaused(mockController);

      const prev = PageNavigationState();
      const next = PageNavigationState(currentIndex: PageIndices.favorites);

      applyFeedVisibilityChange(
        prev: prev,
        next: next,
        controller: mockController,
        userWantsToPlay: true,
      );

      verifyNever(mockController.pause());
    });

    test('切到其他 Tab 时如果已经在播：调用 pause；切回时如果想播：调用 play', () {
      // 完整往返流程
      stubPlaying(mockController);

      // 1. Feed → 收藏：pause
      applyFeedVisibilityChange(
        prev: const PageNavigationState(),
        next: const PageNavigationState(currentIndex: PageIndices.favorites),
        controller: mockController,
        userWantsToPlay: true,
      );
      verify(mockController.pause()).called(1);

      // 2. 模拟 controller 状态变更（pause 后 isPlaying=false）
      stubPaused(mockController);

      // 3. 收藏 → Feed：play
      applyFeedVisibilityChange(
        prev: const PageNavigationState(currentIndex: PageIndices.favorites),
        next: const PageNavigationState(),
        controller: mockController,
        userWantsToPlay: true,
      );
      verify(mockController.play()).called(1);
    });
  });
}

/// Mock VideoPlayerController：拦截 pause/play/value 调用
///
/// video_player 包的 controller 依赖 native platform channel，
/// 单元测试中无法构造真实实例。用 mockito Mock 类拦截方法调用。
///
/// 必须显式 override [value] getter 与 [pause]/[play] 方法：
/// 这些成员的返回类型均为 non-nullable（[VideoPlayerValue] / [Future]<void>）。
/// Mock 默认通过 [noSuchMethod] 返回 null，会触发类型错误
/// （`type 'Null' is not a subtype of type ...`），进而污染 mockito 内部
/// stub response / verification 状态，导致后续 `when`/`verify` 调用抛出
/// `Bad state: Cannot call when within a stub response` 或
/// `Bad state: Verification appears to be in progress`。
/// 这里通过 [super.noSuchMethod] 提供有效的 [returnValue] 兜底，避免上述问题。
class MockVideoPlayerController extends Mock implements VideoPlayerController {
  @override
  VideoPlayerValue get value => super.noSuchMethod(
        Invocation.getter(#value),
        returnValue: const VideoPlayerValue(duration: Duration.zero),
        returnValueForMissingStub:
            const VideoPlayerValue(duration: Duration.zero),
      ) as VideoPlayerValue;

  @override
  Future<void> pause() => super.noSuchMethod(
        Invocation.method(#pause, []),
        returnValue: Future<void>.value(),
        returnValueForMissingStub: Future<void>.value(),
      ) as Future<void>;

  @override
  Future<void> play() => super.noSuchMethod(
        Invocation.method(#play, []),
        returnValue: Future<void>.value(),
        returnValueForMissingStub: Future<void>.value(),
      ) as Future<void>;
}
