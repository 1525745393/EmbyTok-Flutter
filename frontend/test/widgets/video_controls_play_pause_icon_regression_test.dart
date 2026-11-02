// 批次B-F2「播放/暂停按钮图标 pause 后不刷新」回归测试
//
// 根因（MPV/VLC 分支）：播放/暂停按钮包在
//   ValueListenableBuilder<int>(valueListenable: handle.positionMsListenable)
// 里，图标取 _isPlaying。pause 后位置流不再 tick → 按钮不重建 → 图标
// 停在「暂停」不刷新。
// 修复：按钮改订阅 handle.isPlayingListenable（播放状态流，play/pause/播完
// 写入），不再依赖位置流 tick。
// 本测试断言（契约级）：图标即时反映 isPlayingListenable 的值变化，
// 与位置流是否 tick 无关。

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';

import 'package:embytok_flutter/providers/video_playback_controller.dart';
import 'package:embytok_flutter/widgets/video/video_controls.dart';

/// 测试专用统一控制句柄：isPlayingListenable 由外部 notifier 驱动，
/// 模拟真实 handle 的 play()/pause()/播放结束写入行为。
class _FakePlaybackHandle implements PlayerControlHandle {
  _FakePlaybackHandle({required this.isPlaying}) : isPlayingNotifier = ValueNotifier<bool>(isPlaying);

  final ValueNotifier<bool> isPlayingNotifier;
  bool isPlaying;

  @override
  ValueListenable<bool>? get isPlayingListenable => isPlayingNotifier;

  @override
  ValueListenable<int>? get positionMsListenable => _AlwaysZeroNotifierInt();

  @override
  Duration get currentPosition => Duration.zero;

  @override
  Duration get totalDuration => Duration.zero;

  @override
  bool get isReady => true;

  @override
  double get playbackRate => 1.0;

  @override
  double get volume => 1.0;

  @override
  void pause() {}

  @override
  void play() {}

  @override
  Future<void> seekTo(Duration position) async {}

  @override
  Future<void> setRate(double rate) async {}

  @override
  void setVolume(double value) {}
}

class _AlwaysZeroNotifierInt extends ValueNotifier<int> {
  _AlwaysZeroNotifierInt() : super(0);
}

Widget _buildControls(_FakePlaybackHandle handle) {
  return ProviderScope(
    child: MaterialApp(
      home: Scaffold(
        body: VideoControls(controller: null, handle: handle),
      ),
    ),
  );
}

void main() {
  testWidgets('F2 MPV/VLC 播放按钮图标随 isPlayingListenable 即时刷新', (tester) async {
    final handle = _FakePlaybackHandle(isPlaying: false);
    await tester.pumpWidget(_buildControls(handle));

    // 初始暂停态：显示 play_arrow，无 pause
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    expect(find.byIcon(Icons.pause), findsNothing);

    // 播放：状态流置 true（模拟 play() 写入），图标应立即变为 pause
    // 修复前：位置流无 tick，按钮不重建，图标停留在 play_arrow
    handle.isPlayingNotifier.value = true;
    handle.isPlaying = true;
    await tester.pump();
    expect(find.byIcon(Icons.pause), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsNothing);

    // 暂停：状态流置 false（模拟 pause() 写入），图标应立即变回 play_arrow
    // 修复前：pause 后位置流不再 tick，图标卡在 pause——本断言的原始失败场景
    handle.isPlayingNotifier.value = false;
    handle.isPlaying = false;
    await tester.pump();
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    expect(find.byIcon(Icons.pause), findsNothing);

    // 再次播放 → 暂停（覆盖 toggle 往返，确认非一次性生效）
    handle.isPlayingNotifier.value = true;
    await tester.pump();
    expect(find.byIcon(Icons.pause), findsOneWidget);
    handle.isPlayingNotifier.value = false;
    await tester.pump();
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
  });
}
