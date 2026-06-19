/// SubtitleCue 数据结构测试
///
/// SubtitleCue 定义在 widgets/subtitle_renderer.dart 中，
/// 此处测试其基本构造和时间边界行为。

import 'package:flutter_test/flutter_test.dart';
import 'package:embbytok_flutter/widgets/subtitle_renderer.dart';

void main() {
  group('SubtitleCue', () {
    test('构造正确解析 start / end / text', () {
      const cue = SubtitleCue(
        Duration(minutes: 1, seconds: 30),
        Duration(minutes: 1, seconds: 35),
        '测试字幕文本',
      );
      expect(cue.start.inSeconds, 90);
      expect(cue.end.inSeconds, 95);
      expect(cue.text, '测试字幕文本');
    });

    test('零时长 cue 可以正常构造', () {
      const cue = SubtitleCue(Duration.zero, Duration.zero, '');
      expect(cue.start, Duration.zero);
      expect(cue.end, Duration.zero);
      expect(cue.text, '');
    });

    test('多行字幕文本', () {
      const cue = SubtitleCue(
        Duration(seconds: 5),
        Duration(seconds: 10),
        '第一行\n第二行\n第三行',
      );
      expect(cue.text, '第一行\n第二行\n第三行');
    });
  });
}
