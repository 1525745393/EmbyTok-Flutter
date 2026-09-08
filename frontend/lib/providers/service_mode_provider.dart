// 服务模式设置：视频（Emby 竖屏视频流）/ 音乐（群晖 Audio Station 音乐库）
//
// - AppServiceMode：服务模式枚举
// - serviceModeProvider：当前模式（默认视频），持久化到 SharedPreferences
//
// 模式决定首页展示内容：
// - video：首页 = EmbyTok 视频流首页（HomeScaffold）
// - music：首页 = 群晖音乐库界面（SynologyMusicView）

import 'package:flutter/material.dart' show IconData, Icons;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kStorageKeyServiceMode = 'app_service_mode';

/// 服务模式
enum AppServiceMode {
  /// 视频服务模式：Emby / Plex 视频流
  video('视频服务', Icons.movie_outlined),

  /// 音乐服务模式：群晖 Audio Station 音乐库
  music('音乐服务', Icons.music_note_outlined);

  const AppServiceMode(this.label, this.icon);

  /// 中文展示名（设置页 SegmentedButton / 说明文案）
  final String label;

  /// 展示图标
  final IconData icon;

  /// 存储值（持久化用）
  String get storageValue => name;

  static AppServiceMode fromStorage(String? value) {
    return switch (value) {
      'music' => AppServiceMode.music,
      _ => AppServiceMode.video, // 未知/旧值一律回退视频模式
    };
  }
}

/// 服务模式 Provider：控制首页展示视频流或音乐库
final serviceModeProvider =
    StateNotifierProvider<ServiceModeNotifier, AppServiceMode>((ref) {
  return ServiceModeNotifier();
});

class ServiceModeNotifier extends StateNotifier<AppServiceMode> {
  ServiceModeNotifier() : super(AppServiceMode.video) {
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(_kStorageKeyServiceMode);
      // 校验值合法（避免旧版配置或异常值导致类型错误）
      state = AppServiceMode.fromStorage(value);
    } catch (_) {}
  }

  /// 切换服务模式（持久化）
  Future<void> setMode(AppServiceMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kStorageKeyServiceMode, mode.storageValue);
    } catch (_) {}
  }

  /// 从本地存储重新加载模式（应用启动时自动调用；也可用于外部刷新）
  Future<void> reload() => _loadFromStorage();
}
