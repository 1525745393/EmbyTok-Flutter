/// 用户偏好设置 Provider：主题模式、默认倍速、默认字幕语言等

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/app_preferences.dart';

// ---------------- 默认播放倍速 ----------------

/// 默认播放倍速：0.25 - 3.0 之间
class DefaultPlaybackRateNotifier extends StateNotifier<double> {
  DefaultPlaybackRateNotifier() : super(1.0) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await const AppPreferencesService().load();
    state = prefs.defaultPlaybackRate;
  }

  Future<void> set(double rate) async {
    if (rate >= 0.25 && rate <= 3.0) {
      state = rate;
      await const AppPreferencesService().setDefaultPlaybackRate(rate);
    }
  }
}

/// 顶层默认播放倍速 Provider
final defaultPlaybackRateProvider =
    StateNotifierProvider<DefaultPlaybackRateNotifier, double>(
        (ref) => DefaultPlaybackRateNotifier());

// ---------------- 默认字幕语言 ----------------

/// 默认字幕语言：如 'zh-CN'、'en'；空字符串表示关闭
class DefaultSubtitleLanguageNotifier extends StateNotifier<String> {
  DefaultSubtitleLanguageNotifier() : super('') {
    _load();
  }

  Future<void> _load() async {
    final prefs = await const AppPreferencesService().load();
    state = prefs.defaultSubtitleLanguage;
  }

  Future<void> set(String lang) async {
    state = lang;
    await const AppPreferencesService().setDefaultSubtitleLanguage(lang);
  }
}

/// 顶层默认字幕语言 Provider
final defaultSubtitleLanguageProvider =
    StateNotifierProvider<DefaultSubtitleLanguageNotifier, String>(
        (ref) => DefaultSubtitleLanguageNotifier());

// ---------------- 字幕大小 ----------------

/// 字幕大小：如 'small'、'medium'、'large'
class SubtitleSizeNotifier extends StateNotifier<String> {
  SubtitleSizeNotifier() : super('medium') {
    _load();
  }

  Future<void> _load() async {
    final prefs = await const AppPreferencesService().load();
    state = prefs.subtitleSize;
  }

  Future<void> set(String size) async {
    state = size;
    await const AppPreferencesService().setSubtitleSize(size);
  }
}

/// 顶层字幕大小 Provider
final subtitleSizeProvider =
    StateNotifierProvider<SubtitleSizeNotifier, String>(
        (ref) => SubtitleSizeNotifier());

// ---------------- 缓存大小 ----------------

/// 缓存大小（字节）：仅用于 UI 展示当前缓存状态
class CacheSizeNotifier extends StateNotifier<int> {
  CacheSizeNotifier() : super(0);

  void set(int bytes) => state = bytes;
  void clear() => state = 0;
}

/// 顶层缓存大小 Provider
final cacheSizeProvider =
    StateNotifierProvider<CacheSizeNotifier, int>(
        (ref) => CacheSizeNotifier());
