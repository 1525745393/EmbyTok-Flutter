// 主题模式设置：dark / light / system，持久化到本地存储

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kStorageKeyTheme = 'embbytok_theme_mode';

// 主题模式 Provider：字符串 'dark' / 'light' / 'system'
final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, String>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<String> {
  ThemeModeNotifier() : super('system') {
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(_kStorageKeyTheme);
      if (value == 'dark' || value == 'light' || value == 'system') {
        state = value;
      }
    } catch (_) {}
  }

  Future<void> setTheme(String mode) async {
    if (mode != 'dark' && mode != 'light' && mode != 'system') return;
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kStorageKeyTheme, mode);
    } catch (_) {}
  }
}
