// 字幕渲染器：在视频画面上叠加字幕文本
// 支持两种用法：
// 1. 传入 VideoPlayerController -> 自动随播放位置实时更新字幕（推荐）
// 2. 传入静态 position -> 用于测试或手动控制
// 简化版字幕解析 SRT / 文本字幕，按时间展示当前时段的字幕行

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../providers/subtitle_settings_provider.dart';

// 字幕 cue 数据结构
class SubtitleCue {
  final Duration start;
  final Duration end;
  final String text;

  const SubtitleCue(this.start, this.end, this.text);
}

// 字幕渲染器：接收 VideoPlayerController 或 静态 position
class SubtitleRenderer extends ConsumerWidget {
  final VideoPlayerController? controller;
  final Duration? position;
  final List<SubtitleCue> cues;
  final bool enabled;

  const SubtitleRenderer({
    super.key,
    this.controller,
    this.position,
    required this.cues,
    this.enabled = true,
  }) : assert(controller != null || position != null,
            '必须提供 controller 或 position 其一');

  // 根据播放位置在 cues 中查找当前字幕
  static SubtitleCue? findCueAt(List<SubtitleCue> cues, Duration position) {
    if (cues.isEmpty) return null;
    for (final cue in cues) {
      if (position >= cue.start && position <= cue.end) {
        return cue;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!enabled || cues.isEmpty) return const SizedBox.shrink();

    final settings = ref.watch(subtitleSettingsProvider);
    if (!settings.enabled) return const SizedBox.shrink();

    // 使用 controller 时，通过 AnimatedBuilder 监听播放位置变化
    final child = controller != null
        ? AnimatedBuilder(
            animation: controller!,
            builder: (context, _) => _buildCue(
              context,
              findCueAt(cues, controller!.value.position),
              settings,
            ),
          )
        : _buildCue(
            context,
            position != null ? findCueAt(cues, position!) : null,
            settings,
          );

    // 确保字幕层位于视频画面上层且不拦截事件
    return IgnorePointer(
      child: Align(
        alignment: settings.alignment,
        child: child,
      ),
    );
  }

  // 构建单个字幕显示
  Widget _buildCue(BuildContext context, SubtitleCue? cue, SubtitleSettings settings) {
    if (cue == null || cue.text.isEmpty) return const SizedBox.shrink();

    final lines = cue.text.split('\n');
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: lines
            .map((line) => Text(
                  line,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: settings.textColor,
                    fontSize: settings.fontSize,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    shadows: const [
                      Shadow(
                        color: Colors.black87,
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }
}

// SRT 简易解析器：把 SRT 字符串解析为 SubtitleCue 列表
List<SubtitleCue> parseSrt(String content) {
  final result = <SubtitleCue>[];
  // 规范化换行并按空行分块
  final blocks =
      content.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n\n');
  for (final block in blocks) {
    final lines = block.trim().split('\n');
    if (lines.length < 2) continue;

    // 找到包含 "-->" 的时间行（SRT 标准：索引行之后是时间行）
    int? timingIndex;
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].contains('-->')) {
        timingIndex = i;
        break;
      }
    }
    if (timingIndex == null) continue;

    final timing = lines[timingIndex];
    final parts = timing.split('-->');
    if (parts.length < 2) continue;

    final start = _parseSrtTime(parts.first.trim());
    final end = _parseSrtTime(parts[1].trim().split(' ').first);
    if (start == null || end == null) continue;

    // 时间行之后的都是文本
    final textLines = lines.sublist(timingIndex + 1);
    final text = textLines.where((l) => l.isNotEmpty).join('\n');
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
