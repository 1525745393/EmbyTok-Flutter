// AuthNotifier 状态机测试：验证登录、登出的状态流转

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:embbytok_flutter/models/models.dart';
import 'package:embbytok_flutter/providers/auth_provider.dart';
import 'package:embbytok_flutter/utils/constants.dart';

import '../mocks/mock_services.dart';

void main() {
  group('AuthState', () {
    test('初始状态正确', () {
      const state = AuthState();
      expect(state.isAuthenticated, false);
      expect(state.user, isNull);
      expect(state.backendUrl, isNull);
      expect(state.embyServerUrl, isNull);
      expect(state.token, isNull);
      expect(state.isLoading, false);
      expect(state.error, isNull);
    });

    test('copyWith 正确更新字段', () {
      const original = AuthState();
      final user = User(id: 'user-1', name: 'test', accessToken: 'token');

      final updated = original.copyWith(
        isAuthenticated: true,
        user: user,
        backendUrl: 'http://backend',
        embyServerUrl: 'http://emby',
        token: 'token',
        isLoading: true,
        error: 'error',
      );

      expect(updated.isAuthenticated, true);
      expect(updated.user, user);
      expect(updated.backendUrl, 'http://backend');
      expect(updated.embyServerUrl, 'http://emby');
      expect(updated.token, 'token');
      expect(updated.isLoading, true);
      expect(updated.error, 'error');
    });

    test('copyWith 未指定字段保持原值', () {
      final user = User(id: 'user-1', name: 'test', accessToken: 'token');
      final original = AuthState(
        isAuthenticated: true,
        user: user,
        backendUrl: 'http://backend',
      );

      final updated = original.copyWith(isLoading: true);

      expect(updated.isAuthenticated, true);
      expect(updated.user, user);
      expect(updated.backendUrl, 'http://backend');
      expect(updated.isLoading, true);
    });
  });

  group('AuthNotifier', () {
    late MockEmbytokService mockService;
    late ProviderContainer container;

    setUp(() {
      // 设置 SharedPreferences 初始值（空）
      SharedPreferences.setMockInitialValues({});
      mockService = MockEmbytokService();
    });

    tearDown(() {
      container.dispose();
    });

    test('初始状态：isAuthenticated = false, user = null', () async {
      // 创建 ProviderContainer 并注入 mock service
      container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(
            (ref) => AuthNotifier(service: mockService),
          ),
        ],
      );

      // 等待 _loadFromStorage 完成
      await Future.delayed(const Duration(milliseconds: 100));

      final state = container.read(authProvider);
      expect(state.isAuthenticated, false);
      expect(state.user, isNull);
      expect(state.isLoading, false);
      expect(state.error, isNull);
    });

    test('login() 成功：状态正确更新', () async {
      final testUser = User(
        id: 'user-123',
        name: 'testuser',
        accessToken: 'test-token',
      );

      // 配置 mock service 返回成功
      when(mockService.login(
        embyServerUrl: anyNamed('embyServerUrl'),
        username: anyNamed('username'),
        password: anyNamed('password'),
      )).thenAnswer((_) async => testUser);

      container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(
            (ref) => AuthNotifier(service: mockService),
          ),
        ],
      );

      // 等待初始化完成
      await Future.delayed(const Duration(milliseconds: 50));

      final notifier = container.read(authProvider.notifier);
      await notifier.login(
        'http://emby.example.com',
        'testuser',
        'password',
      );

      final state = container.read(authProvider);

      expect(state.isAuthenticated, true);
      expect(state.user, isNotNull);
      expect(state.user!.id, 'user-123');
      expect(state.user!.name, 'testuser');
      expect(state.user!.accessToken, 'test-token');
      expect(state.embyServerUrl, 'http://emby.example.com');
      expect(state.token, 'test-token');
      expect(state.isLoading, false);
      expect(state.error, isNull);

      // 验证 service 被正确调用
      verify(mockService.login(
        embyServerUrl: 'http://emby.example.com',
        username: 'testuser',
        password: 'password',
      )).called(1);
    });

    test('login() 失败：error 包含错误信息', () async {
      // 配置 mock service 抛出异常
      when(mockService.login(
        embyServerUrl: anyNamed('embyServerUrl'),
        username: anyNamed('username'),
        password: anyNamed('password'),
      )).thenThrow(Exception('网络错误'));

      container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(
            (ref) => AuthNotifier(service: mockService),
          ),
        ],
      );

      await Future.delayed(const Duration(milliseconds: 50));

      final notifier = container.read(authProvider.notifier);

      // 调用 login 并等待 Future 完成（Future 内部会抛出异常，被 catch 后 rethrow）
      await expectLater(
        notifier.login(
          'http://emby.example.com',
          'testuser',
          'wrong-password',
        ),
        throwsA(isA<Exception>()),
      );

      final state = container.read(authProvider);
      expect(state.isAuthenticated, false);
      expect(state.user, isNull);
      expect(state.isLoading, false);
      expect(state.error, contains('登录失败'));
    });

    test('logout()：清除状态', () async {
      // 预设已登录状态
      final testUser = User(
        id: 'user-123',
        name: 'testuser',
        accessToken: 'test-token',
      );

      when(mockService.login(
        embyServerUrl: anyNamed('embyServerUrl'),
        username: anyNamed('username'),
        password: anyNamed('password'),
      )).thenAnswer((_) async => testUser);

      container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(
            (ref) => AuthNotifier(service: mockService),
          ),
        ],
      );

      await Future.delayed(const Duration(milliseconds: 50));

      final notifier = container.read(authProvider.notifier);

      // 先登录
      await notifier.login(
        'http://emby.example.com',
        'testuser',
        'password',
      );

      // 验证已登录
      expect(container.read(authProvider).isAuthenticated, true);

      // 执行登出
      await notifier.logout();

      final state = container.read(authProvider);
      expect(state.isAuthenticated, false);
      expect(state.user, isNull);
      expect(state.backendUrl, isNull);
      expect(state.embyServerUrl, isNull);
      expect(state.token, isNull);
    });

    test('从 SharedPreferences 恢复登录状态', () async {
      // 预设 SharedPreferences 中的配置
      final config = {
        'backend_url': 'http://backend.example.com',
        'emby_server_url': 'http://emby.example.com',
        'user_id': 'user-456',
        'user_name': 'restored_user',
        'access_token': 'restored-token',
      };

      SharedPreferences.setMockInitialValues({
        kStorageKeyConfig: json.encode(config),
      });

      container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(
            (ref) => AuthNotifier(service: mockService),
          ),
        ],
      );

      // 等待 _loadFromStorage 完成
      await Future.delayed(const Duration(milliseconds: 100));

      final state = container.read(authProvider);
      expect(state.isAuthenticated, true);
      expect(state.user, isNotNull);
      expect(state.user!.id, 'user-456');
      expect(state.user!.name, 'restored_user');
      expect(state.user!.accessToken, 'restored-token');
      expect(state.backendUrl, 'http://backend.example.com');
      expect(state.embyServerUrl, 'http://emby.example.com');
    });

    test('SharedPreferences 配置损坏时忽略错误', () async {
      // 设置无效的 JSON
      SharedPreferences.setMockInitialValues({
        kStorageKeyConfig: 'invalid json {{{',
      });

      container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(
            (ref) => AuthNotifier(service: mockService),
          ),
        ],
      );

      await Future.delayed(const Duration(milliseconds: 100));

      final state = container.read(authProvider);
      // 应该保持初始状态，不抛出异常
      expect(state.isAuthenticated, false);
      expect(state.user, isNull);
    });
  });
}
