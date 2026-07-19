// 字幕显示组件：在视频画面上叠加字幕文本
// 支持样式配置（字体大小、颜色、背景）

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/subtitle_track.dart';
import '../providers/providers.dart';
import 'subtitle_renderer.dart';

/// 字幕显示组件
/// 接收字幕 cues 数据和当前播放位置，自动显示对应时间的字幕
class SubtitleWidget extends ConsumerWidget {
  /// 当前播放位置
  final Duration position;
  
  /// 字幕 cues 列表
  final List<SubtitleCue> cues;
  
  /// 是否启用字幕显示
  final bool enabled;

  const SubtitleWidget({
    super.key,
    required this.position,
    required this.cues,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 使用已有的 SubtitleRenderer 组件
    return SubtitleRenderer(
      position: position,
      cues: cues,
      enabled: enabled,
    );
  }
}

/// 字幕样式配置
class SubtitleStyle {
  final double fontSize;
  final Color textColor;
  final Color backgroundColor;
  final FontWeight fontWeight;
  final double letterSpacing;
  final double wordSpacing;
  final double lineHeight;
  final bool showBackground;

  const SubtitleStyle({
    this.fontSize = 18.0,
    required this.textColor,
    required this.backgroundColor,
    this.fontWeight = FontWeight.w600,
    this.letterSpacing = 0.0,
    this.wordSpacing = 0.0,
    this.lineHeight = 1.3,
    this.showBackground = true,
  });

  SubtitleStyle copyWith({
    double? fontSize,
    Color? textColor,
    Color? backgroundColor,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? wordSpacing,
    double? lineHeight,
    bool? showBackground,
  }) {
    return SubtitleStyle(
      fontSize: fontSize ?? this.fontSize,
      textColor: textColor ?? this.textColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      fontWeight: fontWeight ?? this.fontWeight,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      wordSpacing: wordSpacing ?? this.wordSpacing,
      lineHeight: lineHeight ?? this.lineHeight,
      showBackground: showBackground ?? this.showBackground,
    );
  }

  /// 从 SubtitleSettings 创建样式
  factory SubtitleStyle.fromSettings(SubtitleSettings settings, ColorScheme scheme) {
    return SubtitleStyle(
      fontSize: settings.fontSize,
      textColor: settings.textColor,
      backgroundColor: scheme.surface.withOpacity(0.54),
      fontWeight: FontWeight.w600,
      lineHeight: 1.3,
      showBackground: true,
    );
  }
}
