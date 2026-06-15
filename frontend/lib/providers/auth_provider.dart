// 认证状态管理：用户登录状态、Token、服务地址等

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../services/embbytok_service.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';

// 认证状态类
class AuthState {
  final bool isAuthenticated;
  final User? user;
  final String? backendUrl;
  final String? embyServerUrl;
  final String? token;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.isAuthenticated = false,
    this.user,
    this.backendUrl,
    this.embyServerUrl,
    this.token,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    User? user,
    String? backendUrl,
    String? embyServerUrl,
    String? token,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: user ?? this.user,
      backendUrl: backendUrl ?? this.backendUrl,
      embyServerUrl: embyServerUrl ?? this.embyServerUrl,
      token: token ?? this.token,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

// 认证 Notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final EmbytokService _service;

  AuthNotifier({EmbytokService? service})
      : _service = service ?? EmbytokService(),
        super(const AuthState()) {
    _loadFromStorage();
  }

  // 从本地存储恢复登录状态
  Future<void> _loadFromStorage() async {
    try {
      AppLogger.debug('从本地存储恢复登录状态');
      final prefs = await SharedPreferences.getInstance();
      final configStr = prefs.getString(kStorageKeyConfig);
      if (configStr == null || configStr.isEmpty) return;

      final Map<String, dynamic> config =
          json.decode(configStr) as Map<String, dynamic>;

      final backendUrl = config['backend_url'] as String?;
      final embyServerUrl = config['emby_server_url'] as String?;
      final userId = config['user_id'] as String?;
      final userName = config['user_name'] as String?;
      final accessToken = config['access_token'] as String?;

      if (accessToken != null && accessToken.isNotEmpty && userId != null) {
        state = AuthState(
          isAuthenticated: true,
          user: User(
            id: userId,
            name: userName ?? '',
            accessToken: accessToken,
          ),
          backendUrl: backendUrl,
          embyServerUrl: embyServerUrl,
          token: accessToken,
        );
        AppLogger.info('登录状态恢复成功', data: {'userId': userId, 'hasToken': true});
      }
    } catch (e) {
      AppLogger.error('恢复登录状态失败', error: e);
      // 读取失败不中断启动，仅忽略已损坏的缓存
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

      // 持久化到 shared_preferences
      final prefs = await SharedPreferences.getInstance();
      final config = <String, dynamic>{
        'backend_url': backendUrl ?? '',
        'emby_server_url': embyServerUrl,
        'user_id': user.id,
        'user_name': user.name,
        'access_token': user.accessToken,
      };
      await prefs.setString(kStorageKeyConfig, json.encode(config));

      state = AuthState(
        isAuthenticated: true,
        user: user,
        backendUrl: backendUrl ?? '',
        embyServerUrl: embyServerUrl,
        token: user.accessToken,
      );
      AppLogger.info('登录成功', data: {'userId': user.id, 'userName': user.name});
    } catch (e) {
      AppLogger.error('登录失败', error: e);
      state = state.copyWith(
        isLoading: false,
        error: e is String ? e : '登录失败：$e',
      );
      rethrow;
    }
  }

  // 退出登录：清除本地 Token
  Future<void> logout() async {
    AppLogger.info('用户登出');
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(kStorageKeyConfig);
    } catch (_) {}
    state = const AuthState();
  }
}

// 顶层 Provider
final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier());
