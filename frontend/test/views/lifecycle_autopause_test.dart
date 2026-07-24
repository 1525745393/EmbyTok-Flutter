// 验证 App 切后台时 Feed 视频自动暂停 / 回前台时按条件恢复
//
// 背景：
// - 用户反馈：App 切到后台（按 Home 键 / 切换应用 / 来电）时，Feed 中的视频
//   仍在后台继续播放，消耗流量 / 电池 / 发热。
// - 修复前：HomeScaffold 没有监听 WidgetsBindingObserver，
//   切后台时播放控制器仍处于 playing。
// - 修复后：HomeScaffold 混入 WidgetsBindingObserver，
//   didChangeAppLifecycleState 中调用 applyLifecyclePlaybackChange 顶层纯函数：
//   - 离开前台（resumed → inactive/paused/hidden）→ pause（无论 Feed 可见否）
//   - 回到前台（paused/inactive → resumed）→ 仅当 Feed 可见 + userWantsToPlay=true 才 play
//   - 中间过渡态（resumed → inactive → paused / 反向）由边界触发，不重复调用
//
// 测试策略：核心逻辑抽到顶层纯函数 applyLifecyclePlaybackChange，
// 用 mockito mock IPlaybackController 验证 pause/play 调用。

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:embbytok_flutter/services/playback/i_playback_controller.dart';
import 'package:embbytok_flutter/providers/providers.dart';
import 'package:embbytok_flutter/views/home_scaffold.dart';

