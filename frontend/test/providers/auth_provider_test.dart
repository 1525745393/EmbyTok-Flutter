// AuthNotifier 状态机测试：验证登录、登出的状态流转

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:embytok_flutter/models/models.dart';
import 'package:embytok_flutter/providers/auth_provider.dart';
import 'package:embytok_flutter/providers/embytok_service_provider.dart';
import 'package:embytok_flutter/utils/constants.dart';

import '../mocks/mock_services.dart';
import '../mocks/mock_secure_storage.dart';

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
      container = ProviderContainer(
        overrides: [
          embytokServiceProvider.overrideWithValue(mockService),
          authProvider.overrideWith(
            (ref) => AuthNotifier(ref),
          ),
        ],
      );

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

      // mock login 使用命名参数调用
      when(mockService.login(
        embyServerUrl: anyNamed('embyServerUrl'),
        username: anyNamed('username'),
        password: anyNamed('password'),
      )).thenAnswer((_) async => testUser);

      container = ProviderContainer(
        overrides: [
          embytokServiceProvider.overrideWithValue(mockService),
          authProvider.overrideWith(
            (ref) => AuthNotifier(ref),
          ),
        ],
      );

      await Future.delayed(const Duration(milliseconds: 50));

      final notifier = container.read(authProvider.notifier);
      // 当前 API 签名: login(embyServerUrl, username, password, {backendUrl})
      await notifier.login(
        'http://emby.example.com',
        'testuser',
        'password',
        backendUrl: 'http://backend.example.com',
      );

      final state = container.read(authProvider);

      expect(state.isAuthenticated, true);
      expect(state.user, isNotNull);
      expect(state.user!.id, 'user-123');
      expect(state.user!.name, 'testuser');
      expect(state.user!.accessToken, 'test-token');
      expect(state.backendUrl, 'http://backend.example.com');
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
      when(mockService.login(
        embyServerUrl: anyNamed('embyServerUrl'),
        username: anyNamed('username'),
        password: anyNamed('password'),
      )).thenThrow(Exception('网络错误'));

      container = ProviderContainer(
        overrides: [
          embytokServiceProvider.overrideWithValue(mockService),
          authProvider.overrideWith(
            (ref) => AuthNotifier(ref),
          ),
        ],
      );

      await Future.delayed(const Duration(milliseconds: 50));

      final notifier = container.read(authProvider.notifier);

      expect(
        () => notifier.login(
          'http://emby.example.com',
          'testuser',
          'wrong-password',
          backendUrl: 'http://backend.example.com',
        ),
        throwsA(isA<Exception>()),
      );

      await Future.delayed(const Duration(milliseconds: 50));

      final state = container.read(authProvider);
      expect(state.isAuthenticated, false);
      expect(state.user, isNull);
      expect(state.isLoading, false);
      expect(state.error, contains('登录失败'));
    });

    test('login() 失败：字符串错误信息', () async {
      when(mockService.login(
        embyServerUrl: anyNamed('embyServerUrl'),
        username: anyNamed('username'),
        password: anyNamed('password'),
      )).thenThrow('用户名或密码错误');

      container = ProviderContainer(
        overrides: [
          embytokServiceProvider.overrideWithValue(mockService),
          authProvider.overrideWith(
            (ref) => AuthNotifier(ref),
          ),
        ],
      );

      await Future.delayed(const Duration(milliseconds: 50));

      final notifier = container.read(authProvider.notifier);

      expect(
        () => notifier.login(
          'http://emby.example.com',
          'testuser',
          'wrong-password',
          backendUrl: 'http://backend.example.com',
        ),
        throwsA('用户名或密码错误'),
      );

      await Future.delayed(const Duration(milliseconds: 50));

      final state = container.read(authProvider);
      expect(state.isAuthenticated, false);
      expect(state.error, '用户名或密码错误');
    });

    test('logout()：清除状态', () async {
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
          embytokServiceProvider.overrideWithValue(mockService),
          authProvider.overrideWith(
            (ref) => AuthNotifier(ref),
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
        backendUrl: 'http://backend.example.com',
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
          embytokServiceProvider.overrideWithValue(mockService),
          authProvider.overrideWith(
            (ref) => AuthNotifier(ref),
          ),
        ],
      );

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
          embytokServiceProvider.overrideWithValue(mockService),
          authProvider.overrideWith(
            (ref) => AuthNotifier(ref),
          ),
        ],
      );

      await Future.delayed(const Duration(milliseconds: 100));

      final state = container.read(authProvider);
      expect(state.isAuthenticated, false);
      expect(state.user, isNull);
    });
  });

  group('AuthProvider 持久化测试', () {
    late MockEmbytokService mockService;
    late MockFlutterSecureStorage mockSecureStorage;
    late ProviderContainer container;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockService = MockEmbytokService();
      mockSecureStorage = MockFlutterSecureStorage();
    });

    tearDown(() {
      container.dispose();
    });

    ProviderContainer createContainer() {
      return ProviderContainer(
        overrides: [
          embytokServiceProvider.overrideWithValue(mockService),
          secureStorageProvider.overrideWithValue(mockSecureStorage),
          authProvider.overrideWith(
            (ref) => AuthNotifier(ref),
          ),
        ],
      );
    }

    test('5.1 损坏 JSON 数据恢复：格式错误的 JSON 不崩溃', () async {
      SharedPreferences.setMockInitialValues({
        kStorageKeyConfig: 'invalid json {{{',
        kStorageKeyEmbyServerUrl: 'http://emby.example.com',
        kStorageKeyUser: 'not valid json {{{',
      });

      container = createContainer();

      await Future.delayed(const Duration(milliseconds: 100));

      final state = container.read(authProvider);
      expect(state.isAuthenticated, false);
      expect(state.user, isNull);
      expect(state.error, isNull);
    });

    test('5.2 缺少 token 字段时降级：进入未登录状态', () async {
      mockSecureStorage.setValue(kStorageKeyAccessToken, '');

      SharedPreferences.setMockInitialValues({
        kStorageKeyEmbyServerUrl: 'http://emby.example.com',
        kStorageKeyUser: json.encode({
          'backend_url': 'http://backend.example.com',
          'user_id': 'user-123',
          'user_name': 'testuser',
        }),
      });

      container = createContainer();

      await Future.delayed(const Duration(milliseconds: 100));

      final state = container.read(authProvider);
      expect(state.isAuthenticated, false);
      expect(state.user, isNull);
    });

    test('5.3 旧数据迁移：从 SharedPreferences 迁移到 flutter_secure_storage', () async {
      final oldConfig = {
        'backend_url': 'http://backend.example.com',
        'emby_server_url': 'http://emby.example.com',
        'user_id': 'user-migrate',
        'user_name': 'migrated_user',
        'access_token': 'migrated-token-123',
      };

      SharedPreferences.setMockInitialValues({
        kStorageKeyConfig: json.encode(oldConfig),
        kStorageKeyEmbyServerUrl: 'http://emby.example.com',
        kStorageKeyUser: json.encode({
          'backend_url': 'http://backend.example.com',
          'user_id': 'user-migrate',
          'user_name': 'migrated_user',
        }),
      });

      container = createContainer();

      await Future.delayed(const Duration(milliseconds: 100));

      final state = container.read(authProvider);
      expect(state.isAuthenticated, true);
      expect(state.user, isNotNull);
      expect(state.user!.id, 'user-migrate');
      expect(state.user!.name, 'migrated_user');
      expect(state.user!.accessToken, 'migrated-token-123');
      expect(state.backendUrl, 'http://backend.example.com');
      expect(state.embyServerUrl, 'http://emby.example.com');
      expect(state.token, 'migrated-token-123');

      expect(
        mockSecureStorage.getValue(kStorageKeyAccessToken),
        'migrated-token-123',
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(kStorageKeyConfig), false);
      expect(prefs.containsKey(kStorageKeyEmbyServerUrl), true);
      expect(prefs.getString(kStorageKeyEmbyServerUrl), 'http://emby.example.com');
      expect(prefs.containsKey(kStorageKeyUser), true);
    });

    test('5.3.2 旧数据迁移：只执行一次', () async {
      final oldConfig = {
        'backend_url': 'http://backend.example.com',
        'emby_server_url': 'http://emby.example.com',
        'user_id': 'user-migrate',
        'user_name': 'migrated_user',
        'access_token': 'migrated-token-123',
      };

      SharedPreferences.setMockInitialValues({
        kStorageKeyConfig: json.encode(oldConfig),
        kStorageKeyEmbyServerUrl: 'http://emby.example.com',
        kStorageKeyUser: json.encode({
          'backend_url': 'http://backend.example.com',
          'user_id': 'user-migrate',
          'user_name': 'migrated_user',
        }),
      });

      container = createContainer();

      await Future.delayed(const Duration(milliseconds: 100));

      final firstState = container.read(authProvider);
      expect(firstState.isAuthenticated, true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(kStorageKeyConfig), false);
      expect(
        mockSecureStorage.getValue(kStorageKeyAccessToken),
        'migrated-token-123',
      );

      container.dispose();

      final newMockStorage = MockFlutterSecureStorage();
      newMockStorage.setValue(kStorageKeyAccessToken, 'migrated-token-123');

      SharedPreferences.setMockInitialValues({
        kStorageKeyEmbyServerUrl: 'http://emby.example.com',
        kStorageKeyUser: json.encode({
          'backend_url': 'http://backend.example.com',
          'user_id': 'user-migrate',
          'user_name': 'migrated_user',
        }),
      });

      container = ProviderContainer(
        overrides: [
          embytokServiceProvider.overrideWithValue(mockService),
          secureStorageProvider.overrideWithValue(newMockStorage),
          authProvider.overrideWith(
            (ref) => AuthNotifier(ref),
          ),
        ],
      );

      await Future.delayed(const Duration(milliseconds: 100));

      final secondState = container.read(authProvider);
      expect(secondState.isAuthenticated, true);
      expect(secondState.token, 'migrated-token-123');
      expect(secondState.user!.id, 'user-migrate');
    });

    test('5.4 secure_storage 读取失败降级：不崩溃', () async {
      mockSecureStorage.setShouldThrowOnRead(true);

      SharedPreferences.setMockInitialValues({
        kStorageKeyEmbyServerUrl: 'http://emby.example.com',
        kStorageKeyUser: json.encode({
          'backend_url': 'http://backend.example.com',
          'user_id': 'user-123',
          'user_name': 'testuser',
        }),
      });

      container = createContainer();

      await Future.delayed(const Duration(milliseconds: 100));

      final state = container.read(authProvider);
      expect(state.error, isNull);
      expect(state.isLoading, false);
      expect(state.isAuthenticated, false);
    });

    test('5.4.2 secure_storage 读取失败：旧数据仍可迁移', () async {
      mockSecureStorage.setShouldThrowOnRead(true);
      mockSecureStorage.setShouldThrowOnWrite(false);

      final oldConfig = {
        'backend_url': 'http://backend.example.com',
        'emby_server_url': 'http://emby.example.com',
        'user_id': 'user-fallback',
        'user_name': 'fallback_user',
        'access_token': 'fallback-token',
      };

      SharedPreferences.setMockInitialValues({
        kStorageKeyConfig: json.encode(oldConfig),
        kStorageKeyEmbyServerUrl: 'http://emby.example.com',
        kStorageKeyUser: json.encode({
          'backend_url': 'http://backend.example.com',
          'user_id': 'user-fallback',
          'user_name': 'fallback_user',
        }),
      });

      container = createContainer();

      await Future.delayed(const Duration(milliseconds: 100));

      final state = container.read(authProvider);
      expect(state.isAuthenticated, true);
      expect(state.user!.id, 'user-fallback');
      expect(state.token, 'fallback-token');
      expect(
        mockSecureStorage.getValue(kStorageKeyAccessToken),
        'fallback-token',
      );
    });

    test('5.4.3 secure_storage 写入失败：登录失败并抛出异常', () async {
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

      mockSecureStorage.setShouldThrowOnWrite(true);

      container = createContainer();

      await Future.delayed(const Duration(milliseconds: 50));

      final notifier = container.read(authProvider.notifier);

      expect(
        () => notifier.login(
          'http://emby.example.com',
          'testuser',
          'password',
          backendUrl: 'http://backend.example.com',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('5.5 登出清除数据完整性：所有存储都被清除', () async {
      mockSecureStorage.setValue(kStorageKeyAccessToken, 'logout-token');

      SharedPreferences.setMockInitialValues({
        kStorageKeyEmbyServerUrl: 'http://emby.example.com',
        kStorageKeyUser: json.encode({
          'backend_url': 'http://backend.example.com',
          'user_id': 'user-logout',
          'user_name': 'logout_user',
        }),
      });

      container = createContainer();

      await Future.delayed(const Duration(milliseconds: 100));

      expect(container.read(authProvider).isAuthenticated, true);
      expect(mockSecureStorage.getValue(kStorageKeyAccessToken), 'logout-token');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(kStorageKeyEmbyServerUrl), true);
      expect(prefs.containsKey(kStorageKeyUser), true);

      final notifier = container.read(authProvider.notifier);
      await notifier.logout();

      final state = container.read(authProvider);
      expect(state.isAuthenticated, false);
      expect(state.user, isNull);
      expect(state.backendUrl, isNull);
      expect(state.embyServerUrl, isNull);
      expect(state.token, isNull);

      expect(mockSecureStorage.getValue(kStorageKeyAccessToken), isNull);
      expect(prefs.containsKey(kStorageKeyEmbyServerUrl), false);
      expect(prefs.containsKey(kStorageKeyUser), false);
      expect(prefs.containsKey(kStorageKeyConfig), false);
    });

    test('5.5.2 登出时 secure_storage 删除失败：仍能正常登出', () async {
      mockSecureStorage.setValue(kStorageKeyAccessToken, 'test-token');
      mockSecureStorage.setShouldThrowOnDelete(true);

      SharedPreferences.setMockInitialValues({
        kStorageKeyEmbyServerUrl: 'http://emby.example.com',
        kStorageKeyUser: json.encode({
          'backend_url': 'http://backend.example.com',
          'user_id': 'user-123',
          'user_name': 'testuser',
        }),
      });

      container = createContainer();

      await Future.delayed(const Duration(milliseconds: 100));

      expect(container.read(authProvider).isAuthenticated, true);

      final notifier = container.read(authProvider.notifier);
      await notifier.logout();

      final state = container.read(authProvider);
      expect(state.isAuthenticated, false);
      expect(state.user, isNull);
    });

    test('5.6 部分数据损坏：user JSON 损坏但 token 和 url 正常时已登录', () async {
      mockSecureStorage.setValue(kStorageKeyAccessToken, 'partial-token');

      SharedPreferences.setMockInitialValues({
        kStorageKeyEmbyServerUrl: 'http://emby.example.com',
        kStorageKeyUser: 'corrupted user json {{{',
      });

      container = createContainer();

      await Future.delayed(const Duration(milliseconds: 100));

      final state = container.read(authProvider);
      expect(state.isAuthenticated, true);
      expect(state.user, isNull);
      expect(state.embyServerUrl, 'http://emby.example.com');
      expect(state.token, 'partial-token');
      expect(state.error, isNull);
    });
  });
}
