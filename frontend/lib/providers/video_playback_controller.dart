// 视频播放控制器：当前播放条目、播放位置、倍速、字幕等

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

// 当前正在播放的媒体条目
final currentPlayingItemProvider = StateProvider<MediaItem?>((ref) => null);

// 当前播放位置（秒）
final currentPositionProvider = StateProvider<Duration>((ref) => Duration.zero);

// 是否正在播放
final isPlayingProvider = StateProvider<bool>((ref) => false);

// 播放倍速：1.0 / 1.25 / 1.5 / 2.0
final playbackRateProvider = StateProvider<double>((ref) => 1.0);

// 当前选中的字幕（字幕语言或轨道 ID，null 表示关闭）
final selectedSubtitleProvider = StateProvider<String?>((ref) => null);

// 是否静音
final isMutedProvider = StateProvider<bool>((ref) => false);

// 是否自动播放（连播模式）- 使用 StateNotifier 支持持久化
final isAutoPlayProvider = StateNotifierProvider<AutoPlayNotifier, bool>((ref) {
  return AutoPlayNotifier();
});

/// 自动播放状态管理器：支持持久化存储
class AutoPlayNotifier extends StateNotifier<bool> {
  static const String _storageKey = 'auto_play_enabled';

  AutoPlayNotifier() : super(true); // 默认开启自动播放

  /// 切换自动播放状态并持久化
  Future<void> toggle() async {
    state = !state;
    await _saveToStorage();
  }

  /// 设置自动播放状态并持久化
  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    await _saveToStorage();
  }

  /// 从本地存储加载设置
  Future<void> loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedValue = prefs.getBool(_storageKey);
      if (savedValue != null) {
        state = savedValue;
      }
    } catch (e) {
      // 加载失败时保持默认值
    }
  }

  /// 保存到本地存储
  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_storageKey, state);
    } catch (e) {
      // 保存失败时忽略
    }
  }
}
