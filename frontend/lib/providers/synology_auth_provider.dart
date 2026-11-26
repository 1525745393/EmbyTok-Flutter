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
import 'service_mode_provider.dart';
import 'syno_accounts_provider.dart';

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

/// 单个群晖会话（内部多槽模型，#170 批次 A1）。
///
/// 会话按归属标识存入多槽 map，对外 [SynologyAuthState] 仍由当前激活槽派生，
/// 既有消费点（isLoggedIn/serverUrl/account/sid/api）透明兼容。
class _SynoSession {
  const _SynoSession({
    required this.id,
    required this.serverUrl,
    required this.account,
    required this.sid,
  });
  final String id;
  final String serverUrl;
  final String account;
  final String sid;
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

  /// 多会话槽：key 为会话归属标识。阶段 A1 内部模型，对外仅暴露当前激活槽派生态。
  final Map<String, _SynoSession> _sessions = {};
  /// 当前激活会话槽标识；对外 SynologyAuthState 由此槽派生。
  String? _currentId;
  /// 跨槽的 UI 瞬态（加载中 / 错误提示），不属于某个会话。
  bool _isLoading = false;
  String? _error;

  SynologyAudioApi get api => _api;

  /// 由当前激活会话槽派生对外状态；isLoading/error 为跨槽瞬态字段。
  SynologyAuthState _derive() {
    final s = _sessions[_currentId];
    return SynologyAuthState(
      isLoggedIn: s != null,
      serverUrl: s?.serverUrl,
      account: s?.account,
      sid: s?.sid,
      isLoading: _isLoading,
      error: _error,
    );
  }

  /// 归一化会话键：去尾部斜杠。
  static String _sessionKey(String url) =>
      url.trim().replaceAll(RegExp(r'/+$'), '');

  /// 解析槽键：优先注册表条目 id；未提供时回退 `url::account`。
  static String _resolveKey({
    String? serverId,
    required String url,
    required String account,
  }) =>
      (serverId != null && serverId.trim().isNotEmpty)
          ? serverId.trim()
          : '${_sessionKey(url)}::$account';

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
        final session = _SynoSession(
          id: _resolveKey(url: serverUrl, account: account ?? ''),
          serverUrl: serverUrl,
          account: account ?? '',
          sid: sid,
        );
        _sessions[session.id] = session;
        _currentId = session.id;
        state = _derive();
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
      final session = _SynoSession(
        id: _resolveKey(url: serverUrl, account: account),
        serverUrl: serverUrl,
        account: account,
        sid: sid,
      );
      _sessions[session.id] = session;
      _currentId = session.id;
      state = _derive();
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
    _isLoading = true;
    _error = null;
    state = _derive();
    try {
      final sid = await _api.login(
        serverUrl: serverUrl,
        account: account,
        password: password,
        otpCode: otpCode,
      );
      // 持久化会话（sid 存安全存储；明文旧键清理）。
      // 分槽落内存；旧单槽 key 作为当前台兼容镜像双写，待分桶持久化验收后移除。
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kSynoServerUrl, _api.serverUrl ?? serverUrl);
      await prefs.setString(_kSynoAccount, account);
      await _secureStorage.write(key: _kSynoSidSecure, value: sid);
      await prefs.remove(_kSynoSid);

