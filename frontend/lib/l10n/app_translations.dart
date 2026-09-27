// 多语言国际化基础
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 支持的语言
class AppLocale {
  static const supportedLocales = [
    Locale('zh', 'CN'),
    Locale('en', 'US'),
  ];

  static const fallbackLocale = Locale('zh', 'CN');

  static const _key = 'app_locale_language_code';

  /// 读取已保存的语言
  static Future<Locale> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_key);
      if (code != null) {
        final parts = code.split('_');
        if (parts.length == 2) {
          return Locale(parts[0], parts[1]);
        }
      }
    } catch (_) {}
    return fallbackLocale;
  }

  /// 保存语言
  static Future<void> save(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, '${locale.languageCode}_${locale.countryCode}');
  }
}

/// 简单翻译字典（key -> {languageCode -> text}）
class AppTranslations {
  final Locale locale;
  static AppTranslations? _instance;
  static late Map<String, Map<String, String>> _localizedValues;

  AppTranslations(this.locale) {
    _instance = this;
    _localizedValues = {
      // === 通用 ===
      'app_name': {'zh_CN': 'EmbyTok', 'en_US': 'EmbyTok'},
      'confirm': {'zh_CN': '确认', 'en_US': 'Confirm'},
      'cancel': {'zh_CN': '取消', 'en_US': 'Cancel'},
      'retry': {'zh_CN': '重试', 'en_US': 'Retry'},
      'loading': {'zh_CN': '加载中...', 'en_US': 'Loading...'},
      // === 底部导航 ===
      'nav_home': {'zh_CN': '首页', 'en_US': 'Home'},
      'nav_discover': {'zh_CN': '发现', 'en_US': 'Discover'},
      'nav_libraries': {'zh_CN': '媒体库', 'en_US': 'Libraries'},
      'nav_favorites': {'zh_CN': '收藏', 'en_US': 'Favorites'},
      'nav_settings': {'zh_CN': '设置', 'en_US': 'Settings'},
      // === 视频相关 ===
      'play': {'zh_CN': '播放', 'en_US': 'Play'},
      'add_to_favorites': {'zh_CN': '添加收藏', 'en_US': 'Add to Favorites'},
      'remove_from_favorites': {
        'zh_CN': '取消收藏',
        'en_US': 'Remove from Favorites'
      },
      'watch_later': {'zh_CN': '稍后观看', 'en_US': 'Watch Later'},
      // === 设置页 ===
      'parental_control': {'zh_CN': '家长控制', 'en_US': 'Parental Control'},
      'kids_mode': {'zh_CN': '儿童模式', 'en_US': 'Kids Mode'},
      'language': {'zh_CN': '语言', 'en_US': 'Language'},
    };
  }

  static AppTranslations of(BuildContext context) {
    return Localizations.of<AppTranslations>(context, AppTranslations) ??
        AppTranslations(const Locale('zh', 'CN'));
  }

  String get languageCode => '${locale.languageCode}_${locale.countryCode}';

  String translate(String key) {
    return _localizedValues[key]?[languageCode] ??
        _localizedValues[key]?['zh_CN'] ??
        key;
  }
}

/// 翻译代理
class AppTranslationsDelegate extends LocalizationsDelegate<AppTranslations> {
  const AppTranslationsDelegate();

  @override
  bool isSupported(Locale locale) => ['zh', 'en'].contains(locale.languageCode);

  @override
  Future<AppTranslations> load(Locale locale) async {
    return AppTranslations(locale);
  }

  @override
  bool shouldReload(AppTranslationsDelegate old) => false;
}
