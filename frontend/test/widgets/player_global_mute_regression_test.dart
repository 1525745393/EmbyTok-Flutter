import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:embytok_flutter/models/media_item.dart';
import 'package:embytok_flutter/providers/video_playback_controller.dart';
import 'package:embytok_flutter/widgets/video/video_player_widget.dart';

/// P2-3 全局静音回归测试：
/// 顶栏静音按钮只切换 isMutedProvider，播放器内 ref.listenManual 监听
/// 并同步实际音量——静音→0，取消→恢复 volumeBeforeMuteProvider（或 1.0）。
/// 契约式：三引擎无法真实初始化（playbackUrl 空走缩略图降级），
/// 通过 handle.volume 观察 _lastSetVolume（controller 未初始化时的回退值）。
void main() {
  MediaItem fakeItem(String id) => MediaItem(
        id: id,
        title: 'item-$id',
        type: 'Video',
        // playbackUrl 为空：走缩略图降级，不初始化原生播放器
      );

  Future<PlayerControlHandle?> pumpPlayer(WidgetTester tester,
      ProviderContainer container) async {
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: VideoPlayerWidget(
            key: const ValueKey('player'),
            item: fakeItem('a'),
            isCurrentPage: true,
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 50));
    return container.read(currentPlayerControlProvider);
  }

  testWidgets('静音切换同步音量：静音→0，取消→恢复 volumeBeforeMute', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final handle = await pumpPlayer(tester, container);
    expect(handle, isNotNull, reason: '前置：当前页已注册句柄');

    // 基线：静音（若初始 prefs 已静音则 prev==next 不重复触发，音量本就为 0）
    container.read(isMutedProvider.notifier).setMuted(true);
    await tester.pump();
    expect(handle!.volume, 0.0, reason: '静音时应将播放器音量置 0');

    // 预置静音前音量后取消静音：应恢复该音量（batch150 语义）
    container.read(volumeBeforeMuteProvider.notifier).state = 0.6;
    container.read(isMutedProvider.notifier).setMuted(false);
    await tester.pump();
    expect(handle.volume, 0.6, reason: '取消静音应恢复静音前音量（batch150 语义）');

    // 清理：卸载树
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: SizedBox.shrink()),
    ));
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('未记录静音前音量时，取消静音回退默认 1.0', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final handle = await pumpPlayer(tester, container);
    expect(handle, isNotNull);

    // 不预置 volumeBeforeMute：取消静音应回退 1.0
    container.read(isMutedProvider.notifier).setMuted(true);
    await tester.pump();
    expect(handle!.volume, 0.0);

    container.read(isMutedProvider.notifier).setMuted(false);
    await tester.pump();
    expect(handle.volume, 1.0, reason: 'volumeBeforeMute 为空时回退默认 1.0');

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: SizedBox.shrink()),
    ));
    await tester.pump(const Duration(milliseconds: 50));
  });
}
