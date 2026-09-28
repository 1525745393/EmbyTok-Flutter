import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 播放器引擎类型
enum PlayerEngine {
  /// 自动选择（根据媒体编码/设备能力）
  auto,
  /// ExoPlayer（默认，video_player 内核）
  exo,
  /// MPV（深度定制：软硬解/缓存/ASS 样式）
  mpv,
  /// VLC（网络流兼容性兜底）
  vlc,
  /// 第三方外部播放器兜底
  external,
}

/// 播放器引擎设置 State
class PlayerEngineSettings {
  final PlayerEngine defaultEngine;
  final bool thirdPartyFallback; // 第三方兜底开关
  final String? preferredExternalPlayerPackage; // 首选外部播放器包名

  const PlayerEngineSettings({
    this.defaultEngine = PlayerEngine.exo,
    this.thirdPartyFallback = true,
    this.preferredExternalPlayerPackage,
  });

  PlayerEngineSettings copyWith({
    PlayerEngine? defaultEngine,
    bool? thirdPartyFallback,
    String? preferredExternalPlayerPackage,
  }) {
    return PlayerEngineSettings(
      defaultEngine: defaultEngine ?? this.defaultEngine,
      thirdPartyFallback: thirdPartyFallback ?? this.thirdPartyFallback,
      preferredExternalPlayerPackage:
          preferredExternalPlayerPackage ?? this.preferredExternalPlayerPackage,
    );
  }
}

/// 播放器引擎设置 Notifier
class PlayerEngineSettingsNotifier
    extends StateNotifier<PlayerEngineSettings> {
  static const _keyDefaultEngine = 'player_default_engine';
  static const _keyThirdPartyFallback = 'player_third_party_fallback';

  PlayerEngineSettingsNotifier() : super(const PlayerEngineSettings()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final engineStr = prefs.getString(_keyDefaultEngine) ?? 'exo';
    final engine = PlayerEngine.values.firstWhere(
      (e) => e.name == engineStr,
      orElse: () => PlayerEngine.exo,
    );
    state = PlayerEngineSettings(
      defaultEngine: engine,
      thirdPartyFallback: prefs.getBool(_keyThirdPartyFallback) ?? true,
    );
  }

  Future<void> setDefaultEngine(PlayerEngine engine) async {
    state = state.copyWith(defaultEngine: engine);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDefaultEngine, engine.name);
  }

  Future<void> setThirdPartyFallback(bool enabled) async {
    state = state.copyWith(thirdPartyFallback: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyThirdPartyFallback, enabled);
  }
}

/// 播放器引擎设置 Provider
final playerEngineSettingsProvider =
    StateNotifierProvider<PlayerEngineSettingsNotifier, PlayerEngineSettings>(
        (ref) => PlayerEngineSettingsNotifier());
