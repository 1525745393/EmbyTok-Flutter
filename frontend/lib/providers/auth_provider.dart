// 认证状态管理：用户登录状态、Token、服务地址等

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../services/embytok_service.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';
import 'cache_providers.dart';
import 'embytok_service_provider.dart';
import 'server_registry_provider.dart'
    show kStorageKeyServerRegistry, kStorageKeyActiveServerId, sameEndpoint;

// 认证状态类
class AuthState {
  const AuthState({
    this.isAuthenticated = false,
    this.user,
    this.backendUrl,
    this.embyServerUrl,
    this.token,
    this.isLoading = false,
    this.error,
  });
  final bool isAuthenticated;
  final User? user;
  final String? backendUrl;
  final String? embyServerUrl;
  final String? token;
  final bool isLoading;
  // error 使用 Object? 以兼容 String 与 AppError 两种错误形式，
  // 避免调用方传入 String 时触发类型转换异常
  final Object? error;

  // sentinel：用于区分"未传参"和"传了 null"，使 copyWith(error: null) 能正确清除 error
  static const Object _sentinel = Object();

  AuthState copyWith({
    bool? isAuthenticated,
    User? user,
    String? backendUrl,
    String? embyServerUrl,
    String? token,
    bool? isLoading,
    Object? error = _sentinel,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: user ?? this.user,
      backendUrl: backendUrl ?? this.backendUrl,
      embyServerUrl: embyServerUrl ?? this.embyServerUrl,
      token: token ?? this.token,
      isLoading: isLoading ?? this.isLoading,
      // 不再强制转换为 AppError?，保留原始错误类型（String / AppError / null）
      error: identical(error, _sentinel) ? this.error : error,
    );
  }
}

/// 单个媒体服务器会话（内部多槽模型）。
///
/// 阶段 1 内部改造：会话按归属标识存入多槽 map，对外 [AuthState] 仍由当前激活槽
/// 派生，既有消费点（只读 isAuthenticated/user/backendUrl/embyServerUrl/token）
/// 透明兼容。阶段 1-B 起归属键切换为注册表条目 id；当前阶段先用服务器地址。
class _VideoSession {
  const _VideoSession({
    required this.id,
    required this.embyServerUrl,
    this.backendUrl,
    this.user,
    this.token,
  });
  final String id;
  final String embyServerUrl;
  final String? backendUrl;
  final User? user;
  final String? token;
}

/// 安全存储 Provider：提供 FlutterSecureStorage 实例
///
/// 测试时可 override 为 Mock 实现
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

