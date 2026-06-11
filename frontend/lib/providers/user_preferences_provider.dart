// 用户偏好设置 Provider：主题模式、默认倍速、默认字幕语言/字号等

import 'package:flutter_riverpod/flutter_riverpod.dart';

// 默认播放倍速
class DefaultPlaybackRateNotifier extends StateNotifier<double> {
  DefaultPlaybackRateNotifier() : super(1.0);

  void set(double rate) {
    if (rate >= 0.25 && rate <= 3.0) state = rate;
  }
}

final defaultPlaybackRateProvider =
    StateNotifierProvider<DefaultPlaybackRateNotifier, double>(
        (ref) => DefaultPlaybackRateNotifier());

// 默认字幕语言代码（如 'zh-CN', 'en'，空字符串代表关闭）
class DefaultSubtitleLanguageNotifier extends StateNotifier<String> {
  DefaultSubtitleLanguageNotifier() : super('');

  void set(String lang) => state = lang;
}

final defaultSubtitleLanguageProvider =
    StateNotifierProvider<DefaultSubtitleLanguageNotifier, String>(
        (ref) => DefaultSubtitleLanguageNotifier());

// 缓存大小
class CacheSizeNotifier extends StateNotifier<int> {
  CacheSizeNotifier() : super(0);

  void set(int bytes) => state = bytes;
  void clear() => state = 0;
}

final cacheSizeProvider =
    StateNotifierProvider<CacheSizeNotifier, int>(
        (ref) => CacheSizeNotifier());
