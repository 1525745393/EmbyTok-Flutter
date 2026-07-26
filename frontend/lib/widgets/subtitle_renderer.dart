// 字幕渲染器：在视频画面上叠加字幕文本
// 支持 SRT/VTT/ASS 多种格式，可配置描边、阴影、背景透明度、时间偏移

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

    // settings 仅用于字幕样式，不控制是否显示
    // 是否显示由外部决定（cues 是否为空、selectedSubId 是否为 null）
    final settings = ref.watch(subtitleSettingsProvider);

    // 应用时间轴偏移（正数延迟，负数提前）
    final effectivePosition = position + settings.timeOffsetDuration;

    // 二分查找当前时间匹配的字幕（O(log n)，优于线性搜索 O(n)）
    final current = findCueAtPosition(cues, effectivePosition);
    if (current == null || current.text.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;

    // 字幕文字颜色：优先使用 cue 自带颜色（ASS），否则使用设置颜色
    final textColor = current.color != null && current.color!.isNotEmpty
        ? _parseColor(current.color!)
        : settings.textColor;

    // 字重：ASS 粗体时加粗
    final fontWeight = current.isBold ? FontWeight.w800 : FontWeight.w600;
    // 斜体
    final fontStyle = current.isItalic ? FontStyle.italic : FontStyle.normal;

    // 描边宽度：使用设置值，0 表示不描边
    final strokeWidth = settings.strokeWidth;

    // 背景透明度
    final bgOpacity = settings.bgOpacityValue;

    final textStyle = TextStyle(
      color: textColor,
      fontSize: settings.fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      height: 1.3,
      // 阴影
      shadows: settings.shadowEnabled
          ? [
              Shadow(
                offset: const Offset(0, 1),
                blurRadius: 2.0,
                color: Colors.black.withOpacity(0.8),
              ),
              Shadow(
                offset: const Offset(0, 2),
                blurRadius: 4.0,
                color: Colors.black.withOpacity(0.4),
              ),
            ]
          : null,
    );

    return IgnorePointer(
      child: Align(
        alignment: settings.alignment,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: scheme.surface.withOpacity(bgOpacity),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            children: [
              // 描边层：亮色场景下保证字幕清晰可读（仅在描边宽度 > 0 时渲染）
              if (strokeWidth > 0)
                Text(
                  current.text,
                  textAlign: TextAlign.center,
                  style: textStyle.copyWith(
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = strokeWidth
                      ..strokeJoin = StrokeJoin.round
                      ..color = Colors.black.withOpacity(0.85),
                    // 描边时取消文字阴影，避免双重阴影
                    shadows: null,
                  ),
                ),
              // 填充层
              Text(
                current.text,
                textAlign: TextAlign.center,
                style: textStyle,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 解析十六进制颜色字符串（如 #FF0000 或 FF0000）
  Color _parseColor(String hexColor) {
    try {
      final cleaned = hexColor.replaceAll('#', '');
      if (cleaned.length == 6) {
        return Color(int.parse('FF$cleaned', radix: 16));
      } else if (cleaned.length == 8) {
        return Color(int.parse(cleaned, radix: 16));
      }
    } catch (_) {}
    return Colors.white;
  }
}