// 认证 Notifier
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._ref) : super(const AuthState()) {
    _service = _ref.read(embytokServiceProvider);
    _secureStorage = _ref.read(secureStorageProvider);
    // 移动端专项 #2：Emby API 返回 401（token 过期/失效）时自动登出，
    // GoRouter redirect 基于 isAuthenticated 会随即跳回登录页。
    // P2 修复（登录界面审查 F1）：login() 执行期间的 401 是「登录请求自身」
    // 的凭证校验失败（密码错/账号不存在），不是会话失效——此时若旧服务器仍
    // 处于已登录态，无条件 logout() 会把原服务器会话一起清掉（切换服务器
    // 失败反被登出）。用 _loggingIn 标志排除这段窗口。
    // 测试环境 mock service 的 apiClient 可能为 null，防御性跳过。
    final apiClient = _service.apiClient;
    if (apiClient != null) {
      apiClient.onUnauthorized = () {
        if (_loggingIn) return;
        if (state.isAuthenticated) {
          // 仅失效当前槽，不清其他在线会话；fire-and-forget 与原 logout 一致。
          _expireCurrentSession();
        }
      };
    }
    _loadFromStorage();
  }
  final Ref _ref;
  late final EmbytokService _service;
  late final FlutterSecureStorage _secureStorage;
  bool _loggingOut = false;
  /// 登录请求进行中标志：见构造器内 onUnauthorized 回调的说明
  bool _loggingIn = false;

  /// 多会话槽：key 为会话归属标识。阶段 1 内部模型，对外仅暴露当前激活槽派生态。
  final Map<String, _VideoSession> _sessions = {};
  /// 当前激活会话槽标识；对外 AuthState 由此槽派生。
  String? _currentId;
  /// 跨槽的 UI 瞬态（加载中 / 错误提示），不属于某个会话。
  bool _isLoading = false;
  Object? _error;

  /// 由当前激活会话槽派生对外状态；isLoading/error 为跨槽瞬态字段。
  AuthState _derive() {
    final s = _sessions[_currentId];
    return AuthState(
      isAuthenticated: s != null,
      user: s?.user,
      backendUrl: s?.backendUrl,
      embyServerUrl: s?.embyServerUrl,
      token: s?.token,
      isLoading: _isLoading,
      error: _error,
    );
  }

  /// 归一化会话键：去尾部斜杠（与登录入参清理一致）。
  static String _sessionKey(String serverUrl) =>
      serverUrl.trim().replaceAll(RegExp(r'/+$'), '');

  // 从本地存储恢复登录状态
  Future<void> _loadFromStorage() async {
    try {
      AppLogger.debug('从本地存储恢复登录状态');
      final prefs = await SharedPreferences.getInstance();

      // 1. 优先从分桶恢复多会话；桶为空再回退旧单槽（含明文 config 迁移）。
      await _restoreFromBuckets(prefs);
      if (_sessions.isNotEmpty) {
        AppLogger.info('分桶会话恢复成功', data: {'count': _sessions.length});
        return;
      }

      // 从安全存储读取 token
      String? token;
      try {
        token = await _secureStorage.read(key: kStorageKeyAccessToken);
      } catch (_) {
        // 缓存失效失败不影响登出主流程，静默处理
      }

      // 旧数据迁移：如果安全存储中没有，从旧配置中读取并迁移
      if (token == null || token.isEmpty) {
        final configStr = prefs.getString(kStorageKeyConfig);
        if (configStr != null && configStr.isNotEmpty) {
          try {
            final Map<String, dynamic> config =
                json.decode(configStr) as Map<String, dynamic>;
            final oldToken = config['access_token'] as String?;
            if (oldToken != null && oldToken.isNotEmpty) {
              // 迁移到安全存储
              await _secureStorage.write(
                  key: kStorageKeyAccessToken, value: oldToken);
              // 删除旧的明文存储
              await prefs.remove(kStorageKeyConfig);
              token = oldToken;
              AppLogger.info('完成 token 从明文存储迁移到安全存储');
            }
          } catch (e) {
            AppLogger.warn('token 明文迁移失败，忽略旧数据', data: {'error': e.toString()});
          }
        }
      }

      final embyServerUrl = prefs.getString(kStorageKeyEmbyServerUrl);
      final userJson = prefs.getString(kStorageKeyUser);

      User? user;
      // 保存已解析的 userMap，避免对损坏的 userJson 二次 json.decode 时抛异常
      Map<String, dynamic>? userMap;
      if (userJson != null) {
        try {
          userMap = json.decode(userJson) as Map<String, dynamic>;
          user = User(
            id: userMap['user_id'] as String? ?? '',
            name: userMap['user_name'] as String? ?? '',
            accessToken: token ?? '',
          );
        } catch (e) {
          AppLogger.warn('用户信息解析失败，使用空用户对象', data: {'error': e.toString()});
        }
      }

      if (token != null && token.isNotEmpty && embyServerUrl != null) {
        // 旧单槽迁移落桶：优先按注册表端点 + 用户名匹配条目 id，匹配不到用 url 键。
        final key = _matchRegistryId(prefs, embyServerUrl, user?.name) ??
            _sessionKey(embyServerUrl);
        final session = _VideoSession(
          id: key,
          embyServerUrl: embyServerUrl,
          backendUrl: userMap?['backend_url'] as String?,
          user: user,
          token: token,
        );
        _sessions[session.id] = session;
        _currentId = session.id;
        await _persistSessionBucket(session);
        state = _derive();
        AppLogger.info('登录状态恢复成功',
            data: {'userId': user?.id, 'hasToken': true});
      }
    } catch (e) {
      AppLogger.error('恢复登录状态失败', error: e);
    }
  }

  /// 扫描 `embytok_session_*` 分桶重建内存多会话；按激活指针定 current，
  /// 指针缺失或失效时取唯一槽。损坏桶 / 缺 token / 缺 url 跳过，不崩溃。
  Future<void> _restoreFromBuckets(SharedPreferences prefs) async {
    for (final prefKey in prefs.getKeys()) {
      if (!prefKey.startsWith(kStorageKeySessionPrefix)) continue;
      final raw = prefs.getString(prefKey);
      if (raw == null || raw.isEmpty) continue;
      try {
        final map = json.decode(raw) as Map<String, dynamic>;
        final url = map['server_url'] as String?;
        if (url == null || url.isEmpty) continue;
        final key = prefKey.substring(kStorageKeySessionPrefix.length);
        String? token;
        try {
          token = await _secureStorage.read(key: sessionTokenKey(key));
        } catch (_) {
          // 单个桶读取失败跳过，不影响其他桶
        }
        if (token == null || token.isEmpty) continue;
        final user = User(
          id: map['user_id'] as String? ?? '',
          name: map['user_name'] as String? ?? '',
          accessToken: token,
        );
        _sessions[key] = _VideoSession(
          id: key,
          embyServerUrl: url,
          backendUrl: map['backend_url'] as String?,
          user: user,
          token: token,
        );
      } catch (_) {
        // 损坏 JSON 桶跳过
      }
    }
    if (_sessions.isEmpty) return;
    final activeId = prefs.getString(kStorageKeyActiveServerId);
    if (activeId != null && _sessions.containsKey(activeId)) {
      _currentId = activeId;
    } else {
      _currentId = _sessions.keys.first;
    }
    state = _derive();
  }

  /// 旧单槽迁移时，按 host+端口 + 用户名匹配注册表条目，返回条目 id；未匹配返回 null。
  String? _matchRegistryId(
      SharedPreferences prefs, String url, String? username) {
    if (username == null || username.isEmpty) return null;
    try {
      final raw = prefs.getString(kStorageKeyServerRegistry);
      if (raw == null || raw.isEmpty) return null;
      final list =
          (json.decode(raw) as List<dynamic>).whereType<Map<String, dynamic>>();
      for (final m in list) {
        final regUrl = m['url'] as String? ?? '';
        final regUser = m['username'] as String? ?? '';
        if (regUser == username && sameEndpoint(regUrl, url)) {
          return m['id'] as String?;
        }
      }
    } catch (_) {
      // 注册表损坏时回退 url 键
    }
    return null;
  }

  /// 会话元信息 JSON（沿用旧 user 槽口径：user_id/user_name/backend_url）。
  Map<String, dynamic> _sessionToJson(_VideoSession s) => {
        'server_url': s.embyServerUrl,
        'backend_url': s.backendUrl,
        'user_id': s.user?.id,
        'user_name': s.user?.name,
      };

  /// 写会话分桶：prefs 元信息 + secure token。存储失败静默，不影响内存态。
  Future<void> _persistSessionBucket(_VideoSession s) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(sessionPrefKey(s.id), json.encode(_sessionToJson(s)));
    } catch (_) {
      // 存储失败静默处理
    }
    try {
      if (s.token != null && s.token!.isNotEmpty) {
        await _secureStorage.write(
            key: sessionTokenKey(s.id), value: s.token!);
      }
    } catch (_) {
      // 存储失败静默处理
    }
  }

  /// 删除指定会话分桶（prefs 元信息 + secure token）。
  Future<void> _deleteSessionBucket(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(sessionPrefKey(key));
    } catch (_) {
      // 存储失败静默处理
    }
    try {
      await _secureStorage.delete(key: sessionTokenKey(key));
    } catch (_) {
      // 存储失败静默处理
    }
  }

  /// 清空所有会话分桶（全局登出 / 重置用）。
  Future<void> _deleteAllSessionBuckets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final k in prefs.getKeys().toList()) {
        if (k.startsWith(kStorageKeySessionPrefix)) await prefs.remove(k);
      }
    } catch (_) {
      // 存储失败静默处理
    }
    try {
      final all = await _secureStorage.readAll();
      for (final k in all.keys) {
        if (k.startsWith(kStorageKeyAccessTokenPrefix)) {
          await _secureStorage.delete(key: k);
        }
      }
    } catch (_) {
      // 存储失败静默处理
    }
  }

  /// 归一化会话键：优先注册表条目 id；未传 id 时回退服务器地址（去尾部斜杠）。
  static String _resolveKey({String? serverId, required String url}) =>
      (serverId != null && serverId.trim().isNotEmpty)
          ? serverId.trim()
          : _sessionKey(url);

  // 登录：直接调用 Emby 原生 API 并持久化
  Future<void> login(
    String embyServerUrl,
    String username,
    String password, {
    String? backendUrl, // 保留向后兼容
    String? serverId, // 注册表条目 id；提供时会话按 id 入槽，供多会话隔离
  }) async {
    _loggingIn = true;
    _isLoading = true;
    _error = null;
    state = _derive();
    try {
      AppLogger.info('开始登录',
          data: {'serverUrl': embyServerUrl, 'username': username});
      final user = await _service.login(
        embyServerUrl: embyServerUrl,
        username: username,
        password: password,
      );

      // 持久化：敏感信息存储到安全存储，非敏感信息存储到 SharedPreferences。
      // 分桶按槽 key 落桶（多会话恢复用）；旧单槽 key 作为当前台兼容镜像双写，
      // 待阶段 2 验收后再移除旧单槽写入。
      await _secureStorage.write(
          key: kStorageKeyAccessToken, value: user.accessToken);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kStorageKeyEmbyServerUrl, embyServerUrl);
      await prefs.setString(
          kStorageKeyUser,
          json.encode({
            'backend_url': backendUrl,
            'user_id': user.id,
            'user_name': user.name,
          }));

      final session = _VideoSession(
        id: _resolveKey(serverId: serverId, url: embyServerUrl),
        embyServerUrl: embyServerUrl,
        backendUrl: backendUrl,
        user: user,
        token: user.accessToken,
      );
      _sessions[session.id] = session;
      _currentId = session.id;
      await _persistSessionBucket(session);
      _isLoading = false;
      state = _derive();
      AppLogger.info('登录成功', data: {'userId': user.id, 'userName': user.name});
    } catch (e, stackTrace) {
      AppLogger.error('登录失败', error: e);
      _isLoading = false;
      _error = AppError.wrap(e, stackTrace: stackTrace);
      state = _derive();
      rethrow;
    } finally {
      _loggingIn = false;
    }
  }

  // 退出登录：清除本地 Token 和内存缓存
  Future<void> logout() async {
    // 防重入：并发多个 401 会并发触发回调，登出只需执行一次
    if (_loggingOut) return;
    _loggingOut = true;
    try {
      AppLogger.info('用户登出');
      await _clearLegacySlotStorage();
      await _deleteAllSessionBuckets();
      await _invalidateMemoryCaches();
      // logout 为全局清空（按 id 单台登出走 logoutSession）。
      _sessions.clear();
      _currentId = null;
      _isLoading = false;
      _error = null;
      state = _derive();
    } finally {
      _loggingOut = false;
    }
  }

  /// 清除旧单槽兼容镜像持久化（secure token + prefs url/user/config）。
  ///
  /// 分桶为主存储，旧单槽仅作为当前台兼容镜像；全局登出 / 登出当前台时一并清理。
  Future<void> _clearLegacySlotStorage() async {
    try {
      await _secureStorage.delete(key: kStorageKeyAccessToken);
    } catch (_) {
      // 存储操作失败不影响主流程，静默处理
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(kStorageKeyEmbyServerUrl);
      await prefs.remove(kStorageKeyUser);
      await prefs.remove(kStorageKeyConfig);
    } catch (_) {
      // 存储操作失败不影响主流程，静默处理
    }
  }

  /// 登出/失效时清除内存缓存，避免账号切换后数据污染。
  Future<void> _invalidateMemoryCaches() async {
    try {
      _ref.read(cacheControllerProvider).invalidateAll();
    } catch (_) {
      // 存储操作失败不影响主流程，静默处理
    }
  }

  /// 401 会话失效：仅移除当前激活槽，其他在线槽保留。
  ///
  /// ApiClient 单例回调不带会话标识，故按 [_currentId] 定位失效条目；
  /// 失效台分桶与旧单槽兼容镜像一并清理，其他在线槽分桶保留。
  Future<void> _expireCurrentSession() async {
    final expiredId = _currentId;
    if (expiredId != null) {
      _sessions.remove(expiredId);
      await _deleteSessionBucket(expiredId);
    }
    if (_currentId == expiredId) {
      _currentId = null;
      _isLoading = false;
      _error = null;
    }
    await _clearLegacySlotStorage();
    await _invalidateMemoryCaches();
    state = _derive();
  }

  /// 进入本地媒体库模式：注入 mock 登录状态
  void enterLocalMode() {
    const session = _VideoSession(
      id: 'local',
      embyServerUrl: 'local://',
      user: User(id: 'local_user', name: '本地用户', accessToken: 'local_token'),
      token: 'local_token',
    );
    _sessions[session.id] = session;
    _currentId = session.id;
    state = _derive();
  }

  /// 重置为未登录状态（替代外部直接 .state = const AuthState()）
  void reset() {
    _sessions.clear();
    _currentId = null;
    _isLoading = false;
    _error = null;
    state = _derive();
  }

  /// 当前激活会话槽标识；未登录为 null。供切换、在线态展示与失效定位使用。
  String? get activeSessionId => _currentId;

  /// 指定槽是否处于在线状态（内存会话存在）。
  bool isSessionOnline(String key) => _sessions.containsKey(key);

  /// 当前所有在线会话槽标识（不可变）。
  List<String> onlineSessionIds() => List.unmodifiable(_sessions.keys);

  /// 切换当前激活槽到已在线会话；目标槽不存在时保持现状。
  void switchTo(String key) {
    if (!_sessions.containsKey(key)) return;
    _currentId = key;
    state = _derive();
  }

  /// 按槽登出：仅移除目标会话，不影响其他在线会话。
  ///
  /// 删除目标分桶；目标为当前激活槽时一并清旧单槽兼容镜像，避免残留指向已登出台。
  Future<void> logoutSession(String key) async {
    _sessions.remove(key);
    await _deleteSessionBucket(key);
    if (_currentId == key) {
      _currentId = null;
      _isLoading = false;
      _error = null;
      await _clearLegacySlotStorage();
      state = _derive();
    }
  }

  /// 登录后注册表条目 id 确定，把 url 临时槽重挂到 id 槽（内存 + 分桶），
  /// 避免同一会话遗留 url 键副本。旧键桶删除、新键桶写入；失败不影响内存态。
  Future<void> rekeySession(String oldKey, String newId) async {
    if (newId.isEmpty || oldKey == newId) return;
    final s = _sessions.remove(oldKey);
    if (s == null) return;
    final rekeyed = _VideoSession(
      id: newId,
      embyServerUrl: s.embyServerUrl,
      backendUrl: s.backendUrl,
      user: s.user,
      token: s.token,
    );
    _sessions[newId] = rekeyed;
    if (_currentId == oldKey) _currentId = newId;
    state = _derive();
    await _deleteSessionBucket(oldKey);
    await _persistSessionBucket(rekeyed);
  }
}

/// 顶层认证 Provider：管理整个应用的登录状态、用户信息和访问令牌
///
/// 提供的功能：
/// - [AuthState.isAuthenticated] 是否已登录
/// - [AuthState.embyServerUrl] Emby 服务器地址
/// - [AuthState.token] 访问令牌
/// - [AuthState.user] 当前登录用户信息
final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier(ref));
