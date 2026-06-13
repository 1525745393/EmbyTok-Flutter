// 认证状态管理：用户登录状态、Token、Emby 服务器地址

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../services/embbytok_service.dart';
import '../utils/constants.dart';

// 认证状态类（简化：不再区分后端代理地址，直接存 Emby 服务器地址）
class AuthState {
  final bool isAuthenticated;
  final User? user;
  final String? embyServerUrl; // 直接连到 Emby 服务器
  final String? token; // Emby AccessToken
  final bool isLoading;
  final String? error;

  const AuthState({
    this.isAuthenticated = false,
    this.user,
    this.embyServerUrl,
    this.token,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    User? user,
    String? embyServerUrl,
    String? token,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: user ?? this.user,
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
      final prefs = await SharedPreferences.getInstance();
      final configStr = prefs.getString(kStorageKeyConfig);
      if (configStr == null || configStr.isEmpty) return;

      final Map<String, dynamic> config =
          json.decode(configStr) as Map<String, dynamic>;

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
          embyServerUrl: embyServerUrl,
          token: accessToken,
        );
      }
    } catch (e) {
      // 读取失败不中断启动
    }
  }

  // 登录：直接 POST 到 Emby 服务器
  Future<void> login(
    String embyServerUrl,
    String username,
    String password,
  ) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // 直接调用 Emby /Users/AuthenticateByName 接口
      final respData = await _service.login(
        embyServerUrl: embyServerUrl,
        username: username,
        password: password,
      );

      final user = User.fromJson(respData);

      // 持久化
      final prefs = await SharedPreferences.getInstance();
      final config = <String, dynamic>{
        'emby_server_url': embyServerUrl,
        'user_id': user.id,
        'user_name': user.name,
        'access_token': user.accessToken,
      };
      await prefs.setString(kStorageKeyConfig, json.encode(config));

      state = AuthState(
        isAuthenticated: true,
        user: user,
        embyServerUrl: embyServerUrl,
        token: user.accessToken,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e is String ? e : '登录失败：$e',
      );
      rethrow;
    }
  }

  // 退出登录
  Future<void> logout() async {
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
