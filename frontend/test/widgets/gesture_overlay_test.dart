import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:video_player/video_player.dart';

import 'package:embytok_flutter/models/models.dart';
import 'package:embytok_flutter/widgets/gesture_overlay.dart';
import 'package:embytok_flutter/widgets/video/video_gesture_mixin.dart';

class MockVideoPlayerController extends Mock implements VideoPlayerController {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 注册 mocktail fallback values：让 any() 可匹配非空参数类型
  setUpAll(() {
    registerFallbackValue(Duration.zero);
    registerFallbackValue(0.0);
  });

  group('GestureOverlay Widget 基本测试', () {
    late MediaItem testMediaItem;

    setUp(() {
      testMediaItem = MediaItem(
        id: 'test-item-1',
        title: '测试视频',
        type: 'Movie',
        durationSeconds: 100.0,
      );
    });

    testWidgets('GestureOverlay 正常构建不崩溃', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 600,
                child: GestureOverlay(
                  item: testMediaItem,
                  controller: null,
                  child: const ColoredBox(color: Colors.black),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GestureOverlay), findsOneWidget);
      expect(find.byType(GestureDetector), findsOneWidget);
    });

    testWidgets('GestureOverlay 正确渲染 child', (WidgetTester tester) async {
      const testKey = Key('test-child');

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 600,
                child: GestureOverlay(
                  item: testMediaItem,
                  controller: null,
                  child: const SizedBox(key: testKey),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(testKey), findsOneWidget);
    });

