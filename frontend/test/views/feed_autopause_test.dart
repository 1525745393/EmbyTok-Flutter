// 验证 Feed Tab 可见性判定 + HomeScaffold 切 Tab 时视频自动暂停
//
// 背景：
// - HomeScaffold 用 IndexedStack 同时保持 Feed / Favorites / Actors / Settings
//   四个 Tab 视图存活，切换 Tab 不会触发 deactivate/activate。
// - 修复前：切到非 Feed Tab 时播放控制器仍处于 playing，
//   视频在后台继续播放/消耗流量/发热。
// - 修复后：HomeScaffold 监听 pageNavigationProvider 变化，
//   当 Feed 刚被隐藏时主动 controller.pause()，重新可见时如果用户
//   原本"想播放"（isPlayingProvider=true）则 controller.play()。
//
// 测试策略：核心逻辑已抽到顶层纯函数 applyFeedVisibilityChange，
// 用 mockito mock IPlaybackController 验证 pause/play 调用。

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:embbytok_flutter/services/playback/i_playback_controller.dart';
import 'package:embbytok_flutter/providers/providers.dart';
import 'package:embbytok_flutter/views/home_scaffold.dart';

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

    test('搜索覆盖层（isOverlayPage=true, currentIndex=search）: 仍可见', () {
      // 覆盖层页面是显示在 Feed 之上的浮层，主体 IndexedStack 仍展示 Feed
      const state = PageNavigationState(
        currentIndex: PageIndices.search,
        isOverlayPage: true,
      );
      expect(state.isFeedVisible, isTrue);
    });

    test('历史覆盖层（isOverlayPage=true, currentIndex=history）: 仍可见', () {
      const state = PageNavigationState(
        currentIndex: PageIndices.history,
        isOverlayPage: true,
      );
      expect(state.isFeedVisible, isTrue);
    });
  });

  group('applyFeedVisibilityChange：核心 pause/play 决策', () {
    // 用 mockito 拦截 pause()/play() 调用，验证决策正确性

    late MockPlaybackController mockController;

    /// 设置一个"已初始化且正在播放"的 mock controller
    void stubPlaying(MockPlaybackController ctrl) {
      when(ctrl.isInitialized).thenReturn(true);
      when(ctrl.isPlaying).thenReturn(true);
    }

    /// 设置一个"已初始化但已暂停"的 mock controller
    void stubPaused(MockPlaybackController ctrl) {
      when(ctrl.isInitialized).thenReturn(true);
      when(ctrl.isPlaying).thenReturn(false);
    }

    setUp(() {
      mockController = MockPlaybackController();
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

    test('Feed → 搜索覆盖层：可见性未变 → 不调用任何 controller 方法', () {
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

      verifyNever(mockController.pause());
      verifyNever(mockController.play());
    });

    test('Feed → 历史覆盖层：可见性未变 → 不调用任何 controller 方法', () {
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

      verifyNever(mockController.pause());
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
      // 模拟 controller 存在但 isInitialized=false
      when(mockController.isInitialized).thenReturn(false);
      when(mockController.isPlaying).thenReturn(false);

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

/// Mock IPlaybackController：拦截 pause/play 调用
///
/// IPlaybackController 是抽象接口，单元测试中用 mockito Mock 类拦截方法调用。
class MockPlaybackController extends Mock implements IPlaybackController {}
