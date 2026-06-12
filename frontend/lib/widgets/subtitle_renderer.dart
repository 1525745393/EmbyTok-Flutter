// 字幕渲染器：在视频画面上叠加字幕文本
// 简化版字幕解析 SRT / 文本字幕，按时间展示当前时段的字幕行

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/subtitle_settings_provider.dart';

// 字幕 cue 数据结构
class SubtitleCue {
  final Duration start;
  final Duration end;
  final String text;

  const SubtitleCue(this.start, this.end, this.text);
}

// 字幕渲染器：接收当前播放时间和字幕数据
class SubtitleRenderer extends ConsumerWidget {
  final Duration position;
  final List<SubtitleCue> cues;
  final bool enabled;

  const SubtitleRenderer({
    super.key,
    required this.position,
    required this.cues,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!enabled || cues.isEmpty) return const SizedBox.shrink();

    final settings = ref.watch(subtitleSettingsProvider);
    if (!settings.enabled) return const SizedBox.shrink();

    // 查找当前时间匹配的字幕
    final current = cues.firstWhere(
      (c) => position >= c.start && position <= c.end,
      orElse: () => SubtitleCue(Duration.zero, Duration.zero, ''),
    );

    if (current.text.isEmpty) return const SizedBox.shrink();

    return IgnorePointer(
      child: Align(
        alignment: settings.alignment,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            current.text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: settings.textColor,
              fontSize: settings.fontSize,
              fontWeight: FontWeight.w600,
              height: 1.3,
              shadows: [
                Shadow(
                  color: Colors.black87,
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// SRT 简易解析器：把 SRT 字符串解析为 SubtitleCue 列表
List<SubtitleCue> parseSrt(String content) {
  final result = <SubtitleCue>[];
  final blocks = content.replaceAll('\r\n', '\n').split('\n\n');
  for (final block in blocks) {
    final lines = block.split('\n');
    if (lines.length < 2) continue;
    final timing = lines.firstWhere(
      (l) => l.contains('-->'),
      orElse: () => '',
    );
    if (timing.isEmpty) continue;
    final parts = timing.split('-->');
    if (parts.length < 2) continue;
    final start = _parseSrtTime(parts.first.trim());
    final end = _parseSrtTime(parts[1].trim());
    if (start == null || end == null) continue;
    final text = lines
        .skipWhile((l) => l.contains('-->')).where((l) => l.isNotEmpty).join('\n');
    if (text.isEmpty) continue;
    result.add(SubtitleCue(start, end, text));
  }
  return result;
}

Duration? _parseSrtTime(String s) {
  // 00:01:23,456 or 00:01:23.456
  try {
    final cleaned = s.replaceAll(',', '.');
    final parts = cleaned.split(':');
    if (parts.length < 3) return null;
    final hours = int.tryParse(parts[0]) ?? 0;
    final minutes = int.tryParse(parts[1]) ?? 0;
    final secondsParts = parts[2].split('.');
    final seconds = int.tryParse(secondsParts[0]) ?? 0;
    final millis = secondsParts.length > 1
        ? (int.tryParse(secondsParts[1].padRight(3, '0')) ?? 0)
        : 0;
    return Duration(
      hours: hours,
      minutes: minutes,
      seconds: seconds,
      milliseconds: millis,
    );
  } catch (_) {
    return null;
  }
}
