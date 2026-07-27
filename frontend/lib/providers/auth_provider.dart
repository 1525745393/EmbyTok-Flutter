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
  final bool isAuthenticated;
  final User? user;
  final String? backendUrl;
  final String? embyServerUrl;
  final String? token;
  final bool isLoading;
  final AppError? error;

  const AuthState({
    this.isAuthenticated = false,
    this.user,
    this.backendUrl,
    this.embyServerUrl,
    this.token,
    this.isLoading = false,
    this.error,
  });

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
      error: identical(error, _sentinel) ? this.error : error as AppError?,
    );
  }
}

/// 安全存储 Provider：提供 FlutterSecureStorage 实例
/// 
/// 测试时可 override 为 Mock 实现
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

// 认证 Notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final Ref _ref;
  late final EmbytokService _service;
  late final FlutterSecureStorage _secureStorage;

  AuthNotifier(this._ref) : super(const AuthState()) {
    _service = _ref.read(embytokServiceProvider);
    _secureStorage = _ref.read(secureStorageProvider);
    _loadFromStorage();
  }

  // 从本地存储恢复登录状态
  Future<void> _loadFromStorage() async {
    try {
      AppLogger.debug('从本地存储恢复登录状态');
      final prefs = await SharedPreferences.getInstance();

      // 从安全存储读取 token
      String? token;
      try {
        token = await _secureStorage.read(key: kStorageKeyAccessToken);
      } catch (_) {}

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
              await _secureStorage.write(key: kStorageKeyAccessToken, value: oldToken);
              // 删除旧的明文存储
              await prefs.remove(kStorageKeyConfig);
              token = oldToken;
              AppLogger.info('完成 token 从明文存储迁移到安全存储');
            }
          } catch (_) {}
        }
      }

      final embyServerUrl = prefs.getString(kStorageKeyEmbyServerUrl);
      final userJson = prefs.getString(kStorageKeyUser);

      User? user;
      if (userJson != null) {
        try {
          final Map<String, dynamic> userMap =
              json.decode(userJson) as Map<String, dynamic>;
          user = User(
            id: userMap['user_id'] as String? ?? '',
            name: userMap['user_name'] as String? ?? '',
            accessToken: token ?? '',
          );
        } catch (_) {}
      }

      if (token != null && token.isNotEmpty && embyServerUrl != null) {
        state = AuthState(
          isAuthenticated: true,
          user: user,
          backendUrl: userJson != null
              ? (json.decode(userJson) as Map<String, dynamic>)['backend_url'] as String?
              : null,
          embyServerUrl: embyServerUrl,
          token: token,
        );
        AppLogger.info('登录状态恢复成功', data: {'userId': user?.id, 'hasToken': true});
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
    state = state.copyWith(isLoading: true, error: null);
    try {
      AppLogger.info('开始登录', data: {'serverUrl': embyServerUrl, 'username': username});
      final user = await _service.login(
        embyServerUrl: embyServerUrl,
        username: username,
        password: password,
      );

      // 持久化：敏感信息存储到安全存储，非敏感信息存储到 SharedPreferences
      await _secureStorage.write(key: kStorageKeyAccessToken, value: user.accessToken);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kStorageKeyEmbyServerUrl, embyServerUrl);
      await prefs.setString(kStorageKeyUser, json.encode({
        'backend_url': backendUrl ?? '',
        'user_id': user.id,
        'user_name': user.name,
      }));

      state = AuthState(
        isAuthenticated: true,
        user: user,
        backendUrl: backendUrl ?? '',
        embyServerUrl: embyServerUrl,
        token: user.accessToken,
      );
      AppLogger.info('登录成功', data: {'userId': user.id, 'userName': user.name});
    } catch (e, stackTrace) {
      AppLogger.error('登录失败', error: e);
      state = state.copyWith(
        isLoading: false,
        error: AppError.wrap(e, stackTrace: stackTrace),
      );
      rethrow;
    }
  }

  // 退出登录：清除本地 Token 和内存缓存
  Future<void> logout() async {
    AppLogger.info('用户登出');
    // 清除安全存储中的敏感信息
    try {
      await _secureStorage.delete(key: kStorageKeyAccessToken);
    } catch (_) {}
    // 清除 SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(kStorageKeyEmbyServerUrl);
      await prefs.remove(kStorageKeyUser);
      await prefs.remove(kStorageKeyConfig);
    } catch (_) {}
    // 登出时清除所有内存缓存，避免账号切换后数据污染
    try {
      _ref.read(cacheControllerProvider).invalidateAll();
    } catch (_) {}
    state = const AuthState();
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
