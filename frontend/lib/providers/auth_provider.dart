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
          logout();
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
        final session = _VideoSession(
          id: _sessionKey(embyServerUrl),
          embyServerUrl: embyServerUrl,
          backendUrl: userMap?['backend_url'] as String?,
          user: user,
          token: token,
        );
        _sessions[session.id] = session;
        _currentId = session.id;
        state = _derive();
        AppLogger.info('登录状态恢复成功',
            data: {'userId': user?.id, 'hasToken': true});
      }
    } catch (e) {
      AppLogger.error('恢复登录状态失败', error: e);
    }
  }

  // 登录：直接调用 Emby 原生 API 并持久化
  Future<void> login(
    String embyServerUrl,
    String username,
    String password, {
    String? backendUrl, // 保留向后兼容
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

      // 持久化：敏感信息存储到安全存储，非敏感信息存储到 SharedPreferences
      // 阶段 1 仍写旧单槽 key（兼容既有恢复/迁移逻辑）；分桶持久化在批次 2 接入。
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
        id: _sessionKey(embyServerUrl),
        embyServerUrl: embyServerUrl,
        backendUrl: backendUrl,
        user: user,
        token: user.accessToken,
      );
      _sessions[session.id] = session;
      _currentId = session.id;
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
      // 清除安全存储中的敏感信息
      try {
        await _secureStorage.delete(key: kStorageKeyAccessToken);
      } catch (_) {
        // 存储操作失败不影响主流程，静默处理
      }
      // 清除 SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(kStorageKeyEmbyServerUrl);
        await prefs.remove(kStorageKeyUser);
        await prefs.remove(kStorageKeyConfig);
      } catch (_) {
        // 存储操作失败不影响主流程，静默处理
      }
      // 登出时清除所有内存缓存，避免账号切换后数据污染
      try {
        _ref.read(cacheControllerProvider).invalidateAll();
      } catch (_) {
        // 存储操作失败不影响主流程，静默处理
      }
      // 批次 1：logout 仍为全局清空（按 id 单台登出在阶段 1-B 接入）。
      _sessions.clear();
      _currentId = null;
      _isLoading = false;
      _error = null;
      state = _derive();
    } finally {
      _loggingOut = false;
    }
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
