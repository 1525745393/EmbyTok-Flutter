// FullscreenVideoPage 进度条拖动防抖测试
//
// 背景：
// - 修复前：_buildBottomBar 中 Slider.onChanged 每帧调用 controller.seekTo，
//   拖动进度条时产生大量 seek 请求，造成卡顿与资源浪费。
// - 修复后：抽出顶层 SliderSeekHandler 封装拖动状态机——
//   startDrag/updateDrag 仅更新预览（不 seek），endDrag 才触发一次 seekTo。
//
// 测试策略：
// - FullscreenVideoPage 依赖 playbackStateProvider / ref 等众多 provider，
//   widget 测试难以构造，故按 spec 允许的"抽取辅助类"路线，
//   单元测试 SliderSeekHandler（与 feed_autopause_test.dart 中
//   测试 applyFeedVisibilityChange 纯函数的模式一致）。
// - SliderSeekHandler 通过 seekTo 回调（void Function(Duration)?）解耦 controller，
//   测试直接注入 seekCalls.add 记录函数验证 seek 触发次数与目标位置。
//   不使用 mockito mock VideoPlayerController 的原因：seekTo 参数为
//   non-nullable Duration，mockito 5.x 对 non-nullable 位置参数的
//   verifyNever+matcher 存在 Null 类型限制（argThat 返回 Null 无法编译），
//   回调注入更轻量可靠且等价覆盖"单次拖动只触发一次 seek"的核心断言。

import 'package:flutter_test/flutter_test.dart';

import 'package:embytok_flutter/views/fullscreen_video_page.dart';

void main() {
  group('SliderSeekHandler：进度条拖动防抖', () {
    late SliderSeekHandler handler;
    late List<Duration> seekCalls;

    setUp(() {
      seekCalls = <Duration>[];
      // 模拟 widget 在 _buildBottomBar 中绑定 controller.seekTo：
      // 这里绑定到记录函数，便于断言 seek 调用次数与目标位置
      handler = SliderSeekHandler()..seekTo = seekCalls.add;
    });

    test('TC-1: 单次拖动（0.0 → 0.5 → 1.0）只触发一次 seek', () {
      // 核心回归场景：模拟 Slider 拖动 0.0 → 0.5 → 1.0
      const duration = Duration(milliseconds: 10000);

      handler.startDrag();
      handler.updateDrag(0.0, duration);
      handler.updateDrag(0.5, duration);
      handler.updateDrag(1.0, duration);
      handler.endDrag(1.0, duration);

      // 仅在 onChangeEnd 时 seek 到最终位置（1.0 * 10000ms）
      expect(seekCalls.length, 1, reason: '单次拖动应只触发一次 seek');
      expect(seekCalls.single, const Duration(milliseconds: 10000));
    });

    test('TC-2: 拖动过程中 updateDrag 不触发任何 seek', () {
      // 防抖核心：拖动中途多次 update 不应发起 seek
      const duration = Duration(milliseconds: 10000);

      handler.startDrag();
      handler.updateDrag(0.0, duration);
      handler.updateDrag(0.25, duration);
      handler.updateDrag(0.5, duration);
      handler.updateDrag(0.75, duration);

      expect(seekCalls, isEmpty, reason: '拖动中途不应发起 seek');
    });

    test('TC-3: onChangeEnd 后预览状态清除（UI 回退到真实 position）', () {
      const duration = Duration(milliseconds: 10000);

      handler.startDrag();
      handler.updateDrag(0.5, duration);
      expect(handler.seekPreviewMs, 5000,
          reason: '拖动中应返回预览毫秒值');

      handler.endDrag(0.5, duration);
      expect(handler.seekPreviewMs, isNull,
          reason: '拖动结束后预览应清除，UI 应回退到真实 position');
    });

    test('TC-4: duration 为 0 时不 seek（防御 duration 未就绪场景）', () {
      handler.startDrag();
      handler.updateDrag(0.5, Duration.zero);
      handler.endDrag(0.5, Duration.zero);

      expect(seekCalls, isEmpty, reason: 'duration 无效时不应 seek');
    });

    test('TC-5: seekTo 未绑定时 endDrag 不抛异常', () {
      // 容忍 controller 尚未就绪、handler.seekTo 为 null 的场景
      final unboundHandler = SliderSeekHandler();
      unboundHandler.startDrag();
      unboundHandler.updateDrag(0.5, const Duration(milliseconds: 10000));

      expect(
        () => unboundHandler.endDrag(0.5, const Duration(milliseconds: 10000)),
        returnsNormally,
      );
    });

    test('TC-6: 多次连续 update 后 endDrag 只 seek 到最终位置', () {
      const duration = Duration(milliseconds: 10000);

      handler.startDrag();
      handler.updateDrag(0.1, duration);
      handler.updateDrag(0.3, duration);
      handler.updateDrag(0.7, duration);
      handler.updateDrag(0.9, duration);
      handler.endDrag(0.9, duration);

      // 只 seek 到最后一次 endDrag 的位置，中间过程不 seek
      expect(seekCalls.length, 1);
      expect(seekCalls.single, const Duration(milliseconds: 9000));
    });

    test('TC-7: startDrag 后预览初始化为 0，进入拖动状态', () {
      expect(handler.seekPreviewMs, isNull,
          reason: '初始状态未拖动，预览应为 null');

      handler.startDrag();
      expect(handler.seekPreviewMs, 0.0,
          reason: 'startDrag 后应进入拖动状态，预览初始化为 0');
    });

    test('TC-8: 连续两次拖动（start-end-start-end）各触发一次 seek', () {
      const duration = Duration(milliseconds: 10000);

      // 第一次拖动到 0.3
      handler.startDrag();
      handler.updateDrag(0.3, duration);
      handler.endDrag(0.3, duration);

      // 第二次拖动到 0.8
      handler.startDrag();
      handler.updateDrag(0.8, duration);
      handler.endDrag(0.8, duration);

      expect(seekCalls.length, 2, reason: '两次独立拖动应各触发一次 seek');
      expect(seekCalls[0], const Duration(milliseconds: 3000));
      expect(seekCalls[1], const Duration(milliseconds: 8000));
    });
  });
}