    testWidgets('enableGestures=false 时仍可单击', (WidgetTester tester) async {
      var tapCount = 0;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 600,
                child: GestureOverlay(
                  item: testMediaItem,
                  controller: null,
                  enableGestures: false,
                  onSingleTap: () => tapCount++,
                  child: const ColoredBox(color: Colors.black),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(GestureOverlay));
      await tester.pump(const Duration(milliseconds: 300));

      expect(tapCount, 1);
    });
  });

  group('VideoGestureMixin 手势逻辑测试', () {
    late MockVideoPlayerController mockController;

    const testDuration = Duration(seconds: 100);
    const testPosition = Duration(seconds: 30);
    const testVolume = 0.7;
    const testPlaybackSpeed = 1.0;

    void stubController({
      Duration duration = testDuration,
      Duration position = testPosition,
      double volume = testVolume,
      double playbackSpeed = testPlaybackSpeed,
      bool isInitialized = true,
    }) {
      when(() => mockController.value).thenReturn(
        VideoPlayerValue(
          duration: duration,
          position: position,
          isInitialized: isInitialized,
          volume: volume,
          playbackSpeed: playbackSpeed,
        ),
      );
      when(() => mockController.seekTo(any())).thenAnswer((_) async {});
      when(() => mockController.setVolume(any())).thenAnswer((_) async {});
      when(() => mockController.setPlaybackSpeed(any())).thenAnswer((_) async {});
    }

    setUp(() {
      mockController = MockVideoPlayerController();
    });

    Future<void> pumpTestWidget(
      WidgetTester tester, {
      VoidCallback? onSingleTap,
      VoidCallback? onDoubleTapLeft,
      VoidCallback? onDoubleTapRight,
      VoidCallback? onDoubleTapCenter,
      bool enableGestures = true,
      bool enableVerticalVolumeDrag = false,
      bool handleLeftVerticalDrag = false,
    }) async {
      // 注意：不使用 SizedBox(400, 600) 限制尺寸。
      // 原因：Scaffold body 只 tighten height，width 是 loose，
      // 导致 SizedBox 实际 width=400 但 MediaQuery.of(context).size.width=800，
      // 使 VideoGestureMixin 中基于 screenWidth 计算的 relativeX 与实际坐标不一致。
      // 让 _GestureTestWidget 占满 Scaffold body 可确保两者一致。
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _GestureTestWidget(
              controller: mockController,
              onSingleTap: onSingleTap,
              onDoubleTapLeft: onDoubleTapLeft,
              onDoubleTapRight: onDoubleTapRight,
              onDoubleTapCenter: onDoubleTapCenter,
              enableGestures: enableGestures,
              enableVerticalVolumeDrag: enableVerticalVolumeDrag,
              handleLeftVerticalDrag: handleLeftVerticalDrag,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    // 双击辅助：直接调用 VideoGestureMixin 的 handleTapDown/handleTap。
    // 原因：_GestureTestWidget 同时注册了 onTap 与 onHorizontalDragStart（或 onPanStart），
    // Tap 与 Drag 识别器在 GestureArena 中竞争；当两次 tap 间隔 < kPressTimeout (100ms) 时，
    // 第二次 onTap 不会被触发，导致 _onDoubleTap 永远不执行。
    // 直接调用 mixin 方法可绕过识别器竞争，专注于验证双击业务逻辑。
    Future<void> performDoubleTapAt(
      WidgetTester tester,
      Finder gestureArea,
      Offset point,
    ) async {
      final state = tester.state(gestureArea) as _GestureTestWidgetState;
      state.handleTapDown(TapDownDetails(globalPosition: point));
      state.handleTap();
      await tester.pump(const Duration(milliseconds: 50));
      state.handleTapDown(TapDownDetails(globalPosition: point));
      state.handleTap();
      await tester.pumpAndSettle();
    }

    // Pan 拖动辅助：直接调用 VideoGestureMixin 的 onPanStart/onPanUpdate/onPanEnd。
    // 原因：与双击类似，Pan 识别器在竞技场中需要 move 超过 touchSlop 才胜出，
    // 且 DragUpdateDetails 的 globalPosition 难以精确模拟；直接调用可确保音量
    // 调节逻辑被覆盖。
    Future<void> performPanDrag(
      WidgetTester tester,
      Finder gestureArea,
      Offset start,
      List<Offset> moves,
    ) async {
      final state = tester.state(gestureArea) as _GestureTestWidgetState;
      state.onPanStart(DragStartDetails(globalPosition: start));
      Offset current = start;
      for (final move in moves) {
        current = current + move;
        state.onPanUpdate(DragUpdateDetails(globalPosition: current));
        await tester.pump();
      }
      state.onPanEnd(DragEndDetails());
      await tester.pump();
    }

    testWidgets('单击触发 onSingleTap 回调', (WidgetTester tester) async {
      stubController();

      var tapCount = 0;
      await pumpTestWidget(
        tester,
        onSingleTap: () => tapCount++,
      );

      final gestureArea = find.byType(_GestureTestWidget);
      await tester.tap(gestureArea);
      await tester.pump(const Duration(milliseconds: 300));

      expect(tapCount, 1);
    });

    testWidgets('双击不触发单击回调（手势冲突）', (WidgetTester tester) async {
      stubController();

      var tapCount = 0;
      await pumpTestWidget(
        tester,
        onSingleTap: () => tapCount++,
      );

      final gestureArea = find.byType(_GestureTestWidget);
      final center = tester.getCenter(gestureArea);

      // 直接调用 mixin 方法模拟双击，避免 GestureDetector 识别器竞争
      await performDoubleTapAt(tester, gestureArea, center);

      expect(tapCount, 0);
    });

    testWidgets('双击左侧触发 onDoubleTapLeft 回调', (WidgetTester tester) async {
      stubController();

      var doubleTapLeftCount = 0;
      await pumpTestWidget(
        tester,
        onDoubleTapLeft: () => doubleTapLeftCount++,
      );

      final gestureArea = find.byType(_GestureTestWidget);
      final leftPoint = tester.getTopLeft(gestureArea) + const Offset(20, 300);

      await performDoubleTapAt(tester, gestureArea, leftPoint);

      expect(doubleTapLeftCount, 1);
    });

    testWidgets('双击右侧触发 onDoubleTapRight 回调', (WidgetTester tester) async {
      stubController();

      var doubleTapRightCount = 0;
      await pumpTestWidget(
        tester,
        onDoubleTapRight: () => doubleTapRightCount++,
      );

      final gestureArea = find.byType(_GestureTestWidget);
      final rightPoint = tester.getTopRight(gestureArea) + const Offset(-20, 300);

      await performDoubleTapAt(tester, gestureArea, rightPoint);

      expect(doubleTapRightCount, 1);
    });

    testWidgets('双击中心触发 onDoubleTapCenter 回调', (WidgetTester tester) async {
      stubController();

      var doubleTapCenterCount = 0;
      await pumpTestWidget(
        tester,
        onDoubleTapCenter: () => doubleTapCenterCount++,
      );

      final gestureArea = find.byType(_GestureTestWidget);
      final center = tester.getCenter(gestureArea);

      await performDoubleTapAt(tester, gestureArea, center);

      expect(doubleTapCenterCount, 1);
    });

    testWidgets('双击左侧触发后退 10 秒（seekTo）', (WidgetTester tester) async {
      stubController();

      await pumpTestWidget(tester);

      final gestureArea = find.byType(_GestureTestWidget);
      final leftPoint = tester.getTopLeft(gestureArea) + const Offset(20, 300);

      await performDoubleTapAt(tester, gestureArea, leftPoint);

      final captured = verify(() => mockController.seekTo(captureAny())).captured;
      expect(captured, isNotEmpty);
      final targetPosition = captured.last as Duration;
      expect(targetPosition, const Duration(seconds: 20));
    });

    testWidgets('双击右侧触发快进 10 秒（seekTo）', (WidgetTester tester) async {
      stubController();

      await pumpTestWidget(tester);

      final gestureArea = find.byType(_GestureTestWidget);
      final rightPoint = tester.getTopRight(gestureArea) + const Offset(-20, 300);

      await performDoubleTapAt(tester, gestureArea, rightPoint);

      final captured = verify(() => mockController.seekTo(captureAny())).captured;
      expect(captured, isNotEmpty);
      final targetPosition = captured.last as Duration;
      expect(targetPosition, const Duration(seconds: 40));
    });

    testWidgets('长按触发倍速播放（2.0x）', (WidgetTester tester) async {
      stubController();

      await pumpTestWidget(tester);

      final gestureArea = find.byType(_GestureTestWidget);
      await tester.longPress(gestureArea);
      await tester.pump();

      verify(() => mockController.setPlaybackSpeed(2.0)).called(1);
    });

    testWidgets('长按结束恢复原倍速', (WidgetTester tester) async {
      stubController();

      await pumpTestWidget(tester);

      final gestureArea = find.byType(_GestureTestWidget);
      final center = tester.getCenter(gestureArea);

      final gesture = await tester.startGesture(center);
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.up();
      await tester.pump();

      verify(() => mockController.setPlaybackSpeed(2.0)).called(1);
      verify(() => mockController.setPlaybackSpeed(1.0)).called(1);
    });

    testWidgets('水平向右拖动结束后调用 seekTo 前进', (WidgetTester tester) async {
      stubController();

      await pumpTestWidget(tester);

      final gestureArea = find.byType(_GestureTestWidget);
      final center = tester.getCenter(gestureArea);

      await tester.dragFrom(center, const Offset(100, 0));
      await tester.pump();

      final captured = verify(() => mockController.seekTo(captureAny())).captured;
      expect(captured, isNotEmpty);
      final targetPosition = captured.last as Duration;
      expect(targetPosition.inMilliseconds, greaterThan(testPosition.inMilliseconds));
    });

    testWidgets('水平向左拖动结束后调用 seekTo 后退', (WidgetTester tester) async {
      stubController();

      await pumpTestWidget(tester);

      final gestureArea = find.byType(_GestureTestWidget);
      final center = tester.getCenter(gestureArea);

      await tester.dragFrom(center, const Offset(-100, 0));
      await tester.pump();

      final captured = verify(() => mockController.seekTo(captureAny())).captured;
      expect(captured, isNotEmpty);
      final targetPosition = captured.last as Duration;
      expect(targetPosition.inMilliseconds, lessThan(testPosition.inMilliseconds));
    });

    testWidgets('小屏模式下水平拖动更新预览位置', (WidgetTester tester) async {
      stubController();

      await pumpTestWidget(
        tester,
        enableVerticalVolumeDrag: false,
      );

      final gestureArea = find.byType(_GestureTestWidget);
      final center = tester.getCenter(gestureArea);

      final gesture = await tester.startGesture(center);
      await gesture.moveBy(const Offset(50, 0));
      await tester.pump();

      final testWidgetState = tester.state(find.byType(_GestureTestWidget)) as _GestureTestWidgetState;
      expect(testWidgetState.previewPositionNotifier.value, isNot(equals(Duration.zero)));
      expect(testWidgetState.dragAxis, 'h');

      await gesture.up();
      await tester.pump();
    });

    testWidgets('全屏模式下垂直右侧滑动调节音量', (WidgetTester tester) async {
      stubController();

      await pumpTestWidget(
        tester,
        enableVerticalVolumeDrag: true,
      );

      final gestureArea = find.byType(_GestureTestWidget);
      final rightSide = tester.getTopRight(gestureArea) + const Offset(-50, 300);

      // 直接调用 mixin 方法模拟 Pan 拖动：
      // 第一次 update 判定 dragAxis='v' 并设置 isVolumeSide=true，
      // 第二次 update 才会调用 onSetVolume 调节音量。
      await performPanDrag(tester, gestureArea, rightSide, [
        const Offset(0, -50),
        const Offset(0, -50),
      ]);

      verify(() => mockController.setVolume(any())).called(greaterThan(0));
    });

    testWidgets('全屏模式下上滑增加音量', (WidgetTester tester) async {
      stubController(volume: 0.5);

      await pumpTestWidget(
        tester,
        enableVerticalVolumeDrag: true,
      );

      final gestureArea = find.byType(_GestureTestWidget);
      final rightSide = tester.getTopRight(gestureArea) + const Offset(-50, 300);

      // 直接调用 mixin 方法：需要两次 update 才能完成音量调节
      // （第一次判定方向，第二次根据累计位移计算新音量）
      await performPanDrag(tester, gestureArea, rightSide, [
        const Offset(0, -50),
        const Offset(0, -150),
      ]);

      final testWidgetState = tester.state(gestureArea) as _GestureTestWidgetState;
      expect(testWidgetState.previewVolumeNotifier.value, greaterThan(0.5));
    });

    testWidgets('小屏模式下垂直滑动不触发音量调节', (WidgetTester tester) async {
      stubController();

      await pumpTestWidget(
        tester,
        enableVerticalVolumeDrag: false,
      );

      final gestureArea = find.byType(_GestureTestWidget);
      final rightSide = tester.getTopRight(gestureArea) + const Offset(-50, 300);

      await tester.dragFrom(rightSide, const Offset(0, -100));
      await tester.pump();

      verifyNever(() => mockController.setVolume(any()));
    });

    testWidgets('enableGestures=false 时长按不触发倍速', (WidgetTester tester) async {
      stubController();

      await pumpTestWidget(
        tester,
        enableGestures: false,
      );

      final gestureArea = find.byType(_GestureTestWidget);
      await tester.longPress(gestureArea);
      await tester.pump();

      verifyNever(() => mockController.setPlaybackSpeed(2.0));
    });

    testWidgets('enableGestures=false 时水平拖动不触发 seek', (WidgetTester tester) async {
      stubController();

      await pumpTestWidget(
        tester,
        enableGestures: false,
      );

      final gestureArea = find.byType(_GestureTestWidget);
      final center = tester.getCenter(gestureArea);

      await tester.dragFrom(center, const Offset(100, 0));
      await tester.pump();

      verifyNever(() => mockController.seekTo(any()));
    });

    testWidgets('enableGestures=false 时单击仍可触发', (WidgetTester tester) async {
      stubController();

      var tapCount = 0;
      await pumpTestWidget(
        tester,
        onSingleTap: () => tapCount++,
        enableGestures: false,
      );

      final gestureArea = find.byType(_GestureTestWidget);
      await tester.tap(gestureArea);
      await tester.pump(const Duration(milliseconds: 300));

      expect(tapCount, 1);
    });

    testWidgets('视频未初始化时拖动不触发 seek', (WidgetTester tester) async {
      stubController(isInitialized: false);

      await pumpTestWidget(tester);

      final gestureArea = find.byType(_GestureTestWidget);
      final center = tester.getCenter(gestureArea);

      await tester.dragFrom(center, const Offset(100, 0));
      await tester.pump();

      verifyNever(() => mockController.seekTo(any()));
    });

    testWidgets('视频未初始化时长按不触发倍速', (WidgetTester tester) async {
      stubController(isInitialized: false);

      await pumpTestWidget(tester);

      final gestureArea = find.byType(_GestureTestWidget);
      await tester.longPress(gestureArea);
      await tester.pump();

      verifyNever(() => mockController.setPlaybackSpeed(2.0));
    });

    testWidgets('滑动距离小于阈值时不触发水平拖动', (WidgetTester tester) async {
      stubController();

      await pumpTestWidget(
        tester,
        enableVerticalVolumeDrag: true,
      );

      final gestureArea = find.byType(_GestureTestWidget);
      final center = tester.getCenter(gestureArea);

      final gesture = await tester.startGesture(center);
      await gesture.moveBy(const Offset(5, 0));
      await tester.pump();

      final testWidgetState = tester.state(find.byType(_GestureTestWidget)) as _GestureTestWidgetState;
      expect(testWidgetState.dragAxis, isNull);

      await gesture.up();
      await tester.pump();
    });

    testWidgets('双击快退不会低于 0 秒', (WidgetTester tester) async {
      stubController(position: const Duration(seconds: 5));

      await pumpTestWidget(tester);

      final gestureArea = find.byType(_GestureTestWidget);
      final leftPoint = tester.getTopLeft(gestureArea) + const Offset(20, 300);

      await performDoubleTapAt(tester, gestureArea, leftPoint);

      final captured = verify(() => mockController.seekTo(captureAny())).captured;
      expect(captured, isNotEmpty);
      final targetPosition = captured.last as Duration;
      expect(targetPosition, Duration.zero);
    });

    testWidgets('双击快进不会超过视频时长', (WidgetTester tester) async {
      stubController(position: const Duration(seconds: 95));

      await pumpTestWidget(tester);

      final gestureArea = find.byType(_GestureTestWidget);
      final rightPoint = tester.getTopRight(gestureArea) + const Offset(-20, 300);

      await performDoubleTapAt(tester, gestureArea, rightPoint);

      final captured = verify(() => mockController.seekTo(captureAny())).captured;
      expect(captured, isNotEmpty);
      final targetPosition = captured.last as Duration;
      expect(targetPosition, testDuration);
    });

    testWidgets('水平拖动 seek 后不超出边界（前进）', (WidgetTester tester) async {
      stubController(position: const Duration(seconds: 95));

      await pumpTestWidget(tester);

      final gestureArea = find.byType(_GestureTestWidget);
      final center = tester.getCenter(gestureArea);

      await tester.dragFrom(center, const Offset(200, 0));
      await tester.pump();

      final captured = verify(() => mockController.seekTo(captureAny())).captured;
      expect(captured, isNotEmpty);
      final targetPosition = captured.last as Duration;
      expect(targetPosition, testDuration);
    });

    testWidgets('水平拖动 seek 后不超出边界（后退）', (WidgetTester tester) async {
      stubController(position: const Duration(seconds: 5));

      await pumpTestWidget(tester);

      final gestureArea = find.byType(_GestureTestWidget);
      final center = tester.getCenter(gestureArea);

      await tester.dragFrom(center, const Offset(-200, 0));
      await tester.pump();

      final captured = verify(() => mockController.seekTo(captureAny())).captured;
      expect(captured, isNotEmpty);
      final targetPosition = captured.last as Duration;
      expect(targetPosition, Duration.zero);
    });
  });
}

class _GestureTestWidget extends StatefulWidget {
  final VideoPlayerController? controller;
  final VoidCallback? onSingleTap;
  final VoidCallback? onDoubleTapLeft;
  final VoidCallback? onDoubleTapRight;
  final VoidCallback? onDoubleTapCenter;
  final bool enableGestures;
  final bool enableVerticalVolumeDrag;
  final bool handleLeftVerticalDrag;

  const _GestureTestWidget({
    this.controller,
    this.onSingleTap,
    this.onDoubleTapLeft,
    this.onDoubleTapRight,
    this.onDoubleTapCenter,
    this.enableGestures = true,
    this.enableVerticalVolumeDrag = false,
    this.handleLeftVerticalDrag = false,
  });

  @override
  State<_GestureTestWidget> createState() => _GestureTestWidgetState();
}

class _GestureTestWidgetState extends State<_GestureTestWidget>
    with VideoGestureMixin {
  @override
  VideoPlayerController? get videoController => widget.controller;

  // 与 VideoGestureMixin 中的 gesturesEnabled 对齐
  @override
  bool get gesturesEnabled => widget.enableGestures;

  bool get enableVerticalVolumeDrag => widget.enableVerticalVolumeDrag;

  @override
  bool get handleLeftVerticalDrag => widget.handleLeftVerticalDrag;

  @override
  void onSingleTap() => widget.onSingleTap?.call();

  // 调用 super 以触发 mixin 的 seekBySeconds（与 GestureOverlay 实现一致），
  // 否则 "双击左侧触发后退 10 秒" 等 seekTo 验证测试会失败。
  @override
  void onDoubleTapLeft() {
    super.onDoubleTapLeft();
    widget.onDoubleTapLeft?.call();
  }

  @override
  void onDoubleTapRight() {
    super.onDoubleTapRight();
    widget.onDoubleTapRight?.call();
  }

  @override
  void onDoubleTapCenter() {
    // mixin 的 onDoubleTapCenter 默认空实现，仅触发回调
    widget.onDoubleTapCenter?.call();
  }

  @override
  Widget build(BuildContext context) {
    // 模拟 GestureOverlay 的手势识别器构建逻辑
    // 保留与生产代码一致的手势回调注册
    final usePan = widget.enableVerticalVolumeDrag;
    // 占满父容器尺寸，确保手势区域不为 0
    return SizedBox.expand(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: handleTapDown,
        onTap: handleTap,
        onLongPressStart: widget.enableGestures ? onLongPressStart : null,
        onLongPressEnd: widget.enableGestures ? onLongPressEnd : null,
        onPanStart: (widget.enableGestures && usePan) ? onPanStart : null,
        onPanUpdate: (widget.enableGestures && usePan) ? onPanUpdate : null,
        onPanEnd: (widget.enableGestures && usePan) ? onPanEnd : null,
        onPanCancel: (widget.enableGestures && usePan) ? onPanCancel : null,
        onHorizontalDragStart:
            (widget.enableGestures && !usePan) ? onHorizontalDragStart : null,
        onHorizontalDragUpdate:
            (widget.enableGestures && !usePan) ? onHorizontalDragUpdate : null,
        onHorizontalDragEnd:
            (widget.enableGestures && !usePan) ? onHorizontalDragEnd : null,
        onHorizontalDragCancel:
            (widget.enableGestures && !usePan) ? onHorizontalDragCancel : null,
        child: const ColoredBox(color: Colors.black),
      ),
    );
  }

  @override
  void dispose() {
    // 清理 VideoGestureMixin 中的定时器，避免测试泄漏
    disposeGestureTimers();
    super.dispose();
  }
}
