// 视频播放控制器：当前播放条目、播放位置、倍速、字幕等

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../utils/app_preferences.dart';

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

// ---------------- isMuted（自动播放前是否静音） ----------------
class IsMutedNotifier extends StateNotifier<bool> {
  IsMutedNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await const AppPreferencesService().load();
    state = prefs.isMuted;
  }

  Future<void> setMuted(bool value) async {
    state = value;
    await const AppPreferencesService().setIsMuted(value);
  }

  Future<void> toggle() async {
    await setMuted(!state);
  }
}

final isMutedProvider =
    StateNotifierProvider<IsMutedNotifier, bool>((ref) => IsMutedNotifier());

// ---------------- isAutoPlay（自动播放下一集） ----------------
class IsAutoPlayNotifier extends StateNotifier<bool> {
  IsAutoPlayNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await const AppPreferencesService().load();
    state = prefs.isAutoPlay;
  }

  Future<void> setEnabled(bool value) async {
    state = value;
    await const AppPreferencesService().setIsAutoPlay(value);
  }

  Future<void> toggle() async {
    await setEnabled(!state);
  }
}

final isAutoPlayProvider =
    StateNotifierProvider<IsAutoPlayNotifier, bool>((ref) => IsAutoPlayNotifier());
