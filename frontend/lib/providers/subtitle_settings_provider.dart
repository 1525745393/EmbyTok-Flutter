// 字幕设置 Provider：语言、字号、颜色、位置，持久化到本地

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/constants.dart';
import '../utils/colors.dart';

// 字幕设置状态
class SubtitleSettings {
  final String language; // 空字符串表示关闭
  final String size; // small / medium / large
  final String color; // white / yellow
  final String position; // bottom / lower / center

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

  bool get enabled => language.isNotEmpty;

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

  Color get textColor {
    if (color == kSubtitleColorYellow) return const Color(0xFFFFFF00);
    return textPrimary;
  }

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

  void setLanguage(String language) => update(language: language);
  void setSize(String size) => update(size: size);
  void setColor(String color) => update(color: color);
  void setPosition(String position) => update(position: position);
}

final subtitleSettingsProvider = StateNotifierProvider<SubtitleSettingsNotifier,
    SubtitleSettings>((ref) => SubtitleSettingsNotifier());
