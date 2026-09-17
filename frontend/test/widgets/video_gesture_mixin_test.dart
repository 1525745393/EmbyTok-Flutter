/// VideoGestureMixin 长按倍速状态清理测试
///
/// 重点验证：
/// - onLongPressStart 进入倍速并显示徽标
/// - cancelLongPress（手势被系统抢占路径）恢复倍速、隐藏徽标
/// - cancelLongPress 清理标志后，onLongPressEnd 的幂等保护生效（不重复恢复）
/// - cancelLongPress 幂等（非长按状态调用无副作用）
/// - onLongPressEnd 在 controller 不可用时仍隐藏徽标（不残留）

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:video_player/video_player.dart';

import 'package:embytok_flutter/widgets/video/video_gesture_mixin.dart';

class MockVideoPlayerController extends Mock implements VideoPlayerController {}

class _TestVideoWidget extends StatefulWidget {
  const _TestVideoWidget({super.key, required this.controller});

  final VideoPlayerController? controller;

  @override
  State<_TestVideoWidget> createState() => _TestVideoWidgetState();
}

class _TestVideoWidgetState extends State<_TestVideoWidget>
    with VideoGestureMixin {
  @override
  VideoPlayerController? get videoController => widget.controller;

  @override
  void onSingleTap() {}

  @override
  void onDoubleTapCenter() {}

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(Duration.zero);
    registerFallbackValue(0.0);
  });

  group('长按倍速状态清理', () {
    late MockVideoPlayerController controller;
    late VideoPlayerValue initializedValue;

    setUp(() {
      controller = MockVideoPlayerController();
      initializedValue = VideoPlayerValue(
        duration: const Duration(seconds: 100),
        position: Duration.zero,
        isInitialized: true,
        size: const Size(1920, 1080),
        playbackSpeed: 1.0,
      );
      when(() => controller.value).thenReturn(initializedValue);
      when(() => controller.setPlaybackSpeed(any())).thenAnswer((_) async {});
    });

    testWidgets('长按开始显示倍速徽标并进入 2x', (tester) async {
      final key = GlobalKey<_TestVideoWidgetState>();
      await tester.pumpWidget(
        MaterialApp(
          home: _TestVideoWidget(key: key, controller: controller),
        ),
      );

      final state = key.currentState!;
      expect(state.showSpeedBadgeNotifier.value, isFalse);

      state.onLongPressStart(const LongPressStartDetails());
      expect(state.showSpeedBadgeNotifier.value, isTrue);
      verify(() => controller.setPlaybackSpeed(2.0)).called(1);
    });

    testWidgets('长按取消恢复倍速并隐藏徽标', (tester) async {
      final key = GlobalKey<_TestVideoWidgetState>();
      await tester.pumpWidget(
        MaterialApp(
          home: _TestVideoWidget(key: key, controller: controller),
        ),
      );

      final state = key.currentState!;
      state.onLongPressStart(const LongPressStartDetails());
      state.cancelLongPress();

      expect(state.showSpeedBadgeNotifier.value, isFalse);
      verify(() => controller.setPlaybackSpeed(1.0)).called(1);
    });

    testWidgets('取消清理标志后 onLongPressEnd 幂等保护生效（不重复恢复倍速）',
        (tester) async {
      final key = GlobalKey<_TestVideoWidgetState>();
      await tester.pumpWidget(
        MaterialApp(
          home: _TestVideoWidget(key: key, controller: controller),
        ),
      );

      final state = key.currentState!;
      state.onLongPressStart(const LongPressStartDetails()); // 2x
      state.cancelLongPress(); // 恢复 1x + 清标志
      state.onLongPressEnd(const LongPressEndDetails()); // 标志已清 → 提前返回

      // 恢复只发生一次（cancel 路径）；onLongPressEnd 不再重复恢复
      verify(() => controller.setPlaybackSpeed(1.0)).called(1);
      expect(state.showSpeedBadgeNotifier.value, isFalse);
    });

    testWidgets('cancelLongPress 幂等：非长按状态调用无副作用', (tester) async {
      final key = GlobalKey<_TestVideoWidgetState>();
      await tester.pumpWidget(
        MaterialApp(
          home: _TestVideoWidget(key: key, controller: controller),
        ),
      );

      final state = key.currentState!;
      state.cancelLongPress();
      expect(state.showSpeedBadgeNotifier.value, isFalse);
      verifyNever(() => controller.setPlaybackSpeed(any()));
    });

    testWidgets('onLongPressEnd 在 controller 不可用时仍隐藏徽标（对称性修复）',
        (tester) async {
      final key = GlobalKey<_TestVideoWidgetState>();
      await tester.pumpWidget(
        MaterialApp(
          home: _TestVideoWidget(key: key, controller: controller),
        ),
      );

      final state = key.currentState!;
      state.onLongPressStart(const LongPressStartDetails());
      expect(state.showSpeedBadgeNotifier.value, isTrue);

      // 模拟播放器释放：同 key 替换 widget，controller 变为 null（State 保留）
      await tester.pumpWidget(
        MaterialApp(
          home: _TestVideoWidget(key: key, controller: null),
        ),
      );

      state.onLongPressEnd(const LongPressEndDetails());
      // 修复前此处徽标残留 true；修复后无条件隐藏
      expect(state.showSpeedBadgeNotifier.value, isFalse);
    });
  });
}