      final session = _SynoSession(
        id: _resolveKey(url: _api.serverUrl ?? serverUrl, account: account),
        serverUrl: _api.serverUrl ?? serverUrl,
        account: account,
        sid: sid,
      );
      _sessions[session.id] = session;
      _currentId = session.id;
      _isLoading = false;
      state = _derive();
      AppLogger.info('群晖 Audio Station 登录成功', data: {'account': account});
    } catch (e, st) {
      AppLogger.error('群晖 Audio Station 登录失败', error: e, stackTrace: st);
      // 登录请求自身失败：保留其他在线槽，仅记录跨槽错误瞬态。
      _isLoading = false;
      _error = e.toString();
      state = _derive();
      rethrow;
    }
  }

  /// 清除当前群晖会话状态与持久化（不触发服务模式切换）：
  ///
  /// 供服务器切换时 sid 失效回退密码登录使用；logout() 会附带
  /// setMode(video) 的模式副作用，切换场景误用会导致服务模式被切走。
  Future<void> clearInvalidSession() async {
    _api.clearSession();
    _sessions.remove(_currentId);
    _currentId = null;
    _isLoading = false;
    _error = null;
    await _clearLegacySessionStorage();
    state = _derive();
  }

  /// 清除旧单槽兼容镜像持久化（prefs url/account/明文 sid + secure sid）。
  Future<void> _clearLegacySessionStorage() async {
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
  }

  /// 退出登录（全局清空所有槽）
  Future<void> logout() async {
    try {
      await _api.logout();
    } catch (_) {
      // 存储操作失败不影响主流程，静默处理
    }
    await _clearLegacySessionStorage();
    // 全局登出：清空内存所有会话（按单台登出走 logoutSession）。
    _sessions.clear();
    _currentId = null;
    _isLoading = false;
    _error = null;
    state = _derive();
    // 解除群晖当前账号指针（含持久化 current key），避免 accountScopedKey
    // 按陈旧账号分桶；已保存的账号列表与密码保留，不在登出时清除。
    await _ref.read(synoAccountsProvider.notifier).clearCurrent();
    // 音乐服务模式依赖群晖账号：登出后同步回退视频模式，
    // 否则后续登录其他模式（Emby/本地）后首页仍按音乐模式渲染（异常）
    await _ref.read(serviceModeProvider.notifier).setMode(AppServiceMode.video);
  }

  /// 会话过期自动续期（PRD #30）：用当前账号保存的密码重新登录拿新 sid。
  /// 成功返回 true；无保存密码或登录失败返回 false（调用方应引导手动登录）。
  Future<bool> renewSession() async {
    try {
      final accounts = _ref.read(synoAccountsProvider);
      final cur = accounts.current;
      if (cur == null) return false;
      final pwd = await _ref
          .read(synoAccountsProvider.notifier)
          .readPassword(cur.accountId);
      if (pwd == null || pwd.isEmpty) return false;
      await login(
        serverUrl: cur.serverUrl,
        account: cur.username,
        password: pwd,
      );
      AppLogger.info('群晖会话已自动续期', data: {'account': cur.username});
      return true;
    } catch (e) {
      AppLogger.warn('群晖会话自动续期失败', data: {'err': e.toString()});
      return false;
    }
  }

  /// 当前激活会话槽标识；未登录为 null。
  String? get activeSessionId => _currentId;

  /// 指定槽是否处于在线状态（内存会话存在）。
  bool isSessionOnline(String key) => _sessions.containsKey(key);

  /// 当前所有在线会话槽标识（不可变）。
  List<String> onlineSessionIds() => List.unmodifiable(_sessions.keys);

  /// 切换当前激活槽到已在线会话；目标槽不存在时保持现状。
  ///
  /// 切槽时把目标会话回填到 API 单例，避免后续请求携带错 sid/账号。
  void switchTo(String key) {
    final s = _sessions[key];
    if (s == null) return;
    _currentId = key;
    _api.restoreSession(
        serverUrl: s.serverUrl, sid: s.sid, account: s.account);
    state = _derive();
  }

  /// 按槽登出：仅移除目标会话，不影响其他在线会话。
  ///
  /// 目标为当前激活槽时一并解除 API 绑定与旧单槽持久化；非当前槽仅移除内存。
  Future<void> logoutSession(String key) async {
    final removed = _sessions.remove(key);
    if (removed == null) return;
    if (_currentId == key) {
      _api.clearSession();
      await _clearLegacySessionStorage();
      _currentId = null;
      _isLoading = false;
      _error = null;
    }
    state = _derive();
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
