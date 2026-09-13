// 群晖 Audio Station 认证状态管理
//
// 独立于 Emby 的 authProvider：
// - 群晖使用独立的 sid 会话（非 Emby token）
// - 登录信息（serverUrl + account）持久化到 SharedPreferences，
//   sid 会话存安全存储（FlutterSecureStorage，替代早期明文存储）
// - 会话恢复后可直接浏览/播放音乐

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/artist_info_service.dart';
import '../services/synology_audio_api.dart';
import '../utils/logger.dart';
import 'auth_provider.dart' show secureStorageProvider;

/// 群晖认证状态
class SynologyAuthState {

  const SynologyAuthState({
    this.isLoggedIn = false,
    this.serverUrl,
    this.account,
    this.sid,
    this.isLoading = false,
    this.error,
  });
  final bool isLoggedIn;
  final String? serverUrl;
  final String? account;
  final String? sid;
  final bool isLoading;
  final String? error;

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

/// 会话持久化键
const _kSynoServerUrl = 'synology_server_url';
const _kSynoAccount = 'synology_account';
const _kSynoSid = 'synology_sid';

/// sid 安全存储键（新；旧明文 key 用于迁移）
const _kSynoSidSecure = 'synology_sid_secure';

class SynologyAuthNotifier extends StateNotifier<SynologyAuthState> {

  SynologyAuthNotifier(this._ref) : super(const SynologyAuthState()) {
    _api = _ref.read(synologyAudioApiProvider);
    _secureStorage = _ref.read(secureStorageProvider);
    _restore();
  }
  final Ref _ref;
  late final SynologyAudioApi _api;
  late final FlutterSecureStorage _secureStorage;

  SynologyAudioApi get api => _api;

  /// 从本地存储恢复群晖会话（sid 优先安全存储，旧明文自动迁移）
  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final serverUrl = prefs.getString(_kSynoServerUrl);
      final account = prefs.getString(_kSynoAccount);
      // 安全存储优先；无则读旧明文并迁移
      var sid = await _readSecureSid();
      if ((sid == null || sid.isEmpty) && prefs.getString(_kSynoSid) != null) {
        sid = prefs.getString(_kSynoSid);
        if (sid != null && sid.isNotEmpty) {
          await _secureStorage.write(key: _kSynoSidSecure, value: sid);
          await prefs.remove(_kSynoSid);
          AppLogger.info('群晖 sid 已从明文迁移到安全存储');
        }
      }
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

  /// 重新从本地存储恢复会话（测试用）
  Future<void> reloadSid() => _restore();

  Future<String?> _readSecureSid() async {
    try {
      return await _secureStorage.read(key: _kSynoSidSecure);
    } catch (_) {
      return null;
    }
  }

  /// 用已有 sid 恢复会话（服务器切换 / 免密恢复；sid 写入安全存储）
  ///
  /// 供服务器管理页在切换群晖服务器时调用，避免重复输入密码。
  Future<void> restoreSession({
    required String serverUrl,
    required String account,
    required String sid,
  }) async {
    try {
      _api.restoreSession(serverUrl: serverUrl, sid: sid, account: account);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kSynoServerUrl, serverUrl);
      await prefs.setString(_kSynoAccount, account);
      await _secureStorage.write(key: _kSynoSidSecure, value: sid);
      state = SynologyAuthState(
        isLoggedIn: true,
        serverUrl: serverUrl,
        account: account,
        sid: sid,
      );
      AppLogger.info('群晖 Audio Station 会话恢复', data: {'account': account});
    } catch (e) {
      AppLogger.error('恢复群晖会话失败', error: e);
      rethrow;
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
      // 持久化会话（sid 存安全存储；明文旧键清理）
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kSynoServerUrl, _api.serverUrl ?? serverUrl);
      await prefs.setString(_kSynoAccount, account);
      await _secureStorage.write(key: _kSynoSidSecure, value: sid);
      await prefs.remove(_kSynoSid);

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
    } catch (_) {
    // 存储操作失败不影响主流程，静默处理
  }
    // 清除持久化（含安全存储 sid）
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kSynoServerUrl);
      await prefs.remove(_kSynoAccount);
      await prefs.remove(_kSynoSid);
    } catch (_) {
    // 存储操作失败不影响主流程，静默处理
  }
    try {
      await _secureStorage.delete(key: _kSynoSidSecure);
    } catch (_) {
    // 存储操作失败不影响主流程，静默处理
  }
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
