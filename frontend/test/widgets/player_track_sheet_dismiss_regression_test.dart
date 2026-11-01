// 音轨 / 字幕选择底部弹窗：选中即关闭 回归测试
//
// 缺陷：audio_track_selector.showAudioTrackSelector 与
// subtitle_selector.showSubtitleSelector 在构造底部弹窗时都没有给
// AudioTrackSelector / SubtitleSelector 传 onClose。
// 而这两个组件每个选项的 onTap 都会调用 onClose?.call()——onClose 为 null
// 意味着用户选中一条音轨/字幕后，弹窗不会收起，必须手动下滑才能关闭，
// 与同目录 video_sheet_utils.showSubtitleSelector（选中即 pop）行为不一致。
//
// 修复：两个 wrapper 统一补 `onClose: () => Navigator.of(context).pop()`。
// 本测试锁定「选中轨道后弹窗被关闭，且轨道状态已写入 Provider」。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:embytok_flutter/models/models.dart';
import 'package:embytok_flutter/providers/providers.dart';
import 'package:embytok_flutter/widgets/video/audio_track_selector.dart';
import 'package:embytok_flutter/widgets/video/subtitle_selector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('showAudioTrackSelector 选中即关闭', () {
    testWidgets('点击某条音轨后弹窗关闭，且 selectedAudioStreamIndexProvider 更新',
        (tester) async {
      final container = ProviderContainer();
      final tracks = [
        const MediaStream(index: 0, type: 'Audio', language: 'und'),
        const MediaStream(
            index: 1, type: 'Audio', language: 'zh', displayTitle: '中文 音轨1'),
      ];

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () => showAudioTrackSelector(context, tracks),
                    child: const Text('打开音轨'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('打开音轨'));
      await tester.pumpAndSettle();

      // 弹窗已弹出
      expect(find.byType(AudioTrackSelector), findsOneWidget);

      // 选中「中文 音轨1」
      await tester.tap(find.text('中文 音轨1'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // 弹窗已关闭
      expect(find.byType(AudioTrackSelector), findsNothing);
      // 状态已写入 Provider
      expect(container.read(selectedAudioStreamIndexProvider), 1);

      container.dispose();
    });
  });

  group('showSubtitleSelector 选中即关闭', () {
    testWidgets('点击某条字幕后弹窗关闭，且 selectedSubtitleProvider 更新',
        (tester) async {
      final container = ProviderContainer();
      const tracks = [
        SubtitleTrack(id: '1', name: '中文内嵌', language: 'zh', format: 'srt'),
        SubtitleTrack(id: '2', name: 'English', language: 'en', format: 'vtt'),
      ];

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () => showSubtitleSelector(
                      context: context,
                      tracks: tracks,
                      // 与 video_controls._showSubtitleMenu 的真实链路一致：
                      // onSelected 负责把选中轨道写回 Provider
                      onSelected: (track) => container
                          .read(selectedSubtitleProvider.notifier)
                          .state = track?.id,
                    ),
                    child: const Text('打开字幕'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('打开字幕'));
      await tester.pumpAndSettle();

      expect(find.byType(SubtitleSelector), findsOneWidget);

      // 测试表面高度有限，底部弹窗仅渲染到第一条服务器字幕，点第一条即可
      await tester.tap(find.text('中文内嵌'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(SubtitleSelector), findsNothing);
      expect(container.read(selectedSubtitleProvider), '1');

      container.dispose();
    });
  });
}
