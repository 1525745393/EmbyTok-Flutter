// 字幕渲染器：在视频画面上叠加字幕文本
// 简化版字幕解析 SRT / 文本字幕，按时间展示当前时段的字幕行

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/subtitle_track.dart';
import '../providers/subtitle_settings_provider.dart';

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

    // settings 仅用于字幕样式（字号、颜色、位置），不控制是否显示
    // 是否显示由外部决定（cues 是否为空、selectedSubId 是否为 null）
    final settings = ref.watch(subtitleSettingsProvider);

    // 二分查找当前时间匹配的字幕（O(log n)，优于线性搜索 O(n)）
    final current = findCueAtPosition(cues, position);
    if (current == null || current.text.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;

    return IgnorePointer(
      child: Align(
        alignment: settings.alignment,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: scheme.surface.withOpacity(0.72),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            children: [
              // 描边层：亮色场景下保证字幕清晰可读
              Text(
                current.text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: settings.fontSize,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = (settings.fontSize * 0.14).clamp(2.0, 5.0)
                    ..strokeJoin = StrokeJoin.round
                    ..color = Colors.black.withOpacity(0.85),
                ),
              ),
              // 填充层
              Text(
                current.text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: settings.textColor,
                  fontSize: settings.fontSize,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


