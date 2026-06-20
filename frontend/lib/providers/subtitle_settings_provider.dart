/// 字幕设置 Provider：语言、字号、颜色、位置，持久化到本地

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/constants.dart';

/// 字幕设置状态：语言、字号、颜色、位置
class SubtitleSettings {
  /// 选中的字幕语言代码；空字符串表示关闭字幕
  final String language;
  /// 字号：'small' / 'medium' / 'large'
  final String size;
  /// 颜色：'white' / 'yellow'
  final String color;
  /// 位置：'bottom' / 'lower' / 'center'
  final String position;

  const SubtitleSettings({
    this.language = '',
    this.size = kSubtitleSizeMedium,
    this.color = kSubtitleColorWhite,
    this.position = kSubtitlePosBottom,
  });

  SubtitleSettings copyWith({
    String? language,
    String? size,
    String? color,
    String? position,
  }) {
    return SubtitleSettings(
      language: language ?? this.language,
      size: size ?? this.size,
      color: color ?? this.color,
      position: position ?? this.position,
    );
  }

  Map<String, dynamic> toJson() => {
        'language': language,
        'size': size,
        'color': color,
        'position': position,
      };

  factory SubtitleSettings.fromJson(Map<String, dynamic> json) =>
      SubtitleSettings(
        language: json['language'] as String? ?? '',
        size: json['size'] as String? ?? kSubtitleSizeMedium,
        color: json['color'] as String? ?? kSubtitleColorWhite,
        position: json['position'] as String? ?? kSubtitlePosBottom,
      );

  /// 是否已开启字幕（即选择了某种语言）
  bool get enabled => language.isNotEmpty;

  /// 根据字号返回实际的文字大小
  double get fontSize {
    switch (size) {
      case kSubtitleSizeSmall:
        return 14.0;
      case kSubtitleSizeLarge:
        return 24.0;
      case kSubtitleSizeMedium:
      default:
        return 18.0;
    }
  }

  /// 根据颜色名返回实际的文字颜色
  Color get textColor {
    if (color == kSubtitleColorYellow) return const Color(0xFFFFFF00);
    return Colors.white;
  }

  /// 根据位置名返回实际的对齐方式
  Alignment get alignment {
    switch (position) {
      case kSubtitlePosCenter:
        return Alignment.center;
      case kSubtitlePosLower:
        return const Alignment(0.0, 0.55);
      case kSubtitlePosBottom:
      default:
        return Alignment.bottomCenter;
    }
  }
}

/// 字幕设置 Notifier：所有设置变化均自动持久化到 SharedPreferences
class SubtitleSettingsNotifier extends StateNotifier<SubtitleSettings> {
  SubtitleSettingsNotifier() : super(const SubtitleSettings()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(kStorageKeySubtitle);
      if (raw == null || raw.isEmpty) return;
      final map = json.decode(raw) as Map<String, dynamic>;
      state = SubtitleSettings.fromJson(map);
    } catch (_) {}
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kStorageKeySubtitle, json.encode(state.toJson()));
    } catch (_) {}
  }

  /// 批量更新设置
  void update({
    String? language,
    String? size,
    String? color,
    String? position,
  }) {
    state = state.copyWith(
      language: language,
      size: size,
      color: color,
      position: position,
    );
    _persist();
  }

  /// 设置字幕语言
  void setLanguage(String language) => update(language: language);
  /// 设置字号
  void setSize(String size) => update(size: size);
  /// 设置颜色
  void setColor(String color) => update(color: color);
  /// 设置位置
  void setPosition(String position) => update(position: position);
}

/// 顶层字幕设置 Provider
final subtitleSettingsProvider = StateNotifierProvider<SubtitleSettingsNotifier,
    SubtitleSettings>((ref) => SubtitleSettingsNotifier());
