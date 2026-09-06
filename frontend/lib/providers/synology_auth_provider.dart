// 群晖 Audio Station 认证状态管理
//
// 独立于 Emby 的 authProvider：
// - 群晖使用独立的 sid 会话（非 Emby token）
// - 登录信息（serverUrl + account + sid）持久化到 SharedPreferences
// - 会话恢复后可直接浏览/播放音乐

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/artist_info_service.dart';
import '../services/synology_audio_api.dart';
import '../utils/logger.dart';

/// 群晖认证状态
class SynologyAuthState {
  final bool isLoggedIn;
  final String? serverUrl;
  final String? account;
  final String? sid;
  final bool isLoading;
  final String? error;

  const SynologyAuthState({
    this.isLoggedIn = false,
    this.serverUrl,
    this.account,
    this.sid,
    this.isLoading = false,
    this.error,
  });

  SynologyAuthState copyWith({
    bool? isLoggedIn,
    String? serverUrl,
    String? account,
    String? sid,
    bool? isLoading,
    String? error,
  }) {
    return SynologyAuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      serverUrl: serverUrl ?? this.serverUrl,
      account: account ?? this.account,
      sid: sid ?? this.sid,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

/// 会话持久化键（SharedPreferences）
const _kSynoServerUrl = 'synology_server_url';
const _kSynoAccount = 'synology_account';
const _kSynoSid = 'synology_sid';

class SynologyAuthNotifier extends StateNotifier<SynologyAuthState> {
  final Ref _ref;
  late final SynologyAudioApi _api;

  SynologyAuthNotifier(this._ref) : super(const SynologyAuthState()) {
    _api = _ref.read(synologyAudioApiProvider);
    _restore();
  }

  SynologyAudioApi get api => _api;

  /// 从本地存储恢复群晖会话
  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final serverUrl = prefs.getString(_kSynoServerUrl);
      final account = prefs.getString(_kSynoAccount);
      final sid = prefs.getString(_kSynoSid);
      if (serverUrl != null &&
          serverUrl.isNotEmpty &&
          sid != null &&
          sid.isNotEmpty) {
        _api.restoreSession(
            serverUrl: serverUrl, sid: sid, account: account);
        state = SynologyAuthState(
          isLoggedIn: true,
          serverUrl: serverUrl,
          account: account,
          sid: sid,
        );
        AppLogger.info('群晖 Audio Station 会话恢复成功');
      }
    } catch (e) {
      AppLogger.error('恢复群晖会话失败', error: e);
    }
  }

  /// 登录 Audio Station
  ///
  /// [otpCode]：两步验证开启时，第一次登录抛 SynologyOtpRequiredException，
  /// UI 提示用户输入验证码后带 otpCode 重试。
  Future<void> login({
    required String serverUrl,
    required String account,
    required String password,
    String? otpCode,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final sid = await _api.login(
        serverUrl: serverUrl,
        account: account,
        password: password,
        otpCode: otpCode,
      );
      // 持久化会话
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kSynoServerUrl, _api.serverUrl ?? serverUrl);
      await prefs.setString(_kSynoAccount, account);
      await prefs.setString(_kSynoSid, sid);

      state = SynologyAuthState(
        isLoggedIn: true,
        serverUrl: _api.serverUrl ?? serverUrl,
        account: account,
        sid: sid,
      );
      AppLogger.info('群晖 Audio Station 登录成功', data: {'account': account});
    } catch (e, st) {
      AppLogger.error('群晖 Audio Station 登录失败', error: e, stackTrace: st);
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      rethrow;
    }
  }

  /// 退出登录
  Future<void> logout() async {
    try {
      await _api.logout();
    } catch (_) {}
    // 清除持久化
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kSynoServerUrl);
      await prefs.remove(_kSynoAccount);
      await prefs.remove(_kSynoSid);
    } catch (_) {}
    state = const SynologyAuthState();
  }
}

/// 群晖 API 客户端 Provider（全局单例）
final synologyAudioApiProvider = Provider<SynologyAudioApi>((ref) {
  return SynologyAudioApi();
});

/// 歌手简介服务 Provider（Wikipedia，带内存缓存）
final artistInfoServiceProvider = Provider<ArtistInfoService>((ref) {
  final service = ArtistInfoService();
  ref.onDispose(service.dispose);
  return service;
});

/// 群晖认证 Provider
final synologyAuthProvider =
    StateNotifierProvider<SynologyAuthNotifier, SynologyAuthState>(
  (ref) => SynologyAuthNotifier(ref),
);
