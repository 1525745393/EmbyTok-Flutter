import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:video_player/video_player.dart';

import 'package:embbytok_flutter/widgets/video/video_progress_bars.dart';

void main() {
  group('SeekableProgressBar 拖动 seek 行为', () {
    late MockVideoPlayerController mockController;

    /// 创建一个已初始化的 mock controller，指定时长和当前位置
    void stubController({
      required Duration duration,
      required Duration position,
    }) {
      when(mockController.value).thenReturn(
        VideoPlayerValue(
          duration: duration,
          position: position,
          isInitialized: true,
        ),
      );
      when(mockController.addListener(any)).thenReturn(null);
      when(mockController.removeListener(any)).thenReturn(null);
    }

    setUp(() {
      mockController = MockVideoPlayerController();
    });

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

      final progressBar = find.byType(SeekableProgressBar);
      expect(progressBar, findsOneWidget);

      final center = tester.getCenter(progressBar);
      await tester.dragFrom(center, const Offset(50, 0));

      verify(mockController.seekTo(any)).called(2);
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

      final progressBar = find.byType(SeekableProgressBar);
      final center = tester.getCenter(progressBar);

      final TestGesture gesture = await tester.startGesture(center);
      await tester.pump();

      verify(mockController.seekTo(any)).called(1);

      for (int i = 1; i <= 10; i++) {
        await gesture.moveBy(Offset(i * 10.0, 0));
        await tester.pump();
      }

      verify(mockController.seekTo(any)).called(1);

      await gesture.up();
      await tester.pump();

      verify(mockController.seekTo(any)).called(2);
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

      final progressBar = find.byType(SeekableProgressBar);
      final center = tester.getCenter(progressBar);

      await tester.dragFrom(center, const Offset(100, 0));

      verify(mockController.seekTo(any)).called(2);
    });

    /// 测试点击（onTapDown）时调用一次 seekTo
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

      final progressBar = find.byType(SeekableProgressBar);
      final center = tester.getCenter(progressBar);

      await tester.tapAt(center);

      verify(mockController.seekTo(any)).called(1);
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

      final progressBar = find.byType(SeekableProgressBar);
      final startOffset = tester.getTopLeft(progressBar) + const Offset(10, 0);
      final endOffset = tester.getTopRight(progressBar) - const Offset(10, 0);

      await tester.dragFrom(startOffset, endOffset - startOffset);

      verify(mockController.seekTo(any)).called(2);
    });
  });
}

/// Mock VideoPlayerController
class MockVideoPlayerController extends Mock implements VideoPlayerController {}
