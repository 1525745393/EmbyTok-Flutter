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

/// MPV 解码方式（映射 mpv --hwdec 参数）
enum MpvHwDec {
  /// 自动（硬解优先，失败回退软解）：--hwdec=auto-safe
  auto,
  /// 强制硬解：--hwdec=auto
  hard,
  /// 强制软解：--hwdec=copy
  soft,
}

/// 播放器引擎设置 State
class PlayerEngineSettings { // 强制覆盖 ASS 字体样式

  const PlayerEngineSettings({
    this.defaultEngine = PlayerEngine.exo,
    this.thirdPartyFallback = true,
    this.preferredExternalPlayerPackage,
    this.mpvHwDec = MpvHwDec.auto,
    this.mpvCacheSizeMb = 16,
    this.mpvForceAssStyle = false,
  });
  final PlayerEngine defaultEngine;
  final bool thirdPartyFallback; // 第三方兜底开关
  final String? preferredExternalPlayerPackage; // 首选外部播放器包名

  // MPV 专属设置（PRD R2）
  final MpvHwDec mpvHwDec; // 解码方式
  final int mpvCacheSizeMb; // 网络缓存大小（MB）
  final bool mpvForceAssStyle;

  PlayerEngineSettings copyWith({
    PlayerEngine? defaultEngine,
    bool? thirdPartyFallback,
    String? preferredExternalPlayerPackage,
    MpvHwDec? mpvHwDec,
    int? mpvCacheSizeMb,
    bool? mpvForceAssStyle,
  }) {
    return PlayerEngineSettings(
      defaultEngine: defaultEngine ?? this.defaultEngine,
      thirdPartyFallback: thirdPartyFallback ?? this.thirdPartyFallback,
      preferredExternalPlayerPackage:
          preferredExternalPlayerPackage ?? this.preferredExternalPlayerPackage,
      mpvHwDec: mpvHwDec ?? this.mpvHwDec,
      mpvCacheSizeMb: mpvCacheSizeMb ?? this.mpvCacheSizeMb,
      mpvForceAssStyle: mpvForceAssStyle ?? this.mpvForceAssStyle,
    );
  }
}

/// 播放器引擎设置 Notifier
class PlayerEngineSettingsNotifier
    extends StateNotifier<PlayerEngineSettings> {

  PlayerEngineSettingsNotifier() : super(const PlayerEngineSettings()) {
    _load();
  }
  static const _keyDefaultEngine = 'player_default_engine';
  static const _keyThirdPartyFallback = 'player_third_party_fallback';
  static const _keyMpvHwDec = 'player_mpv_hwdec';
  static const _keyMpvCacheSize = 'player_mpv_cache_size';
  static const _keyMpvForceAss = 'player_mpv_force_ass_style';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final engineStr = prefs.getString(_keyDefaultEngine) ?? 'exo';
    final engine = PlayerEngine.values.firstWhere(
      (e) => e.name == engineStr,
      orElse: () => PlayerEngine.exo,
    );
    final hwDecStr = prefs.getString(_keyMpvHwDec) ?? 'auto';
    final hwDec = MpvHwDec.values.firstWhere(
      (e) => e.name == hwDecStr,
      orElse: () => MpvHwDec.auto,
    );
    state = PlayerEngineSettings(
      defaultEngine: engine,
      thirdPartyFallback: prefs.getBool(_keyThirdPartyFallback) ?? true,
      mpvHwDec: hwDec,
      mpvCacheSizeMb: prefs.getInt(_keyMpvCacheSize) ?? 16,
      mpvForceAssStyle: prefs.getBool(_keyMpvForceAss) ?? false,
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

  Future<void> setMpvHwDec(MpvHwDec mode) async {
    state = state.copyWith(mpvHwDec: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMpvHwDec, mode.name);
  }

  Future<void> setMpvCacheSizeMb(int mb) async {
    state = state.copyWith(mpvCacheSizeMb: mb);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyMpvCacheSize, mb);
  }

  Future<void> setMpvForceAssStyle(bool enabled) async {
    state = state.copyWith(mpvForceAssStyle: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyMpvForceAss, enabled);
  }
}

/// 播放器引擎设置 Provider
final playerEngineSettingsProvider =
    StateNotifierProvider<PlayerEngineSettingsNotifier, PlayerEngineSettings>(
        (ref) => PlayerEngineSettingsNotifier());
