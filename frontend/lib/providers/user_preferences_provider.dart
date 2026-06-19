/// 用户偏好设置 Provider：主题模式、默认倍速、默认字幕语言等

import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---------------- 默认播放倍速 ----------------

/// 默认播放倍速：0.25 - 3.0 之间
class DefaultPlaybackRateNotifier extends StateNotifier<double> {
  DefaultPlaybackRateNotifier() : super(1.0);

  void set(double rate) {
    if (rate >= 0.25 && rate <= 3.0) state = rate;
  }
}

/// 顶层默认播放倍速 Provider
final defaultPlaybackRateProvider =
    StateNotifierProvider<DefaultPlaybackRateNotifier, double>(
        (ref) => DefaultPlaybackRateNotifier());

// ---------------- 默认字幕语言 ----------------

/// 默认字幕语言：如 'zh-CN'、'en'；空字符串表示关闭
class DefaultSubtitleLanguageNotifier extends StateNotifier<String> {
  DefaultSubtitleLanguageNotifier() : super('');

  void set(String lang) => state = lang;
}

/// 顶层默认字幕语言 Provider
final defaultSubtitleLanguageProvider =
    StateNotifierProvider<DefaultSubtitleLanguageNotifier, String>(
        (ref) => DefaultSubtitleLanguageNotifier());

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
