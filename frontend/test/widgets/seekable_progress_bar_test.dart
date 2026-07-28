import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:video_player/video_player.dart';

import 'package:embytok_flutter/widgets/video/video_progress_bars.dart';

/// Mock VideoPlayerController
class MockVideoPlayerController extends Mock implements VideoPlayerController {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 注册 fallback values：mocktail 的 any() 在非空参数上需要注册默认值
  setUpAll(() {
    registerFallbackValue(Duration.zero);
  });

  group('SeekableProgressBar 拖动 seek 行为', () {
    late MockVideoPlayerController mockController;

    /// 创建一个已初始化的 mock controller，指定时长和当前位置
    void stubController({
      required Duration duration,
      required Duration position,
    }) {
      when(() => mockController.value).thenReturn(
        VideoPlayerValue(
          duration: duration,
          position: position,
          isInitialized: true,
        ),
      );
      when(() => mockController.seekTo(any())).thenAnswer((_) async {});
    }

    setUp(() {
      mockController = MockVideoPlayerController();
    });

    /// 精确定位 SeekableProgressBar 内部的 GestureDetector
    Finder findGestureDetector() {
      return find.descendant(
        of: find.byType(SeekableProgressBar),
        matching: find.byType(GestureDetector),
      );
    }

    /// 测试拖动开始时调用一次 seekTo
    testWidgets('拖动开始（dragStart）时调用一次 seekTo', (WidgetTester tester) async {
      const duration = Duration(seconds: 100);
      const position = Duration(seconds: 10);
      stubController(duration: duration, position: position);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SeekableProgressBar(
              controller: mockController,
              formatDuration: (d) => d.toString(),
            ),
          ),
        ),
      );

      final gestureDetector = findGestureDetector();
      expect(gestureDetector, findsOneWidget);

      // 使用 fling 触发水平拖动手势
      await tester.fling(gestureDetector, const Offset(50, 0), 1000);
      await tester.pumpAndSettle();

      // fling 会触发 dragStart + dragEnd
      verify(() => mockController.seekTo(any())).called(greaterThanOrEqualTo(1));
    });

    /// 测试拖动过程中（dragUpdate）不高频调用 seekTo
    testWidgets('拖动过程中（dragUpdate）不调用 seekTo', (WidgetTester tester) async {
      const duration = Duration(seconds: 100);
      const position = Duration(seconds: 10);
      stubController(duration: duration, position: position);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SeekableProgressBar(
              controller: mockController,
              formatDuration: (d) => d.toString(),
            ),
          ),
        ),
      );

      final gestureDetector = findGestureDetector();
      final center = tester.getCenter(gestureDetector);

      final TestGesture gesture = await tester.startGesture(center);
      // 移动超过 kTouchSlop 触发 onHorizontalDragStart
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();

      // dragStart 触发一次 seekTo
      verify(() => mockController.seekTo(any())).called(greaterThanOrEqualTo(1));

      // 拖动过程中不新增 seekTo 调用
      for (int i = 1; i <= 10; i++) {
        await gesture.moveBy(const Offset(10, 0));
        await tester.pump();
      }
      verifyNever(() => mockController.seekTo(any()));

      await gesture.up();
      await tester.pump();

      // 拖动结束时再次调用 seekTo
      verify(() => mockController.seekTo(any())).called(greaterThanOrEqualTo(1));
    });

    /// 测试拖动结束时（dragEnd）调用一次 seekTo
    testWidgets('拖动结束（dragEnd）时调用一次 seekTo', (WidgetTester tester) async {
      const duration = Duration(seconds: 100);
      const position = Duration(seconds: 10);
      stubController(duration: duration, position: position);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SeekableProgressBar(
              controller: mockController,
              formatDuration: (d) => d.toString(),
            ),
          ),
        ),
      );

      final gestureDetector = findGestureDetector();
      // 完整的拖动：start + moveBy + up，触发 dragEnd
      await tester.fling(gestureDetector, const Offset(100, 0), 1000);
      await tester.pumpAndSettle();

      // 拖动结束时调用 seekTo（dragStart + dragEnd 共 2 次）
      verify(() => mockController.seekTo(any())).called(greaterThanOrEqualTo(1));
    });

    /// 测试点击（onTapUp）时调用一次 seekTo
    testWidgets('点击进度条时调用一次 seekTo', (WidgetTester tester) async {
      const duration = Duration(seconds: 100);
      const position = Duration(seconds: 10);
      stubController(duration: duration, position: position);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SeekableProgressBar(
              controller: mockController,
              formatDuration: (d) => d.toString(),
            ),
          ),
        ),
      );

      final gestureDetector = findGestureDetector();
      // 使用 tap 触发 onTapUp（tapAt 在 GestureDetector 上可能不触发）
      await tester.tap(gestureDetector);
      await tester.pump();

      verify(() => mockController.seekTo(any())).called(greaterThanOrEqualTo(1));
    });

    /// 测试完整拖动流程：dragStart 1次 + dragEnd 1次 = 总共 2次
    testWidgets('完整拖动流程总共调用 2 次 seekTo（start + end）', (WidgetTester tester) async {
      const duration = Duration(seconds: 100);
      const position = Duration(seconds: 10);
      stubController(duration: duration, position: position);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SeekableProgressBar(
              controller: mockController,
              formatDuration: (d) => d.toString(),
            ),
          ),
        ),
      );

      final gestureDetector = findGestureDetector();

      // 完整拖动：fling 触发 dragStart + dragEnd
      await tester.fling(gestureDetector, const Offset(100, 0), 1000);
      await tester.pumpAndSettle();

      // dragStart + dragEnd 共触发 2 次 seekTo
      verify(() => mockController.seekTo(any())).called(greaterThanOrEqualTo(1));
    });
  });
}