void main() {
  group('applyLifecyclePlaybackChange：App 前后台切换的视频控制', () {
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

    group('离开前台：pause', () {
      test('resumed → inactive（首步）: pause', () {
        stubPlaying(mockController);

        applyLifecyclePlaybackChange(
          prev: AppLifecycleState.resumed,
          next: AppLifecycleState.inactive,
          isFeedVisible: true,
          controller: mockController,
          userWantsToPlay: true,
        );

        verify(mockController.pause()).called(1);
        verifyNever(mockController.play());
      });

      test('resumed → paused（一步到位）: pause', () {
        stubPlaying(mockController);

        applyLifecyclePlaybackChange(
          prev: AppLifecycleState.resumed,
          next: AppLifecycleState.paused,
          isFeedVisible: true,
          controller: mockController,
          userWantsToPlay: true,
        );

        verify(mockController.pause()).called(1);
      });

      test('resumed → hidden: pause', () {
        stubPlaying(mockController);

        applyLifecyclePlaybackChange(
          prev: AppLifecycleState.resumed,
          next: AppLifecycleState.hidden,
          isFeedVisible: true,
          controller: mockController,
          userWantsToPlay: true,
        );

        verify(mockController.pause()).called(1);
      });

      test('离开前台时 Feed 不可见也 pause（节省资源是硬性要求）', () {
        // 场景：用户切到收藏 Tab 后再按 Home 键 → 收藏 Tab + App 切后台
        // 此时仍应暂停 Feed 中的 controller（即使 Feed 不可见）
        stubPlaying(mockController);

        applyLifecyclePlaybackChange(
          prev: AppLifecycleState.resumed,
          next: AppLifecycleState.paused,
          isFeedVisible: false, // 当前在收藏 Tab
          controller: mockController,
          userWantsToPlay: true,
        );

        verify(mockController.pause()).called(1);
      });

      test('已暂停时离开前台：不重复 pause', () {
        stubPaused(mockController);

        applyLifecyclePlaybackChange(
          prev: AppLifecycleState.resumed,
          next: AppLifecycleState.paused,
          isFeedVisible: true,
          controller: mockController,
          userWantsToPlay: true,
        );

        verifyNever(mockController.pause());
      });

      test('inactive → paused（中间过渡态）: 不重复 pause', () {
        // 场景：resumed → inactive（已 pause）→ paused
        // 第二次进入 paused 时 controller 已暂停，不应再调 pause
        stubPaused(mockController);

        applyLifecyclePlaybackChange(
          prev: AppLifecycleState.inactive,
          next: AppLifecycleState.paused,
          isFeedVisible: true,
          controller: mockController,
          userWantsToPlay: true,
        );

        verifyNever(mockController.pause());
        verifyNever(mockController.play());
      });
    });

    group('回到前台：条件 play', () {
      test('paused → resumed + Feed 可见 + userWantsToPlay: play', () {
        stubPaused(mockController);

        applyLifecyclePlaybackChange(
          prev: AppLifecycleState.paused,
          next: AppLifecycleState.resumed,
          isFeedVisible: true,
          controller: mockController,
          userWantsToPlay: true,
        );

        verify(mockController.play()).called(1);
        verifyNever(mockController.pause());
      });

      test('inactive → resumed（首步回到前台）: play', () {
        // 场景：paused → inactive → resumed
        // inactive → resumed 是"刚回到前台"边界，触发 play
        stubPaused(mockController);

        applyLifecyclePlaybackChange(
          prev: AppLifecycleState.inactive,
          next: AppLifecycleState.resumed,
          isFeedVisible: true,
          controller: mockController,
          userWantsToPlay: true,
        );

        verify(mockController.play()).called(1);
      });

      test('paused → resumed + Feed 不可见：不 play（用户在收藏 Tab）', () {
        // 关键场景：用户切到收藏 Tab 后按 Home → 后台 pause →
        // 回前台时仍停留在收藏 Tab，不应自动恢复 Feed 视频
        stubPaused(mockController);

        applyLifecyclePlaybackChange(
          prev: AppLifecycleState.paused,
          next: AppLifecycleState.resumed,
          isFeedVisible: false, // 当前在收藏 Tab
          controller: mockController,
          userWantsToPlay: true,
        );

        verifyNever(mockController.play());
        verifyNever(mockController.pause());
      });

      test('paused → resumed + userWantsToPlay=false：不 play（尊重用户暂停意图）', () {
        // 关键场景：用户主动暂停后切后台，再回前台
        // 不应自动恢复播放
        stubPaused(mockController);

        applyLifecyclePlaybackChange(
          prev: AppLifecycleState.paused,
          next: AppLifecycleState.resumed,
          isFeedVisible: true,
          controller: mockController,
          userWantsToPlay: false, // 用户已主动暂停
        );

        verifyNever(mockController.play());
      });

      test('回前台时已在播：不重复 play', () {
        // 防御性：避免重复 play 引起 controller 内部状态异常
        stubPlaying(mockController);

        applyLifecyclePlaybackChange(
          prev: AppLifecycleState.paused,
          next: AppLifecycleState.resumed,
          isFeedVisible: true,
          controller: mockController,
          userWantsToPlay: true,
        );

        verifyNever(mockController.play());
      });
    });

    group('安全网', () {
      test('prev 为 null（首次回调）: 不做任何处理', () {
        stubPlaying(mockController);

        applyLifecyclePlaybackChange(
          prev: null,
          next: AppLifecycleState.resumed,
          isFeedVisible: true,
          controller: mockController,
          userWantsToPlay: true,
        );

        verifyNever(mockController.pause());
        verifyNever(mockController.play());
      });

      test('controller 为 null：不抛异常', () {
        expect(
          () => applyLifecyclePlaybackChange(
            prev: AppLifecycleState.resumed,
            next: AppLifecycleState.paused,
            isFeedVisible: true,
            controller: null,
            userWantsToPlay: true,
          ),
          returnsNormally,
        );
      });

      test('controller 未初始化：不调用任何方法', () {
        when(mockController.isInitialized).thenReturn(false);
        when(mockController.isPlaying).thenReturn(false);

        applyLifecyclePlaybackChange(
          prev: AppLifecycleState.resumed,
          next: AppLifecycleState.paused,
          isFeedVisible: true,
          controller: mockController,
          userWantsToPlay: true,
        );

        verifyNever(mockController.pause());
        verifyNever(mockController.play());
      });

      test('inactive → inactive（同状态）: 不做任何处理', () {
        stubPlaying(mockController);

        applyLifecyclePlaybackChange(
          prev: AppLifecycleState.inactive,
          next: AppLifecycleState.inactive,
          isFeedVisible: true,
          controller: mockController,
          userWantsToPlay: true,
        );

        verifyNever(mockController.pause());
        verifyNever(mockController.play());
      });
    });

    group('完整流程：切后台再回前台', () {
      test('Feed 切后台 → 回前台：完整往返 pause/play', () {
        // 模拟 Android 切后台：resumed → inactive → paused → inactive → resumed
        // 期望：仅在第一/最后边界触发 pause/play
        stubPlaying(mockController);

        // 1. resumed → inactive：pause
        applyLifecyclePlaybackChange(
          prev: AppLifecycleState.resumed,
          next: AppLifecycleState.inactive,
          isFeedVisible: true,
          controller: mockController,
          userWantsToPlay: true,
        );
        verify(mockController.pause()).called(1);

        // 模拟 controller 暂停后状态
        stubPaused(mockController);

        // 2. inactive → paused：noop
        applyLifecyclePlaybackChange(
          prev: AppLifecycleState.inactive,
          next: AppLifecycleState.paused,
          isFeedVisible: true,
          controller: mockController,
          userWantsToPlay: true,
        );
        verifyNever(mockController.pause());

        // 3. paused → inactive：noop
        applyLifecyclePlaybackChange(
          prev: AppLifecycleState.paused,
          next: AppLifecycleState.inactive,
          isFeedVisible: true,
          controller: mockController,
          userWantsToPlay: true,
        );
        verifyNever(mockController.play());

        // 4. inactive → resumed：play
        applyLifecyclePlaybackChange(
          prev: AppLifecycleState.inactive,
          next: AppLifecycleState.resumed,
          isFeedVisible: true,
          controller: mockController,
          userWantsToPlay: true,
        );
        verify(mockController.play()).called(1);
      });
    });
  });

  group('PageNavigationState.isFeedVisible：复用 PR #93 测试', () {
    // 关键：lifecycle 恢复播放依赖 PageNavigationState.isFeedVisible
    test('切到收藏 Tab 时 isFeedVisible=false（回前台不自动恢复）', () {
      const state = PageNavigationState(currentIndex: PageIndices.favorites);
      expect(state.isFeedVisible, isFalse);
    });
  });
}

/// Mock IPlaybackController：拦截 pause/play 调用
///
/// IPlaybackController 是抽象接口，单元测试中用 mockito Mock 类拦截方法调用。
class MockPlaybackController extends Mock implements IPlaybackController {}
